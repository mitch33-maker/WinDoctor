---
description: "BitLocker 開機要求修復金鑰"
---
# BitLocker 開機要求修復金鑰
- EventID/Code: BITLOCKER_RECOVERY
- Trigger: ["BitLocker recovery", "recovery key", "TPM", "Secure Boot policy", "PCR"]
- Script: "N/A"

## 分析細節
常見於 BIOS/TPM/Secure Boot 變更、開機順序改變、韌體更新或硬體更換。系統只能引導使用者找回 Microsoft 帳戶或公司 AD/Azure AD 中的修復金鑰，不應嘗試繞過加密。
