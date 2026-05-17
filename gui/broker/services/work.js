/* eslint-disable @typescript-eslint/no-require-imports */
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const config = require('../config');
const { buildIssuePlan, classifyIssue } = require('./issuePlanner');
const { getSafeCliToolIdsForComponent } = require('./offlineTools');

let activeWork = null;
let lastWork = null;

function nowIso() {
    return new Date().toISOString();
}

function summarizeRepairPlan(plan) {
    const safe = plan.SafeRecommendations || [];
    const manual = plan.ManualReviewRecommendations || [];
    const observations = plan.ObservationRecommendations || [];
    return {
        repaired: plan.Executed ? safe.map((item) => ({
            id: item.id,
            title: item.title,
            script: item.script,
            confidence: item.Confidence,
        })) : [],
        notRepaired: [...manual, ...observations].map((item) => ({
            id: item.id,
            title: item.title,
            script: item.script,
            reason: item.RepairDecisionState || item.RecommendationState || 'not eligible',
            riskLevel: item.RiskLevel,
        })),
        nextSteps: [
            plan.Executed ? 'Review the execution report and reboot only if a repaired component requires it.' : 'Preview completed only. Enter RUN before executing eligible low-risk repairs.',
            manual.length > 0 ? 'Manual-review items require technician review before any repair is allowed.' : 'No manual-review repair item was returned by the current plan.',
            observations.length > 0 ? 'Observation-only matches are diagnostic context and were not executed.' : 'No observation-only item was returned by the current plan.',
        ],
    };
}

function summarizeOfflineDiagnostics(result) {
    const diagnosticReport = result.DiagnosticReport || null;
    if (diagnosticReport && diagnosticReport.UserReport) {
        return {
            repaired: diagnosticReport.UserReport.Fixed || [],
            notRepaired: diagnosticReport.UserReport.NotFixed || [],
            nextSteps: diagnosticReport.UserReport.NextSteps || [
                'Diagnostic report completed. Review evidence before any repair preview.',
            ],
        };
    }
    const report = result.UserReport || {};
    return {
        repaired: report.Fixed || [],
        notRepaired: report.NotFixed || [],
        nextSteps: report.NextSteps || [
            result.Executed ? 'Review diagnostic evidence and continue with the repair preview gate.' : 'Preview completed only. Enter RUN before executing diagnostic tools.',
        ],
    };
}

function readResourceSnapshot(rootDir) {
    return new Promise((resolve) => {
        const child = spawn('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'RemoteSigned',
            '-File',
            path.join(rootDir, 'scripts', 'Test-ResourceSafety.ps1'),
            '-Root',
            rootDir,
            '-MaxWindowsDoctorNodeProcesses',
            '8',
            '-MaxWindowsDoctorTotalWorkingSetMB',
            '1200',
            '-MaxWindowsDoctorProcessWorkingSetMB',
            '512',
            '-Json',
        ], {
            cwd: rootDir,
            windowsHide: true,
            shell: false,
        });
        let stdout = '';
        child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
        child.on('close', () => {
            try {
                const parsed = JSON.parse(stdout);
                resolve({
                    time: nowIso(),
                    status: parsed.Status,
                    freeMemoryGB: parsed.FreeMemoryGB,
                    overallCpuPercent: parsed.OverallCpuPercent,
                    postCssWorkerCount: parsed.PostCssWorkerCount,
                    windowsDoctorNodeProcessCount: parsed.WindowsDoctorNodeProcessCount,
                    windowsDoctorTotalWorkingSetMB: parsed.WindowsDoctorTotalWorkingSetMB,
                    windowsDoctorMaxProcessWorkingSetMB: parsed.WindowsDoctorMaxProcessWorkingSetMB,
                });
            } catch {
                resolve({ time: nowIso(), status: 'UNKNOWN' });
            }
        });
        child.on('error', () => resolve({ time: nowIso(), status: 'UNKNOWN' }));
    });
}

