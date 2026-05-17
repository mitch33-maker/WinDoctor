/* eslint-disable @typescript-eslint/no-require-imports */
const path = require('path');
const { spawn } = require('child_process');
const config = require('../config');

function invokeRecommendedRepairPlan({ execute = false, confirmToken = '' } = {}) {
    return new Promise((resolve, reject) => {
        const scriptPath = path.join(config.scriptsDir, 'Invoke-RecommendedRepairPlan.ps1');
        const reportPath = path.join(config.rootDir, 'logs', execute ? 'gui-recommended-repair-execute.latest.json' : 'gui-recommended-repair-preview.latest.json');
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

        if (execute) {
            args.push('-Execute', '-ConfirmToken', confirmToken);
        }

        const child = spawn('powershell', args, {
            cwd: config.rootDir,
            windowsHide: true,
            shell: false,
        });

        let stdout = '';
        let stderr = '';
        let settled = false;

        const timer = setTimeout(() => {
            settled = true;
            child.kill();
            reject(Object.assign(new Error('Recommended repair plan timed out'), { status: 504, stderr }));
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
            if (code !== 0) {
                reject(Object.assign(new Error(stderr || stdout || `Recommended repair plan exited with code ${code}`), { status: execute && confirmToken !== 'RUN' ? 400 : 500, stderr }));
                return;
            }
            try {
                resolve(JSON.parse(stdout));
            } catch (err) {
                reject(Object.assign(new Error(`Failed to parse recommended repair plan JSON: ${err.message}`), { status: 500, stdout }));
            }
        });
    });
}

module.exports = { invokeRecommendedRepairPlan };
