/* eslint-disable @typescript-eslint/no-require-imports */
const { exec, execSync } = require('child_process');
const os = require('os');

function getMachineUUID() {
    try {
        const output = execSync('wmic csproduct get uuid', { encoding: 'utf8' });
        const lines = output.split('\n').map(l => l.trim()).filter(Boolean);
        return lines.length > 1 ? lines[1] : 'UNKNOWN-UUID';
    } catch {
        return 'UNKNOWN-UUID';
    }
}

function testAdmin() {
    return new Promise((resolve) => {
        exec('net session', (err) => resolve(!err));
    });
}

async function getHealth() {
    const isAdmin = await testAdmin();
    const healthData = {
        Timestamp: new Date().toISOString().replace('T', ' ').substring(0, 19),
        OS: `${os.type()} ${os.release()}`,
        Version: os.release(),
        RAM_Total_GB: parseFloat((os.totalmem() / 1024 ** 3).toFixed(2)),
        Disks: [],
        IsAdmin: isAdmin
    };

    try {
        const diskOut = execSync('wmic logicaldisk get caption,freespace,size /format:csv', { encoding: 'utf8' })
            .trim()
            .split('\n')
            .filter(l => l.length > 0 && !l.includes('Node'));
        for (const line of diskOut) {
            const parts = line.trim().split(',');
            if (parts.length >= 3 && parts[1]) {
                const drive = parts[1];
                const freespace = parseFloat((parseInt(parts[2], 10) / 1024 ** 3).toFixed(2));
                healthData.Disks.push({ Drive: drive, FreeSpaceGB: freespace || 0, Health: 'Healthy' });
            }
        }
    } catch (err) {
        console.error('Disk parse error:', err);
    }

    return healthData;
}

function getRecentSystemEvents() {
    const wevtCmd = 'wevtutil qe System /c:5 /rd:true /f:text /q:"*[System[(Level=1 or Level=2 or Level=3)]]"';
    const logData = execSync(wevtCmd, { encoding: 'utf8' });
    const foundEvents = [];
    const lines = logData.split('\n');
    let currentEvent = { Source: 'System Log', Message: '' };
    const benignSignatures = ['Microsoft-Windows-DistributedCOM', '10016', '1008'];

    for (const line of lines) {
        if (line.includes('Event[') || line.includes('事件[')) {
            if (currentEvent.Message && currentEvent.Message.length > 10) {
                const isBenign = benignSignatures.some(sig => currentEvent.Message.includes(sig));
                if (!isBenign) foundEvents.push(currentEvent);
            }
            currentEvent = { Source: 'System Log', Message: '' };
        } else if (line.trim().length > 0) {
            currentEvent.Message += line.trim() + ' ';
        }
    }

    if (currentEvent.Message && currentEvent.Message.length > 10) {
        const isBenign = benignSignatures.some(sig => currentEvent.Message.includes(sig));
        if (!isBenign) foundEvents.push(currentEvent);
    }

    return foundEvents;
}

module.exports = { getMachineUUID, testAdmin, getHealth, getRecentSystemEvents };
