#!/bin/bash
# 每周 Shodan 主动核查（消耗 ~2 query credits）
KEY="$SHODAN_KEY"
source /home/ubuntu/asset-monitor/monitor.env 2>/dev/null
WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$WECOM_KEY"
OUT="/home/ubuntu/asset-monitor/shodan-$(date +%Y%m%d).json"

# Shodan DNS 数据库子域名（1 credit）
curl -s --max-time 30 "https://api.shodan.io/dns/domain/poppula.com?key=$KEY" > "$OUT"
new_ips=$(python3 -c "
import json
d = json.load(open('$OUT'))
dns = d.get('data', [])
lines = []
for r in dns:
    sub = r.get('subdomain','')
    val = r.get('value','')
    if isinstance(val, list): val = val[0] if val else ''
    if sub and val: lines.append(f\"{sub}.poppula.com -> {val}\")
print('\n'.join(sorted(set(lines))))
" 2>/dev/null)

# 推送周报
curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
  \"msgtype\": \"markdown\",
  \"markdown\": {\"content\": \"## 📊 Shodan 周度资产核查\n> $(date +%Y-%m-%d)\n\n**Shodan DNS 库中的子域名:**\n$(for l in "$new_ips"; do echo "> \`$l\`"; done)\n\n<font color=\\\"comment\\\">额度用量见 api-info，每周1次DNS查询</font>\"}
}"
