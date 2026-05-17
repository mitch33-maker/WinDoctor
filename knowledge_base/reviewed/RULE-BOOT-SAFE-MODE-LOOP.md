---
description: "Windows 卡在安全模式或診斷啟動"
---
# Windows 卡在安全模式或診斷啟動
- EventID/Code: SAFE_MODE_LOOP
- Trigger: ["safe mode loop", "safeboot", "msconfig diagnostic startup", "Minimal Safe Boot"]
- Script: "N/A"

## 分析細節
常見於 msconfig 設定 safeboot、BCD boot option 殘留或修復後未還原正常啟動。引導使用者檢查 msconfig 與 BCD 啟動參數，確認問題解除後再恢復正常啟動。
