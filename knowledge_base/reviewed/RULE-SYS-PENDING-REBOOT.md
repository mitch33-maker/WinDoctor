---
description: "系統等待重新啟動導致安裝或更新失敗"
---
# 系統等待重新啟動導致安裝或更新失敗
- EventID/Code: SYS_PENDING_REBOOT
- Trigger: [pending reboot, 需要重新啟動, CBS RebootPending, 安裝失敗]
- Script: "N/A"

## 分析細節
Windows 更新、驅動或 MSI 安裝後可能留下待重開機狀態，導致後續安裝失敗。應先完成重開機與更新佇列，不自動強制重啟。
