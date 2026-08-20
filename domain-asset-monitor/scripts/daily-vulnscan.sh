#!/bin/bash
# 每日漏洞扫描：扫描 scan-targets.txt 中的资产，与昨日结果比对，新增高危推送企微
SCAN=/home/ubuntu/.local/bin/vulnscan
DIR=/home/ubuntu/asset-monitor
WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=fd2c911e-da2a-40f7-9069-62659071e894"
TODAY="$DIR/vulnscan-$(date +%Y%m%d).json"
YESTERDAY="$DIR/vulnscan-latest.json"

# 跑扫描
$SCAN "$DIR/scan-targets.txt" > "$TODAY" 2>/dev/null
if [ ! -s "$TODAY" ]; then echo "$(date) 扫描失败"; exit 1; fi

# 统计今日高危/中危
high_today=$(python3 -c "
import json
d = json.load(open('$TODAY'))
cnt = 0
for url, fs in d['results'].items():
    for f in fs:
        if f['level'] in ('HIGH','MEDIUM'):
            cnt += 1
            print(f\"[{f['level']}] {url} {f['type']}: {f['detail']}\")
" 2>/dev/null)
high_count=$(echo "$high_today" | grep -c "^\[" || true)

# 与昨日对比（新出现的高危才告警）
if [ -f "$YESTERDAY" ]; then
  new_high=$(python3 -c "
import json
today = json.load(open('$TODAY'))
yesterday = json.load(open('$YESTERDAY'))
y_keys = set()
for url, fs in yesterday.get('results', {}).items():
    for f in fs:
        if f['level'] in ('HIGH','MEDIUM'):
            y_keys.add((url, f['type'], f['detail']))
for url, fs in today['results'].items():
    for f in fs:
        if f['level'] in ('HIGH','MEDIUM') and (url, f['type'], f['detail']) not in y_keys:
            print(f\"[{f['level']}] {url}\n  {f['detail']}\")
" 2>/dev/null)
else
  new_high="$high_today"  # 首跑全部报
fi

if [ -n "$new_high" ] && [ "$new_high" != "0" ]; then
  # 构造企微消息
  esc_new=$(echo "$new_high" | sed 's/"/\\"/g' | awk '{print "> " $0 "\\n"}' | tr -d '\n')
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
    \"msgtype\": \"markdown\",
    \"markdown\": {\"content\": \"## 🔥 漏洞扫描告警\\n> poppula.com 外网资产 $(date +%m-%d)\\n\\n**新增高危/中危发现：**\\n${esc_new}\\n\\n<font color=\\\"comment\\\">详情: $TODAY</font>\"}
  }"
fi

cp "$TODAY" "$YESTERDAY"
echo "$(date) 扫描完成: 高/中危 $high_count 个"
