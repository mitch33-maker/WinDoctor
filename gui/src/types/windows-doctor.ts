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

export type AdminRole = "viewer" | "operator" | "admin" | "maintainer";

export type AdminAccount = {
  adminId: string;
  displayName: string;
  role: AdminRole;
  disabled: boolean;
  createdAt?: string;
  updatedAt?: string;
  lastSeenAt?: string;
  note?: string;
};

export type AdminAccountList = {
  Status: string;
  Count?: number;
  Admins?: AdminAccount[];
  Admin?: AdminAccount;
};

export type AdminAudit = {
  Status: string;
  Total: number;
  Events: Array<{ createdAt: string; actor: string; action: string; metadata?: Record<string, unknown> }>;
};

export type AdminStatus = {
  Status: string;
  Mode: string;
  TokenEnvironmentConfigured: boolean;
  AdminAccountCount: number;
  AuditEventCount: number;
  OperationClasses: Array<{ id: string; role: AdminRole; description: string }>;
  Profile: {
    service: string;
    mode: string;
    nas: string;
    policies: {
      externalAccessRequiresToken: boolean;
      runGatedOperationsRequireAdmin: boolean;
      maintainerOperationsRequireMaintainer: boolean;
      nasServerRequired: boolean;
    };
  };
  SafetyPolicy: {
    NasRequired: boolean;
    ExternalAccessRequiresToken: boolean;
    RunGatedOperationsRequireAdmin: boolean;
    NoRepairExecuted: boolean;
  };
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
  AutoRepairSafety?: {
    RiskLevel?: string;
    Reversible?: boolean;
    DryRunImpactAvailable?: boolean;
    LocalValidationStatus?: string;
    CriticalInterruption?: boolean;
    RollbackGuidanceAvailable?: boolean;
    AllowlistReviewStatus?: string;
    AutoBatchPolicyApproved?: boolean;
    RunGateRequired?: boolean;
    BlockReasons?: string[];
    RollbackGuidance?: string;
  };
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
    issuePlan?: IssuePlan;
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

export type EventLogAnalysis = {
  Status: string;
  Phase: string;
  EventCount: number;
  RecentHours: number;
  MaxEvents: number;
  Summary: {
    CriticalCount: number;
    ErrorCount: number;
    WarningCount: number;
    UnknownCount: number;
    KbMatchedCount: number;
    PreviewRequiredCount: number;
    ManualReviewCount: number;
  };
  ProviderSummary: Array<{ ProviderName: string; Count: number }>;
  EventIdSummary: Array<{ LogName: string; ProviderName: string; EventId: number; Count: number; Level: string }>;
  Findings: Array<{
    TimeCreated?: string | null;
    LogName: string;
    ProviderName: string;
    EventId: number;
    LevelDisplayName: string;
    Message: string;
    KbMatchCount: number;
    PrimaryRuleId: string;
    PrimaryRecommendation: string;
    RepairState: "learn_only" | "preview_required" | "guided_or_manual_review";
  }>;
  MisGuidance: string[];
  SafetyPolicy: {
    ReadOnly: boolean;
    NoRepairExecuted: boolean;
    NoServiceChanged: boolean;
    RunGateRequiredForRepair: boolean;
  };
  ReportPath?: string;
  CsvPath?: string;
};

export type OfflineToolPlan = {
  Status: string;
  Mode: string;
  Component: string;
  PackageRoot?: string | null;
  SelectedTools: Array<{
    id: string;
    reason: string;
    status: "ready" | "missing";
    tool: {
      id: string;
      name: string;
      publisher: string;
      allowedUse: string;
      executionPolicy: string;
      autoRunAllowed: boolean;
      sourceTrustLevel: string;
      expectedSha256: string;
      packageRelativePath: string;
      available: boolean;
      commandPreview: string;
    } | null;
  }>;
  ExecutionModel: string;
  NextAction: string;
  SafetyPolicy: {
    NoToolExecuted: boolean;
    NoInstall: boolean;
    NoRepairAllowlistChange: boolean;
    AutoRunAllowed: boolean;
    RunGateRequired: boolean;
  };
};

export type IssuePlan = {
  Status: string;
  Mode: string;
  ProblemText: string;
  Classification: {
    component: string;
    label: string;
    confidence: number;
    matchedTerms: string[];
    checks: string[];
  };
  DiagnosticPlan: {
    ExecutionModel: string;
    Steps: Array<{ name: string; status: string; destructive: boolean }>;
  };
  RelevantRules: Array<{ id: string; title: string; script: string; details?: string; score: number }>;
  SpecializedDiagnostics?: {
    Status: string;
    Component: string;
    CheckCount: number;
    Checks: Array<{ Name: string; Status: string; Detail: string; Data?: unknown }>;
  };
  OfflineToolPlan?: OfflineToolPlan;
  AiTriageSummary: AiTriageResult["Summary"];
  RepairPreview: {
    RepairPlanVersion: number;
    DecisionEngineVersion: number;
    SafeBatchScriptCount: number;
    Executed: boolean;
    Outcome: {
      autoRepairReady: Array<{ id: string; title: string; script: string; confidence?: number; gate?: string }>;
      blockedOrManual: Array<{ id: string; title: string; script: string; reason: string; riskLevel?: string }>;
    };
  };
  UserReport: {
    Summary: string;
    Fixed: Array<{ id: string; title: string; script: string }>;
    NotFixed: Array<{ id: string; title: string; script: string; reason: string; riskLevel?: string }>;
    NextActions: string[];
    RequiresRun: boolean;
  };
  SafetyPolicy: {
    NoRepairExecuted: boolean;
    RunGateRequired: boolean;
    AutoBatchRequiresPolicyApproval: boolean;
    OfflineToolAutoSelection?: boolean;
    OfflineToolExecution?: string;
    ExternalAi: string;
  };
};
