---
description: "遠端桌面 NLA 或認證失敗"
---
# 遠端桌面 NLA 或認證失敗
- EventID/Code: SYS_RDP_NLA
- Trigger: [NLA, CredSSP, 遠端桌面認證, 0x800903]
- Script: "N/A"

## 分析細節
NLA/CredSSP 失敗可能與時間差、憑證、網域信任、更新層級或安全原則有關。不自動停用 NLA；需先確認風險與管理政策。
