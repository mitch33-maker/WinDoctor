"use client";

import { useCallback, useEffect, useState } from "react";
import { ReportModal } from "@/components/ReportModal";
import { SettingsPanel } from "@/components/SettingsPanel";
import { StatusToast } from "@/components/StatusToast";
import { SystemMonitor } from "@/components/SystemMonitor";
import { VisionModal } from "@/components/VisionModal";
import { DiagnosisResults } from "@/components/DiagnosisResults";
import { NotebookLMImportPanel } from "@/components/NotebookLMImportPanel";
import { WinPEBootMediaPanel } from "@/components/WinPEBootMediaPanel";
import { OneClickRepairPanel } from "@/components/OneClickRepairPanel";
import { WorkStatusPanel } from "@/components/WorkStatusPanel";
import { AiAssistantPanel } from "@/components/AiAssistantPanel";
import { ProblemSolverPanel } from "@/components/ProblemSolverPanel";
import { EventLogAnalysisPanel } from "@/components/EventLogAnalysisPanel";
import { windowsDoctorApi } from "@/lib/windowsDoctorApi";
import type { AiTriageResult, AppStatus, EventLogAnalysis, Finding, HealthData, IssuePlan, LockStatus, RepairPlan, ReportResult, RuleIndexItem, ScanError, VisionResult, VisionStatus, WorkStatus } from "@/types/windows-doctor";

