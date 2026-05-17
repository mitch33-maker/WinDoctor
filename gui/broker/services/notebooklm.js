/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const config = require('../config');

function ensureLogDir() {
    const logDir = path.join(config.rootDir, 'logs');
    if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
    return logDir;
}

function runPowerShell(script, args) {
    return new Promise((resolve, reject) => {
        const child = spawn('powershell', [
            '-NonInteractive',
            '-NoProfile',
            '-InputFormat',
            'None',
            '-ExecutionPolicy',
            'RemoteSigned',
            '-File',
            script,
            ...args,
            '-Json'
        ], {
            cwd: config.rootDir,
            shell: false,
            windowsHide: true,
        });
        const timeout = setTimeout(() => {
            child.kill('SIGKILL');
            reject(new Error(`${path.basename(script)} timed out`));
        }, 120000);

        let stdout = '';
        let stderr = '';
        child.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
        child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
        child.on('error', reject);
        child.on('close', (code) => {
            clearTimeout(timeout);
            if (code !== 0) {
                reject(new Error((stderr || stdout || `PowerShell failed with exit code ${code}`).trim()));
                return;
            }
            try {
                resolve(JSON.parse(stdout.trim()));
            } catch {
                reject(new Error(`Invalid JSON output from ${path.basename(script)}: ${stdout.trim()}`));
            }
        });
    });
}

async function importNotebookLmSourcePack(sourcePack) {
    if (!sourcePack || typeof sourcePack !== 'object' || Array.isArray(sourcePack)) {
        const error = new Error('sourcePack object is required');
        error.status = 400;
        throw error;
    }

    const logDir = ensureLogDir();
    const inputPath = path.join(logDir, 'notebooklm-gui-source-pack.json');
    const validateReport = path.join(logDir, 'notebooklm-source-pack-validate.latest.json');
    const importReport = path.join(logDir, 'notebooklm-import.latest.json');
    const exportReport = path.join(logDir, 'normalized-kb-export.latest.json');
    const validationReport = path.join(logDir, 'normalized-kb-validate.latest.json');

    fs.writeFileSync(inputPath, JSON.stringify(sourcePack, null, 2), 'utf8');

    const sourcePackValidation = await runPowerShell(
        path.join(config.scriptsDir, 'Test-NotebookLMSourcePack.ps1'),
        ['-InputPath', inputPath, '-ReportPath', validateReport]
    );
    const importResult = await runPowerShell(
        path.join(config.scriptsDir, 'Import-NotebookLMSourcePack.ps1'),
        ['-Root', config.rootDir, '-InputPath', inputPath, '-ReportPath', importReport]
    );
    const exportResult = await runPowerShell(
        path.join(config.scriptsDir, 'Export-NormalizedKBDatabase.ps1'),
        ['-Root', config.rootDir, '-ReportPath', exportReport]
    );
    const normalizedValidation = await runPowerShell(
        path.join(config.scriptsDir, 'Test-NormalizedKBDatabase.ps1'),
        ['-Root', config.rootDir, '-ReportPath', validationReport]
    );

    return {
        status: 'success',
        inputPath,
        reports: {
            validateReport,
            importReport,
            exportReport,
            validationReport,
        },
        sourcePackValidation,
        importResult,
        exportResult,
        normalizedValidation,
    };
}

module.exports = { importNotebookLmSourcePack };
