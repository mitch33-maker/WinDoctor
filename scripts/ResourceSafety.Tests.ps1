Describe "WindowsDoctor resource safety scripts" {
    BeforeAll {
        $script:root = "E:\WindowsDoctor"
    }

    It "parses safety scripts" {
        $paths = @(
            "$script:root\scripts\Test-ResourceSafety.ps1",
            "$script:root\scripts\Stop-WDGuiDevWorkers.ps1",
            "$script:root\scripts\Stop-WindowsDoctorServices.ps1",
            "$script:root\scripts\Test-KBMarkdownEncoding.ps1",
            "$script:root\scripts\Test-WinPEOfflineFlow.ps1",
            "$script:root\scripts\Test-DocumentationSync.ps1",
            "$script:root\scripts\Add-TaskCompletionRecord.ps1",
            "$script:root\scripts\Test-DocumentationMemorySystem.ps1",
            "$script:root\scripts\Test-RepairCoverageGoal.ps1",
            "$script:root\scripts\Test-AutoRepairSafetyPolicy.ps1",
            "$script:root\scripts\Test-SpecializedIssueDiagnostics.ps1",
            "$script:root\scripts\Test-WindowsResourceOrganizerCapability.ps1",
            "$script:root\scripts\Test-ManagementSystemReadiness.ps1",
            "$script:root\scripts\Test-PortableUsbReadiness.ps1",
            "$script:root\scripts\Test-SystemErrorScan.ps1",
            "$script:root\scripts\Analyze-WindowsEventLogs.ps1",
            "$script:root\scripts\Test-RepairToolPackageManifest.ps1",
            "$script:root\scripts\New-RepairToolPackage.ps1",
            "$script:root\scripts\Save-OfflineRepairTools.ps1",
            "$script:root\scripts\Test-OfflineToolAutomation.ps1",
            "$script:root\scripts\Test-OfflineDiagnosticRunnerSkill.ps1",
            "$script:root\scripts\Invoke-OfflineDiagnosticTools.ps1",
            "$script:root\scripts\Convert-OfflineDiagnosticToolOutput.ps1",
            "$script:root\scripts\New-OfflineDiagnosticUserReport.ps1",
            "$script:root\scripts\Test-SystemErroeScan.ps1",
            "$script:root\scripts\Test-SystemErrorsScan.ps1",
            "$script:root\scripts\Test-PortableRuntimeSelfTest.ps1",
            "$script:root\scripts\Get-PortableRuntimeStatus.ps1",
            "$script:root\scripts\Invoke-RecommendedRepairPlan.ps1",
            "$script:root\scripts\Test-NotebookLMSourcePack.ps1",
            "$script:root\scripts\Import-NotebookLMSourcePack.ps1",
            "$script:root\scripts\Test-ExternalDiagnosticsPack.ps1",
            "$script:root\scripts\Import-ExternalDiagnosticsPack.ps1",
            "$script:root\scripts\Convert-OfficialDiagnosticsToExternalPack.ps1",
            "$script:root\scripts\Test-RealDataImportReadiness.ps1",
            "$script:root\scripts\Test-TaskHandoffArchiveReadiness.ps1",
            "$script:root\scripts\Test-LowResourceStartup.ps1",
            "$script:root\scripts\Watch-WDResourceSafety.ps1",
            "$script:root\scripts\Invoke-WDSequentialTaskQueue.ps1",
            "$script:root\scripts\Export-IntuneRemediationPackage.ps1",
            "$script:root\scripts\Test-IntuneRemediationPackage.ps1",
            "$script:root\scripts\Export-NormalizedKBDatabase.ps1",
            "$script:root\scripts\Test-NormalizedKBDatabase.ps1",
            "$script:root\scripts\New-PortableUsbPayload.ps1",
            "$script:root\scripts\Test-PortableUsbPayload.ps1",
            "$script:root\scripts\Test-PortableUsbReleaseValidation.ps1",
            "$script:root\scripts\Test-PortableUsbZipManifest.ps1",
            "$script:root\scripts\New-PortableIncrementalPatch.ps1",
            "$script:root\scripts\Test-PortableIncrementalPatch.ps1",
            "$script:root\scripts\Test-UsbLowResourceEntry.ps1",
            "$script:root\scripts\Test-UsbLowResourceAcceptance.ps1",
            "$script:root\scripts\Publish-PortableUsbPackage.ps1",
            "$script:root\scripts\Invoke-PortableUsbAcceptance.ps1",
            "$script:root\scripts\Sync-GuiReadyUsbPatch.ps1",
            "$script:root\scripts\Export-OfflineKBDatabase.ps1",
            "$script:root\scripts\Invoke-WindowsMaintenance.ps1",
            "$script:root\scripts\Test-OfflineKBDatabase.ps1",
            "$script:root\scripts\Search-OfflineKB.ps1",
            "$script:root\scripts\Invoke-AllowedRepair.ps1",
            "$script:root\scripts\New-WinPEStartNet.ps1",
            "$script:root\scripts\New-ContinuationPrompt.ps1",
            "$script:root\scripts\Start-WinPEOfflineMenu.ps1",
            "$script:root\scripts\Build-WinPEMedia.ps1",
            "$script:root\scripts\Test-SystemBaseline.ps1",
            "$script:root\scripts\Test-VersionPolicy.ps1",
            "$script:root\scripts\Start-WindowsDoctor.ps1"
        )

        foreach ($path in $paths) {
            { [scriptblock]::Create((Get-Content -Raw -LiteralPath $path)) } | Should -Not -Throw
        }
    }

    It "reports zero or more matched GUI dev workers in dry-run mode" {
        $result = & "$script:root\scripts\Stop-WDGuiDevWorkers.ps1" -WhatIf

        $result | Should -Not -BeNullOrEmpty
        [int]$result.Matched | Should -BeGreaterOrEqual 0
        [int]$result.Stopped | Should -Be 0
        [bool]$result.WhatIf | Should -BeTrue
    }

    It "emits machine-readable worker cleanup JSON" {
        $json = & "$script:root\scripts\Stop-WDGuiDevWorkers.ps1" -WhatIf -Json
        $result = $json | ConvertFrom-Json

        $result.Root | Should -Be $script:root
        [bool]$result.WhatIf | Should -BeTrue
        [int]$result.Stopped | Should -Be 0
        [int]$result.Matched | Should -BeGreaterOrEqual 0
    }

    It "writes a worker cleanup dry-run report without stopping processes" {
        $reportPath = "$script:root\logs\gui-dev-workers.whatif.test.json"
        try {
            $json = & "$script:root\scripts\Stop-WDGuiDevWorkers.ps1" -WhatIf -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Root | Should -Be $script:root
            $result.ReportPath | Should -Be $reportPath
            [bool]$result.WhatIf | Should -BeTrue
            [int]$result.Stopped | Should -Be 0
            $report.ReportPath | Should -Be $reportPath
            [bool]$report.WhatIf | Should -BeTrue
            [int]$report.Stopped | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a version policy report" {
        $reportPath = "$script:root\logs\version-policy.test.json"
        try {
            $json = & "$script:root\scripts\Test-VersionPolicy.ps1" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $report.Version | Should -Match "^\d+\.\d+\.\d+"
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a resource snapshot report without command lines" {
        $reportPath = "$script:root\logs\resource-snapshot.test.json"
        try {
            $json = & "$script:root\scripts\Get-WDResourceSnapshot.ps1" -Top 3 -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.ReportPath | Should -Be $reportPath
            $report.ReportPath | Should -Be $reportPath
            [double]$report.Memory.TotalGB | Should -BeGreaterThan 0
            [double]$report.Memory.FreeGB | Should -BeGreaterThan 0
            @($report.TopProcesses).Count | Should -BeLessOrEqual 3
            @($report.TargetProcesses | Where-Object { $_.CommandLine }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "passes resource safety with relaxed process limits" {
        {
            & "$script:root\scripts\Test-ResourceSafety.ps1" `
                -MinFreeMemoryGB 0 `
                -MaxPostCssWorkers 9999 `
                -MaxWindowsDoctorNodeProcesses 9999
        } | Should -Not -Throw
    }

    It "emits machine-readable resource safety JSON" {
        $json = & "$script:root\scripts\Test-ResourceSafety.ps1" `
            -MinFreeMemoryGB 0 `
            -MaxPostCssWorkers 9999 `
            -MaxWindowsDoctorNodeProcesses 9999 `
            -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Root | Should -Be $script:root
        [double]$result.FreeMemoryGB | Should -BeGreaterThan 0
        [int]$result.PostCssWorkerCount | Should -BeGreaterOrEqual 0
        [int]$result.WindowsDoctorNodeProcessCount | Should -BeGreaterOrEqual 0
        @($result.Checks).Count | Should -BeGreaterOrEqual 5
        @($result.Checks | Where-Object { $_.Name -eq "windowsdoctor-node-working-set-total" }).Count | Should -Be 1
        @($result.Checks | Where-Object { $_.Name -eq "windowsdoctor-node-working-set-process" }).Count | Should -Be 1
    }

    It "writes a resource safety report" {
        $reportPath = "$script:root\logs\resource-safety.test.json"
        try {
            $json = & "$script:root\scripts\Test-ResourceSafety.ps1" `
                -MinFreeMemoryGB 0 `
                -MaxPostCssWorkers 9999 `
                -MaxWindowsDoctorNodeProcesses 9999 `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Checks).Count | Should -BeGreaterOrEqual 5
            @($report.Checks | Where-Object { $_.Name -eq "windowsdoctor-node-working-set-total" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Name -eq "windowsdoctor-node-working-set-process" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "runs a sequential task queue with resource gates" {
        $reportPath = "$script:root\logs\sequential-task-queue.test.json"
        try {
            $json = & "$script:root\scripts\Invoke-WDSequentialTaskQueue.ps1" `
                -Task "resource-safety" `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            [bool]$result.Sequential | Should -BeTrue
            @($result.Results).Count | Should -Be 1
            $result.Results[0].Name | Should -Be "resource-safety"
            $report.Status | Should -Be "PASS"
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a service status report without starting GUI or Broker" {
        $reportPath = "$script:root\logs\service-status.test.json"
        try {
            $json = & "$script:root\scripts\Start-WindowsDoctor.ps1" `
                -NoGui `
                -NoBroker `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.GuiUrl | Should -Be "http://localhost:3000"
            $result.BrokerUrl | Should -Be "http://localhost:3001"
            $result.ReportPath | Should -Be $reportPath
            $report.ReportPath | Should -Be $reportPath
            [double]$report.FreeMemoryGB | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a GUI smoke offline report without starting services" {
        $reportPath = "$script:root\logs\gui-smoke-offline.test.json"
        try {
            $json = & "$script:root\scripts\Test-GuiSmoke.ps1" `
                -AllowOffline `
                -MinFreeMemoryGB 0 `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            [bool]$result.AllowOffline | Should -BeTrue
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Results | Where-Object { $_.Name -eq "gui-home" }).Count | Should -Be 1
            @($report.Results | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates KB markdown encoding and required fields" {
        $json = & "$script:root\scripts\Test-KBMarkdownEncoding.ps1" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.TotalFiles | Should -BeGreaterThan 0
        @($result.Checks | Where-Object { $_.Name -eq "mojibake-patterns" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
    }

    It "writes a KB markdown encoding report" {
        $reportPath = "$script:root\logs\kb-markdown-encoding.test.json"
        try {
            $json = & "$script:root\scripts\Test-KBMarkdownEncoding.ps1" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Checks | Where-Object { $_.Name -eq "mojibake-patterns" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "exports machine-readable offline KB database" {
        $outputPath = "$script:root\offline_database\windowsdoctor-kb.test.json"
        try {
            $json = & "$script:root\scripts\Export-OfflineKBDatabase.ps1" -OutputPath $outputPath -Json
            $summary = $json | ConvertFrom-Json
            $validationJson = & "$script:root\scripts\Test-OfflineKBDatabase.ps1" -DatabasePath $outputPath -Json
            $validation = $validationJson | ConvertFrom-Json

            $summary.Status | Should -Be "PASS"
            $summary.TotalRules | Should -BeGreaterThan 0
            $validation.Status | Should -Be "PASS"
            $validation.TotalRules | Should -Be $summary.TotalRules
        }
        finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes an offline KB export summary report" {
        $outputPath = "$script:root\offline_database\windowsdoctor-kb.report-test.json"
        $reportPath = "$script:root\logs\offline-kb-export.test.json"
        try {
            $json = & "$script:root\scripts\Export-OfflineKBDatabase.ps1" `
                -OutputPath $outputPath `
                -ReportPath $reportPath `
                -Json
            $summary = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json
            $validationJson = & "$script:root\scripts\Test-OfflineKBDatabase.ps1" -DatabasePath $outputPath -Json
            $validation = $validationJson | ConvertFrom-Json

            $summary.Status | Should -Be "PASS"
            $summary.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $validation.Status | Should -Be "PASS"
            $report.TotalRules | Should -Be $validation.TotalRules
        }
        finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates machine-readable offline KB database" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $json = & "$script:root\scripts\Test-OfflineKBDatabase.ps1" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.TotalRules | Should -BeGreaterThan 0
        @($result.Checks).Count | Should -BeGreaterThan 5
        @($result.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        @($result.Checks | Where-Object { $_.Name -eq "rule-readable-text" -and $_.Status -eq "PASS" }).Count | Should -Be 1
    }

    It "writes an offline KB database validation report" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $reportPath = "$script:root\logs\offline-kb-validate.test.json"
        try {
            $json = & "$script:root\scripts\Test-OfflineKBDatabase.ps1" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Checks | Where-Object { $_.Name -eq "auto-repair-allowlist-match" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "exports and validates normalized KB database with official source provenance" {
        $outputPath = "$script:root\offline_database\windowsdoctor-kb-normalized.test.json"
        $exportReport = "$script:root\logs\normalized-kb-export.test.json"
        $validateReport = "$script:root\logs\normalized-kb-validate.test.json"
        try {
            $json = & "$script:root\scripts\Export-NormalizedKBDatabase.ps1" `
                -OutputPath $outputPath `
                -ReportPath $exportReport `
                -Json
            $export = $json | ConvertFrom-Json
            $validateJson = & "$script:root\scripts\Test-NormalizedKBDatabase.ps1" `
                -DatabasePath $outputPath `
                -ReportPath $validateReport `
                -Json
            $validation = $validateJson | ConvertFrom-Json

            $export.Status | Should -Be "PASS"
            $export.SchemaVersion | Should -Be 2
            [int]$export.TotalRecords | Should -BeGreaterOrEqual 70
            [int]$export.PublicReferenceRecords | Should -BeGreaterOrEqual 8
            $validation.Status | Should -Be "PASS"
            [int]$validation.SourceCount | Should -BeGreaterOrEqual 6
            @($validation.Checks | Where-Object { $_.Name -eq "official-source-urls" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($validation.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $exportReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validateReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "imports NotebookLM source packs into normalized KB records" {
        $inputPath = "$script:root\logs\notebooklm-import.test.input.json"
        $packPath = "$script:root\logs\notebooklm-repair-sources.test.json"
        $normalizedPath = "$script:root\offline_database\windowsdoctor-kb-normalized.notebooklm-test.json"
        $importReport = "$script:root\logs\notebooklm-import.test.json"
        try {
            $sample = [PSCustomObject]@{
                notebookTitle = "Windows repair notebook"
                sources = @(
                    [PSCustomObject]@{
                        id = "SRC1"
                        vendor = "NotebookLM"
                        title = "Notebook note"
                        url = "https://example.com/windows-repair-note"
                        sourceType = "notebooklm_export"
                    }
                )
                records = @(
                    [PSCustomObject]@{
                        id = "DNS-NOTE"
                        title = "NotebookLM DNS repair note"
                        component = "network"
                        symptoms = @("DNS failure")
                        errorCodes = @("0x80072ee7")
                        eventIds = @()
                        triggerTerms = @("DNS", "0x80072ee7")
                        recommendedActions = @("Check DNS server settings")
                        script = "Repair-NetworkStack.bat"
                        actionType = "auto_repair"
                        repairAllowed = $true
                        riskLevel = "low"
                        sourceIds = @("SRC1")
                    }
                )
            }
            [System.IO.File]::WriteAllText($inputPath, ($sample | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

            $json = & "$script:root\scripts\Import-NotebookLMSourcePack.ps1" `
                -InputPath $inputPath `
                -OutputPath $packPath `
                -ReportPath $importReport `
                -Json
            $import = $json | ConvertFrom-Json
            $exportJson = & "$script:root\scripts\Export-NormalizedKBDatabase.ps1" `
                -NotebookLMPackPath $packPath `
                -OutputPath $normalizedPath `
                -Json
            $export = $exportJson | ConvertFrom-Json
            $validateJson = & "$script:root\scripts\Test-NormalizedKBDatabase.ps1" -DatabasePath $normalizedPath -Json
            $validation = $validateJson | ConvertFrom-Json
            $database = Get-Content -Raw -Encoding UTF8 -LiteralPath $normalizedPath | ConvertFrom-Json

            $import.Status | Should -Be "PASS"
            [int]$import.RecordCount | Should -Be 1
            [int]$export.NotebookLMRecords | Should -Be 1
            $validation.Status | Should -Be "PASS"
            @($database.records | Where-Object { $_.id -eq "NBLM-DNS-NOTE" -and $_.provenance.sourceType -eq "notebooklm_export" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $packPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $normalizedPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $importReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates the NotebookLM source pack template" {
        $templatePath = "$script:root\templates\NOTEBOOKLM_SOURCE_PACK_TEMPLATE.json"
        $packPath = "$script:root\logs\notebooklm-template-repair-sources.test.json"
        $normalizedPath = "$script:root\offline_database\windowsdoctor-kb-normalized.notebooklm-template-test.json"
        $importReport = "$script:root\logs\notebooklm-template-import.test.json"
        try {
            $json = & "$script:root\scripts\Import-NotebookLMSourcePack.ps1" `
                -InputPath $templatePath `
                -OutputPath $packPath `
                -ReportPath $importReport `
                -Json
            $import = $json | ConvertFrom-Json
            $exportJson = & "$script:root\scripts\Export-NormalizedKBDatabase.ps1" `
                -NotebookLMPackPath $packPath `
                -OutputPath $normalizedPath `
                -Json
            $export = $exportJson | ConvertFrom-Json
            $validateJson = & "$script:root\scripts\Test-NormalizedKBDatabase.ps1" -DatabasePath $normalizedPath -Json
            $validation = $validateJson | ConvertFrom-Json
            $database = Get-Content -Raw -Encoding UTF8 -LiteralPath $normalizedPath | ConvertFrom-Json

            $import.Status | Should -Be "PASS"
            [int]$import.SourceCount | Should -Be 1
            [int]$import.RecordCount | Should -Be 1
            [int]$export.NotebookLMRecords | Should -Be 1
            $validation.Status | Should -Be "PASS"
            @($database.records | Where-Object { $_.id -eq "NBLM-EXAMPLE-DNS" -and $_.provenance.sourceType -eq "notebooklm_export" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $packPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $normalizedPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $importReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a NotebookLM source pack validation report" {
        $templatePath = "$script:root\templates\NOTEBOOKLM_SOURCE_PACK_TEMPLATE.json"
        $reportPath = "$script:root\logs\notebooklm-source-pack-validate.test.json"
        try {
            $json = & "$script:root\scripts\Test-NotebookLMSourcePack.ps1" `
                -InputPath $templatePath `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            [int]$result.SourceCount | Should -Be 1
            [int]$result.RecordCount | Should -Be 1
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            @($report.Checks | Where-Object { $_.Name -eq "diagnostic-signals" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "reports real data import readiness as waiting when intake is empty" {
        $intakeRoot = "$script:root\logs\real-data-intake-empty-test"
        $reportPath = "$script:root\logs\real-data-import-readiness.empty.test.json"
        try {
            $json = & "$script:root\scripts\Test-RealDataImportReadiness.ps1" `
                -IntakeRoot $intakeRoot `
                -CreateDirectories `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "WAITING"
            $result.CandidateCount | Should -Be 0
            $report.Status | Should -Be "WAITING"
            Test-Path -LiteralPath "$intakeRoot\notebooklm" | Should -BeTrue
            Test-Path -LiteralPath "$intakeRoot\external-diagnostics" | Should -BeTrue
            Test-Path -LiteralPath "$intakeRoot\official-diagnostics" | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $intakeRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "reports real data import readiness as pass when valid candidates exist" {
        $intakeRoot = "$script:root\logs\real-data-intake-ready-test"
        $reportPath = "$script:root\logs\real-data-import-readiness.ready.test.json"
        try {
            New-Item -Path "$intakeRoot\notebooklm" -ItemType Directory -Force | Out-Null
            New-Item -Path "$intakeRoot\external-diagnostics" -ItemType Directory -Force | Out-Null
            Copy-Item -LiteralPath "$script:root\templates\NOTEBOOKLM_SOURCE_PACK_TEMPLATE.json" -Destination "$intakeRoot\notebooklm\source-pack.json" -Force
            Copy-Item -LiteralPath "$script:root\templates\EXTERNAL_DIAGNOSTICS_PACK_TEMPLATE.json" -Destination "$intakeRoot\external-diagnostics\external-pack.json" -Force

            $json = & "$script:root\scripts\Test-RealDataImportReadiness.ps1" `
                -IntakeRoot $intakeRoot `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            [int]$result.ReadyCount | Should -Be 2
            @($result.Candidates | Where-Object { $_.Type -eq "notebooklm" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($result.Candidates | Where-Object { $_.Type -eq "external-diagnostics" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $intakeRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\real-data-import-readiness" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "reports task handoff archive readiness without modifying the handoff" {
        $reportPath = "$script:root\logs\task-handoff-archive-readiness.test.json"
        try {
            $json = & "$script:root\scripts\Test-TaskHandoffArchiveReadiness.ps1" `
                -ThresholdLines 9999 `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "WAITING"
            [int]$result.LineCount | Should -BeGreaterThan 0
            [int]$result.ThresholdLines | Should -Be 9999
            $report.Status | Should -Be "WAITING"
            @($report.Checks | Where-Object { $_.Name -eq "latest-status-at-top" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "flags task handoff archive action when the threshold is exceeded" {
        $json = & "$script:root\scripts\Test-TaskHandoffArchiveReadiness.ps1" `
            -ThresholdLines 1 `
            -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "ACTION_REQUIRED"
        [int]$result.ArchiveCandidateSectionCount | Should -BeGreaterThan 0
        $result.ProposedArchivePath | Should -Match "TASK_HANDOFF-"
    }

    It "captures unknown errors into learned KB without enabling auto repair" {
        $learnedFile = "$script:root\knowledge_base\learned\LEARN-0xE0FFTEST.md"
        $offlinePath = "$script:root\offline_database\windowsdoctor-kb.unknown-test.json"
        $normalizedPath = "$script:root\offline_database\windowsdoctor-kb-normalized.unknown-test.json"
        $reportPath = "$script:root\logs\unknown-error-capture.test.json"
        try {
            Remove-Item -LiteralPath $learnedFile -Force -ErrorAction SilentlyContinue
            $json = & "$script:root\scripts\Capture-UnknownErrorToKB.ps1" `
                -Title "Unknown test error" `
                -ErrorCode "0xE0FFTEST" `
                -Description "Unknown test error must not enable auto repair." `
                -OfflineDatabasePath $offlinePath `
                -NormalizedDatabasePath $normalizedPath `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $offline = Get-Content -Raw -Encoding UTF8 -LiteralPath $offlinePath | ConvertFrom-Json
            $normalized = Get-Content -Raw -Encoding UTF8 -LiteralPath $normalizedPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.CapturedCount | Should -Be 1
            $result.Rebuilt | Should -BeTrue
            $result.OfflineValidationStatus | Should -Be "PASS"
            $result.NormalizedValidationStatus | Should -Be "PASS"
            Test-Path -LiteralPath $learnedFile | Should -BeTrue
            @($offline.rules | Where-Object { $_.id -eq "LEARN-0xE0FFTEST" -and $_.script -eq "N/A" -and $_.repairAllowed -eq $false }).Count | Should -Be 1
            @($normalized.records | Where-Object { $_.id -eq "LEARN-0xE0FFTEST" -and $_.action.actionType -eq "guided" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $learnedFile -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $offlinePath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $normalizedPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "keeps common Windows error coverage summary aligned with offline KB stats" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $database = Get-Content -Raw -Encoding UTF8 -LiteralPath "$script:root\offline_database\windowsdoctor-kb.json" | ConvertFrom-Json
        $summary = Get-Content -Raw -Encoding UTF8 -LiteralPath "$script:root\COMMON_WINDOWS_ERRORS.md"

        $summary | Should -Match "Reviewed KB rules: ``$($database.stats.totalRules)``"
        $summary | Should -Match "Allowlist .*: ``$($database.stats.autoRepairRules)``"
        $summary | Should -Match "``$($database.stats.guidedRules)``"
        $summary | Should -Match "SYSTEM_MAINTENANCE"
        $summary | Should -Match "(?s)``$($database.stats.totalRules)``.*``$($database.stats.autoRepairRules)``.*``$($database.stats.guidedRules)``"
    }

    It "validates documentation synchronization without starting services" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $json = & "$script:root\scripts\Test-DocumentationSync.ps1" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        @($result.Checks | Where-Object { $_.Name -eq "operations-baseline-report" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
    }

    It "writes a documentation synchronization report" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $reportPath = "$script:root\logs\documentation-sync.test.json"
        try {
            $json = & "$script:root\scripts\Test-DocumentationSync.ps1" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Checks | Where-Object { $_.Name -eq "handoff-current-maintenance-trigger" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "exports offline KB text as readable UTF-8 Traditional Chinese" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $database = Get-Content -Raw -Encoding UTF8 -LiteralPath "$script:root\offline_database\windowsdoctor-kb.json" | ConvertFrom-Json
        $rule = $database.rules | Where-Object { $_.id -eq "RULE-SMB-0x0035" } | Select-Object -First 1
        $expectedTitle = [string]::Concat([char[]](0x7db2, 0x8def, 0x5171, 0x7528, 0x786c, 0x789f, 0x9023, 0x7dda, 0x5931, 0x6557))
        $expectedTrigger = [string]::Concat([char[]](0x627e, 0x4e0d, 0x5230, 0x7db2, 0x8def, 0x8def, 0x5f91))

        $rule | Should -Not -BeNullOrEmpty
        $rule.title | Should -Be $expectedTitle
        @($rule.triggers | Where-Object { $_ -eq $expectedTrigger }).Count | Should -Be 1
        $rule.details | Should -Match "SMB 0x80070035"
    }

    It "searches offline KB by error code" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $json = & "$script:root\scripts\Search-OfflineKB.ps1" -Query "0x80070035" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.MatchCount | Should -BeGreaterThan 0
        @($result.Matches | Where-Object { $_.id -eq "RULE-SMB-0x0035" }).Count | Should -BeGreaterThan 0
    }

    It "writes an offline KB search report" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $reportPath = "$script:root\logs\offline-kb-search.test.json"
        try {
            $json = & "$script:root\scripts\Search-OfflineKB.ps1" `
                -Query "SYSTEM_MAINTENANCE" `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Matches | Where-Object { $_.id -eq "RULE-SYS-MAINTENANCE" }).Count | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "searches offline KB for Windows maintenance" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $json = & "$script:root\scripts\Search-OfflineKB.ps1" -Query "SYSTEM_MAINTENANCE" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.MatchCount | Should -BeGreaterThan 0
        @($result.Matches | Where-Object { $_.id -eq "RULE-SYS-MAINTENANCE" -and $_.script -eq "Repair-SystemMaintenance.bat" }).Count | Should -BeGreaterThan 0
    }

    It "lists offline KB categories" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $json = & "$script:root\scripts\Search-OfflineKB.ps1" -ListCategories -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "categories"
        $result.CategoryCount | Should -BeGreaterThan 0
        @($result.Categories | Where-Object { $_.category -eq "reviewed" }).Count | Should -BeGreaterThan 0
    }

    It "writes an offline KB categories report" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $reportPath = "$script:root\logs\offline-kb-categories.test.json"
        try {
            $json = & "$script:root\scripts\Search-OfflineKB.ps1" `
                -ListCategories `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Mode | Should -Be "categories"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Categories | Where-Object { $_.category -eq "reviewed" }).Count | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "shows offline KB rule details by id" {
        & "$script:root\scripts\Export-OfflineKBDatabase.ps1" | Out-Null
        $json = & "$script:root\scripts\Search-OfflineKB.ps1" -RuleId "RULE-SMB-0x0035" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "details"
        $result.MatchCount | Should -Be 1
        $result.Matches[0].id | Should -Be "RULE-SMB-0x0035"
        $result.Matches[0].details | Should -Not -BeNullOrEmpty
    }

    It "lists WinPE offline menu allowlisted repairs" {
        $json = & "$script:root\scripts\Start-WinPEOfflineMenu.ps1" -ListAllowedRepairs -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "list"
        $result.Count | Should -BeGreaterThan 0
        @($result.Repairs | Where-Object { $_.name -eq "Repair-NetworkStack.bat" -and $_.exists -eq $true }).Count | Should -BeGreaterThan 0
    }

    It "previews only allowlisted WinPE repair scripts" {
        $json = & "$script:root\scripts\Start-WinPEOfflineMenu.ps1" -PreviewRepair "Repair-NetworkStack.bat" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "preview"
        $result.Repair.name | Should -Be "Repair-NetworkStack.bat"
        $result.Content | Should -Match "netsh"
    }

    It "keeps the offline menu user interface localized to Traditional Chinese" {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath "$script:root\scripts\Start-WinPEOfflineMenu.ps1"

        $content | Should -Match "function New-UiText"
        $content | Should -Match "0x96e2,0x7dda,0x4fee,0x5fa9,0x9078,0x55ae"
        $content | Should -Match "0x67e5,0x8a62,0x96e2,0x7dda,0x6545,0x969c,0x8cc7,0x6599,0x5eab"
        $content | Should -Match "0x8acb,0x8f38,0x5165,0x932f,0x8aa4,0x78bc,0x6216,0x95dc,0x9375,0x5b57"
        $content | Should -Match "0x6309,0x0020,0x0045,0x006e,0x0074,0x0065,0x0072,0x0020,0x8fd4,0x56de,0x9078,0x55ae"
        $content | Should -Match "0x6383,0x63cf,0x672c,0x6a5f,0x7cfb,0x7d71,0x8207,0x7db2,0x8def,0x932f,0x8aa4"
        $content | Should -Match "0x57f7,0x884c,0x53ef,0x651c,0x7248,0x81ea,0x6211,0x6aa2,0x6e2c"
        $content | Should -Match "0x986f,0x793a,0x7248,0x672c,0x8207,0x72c0,0x614b,0x6458,0x8981"
        $content | Should -Match "0x4e00,0x9375,0x6383,0x63cf,0x4e26,0x5efa,0x8b70,0x4fee,0x5fa9"
        $content | Should -Not -Match "Search offline KB"
        $content | Should -Not -Match "Press Enter"
    }

    It "scans local system and network diagnostics without repairing" {
        $reportPath = "$script:root\logs\system-error-scan.test.json"
        try {
            $json = & "$script:root\scripts\Test-SystemErrorScan.ps1" `
                -RecentHours 1 `
                -MaxEvents 20 `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -BeIn @("PASS", "WARN")
            $result.ReportPath | Should -Be $reportPath
            $result.KbAvailable | Should -BeTrue
            [int]$result.KbRuleCount | Should -BeGreaterOrEqual 60
            [int]$result.KbMatchCount | Should -BeGreaterThan 0
            $report.ReportPath | Should -Be $reportPath
            @($report.Findings | Where-Object { $_.Name -eq "network-adapters" }).Count | Should -Be 1
            @($report.Findings | Where-Object { $_.Name -eq "dns-client" }).Count | Should -Be 1
            @($report.Findings | Where-Object { $_.KbMatchCount -gt 0 }).Count | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "analyzes Windows event logs into MIS-readable findings without repairing" {
        $inputPath = "$script:root\logs\event-log-analysis.sample.test.json"
        $reportPath = "$script:root\logs\event-log-analysis.test.json"
        $csvPath = "$script:root\logs\event-log-analysis.test.csv"
        try {
            @{
                events = @(
                    @{
                        TimeCreated = "2026-05-17T10:00:00"
                        LogName = "System"
                        ProviderName = "Microsoft-Windows-DistributedCOM"
                        Id = 10016
                        Level = 3
                        LevelDisplayName = "Warning"
                        MachineName = "TEST-PC"
                        Message = "DistributedCOM 10016 Local Activation permission warning"
                    },
                    @{
                        TimeCreated = "2026-05-17T10:05:00"
                        LogName = "System"
                        ProviderName = "Service Control Manager"
                        Id = 7031
                        Level = 2
                        LevelDisplayName = "Error"
                        MachineName = "TEST-PC"
                        Message = "The service terminated unexpectedly"
                    }
                )
            } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -LiteralPath $inputPath

            $json = & "$script:root\scripts\Analyze-WindowsEventLogs.ps1" `
                -InputPath $inputPath `
                -ReportPath $reportPath `
                -CsvPath $csvPath `
                -MaxEvents 10 `
                -Top 5 `
                -Json
            $result = $json | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.SafetyPolicy.ReadOnly | Should -BeTrue
            $result.SafetyPolicy.NoRepairExecuted | Should -BeTrue
            [int]$result.EventCount | Should -Be 2
            [int]$result.Summary.KbMatchedCount | Should -BeGreaterThan 0
            @($result.ProviderSummary).Count | Should -BeGreaterThan 0
            Test-Path -LiteralPath $reportPath | Should -BeTrue
            Test-Path -LiteralPath $csvPath | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $csvPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "packages repair tools only after manifest and SHA256 validation" {
        $inputRoot = "$script:root\logs\repair-tool-package-test-input"
        $outputRoot = "$script:root\logs\repair-tool-package-test-output"
        $manifestPath = Join-Path $inputRoot "manifest.json"
        $toolFile = Join-Path $inputRoot "tools\dummy-tool.txt"
        $validateReport = "$script:root\logs\repair-tool-package-manifest.test.json"
        $packageReport = "$script:root\logs\repair-tool-package.test.json"
        try {
            New-Item -Path (Split-Path -Parent $toolFile) -ItemType Directory -Force | Out-Null
            Set-Content -LiteralPath $toolFile -Encoding UTF8 -Value "WindowsDoctor dummy diagnostic tool"
            $hash = (Get-FileHash -LiteralPath $toolFile -Algorithm SHA256).Hash.ToLowerInvariant()
            @{
                schemaVersion = 1
                packageId = "test-repair-tools"
                packageName = "Test Repair Tools"
                tools = @(
                    @{
                        id = "dummy-tool"
                        name = "Dummy Diagnostic Tool"
                        version = "1.0.0"
                        publisher = "Microsoft"
                        sourceUrl = "https://learn.microsoft.com/windows/"
                        sourceTrustLevel = "microsoft_official"
                        expectedSha256 = $hash
                        license = "test"
                        allowedUse = "diagnostic evidence only"
                        executionPolicy = "diagnostic_only"
                        autoRunAllowed = $false
                        files = @(@{ relativePath = "tools\dummy-tool.txt"; expectedSha256 = $hash })
                    }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $manifestPath

            $validationJson = & "$script:root\scripts\Test-RepairToolPackageManifest.ps1" -ManifestPath $manifestPath -InputRoot $inputRoot -ReportPath $validateReport -Json
            $validation = $validationJson | ConvertFrom-Json
            $validation.Status | Should -Be "PASS"
            $validation.SafetyPolicy.NoInstall | Should -BeTrue
            $validation.SafetyPolicy.NoExecute | Should -BeTrue

            $packageJson = & "$script:root\scripts\New-RepairToolPackage.ps1" -ManifestPath $manifestPath -InputRoot $inputRoot -OutputRoot $outputRoot -ReportPath $packageReport -Json
            $package = $packageJson | ConvertFrom-Json
            $package.Status | Should -Be "PASS"
            $package.SafetyPolicy.NoInstall | Should -BeTrue
            $package.SafetyPolicy.NoExecute | Should -BeTrue
            $package.SafetyPolicy.RepairAllowlistUpdated | Should -BeFalse
            [int]$package.FileCount | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $inputRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validateReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $packageReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$packageReport.validation.json" -Force -ErrorAction SilentlyContinue
        }
    }

    It "keeps typo-compatible system scan entrypoints working" {
        $json = & "$script:root\scripts\Test-SystemErroeScan.ps1" `
            -RecentHours 1 `
            -MaxEvents 20 `
            -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -BeIn @("PASS", "WARN")
        $result.DatabasePath | Should -Match "windowsdoctor-kb\.json"
        [int]$result.KbRuleCount | Should -BeGreaterOrEqual 60

        $jsonPlural = & "$script:root\scripts\Test-SystemErrorsScan.ps1" `
            -RecentHours 1 `
            -MaxEvents 20 `
            -Json
        $resultPlural = $jsonPlural | ConvertFrom-Json

        $resultPlural.Status | Should -BeIn @("PASS", "WARN")
        [int]$resultPlural.KbRuleCount | Should -BeGreaterOrEqual 60
    }

    It "reports portable runtime status without starting services" {
        $reportPath = "$script:root\logs\portable-runtime-status.test.json"
        try {
            $json = & "$script:root\scripts\Get-PortableRuntimeStatus.ps1" `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Phase | Should -Be "portable-usb"
            $result.InstallerPhase | Should -Be "deferred"
            [int]$result.TotalRules | Should -BeGreaterOrEqual 60
            [int]$result.AllowlistRepairs | Should -BeGreaterOrEqual 6
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a WinPE offline menu portable status report" {
        $reportPath = "$script:root\logs\winpe-menu-status.test.json"
        try {
            $json = & "$script:root\scripts\Start-WinPEOfflineMenu.ps1" -StatusSummary -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            [int]$result.TotalRules | Should -BeGreaterOrEqual 60
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "previews recommended repairs without executing them" {
        $reportPath = "$script:root\logs\recommended-repair-plan.test.json"
        try {
            $json = & "$script:root\scripts\Invoke-RecommendedRepairPlan.ps1" `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Mode | Should -Be "preview"
            [bool]$result.Executed | Should -BeFalse
            $result.RepairPlanVersion | Should -Be 4
            $result.DecisionEngineVersion | Should -Be 4
            $result.RepairPlanScoring.SafeBatchPolicy | Should -Match "policy-approved"
            [bool]$result.SafeBatchExecutionPolicy.StopOnFirstFailure | Should -BeTrue
            $result.SafeBatchExecutionPolicy.AutoBatchReviewStatusRequired | Should -Be "APPROVED"
            $result.OperatorGuidance.EvidenceScoring | Should -Match "Confidence combines"
            $result.OperatorGuidance.DryRunImpact | Should -Match "does not execute"
            $result.OperatorGuidance.RunGate | Should -Match "RUN"
            $result.OperatorGuidance.RollbackGuidance | Should -Match "restore"
            [int]$result.ActiveRecommendedRepairCount | Should -BeGreaterOrEqual 0
            [int]$result.ObservationCount | Should -BeGreaterOrEqual 0
            @($result.PrioritizedRecommendations | Where-Object { $_.PSObject.Properties.Name -contains "Confidence" }).Count | Should -Be @($result.PrioritizedRecommendations).Count
            @($result.PrioritizedRecommendations | Where-Object { $_.PSObject.Properties.Name -contains "RiskLevel" }).Count | Should -Be @($result.PrioritizedRecommendations).Count
            @($result.PrioritizedRecommendations | Where-Object { $_.PSObject.Properties.Name -contains "RecommendationState" }).Count | Should -Be @($result.PrioritizedRecommendations).Count
            @($result.PrioritizedRecommendations | Where-Object { $_.PSObject.Properties.Name -contains "RepairDecisionState" }).Count | Should -Be @($result.PrioritizedRecommendations).Count
            @($result.PrioritizedRecommendations | Where-Object { $_.PSObject.Properties.Name -contains "AutoRepairSafety" }).Count | Should -Be @($result.PrioritizedRecommendations).Count
            @($result.PrioritizedRecommendations | Where-Object { $_.AutoRepairSafety.RunGateRequired -ne $true }).Count | Should -Be 0
            @($result.SafeRecommendations | Where-Object { $_.RecommendationState -ne "recommended" }).Count | Should -Be 0
            @($result.SafeRecommendations | Where-Object { $_.AutoBatchEligible -ne $true }).Count | Should -Be 0
            @($result.SafeBatchScripts | Where-Object { $_ -eq "Repair-BCDBoot.bat" }).Count | Should -Be 0
            @($result.SafeBatchScripts | Where-Object { $_ -eq "Repair-SystemIntegrity.bat" }).Count | Should -Be 0
            @($result.SafeBatchScripts | Where-Object { $_ -eq "Repair-SystemMaintenance.bat" }).Count | Should -Be 0
            @($result.SafeBatchScripts | Where-Object { $_ -eq "Repair-WUSoftwareDistribution.bat" }).Count | Should -Be 0
            $report.ReportPath | Should -Be $reportPath
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "rejects recommended repair execution without confirmation" {
        {
            & "$script:root\scripts\Invoke-RecommendedRepairPlan.ps1" -Execute -Json
        } | Should -Throw
    }

    It "previews recommended repairs through the offline menu" {
        $json = & "$script:root\scripts\Start-WinPEOfflineMenu.ps1" -RecommendedRepair -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "preview"
        [bool]$result.Executed | Should -BeFalse
    }

    It "runs the portable runtime self-test without repairing" {
        $reportPath = "$script:root\logs\portable-runtime-self-test.test.json"
        try {
            $json = & "$script:root\scripts\Test-PortableRuntimeSelfTest.ps1" `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            @($report.Checks | Where-Object { $_.Name -eq "offline-db-validation" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Name -eq "system-network-scan" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Name -eq "scan-kb-matching" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Name -eq "portable-status-summary" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Checks | Where-Object { $_.Name -eq "recommended-repair-preview" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a WinPE offline menu allowlisted repair list report" {
        $reportPath = "$script:root\logs\winpe-menu-repairs.test.json"
        try {
            $json = & "$script:root\scripts\Start-WinPEOfflineMenu.ps1" -ListAllowedRepairs -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Mode | Should -Be "list"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Repairs | Where-Object { $_.name -eq "Repair-NetworkStack.bat" -and $_.exists -eq $true }).Count | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a WinPE offline menu repair preview report without executing it" {
        $reportPath = "$script:root\logs\winpe-menu-preview.test.json"
        try {
            $json = & "$script:root\scripts\Start-WinPEOfflineMenu.ps1" -PreviewRepair "Repair-SystemMaintenance.bat" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Mode | Should -Be "preview"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $report.Content | Should -Match "Invoke-WindowsMaintenance.ps1"
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "previews allowlisted repairs through the standalone wrapper" {
        $json = & "$script:root\scripts\Invoke-AllowedRepair.ps1" -ScriptName "Repair-NetworkStack.bat" -Preview -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "preview"
        $result.Command | Should -Match "Repair-NetworkStack.bat"
        $result.Content | Should -Match "netsh"
    }

    It "writes an allowlisted repair list report" {
        $reportPath = "$script:root\logs\allowed-repair-list.test.json"
        try {
            $json = & "$script:root\scripts\Invoke-AllowedRepair.ps1" `
                -List `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Mode | Should -Be "list"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Repairs | Where-Object { $_.name -eq "Repair-NetworkStack.bat" -and $_.exists -eq $true }).Count | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes an allowlisted repair preview report without executing it" {
        $reportPath = "$script:root\logs\allowed-repair-preview.test.json"
        try {
            $json = & "$script:root\scripts\Invoke-AllowedRepair.ps1" `
                -ScriptName "Repair-SystemMaintenance.bat" `
                -Preview `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.Mode | Should -Be "preview"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $report.Content | Should -Match "Invoke-WindowsMaintenance.ps1"
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "previews Windows maintenance without executing destructive actions" {
        $json = & "$script:root\scripts\Invoke-WindowsMaintenance.ps1" `
            -Preview `
            -ForceLogoffDisconnectedUsers `
            -CleanDisk `
            -ReleaseMemory `
            -SystemMaintenance `
            -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "preview"
        [bool]$result.Executed | Should -BeFalse
        @($result.Actions | Where-Object { $_.Name -eq "force-logoff-disconnected-users" }).Count | Should -Be 1
        @($result.Actions | Where-Object { $_.Name -eq "clean-disk-space" }).Count | Should -Be 1
        @($result.Actions | Where-Object { $_.Name -eq "system-maintenance" }).Count | Should -Be 1
    }

    It "writes a Windows maintenance preview report" {
        $reportPath = "$script:root\logs\windows-maintenance.preview.test.json"
        try {
            $json = & "$script:root\scripts\Invoke-WindowsMaintenance.ps1" `
                -Preview `
                -CleanDisk `
                -ReleaseMemory `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.Mode | Should -Be "preview"
            [bool]$report.Executed | Should -BeFalse
            @($report.Actions | Where-Object { $_.Name -eq "clean-disk-space" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "requires confirmation before executing Windows maintenance" {
        {
            & "$script:root\scripts\Invoke-WindowsMaintenance.ps1" -Execute -CleanDisk -Json
        } | Should -Throw
    }

    It "exposes Windows maintenance through the repair allowlist as preview" {
        $json = & "$script:root\scripts\Invoke-AllowedRepair.ps1" -ScriptName "Repair-SystemMaintenance.bat" -Preview -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Mode | Should -Be "preview"
        $result.Repair.name | Should -Be "Repair-SystemMaintenance.bat"
        $result.Content | Should -Match "Invoke-WindowsMaintenance.ps1"
    }

    It "rejects repairs outside the allowlist" {
        {
            & "$script:root\scripts\Invoke-AllowedRepair.ps1" -ScriptName "Repair-NotAllowed.bat" -Preview -Json
        } | Should -Throw
    }

    It "checks WinPE media readiness with menu startup mode" {
        $output = & "$script:root\scripts\Build-WinPEMedia.ps1" -CheckOnly | Out-String

        $output | Should -Match "Status\s+: Ready"
        $output | Should -Match "StartupMode\s+: Menu"
        $output | Should -Match "OfflineDbPath\s+:"
    }

    It "writes a WinPE media check-only report without building media" {
        $reportPath = "$script:root\logs\winpe-media-checkonly.test.json"
        try {
            $json = & "$script:root\scripts\Build-WinPEMedia.ps1" -CheckOnly -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "Ready"
            $result.StartupMode | Should -Be "Menu"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "Ready"
            $report.ReportPath | Should -Be $reportPath
            $report.OfflineDbPath | Should -Match "windowsdoctor-kb\.json"
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "generates WinPE startnet content for menu startup" {
        $json = & "$script:root\scripts\New-WinPEStartNet.ps1" -StartupMode Menu -Json
        $result = $json | ConvertFrom-Json
        $content = @($result.Lines) -join "`n"

        $result.Status | Should -Be "PASS"
        $result.StartupMode | Should -Be "Menu"
        $content | Should -Match "WD_USE_OFFLINE_DB=1"
        $content | Should -Match "Start-WinPEOfflineMenu.ps1"
        $content | Should -Not -Match "broker.js"
    }

    It "generates WinPE startnet content for broker startup" {
        $json = & "$script:root\scripts\New-WinPEStartNet.ps1" -StartupMode Broker -Json
        $result = $json | ConvertFrom-Json
        $content = @($result.Lines) -join "`n"

        $result.Status | Should -Be "PASS"
        $result.StartupMode | Should -Be "Broker"
        $content | Should -Match "WD_USE_OFFLINE_DB=1"
        $content | Should -Match "broker.js"
        $content | Should -Not -Match "Start-WinPEOfflineMenu.ps1"
    }

    It "writes a WinPE startnet preview report without starting services" {
        $reportPath = "$script:root\logs\winpe-startnet.test.json"
        try {
            $json = & "$script:root\scripts\New-WinPEStartNet.ps1" -StartupMode Menu -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json
            $content = @($report.Lines) -join "`n"

            $result.Status | Should -Be "PASS"
            $result.StartupMode | Should -Be "Menu"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $content | Should -Match "WD_USE_OFFLINE_DB=1"
            $content | Should -Match "Start-WinPEOfflineMenu.ps1"
            $content | Should -Not -Match "broker.js"
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "generates a continuation prompt without starting services" {
        $outputPath = "$script:root\NEXT_CHAT_PROMPT.test.md"
        try {
            $json = & "$script:root\scripts\New-ContinuationPrompt.ps1" -OutputPath $outputPath -SkipResourceSnapshot -Json
            $result = $json | ConvertFrom-Json
            $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $outputPath

            $result.Status | Should -Be "PASS"
            $result.OutputPath | Should -Be $outputPath
            $result.ResourceSnapshotIncluded | Should -BeFalse
            $content | Should -Match "Test-ResourceSafety.ps1 -Json"
            $content | Should -Match "TASK_HANDOFF.md"
            $content | Should -Match "GUI/Broker"
            $content | Should -Match "production build"
        }
        finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes a continuation prompt report without copying to clipboard" {
        $outputPath = "$script:root\NEXT_CHAT_PROMPT.report-test.md"
        $reportPath = "$script:root\logs\continuation-prompt.test.json"
        try {
            $json = & "$script:root\scripts\New-ContinuationPrompt.ps1" `
                -OutputPath $outputPath `
                -ReportPath $reportPath `
                -SkipResourceSnapshot `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.OutputPath | Should -Be $outputPath
            $result.CopiedToClipboard | Should -BeFalse
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $report.ResourceSnapshotIncluded | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates the WinPE offline flow without starting services" {
        $json = & "$script:root\scripts\Test-WinPEOfflineFlow.ps1" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        @($result.Steps).Count | Should -BeGreaterThan 8
        @($result.Steps | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        @($result.Steps | Where-Object { $_.Name -eq "winpe-checkonly" -and $_.Status -eq "PASS" }).Count | Should -Be 1
    }

    It "writes a WinPE offline flow report without starting services" {
        $reportPath = "$script:root\logs\winpe-offline-flow.test.json"
        try {
            $json = & "$script:root\scripts\Test-WinPEOfflineFlow.ps1" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Steps | Where-Object { $_.Name -eq "offline-kb-maintenance-search" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates portable USB readiness without writing media" {
        $json = & "$script:root\scripts\Test-PortableUsbReadiness.ps1" -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Phase | Should -Be "portable-usb"
        $result.InstallerPhase | Should -Be "deferred"
        @($result.Steps | Where-Object { $_.Name -eq "winpe-media-checkonly-menu" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Name -eq "services-remain-offline" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Name -eq "system-network-scan" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Name -eq "portable-runtime-self-test" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
    }

    It "writes a portable USB readiness report without writing media" {
        $reportPath = "$script:root\logs\portable-usb-readiness.test.json"
        try {
            $json = & "$script:root\scripts\Test-PortableUsbReadiness.ps1" -ReportPath $reportPath -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            $report.Phase | Should -Be "portable-usb"
            @($report.Steps | Where-Object { $_.Name -eq "portable-release-order" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "creates and validates a lightweight portable USB payload" {
        $outputRoot = "$script:root\logs\portable-usb-payload-test"
        $payloadReport = "$script:root\logs\portable-usb-payload.test.json"
        $validationReport = "$script:root\logs\portable-usb-payload-validate.test.json"
        try {
            $json = & "$script:root\scripts\New-PortableUsbPayload.ps1" `
                -OutputRoot $outputRoot `
                -PackageName "payload" `
                -SkipNodeModules `
                -ReportPath $payloadReport `
                -Json
            $payload = $json | ConvertFrom-Json
            $validationJson = & "$script:root\scripts\Test-PortableUsbPayload.ps1" `
                -PackageRoot $payload.PackageRoot `
                -ReportPath $validationReport `
                -Json
            $validation = $validationJson | ConvertFrom-Json

            $payload.Status | Should -Be "PASS"
            $payload.Phase | Should -Be "portable-usb"
            $payload.InstallerPhase | Should -Be "deferred"
            [bool]$payload.SkipNodeModules | Should -BeTrue
            Test-Path -LiteralPath $payload.Launcher | Should -BeTrue
            $validation.Status | Should -Be "PASS"
            @($validation.Checks | Where-Object { $_.Name -eq "no-next-build-cache" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $payloadReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validationReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates a portable USB release package without executing repairs" {
        $outputRoot = "$script:root\logs\portable-usb-release-validation-test"
        $payloadReport = "$script:root\logs\portable-usb-release-validation-payload.test.json"
        $releaseReport = "$script:root\logs\portable-usb-release-validation.test.json"
        $zipReport = "$script:root\logs\portable-usb-release-validation-zip.test.json"
        $zipHashReport = "$script:root\logs\portable-usb-release-validation-zip-hash.test.json"
        $zipPath = "$script:root\logs\release-validation.zip"
        try {
            $json = & "$script:root\scripts\New-PortableUsbPayload.ps1" `
                -OutputRoot $outputRoot `
                -PackageName "release-validation" `
                -SkipNodeModules `
                -ReportPath $payloadReport `
                -Json
            $payload = $json | ConvertFrom-Json
            Compress-Archive -LiteralPath $payload.PackageRoot -DestinationPath $zipPath -CompressionLevel Fastest -Force
            $zipJson = & "$script:root\scripts\Test-PortableUsbZipManifest.ps1" `
                -ZipPath $zipPath `
                -PackageRoot $payload.PackageRoot `
                -ReportPath $zipReport `
                -Json
            $zip = $zipJson | ConvertFrom-Json
            $zipHashJson = & "$script:root\scripts\Test-PortableUsbZipManifest.ps1" `
                -ZipPath $zipPath `
                -PackageRoot $payload.PackageRoot `
                -ReportPath $zipHashReport `
                -Hash `
                -Json
            $zipHash = $zipHashJson | ConvertFrom-Json
            $validationJson = & "$script:root\scripts\Test-PortableUsbReleaseValidation.ps1" `
                -PackageRoot $payload.PackageRoot `
                -ZipPath $zipPath `
                -ReportPath $releaseReport `
                -Json
            $validation = $validationJson | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $releaseReport | ConvertFrom-Json

            $zip.Status | Should -Be "PASS"
            [int]$zip.MissingCount | Should -Be 0
            [int]$zip.SizeMismatchCount | Should -Be 0
            $zipHash.Status | Should -Be "PASS"
            [bool]$zipHash.HashEnabled | Should -BeTrue
            [int]$zipHash.HashComparedCount | Should -BeGreaterThan 0
            [int]$zipHash.HashMismatchCount | Should -Be 0
            $validation.Status | Should -Be "PASS"
            $validation.ReportPath | Should -Be $releaseReport
            $report.Status | Should -Be "PASS"
            @($report.Steps | Where-Object { $_.Name -eq "zip-manifest" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Name -eq "payload-validation" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Name -eq "runtime-self-test" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Name -eq "recommended-repair-preview" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $payloadReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $releaseReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $zipReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $zipHashReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-release-payload.json" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-release-runtime-self-test.json" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-release-recommended-repair.json" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-release-zip-manifest.json" -Force -ErrorAction SilentlyContinue
        }
    }

    It "publishes a lightweight portable USB package by zip and expand flow" {
        $usbRoot = "$script:root\logs\portable-usb-publish-target"
        $reportPath = "$script:root\logs\portable-usb-publish.test.json"
        $resumeReportPath = "$script:root\logs\portable-usb-publish-resume.test.json"
        $acceptanceReport = "$script:root\logs\portable-usb-acceptance.test.json"
        $summaryReport = "$script:root\logs\portable-usb-acceptance-summary.test.json"
        try {
            New-Item -Path $usbRoot -ItemType Directory -Force | Out-Null
            $json = & "$script:root\scripts\Publish-PortableUsbPackage.ps1" `
                -USBPath $usbRoot `
                -PackageName "publish-test" `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json
            $acceptanceJson = & "$script:root\scripts\Invoke-PortableUsbAcceptance.ps1" `
                -PackageRoot $result.TargetPackageRoot `
                -ZipPath $result.ZipPath `
                -UsbRoot $usbRoot `
                -ReportPath $acceptanceReport `
                -MinFreeMemoryGB 0 `
                -SkipGuiReadyPreflight `
                -Json
            $acceptance = $acceptanceJson | ConvertFrom-Json
            $summaryJson = & "$script:root\scripts\Invoke-PortableUsbAcceptance.ps1" `
                -PackageRoot $result.TargetPackageRoot `
                -ZipPath $result.ZipPath `
                -UsbRoot $usbRoot `
                -ReportPath $summaryReport `
                -MinFreeMemoryGB 0 `
                -SkipGuiReadyPreflight `
                -SummaryOnly `
                -Json
            $summary = $summaryJson | ConvertFrom-Json
            $resumeJson = & "$script:root\scripts\Publish-PortableUsbPackage.ps1" `
                -USBPath $usbRoot `
                -PackageName "publish-test" `
                -ResumeExistingTarget `
                -ReportPath $resumeReportPath `
                -Json
            $resume = $resumeJson | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.CopiedByZip | Should -BeTrue
            $result.ExpandedOnUsb | Should -BeTrue
            [bool]$result.IncludeNodeModules | Should -BeFalse
            $result.ReportPath | Should -Be $reportPath
            $result.ManifestComparisonStatus | Should -Be "PASS"
            $result.ManifestComparisonReport | Should -Match "portable-usb-publish-zip-manifest\.json"
            $result.RuntimeSelfTestReport | Should -Match "portable-usb-release-runtime-self-test\.json"
            $result.RecommendedRepairPreviewReport | Should -Match "portable-usb-release-recommended-repair\.json"
            $report.Status | Should -Be "PASS"
            @($report.Steps | Where-Object { $_.Name -eq "zip-manifest" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Name -eq "usb-zip-cleanup" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            $acceptance.Status | Should -Be "PASS"
            $acceptance.Summary.Status | Should -Be "PASS"
            @($acceptance.Steps | Where-Object { $_.Name -eq "zip-manifest" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($acceptance.Steps | Where-Object { $_.Name -eq "release-validation" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            $summary.Status | Should -Be "PASS"
            $summary.StepCount | Should -BeGreaterThan 0
            $summary.ReleaseValidation | Should -Be "PASS"
            $resume.Status | Should -Be "PASS"
            [bool]$resume.ResumeExistingTarget | Should -BeTrue
            @($resume.Steps | Where-Object { $_.Name -eq "target-existing" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            Test-Path -LiteralPath "$usbRoot\publish-test\Start-WindowsDoctor-Portable.cmd" | Should -BeTrue
            Test-Path -LiteralPath "$usbRoot\publish-test.zip" | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $usbRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $resumeReportPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $acceptanceReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $summaryReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\releases\portable-usb\publish-test" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\releases\portable-usb\publish-test.zip" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-publish-payload.json" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-publish-zip-manifest.json" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\portable-usb-publish-validate.json" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$script:root\logs\usb-package-selector.latest.json" -Force -ErrorAction SilentlyContinue
        }
    }

    It "emits machine-readable low-risk baseline JSON" {
        $json = & "$script:root\scripts\Test-SystemBaseline.ps1" `
            -SkipServiceSmoke `
            -SkipBuild `
            -SkipPester `
            -SkipLint `
            -MinFreeMemoryGB 0 `
            -Json
        $result = $json | ConvertFrom-Json

        $result.Status | Should -Be "PASS"
        $result.Root | Should -Be $script:root
        [bool]$result.SkipPester | Should -BeTrue
        [bool]$result.SkipLint | Should -BeTrue
        @($result.Steps | Where-Object { $_.Name -eq "winpe-offline-flow" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Name -eq "portable-usb-readiness" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Name -eq "documentation-sync" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        @($result.Steps | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
    }

    It "writes a machine-readable low-risk baseline report" {
        $reportPath = "$script:root\logs\system-baseline.test.json"
        try {
            $json = & "$script:root\scripts\Test-SystemBaseline.ps1" `
                -SkipServiceSmoke `
                -SkipBuild `
                -SkipPester `
                -SkipLint `
                -MinFreeMemoryGB 0 `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json
            $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.ReportPath | Should -Be $reportPath
            $report.Status | Should -Be "PASS"
            $report.ReportPath | Should -Be $reportPath
            @($report.Steps | Where-Object { $_.Name -eq "resource-safety" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            @($report.Steps | Where-Object { $_.Status -eq "FAIL" }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates and imports an external diagnostics pack as diagnostic-only evidence" {
        $templatePath = "$script:root\templates\EXTERNAL_DIAGNOSTICS_PACK_TEMPLATE.json"
        $outputPath = "$script:root\logs\external-diagnostic-sources.test.json"
        $validateReport = "$script:root\logs\external-diagnostics-pack-validate.test.json"
        $importReport = "$script:root\logs\external-diagnostics-import.test.json"
        try {
            $validationJson = & "$script:root\scripts\Test-ExternalDiagnosticsPack.ps1" `
                -InputPath $templatePath `
                -ReportPath $validateReport `
                -Json
            $validation = $validationJson | ConvertFrom-Json

            $importJson = & "$script:root\scripts\Import-ExternalDiagnosticsPack.ps1" `
                -InputPath $templatePath `
                -OutputPath $outputPath `
                -ReportPath $importReport `
                -Json
            $import = $importJson | ConvertFrom-Json
            $pack = Get-Content -Raw -Encoding UTF8 -LiteralPath $outputPath | ConvertFrom-Json

            $validation.Status | Should -Be "PASS"
            $import.Status | Should -Be "PASS"
            $import.FindingCount | Should -Be 1
            @($pack.findings | Where-Object { $_.repairAllowed -eq $false -and $_.script -eq "N/A" -and $_.actionType -eq "manual_review" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validateReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $importReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "exports and validates normalized KB with external diagnostics evidence" {
        $templatePath = "$script:root\templates\EXTERNAL_DIAGNOSTICS_PACK_TEMPLATE.json"
        $externalPath = "$script:root\logs\external-diagnostic-sources.normalized.test.json"
        $normalizedPath = "$script:root\logs\windowsdoctor-kb-normalized.external.test.json"
        $exportReport = "$script:root\logs\normalized-kb-export.external.test.json"
        $validateReport = "$script:root\logs\normalized-kb-validate.external.test.json"
        try {
            & "$script:root\scripts\Import-ExternalDiagnosticsPack.ps1" `
                -InputPath $templatePath `
                -OutputPath $externalPath `
                -Json | Out-Null

            $exportJson = & "$script:root\scripts\Export-NormalizedKBDatabase.ps1" `
                -ExternalDiagnosticsPackPath $externalPath `
                -OutputPath $normalizedPath `
                -ReportPath $exportReport `
                -Json
            $export = $exportJson | ConvertFrom-Json

            $validateJson = & "$script:root\scripts\Test-NormalizedKBDatabase.ps1" `
                -DatabasePath $normalizedPath `
                -ReportPath $validateReport `
                -Json
            $validate = $validateJson | ConvertFrom-Json

            $export.Status | Should -Be "PASS"
            $export.ExternalDiagnosticRecords | Should -Be 1
            $validate.Status | Should -Be "PASS"
            $validate.ExternalDiagnosticRecords | Should -Be 1
            @($validate.Checks | Where-Object { $_.Name -eq "external-diagnostic-safety" -and $_.Status -eq "PASS" }).Count | Should -Be 1
        }
        finally {
            Remove-Item -LiteralPath $externalPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $normalizedPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $exportReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validateReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "converts official diagnostic logs into an external diagnostics pack" {
        $packPath = "$script:root\logs\official-diagnostics-pack.test.json"
        $reportPath = "$script:root\logs\official-diagnostics-pack.test.report.json"
        $validateReport = "$script:root\logs\official-diagnostics-pack.validate.test.json"
        try {
            $json = & "$script:root\scripts\Convert-OfficialDiagnosticsToExternalPack.ps1" `
                -SetupDiagPath "$script:root\templates\SETUPDIAG_SAMPLE.log" `
                -DismLogPath "$script:root\templates\DISM_SAMPLE.log" `
                -SfcLogPath "$script:root\templates\SFC_SAMPLE.log" `
                -GetHelpPath "$script:root\templates\GETHELP_SAMPLE.log" `
                -OutputPath $packPath `
                -ReportPath $reportPath `
                -Json
            $result = $json | ConvertFrom-Json

            $validationJson = & "$script:root\scripts\Test-ExternalDiagnosticsPack.ps1" `
                -InputPath $packPath `
                -ReportPath $validateReport `
                -Json
            $validation = $validationJson | ConvertFrom-Json
            $pack = Get-Content -Raw -Encoding UTF8 -LiteralPath $packPath | ConvertFrom-Json

            $result.Status | Should -Be "PASS"
            $result.FindingCount | Should -Be 4
            $validation.Status | Should -Be "PASS"
            @($pack.findings | Where-Object { $_.adapterName -in @("setupdiag", "dism", "sfc", "gethelpcmd") }).Count | Should -Be 4
        }
        finally {
            Remove-Item -LiteralPath $packPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validateReport -Force -ErrorAction SilentlyContinue
        }
    }

    It "exports a safe Intune remediation package without executing repairs" {
        $outputRoot = "$script:root\logs\intune-remediation-package-test"
        $exportReport = "$script:root\logs\intune-remediation-export.test.json"
        $validationReport = "$script:root\logs\intune-remediation-validate.test.json"
        try {
            $json = & "$script:root\scripts\Export-IntuneRemediationPackage.ps1" `
                -OutputRoot $outputRoot `
                -PackageName "intune-test" `
                -ReportPath $exportReport `
                -Json
            $export = $json | ConvertFrom-Json

            $validationJson = & "$script:root\scripts\Test-IntuneRemediationPackage.ps1" `
                -PackageRoot $export.PackageRoot `
                -ReportPath $validationReport `
                -Json
            $validation = $validationJson | ConvertFrom-Json

            $export.Status | Should -Be "PASS"
            $export.ItemCount | Should -BeGreaterThan 0
            $validation.Status | Should -Be "PASS"
            @($validation.Checks | Where-Object { $_.Name -eq "high-risk-scripts-excluded" -and $_.Status -eq "PASS" }).Count | Should -Be 1
            $generatedScripts = Get-ChildItem -Path $export.PackageRoot -Recurse -Filter *.ps1
            @($generatedScripts).Count | Should -BeGreaterThan 0
            foreach ($scriptFile in $generatedScripts) {
                { [scriptblock]::Create((Get-Content -Raw -LiteralPath $scriptFile.FullName)) } | Should -Not -Throw
            }
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $exportReport -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $validationReport -Force -ErrorAction SilentlyContinue
        }
    }
}
