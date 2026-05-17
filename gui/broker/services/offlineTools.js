/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');
const config = require('../config');

const PACKAGE_PREFIX = 'windowsdoctor-offline-microsoft-diagnostics-';

const TOOL_FILE_BY_ID = {
    setupdiag: 'SetupDiag.exe',
    'process-explorer': 'ProcessExplorer.zip',
    'process-monitor': 'ProcessMonitor.zip',
    autoruns: 'Autoruns.zip',
    handle: 'Handle.zip',
    tcpview: 'TCPView.zip',
    rammap: 'RAMMap.zip',
    sigcheck: 'Sigcheck.zip',
};

const COMPONENT_TOOL_MAP = {
    printer: [
        { id: 'process-monitor', reason: '收集列印佇列、spooler、驅動存取失敗的檔案與登錄活動' },
        { id: 'handle', reason: '找出鎖定列印檔或驅動檔案的程序' },
    ],
    windows_update: [
        { id: 'setupdiag', reason: '分析 Windows 更新或升級失敗記錄' },
        { id: 'process-monitor', reason: '必要時追蹤更新元件存取失敗' },
    ],
    network: [
        { id: 'tcpview', reason: '檢視本機連線、遠端端點與可疑連線狀態' },
        { id: 'process-explorer', reason: '確認高網路活動程序與父子程序關係' },
    ],
    boot: [
        { id: 'sigcheck', reason: '檢查可疑開機相關檔案簽章與版本' },
        { id: 'autoruns', reason: '檢視啟動項與持久化項目，不自動停用' },
    ],
    performance: [
        { id: 'rammap', reason: '分析記憶體使用與檔案快取壓力' },
        { id: 'process-explorer', reason: '定位高 CPU 或高記憶體程序' },
    ],
    hardware: [
        { id: 'sigcheck', reason: '檢查驅動或可執行檔簽章與版本' },
        { id: 'process-explorer', reason: '檢視驅動相關服務程序狀態' },
    ],
    system_integrity: [
        { id: 'sigcheck', reason: '檢查系統檔案簽章與版本線索' },
        { id: 'process-monitor', reason: '必要時追蹤檔案或登錄存取失敗' },
    ],
    general: [
        { id: 'process-explorer', reason: '建立程序層級初步診斷線索' },
        { id: 'sigcheck', reason: '檢查可疑檔案簽章與版本' },
    ],
};

const SAFE_CLI_TOOL_MAP = {
    printer: ['handle', 'autoruns', 'sigcheck'],
    windows_update: ['setupdiag', 'sigcheck'],
    network: ['tcpview', 'handle'],
    boot: ['autoruns', 'sigcheck'],
    performance: ['handle', 'tcpview', 'sigcheck'],
    hardware: ['sigcheck', 'autoruns'],
    system_integrity: ['sigcheck', 'handle'],
    general: ['setupdiag', 'sigcheck', 'tcpview', 'handle', 'autoruns'],
};

