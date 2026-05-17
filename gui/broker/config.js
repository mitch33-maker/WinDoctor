/* eslint-disable @typescript-eslint/no-require-imports */
const path = require('path');

const ROOT_DIR = process.env.WD_ROOT_DIR || path.resolve(__dirname, '..', '..');
const SCRIPTS_DIR = path.join(ROOT_DIR, 'scripts');
const KB_DIR = path.join(ROOT_DIR, 'knowledge_base');
const OFFLINE_DB_FILE = path.join(ROOT_DIR, 'offline_database', 'windowsdoctor-kb.json');
const VAULT_DIR = path.join(ROOT_DIR, '.vault');

module.exports = {
    port: parseInt(process.env.WD_BROKER_PORT || '3001', 10),
    host: process.env.WD_BROKER_HOST || '127.0.0.1',
    rootDir: ROOT_DIR,
    scriptsDir: SCRIPTS_DIR,
    kbDir: KB_DIR,
    offlineDbFile: OFFLINE_DB_FILE,
    useOfflineDb: process.env.WD_USE_OFFLINE_DB === '1' || process.env.WD_USE_OFFLINE_DB === 'true',
    allowlistFile: path.join(SCRIPTS_DIR, 'repair-allowlist.json'),
    vaultFile: path.join(VAULT_DIR, 'credentials.enc'),
    lockFile: path.join(VAULT_DIR, 'environment.lock'),
    searchTimeoutMs: parseInt(process.env.WD_SEARCH_TIMEOUT_MS || '8000', 10),
    repairTimeoutMs: parseInt(process.env.WD_REPAIR_TIMEOUT_MS || '120000', 10),
    visionTimeoutMs: parseInt(process.env.WD_VISION_TIMEOUT_MS || '12000', 10),
    visionProvider: process.env.WD_VISION_PROVIDER || 'mock',
    geminiApiKey: process.env.GEMINI_API_KEY || process.env.WD_GEMINI_API_KEY || '',
    geminiModel: process.env.WD_GEMINI_MODEL || 'gemini-1.5-flash',
};
