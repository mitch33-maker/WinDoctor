# WindowsDoctor Unit Tests (Pester)
# Force re-import to ensure latest changes
Import-Module "e:\WindowsDoctor\core\WindowsDoctor.psm1" -Force

Describe "WindowsDoctor Detection Module Tests" {
    Context "Get-WDSystemHealth" {
        BeforeAll {
            $script:health = Get-WDSystemHealth
        }
        
        It "Should return a health object" {
            $script:health | Should -Not -BeNullOrEmpty
        }
        
        It "Should have valid OS Caption" {
            $script:health.OS | Should -Not -BeNullOrEmpty
        }

        It "Should contain at least one Disk" {
            $script:health.Disks.Count | Should -BeGreaterThan 0
        }
    }

    Context "Get-WDEventLogSummary" {
        It "Should not throw error when scanning logs" {
            { Get-WDEventLogSummary -Hours 1 } | Should -Not -Throw
        }
    }
}