function startRepairPlanWork({ execute = false, confirmToken = '' } = {}) {
    if (activeWork && activeWork.status === 'running') {
        const err = new Error('Another WindowsDoctor work item is already running');
        err.status = 409;
        throw err;
    }
    if (execute && confirmToken !== 'RUN') {
        const err = new Error('RUN confirmation is required before repair execution');
        err.status = 400;
        throw err;
    }

    const id = `work-${Date.now()}`;
    const scriptPath = path.join(config.scriptsDir, 'Invoke-RecommendedRepairPlan.ps1');
    const reportPath = path.join(config.rootDir, 'logs', execute ? 'gui-work-repair-execute.latest.json' : 'gui-work-repair-preview.latest.json');
    const args = [
        '-NoProfile',
        '-ExecutionPolicy',
        'RemoteSigned',
        '-File',
        scriptPath,
        '-Root',
        config.rootDir,
        '-ReportPath',
        reportPath,
        '-Json',
    ];
    if (execute) args.push('-Execute', '-ConfirmToken', confirmToken);

    const work = {
        id,
        type: 'repair-plan',
        status: 'running',
        startedAt: nowIso(),
        updatedAt: nowIso(),
        currentStep: execute ? 'Executing safe repair batch' : 'Building repair preview',
        canCancel: true,
        reportPath,
        resourceSamples: [],
        result: null,
        error: null,
        child: null,
        poller: null,
        stdout: '',
        stderr: '',
    };

    const child = spawn('powershell', args, {
        cwd: config.rootDir,
        windowsHide: true,
        shell: false,
        env: {
            ...process.env,
            NODE_OPTIONS: '--max-old-space-size=384',
            NEXT_TELEMETRY_DISABLED: '1',
        },
    });
    work.child = child;
    activeWork = work;
    lastWork = work;

    const sample = async () => {
        if (!activeWork || activeWork.id !== id) return;
        const snapshot = await readResourceSnapshot(config.rootDir);
        work.resourceSamples.push(snapshot);
        if (work.resourceSamples.length > 30) work.resourceSamples.shift();
        work.updatedAt = nowIso();
        if (snapshot.status === 'FAIL') {
            work.currentStep = 'Resource budget exceeded; cancelling work';
            child.kill();
        }
    };
    work.poller = setInterval(() => { void sample(); }, 2000);
    void sample();

    child.stdout.on('data', (chunk) => { work.stdout += chunk.toString('utf8'); });
    child.stderr.on('data', (chunk) => { work.stderr += chunk.toString('utf8'); });
    child.on('error', (err) => {
        clearInterval(work.poller);
        work.status = 'failed';
        work.error = err.message;
        work.updatedAt = nowIso();
        activeWork = null;
    });
    child.on('close', (code) => {
        clearInterval(work.poller);
        work.updatedAt = nowIso();
        if (work.status === 'cancelling') {
            work.status = 'cancelled';
            work.currentStep = 'Cancelled by operator';
            activeWork = null;
            return;
        }
        if (code !== 0) {
            work.status = 'failed';
            work.error = work.stderr || work.stdout || `Work exited with code ${code}`;
            work.currentStep = 'Failed';
            activeWork = null;
            return;
        }
        try {
            const result = JSON.parse(work.stdout);
            work.status = 'completed';
            work.result = {
                repairPlan: result,
                summary: summarizeRepairPlan(result),
            };
            work.currentStep = 'Completed';
        } catch (err) {
            work.status = 'failed';
            work.error = `Failed to parse work result JSON: ${err.message}`;
            work.currentStep = 'Failed';
        }
        activeWork = null;
    });

    return getWorkStatus();
}

