#!/bin/bash
# 每日漏洞扫描（双引擎）：
#   1. vulnscan 轻量检测（安全头/TLS/指纹）→ 落盘
#   2. nuclei 模板扫描（exposed-panels/misconfig/cve等 561+模板）→ 新增高危推送企微
SCAN=/home/ubuntu/.local/bin/vulnscan
NUCLEI=/home/ubuntu/go/bin/nuclei
TPL=~/.config/nuclei/templates/http/
DIR=/home/ubuntu/asset-monitor
WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=fd2c911e-da2a-40f7-9069-62659071e894"
TODAY_N=$(date +%Y%m%d)

# ---- 引擎1: vulnscan 轻量 ----
$SCAN "$DIR/scan-targets.txt" > "$DIR/vulnscan-$TODAY_N.json" 2>/dev/null

# ---- 引擎2: nuclei 深度 ----
if [ -x "$NUCLEI" ]; then
  timeout 1800 $NUCLEI -l "$DIR/scan-targets.txt" \
    -t $TPL -severity medium,high,critical \
    -jsonl -o "$DIR/nuclei-$TODAY_N.jsonl" \
    -silent -timeout 8 -retries 1 -c 15 -duc 2>/dev/null
fi
[ -f "$DIR/nuclei-$TODAY_N.jsonl" ] || touch "$DIR/nuclei-$TODAY_N.jsonl"

# ---- 增量比对（nuclei 高危发现，与上次比）----
PREV=$(ls -t $DIR/nuclei-*.jsonl 2>/dev/null | grep -v "$TODAY_N" | head -1)
new_findings=""
if [ -n "$PREV" ]; then
  # 对比模板ID集合
  new_ids=$(comm -13 <(jq -r '."template-id"' "$PREV" 2>/dev/null | sort -u) \
                    <(jq -r '."template-id"' "$DIR/nuclei-$TODAY_N.jsonl" 2>/dev/null | sort -u))
  for tid in $new_ids; do
    detail=$(jq -r "select(.\"template-id\"==\"$tid\") | \"[\(.severity)] \(.info.name) @ \(.matched-at)\"" "$DIR/nuclei-$TODAY_N.jsonl" 2>/dev/null | head -1)
    new_findings="${new_findings}> ${detail}\n"
  done
fi

# ---- 推送 ----
if [ ! -n "$PREV" ]; then
  # 首跑：全量报
  total=$(wc -l < "$DIR/nuclei-$TODAY_N.jsonl")
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
    \"msgtype\": \"markdown\",
    \"markdown\": {\"content\": \"## 🛡️ nuclei 每日扫描已接入\n> poppula.com $(date +%m-%d)\n\n**引擎：** vulnscan(轻量) + nuclei v3.11.1(561模板)\n\n**本次中高危发现：** ${total} 个\n<font color=\\\"comment\\\">此后仅新增发现才告警</font>\"}
  }"
elif [ -n "$new_findings" ]; then
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
    \"msgtype\": \"markdown\",
    \"markdown\": {\"content\": \"## 🔥 nuclei 新增漏洞发现\n> poppula.com $(date +%m-%d)\n\n$new_findings\"}
  }"
fi

# 清理30天前的旧结果
find $DIR -name "vulnscan-*.json" -mtime +30 -delete 2>/dev/null
find $DIR -name "nuclei-*.jsonl" -mtime +30 -delete 2>/dev/null
echo "$(date) 双引擎扫描完成: nuclei发现 $(wc -l < $DIR/nuclei-$TODAY_N.jsonl) 个"
