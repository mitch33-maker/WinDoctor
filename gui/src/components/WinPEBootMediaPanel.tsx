import { useMemo, useState } from "react";

type StartupMode = "Menu" | "Broker";
type MediaTarget = "usb" | "iso";

function normalizeUsbPath(value: string): string {
  const trimmed = value.trim().replace(/\//g, "\\");
  if (/^[A-Za-z]:$/.test(trimmed)) return `${trimmed}\\`;
  return trimmed;
}

export function WinPEBootMediaPanel() {
  const [usbPath, setUsbPath] = useState("G:\\");
  const [isoPath, setIsoPath] = useState("E:\\WindowsDoctor_Rescue.iso");
  const [startupMode, setStartupMode] = useState<StartupMode>("Menu");
  const [mediaTarget, setMediaTarget] = useState<MediaTarget>("usb");
  const [confirmToken, setConfirmToken] = useState("");

  const normalizedUsb = normalizeUsbPath(usbPath);
  const usbReady = /^[A-Za-z]:\\$/.test(normalizedUsb);
  const canWriteUsb = mediaTarget === "usb" && usbReady && confirmToken === "RUN";
  const targetCommand = mediaTarget === "usb"
    ? `-USBPath ${normalizedUsb}`
    : `-OutputPath ${isoPath.trim() || "E:\\WindowsDoctor_Rescue.iso"}`;

  const preflightCommand = useMemo(() => (
    `powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\\WindowsDoctor\\scripts\\Build-WinPEMedia.ps1 -CheckOnly -StartupMode ${startupMode} -ReportPath E:\\WindowsDoctor\\logs\\winpe-media-checkonly.latest.json -Json`
  ), [startupMode]);

  const buildCommand = useMemo(() => (
    `powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\\WindowsDoctor\\scripts\\Build-WinPEMedia.ps1 -StartupMode ${startupMode} ${targetCommand}`
  ), [startupMode, targetCommand]);

  return (
    <section className="max-w-6xl mx-auto mt-8 rounded-[28px] bg-[#0f172a] border border-[#1e293b] overflow-hidden shadow-[0_18px_60px_rgba(0,0,0,0.25)]">
      <div className="px-5 md:px-8 py-5 border-b border-white/10 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <p className="text-xs font-semibold text-cyan-300">Windows PE Rescue Media</p>
          <h2 className="text-xl md:text-2xl font-semibold text-white tracking-normal">開機 USB 製作中心</h2>
        </div>
        <div className="inline-flex rounded-full bg-white/10 p-1 border border-white/10 w-fit">
          {(["Menu", "Broker"] as StartupMode[]).map((mode) => (
            <button
              key={mode}
              type="button"
              onClick={() => setStartupMode(mode)}
              className={`px-4 py-2 rounded-full text-xs font-bold transition-all ${startupMode === mode ? "bg-cyan-400 text-slate-950" : "text-slate-300 hover:text-white"}`}
            >
              {mode === "Menu" ? "離線選單" : "Broker"}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[0.9fr_1.1fr]">
        <div className="p-5 md:p-8 border-b lg:border-b-0 lg:border-r border-white/10">
          <div className="space-y-5">
            <div>
              <p className="text-xs text-slate-400 mb-2">輸出類型</p>
              <div className="grid grid-cols-2 gap-2">
                {(["usb", "iso"] as MediaTarget[]).map((target) => (
                  <button
                    key={target}
                    type="button"
                    onClick={() => setMediaTarget(target)}
                    className={`rounded-2xl px-4 py-3 text-sm font-bold border transition-all ${mediaTarget === target ? "bg-cyan-400 text-slate-950 border-cyan-300" : "bg-white/5 text-slate-300 border-white/10 hover:bg-white/10"}`}
                  >
                    {target === "usb" ? "開機 USB" : "ISO 檔"}
                  </button>
                ))}
              </div>
            </div>

            {mediaTarget === "usb" ? (
              <div>
                <label className="text-xs text-slate-400 mb-2 block">USB 磁碟代號</label>
                <input
                  value={usbPath}
                  onChange={(event) => setUsbPath(event.target.value)}
                  className="w-full rounded-2xl bg-slate-950 border border-white/10 px-4 py-3 text-sm text-cyan-200 outline-none focus:border-cyan-400"
                  placeholder="G:\"
                />
              </div>
            ) : (
              <div>
                <label className="text-xs text-slate-400 mb-2 block">ISO 輸出路徑</label>
                <input
                  value={isoPath}
                  onChange={(event) => setIsoPath(event.target.value)}
                  className="w-full rounded-2xl bg-slate-950 border border-white/10 px-4 py-3 text-sm text-cyan-200 outline-none focus:border-cyan-400"
                  placeholder="E:\WindowsDoctor_Rescue.iso"
                />
              </div>
            )}

            <div>
              <label className="text-xs text-slate-400 mb-2 block">寫入確認</label>
              <input
                value={confirmToken}
                onChange={(event) => setConfirmToken(event.target.value)}
                className="w-full rounded-2xl bg-slate-950 border border-white/10 px-4 py-3 text-sm text-cyan-200 outline-none focus:border-cyan-400"
                placeholder="輸入 RUN 啟用 USB 寫入"
              />
            </div>

            <div className="grid grid-cols-3 gap-2">
              <div className="rounded-2xl bg-white/5 border border-white/10 p-4">
                <p className="text-[11px] text-slate-500">ADK</p>
                <p className="text-sm font-bold text-white">預檢</p>
              </div>
              <div className="rounded-2xl bg-white/5 border border-white/10 p-4">
                <p className="text-[11px] text-slate-500">啟動模式</p>
                <p className="text-sm font-bold text-white">{startupMode}</p>
              </div>
              <div className={`rounded-2xl border p-4 ${canWriteUsb || mediaTarget === "iso" ? "bg-emerald-500/10 border-emerald-400/30" : "bg-amber-500/10 border-amber-400/30"}`}>
                <p className="text-[11px] text-slate-500">寫入狀態</p>
                <p className={`text-sm font-bold ${canWriteUsb || mediaTarget === "iso" ? "text-emerald-300" : "text-amber-300"}`}>
                  {mediaTarget === "iso" ? "ISO" : canWriteUsb ? "RUN" : "LOCK"}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="p-5 md:p-8 bg-slate-950/70">
          <div className="space-y-4">
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-sm font-bold text-white">1. 預檢命令</h3>
                <span className="text-[11px] text-slate-500">不寫入 USB</span>
              </div>
              <pre className="whitespace-pre-wrap rounded-2xl bg-black border border-white/10 p-4 text-[11px] leading-relaxed text-cyan-200 overflow-auto">{preflightCommand}</pre>
            </div>
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-sm font-bold text-white">2. 製作命令</h3>
                <span className="text-[11px] text-slate-500">{mediaTarget === "usb" ? "會重製目標 USB" : "建立 ISO"}</span>
              </div>
              <pre className={`whitespace-pre-wrap rounded-2xl border p-4 text-[11px] leading-relaxed overflow-auto ${mediaTarget === "usb" && !canWriteUsb ? "bg-black/40 border-amber-400/30 text-amber-200" : "bg-black border-white/10 text-cyan-200"}`}>{buildCommand}</pre>
            </div>
            <div className="rounded-2xl bg-white/5 border border-white/10 p-4">
              <p className="text-xs text-slate-300 leading-relaxed">
                WinPE 預設啟動離線文字選單，會載入 WindowsDoctor 離線 KB、系統掃描、自我測試與 allowlist 修復預覽。Broker 模式只在需要網頁 API 時使用。
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
