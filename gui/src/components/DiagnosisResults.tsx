import type { Finding, ScanError } from "@/types/windows-doctor";

type DiagnosisResultsProps = {
  findings: Finding[];
  scanning: boolean;
  error: ScanError | null;
  onLearn: (errorCode: string) => void;
  onRepair: (scriptName: string) => void;
  onRetry: () => void;
};

function getActionMeta(finding: Finding) {
  const action = finding.ActionType || (finding.SuggestedFix === "N/A" || finding.SuggestedFix === "無可用修復指令碼" ? "guided" : "auto_repair");
  if (action === "auto_repair") return { label: "可自動修復", className: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30" };
  if (action === "manual_review") return { label: "需人工確認", className: "bg-amber-500/15 text-amber-300 border-amber-500/30" };
  if (action === "learn") return { label: "待建立規則", className: "bg-blue-500/15 text-blue-300 border-blue-500/30" };
  return { label: "引導修復", className: "bg-sky-500/15 text-sky-300 border-sky-500/30" };
}

export function DiagnosisResults({ findings, scanning, error, onLearn, onRepair, onRetry }: DiagnosisResultsProps) {
  return (
    <div className="lg:col-span-2">
      <div className="p-8 rounded-3xl bg-white/5 border border-white/10 min-h-[500px] backdrop-blur-2xl relative overflow-hidden">
        {scanning && <div className="absolute top-0 left-0 w-full h-[2px] bg-blue-500 shadow-[0_0_15px_#3b82f6] animate-scanline z-10" />}
        <h2 className="text-2xl font-bold mb-8 flex items-center gap-3">故障研判與 RAG 指引</h2>
        {error ? (
          <div className="flex flex-col items-center justify-center min-h-[300px] text-center">
            <div className="p-6 border border-red-500/30 bg-red-500/10 rounded-2xl max-w-md">
              <p className="text-red-300 font-bold mb-2">診斷資料讀取失敗</p>
              <p className="text-sm text-gray-300 mb-4">{error.message}</p>
              <button onClick={onRetry} className="px-6 py-3 bg-red-500 text-white rounded-xl font-bold hover:bg-red-400 transition-all">
                重新嘗試
              </button>
            </div>
          </div>
        ) : findings.length > 0 ? (
          <div className="space-y-4">
            {findings.map((f, i) => (
              <div key={`${f.MatchedRule}-${i}`} className="p-6 rounded-2xl bg-red-500/10 border border-red-500/30 animate-in fade-in slide-in-from-bottom-4 duration-500">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <h3 className="text-xl font-bold text-red-400">⚠ {f.EventID !== "Unknown" ? f.MatchedRule : "系統異常"}</h3>
                    <p className="text-white mt-1 text-sm font-medium">{f.Description}</p>
                  </div>
                  <span className={`px-3 py-1 text-xs rounded-full border ${getActionMeta(f).className}`}>{getActionMeta(f).label}</span>
                </div>
                <div className="p-4 bg-black/40 rounded-xl mb-6 border border-white/5 shadow-inner">
                  <p className="text-blue-400 text-xs font-mono mb-2">RAG 智慧修復指引：</p>
                  <p className="text-white font-bold text-base leading-relaxed tracking-wide">{f.Diagnosis}</p>
                </div>
                {f.ActionType === "auto_repair" || (f.SuggestedFix !== "N/A" && f.SuggestedFix !== "無可用修復指令碼" && f.ActionType !== "manual_review") ? (
                  <button
                    onClick={() => onRepair(f.SuggestedFix)}
                    className="px-8 py-3 bg-white text-black font-extrabold rounded-xl hover:bg-gray-200 transition-all hover:scale-[1.02]"
                  >
                    一鍵執行原子修復
                  </button>
                ) : f.ActionType === "manual_review" ? (
                  <div className="px-5 py-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-100 text-sm">
                    此項目需要人工確認，系統不會自動執行修復腳本。
                  </div>
                ) : (
                  <button
                    onClick={() => onLearn(f.EventID !== "Unknown" ? f.EventID : "特殊系統錯誤")}
                    className="px-8 py-3 bg-blue-600 text-white font-extrabold rounded-xl hover:bg-blue-500 hover:shadow-[0_0_20px_rgba(37,99,235,0.6)] transition-all animate-pulse"
                  >
                    🚀 啟動 AI 聯網搜尋並自我進化
                  </button>
                )}
              </div>
            ))}
          </div>
        ) : scanning ? (
          <div className="flex flex-col items-center justify-center h-[300px] text-gray-500 text-center">
            <div className="text-6xl mb-4 animate-pulse">🔎</div>
            <p>深度研判中，正跨越 RAG 知識庫進行比對...</p>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center min-h-[300px] text-gray-400">
            <div className="p-8 border-2 border-dashed border-white/10 rounded-3xl text-center max-w-sm">
              <p className="mb-6 italic">目前知識庫尚未內建此特定故障的解決方案。</p>
              <button
                onClick={() => onLearn("0x80244018")}
                className="px-6 py-3 bg-blue-600 rounded-xl text-white font-bold hover:bg-blue-500 shadow-lg shadow-blue-900/50"
              >
                🚀 啟動 AI 自我學習進化
              </button>
              <p className="mt-4 text-xs text-gray-500">(將自動搜尋網路解決方案並生成 RAG 文件)</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
