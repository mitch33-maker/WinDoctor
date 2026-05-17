/* eslint-disable @typescript-eslint/no-require-imports */
const https = require('https');
const config = require('../config');
const { writeLearnedRule } = require('./kb');

function searchWebSolution(errorCode) {
    const query = `windows error ${encodeURIComponent(errorCode)} fix`;
    const url = `https://html.duckduckgo.com/html/?q=${query}`;

    return new Promise((resolve) => {
        const req = https.get(url, (webRes) => {
            let data = '';
            webRes.on('data', chunk => data += chunk);
            webRes.on('end', () => {
                const snippetMatch = data.match(/<a class="result__snippet[^>]*>([\s\S]*?)<\/a>/);
                const snippet = snippetMatch ? snippetMatch[1].replace(/<\/?[^>]+(>|$)/g, '') : '';
                resolve(snippet || '線上搜尋沒有取得可用摘要；已建立 learn-only 知識庫案例，待人工補充修復步驟。');
            });
        });
        req.setTimeout(config.searchTimeoutMs, () => {
            req.destroy();
            resolve('線上搜尋逾時；已建立 learn-only 知識庫案例，待人工補充修復步驟。');
        });
        req.on('error', () => {
            resolve('線上搜尋失敗；已建立 learn-only 知識庫案例，待人工補充修復步驟。');
        });
    });
}

async function learnIssue({ title, errorCode, description }) {
    const id = `KB-${Date.now()}`;
    const webSolution = await searchWebSolution(errorCode);
    const content = `---
description: "${title}"
---
# ${title}
- EventID/Code: ${errorCode}
- Trigger: ["${errorCode}", "${title}"]
- Script: "N/A"

## 分析細節
**系統觸發無人值守模式 (Fully Unattended)**：
已經自動連上網路查獲以下解法與情境：
> ${webSolution}

使用者描述：
${description || '未提供'}

此案例已寫入知識庫，但不自動生成或執行修復腳本。
`;
    writeLearnedRule(id, content);
    return { status: 'success', id, webSolution, mode: 'learn-only' };
}

module.exports = { learnIssue, searchWebSolution };