export default function Home() {
  const [health, setHealth] = useState<HealthData | null>(null);
  const [findings, setFindings] = useState<Finding[]>([]);
  const [scanning, setScanning] = useState(false);
  const [visionOpen, setVisionOpen] = useState(false);
  const [visionImg, setVisionImg] = useState<string | null>(null);
  const [visionResult, setVisionResult] = useState<VisionResult | null>(null);
  const [lockStatus, setLockStatus] = useState<LockStatus>({ match: true });
  const [reportOpen, setReportOpen] = useState(false);
  const [reportText, setReportText] = useState("");
  const [reportImg, setReportImg] = useState<string | null>(null);
  const [reportResult, setReportResult] = useState<ReportResult | null>(null);
  const [reporting, setReporting] = useState(false);
  const [rules, setRules] = useState<RuleIndexItem[]>([]);
  const [allowlist, setAllowlist] = useState<string[]>([]);
  const [visionStatus, setVisionStatus] = useState<VisionStatus | null>(null);
  const [status, setStatus] = useState<AppStatus | null>(null);
  const [scanError, setScanError] = useState<ScanError | null>(null);
  const [repairPlan, setRepairPlan] = useState<RepairPlan | null>(null);
  const [repairPlanLoading, setRepairPlanLoading] = useState(false);
  const [repairRunToken, setRepairRunToken] = useState("");
  const [workStatus, setWorkStatus] = useState<WorkStatus | null>(null);
  const [workLoading, setWorkLoading] = useState(false);
  const [aiTriage, setAiTriage] = useState<AiTriageResult | null>(null);
  const [aiLoading, setAiLoading] = useState(false);
  const [eventLogAnalysis, setEventLogAnalysis] = useState<EventLogAnalysis | null>(null);
  const [eventLogLoading, setEventLogLoading] = useState(false);
  const [problemText, setProblemText] = useState("");
  const [issuePlan, setIssuePlan] = useState<IssuePlan | null>(null);
  const [issueLoading, setIssueLoading] = useState(false);

  const checkEnvironment = async () => {
    try {
      const data = await windowsDoctorApi.getLockStatus();
      setLockStatus(data);
      if (!data.match) setStatus({ tone: "warning", message: "檢測到環境變更：系統已進入安全性鎖定模式，請重新綁定。" });
    } catch {
      console.error("Environment check failed");
    }
  };

  const refreshSystemIndex = async () => {
    try {
      const [ruleData, allowData, visionData] = await Promise.all([
        windowsDoctorApi.getRules(),
        windowsDoctorApi.getAllowlist(),
        windowsDoctorApi.getVisionStatus(),
      ]);
      setRules(ruleData);
      setAllowlist(allowData.scripts || []);
      setVisionStatus(visionData);
    } catch {
      console.error("Index refresh failed");
    }
  };

  const refreshWorkStatus = useCallback(async () => {
    setWorkLoading(true);
    try {
      const statusData = await windowsDoctorApi.getWorkStatus();
      setWorkStatus(statusData);
      const completedPlan = statusData.last?.result?.repairPlan;
      if (completedPlan) setRepairPlan(completedPlan);
      const completedIssuePlan = statusData.last?.result?.issuePlan;
      if (completedIssuePlan) setIssuePlan(completedIssuePlan);
    } catch {
      console.error("Work status refresh failed");
    }
    setWorkLoading(false);
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void checkEnvironment();
      void refreshSystemIndex();
      void refreshWorkStatus();
    }, 0);
    return () => window.clearTimeout(timer);
  }, [refreshWorkStatus]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      if (workStatus?.active) void refreshWorkStatus();
    }, 2000);
    return () => window.clearInterval(timer);
  }, [refreshWorkStatus, workStatus?.active]);

  const submitReport = async () => {
    if (!reportText.trim() && !reportImg) return;
    setReporting(true);
    setReportResult(null);
    try {
      let visionAnalysis: VisionResult | null = null;
      if (reportImg) {
        visionAnalysis = await windowsDoctorApi.analyzeVision();
      }
      const errorMatch = reportText.match(/0x[0-9A-Fa-f]{4,8}/);
      const errorCode = errorMatch ? errorMatch[0] : "USER-REPORT-" + Date.now();
      const learnData = await windowsDoctorApi.learn({
        title: "使用者回報：" + reportText.slice(0, 40),
        errorCode,
        description: reportText
      });
      setReportResult({ vision: visionAnalysis, learnId: learnData.id, errorCode });
      await refreshSystemIndex();
    } catch {
      setReportResult({ error: "分析失敗，請確認 Broker 服務運行中。" });
    }
    setReporting(false);
  };

  const learnNewSkill = async (errorCode: string) => {
    setScanning(true);
    try {
      await windowsDoctorApi.learn({
        title: `針對 ${errorCode} 的自動學習方案`,
        errorCode,
        description: "此方案由 WindowsDoctor AI 導航員透過網路搜尋自動生成。"
      });
      setStatus({ tone: "success", message: `已建立 ${errorCode} 的 learn-only 知識庫案例。` });
      await refreshSystemIndex();
      await scanSystem();
    } catch {
      console.error("Learning failed");
    }
    setScanning(false);
  };

  const scanSystem = async () => {
    setScanning(true);
    setFindings([]);
    setScanError(null);
    try {
      const [healthData, findingData] = await Promise.all([
        windowsDoctorApi.getHealth().catch(() => {
          setScanError({ scope: "health", message: "無法讀取系統健康資料。" });
          return null;
        }),
        windowsDoctorApi.analyze().catch(() => {
          setScanError({ scope: "analyze", message: "無法讀取事件診斷資料。" });
          return null;
        }),
      ]);
      if (healthData) setHealth(healthData);
      if (findingData) setFindings(findingData);
    } catch {
      setScanError({ scope: "connection", message: "無法連線至 Broker，請確認 http://localhost:3001 已啟動。" });
    }
    setScanning(false);
  };

  const simulateVision = async () => {
    setScanning(true);
    try {
      setVisionResult(await windowsDoctorApi.analyzeVision());
    } catch {
      setVisionResult({
        prediction: "模擬偵測: 系統啟動分割區損壞 (BCD Error)",
        recommendation: "建議進入 WinRE 執行 bootrec /rebuildbcd"
      });
    }
    setScanning(false);
  };

  const runRepair = async (scriptName: string) => {
    setScanning(true);
    try {
      await windowsDoctorApi.repair(scriptName);
      setStatus({ tone: "success", message: "修復指令執行成功，系統組件已重置。" });
      setFindings([]);
    } catch {
      setStatus({ tone: "error", message: "修復失敗，請檢查 Broker 連線或 allowlist。" });
    }
    setScanning(false);
  };

  const previewRepairPlan = async () => {
    setRepairPlanLoading(true);
    try {
      const statusData = await windowsDoctorApi.startRepairPlanWork({ execute: false });
      setWorkStatus(statusData);
      setStatus({ tone: "info", message: "Repair preview started in the work window." });
    } catch {
      setStatus({ tone: "error", message: "Repair plan preview failed. Check Broker and logs." });
    }
    setRepairPlanLoading(false);
  };

  const executeRepairPlan = async () => {
    setRepairPlanLoading(true);
    try {
      const statusData = await windowsDoctorApi.startRepairPlanWork({ execute: true, confirmToken: repairRunToken });
      setWorkStatus(statusData);
      setRepairRunToken("");
      setStatus({ tone: "info", message: "Safe batch started in the work window." });
    } catch {
      setStatus({ tone: "error", message: "Safe batch execution was rejected or failed." });
    }
    setRepairPlanLoading(false);
  };

  const cancelWork = async () => {
    setWorkLoading(true);
    try {
      setWorkStatus(await windowsDoctorApi.cancelWork());
      setStatus({ tone: "warning", message: "已送出中斷目前工作的請求。" });
    } catch {
      setStatus({ tone: "error", message: "無法中斷目前工作，請檢查 Broker。" });
    }
    setWorkLoading(false);
  };

  const runAiTriage = async () => {
    setAiLoading(true);
    try {
      const triage = await windowsDoctorApi.getAiTriage();
      setAiTriage(triage);
      setStatus({ tone: "info", message: `AI triage: ${triage.Summary.OverallRisk}, findings=${triage.Summary.FindingCount}` });
    } catch {
      setStatus({ tone: "error", message: "AI triage failed. Check Broker and resource safety." });
    }
    setAiLoading(false);
  };

  const runEventLogAnalysis = async () => {
    setEventLogLoading(true);
    try {
      const analysis = await windowsDoctorApi.analyzeEventLogs({ recentHours: 24, maxEvents: 120, top: 10, logName: ["System", "Application"] });
      setEventLogAnalysis(analysis);
      setStatus({ tone: "info", message: `日誌分析完成：events=${analysis.EventCount}, matched=${analysis.Summary.KbMatchedCount}` });
    } catch {
      setStatus({ tone: "error", message: "無法分析系統日誌，請確認 Broker 權限與事件記錄服務狀態。" });
    }
    setEventLogLoading(false);
  };

  const previewIssuePlan = async () => {
    if (!problemText.trim()) return;
    setIssueLoading(true);
    try {
      const plan = await windowsDoctorApi.buildIssuePlan(problemText);
      setIssuePlan(plan);
      setStatus({ tone: "info", message: `已建立 ${plan.Classification.label} 診斷預覽，未執行修復。` });
    } catch {
      setStatus({ tone: "error", message: "無法建立問題診斷預覽，請確認 Broker 服務運行中。" });
    }
    setIssueLoading(false);
  };

  const startIssueWork = async () => {
    if (!problemText.trim()) return;
    setIssueLoading(true);
    try {
      const statusData = await windowsDoctorApi.startIssueDiagnosticWork(problemText);
      setWorkStatus(statusData);
      setStatus({ tone: "info", message: "已放入即時工作視窗，將序列化執行診斷預覽。" });
    } catch {
      setStatus({ tone: "error", message: "無法啟動問題診斷工作，請確認沒有其他工作正在執行。" });
    }
    setIssueLoading(false);
  };

  const startOfflineDiagnosticPreview = async () => {
    const component = issuePlan?.Classification.component || "general";
    setIssueLoading(true);
    try {
      const statusData = await windowsDoctorApi.startOfflineDiagnosticWork({ component, problemText, execute: false });
      setWorkStatus(statusData);
      setStatus({ tone: "info", message: "已建立離線工具序列化診斷預覽；未執行工具。" });
    } catch {
      setStatus({ tone: "error", message: "無法建立離線工具診斷預覽，請確認沒有其他工作正在執行。" });
    }
    setIssueLoading(false);
  };

  const requestElevation = async () => {
    try {
      const data = await windowsDoctorApi.requestElevation();
      setStatus({ tone: "info", message: data.message || "提權狀態已更新。" });
    } catch {
      setStatus({ tone: "error", message: "無法發起提權請求，請檢查 Broker 是否運行。" });
    }
  };

  return (
    <main className="min-h-screen p-4 md:p-8 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-blue-900/20 via-black to-black overflow-hidden font-sans">
      <StatusToast status={status} onDismiss={() => setStatus(null)} />
      <div className="max-w-6xl mx-auto flex justify-between items-center mb-8 border-b border-white/10 pb-6">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 md:w-12 md:h-12 bg-blue-600 rounded-lg flex items-center justify-center shadow-[0_0_20px_rgba(37,99,235,0.5)]">
            <span className="text-xl md:text-2xl font-bold">W</span>
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tighter bg-clip-text text-transparent bg-gradient-to-r from-white to-gray-500">
            WindowsDoctor <span className="text-blue-500 text-xs md:text-sm font-mono ml-2">v0.1.0-alpha</span>
          </h1>
        </div>
        <div className="flex gap-3">
          <button
            id="report-btn"
            onClick={() => { setReportOpen(true); setReportResult(null); }}
            className="px-4 py-2 text-sm rounded-full border border-orange-500/40 bg-orange-500/10 hover:bg-orange-500/20 text-orange-400 transition-all flex items-center gap-2"
          >
            🩺 回報問題
          </button>
          <button
            id="vision-btn"
            onClick={() => setVisionOpen(true)}
            className="px-4 py-2 text-sm rounded-full border border-white/20 hover:bg-white/5 transition-all flex items-center gap-2"
          >
            📸 拍照診斷
          </button>
        </div>
      </div>

      <VisionModal
        open={visionOpen}
        scanning={scanning}
        visionImg={visionImg}
        visionResult={visionResult}
        onClose={() => setVisionOpen(false)}
        onSetImage={setVisionImg}
        onAnalyze={simulateVision}
      />

      <ReportModal
        open={reportOpen}
        reportText={reportText}
        reportImg={reportImg}
        reportResult={reportResult}
        reporting={reporting}
        onClose={() => { setReportOpen(false); setReportResult(null); setReportImg(null); setReportText(""); }}
        onTextChange={setReportText}
        onImageChange={setReportImg}
        onSubmit={submitReport}
      />

      <ProblemSolverPanel
        problemText={problemText}
        loading={issueLoading}
        plan={issuePlan}
        workStatus={workStatus}
        onTextChange={setProblemText}
        onPreview={previewIssuePlan}
        onStartWork={startIssueWork}
        onStartOfflineDiagnostics={startOfflineDiagnosticPreview}
      />

      <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-8">
        <SystemMonitor health={health} scanning={scanning} onScan={scanSystem} onRequestElevation={requestElevation} />
        <DiagnosisResults findings={findings} scanning={scanning} error={scanError} onLearn={learnNewSkill} onRepair={runRepair} onRetry={scanSystem} />
      </div>

      <NotebookLMImportPanel />
      <WinPEBootMediaPanel />
      <AiAssistantPanel triage={aiTriage} loading={aiLoading} onRun={runAiTriage} />
      <EventLogAnalysisPanel analysis={eventLogAnalysis} loading={eventLogLoading} onRun={runEventLogAnalysis} />
      <WorkStatusPanel
        workStatus={workStatus}
        loading={workLoading}
        onRefresh={refreshWorkStatus}
        onCancel={cancelWork}
      />
      <OneClickRepairPanel
        plan={repairPlan}
        loading={repairPlanLoading}
        runToken={repairRunToken}
        onRunTokenChange={setRepairRunToken}
        onPreview={previewRepairPlan}
        onExecute={executeRepairPlan}
      />

      <SettingsPanel
        lockStatus={lockStatus}
        rules={rules}
        allowlist={allowlist}
        visionStatus={visionStatus}
        onCheckEnvironment={checkEnvironment}
        onRefreshSystemIndex={refreshSystemIndex}
        onStatus={setStatus}
      />

      <style jsx global>{`
        @keyframes scanline {
          from { top: 0; }
          to { top: 100%; }
        }
        .animate-scanline {
          animation: scanline 3s linear infinite;
        }
      `}</style>
    </main>
  );
}
