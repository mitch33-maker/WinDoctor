/* eslint-disable @typescript-eslint/no-require-imports */
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { normalizeRepairScript, parseKbRule, loadKbRules, loadOfflineKbRules } = require('../services/kb');
const { getAllowedRepairScripts, isAllowedRepairScript } = require('../services/repair');
const { invokeRecommendedRepairPlan } = require('../services/repairPlan');
const { getAiAssistantTriage } = require('../services/aiAssistant');
const { classifyIssue, buildIssuePlan } = require('../services/issuePlanner');
const { getToolPackageStatus, selectToolsForComponent, getSafeCliToolIdsForComponent } = require('../services/offlineTools');
const { analyzeVision, getVisionStatus } = require('../services/vision');
const { hashToken, verifyTokenHash, roleAllows, getManagementStatus } = require('../services/admin');
const config = require('../config');

function testNormalizeRepairScript() {
    assert.strictEqual(normalizeRepairScript('N/A'), 'N/A');
    assert.strictEqual(normalizeRepairScript('"N/A"'), 'N/A');
    assert.strictEqual(normalizeRepairScript('scripts/Repair-NetworkStack.bat'), 'Repair-NetworkStack.bat');
    assert.strictEqual(normalizeRepairScript('..\\bad.bat'), 'N/A');
    assert.strictEqual(normalizeRepairScript('AutoRepair-KB-1.bat'), 'N/A');
    assert.strictEqual(normalizeRepairScript('Repair-Test.ps1'), 'N/A');
}

function testParseKbRule() {
    const rule = parseKbRule('RULE-TEST.md', `---
description: "Test rule"
---
# Test Rule
- EventID/Code: 0xTEST
- Trigger: ["0xTEST", "Network"]
- Script: "scripts/Repair-NetworkStack.bat"

## 分析細節
Reviewed detail.
`);
    assert.strictEqual(rule.id, 'RULE-TEST');
    assert.strictEqual(rule.title, 'Test Rule');
    assert.deepStrictEqual(rule.triggers, ['0xTEST', 'Network']);
    assert.strictEqual(rule.script, 'Repair-NetworkStack.bat');
    assert.strictEqual(rule.details, 'Reviewed detail.');
}

function testAllowlist() {
    const allowlist = getAllowedRepairScripts();
    assert.ok(allowlist.size >= 1);
    assert.strictEqual(isAllowedRepairScript('Repair-NetworkStack.bat'), true);
    assert.strictEqual(isAllowedRepairScript('..\\Repair-NetworkStack.bat'), false);
    assert.strictEqual(isAllowedRepairScript('AutoRepair-KB-1.bat'), false);
    assert.strictEqual(isAllowedRepairScript('N/A'), false);
}

function testLoadKbRules() {
    const rules = loadKbRules();
    assert.ok(rules.length >= 1);
    assert.ok(rules.every((rule) => rule.category === 'reviewed' || rule.category === 'learned'));
    assert.ok(!rules.some((rule) => rule.script === 'A'));
}

function testOfflineKbRulesAvailable() {
    const original = process.env.WD_USE_OFFLINE_DB;
    process.env.WD_USE_OFFLINE_DB = '1';
    delete require.cache[require.resolve('../config')];
    delete require.cache[require.resolve('../state')];
    delete require.cache[require.resolve('../services/kb')];
    const { loadOfflineKbRules: reloadOfflineRules } = require('../services/kb');
    const rules = reloadOfflineRules();
    if (original === undefined) delete process.env.WD_USE_OFFLINE_DB;
    else process.env.WD_USE_OFFLINE_DB = original;
    delete require.cache[require.resolve('../config')];
    delete require.cache[require.resolve('../state')];
    delete require.cache[require.resolve('../services/kb')];

    assert.ok(rules.length >= 1);
    assert.ok(rules.every((rule) => rule.triggers.length > 0));
}

function testPortableRootPath() {
    const expectedRoot = path.resolve(__dirname, '..', '..', '..');
    assert.strictEqual(config.rootDir, expectedRoot);
    assert.strictEqual(config.kbDir, path.join(expectedRoot, 'knowledge_base'));
    assert.strictEqual(config.scriptsDir, path.join(expectedRoot, 'scripts'));
}

function testRepairServiceAvoidsDynamicShellExec() {
    const source = fs.readFileSync(path.join(__dirname, '..', 'services', 'repair.js'), 'utf8');
    assert.ok(source.includes("spawn('cmd.exe'"));
    assert.ok(source.includes('shell: false'));
    assert.ok(!source.includes('exec(`'));
    assert.ok(!source.includes('exec("'));
}

function testEventLogAnalyzerService() {
    const source = fs.readFileSync(path.join(__dirname, '..', 'services', 'eventLogAnalyzer.js'), 'utf8');
    assert.ok(source.includes('Analyze-WindowsEventLogs.ps1'));
    assert.ok(source.includes('shell: false'));
    assert.ok(source.includes('windowsHide: true'));
    assert.ok(!source.includes('exec('));
}

function testManagementService() {
    const hashed = hashToken('test-token');
    assert.strictEqual(verifyTokenHash('test-token', hashed), true);
    assert.strictEqual(verifyTokenHash('bad-token', hashed), false);
    assert.strictEqual(roleAllows('admin', 'operator'), true);
    assert.strictEqual(roleAllows('viewer', 'admin'), false);
    const status = getManagementStatus();
    assert.strictEqual(status.Status, 'PASS');
    assert.strictEqual(status.SafetyPolicy.NasRequired, false);
    assert.ok(status.OperationClasses.some((item) => item.id === 'run_gated' && item.role === 'admin'));
}

