#!/bin/bash
# 每日漏洞扫描 v3（分层扫描）：
#   WAF 资产（scan-targets-waf.txt）：只做 HTTP 存活监测（不跑 nuclei，避免触发自家 WAF 告警/封IP）
#   直连资产（scan-targets-direct.txt）：vulnscan 轻量检测 + nuclei 全模板漏洞扫描
#   新增端口发现：Shodan 免费数据交叉（weekly-shodan 周报负责），新端口人工评估后加入 direct 清单
NUCLEI=/home/ubuntu/go/bin/nuclei
TPL=~/.config/nuclei/templates/http/
SCAN=/home/ubuntu/.local/bin/vulnscan
DIR=/home/ubuntu/asset-monitor
source $DIR/monitor.env 2>/dev/null
WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$WECOM_KEY"
TODAY_N=$(date +%Y%m%d)

# ---- 1. WAF 资产：轻量存活监测 ----
WAF_DOWN=""
while IFS= read -r url; do
  [ -z "$url" ] || [[ "$url" == \#* ]] && continue
  code=$(timeout 10 curl -sk -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
  if [ "$code" = "000" ] || [ -z "$code" ]; then
    WAF_DOWN="${WAF_DOWN}${url} "
  fi
done < "$DIR/scan-targets-waf.txt"
if [ -n "$WAF_DOWN" ]; then
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
    \"msgtype\":\"markdown\",
    \"markdown\":{\"content\":\"## ⚠️ 站点存活告警\n> $(date +%m-%d)\n\n**以下 WAF 资产不可达：**\n> $WAF_DOWN\n\n<font color=\\\"comment\\\">WAF资产只做存活监测，不跑漏洞扫描</font>\"}
  }"
fi

# ---- 2. 直连资产：轻量 + nuclei ----
$SCAN "$DIR/scan-targets-direct.txt" > "$DIR/vulnscan-$TODAY_N.json" 2>/dev/null

if [ -x "$NUCLEI" ]; then
  timeout 1800 $NUCLEI -l "$DIR/scan-targets-direct.txt" \
    -t $TPL -severity medium,high,critical \
    -jsonl -o "$DIR/nuclei-$TODAY_N.jsonl" \
    -silent -timeout 8 -retries 1 -c 15 -duc 2>/dev/null
fi
[ -f "$DIR/nuclei-$TODAY_N.jsonl" ] || touch "$DIR/nuclei-$TODAY_N.jsonl"

# ---- 3. 增量比对（仅直连资产的 nuclei 发现）----
PREV=$(ls -t $DIR/nuclei-*.jsonl 2>/dev/null | grep -v "$TODAY_N" | head -1)
new_findings=""
if [ -n "$PREV" ]; then
  new_ids=$(comm -13 <(jq -r '."template-id"' "$PREV" 2>/dev/null | sort -u) \
                    <(jq -r '."template-id"' "$DIR/nuclei-$TODAY_N.jsonl" 2>/dev/null | sort -u))
  for tid in $new_ids; do
    detail=$(jq -r "select(.\"template-id\"==\"$tid\") | \"[\(.severity)] \(.info.name) @ \(.matched-at)\"" "$DIR/nuclei-$TODAY_N.jsonl" 2>/dev/null | head -1)
    new_findings="${new_findings}> ${detail}\n"
  done
fi

# ---- 4. 推送 ----
if [ ! -n "$PREV" ]; then
  total=$(wc -l < "$DIR/nuclei-$TODAY_N.jsonl")
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
    \"msgtype\":\"markdown\",
    \"markdown\":{\"content\":\"## 🛡️ 分层扫描基线已建立\n> $(date +%m-%d)\n\n**WAF资产：** 存活监测（$(grep -vc '^#' $DIR/scan-targets-waf.txt) 个）\n**直连资产：** nuclei 全模板（$(grep -vc '^#' $DIR/scan-targets-direct.txt) 个）\n\n**直连资产本次中高危：** ${total} 个\n<font color=\\\"comment\\\">WAF资产不做漏扫，避免封IP</font>\"}
  }"
elif [ -n "$new_findings" ]; then
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" -d "{
    \"msgtype\":\"markdown\",
    \"markdown\":{\"content\":\"## 🔥 nuclei 新增漏洞发现\n> poppula.com $(date +%m-%d)\n\n$new_findings\"}
  }"
fi

# 清理30天前
find $DIR -name "vulnscan-*.json" -mtime +30 -delete 2>/dev/null
find $DIR -name "nuclei-*.jsonl" -mtime +30 -delete 2>/dev/null
echo "$(date) 分层扫描完成: WAF存活$( [ -n "$WAF_DOWN" ] && echo "异常!" || echo "正常" ) + 直连nuclei发现 $(wc -l < $DIR/nuclei-$TODAY_N.jsonl) 个"
