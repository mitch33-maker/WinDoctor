import type { HealthData } from "@/types/windows-doctor";

type SystemMonitorProps = {
  health: HealthData | null;
  scanning: boolean;
  onScan: () => void;
  onRequestElevation: () => void;
};

export function SystemMonitor({ health, scanning, onScan, onRequestElevation }: SystemMonitorProps) {
  return (
    <div className="lg:col-span-1 space-y-6">
      <div className="p-6 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl hover:border-blue-500/50 transition-all group">
        <h2 className="text-xl font-bold mb-4 flex items-center gap-2 text-blue-400">
          <span className="group-hover:animate-pulse">●</span> 系統監控 (PC 本機端)
        </h2>
        {health ? (
          <div className="space-y-4 text-sm">
            <div className="flex justify-between border-b border-white/5 pb-2">
              <span className="text-gray-400">作業系統</span>
              <span className="font-mono text-xs">{health.OS}</span>
            </div>
            <div className="flex justify-between border-b border-white/5 pb-2">
              <span className="text-gray-400">記憶體</span>
              <span>{health.RAM_Total_GB} GB</span>
            </div>
            <div className="flex justify-between border-b border-white/5 pb-2">
              <span className="text-gray-400">磁碟狀態</span>
              <span className="text-green-500 font-bold">HEALTHY</span>
            </div>
            <div className={`mt-4 p-2 rounded text-center text-xs font-bold ${health.IsAdmin ? "bg-green-500/10 text-green-500 border border-green-500/20" : "bg-red-500/10 text-red-500 border border-red-500/20"}`}>
              {health.IsAdmin ? "√ 已取得管理員權限 (Elevated)" : (
                <div className="flex flex-col gap-2">
                  <span>⚠ 權限不足：無法執行修復功能</span>
                  <button onClick={onRequestElevation} className="bg-red-500 text-white px-2 py-1 rounded hover:bg-red-600 transition-colors">
                    點擊此處發起提權請求
                  </button>
                </div>
              )}
            </div>
          </div>
        ) : (
          <p className="text-gray-500 italic text-sm">尚未與本機 Broker (Port 3001) 連線...</p>
        )}
      </div>
      <button
        id="scan-btn"
        onClick={onScan}
        disabled={scanning}
        className="w-full py-4 rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 font-bold text-lg hover:shadow-[0_0_30px_rgba(37,99,235,0.6)] active:scale-[0.98] transition-all flex items-center justify-center gap-3"
      >
        {scanning ? "正在掃描與研判..." : "🚀 開始全方位診斷"}
      </button>
    </div>
  );
}
