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

# 对比新发现
new_subs=$(comm -23 <(echo "$subs") <(awk '{print $1}' $BASELINE | sort))
gone_subs=$(comm -13 <(echo "$subs") <(awk '{print $1}' $BASELINE | sort))

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
