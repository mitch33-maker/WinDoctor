# WindowsDoctor Documentation System Skill

Use this skill when working in `E:\WindowsDoctor` on documentation architecture, handoff updates, task completion records, success memory, error history, or long-term project memory.

## Required Safety Gate
Run this before any work:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
```

Stop if resource safety fails.

## Minimal Read Set
Read in this order:
1. `INDEX.md`
2. `DOCUMENTATION_ARCHITECTURE.md`
3. `MEMORY_SYSTEM.md`
4. Latest section at the top of `TASK_HANDOFF.md`
5. Task-specific files only

Do not reread every historical document unless the task requires it.

## Safety Rules
- Do not run repairs without explicit `RUN`.
- Do not run production build unless explicitly requested.
- Do not start GUI/Broker for documentation-only work.
- Do not invent real diagnostic data.
- Use `logs\*.json` as evidence source; do not handwrite validation results.

## Completion Routine
After a task is completed:
1. Write or update the relevant authority file.
2. If the task created a reusable pattern, update `SUCCESS_EXPERIENCE.md`.
3. If the task exposed a blocking failure, update `SYSTEM_ERROR_HISTORY.md`.
4. Run:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-DocumentationMemorySystem.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-memory-system.latest.json -Json
```

5. Add a completion record:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Add-TaskCompletionRecord.ps1 -Title "task title" -Status PASS -Summary "short summary" -EvidencePath E:\WindowsDoctor\logs\documentation-memory-system.latest.json -Json
```

6. Update `TASK_HANDOFF.md` and `NEXT_CHAT_PROMPT.md` only with high-value current state.

## Reuse Decision
Use this skill instead of rereading the full documentation set when:
- The task is about docs, memory, handoff, safety policy, or recurring workflow.
- The task is a continuation of WindowsDoctor system development.
- The goal is to avoid repeating a previous mistake.

