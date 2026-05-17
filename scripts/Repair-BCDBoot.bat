@echo off
REM Repair-BCDBoot.bat
REM 專門給 WinPE 用的 BCD 救援工具

echo 正在掃描並修復硬碟 MBR...
bootrec /fixmbr
echo 正在掃描並重建 BCD 開機引導...
bootrec /rebuildbcd

echo 救援完成，請拔除隨身碟並重啟電腦。
