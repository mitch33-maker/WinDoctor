/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const config = require('../config');
const { getMachineUUID } = require('./system');

const VAULT_KEY = crypto.createHash('sha256').update(getMachineUUID()).digest();

function encrypt(text) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-gcm', VAULT_KEY, iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');
    return `${iv.toString('hex')}:${encrypted}:${authTag}`;
}

function saveCredential(username, password) {
    if (!fs.existsSync(path.dirname(config.vaultFile))) fs.mkdirSync(path.dirname(config.vaultFile), { recursive: true });
    const encData = encrypt(JSON.stringify({ username, password }));
    fs.writeFileSync(config.vaultFile, encData, 'utf8');
}

function getLockStatus() {
    const sig = Buffer.from(getMachineUUID()).toString('base64');
    const lockedSig = fs.existsSync(config.lockFile) ? fs.readFileSync(config.lockFile, 'utf8').trim() : '';
    const isLocked = lockedSig === sig;
    return { match: lockedSig ? isLocked : true, signature: sig };
}

function bindLock() {
    if (!fs.existsSync(path.dirname(config.lockFile))) fs.mkdirSync(path.dirname(config.lockFile), { recursive: true });
    fs.writeFileSync(config.lockFile, Buffer.from(getMachineUUID()).toString('base64'), 'utf8');
}

module.exports = { saveCredential, getLockStatus, bindLock };
