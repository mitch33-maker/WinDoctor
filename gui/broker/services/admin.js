/* eslint-disable @typescript-eslint/no-require-imports */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const config = require('../config');

const ROLE_LEVELS = { viewer: 1, operator: 2, admin: 3, maintainer: 4 };
const MANAGEMENT_DIR = path.join(config.rootDir, 'management');
const ADMIN_ACCOUNTS_FILE = path.join(MANAGEMENT_DIR, 'admin_accounts.json');
const ADMIN_AUDIT_FILE = path.join(MANAGEMENT_DIR, 'admin_audit_events.jsonl');
const MANAGEMENT_PROFILE_FILE = path.join(config.rootDir, 'nas', 'windowsdoctor-management-profile.json');

const OPERATION_CLASSES = [
    { id: 'read_only', role: 'viewer', description: 'Health, rules, reports, AI preview, resource status.' },
    { id: 'preview', role: 'operator', description: 'Diagnostic preview, repair preview, resource organizer preview.' },
    { id: 'run_gated', role: 'admin', description: 'Repair, cleanup, logoff, uninstall, USB write, or any RUN-gated state change.' },
    { id: 'admin_only', role: 'admin', description: 'Create or disable admin accounts, read audit events, manage tokens.' },
    { id: 'maintainer_only', role: 'maintainer', description: 'Change allowlist, repair policy, KB promotion, release and package policy.' },
];

