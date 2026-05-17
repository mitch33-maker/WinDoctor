Option Explicit
Dim shell, fso, root, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
command = "powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File """ & root & "\scripts\Start-WindowsDoctor.ps1"" -Root """ & root & """ -RestartBroker -NoGui -SkipBuild -Hidden -MaxGuiNodeProcesses 4 -MaxWindowsDoctorTotalWorkingSetMB 512 -MaxWindowsDoctorProcessWorkingSetMB 256 -NodeMaxOldSpaceSizeMB 192 -ProcessPriority BelowNormal"
shell.Run command, 0, True
shell.Run """" & root & "\docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html""", 1, False
