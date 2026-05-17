/* eslint-disable @typescript-eslint/no-require-imports */
const path = require('path');
const { spawn } = require('child_process');
const config = require('../config');
const { loadKbRules } = require('./kb');
const { invokeRecommendedRepairPlan } = require('./repairPlan');
const { getAiAssistantTriage } = require('./aiAssistant');
const { selectToolsForComponent, getSafeCliToolIdsForComponent } = require('./offlineTools');

const COMPONENTS = [
    {
        id: 'printer',
        label: '印表機',
        terms: ['printer', 'print', 'spooler', '列印', '印表機', '卡住', '佇列', '0x0000011b', '0x0709'],
        checks: ['printer queue/spooler evidence', 'printer related KB match', 'manual driver risk review'],
    },
    {
        id: 'windows_update',
        label: 'Windows Update',
        terms: ['windows update', 'update', '更新', '升級', '0x8024', '0x80070005', '0xc1900101'],
        checks: ['Windows Update event evidence', 'official Microsoft update guidance', 'update-cache repair safety gate'],
    },
    {
        id: 'network',
        label: '網路',
        terms: ['network', 'dns', 'wifi', 'wi-fi', 'dhcp', 'internet', 'proxy', '網路', '上網', '無法連線', 'dns', '169.254'],
        checks: ['adapter/IP/DNS evidence', 'WinHTTP proxy state', 'network reset safety gate'],
    },
    {
        id: 'boot',
        label: '開機',
        terms: ['boot', 'bcd', 'winre', 'bitlocker', '開機', '啟動', '藍畫面', 'bsod', 'inaccessible boot'],
        checks: ['boot/BCD evidence', 'WinRE readiness', 'manual boot repair guidance'],
    },
    {
        id: 'performance',
        label: '效能',
        terms: ['slow', 'performance', 'cpu', 'memory', 'ram', '很慢', '卡', '當機', '記憶體', '高cpu', '高 cpu'],
        checks: ['resource safety', 'high CPU/hang event evidence', 'low-resource startup guidance'],
    },
    {
        id: 'hardware',
        label: '硬體/驅動',
        terms: ['device manager', 'code 43', 'driver', 'gpu', 'usb', '裝置管理員', '驅動', '顯示卡', '硬體'],
        checks: ['Device Manager code evidence', 'driver risk review', 'manual hardware guidance'],
    },
    {
        id: 'system_integrity',
        label: '系統完整性',
        terms: ['sfc', 'dism', 'cbs', 'corrupt', '系統檔', '損毀', '完整性'],
        checks: ['CBS/DISM evidence', 'SFC/DISM official sequence', 'RUN-gated repair guidance'],
    },
];

function normalizeText(value) {
    return String(value || '').trim();
}

function classifyIssue(problemText) {
    const text = normalizeText(problemText).toLowerCase();
    if (!text) {
        return {
            component: 'unknown',
            label: '未知',
            confidence: 0,
            matchedTerms: [],
            checks: ['ask user for a short problem description'],
        };
    }

    const ranked = COMPONENTS.map((component) => {
        const matchedTerms = component.terms.filter((term) => text.includes(term.toLowerCase()));
        return {
            component: component.id,
            label: component.label,
            confidence: Math.min(95, matchedTerms.length * 30),
            matchedTerms,
            checks: component.checks,
        };
    }).sort((a, b) => b.confidence - a.confidence);

    const best = ranked[0];
    if (!best || best.confidence === 0) {
        return {
            component: 'general',
            label: '一般 Windows 問題',
            confidence: 35,
            matchedTerms: [],
            checks: ['resource safety', 'event log scan', 'KB matching', 'repair preview'],
        };
    }
    return best;
}

function findRelevantRules(problemText, component) {
    const text = normalizeText(problemText).toLowerCase();
    const terms = text.split(/[\s,，。；;:：]+/).filter((item) => item.length >= 2);
    const rules = loadKbRules();
    return rules.map((rule) => {
        const haystack = `${rule.id} ${rule.title} ${rule.details} ${rule.triggers.join(' ')}`.toLowerCase();
        let score = 0;
        for (const term of terms) {
            if (haystack.includes(term)) score += 2;
        }
        if (component && component !== 'general' && component !== 'unknown' && haystack.includes(component)) score += 4;
        return {
            id: rule.id,
            title: rule.title,
            script: rule.script,
            details: rule.details,
            score,
        };
    }).filter((rule) => rule.score > 0)
        .sort((a, b) => b.score - a.score)
        .slice(0, 6);
}

function summarizeRepairOutcome(repairPlan) {
    const safe = repairPlan.SafeRecommendations || [];
    const manual = repairPlan.ManualReviewRecommendations || [];
    const previewOnly = repairPlan.PreviewOnlyRecommendations || [];
    const observations = repairPlan.ObservationRecommendations || [];
    return {
        autoRepairReady: safe.map((item) => ({
            id: item.id,
            title: item.title,
            script: item.script,
            confidence: item.Confidence,
            gate: item.ExecutionGate,
        })),
        blockedOrManual: [...manual, ...previewOnly, ...observations].map((item) => ({
            id: item.id,
            title: item.title,
            script: item.script,
            reason: item.AutoRepairSafety?.BlockReasons?.join('; ') || item.RepairDecisionState || item.RecommendationState || 'not eligible',
            riskLevel: item.RiskLevel,
        })),
    };
}