function nowText() {
    return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function ensureManagementDir() {
    fs.mkdirSync(MANAGEMENT_DIR, { recursive: true });
}

function readJson(file, fallback) {
    try {
        if (!fs.existsSync(file)) return fallback;
        const data = JSON.parse(fs.readFileSync(file, 'utf8'));
        return data;
    } catch {
        return fallback;
    }
}

function writeJson(file, data) {
    ensureManagementDir();
    fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
}

function hashToken(token, salt = crypto.randomBytes(16).toString('hex')) {
    const digest = crypto.pbkdf2Sync(String(token || ''), salt, 120000, 32, 'sha256').toString('hex');
    return { salt, hash: digest, algorithm: 'PBKDF2-SHA256' };
}

function verifyTokenHash(token, record) {
    if (!token || !record?.salt || !record?.hash) return false;
    const actual = hashToken(token, record.salt).hash;
    return crypto.timingSafeEqual(Buffer.from(actual, 'hex'), Buffer.from(record.hash, 'hex'));
}

function publicAdmin(row) {
    return {
        adminId: row.adminId || '',
        displayName: row.displayName || '',
        role: row.role || 'viewer',
        disabled: !!row.disabled,
        createdAt: row.createdAt || '',
        updatedAt: row.updatedAt || '',
        lastSeenAt: row.lastSeenAt || '',
        note: row.note || '',
    };
}

function loadAdminAccounts() {
    const rows = readJson(ADMIN_ACCOUNTS_FILE, []);
    return Array.isArray(rows) ? rows : [];
}

function saveAdminAccounts(rows) {
    writeJson(ADMIN_ACCOUNTS_FILE, rows.map((row) => {
        const safe = { ...row };
        delete safe.token;
        return safe;
    }));
}

function listAdminAccounts() {
    const rows = loadAdminAccounts();
    return {
        Status: 'PASS',
        Count: rows.length,
        Admins: rows.map(publicAdmin),
    };
}

function recordAdminAudit(actor, action, metadata = {}) {
    ensureManagementDir();
    const event = {
        createdAt: nowText(),
        actor: String(actor || 'system'),
        action: String(action || ''),
        metadata,
    };
    fs.appendFileSync(ADMIN_AUDIT_FILE, `${JSON.stringify(event)}\n`, 'utf8');
    return event;
}

function createAdminAccount({ adminId, displayName, role, token, note, actor = 'system' }) {
    const safeAdminId = String(adminId || '').trim();
    const safeRole = String(role || 'viewer').trim();
    if (!safeAdminId) {
        const err = new Error('adminId is required');
        err.status = 400;
        throw err;
    }
    if (!ROLE_LEVELS[safeRole]) {
        const err = new Error(`Invalid role: ${safeRole}`);
        err.status = 400;
        throw err;
    }
    if (!token) {
        const err = new Error('token is required');
        err.status = 400;
        throw err;
    }
    const rows = loadAdminAccounts();
    if (rows.some((row) => row.adminId === safeAdminId)) {
        const err = new Error(`adminId exists: ${safeAdminId}`);
        err.status = 409;
        throw err;
    }
    const hashed = hashToken(token);
    const record = {
        adminId: safeAdminId,
        displayName: String(displayName || safeAdminId).trim(),
        role: safeRole,
        salt: hashed.salt,
        hash: hashed.hash,
        algorithm: hashed.algorithm,
        disabled: false,
        createdAt: nowText(),
        updatedAt: nowText(),
        note: String(note || '').trim(),
    };
    rows.push(record);
    saveAdminAccounts(rows);
    recordAdminAudit(actor, 'admin.create', { adminId: safeAdminId, role: safeRole });
    return { Status: 'PASS', Admin: publicAdmin(record) };
}

function setAdminDisabled({ adminId, disabled, reason = '', actor = 'system' }) {
    const rows = loadAdminAccounts();
    const target = rows.find((row) => row.adminId === String(adminId || '').trim());
    if (!target) {
        const err = new Error(`adminId not found: ${adminId}`);
        err.status = 404;
        throw err;
    }
    target.disabled = !!disabled;
    target.disabledReason = String(reason || '').trim();
    target.updatedAt = nowText();
    saveAdminAccounts(rows);
    recordAdminAudit(actor, target.disabled ? 'admin.disable' : 'admin.enable', { adminId: target.adminId, reason });
    return { Status: 'PASS', Admin: publicAdmin(target) };
}

function authenticateAdminToken(token) {
    const envTokens = [
        { token: process.env.WD_VIEWER_TOKEN || '', role: 'viewer', adminId: 'env-viewer' },
        { token: process.env.WD_OPERATOR_TOKEN || '', role: 'operator', adminId: 'env-operator' },
        { token: process.env.WD_ADMIN_TOKEN || '', role: 'admin', adminId: 'env-admin' },
        { token: process.env.WD_MAINTAINER_TOKEN || '', role: 'maintainer', adminId: 'env-maintainer' },
    ].filter((item) => item.token);
    const supplied = String(token || '');
    const matchedEnv = envTokens.find((item) => {
        const expected = Buffer.from(item.token);
        const actual = Buffer.from(supplied);
        return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
    });
    if (matchedEnv) {
        return { ok: true, adminId: matchedEnv.adminId, role: matchedEnv.role, source: 'environment' };
    }

    const rows = loadAdminAccounts();
    for (const row of rows) {
        if (row.disabled) continue;
        if (verifyTokenHash(token, row)) {
            row.lastSeenAt = nowText();
            saveAdminAccounts(rows);
            return { ok: true, adminId: row.adminId, role: row.role, source: 'admin_accounts' };
        }
    }
    return { ok: false, role: 'anonymous', source: 'none' };
}

function roleAllows(role, minimumRole) {
    return (ROLE_LEVELS[role] || 0) >= (ROLE_LEVELS[minimumRole] || 0);
}

function getTokenFromRequest(req) {
    const header = req.headers.authorization || '';
    if (header.startsWith('Bearer ')) return header.slice('Bearer '.length).trim();
    return req.body?.adminToken || req.query?.token || '';
}

function requireRole(req, minimumRole) {
    const auth = authenticateAdminToken(getTokenFromRequest(req));
    if (!auth.ok || !roleAllows(auth.role, minimumRole)) {
        const err = new Error(`${minimumRole} role is required`);
        err.status = 403;
        err.code = 'ACCESS_DENIED';
        throw err;
    }
    return auth;
}

function getAdminAudit({ limit = 100 } = {}) {
    const rows = [];
    if (fs.existsSync(ADMIN_AUDIT_FILE)) {
        const lines = fs.readFileSync(ADMIN_AUDIT_FILE, 'utf8').split(/\r?\n/).filter(Boolean);
        for (const line of lines) {
            try { rows.push(JSON.parse(line)); } catch { /* ignore malformed audit rows */ }
        }
    }
    return { Status: 'PASS', Total: rows.length, Events: rows.slice(-Math.max(1, Number(limit) || 100)) };
}

function getManagementProfile() {
    return {
        service: 'windowsdoctor-management',
        mode: 'local-first',
        nas: 'optional',
        broker: {
            baseUrl: `http://${config.host}:${config.port}`,
            bindHost: config.host,
            port: config.port,
        },
        roles: {
            viewer: 'WD_VIEWER_TOKEN',
            operator: 'WD_OPERATOR_TOKEN',
            admin: 'WD_ADMIN_TOKEN',
            maintainer: 'WD_MAINTAINER_TOKEN',
        },
        files: {
            adminAccounts: path.relative(config.rootDir, ADMIN_ACCOUNTS_FILE),
            auditEvents: path.relative(config.rootDir, ADMIN_AUDIT_FILE),
            profile: path.relative(config.rootDir, MANAGEMENT_PROFILE_FILE),
        },
        policies: {
            externalAccessRequiresToken: true,
            runGatedOperationsRequireAdmin: true,
            maintainerOperationsRequireMaintainer: true,
            nasServerRequired: false,
        },
        operationClasses: OPERATION_CLASSES,
    };
}

function writeManagementProfile() {
    const profile = getManagementProfile();
    fs.mkdirSync(path.dirname(MANAGEMENT_PROFILE_FILE), { recursive: true });
    fs.writeFileSync(MANAGEMENT_PROFILE_FILE, JSON.stringify(profile, null, 2), 'utf8');
    return profile;
}

function getManagementStatus() {
    const profile = fs.existsSync(MANAGEMENT_PROFILE_FILE) ? readJson(MANAGEMENT_PROFILE_FILE, getManagementProfile()) : getManagementProfile();
    return {
        Status: 'PASS',
        Mode: 'local-management',
        TokenEnvironmentConfigured: Boolean(process.env.WD_VIEWER_TOKEN || process.env.WD_OPERATOR_TOKEN || process.env.WD_ADMIN_TOKEN || process.env.WD_MAINTAINER_TOKEN),
        AdminAccountCount: loadAdminAccounts().length,
        AuditEventCount: getAdminAudit({ limit: 1 }).Total,
        OperationClasses: OPERATION_CLASSES,
        Profile: profile,
        SafetyPolicy: {
            NasRequired: false,
            ExternalAccessRequiresToken: true,
            RunGatedOperationsRequireAdmin: true,
            NoRepairExecuted: true,
        },
    };
}

module.exports = {
    ROLE_LEVELS,
    OPERATION_CLASSES,
    hashToken,
    verifyTokenHash,
    loadAdminAccounts,
    listAdminAccounts,
    createAdminAccount,
    setAdminDisabled,
    authenticateAdminToken,
    roleAllows,
    requireRole,
    recordAdminAudit,
    getAdminAudit,
    getManagementProfile,
    writeManagementProfile,
    getManagementStatus,
};
