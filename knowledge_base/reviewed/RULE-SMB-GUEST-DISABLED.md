---
description: "Windows 停用不安全 Guest SMB 存取"
---
# Windows 停用不安全 Guest SMB 存取
- EventID/Code: SMB_GUEST_DISABLED
- Trigger: ["guest access", "insecure guest logons", "SMB guest", "You can't access this shared folder because your organization's security policies"]
- Script: "N/A"

## 分析細節
Windows 預設阻擋不安全 Guest SMB。建議優先在 NAS 建立帳密與權限，不建議自動啟用 Guest。若是隔離測試環境，應由使用者明確確認風險後手動調整原則。
