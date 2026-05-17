Option Explicit
Dim shell, fso, root, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
command = "powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File """ & root & "\scripts\Stop-WindowsDoctorServices.ps1"" -Root """ & root & """"
shell.Run command, 0, True
