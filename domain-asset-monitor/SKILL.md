---
name: domain-asset-monitor
description: 监控公司外网资产（子域名发现 + 变更告警 + Shodan 集成）。Use when the user asks to 监控资产/子域名发现/资产测绘/domain monitoring/asset discovery/新子域名告警, or wants to set up continuous external attack surface monitoring for a company domain. 包含工具安装（subenum 枚举器）、基线建立、企业微信告警、定时任务配置、Shodan 额度优化（学生账号友好）。
---

# 公司外网资产监控（Domain Asset Monitor）

对外网资产做持续监控：子域名发现 → 变更告警（企业微信）→ **每日漏洞扫描** → Shodan 周度核查。零 API 成本为主，Shodan 每周仅 1 credit。

## 前置条件

- Linux 主机（有 cron）
- Go 1.22+（nuclei 编译安装用）
- Shodan API key（可选，学生/Dev 账号即可）
- 企业微信群机器人 webhook（可选，告警用）
- Python3 + `pip install cryptography`（TLS 证书检测用）

## 整体流程（6 步）

```
第1步 侦察基线    → subenum 全量枚举子域名，落盘 baseline.txt
第2步 搭告警      → 企业微信 webhook 测试连通
第3步 定时任务    → cron 每日免费枚举 + 变更对比，有变化才推送
第4步 漏洞扫描    → vulnscan 每日扫描目标清单，新增高危才推送
第5步 Shodan集成  → Monitor 实时监控（0额度）+ 每周 DNS 主动核查（1 credit）
第6步 人工复核    → 对发现的高危资产（堡垒机/敏感子域）做版本核实
```

## 每日自动化全景（cron）

| 时间 | 任务 | 脚本 | 消耗 |
|------|------|------|------|
| 09:00 | 子域名枚举+变更告警 | daily-check.sh | 0 |
| 09:30 | 漏洞扫描+新增高危告警 | daily-vulnscan.sh | 0 |
| 14:00 | nuclei 模板库增量更新 | update-templates.sh | 0 |
| 周一 10:00 | Shodan DNS 核查周报 | weekly-shodan.sh | 1 credit |

## 第 1 步：安装枚举器 + 建基线

subenum 是聚合式被动枚举器（crt.sh + rapiddns + hackertarget + 115 词 DNS 字典），零 API key。完整脚本见本 skill 的 `scripts/subenum`。

```bash
# 安装
cp scripts/subenum ~/.local/bin/ && chmod +x ~/.local/bin/subenum

# 建监控目录 + 首次基线
mkdir -p ~/asset-monitor
subenum example.com > ~/asset-monitor/baseline.txt
```

输出格式：`子域名<TAB>解析IP`（未解析的只列名字）。数据源说明：
- crt.sh：证书透明度日志（HTTPS 站点的证书记录），最全但经常 502，脚本内置 3 次重试
- rapiddns.io / hackertarget：被动 DNS 聚合
- DNS 字典：并发探测 115 个常见企业子域（vpn/oa/jumpserver/vault/kibana...），能发现"没上 HTTPS 所以证书日志里没有"的记录

## 第 2 步：企业微信告警

```bash
WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的key"
curl -s "$WEBHOOK" -H "Content-Type: application/json" -d '{
  "msgtype": "markdown",
  "markdown": {"content": "## 测试\n> 告警链路 OK"}
}'
# 返回 {"errcode":0} 即通
```

格式要点：用 markdown 类型；支持 `<font color="info|warning|comment">`；告警内容必须包含"新增/消失资产 + IP + 时间"。

## 第 3 步：定时任务（核心）

每日免费检查脚本（`scripts/daily-check.sh`，改 DOMAIN 和 WEBHOOK 后直接用）：

```bash
逻辑：
1. subenum 跑当日全量 → current-日期.txt
2. 与 baseline.txt 做 comm 对比
3. 有新增/消失 → 拼装 markdown → 推企微 → 更新基线
4. 无变化 → 只写日志，不打扰
```

注册 cron（每天 09:00）：

```bash
(crontab -l 2>/dev/null | grep -v daily-check; \
 echo "0 9 * * * /home/ubuntu/asset-monitor/daily-check.sh >> /home/ubuntu/asset-monitor/monitor.log 2>&1") | crontab -
```

验证：`crontab -l`，次日看 monitor.log；手动触发一次 `daily-check.sh` 确认首跑建基线。

## 第 4 步：每日漏洞扫描（分层策略）

