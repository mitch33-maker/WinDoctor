# WindowsDoctor Performance Policy

Last updated: `2026-05-09`

## Goal
WindowsDoctor should evolve toward high performance with low resource consumption.

## Default Runtime
- Default user launch path is Broker-only plus static low-resource console.
- Default console:
  - `docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html`
- Default launchers:
  - `Start-WindowsDoctor.cmd`
  - `Start-WindowsDoctor-Silent.vbs`
  - `Start-WindowsDoctor-LowResource.cmd`
  - `Start-WindowsDoctor-LowResource-Silent.vbs`

## Development Runtime
- Next dev GUI is a development-only path.
- Dev GUI launchers:
  - `Start-WindowsDoctor-DevGui.cmd`
  - `Start-WindowsDoctor-DevGui-Silent.vbs`
- Dev GUI must keep watchdog enabled.
- Dev GUI must not be the default user entrypoint.

## Resource Budgets
- Default low-resource target:
  - `MaxWindowsDoctorNodeProcesses=4`
  - `MaxWindowsDoctorTotalWorkingSetMB=512`
  - `MaxWindowsDoctorProcessWorkingSetMB=256`
  - `NodeMaxOldSpaceSizeMB=192`
- Dev GUI target:
  - `MaxWindowsDoctorNodeProcesses=8`
  - `MaxWindowsDoctorTotalWorkingSetMB=1200`
  - `MaxWindowsDoctorProcessWorkingSetMB=512`
  - `NodeMaxOldSpaceSizeMB=384`
  - `MaxPostCssWorkers=1`
  - `MaxPostCssWorkerSeconds=45`

## Execution Model
- Prefer sequential jobs over concurrent jobs.
- Run `Test-ResourceSafety.ps1` before and after heavy tasks.
- Use `Invoke-WDSequentialTaskQueue.ps1` for multi-step verification.
- Stop on first failure unless explicitly running a diagnostic batch.

## Delivery Model
- Prefer incremental patch packages over rebuilding full portable zips.
- Use `New-PortableIncrementalPatch.ps1` for low-resource USB update handoff.
- Use `Test-PortableIncrementalPatch.ps1` to verify patch zip contents before handoff.
- Incremental patches exclude target-specific `portable-usb-manifest.json`.
- Full portable zip rebuild is a heavy task and should only run when explicitly needed and resource safety remains PASS.

## Safety
- No repair execution without `RUN`.
- No production build during unattended normal operation.
- No GUI dev startup unless explicitly requested for development or validation.
