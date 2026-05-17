import type { ReportResult } from "@/types/windows-doctor";

/* eslint-disable @next/next/no-img-element */

type ReportModalProps = {
  open: boolean;
  reportText: string;
  reportImg: string | null;
  reportResult: ReportResult | null;
  reporting: boolean;
  onClose: () => void;
  onTextChange: (value: string) => void;
  onImageChange: (value: string | null) => void;
  onSubmit: () => void;
};

export function ReportModal({ open, reportText, reportImg, reportResult, reporting, onClose, onTextChange, onImageChange, onSubmit }: ReportModalProps) {
  if (!open) return null;

  return (
    <div id="report-modal" className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-4">
      <div className="bg-neutral-900 border border-orange-500/20 p-8 rounded-3xl max-w-2xl w-full relative shadow-[0_0_60px_rgba(249,115,22,0.15)] animate-in zoom-in-95 duration-200">
        <button onClick={onClose} className="absolute top-4 right-4 text-gray-400 hover:text-white text-2xl">×</button>
        <h2 className="text-2xl font-bold mb-2 text-orange-400 flex items-center gap-2">🩺 回報 Windows 問題</h2>
        <p className="text-gray-500 text-sm mb-6">描述您遇到的問題或上傳截圖，AI 將自動分析並注入知識庫。</p>
        <textarea
          value={reportText}
          onChange={(e) => onTextChange(e.target.value)}
          placeholder="請描述問題...&#10;例如：印表機無法列印，錯誤代碼 0x00000709&#10;或：系統啟動後藍屏，顯示 CRITICAL_PROCESS_DIED"
          rows={5}
          className="w-full bg-black/40 border border-white/10 rounded-2xl p-4 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-orange-500/50 transition-all resize-none mb-4 font-mono"
        />
        <div
          className="w-full aspect-video bg-black/30 border-2 border-dashed border-white/10 rounded-2xl flex flex-col items-center justify-center mb-6 overflow-hidden cursor-pointer hover:border-orange-500/40 transition-all relative"
          onClick={() => (document.getElementById("report-img-input") as HTMLInputElement)?.click()}
        >
          {reportImg ? (
            <img src={reportImg} className="w-full h-full object-cover" alt="Report" />
          ) : (
            <div className="flex flex-col items-center gap-2 pointer-events-none">
              <span className="text-4xl">🖼️</span>
              <p className="text-gray-500 text-sm">點擊上傳截圖 (可選)</p>
              <p className="text-gray-600 text-xs">支援 PNG / JPG / WebP</p>
            </div>
          )}
          <input
            id="report-img-input"
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) {
                const reader = new FileReader();
                reader.onload = (ev) => onImageChange(ev.target?.result as string);
                reader.readAsDataURL(file);
              }
            }}
          />
        </div>
        {reportResult && (
          <div className={`p-4 rounded-xl mb-4 text-sm border ${reportResult.error ? "bg-red-500/10 border-red-500/30 text-red-400" : "bg-green-500/10 border-green-500/30 text-green-300"}`}>
            {reportResult.error ? (
              <p>{reportResult.error}</p>
            ) : (
              <div className="space-y-2">
                <p className="font-bold text-green-400">✅ 問題已分析並注入知識庫！</p>
                <p className="text-gray-400 text-xs">案例 ID：<code className="text-green-400">{reportResult.learnId}</code></p>
                <p className="text-gray-400 text-xs">錯誤代碼：<code className="text-orange-400">{reportResult.errorCode}</code></p>
                {reportResult.vision && (
                  <div className="mt-2 p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl">
                    <p className="text-blue-400 text-xs font-bold mb-1">AI 視覺分析：</p>
                    <p className="text-gray-300 text-xs">{reportResult.vision.prediction}</p>
                    <p className="text-gray-400 text-xs mt-1">{reportResult.vision.recommendation}</p>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
        <button
          onClick={onSubmit}
          disabled={reporting || (!reportText.trim() && !reportImg)}
          className="w-full py-4 bg-gradient-to-r from-orange-600 to-red-600 rounded-2xl font-bold text-lg hover:shadow-[0_0_30px_rgba(249,115,22,0.4)] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-3"
        >
          {reporting ? "AI 分析中，請稍候..." : "🚀 送出問題並啟動 AI 分析"}
        </button>
      </div>
    </div>
  );
}
