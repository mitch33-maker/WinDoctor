# WindowsDoctor Rescue Media Builder
# This script creates a custom WinPE/WinRE ISO with WindowsDoctor pre-installed.

Import-Module "e:\WindowsDoctor\core\WindowsDoctor.psm1" -Force

function New-WDRescueMedia {
    [CmdletBinding()]
    param(
        [string]$WorkingDir = "e:\WindowsDoctor\build\pe",
        [string]$OutputIso = "e:\WindowsDoctor\WindowsDoctor_Rescue.iso"
    )
    process {
        Write-Host ">>> Starting WindowsDoctor Rescue Media Build..." -ForegroundColor Blue
        
        # 1. Environment Preparation
        if (-not (Test-WDAdmin)) { throw "Required: Administrator Privileges" }
        if (Test-Path $WorkingDir) { Remove-Item $WorkingDir -Recurse -Force }
        New-Item -ItemType Directory -Path "$WorkingDir\mount" -Force | Out-Null
        
        # 2. Locate WinRE.wim (The heart of our rescue disk)
        # Attempt to copy from local recovery partition if possible
        $winrePath = "C:\Windows\System32\Recovery\Winre.wim"
        if (-not (Test-Path $winrePath)) {
            Write-Host "Searching for WinRE.wim in Recovery Partitions..."
            $reInfo = reagentc /info
            # Usually requires mounting the recovery partition, simplified for this demo
            throw "WinRE.wim not found at standard path. Please provide a source WIM."
        }
        
        Copy-Item $winrePath "$WorkingDir\Winre.wim" -Force
        
        # 3. Mount Image
        Write-Host "Mounting WinRE Image..."
        dism /Mount-Image /ImageFile:"$WorkingDir\Winre.wim" /Index:1 /MountDir:"$WorkingDir\mount"
        
        # 4. Inject WindowsDoctor Core
        Write-Host "Injecting WindowsDoctor Components..."
        $targetPath = "$WorkingDir\mount\WindowsDoctor"
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        Copy-Item "e:\WindowsDoctor\core" "$targetPath\core" -Recurse
        Copy-Item "e:\WindowsDoctor\knowledge_base" "$targetPath\knowledge_base" -Recurse
        Copy-Item "e:\WindowsDoctor\scripts" "$targetPath\scripts" -Recurse
        
        # 5. Configure Autostart
        Write-Host "Configuring Autostart (startnet.cmd)..."
        $startnet = "$WorkingDir\mount\Windows\System32\startnet.cmd"
        $cmd = @"
wpeinit
echo Starting WindowsDoctor Diagnostic Engine...
powershell.exe -ExecutionPolicy RemoteSigned -File X:\WindowsDoctor\scripts\Maintenance-Daily.ps1
"@
        $cmd | Out-File $startnet -Encoding ascii -Force
        
        # 6. Unmount and Commit
        Write-Host "Unmounting and Saving Changes..."
        dism /Unmount-Image /MountDir:"$WorkingDir\mount" /Commit
        
        Write-Host ">>> CUSTOM WINRE READY: $WorkingDir\Winre.wim" -ForegroundColor Green
        Write-Host ">>> Please use Rufus or Ventoy to flash this image to a USB drive."
    }
}

New-WDRescueMedia