function readJson(filePath) {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function getLatestOfflineToolPackage() {
    const repairToolsRoot = path.join(config.rootDir, 'releases', 'repair-tools');
    if (!fs.existsSync(repairToolsRoot)) return null;
    const candidates = fs.readdirSync(repairToolsRoot, { withFileTypes: true })
        .filter((entry) => entry.isDirectory() && entry.name.startsWith(PACKAGE_PREFIX))
        .map((entry) => {
            const fullPath = path.join(repairToolsRoot, entry.name);
            const stat = fs.statSync(fullPath);
            return { fullPath, name: entry.name, mtimeMs: stat.mtimeMs };
        })
        .sort((a, b) => b.mtimeMs - a.mtimeMs);
    return candidates[0] || null;
}

function getToolPackageStatus() {
    const latest = getLatestOfflineToolPackage();
    if (!latest) {
        return {
            Status: 'WAITING',
            Mode: 'offline-tool-package-catalog',
            PackageRoot: null,
            ToolCount: 0,
            Tools: [],
            SafetyPolicy: {
                NoToolExecuted: true,
                AutoRunAllowed: false,
                RunGateRequired: true,
                MicrosoftOfficialOnly: true,
            },
        };
    }

    const manifestPath = path.join(latest.fullPath, 'repair-tool-package-manifest.json');
    if (!fs.existsSync(manifestPath)) {
        return {
            Status: 'WARN',
            Mode: 'offline-tool-package-catalog',
            PackageRoot: latest.fullPath,
            ToolCount: 0,
            Tools: [],
            Warning: 'repair-tool-package-manifest.json not found',
            SafetyPolicy: {
                NoToolExecuted: true,
                AutoRunAllowed: false,
                RunGateRequired: true,
                MicrosoftOfficialOnly: true,
            },
        };
    }

    const manifest = readJson(manifestPath);
    const tools = (manifest.tools || []).map((tool) => {
        const fileName = TOOL_FILE_BY_ID[tool.id] || '';
        const packageRelativePath = fileName ? path.join('tools', tool.id, fileName) : '';
        const packagePath = packageRelativePath ? path.join(latest.fullPath, packageRelativePath) : '';
        return {
            id: tool.id,
            name: tool.name,
            publisher: tool.publisher,
            allowedUse: tool.allowedUse,
            executionPolicy: tool.executionPolicy,
            autoRunAllowed: !!tool.autoRunAllowed,
            sourceTrustLevel: tool.sourceTrustLevel,
            expectedSha256: tool.expectedSha256,
            packageRelativePath,
            available: !!packagePath && fs.existsSync(packagePath),
            commandPreview: buildCommandPreview(tool.id, packagePath),
        };
    });

    return {
        Status: tools.every((tool) => tool.available && !tool.autoRunAllowed) ? 'PASS' : 'WARN',
        Mode: 'offline-tool-package-catalog',
        PackageRoot: latest.fullPath,
        ManifestPath: manifestPath,
        ToolCount: tools.length,
        Tools: tools,
        SafetyPolicy: {
            NoToolExecuted: true,
            AutoRunAllowed: false,
            RunGateRequired: true,
            MicrosoftOfficialOnly: tools.every((tool) => tool.sourceTrustLevel === 'microsoft_official'),
        },
    };
}

function buildCommandPreview(toolId, packagePath) {
    if (!packagePath) return '';
    if (toolId === 'setupdiag') {
        return `"${packagePath}" /Output:"%LOCALAPPDATA%\\WindowsDoctor\\SetupDiag\\SetupDiagResults.log"`;
    }
    if (packagePath.toLowerCase().endsWith('.zip')) {
        return `Expand-Archive -LiteralPath "${packagePath}" -DestinationPath "%LOCALAPPDATA%\\WindowsDoctor\\Tools\\${toolId}" -Force`;
    }
    return `"${packagePath}"`;
}

function selectToolsForComponent(component) {
    const status = getToolPackageStatus();
    const candidates = COMPONENT_TOOL_MAP[component] || COMPONENT_TOOL_MAP.general;
    const selected = candidates.map((candidate) => {
        const tool = status.Tools.find((item) => item.id === candidate.id);
        return {
            ...candidate,
            tool: tool || null,
            status: tool && tool.available ? 'ready' : 'missing',
        };
    });

    return {
        Status: status.Status === 'PASS' && selected.every((item) => item.status === 'ready') ? 'PASS' : 'WAITING',
        Mode: 'offline-tool-auto-selection-preview',
        Component: component || 'general',
        PackageRoot: status.PackageRoot,
        SelectedTools: selected,
        ExecutionModel: 'sequential-preview-only',
        NextAction: '介面可自動選用工具並顯示用途與命令預覽；實際執行仍需 RUN gate 與診斷專用執行器。',
        SafetyPolicy: {
            NoToolExecuted: true,
            NoInstall: true,
            NoRepairAllowlistChange: true,
            AutoRunAllowed: false,
            RunGateRequired: true,
        },
    };
}

function getSafeCliToolIdsForComponent(component) {
    const ids = SAFE_CLI_TOOL_MAP[component] || SAFE_CLI_TOOL_MAP.general;
    return [...ids];
}

module.exports = {
    getToolPackageStatus,
    selectToolsForComponent,
    getSafeCliToolIdsForComponent,
};
