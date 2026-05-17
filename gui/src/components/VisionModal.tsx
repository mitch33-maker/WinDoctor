import type { VisionResult } from "@/types/windows-doctor";

/* eslint-disable @next/next/no-img-element */

type VisionModalProps = {
  open: boolean;
  scanning: boolean;
  visionImg: string | null;
  visionResult: VisionResult | null;
  onClose: () => void;
  onSetImage: (value: string) => void;
  onAnalyze: () => void;
};

export function VisionModal({ open, scanning, visionImg, visionResult, onClose, onSetImage, onAnalyze }: VisionModalProps) {
  if (!open) return null;

  return (
    <div id="vision-modal" className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-4">
      <div className="bg-neutral-900 border border-white/10 p-8 rounded-3xl max-w-2xl w-full relative animate-in zoom-in-95 duration-200 shadow-[0_0_50px_rgba(0,0,0,0.5)]">
        <button onClick={onClose} className="absolute top-4 right-4 text-gray-400 hover:text-white text-2xl">×</button>
        <h2 className="text-2xl font-bold mb-6 text-blue-400">AI 視覺故障分析 (手機端實作預覽)</h2>
        <div className="aspect-video w-full bg-black/50 rounded-2xl border-2 border-dashed border-white/10 flex flex-col items-center justify-center mb-6 overflow-hidden relative">
          {visionImg ? (
            <img src={visionImg} className="w-full h-full object-cover" alt="Scan" />
          ) : (
            <div className="flex flex-col items-center">
              <p className="text-gray-500 mb-4">請對準螢幕故障處拍照 (如藍屏或診斷碼)</p>
              <button
                onClick={() => onSetImage("https://images.unsplash.com/photo-1563911302283-d2bc129e7370?auto=format&fit=crop&q=80&w=800")}
                className="px-6 py-2 bg-blue-600 rounded-full hover:bg-blue-500 transition-all font-bold"
              >
                模擬拍照 / 上傳照片
              </button>
            </div>
          )}
        </div>
        {visionResult ? (
          <div className="p-6 rounded-2xl bg-blue-500/10 border border-blue-500/30 mb-6">
            <p className="text-blue-400 font-bold mb-2 font-mono tracking-widest text-xs">AI VISION ANALYSIS RESULT:</p>
            <p className="text-lg mb-4 text-white font-semibold">{visionResult.prediction}</p>
            <div className="p-4 bg-black/40 rounded-xl mb-4 text-sm text-gray-400 border border-white/5">
              {visionResult.recommendation}
            </div>
            <button className="w-full py-4 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-xl font-bold hover:shadow-[0_0_20px_rgba(37,99,235,0.4)] transition-all">
              開始同步引導修復
            </button>
          </div>
        ) : (
          <button
            onClick={onAnalyze}
            disabled={!visionImg || scanning}
            className="w-full py-4 bg-white text-black font-bold rounded-2xl disabled:opacity-50 transition-all hover:bg-gray-200"
          >
            {scanning ? "AI 專家系統分析中..." : "開始視覺分析"}
          </button>
        )}
      </div>
    </div>
  );
}
