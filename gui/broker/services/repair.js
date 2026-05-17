/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const config = require('../config');

function getAllowedRepairScripts() {
    try {
        const raw = fs.readFileSync(config.allowlistFile, 'utf8');
        const parsed = JSON.parse(raw);
        return new Set((parsed.scripts || []).filter((name) => typeof name === 'string' && /^Repair-[A-Za-z0-9_.-]+\.bat$/.test(name)));
    } catch {
        return new Set();
    }
}

function isAllowedRepairScript(script) {
    if (!script || typeof script !== 'string') return false;
    const normalized = path.basename(script);
    if (normalized !== script) return false;
    return getAllowedRepairScripts().has(normalized);
}

function runRepairScript(script) {
    return new Promise((resolve, reject) => {
        if (!isAllowedRepairScript(script)) {
            reject(Object.assign(new Error('Script not allowed'), { status: 400 }));
            return;
        }

        const scriptPath = path.join(config.scriptsDir, script);
        if (!fs.existsSync(scriptPath)) {
            reject(Object.assign(new Error('Script not found'), { status: 404 }));
            return;
        }

        const child = spawn('cmd.exe', ['/d', '/s', '/c', scriptPath], {
            cwd: config.scriptsDir,
            windowsHide: false,
            shell: false,
        });
        let stdout = '';
        let stderr = '';
        let settled = false;

        const timer = setTimeout(() => {
            settled = true;
            child.kill();
            reject(Object.assign(new Error('Repair script timed out'), { status: 504, stderr }));
        }, config.repairTimeoutMs);

        child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
        child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });
        child.on('error', (err) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            reject(Object.assign(new Error(err.message), { status: 500, stderr }));
        });
        child.on('close', (code) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            if (code !== 0 && stdout.trim() === '') {
                reject(Object.assign(new Error(stderr || `Repair script exited with code ${code}`), { status: 500, stderr }));
                return;
            }
            resolve(stdout || stderr || `Repair script exited with code ${code}`);
        });
    });
}

module.exports = { getAllowedRepairScripts, isAllowedRepairScript, runRepairScript };