function startIssueDiagnosticWork({ problemText = '' } = {}) {
    if (activeWork && activeWork.status === 'running') {
        const err = new Error('Another WindowsDoctor work item is already running');
        err.status = 409;
        throw err;
    }
    if (!String(problemText || '').trim()) {
        const err = new Error('Problem text is required');
        err.status = 400;
        throw err;
    }

    const id = `work-${Date.now()}`;
    const reportPath = path.join(config.rootDir, 'logs', 'gui-work-issue-diagnostic.latest.json');
    const work = {
        id,
        type: 'issue-diagnostic',
        status: 'running',
        startedAt: nowIso(),
        updatedAt: nowIso(),
        currentStep: 'Reading problem description',
        canCancel: true,
        reportPath,
        resourceSamples: [],
        result: null,
        error: null,
        child: null,
        poller: null,
        stdout: '',
        stderr: '',
    };

    activeWork = work;
    lastWork = work;

    const sample = async () => {
        if (!activeWork || activeWork.id !== id) return;
        const snapshot = await readResourceSnapshot(config.rootDir);
        work.resourceSamples.push(snapshot);
        if (work.resourceSamples.length > 30) work.resourceSamples.shift();
        work.updatedAt = nowIso();
        if (snapshot.status === 'FAIL') {
            work.status = 'failed';
            work.error = 'Resource budget exceeded before repair execution';
            work.currentStep = 'Resource budget exceeded';
            clearInterval(work.poller);
            activeWork = null;
        }
    };

    work.poller = setInterval(() => { void sample(); }, 2000);
    void sample();

    void (async () => {
        try {
            work.currentStep = 'Classifying problem and collecting evidence';
            work.updatedAt = nowIso();
            const plan = await buildIssuePlan(problemText);
            if (work.status === 'cancelling') {
                work.status = 'cancelled';
                work.currentStep = 'Cancelled by operator';
                return;
            }
            work.currentStep = 'Writing diagnostic report';
            work.updatedAt = nowIso();
            const json = JSON.stringify(plan, null, 2);
            require('fs').writeFileSync(reportPath, json, 'utf8');
            work.result = {
                issuePlan: plan,
                summary: {
                    repaired: plan.UserReport.Fixed,
                    notRepaired: plan.UserReport.NotFixed,
                    nextSteps: plan.UserReport.NextActions,
                },
            };
            work.status = 'completed';
            work.currentStep = 'Completed';
        } catch (err) {
            work.status = 'failed';
            work.error = err.message;
            work.currentStep = 'Failed';
        } finally {
            clearInterval(work.poller);
            work.updatedAt = nowIso();
            if (activeWork && activeWork.id === id) activeWork = null;
        }
    })();

    return getWorkStatus();
}

function readProgressFile(progressPath) {
    try {
        if (!progressPath || !fs.existsSync(progressPath)) return null;
        return JSON.parse(fs.readFileSync(progressPath, 'utf8'));
    } catch {
        return null;
    }
}

