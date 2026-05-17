import type { AppStatus } from "@/types/windows-doctor";

type StatusToastProps = {
  status: AppStatus | null;
  onDismiss: () => void;
};

const toneClass = {
  success: "border-green-500/40 bg-green-500/15 text-green-200",
  error: "border-red-500/40 bg-red-500/15 text-red-200",
  warning: "border-yellow-500/40 bg-yellow-500/15 text-yellow-100",
  info: "border-blue-500/40 bg-blue-500/15 text-blue-100",
};

export function StatusToast({ status, onDismiss }: StatusToastProps) {
  if (!status) return null;

  return (
    <div className={`fixed right-4 top-4 z-[70] max-w-md rounded-2xl border px-4 py-3 shadow-2xl backdrop-blur ${toneClass[status.tone]}`}>
      <div className="flex items-start gap-3">
        <p className="text-sm leading-relaxed">{status.message}</p>
        <button onClick={onDismiss} className="ml-auto text-lg leading-none opacity-70 hover:opacity-100">×</button>
      </div>
    </div>
  );
}
