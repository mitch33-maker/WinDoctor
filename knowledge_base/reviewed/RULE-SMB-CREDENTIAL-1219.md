---
description: "網路磁碟多重帳號連線衝突 1219"
---
# 網路磁碟多重帳號連線衝突 1219
- EventID/Code: 1219
- Trigger: ["System error 1219", "multiple connections", "more than one user name", "net use", "SMB credential"]
- Script: "N/A"

## 分析細節
同一台 NAS/伺服器已用另一組帳號連線時會出現。引導使用者列出現有 `net use`，中斷同伺服器連線後重新掛載；避免自動刪除全部網路磁碟，以免中斷其他工作。
