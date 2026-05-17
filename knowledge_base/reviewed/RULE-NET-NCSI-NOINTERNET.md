---
description: "Windows NCSI 誤判無網際網路"
---
# Windows NCSI 誤判無網際網路
- EventID/Code: NET_NCSI_NOINTERNET
- Trigger: [NCSI, 無網際網路, No Internet, msftconnecttest]
- Script: "N/A"

## 分析細節
NCSI 可能因公司 Proxy、防火牆、DNS 攔截或封鎖 msftconnecttest 而誤判無網路。此類問題通常不應自動修復，需依網路政策確認 Proxy 與防火牆規則。
