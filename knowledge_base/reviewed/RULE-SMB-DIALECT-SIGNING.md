---
description: "SMB 版本或簽章需求不相容"
---
# SMB 版本或簽章需求不相容
- EventID/Code: SMB_DIALECT_SIGNING
- Trigger: ["SMB1", "SMB2", "SMB signing", "STATUS_NOT_SUPPORTED", "The specified network name is no longer available"]
- Script: "N/A"

## 分析細節
常見於舊 NAS、舊印表機分享、網域原則要求 SMB signing 或 SMB1 已停用。引導使用者確認 NAS 韌體與 SMB 版本設定；不應自動啟用 SMB1。
