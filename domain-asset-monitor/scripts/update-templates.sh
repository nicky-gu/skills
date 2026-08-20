#!/bin/bash
set -a; source /home/ubuntu/asset-monitor/monitor.env; set +a
# nuclei 模板每日更新：GitHub API(目录列表) + jsDelivr CDN(文件内容) 双通道
# 官方 -update-templates 走 git 协议被网络拦截，此为替代方案
TPL_DIR=~/.config/nuclei/templates
WEBHOOK = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=" + os.environ.get("WECOM_KEY", "")""
LOG=/home/ubuntu/asset-monitor/monitor.log

python3 << "PYEOF" >> /home/ubuntu/asset-monitor/monitor.log 2>&1
import json, os, urllib.request, urllib.parse, time, subprocess

import os
TOKEN = os.environ.get("GH_TOKEN", "")
DEST = os.path.expanduser("~/.config/nuclei/templates")
REPO = "projectdiscovery/nuclei-templates"
CDN = "https://cdn.jsdelivr.net/gh/projectdiscovery/nuclei-templates@v10.4.7"

def gh_api(path, retries=2):
    enc = urllib.parse.quote(path, safe='/')
    url = f"https://api.github.com/repos/{REPO}/contents/{enc}?ref=v10.4.7"
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={'Authorization': f'token {TOKEN}'})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read())
        except Exception:
            if i == retries-1: return None
            time.sleep(3)

def cdn_get(path, retries=2):
    url = f"{CDN}/{urllib.parse.quote(path, safe='/')}"
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=25) as r:
                return r.read()
        except Exception:
            if i == retries-1: return None
            time.sleep(2)

WANT_DIRS = ["http/cves/2026", "http/cves/2025", "http/exposed-panels",
             "http/exposures", "http/default-logins", "http/takeovers",
             "http/misconfiguration"]

added = updated = 0
for d in WANT_DIRS:
    items = gh_api(d)
    if items is None:
        print(f"[tpl-update] {d}: 目录获取失败，跳过")
        continue
    for item in items:
        if item['type'] != 'file' or not item['name'].endswith('.yaml'): continue
        local = os.path.join(DEST, item['path'])
        os.makedirs(os.path.dirname(local), exist_ok=True)
        # jsDelivr CDN 拉内容
        content = cdn_get(item['path'])
        if content is None:
            # CDN失败回退 GitHub API
            data = gh_api(item['path'])
            if data and data.get('content'):
                import base64
                content = base64.b64decode(data['content'])
        if content is None: continue
        if not os.path.exists(local):
            with open(local, 'wb') as f: f.write(content)
            added += 1
            time.sleep(0.1)
        else:
            old = open(local,'rb').read()
            if old != content:
                with open(local,'wb') as f: f.write(content)
                updated += 1
                time.sleep(0.1)

total = subprocess.run(f'find {DEST} -name "*.yaml" | wc -l', shell=True, capture_output=True, text=True).stdout.strip()
print(f"[tpl-update] {time.strftime('%F %T')} 新增 {added} / 更新 {updated}，总计 {total} 模板")

if added > 0 or updated > 0:
    import urllib.request as ur
    msg = {"msgtype":"markdown","markdown":{"content":f"## 📦 nuclei 模板库已更新\n> {time.strftime('%m-%d')}\n\n> 新增: <font color=\"info\">{added}</font> 个\n> 更新: <font color=\"warning\">{updated}</font> 个\n> 总计: {total} 个模板"}}
    req = ur.Request("https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=" + os.environ.get("WECOM_KEY", "") + "",
        data=json.dumps(msg).encode(), headers={'Content-Type':'application/json'})
    ur.urlopen(req, timeout=15).read()
    print(f"[tpl-update] 已推送企微")
PYEOF
