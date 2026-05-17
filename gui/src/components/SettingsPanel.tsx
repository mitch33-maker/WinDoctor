import { useState } from "react";
import type { AdminAccount, AdminAudit, AdminStatus, AppStatus, LockStatus, RuleIndexItem, VisionStatus } from "@/types/windows-doctor";
import { windowsDoctorApi } from "@/lib/windowsDoctorApi";
import { RuleIndexPanel } from "./RuleIndexPanel";

type SettingsPanelProps = {
  lockStatus: LockStatus;
  rules: RuleIndexItem[];
  allowlist: string[];
  visionStatus: VisionStatus | null;
  onCheckEnvironment: () => Promise<void>;
  onRefreshSystemIndex: () => void;
  onStatus: (status: AppStatus) => void;
};

export function SettingsPanel({ lockStatus, rules, allowlist, visionStatus, onCheckEnvironment, onRefreshSystemIndex, onStatus }: SettingsPanelProps) {
  const [adminUser, setAdminUser] = useState("");
  const [adminPass, setAdminPass] = useState("");
  const [kbPath, setKbPath] = useState("e:\\WindowsDoctor\\knowledge_base");
  const [adminToken, setAdminToken] = useState("");
  const [newAdminId, setNewAdminId] = useState("");
  const [newAdminDisplayName, setNewAdminDisplayName] = useState("");
  const [newAdminRole, setNewAdminRole] = useState("viewer");
  const [newAdminToken, setNewAdminToken] = useState("");
  const [managementStatus, setManagementStatus] = useState<AdminStatus | null>(null);
  const [adminAccounts, setAdminAccounts] = useState<AdminAccount[]>([]);
  const [adminAudit, setAdminAudit] = useState<AdminAudit | null>(null);

  return (
    <div className="max-w-6xl mx-auto mt-12 p-8 rounded-3xl bg-white/5 border border-white/10">
      <h2 className="text-xl font-bold mb-6 flex items-center gap-2">🔐 安全憑證保險箱 (Credential Vault)</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <input value={adminUser} onChange={(e) => setAdminUser(e.target.value)} placeholder="管理員帳號 (例如: .\Administrator)" className="bg-black/50 border border-white/10 rounded-xl px-4 py-3 text-sm focus:border-blue-500 outline-none" />
        <input value={adminPass} onChange={(e) => setAdminPass(e.target.value)} type="password" placeholder="管理者密碼" className="bg-black/50 border border-white/10 rounded-xl px-4 py-3 text-sm focus:border-blue-500 outline-none" />
        <button
          onClick={async () => {
            await windowsDoctorApi.saveCredential(adminUser, adminPass);
            onStatus({ tone: "success", message: "憑證已使用 AES-GCM 加密儲存。" });
          }}
          className="bg-blue-600 hover:bg-blue-500 py-3 rounded-xl font-bold transition-all"
        >
          儲存加密憑證
        </button>
      </div>
      <div className="mt-8 pt-6 border-t border-white/5">
        <h3 className="text-sm font-bold text-gray-400 mb-4 flex items-center gap-2">🛡️ 管理系統</h3>
        <div className="bg-black/30 p-4 rounded-2xl border border-white/5 space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
            <input value={adminToken} onChange={(e) => setAdminToken(e.target.value)} type="password" placeholder="管理 token" className="bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-blue-100 focus:outline-none focus:border-blue-500" />
            <button
              onClick={async () => {
                const status = await windowsDoctorApi.getAdminStatus();
                setManagementStatus(status);
                onStatus({ tone: "info", message: "管理系統狀態已更新。" });
              }}
              className="px-4 py-2 bg-blue-500/20 hover:bg-blue-500/40 text-blue-300 rounded-xl text-xs font-bold border border-blue-500/20"
            >
              讀取管理狀態
            </button>
            <button
              onClick={async () => {
                const result = await windowsDoctorApi.getAdminAccounts(adminToken);
                setAdminAccounts(result.Admins || []);
                onStatus({ tone: "success", message: "管理員清單已更新。" });
              }}
              className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-xl text-xs font-bold border border-white/10"
            >
              管理員清單
            </button>
            <button
              onClick={async () => {
                const result = await windowsDoctorApi.getAdminAudit(adminToken);
                setAdminAudit(result);
                onStatus({ tone: "success", message: "操作稽核已更新。" });
              }}
              className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-xl text-xs font-bold border border-white/10"
            >
              操作稽核
            </button>
          </div>
          {managementStatus && (
            <div className="grid grid-cols-1 md:grid-cols-4 gap-3 text-xs">
              <div className="rounded-xl bg-white/5 p-3 border border-white/10">
                <p className="text-gray-500">模式</p>
                <p className="font-bold text-white">{managementStatus.Mode}</p>
              </div>
              <div className="rounded-xl bg-white/5 p-3 border border-white/10">
                <p className="text-gray-500">管理員</p>
                <p className="font-bold text-white">{managementStatus.AdminAccountCount}</p>
              </div>
              <div className="rounded-xl bg-white/5 p-3 border border-white/10">
                <p className="text-gray-500">稽核事件</p>
                <p className="font-bold text-white">{managementStatus.AuditEventCount}</p>
              </div>
              <div className="rounded-xl bg-white/5 p-3 border border-white/10">
                <p className="text-gray-500">NAS</p>
                <p className="font-bold text-white">{managementStatus.SafetyPolicy.NasRequired ? "必要" : "選用"}</p>
              </div>
            </div>
          )}
          <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
            <input value={newAdminId} onChange={(e) => setNewAdminId(e.target.value)} placeholder="admin id" className="bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-blue-100 focus:outline-none focus:border-blue-500" />
            <input value={newAdminDisplayName} onChange={(e) => setNewAdminDisplayName(e.target.value)} placeholder="顯示名稱" className="bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-blue-100 focus:outline-none focus:border-blue-500" />
            <select value={newAdminRole} onChange={(e) => setNewAdminRole(e.target.value)} className="bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-blue-100 focus:outline-none focus:border-blue-500">
              <option value="viewer">viewer</option>
              <option value="operator">operator</option>
              <option value="admin">admin</option>
              <option value="maintainer">maintainer</option>
            </select>
            <input value={newAdminToken} onChange={(e) => setNewAdminToken(e.target.value)} type="password" placeholder="新 token" className="bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-blue-100 focus:outline-none focus:border-blue-500" />
            <button
              onClick={async () => {
                await windowsDoctorApi.createAdminAccount(adminToken, { adminId: newAdminId, displayName: newAdminDisplayName, role: newAdminRole, token: newAdminToken });
                setNewAdminToken("");
                const result = await windowsDoctorApi.getAdminAccounts(adminToken);
                setAdminAccounts(result.Admins || []);
                onStatus({ tone: "success", message: "建立管理員完成，明文 token 未保存。" });
              }}
              className="px-4 py-2 bg-amber-500/20 hover:bg-amber-500/40 text-amber-300 rounded-xl text-xs font-bold border border-amber-500/20"
            >
              建立管理員
            </button>
          </div>
          {adminAccounts.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
              {adminAccounts.map((item) => (
                <div key={item.adminId} className="rounded-xl bg-white/5 border border-white/10 p-3 text-xs flex items-center justify-between">
                  <div>
                    <p className="font-bold text-white">{item.displayName || item.adminId}</p>
                    <p className="text-gray-500">{item.adminId} · {item.role} · {item.disabled ? "disabled" : "active"}</p>
                  </div>
                  <button
                    onClick={async () => {
                      await windowsDoctorApi.setAdminDisabled(adminToken, { adminId: item.adminId, disabled: !item.disabled, reason: "GUI management" });
                      const result = await windowsDoctorApi.getAdminAccounts(adminToken);
                      setAdminAccounts(result.Admins || []);
                    }}
                    className="px-3 py-1 rounded-lg bg-white/10 hover:bg-white/20 text-white"
                  >
                    {item.disabled ? "啟用" : "停用"}
                  </button>
                </div>
              ))}
            </div>
          )}
          {adminAudit && (
            <div className="rounded-xl bg-white/5 border border-white/10 p-3 text-xs max-h-48 overflow-auto">
              {adminAudit.Events.slice(-8).map((event, index) => (
                <div key={`${event.createdAt}-${index}`} className="py-1 border-b border-white/5">
                  <span className="text-gray-500">{event.createdAt}</span> <span className="text-blue-300">{event.actor}</span> <span className="text-white">{event.action}</span>
                </div>
              ))}
            </div>
          )}
          <p className="text-[10px] text-gray-600 italic">* 管理系統採 local-first；NAS 為選用集中儲存，不是必要伺服器。</p>
        </div>
      </div>
      <div className="mt-8 pt-6 border-t border-white/5">
        <h3 className="text-sm font-bold text-gray-400 mb-4 flex items-center gap-2">🌐 網路環境特徵鎖定 (Network Lock)</h3>
        <div className="flex items-center justify-between bg-black/30 p-4 rounded-2xl border border-white/5">
          <div className="text-xs">
            <p className="text-gray-500 mb-1">當前環境簽章</p>
            <code className="text-blue-500">{lockStatus.signature || "讀取中..."}</code>
          </div>
          <button
            onClick={async () => {
              await windowsDoctorApi.bindLock();
              onStatus({ tone: "success", message: "環境綁定成功。" });
              await onCheckEnvironment();
            }}
            className="px-6 py-2 bg-white/10 hover:bg-white/20 rounded-full text-xs font-bold transition-all border border-white/10"
          >
            🔒 綁定當前環境
          </button>
        </div>
        {!lockStatus.match && (
          <div className="mt-4 p-3 bg-red-500/20 border border-red-500/50 rounded-xl text-red-500 text-xs font-bold animate-pulse text-center">
            偵測到非法遷移：請使用上方帳密儲存功能驗證身分並重新綁定。
          </div>
        )}
      </div>
      <div className="mt-8 pt-6 border-t border-white/5">
        <h3 className="text-sm font-bold text-gray-400 mb-4 flex items-center gap-2">📂 企業級 NAS 知識庫 (Shared RAG)</h3>
        <div className="bg-black/30 p-4 rounded-2xl border border-white/5 space-y-4">
          <div>
            <p className="text-xs text-gray-500 mb-2">配置共享路徑 (例如: \\NAS\WindowsDoctor\KB)</p>
            <input type="text" value={kbPath} onChange={(e) => setKbPath(e.target.value)} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-blue-400 focus:outline-none focus:border-blue-500 transition-all" />
          </div>
          <div className="flex gap-3">
            <button
              onClick={async () => {
                await windowsDoctorApi.setKbPath(kbPath);
                onStatus({ tone: "success", message: "知識庫路徑已更新。" });
              }}
              className="flex-1 px-4 py-2 bg-blue-500/20 hover:bg-blue-500/40 text-blue-400 rounded-xl text-xs font-bold transition-all border border-blue-500/20"
            >
              🔄 套用路徑
            </button>
            <button
              onClick={async () => {
                await windowsDoctorApi.syncNas();
                onStatus({ tone: "info", message: "NAS 同步已觸發。" });
              }}
              className="flex-1 px-4 py-2 bg-green-500/20 hover:bg-green-500/40 text-green-400 rounded-xl text-xs font-bold transition-all border border-green-500/20"
            >
              ☁️ 同步 NAS
            </button>
          </div>
          <p className="text-[10px] text-gray-600 italic">* 建議將知識庫放置於 NAS，以便技術團隊共享故障修復經驗。</p>
        </div>
      </div>
      <RuleIndexPanel rules={rules} allowlist={allowlist} visionStatus={visionStatus} onRefresh={onRefreshSystemIndex} />
    </div>
  );
}