function startOfflineDiagnosticWork({ component = 'general', problemText = '', toolId = '', execute = false, confirmToken = '' } = {}) {
    if (activeWork && activeWork.status === 'running') {
        const err = new Error('Another WindowsDoctor work item is already running');
        err.status = 409;
        throw err;
    }
    if (execute && confirmToken !== 'RUN') {
        const err = new Error('RUN confirmation is required before offline diagnostic execution');
        err.status = 400;
        throw err;
    }

    const id = `work-${Date.now()}`;
    const classification = String(problemText || '').trim() ? classifyIssue(problemText) : { component: component || 'general' };
    const selectedComponent = classification.component || component || 'general';
    const safeToolIds = toolId || getSafeCliToolIdsForComponent(selectedComponent).join(',');
    const scriptPath = path.join(config.scriptsDir, 'Invoke-OfflineDiagnosticTools.ps1');
    const reportPath = path.join(config.rootDir, 'logs', execute ? 'gui-work-offline-diagnostics-execute.latest.json' : 'gui-work-offline-diagnostics-preview.latest.json');
    const progressPath = path.join(config.rootDir, 'logs', 'gui-work-offline-diagnostics-progress.latest.json');
    const args = [
        '-NoProfile',
        '-ExecutionPolicy',
        'RemoteSigned',
        '-File',
        scriptPath,
        '-Root',
        config.rootDir,
        '-Component',
        selectedComponent,
        '-ToolId',
        safeToolIds,
        '-ProgressPath',
        progressPath,
        '-ReportPath',
        reportPath,
        '-Json',
    ];
    if (execute) args.push('-Execute', '-ConfirmToken', confirmToken);

    const work = {
        id,
        type: 'offline-diagnostic',
        status: 'running',
        startedAt: nowIso(),
        updatedAt: nowIso(),
        currentStep: execute ? 'Running offline diagnostic tools sequentially' : 'Building offline diagnostic tool preview',
        canCancel: true,
        reportPath,
        progressPath,
        resourceSamples: [],
        result: null,
        error: null,
        child: null,
        poller: null,
        stdout: '',
        stderr: '',
    };

    const child = spawn('powershell', args, {
        cwd: config.rootDir,
        windowsHide: true,
        shell: false,
        env: {
            ...process.env,
            NODE_OPTIONS: '--max-old-space-size=384',
            NEXT_TELEMETRY_DISABLED: '1',
        },
    });
    work.child = child;
    activeWork = work;
    lastWork = work;

    const sample = async () => {
        if (!activeWork || activeWork.id !== id) return;
        const snapshot = await readResourceSnapshot(config.rootDir);
        const progress = readProgressFile(progressPath);
        if (progress && progress.CurrentToolId) {
            work.currentStep = `${execute ? 'Running' : 'Previewing'} ${progress.CurrentToolId} (${progress.CompletedCount || 0}/${progress.ToolCount || '?'})`;
        }
        work.resourceSamples.push(snapshot);
        if (work.resourceSamples.length > 30) work.resourceSamples.shift();
        work.updatedAt = nowIso();
        if (snapshot.status === 'FAIL') {
            work.currentStep = 'Resource budget exceeded; cancelling offline diagnostics';
            child.kill();
        }
    };
    work.poller = setInterval(() => { void sample(); }, 2000);
    void sample();

    child.stdout.on('data', (chunk) => { work.stdout += chunk.toString('utf8'); });
    child.stderr.on('data', (chunk) => { work.stderr += chunk.toString('utf8'); });
    child.on('error', (err) => {
        clearInterval(work.poller);
        work.status = 'failed';
        work.error = err.message;
        work.updatedAt = nowIso();
        activeWork = null;
    });
    child.on('close', (code) => {
        clearInterval(work.poller);
        work.updatedAt = nowIso();
        if (work.status === 'cancelling') {
            work.status = 'cancelled';
            work.currentStep = 'Cancelled by operator';
            activeWork = null;
            return;
        }
        if (code !== 0) {
            work.status = 'failed';
            work.error = work.stderr || work.stdout || `Work exited with code ${code}`;
            work.currentStep = 'Failed';
            activeWork = null;
            return;
        }
        try {
            const result = JSON.parse(work.stdout);
            work.status = 'completed';
            work.result = {
                offlineDiagnostics: result,
                diagnosticReport: result.DiagnosticReport || null,
                summary: summarizeOfflineDiagnostics(result),
            };
            work.currentStep = 'Completed';
        } catch (err) {
            work.status = 'failed';
            work.error = `Failed to parse work result JSON: ${err.message}`;
            work.currentStep = 'Failed';
        }
        activeWork = null;
    });

    return getWorkStatus();
}

function cancelActiveWork() {
    if (!activeWork || activeWork.status !== 'running') {
        return getWorkStatus();
    }
    activeWork.status = 'cancelling';
    activeWork.currentStep = 'Cancelling';
    activeWork.updatedAt = nowIso();
    if (activeWork.child) activeWork.child.kill();
    if (!activeWork.child) {
        activeWork.status = 'cancelled';
        activeWork.currentStep = 'Cancelled by operator';
        activeWork.updatedAt = nowIso();
        activeWork = null;
    }
    return getWorkStatus();
}

function publicWork(work) {
    if (!work) return null;
    return {
        id: work.id,
        type: work.type,
        status: work.status,
        startedAt: work.startedAt,
        updatedAt: work.updatedAt,
        currentStep: work.currentStep,
        canCancel: work.canCancel && work.status === 'running',
        reportPath: work.reportPath,
        latestResource: work.resourceSamples[work.resourceSamples.length - 1] || null,
        resourceSamples: work.resourceSamples,
        result: work.result,
        error: work.error,
    };
}

function getWorkStatus() {
    return {
        active: publicWork(activeWork),
        last: publicWork(lastWork),
    };
}

module.exports = { startRepairPlanWork, startIssueDiagnosticWork, startOfflineDiagnosticWork, cancelActiveWork, getWorkStatus };