function runSpecializedDiagnostics(component) {
    return new Promise((resolve) => {
        const safeComponent = component || 'general';
        const scriptPath = path.join(config.scriptsDir, 'Test-SpecializedIssueDiagnostics.ps1');
        const args = [
            '-NoProfile',
            '-ExecutionPolicy',
            'RemoteSigned',
            '-File',
            scriptPath,
            '-Root',
            config.rootDir,
            '-Component',
            safeComponent,
            '-Json',
        ];
        const child = spawn('powershell', args, { cwd: config.rootDir, windowsHide: true });
        let stdout = '';
        let stderr = '';
        const timer = setTimeout(() => child.kill(), 20000);
        child.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
        child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
        child.on('close', (code) => {
            clearTimeout(timer);
            if (code !== 0) {
                resolve({
                    Status: 'WARN',
                    Component: safeComponent,
                    CheckCount: 0,
                    Checks: [{ Name: 'specialized-diagnostics', Status: 'WARN', Detail: stderr || `ExitCode=${code}` }],
                });
                return;
            }
            try {
                resolve(JSON.parse(stdout));
            } catch (error) {
                resolve({
                    Status: 'WARN',
                    Component: safeComponent,
                    CheckCount: 0,
                    Checks: [{ Name: 'specialized-diagnostics-json', Status: 'WARN', Detail: error.message }],
                });
            }
        });
        child.on('error', (error) => {
            clearTimeout(timer);
            resolve({
                Status: 'WARN',
                Component: safeComponent,
                CheckCount: 0,
                Checks: [{ Name: 'specialized-diagnostics-spawn', Status: 'WARN', Detail: error.message }],
            });
        });
    });
}

async function buildIssuePlan(problemText) {
    const userProblem = normalizeText(problemText);
    if (!userProblem) {
        const err = new Error('Problem text is required');
        err.status = 400;
        throw err;
    }

    const classification = classifyIssue(userProblem);
    const [triage, repairPlan, specializedDiagnostics] = await Promise.all([
        getAiAssistantTriage(),
        invokeRecommendedRepairPlan(),
        runSpecializedDiagnostics(classification.component),
    ]);
    const relevantRules = findRelevantRules(userProblem, classification.component);
    const repairOutcome = summarizeRepairOutcome(repairPlan);
    const offlineToolPlan = selectToolsForComponent(classification.component);
    const safeCliToolIds = getSafeCliToolIdsForComponent(classification.component);
    const canAutoExecute = repairOutcome.autoRepairReady.length > 0;

    const nextActions = [
        '已完成問題理解、資源檢查、KB 比對與修復預覽。',
        offlineToolPlan.SelectedTools.length > 0 ? '已依問題類型自動選出離線診斷工具；目前只顯示用途與命令預覽，未執行工具。' : '尚未找到可用的離線診斷工具包。',
        canAutoExecute ? '已有通過 safety policy 的候選修復；真正執行仍需 RUN。' : '目前沒有通過 unattended auto-batch gate 的修復項目，先提供安全建議與需補證據項目。',
        '高風險或會中斷裝置/服務的修復會停在 manual review。',
    ];

    return {
        Status: 'PASS',
        Mode: 'natural-language-diagnostic-preview',
        ProblemText: userProblem,
        Classification: classification,
        DiagnosticPlan: {
            ExecutionModel: 'sequential',
            Steps: [
                { name: 'resource-safety', status: triage.ResourceSafety?.Status || 'UNKNOWN', destructive: false },
                { name: 'classify-user-problem', status: 'PASS', destructive: false },
                { name: 'run-specialized-read-only-diagnostics', status: specializedDiagnostics.Status || 'UNKNOWN', destructive: false },
                { name: 'match-kb-rules', status: 'PASS', destructive: false },
                { name: 'build-repair-preview', status: repairPlan.Status || 'UNKNOWN', destructive: false },
                { name: 'apply-auto-repair-safety-policy', status: 'PASS', destructive: false },
            ],
        },
        RelevantRules: relevantRules,
        SpecializedDiagnostics: specializedDiagnostics,
        OfflineToolPlan: offlineToolPlan,
        SafeCliDiagnosticBatch: {
            ToolIds: safeCliToolIds,
            ExecutionModel: 'sequential-run-gated',
            PreviewCommandHint: `Invoke-OfflineDiagnosticTools.ps1 -ToolId ${safeCliToolIds.join(',')} -Json`,
            SafetyPolicy: {
                SafeCliOnly: true,
                RunGateRequired: true,
                NoRepairExecuted: true,
                NoCleanupExecuted: true,
            },
        },
        AiTriageSummary: triage.Summary,
        RepairPreview: {
            RepairPlanVersion: repairPlan.RepairPlanVersion,
            DecisionEngineVersion: repairPlan.DecisionEngineVersion,
            SafeBatchScriptCount: repairPlan.SafeBatchScriptCount,
            Executed: repairPlan.Executed,
            Outcome: repairOutcome,
        },
        UserReport: {
            Summary: `${classification.label} 類型問題，信心 ${classification.confidence}%。已完成安全預覽，未執行修復。`,
            Fixed: [],
            NotFixed: repairOutcome.blockedOrManual,
            NextActions: nextActions,
            RequiresRun: canAutoExecute,
        },
        SafetyPolicy: {
            NoRepairExecuted: true,
            RunGateRequired: true,
            AutoBatchRequiresPolicyApproval: true,
            OfflineToolAutoSelection: true,
            OfflineToolExecution: 'preview-only',
            ExternalAi: 'not used',
        },
    };
}

module.exports = { classifyIssue, buildIssuePlan, runSpecializedDiagnostics };
