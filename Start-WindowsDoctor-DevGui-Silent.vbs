Option Explicit
Dim shell, fso, root, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
command = "powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File """ & root & "\scripts\Start-WindowsDoctor.ps1"" -Root """ & root & """ -RestartBroker -RestartGui -SkipBuild -Hidden -MaxGuiNodeProcesses 8 -MaxStartupPostCssWorkers 1 -MaxPostCssWorkerSeconds 45 -MaxWindowsDoctorTotalWorkingSetMB 1200 -MaxWindowsDoctorProcessWorkingSetMB 512 -NodeMaxOldSpaceSizeMB 384 -ResourceWatchSeconds 900 -StartupStepDelaySeconds 5 -ProcessPriority BelowNormal"
shell.Run command, 0, True
shell.Run "http://localhost:3000", 1, False