**vulnscan（`scripts/vulnscan`）**——零依赖轻量检测器，无侵入纯 GET：
- 敏感路径暴露（HIGH）：.git/config、.env、phpMyAdmin、actuator、Druid 等 12 类
- TLS 弱配置（MEDIUM）：TLSv1.0 弱协议、证书过期/<30天
- 安全响应头缺失（LOW）、技术栈指纹（INFO）

**nuclei（官方模板引擎，2098+ 模板）**——每日主力扫描。

**分层扫描策略（daily-vulnscan.sh v3）**——WAF 资产与直连资产区别对待：

| 目标文件 | 内容 | 动作 |
|---------|------|------|
| `scan-targets-waf.txt` | WAF 后面的资产（官网 80/443 等） | **只做 HTTP 存活监测**（不跑 nuclei——扫了被 WAF 拦，还可能触发自家告警/封扫描 IP） |
| `scan-targets-direct.txt` | 非 WAF 端口资产（堡垒机 81/444 等非常规端口） | vulnscan 轻量检测 + **nuclei 全模板扫描** |

```
流程：
1. WAF 资产逐个 curl 存活检查 → 不可达推送企微告警
2. 直连资产：vulnscan 轻量 → nuclei(-severity medium,high,critical)
3. 与上次比对 template-id 集合 → 仅"新增"发现推送企微
4. 清理 30 天前历史
```

cron：`30 9 * * *`（子域名检查后 30 分钟）。

设计取舍：
- **WAF 资产不漏扫**是刻意的：漏洞扫描打 WAF 没意义（拦了测不到真实面），反而消耗 WAF 告警注意力、有封扫描出口 IP 的风险。WAF 资产的漏洞治理交给 WAF 规则 + 代码审计
- **新端口的纳入流程**：Shodan 周报/子域名告警发现新端口 → 人工判断是否 WAF 后面 → 加入对应目标文件
- **告警只报增量**——首次全量报基线；WAF 资产只在不可达时告警
- nuclei 用 `-duc` + `timeout 1800` 兜底；目标不可达自动跳过

## 第 5 步：Shodan 集成（额度优化）

学生/Dev 账号配额：100 query credits/月、16 个监控 IP。设计原则——**查询额度只花在主动发现，实时监控走 Monitor（零额度）**。

**4a. Monitor 实时监控（零额度，端口/CVE 变化自动邮件）：**

```bash
curl -X POST "https://api.shodan.io/shodan/alert?key=$KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"company-web","filters":{"ipv4":["1.2.3.4"]},"expires":31536000}'
# 注意：expires 必须是秒数（不能 null），1年=31536000
# 常见坑：Shodan 该端点偶发 503 upstream reset，隔天重试即可
# 监控上限 16 IP，优先：Web服务器/堡垒机/邮件服务器等固定公网IP
```

**4b. 每周 DNS 主动核查（1 credit/周，约 5/月）：**

```bash
curl -s "https://api.shodan.io/dns/domain/example.com?key=$KEY"
# 对比 Shodan DNS 库与自己枚举的结果，差异即新资产
# 注册 cron：0 10 * * 1 weekly-shodan.sh
```

**额度月度预算表：**
| 操作 | 单价 | 频率 | 月耗 |
|------|------|------|------|
| dns/domain 周核查 | 1 | 每周 | ~4 |
| host 查指定 IP | 1 | 按需/事件驱动 | ~10 |
| Monitor 告警 | 0 | 实时 | 0 |
| **合计** | | | **~15/100** |

**省额度技巧：** host 查询用 `?minify=true`（轻量）；查过的 IP 信息落盘 JSON，下次对比用缓存；突发核查（如新闻曝某 CVE）才手动花 credit。

## 第 6 步：高危资产人工复核清单

自动监控发现高危资产后按此核实（都不花钱）：
- 堡垒机/JumpServer 暴露 → 浏览器访问看登录页版本特征，核对官方 CVE 公告
- Web 服务器 CVE 标记 → 让运维确认真实版本（Shodan 指纹可能误报）
- 敏感命名子域（mysql/vault/kibana）→ curl 看 title/证书 SAN，确认是否真实服务
- 新增子域 → 判断"应有"（业务上线）还是"阴影资产"（未报备的私搭）

## 维护

- 基线误报（业务正常上下线）：直接编辑 baseline.txt
- 增加监控域名：daily-check.sh 里循环多个 DOMAIN
- 邮箱通知：Shodan Monitor 自带邮件（账号设置里绑定），与企微 webhook 互补
