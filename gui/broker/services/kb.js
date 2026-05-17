/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');
const config = require('../config');
const state = require('../state');

function parseQuotedList(value) {
    if (!value) return [];
    return value
        .split(',')
        .map((item) => item.trim().replace(/^["']|["']$/g, ''))
        .filter(Boolean);
}

function normalizeRepairScript(rawScript) {
    const value = (rawScript || 'N/A').trim().replace(/^["']|["']$/g, '');
    if (/^(N\/A|NA|NONE|無可用修復指令碼)$/i.test(value)) return 'N/A';
    const normalized = value.replace(/\\/g, '/').split('/').pop();
    if (!/^Repair-[A-Za-z0-9_.-]+\.bat$/.test(normalized)) return 'N/A';
    return normalized;
}

function parseKbRule(file, content) {
    const triggerMatch = content.match(/Trigger:\s*\[(.*?)\]/);
    const errorCodeMatch = content.match(/ErrorCode:\s*"?([^"\r\n]+)"?/);
    const titleMatch = content.match(/Title:\s*"?([^"\r\n]+)"?/) || content.match(/^#\s+(.+)$/m);
    const scriptMatch = content.match(/Script:\s*"?([^"\r\n]+)"?/) || content.match(/Remediation_Steps:\s*(?:scripts[\\/])?([^"\r\n]+)/);
    const detailMatch = content.match(/## 分析細節[\r\n]+([\s\S]*?)(?=\n#|$)/) || content.match(/## 修復方法[\r\n]+([\s\S]*?)(?=\n#|$)/);
    const descriptionMatch = content.match(/description:\s*"?([^"\r\n]+)"?/);
    const triggers = triggerMatch ? parseQuotedList(triggerMatch[1]) : [];
    if (errorCodeMatch) triggers.push(errorCodeMatch[1].trim());

    return {
        id: file.replace('.md', ''),
        title: titleMatch ? titleMatch[1].trim() : file.replace('.md', ''),
        triggers: [...new Set(triggers)],
        script: normalizeRepairScript(scriptMatch ? scriptMatch[1] : 'N/A'),
        details: detailMatch ? detailMatch[1].trim() : (descriptionMatch ? descriptionMatch[1].trim() : 'Matched Knowledge Base')
    };
}

function normalizeOfflineRule(rule) {
    return {
        id: rule.id,
        title: rule.title,
        triggers: Array.isArray(rule.triggers) ? rule.triggers : [],
        script: normalizeRepairScript(rule.script),
        details: rule.details || 'Matched Knowledge Base',
        category: rule.category || 'offline'
    };
}

function loadOfflineKbRules() {
    if (!config.useOfflineDb || !fs.existsSync(config.offlineDbFile)) return null;
    const database = JSON.parse(fs.readFileSync(config.offlineDbFile, 'utf8').replace(/^\uFEFF/, ''));
    if (database.schemaVersion !== 1 || !Array.isArray(database.rules)) return null;
    return database.rules
        .map(normalizeOfflineRule)
        .filter((rule) => rule.triggers.length > 0);
}

function loadMarkdownKbRules() {
    const roots = ['reviewed', 'learned']
        .map((folder) => path.join(state.kbPath, folder))
        .filter((folder) => fs.existsSync(folder));
    const searchRoots = roots.length > 0 ? roots : [state.kbPath];

    return searchRoots
        .flatMap((root) => fs.readdirSync(root, { withFileTypes: true })
            .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
            .map((entry) => ({ root, file: entry.name })))
        .map(({ root, file }) => {
            const content = fs.readFileSync(path.join(root, file), 'utf8');
            const rule = parseKbRule(file, content);
            rule.category = path.basename(root);
            return rule;
        })
        .filter((rule) => rule.triggers.length > 0);
}

function loadKbRules() {
    return loadOfflineKbRules() || loadMarkdownKbRules();
}

function writeLearnedRule(id, content) {
    const learnedPath = path.join(state.kbPath, 'learned');
    if (!fs.existsSync(learnedPath)) fs.mkdirSync(learnedPath, { recursive: true });
    fs.writeFileSync(path.join(learnedPath, `${id}.md`), content, 'utf8');
}

function getKbPath() {
    return state.kbPath;
}

function setKbPath(nextPath) {
    state.kbPath = nextPath;
    return state.kbPath;
}

module.exports = {
    getKbPath,
    setKbPath,
    loadKbRules,
    loadMarkdownKbRules,
    loadOfflineKbRules,
    writeLearnedRule,
    normalizeRepairScript,
    parseKbRule
};