async function testVisionFallback() {
    const status = getVisionStatus();
    assert.ok(['mock', 'gemini'].includes(status.provider));
    assert.strictEqual(status.fallback, 'mock');
    const result = await analyzeVision();
    assert.ok(result.prediction);
    assert.ok(result.recommendation);
}

async function testRecommendedRepairPlanPreview() {
    const result = await invokeRecommendedRepairPlan();
    assert.strictEqual(result.Status, 'PASS');
    assert.strictEqual(result.Mode, 'preview');
    assert.strictEqual(result.Executed, false);
    assert.strictEqual(result.RepairPlanVersion, 4);
    assert.strictEqual(result.DecisionEngineVersion, 4);
    assert.strictEqual(result.SafeBatchExecutionPolicy.StopOnFirstFailure, true);
    assert.strictEqual(result.SafeBatchExecutionPolicy.AutoBatchReviewStatusRequired, 'APPROVED');
    assert.ok(Array.isArray(result.RepairPlanScoring.RequiredAutoRepairGates));
    assert.match(result.OperatorGuidance.EvidenceScoring, /Confidence combines/);
    assert.match(result.OperatorGuidance.DryRunImpact, /does not execute/);
    assert.match(result.OperatorGuidance.RunGate, /RUN/);
    assert.match(result.OperatorGuidance.RollbackGuidance, /restore/);
}

async function testAiAssistantTriage() {
    const result = await getAiAssistantTriage();
    assert.strictEqual(result.Status, 'PASS');
    assert.strictEqual(result.Mode, 'offline-triage');
    assert.ok(result.Summary);
    assert.ok(Array.isArray(result.NextActions));
    assert.strictEqual(result.SafetyPolicy.ExternalAi, 'not used');
}

async function testIssuePlanner() {
    const classification = classifyIssue('Windows Update 失敗 0x8024');
    assert.strictEqual(classification.component, 'windows_update');
    assert.ok(classification.confidence > 0);

    const plan = await buildIssuePlan('印表機不能列印，佇列卡住');
    assert.strictEqual(plan.Status, 'PASS');
    assert.strictEqual(plan.Mode, 'natural-language-diagnostic-preview');
    assert.strictEqual(plan.SafetyPolicy.NoRepairExecuted, true);
    assert.strictEqual(plan.DiagnosticPlan.ExecutionModel, 'sequential');
    assert.ok(Array.isArray(plan.UserReport.NextActions));
    assert.ok(plan.SpecializedDiagnostics);
    assert.ok(plan.SpecializedDiagnostics.CheckCount >= 1);
    assert.ok(plan.OfflineToolPlan);
    assert.strictEqual(plan.OfflineToolPlan.SafetyPolicy.NoToolExecuted, true);
    assert.ok(plan.OfflineToolPlan.SelectedTools.length >= 1);
    assert.ok(plan.SafeCliDiagnosticBatch.ToolIds.includes('handle'));
    assert.strictEqual(plan.SafeCliDiagnosticBatch.SafetyPolicy.SafeCliOnly, true);
    assert.ok(plan.RepairPreview.RepairPlanVersion >= 4);
}

function testOfflineTools() {
    const status = getToolPackageStatus();
    assert.ok(['PASS', 'WARN', 'WAITING'].includes(status.Status));
    assert.strictEqual(status.SafetyPolicy.NoToolExecuted, true);
    assert.strictEqual(status.SafetyPolicy.AutoRunAllowed, false);
    if (status.Status === 'PASS') {
        assert.ok(status.ToolCount >= 1);
        assert.ok(status.Tools.every((tool) => tool.autoRunAllowed === false));
        assert.ok(status.Tools.every((tool) => tool.commandPreview));
    }

    const selected = selectToolsForComponent('performance');
    assert.strictEqual(selected.Mode, 'offline-tool-auto-selection-preview');
    assert.strictEqual(selected.SafetyPolicy.NoToolExecuted, true);
    assert.ok(selected.SelectedTools.some((item) => item.id === 'rammap'));
    const safeCli = getSafeCliToolIdsForComponent('network');
    assert.deepStrictEqual(safeCli, ['tcpview', 'handle']);
}

function testOfflineDiagnosticWorkReportIntegration() {
    const source = fs.readFileSync(path.join(__dirname, '..', 'services', 'work.js'), 'utf8');
    assert.ok(source.includes('DiagnosticReport'));
    assert.ok(source.includes('diagnosticReport'));
    assert.ok(source.includes('summarizeOfflineDiagnostics'));
    assert.ok(source.includes('problemText'));
    assert.ok(source.includes('getSafeCliToolIdsForComponent'));
    assert.ok(source.includes('ProgressPath'));
}

(async () => {
    testNormalizeRepairScript();
    testParseKbRule();
    testAllowlist();
    testLoadKbRules();
    assert.strictEqual(loadOfflineKbRules(), null);
    testOfflineKbRulesAvailable();
    testPortableRootPath();
    testRepairServiceAvoidsDynamicShellExec();
    testEventLogAnalyzerService();
    testManagementService();
    await testVisionFallback();
    await testRecommendedRepairPlanPreview();
    await testAiAssistantTriage();
    testOfflineTools();
    testOfflineDiagnosticWorkReportIntegration();
    await testIssuePlanner();
    console.log('broker service tests passed');
})();
