/* eslint-disable @typescript-eslint/no-require-imports */
const path = require('path');
const { spawn } = require('child_process');
const config = require('../config');

function asPositiveInt(value, fallback, max) {
    const parsed = Number.parseInt(value, 10);
    if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
    return Math.min(parsed, max);
}

function analyzeEventLogs(options = {}) {
    return new Promise((resolve, reject) => {
        const recentHours = asPositiveInt(options.recentHours, 24, 168);
        const maxEvents = asPositiveInt(options.maxEvents, 120, 500);
        const top = asPositiveInt(options.top, 10, 50);
        const logs = Array.isArray(options.logName) && options.logName.length > 0
            ? options.logName
            : ['System', 'Application'];
        const reportPath = options.reportPath || path.join(config.rootDir, 'logs', 'windows-event-log-analysis.latest.json');
        const csvPath = options.csvPath || path.join(config.rootDir, 'logs', 'windows-event-log-analysis.latest.csv');
        const args = [
            '-NoProfile',
            '-ExecutionPolicy',
            'RemoteSigned',
            '-File',
            path.join(config.scriptsDir, 'Analyze-WindowsEventLogs.ps1'),
            '-Root',
            config.rootDir,
            '-RecentHours',
            String(recentHours),
            '-MaxEvents',
            String(maxEvents),
            '-Top',
            String(top),
            '-ReportPath',
            reportPath,
            '-CsvPath',
            csvPath,
            '-Json',
        ];
        args.push('-LogName', ...logs.slice(0, 6).map((log) => String(log)));

        const child = spawn('powershell', args, {
            cwd: config.rootDir,
            windowsHide: true,
            shell: false,
        });
        let stdout = '';
        let stderr = '';
        child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
        child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });
        child.on('close', (code) => {
            if (code !== 0) return reject(new Error(stderr || `Analyze-WindowsEventLogs exited with ${code}`));
            try { resolve(JSON.parse(stdout)); }
            catch (err) { reject(new Error(`Invalid event log analysis JSON: ${err.message}`)); }
        });
        child.on('error', reject);
    });
}

module.exports = { analyzeEventLogs };
