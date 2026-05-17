/* eslint-disable @typescript-eslint/no-require-imports */
const path = require('path');
const { spawn } = require('child_process');
const { getHealth, getRecentSystemEvents } = require('./system');
const { loadKbRules } = require('./kb');
const { isAllowedRepairScript } = require('./repair');
const { invokeRecommendedRepairPlan } = require('./repairPlan');
const config = require('../config');

function runResourceSafety() {
    return new Promise((resolve) => {
        const child = spawn('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'RemoteSigned',
            '-File',
            path.join(config.scriptsDir, 'Test-ResourceSafety.ps1'),
            '-Root',
            config.rootDir,
            '-MaxWindowsDoctorNodeProcesses',
            '8',
            '-MaxWindowsDoctorTotalWorkingSetMB',
            '1200',
            '-MaxWindowsDoctorProcessWorkingSetMB',
            '512',
            '-Json',
        ], {
            cwd: config.rootDir,
            windowsHide: true,
            shell: false,
        });
        let stdout = '';
        child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
        child.on('close', () => {
            try { resolve(JSON.parse(stdout)); }
            catch { resolve({ Status: 'UNKNOWN' }); }
        });
        child.on('error', () => resolve({ Status: 'UNKNOWN' }));
    });
}

function actionType(rule) {
    if (isAllowedRepairScript(rule.script)) return 'auto_repair';
    if (rule.script && rule.script !== 'N/A') return 'manual_review';
    return 'guided';
}

function rankFinding(finding) {
    if (finding.actionType === 'auto_repair') return 1;
    if (finding.actionType === 'guided') return 2;
    if (finding.actionType === 'manual_review') return 3;
    return 4;
}

function buildFindings() {
    const rules = loadKbRules();
    const events = getRecentSystemEvents().slice(0, 5);
    return events.map((event) => {
        const matched = rules.find((rule) => rule.triggers.some((trigger) => event.Message.includes(trigger)));
        if (!matched) {
            return {
                source: event.Source,
                description: event.Message.substring(0, 160).replace(/\r?\n/g, ' '),
                ruleId: 'UNKNOWN',
                title: '未知系統事件',
                actionType: 'learn',
                riskLevel: 'manual_review',
                recommendation: '保留為 learn-only，不自動修復。',
            };
        }
        const action = actionType(matched);
        return {
            source: event.Source,
            description: event.Message.substring(0, 160).replace(/\r?\n/g, ' '),
            ruleId: matched.id,
            title: matched.title,
            script: matched.script,
            actionType: action,
            riskLevel: action === 'auto_repair' ? 'low' : 'manual_review',
            recommendation: matched.details,
        };
    }).sort((a, b) => rankFinding(a) - rankFinding(b));
}

async function getAiAssistantTriage() {
    const [health, resourceSafety, repairPlan] = await Promise.all([
        getHealth().catch(() => null),
        runResourceSafety(),
        invokeRecommendedRepairPlan().catch((err) => ({ Status: 'FAIL', Error: err.message })),
    ]);
    const findings = buildFindings();
    const autoRepairCount = findings.filter((item) => item.actionType === 'auto_repair').length;
    const manualCount = findings.filter((item) => item.actionType === 'manual_review').length;
    const learnCount = findings.filter((item) => item.actionType === 'learn').length;
    const resourceOk = resourceSafety.Status === 'PASS';

    const nextActions = [];
    if (!resourceOk) nextActions.push('先停止或中斷目前工作，等待資源回到安全門檻。');
    if (repairPlan.SafeBatchScriptCount > 0) nextActions.push('可先預覽 safe batch；執行仍需輸入 RUN。');
    if (autoRepairCount > 0) nextActions.push('優先處理低風險 allowlist 修復項目。');
    if (manualCount > 0) nextActions.push('manual-review 項目需人工確認，不要自動執行。');
    if (learnCount > 0) nextActions.push('未知事件應先建立 learn-only 記錄，等待審核後再升級。');
    if (nextActions.length === 0) nextActions.push('目前沒有明確故障；建議維持監控並保留最新報告。');

    return {
        Status: 'PASS',
        Mode: 'offline-triage',
        Model: 'WindowsDoctor local rules + repair decision engine',
        ResourceSafety: resourceSafety,
        Health: health,
        Summary: {
            FindingCount: findings.length,
            AutoRepairCount: autoRepairCount,
            ManualReviewCount: manualCount,
            LearnOnlyCount: learnCount,
            SafeBatchScriptCount: repairPlan.SafeBatchScriptCount || 0,
            OverallRisk: !resourceOk ? 'resource_risk' : (manualCount > 0 || learnCount > 0 ? 'manual_review' : 'low'),
        },
        Findings: findings,
        RepairPlan: repairPlan,
        NextActions: nextActions,
        SafetyPolicy: {
            RepairExecution: 'RUN required',
            ExternalAi: 'not used',
            AutoAllowlistPromotion: false,
        },
    };
}

module.exports = { getAiAssistantTriage };
