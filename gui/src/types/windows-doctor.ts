export type HealthData = {
  OS: string;
  RAM_Total_GB: number;
  IsAdmin: boolean;
};

export type Finding = {
  EventID: string;
  Source: string;
  Description: string;
  MatchedRule: string;
  Diagnosis: string;
  SuggestedFix: string;
  ActionType?: "auto_repair" | "guided" | "manual_review" | "learn";
};

export type VisionResult = {
  provider?: string;
  model?: string;
  fallback?: string;
  prediction: string;
  recommendation: string;
};

export type LockStatus = {
  match: boolean;
  signature?: string;
};

export type ReportResult = {
  error?: string;
  vision?: VisionResult | null;
  learnId?: string;
  errorCode?: string;
};

export type RuleIndexItem = {
  id: string;
  title: string;
  category?: string;
  triggers: string[];
  script: string;
  repairAllowed: boolean;
};

export type VisionStatus = {
  provider: string;
  configured: boolean;
  fallback: string;
  model?: string;
  timeoutMs?: number;
};

export type AppStatus = {
  tone: "success" | "error" | "warning" | "info";
  message: string;
};

export type ScanError = {
  scope: "health" | "analyze" | "connection";
  message: string;
};

export type RepairRecommendation = {
  id: string;
  title: string;
  script: string;
  Confidence: number;
  RiskLevel: string;
  Priority: string;
  RecommendationState: string;
  RepairDecisionState: string;
  AutoBatchEligible: boolean;
  ExecutionGate: string;
};

export type RepairPlan = {
  Status: string;
  Mode: "preview" | "execute";
  RepairPlanVersion: number;
  DecisionEngineVersion: number;
  RecommendedRepairCount: number;
  ActiveRecommendedRepairCount: number;
  ObservationCount: number;
  PreviewOnlyCount?: number;
  ManualReviewCount?: number;
  SafeBatchScriptCount: number;
  SafeBatchScripts: string[];
  Executed: boolean;
  SafeRecommendations: RepairRecommendation[];
  PreviewOnlyRecommendations?: RepairRecommendation[];
  ManualReviewRecommendations: RepairRecommendation[];
  ObservationRecommendations: RepairRecommendation[];
  SafeBatchExecutionPolicy?: {
    StopOnFirstFailure: boolean;
    ExecuteRequires: string;
  };
  OperatorGuidance?: {
    EvidenceScoring: string;
    DryRunImpact: string;
    RunGate: string;
    RollbackGuidance: string;
    StopPolicy: string;
  };
};

export type WorkResourceSample = {
  time: string;
  status: string;
  freeMemoryGB?: number;
  postCssWorkerCount?: number;
  windowsDoctorNodeProcessCount?: number;
  windowsDoctorTotalWorkingSetMB?: number;
  windowsDoctorMaxProcessWorkingSetMB?: number;
};

export type WorkRepairSummary = {
  repaired: Array<{ id: string; title: string; script: string; confidence?: number }>;
  notRepaired: Array<{ id: string; title: string; script: string; reason: string; riskLevel?: string }>;
  nextSteps: string[];
};

export type WorkItem = {
  id: string;
  type: string;
  status: "running" | "cancelling" | "cancelled" | "completed" | "failed";
  startedAt: string;
  updatedAt: string;
  currentStep: string;
  canCancel: boolean;
  reportPath?: string;
  latestResource: WorkResourceSample | null;
  resourceSamples: WorkResourceSample[];
  result?: {
    repairPlan?: RepairPlan;
    summary?: WorkRepairSummary;
  } | null;
  error?: string | null;
};

export type WorkStatus = {
  active: WorkItem | null;
  last: WorkItem | null;
};

export type AiTriageFinding = {
  source: string;
  description: string;
  ruleId: string;
  title: string;
  script?: string;
  actionType: "auto_repair" | "guided" | "manual_review" | "learn";
  riskLevel: string;
  recommendation: string;
};

export type AiTriageResult = {
  Status: string;
  Mode: string;
  Model: string;
  ResourceSafety: {
    Status?: string;
    FreeMemoryGB?: number;
    WindowsDoctorNodeProcessCount?: number;
    WindowsDoctorTotalWorkingSetMB?: number;
  };
  Summary: {
    FindingCount: number;
    AutoRepairCount: number;
    ManualReviewCount: number;
    LearnOnlyCount: number;
    SafeBatchScriptCount: number;
    OverallRisk: string;
  };
  Findings: AiTriageFinding[];
  NextActions: string[];
  SafetyPolicy: {
    RepairExecution: string;
    ExternalAi: string;
    AutoAllowlistPromotion: boolean;
  };
};
