#!/bin/bash
# poppula.com 每日资产监控 — 免费渠道 + 新发现推送企业微信
DOMAIN="poppula.com"
source /home/ubuntu/asset-monitor/monitor.env 2>/dev/null
WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$WECOM_KEY"
BASELINE="/home/ubuntu/asset-monitor/baseline.txt"
NEWFILE="/home/ubuntu/asset-monitor/current-$(date +%Y%m%d).txt"

# 子域名枚举（subenum: crt.sh + rapiddns + hackertarget + DNS字典）
/home/ubuntu/.local/bin/subenum $DOMAIN > "$NEWFILE" 2>/dev/null
subs=$(cat "$NEWFILE" | awk '{print $1}' | sort)

if [ ! -f "$BASELINE" ]; then
  cp "$NEWFILE" "$BASELINE"
  echo "首次运行，建立基线: $(echo "$subs" | wc -l) 个子域名"
  exit 0
fi

# 对比新发现（容忍抖动：消失的子域只在"连续2天都不出现"时才告警，避免DNS缓存抖动误报）
new_subs=$(comm -23 <(echo "$subs") <(awk '{print $1}' $BASELINE | sort))
# 昨天的记录（若存在）用于二次确认消失
YESTERDAY_FILE="/home/ubuntu/asset-monitor/current-$(date -d yesterday +%Y%m%d).txt"
if [ -f "$YESTERDAY_FILE" ]; then
  # 今天没出现 + 昨天也没出现 = 真消失；昨天还在 = 可能抖动，不告警
  gone_subs=$(comm -13 <(echo "$subs") <(awk '{print $1}' $BASELINE | sort) | comm -12 - <(awk '{print $1}' "$YESTERDAY_FILE" | sort) | comm -23 /dev/null - 2>/dev/null || true)
  # 修正：消失 = 在基线里但今天不在，且昨天也不在
  gone_subs=$(comm -13 <(echo "$subs") <(awk '{print $1}' $BASELINE | sort))
  gone_subs=$(echo "$gone_subs" | while read s; do
    [ -n "$s" ] && ! grep -q "^$s" "$YESTERDAY_FILE" 2>/dev/null && echo "$s"
  done)
else
  gone_subs=$(comm -13 <(echo "$subs") <(awk '{print $1}' $BASELINE | sort))
fi

if [ -n "$new_subs" ] || [ -n "$gone_subs" ]; then
  # 构造 markdown 消息
  MSG="## 🚨 资产变更告警\n> 域名: \`$DOMAIN\`\n"
  if [ -n "$new_subs" ]; then
    MSG+="\n**🆕 新发现子域名:**\n"
    for s in $new_subs; do
      ip=$(grep "^$s" "$NEWFILE" | awk '{print $2}')
      MSG+="> ⬆️ \`$s\` → ${ip:-未解析}\n"
    done
  fi
  if [ -n "$gone_subs" ]; then
    MSG+="\n**➖ 消失的子域名:**\n"
    for s in $gone_subs; do
      MSG+="> ⬇️ \`$s\`\n"
    done
  fi
  # 发企业微信
  curl -s --max-time 15 "$WEBHOOK" -H "Content-Type: application/json" \
    -d "{\"msgtype\":\"markdown\",\"markdown\":{\"content\":\"$MSG\"}}"
  # 更新基线
  cp "$NEWFILE" "$BASELINE"
else
  echo "$(date) 无变化"
fi
