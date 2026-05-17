/* eslint-disable @typescript-eslint/no-require-imports */
const config = require('../config');

function getMockVisionResult(reason = 'mock') {
    return {
        provider: 'mock',
        fallback: reason,
        prediction: '模擬偵測: Windows 錯誤畫面或啟動異常',
        recommendation: '請先執行完整診斷；若出現 BCD、Windows Update 或網路錯誤，系統會比對本機知識庫規則。'
    };
}

function extractGeminiText(payload) {
    return payload?.candidates?.[0]?.content?.parts
        ?.map((part) => part.text || '')
        .filter(Boolean)
        .join('\n')
        .trim();
}

async function analyzeGeminiVision() {
    if (!config.geminiApiKey) return getMockVisionResult('missing_api_key');

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.visionTimeoutMs);
    try {
        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(config.geminiModel)}:generateContent?key=${encodeURIComponent(config.geminiApiKey)}`;
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            signal: controller.signal,
            body: JSON.stringify({
                contents: [{
                    role: 'user',
                    parts: [{
                        text: '你是 Windows 故障診斷助理。請根據使用者可能提供的錯誤畫面，輸出精簡的故障推測與安全修復建議。若沒有影像內容，請提醒先執行本機完整診斷。'
                    }]
                }]
            })
        });
        if (!response.ok) return getMockVisionResult(`gemini_http_${response.status}`);
        const text = extractGeminiText(await response.json());
        if (!text) return getMockVisionResult('empty_provider_response');
        return {
            provider: 'gemini',
            model: config.geminiModel,
            prediction: text.slice(0, 240),
            recommendation: text
        };
    } catch (err) {
        return getMockVisionResult(err.name === 'AbortError' ? 'provider_timeout' : 'provider_error');
    } finally {
        clearTimeout(timer);
    }
}

async function analyzeVision() {
    if (config.visionProvider.toLowerCase() === 'gemini') return analyzeGeminiVision();
    return getMockVisionResult('mock_provider');
}

function getVisionStatus() {
    const provider = config.visionProvider.toLowerCase();
    return {
        provider,
        configured: provider === 'mock' || (provider === 'gemini' && Boolean(config.geminiApiKey)),
        model: provider === 'gemini' ? config.geminiModel : undefined,
        fallback: 'mock',
        timeoutMs: config.visionTimeoutMs
    };
}

module.exports = { analyzeVision, getVisionStatus };
