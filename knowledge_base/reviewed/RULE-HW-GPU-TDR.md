---
description: "顯示卡驅動 TDR 重置或畫面黑屏"
---
# 顯示卡驅動 TDR 重置或畫面黑屏
- EventID/Code: VIDEO_TDR
- Trigger: ["Display driver stopped responding", "nvlddmkm", "amdkmdag", "igfx", "LiveKernelEvent 141", "VIDEO_TDR_FAILURE"]
- Script: "N/A"

## 分析細節
常見於顯示卡驅動、過熱、超頻、電源供應或硬體老化。引導使用者先更新或回退官方驅動、檢查溫度與電源；若伴隨 LiveKernelEvent，需保留 Minidump 或可靠性監視器紀錄。
