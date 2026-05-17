/* eslint-disable @typescript-eslint/no-require-imports */
const { spawn } = require('child_process');
const { getHealth, getRecentSystemEvents, testAdmin } = require('./services/system');
const { getKbPath, setKbPath, loadKbRules } = require('./services/kb');
const { getAllowedRepairScripts, isAllowedRepairScript, runRepairScript } = require('./services/repair');
const { invokeRecommendedRepairPlan } = require('./services/repairPlan');
const { startRepairPlanWork, cancelActiveWork, getWorkStatus } = require('./services/work');
const { getAiAssistantTriage } = require('./services/aiAssistant');
const { analyzeVision, getVisionStatus } = require('./services/vision');
const { learnIssue } = require('./services/learn');
const { importNotebookLmSourcePack } = require('./services/notebooklm');
const { saveCredential, getLockStatus, bindLock } = require('./services/vault');
const { ok, fail } = require('./services/response');
const state = require('./state');

function getActionType(script) {
    if (isAllowedRepairScript(script)) return 'auto_repair';
    if (script && script !== 'N/A') return 'manual_review';
    return 'guided';
}

function registerRoutes(app) {
    app.get('/api/health', async (req, res) => {
        try { ok(res, await getHealth()); }
        catch (err) { fail(res, 500, 'HEALTH_FAILED', err.message); }
    });

    app.get('/api/analyze', async (req, res) => {
        try {
            const rules = loadKbRules();
            const findings = [];
            for (const e of getRecentSystemEvents().slice(0, 5)) {
                const rule = rules.find((item) => item.triggers.some(k => e.Message.includes(k)));
                if (rule) {
                    findings.push({
                        EventID: 'Match',
                        Source: e.Source,
                        Description: e.Message.substring(0, 100).replace(/\r?\n/g, ' '),
                        MatchedRule: rule.id,
                        Diagnosis: rule.details,
                        SuggestedFix: rule.script,
                        ActionType: getActionType(rule.script)
                    });
                } else if (e.Message.length > 10) {
                    findings.push({
                        EventID: 'Unknown',
                        Source: e.Source,
                        Description: e.Message.substring(0, 100),
                        MatchedRule: 'Unknown Issue',
                        Diagnosis: '目前知識庫尚未建置此特定故障的解決方案。',
                        SuggestedFix: 'N/A',
                        ActionType: 'learn'
                    });
                }
            }
            ok(res, findings);
        } catch (err) {
            fail(res, 500, 'ANALYZE_FAILED', err.message);
        }
    });

    app.get('/api/config/kb', (req, res) => ok(res, { path: getKbPath() }));
    app.post('/api/config/kb', (req, res) => {
        if (!req.body.path) return fail(res, 400, 'PATH_REQUIRED', 'Path required');
        ok(res, { status: 'success', path: setKbPath(req.body.path) });
    });

    app.get('/api/repair/allowlist', (req, res) => ok(res, { scripts: [...getAllowedRepairScripts()].sort() }));
    app.get('/api/rules', (req, res) => {
        ok(res, loadKbRules().map((rule) => ({
            id: rule.id,
            title: rule.title,
            category: rule.category,
            triggers: rule.triggers,
            script: rule.script,
            repairAllowed: isAllowedRepairScript(rule.script)
        })));
    });

    app.post('/api/repair', async (req, res) => {
        try {
            const output = await runRepairScript(req.body.script);
            ok(res, { status: 'success', output });
        } catch (err) {
            fail(res, err.status || 500, err.status === 400 ? 'SCRIPT_NOT_ALLOWED' : 'REPAIR_FAILED', err.message);
        }
    });

    app.get('/api/repair-plan', async (req, res) => {
        try { ok(res, await invokeRecommendedRepairPlan()); }
        catch (err) { fail(res, err.status || 500, 'REPAIR_PLAN_FAILED', err.message); }
    });

    app.post('/api/repair-plan/execute', async (req, res) => {
        try { ok(res, await invokeRecommendedRepairPlan({ execute: true, confirmToken: req.body.confirmToken || '' })); }
        catch (err) { fail(res, err.status || 500, err.status === 400 ? 'RUN_CONFIRMATION_REQUIRED' : 'REPAIR_PLAN_EXECUTE_FAILED', err.message); }
    });

    app.get('/api/work/status', (req, res) => ok(res, getWorkStatus()));
    app.post('/api/work/cancel', (req, res) => ok(res, cancelActiveWork()));
    app.post('/api/work/repair-plan', (req, res) => {
        try { ok(res, startRepairPlanWork({ execute: !!req.body.execute, confirmToken: req.body.confirmToken || '' })); }
        catch (err) { fail(res, err.status || 500, err.status === 409 ? 'WORK_ALREADY_RUNNING' : 'WORK_START_FAILED', err.message); }
    });

    app.get('/api/ai/triage', async (req, res) => {
        try { ok(res, await getAiAssistantTriage()); }
        catch (err) { fail(res, err.status || 500, 'AI_TRIAGE_FAILED', err.message); }
    });

    app.post('/api/vision-analyze', async (req, res) => ok(res, await analyzeVision()));
    app.get('/api/vision/status', (req, res) => ok(res, getVisionStatus()));

    app.post('/api/sentry/elevate', async (req, res) => {
        const isAdmin = await testAdmin();
        if (isAdmin) return ok(res, { status: 'success', elevated: true, message: 'Broker already elevated' });
        return fail(res, 501, 'MANUAL_ELEVATION_REQUIRED', '請以系統管理員身分啟動 Broker：node e:\\WindowsDoctor\\gui\\broker.js');
        /*
        return res.status(501).json({
            status: 'manual_required',
            elevated: false,
            message: '請以系統管理員身分啟動 Broker：node e:\\WindowsDoctor\\gui\\broker.js'
        });
        */
    });

    app.post('/api/learn', async (req, res) => {
        try { ok(res, await learnIssue(req.body)); }
        catch (err) { fail(res, 500, 'LEARN_FAILED', err.message); }
    });

    app.post('/api/notebooklm/import', async (req, res) => {
        try { ok(res, await importNotebookLmSourcePack(req.body.sourcePack)); }
        catch (err) { fail(res, err.status || 500, 'NOTEBOOKLM_IMPORT_FAILED', err.message); }
    });

    app.post('/api/vault/save', (req, res) => {
        try {
            saveCredential(req.body.username, req.body.password);
            ok(res, { status: 'success', message: 'Credentials Stored Securely (AES-GCM)' });
        } catch (err) {
            fail(res, 500, 'VAULT_SAVE_FAILED', err.message);
        }
    });

    app.get('/api/vault/lock-status', (req, res) => {
        try { ok(res, getLockStatus()); }
        catch (err) { fail(res, 500, 'LOCK_STATUS_FAILED', err.message); }
    });

    app.post('/api/vault/lock-bind', (req, res) => {
        try {
            bindLock();
            ok(res, { status: 'success' });
        } catch (err) {
            fail(res, 500, 'LOCK_BIND_FAILED', err.message);
        }
    });

    app.post('/api/sync', (req, res) => {
        try {
            const { nas, web } = req.body;
            if (nas) {
                const target = '\\\\192.168.1.135\\home\\WindowsDoctor\\knowledge_base';
                const child = spawn('robocopy', [state.kbPath, target, '/MIR', '/R:3', '/W:5'], {
                    windowsHide: false,
                    shell: false,
                });
                child.on('close', (code) => {
                    if (code > 7) console.error('RoboCopy sync failed:', code);
                });
                child.on('error', (err) => console.error('RoboCopy sync failed:', err.message));
            }
            ok(res, { status: 'success', data: web ? 'NAS sync triggered; web sync is not configured' : 'Sync triggered in background via RoboCopy' });
        } catch (err) {
            fail(res, 500, 'SYNC_FAILED', err.message);
        }
    });
}

module.exports = { registerRoutes };
