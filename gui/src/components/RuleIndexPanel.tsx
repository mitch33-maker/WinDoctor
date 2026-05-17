import type { RuleIndexItem, VisionStatus } from "@/types/windows-doctor";

type RuleIndexPanelProps = {
  rules: RuleIndexItem[];
  allowlist: string[];
  visionStatus: VisionStatus | null;
  onRefresh: () => void;
};

export function RuleIndexPanel({ rules, allowlist, visionStatus, onRefresh }: RuleIndexPanelProps) {
  return (
    <div className="mt-8 pt-6 border-t border-white/5">
      <h3 className="text-sm font-bold text-gray-400 mb-4 flex items-center gap-2">
        🧭 規則索引與修復核准狀態
      </h3>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-black/30 p-4 rounded-2xl border border-white/5">
          <p className="text-xs text-gray-500 mb-1">KB 規則數</p>
          <p className="text-2xl font-bold text-white">{rules.length}</p>
        </div>
        <div className="bg-black/30 p-4 rounded-2xl border border-white/5">
          <p className="text-xs text-gray-500 mb-1">核准修復腳本</p>
          <p className="text-2xl font-bold text-green-400">{allowlist.length}</p>
        </div>
        <div className="bg-black/30 p-4 rounded-2xl border border-white/5">
          <p className="text-xs text-gray-500 mb-1">Vision Provider</p>
          <p className="text-sm font-mono text-blue-400">{visionStatus?.provider || "unknown"}</p>
          <p className="text-[10px] text-gray-600 mt-1">{visionStatus?.configured ? "configured" : "mock fallback"}</p>
        </div>
      </div>
      <div className="mt-4 max-h-48 overflow-auto rounded-2xl border border-white/5 bg-black/30">
        <table className="w-full text-xs">
          <thead className="sticky top-0 bg-neutral-950 text-gray-500">
            <tr>
              <th className="text-left p-3">規則</th>
              <th className="text-left p-3">分類</th>
              <th className="text-left p-3">腳本</th>
              <th className="text-left p-3">核准</th>
            </tr>
          </thead>
          <tbody>
            {rules.slice(0, 20).map((rule) => (
              <tr key={rule.id} className="border-t border-white/5">
                <td className="p-3 text-gray-300">{rule.id}</td>
                <td className="p-3 text-gray-500">{rule.category || "root"}</td>
                <td className="p-3 font-mono text-gray-400">{rule.script}</td>
                <td className={`p-3 font-bold ${rule.repairAllowed ? "text-green-400" : "text-gray-600"}`}>
                  {rule.repairAllowed ? "YES" : "NO"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <button
        onClick={onRefresh}
        className="mt-4 px-4 py-2 bg-white/10 hover:bg-white/20 rounded-xl text-xs font-bold transition-all border border-white/10"
      >
        重新整理索引
      </button>
    </div>
  );
}
