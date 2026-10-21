---
name: ikea-reputation-monitor
description: "Monitor public sentiment and reputation risk for IKEA / Ingka / Inter IKEA across news, regulators, social media, product recalls, ESG supply chain, and store or capital moves, then produce a structured HTML daily report and optionally deliver it privately via agently-cli. This skill should be used when the user requests a company reputation-monitoring brief, a brand sentiment watch, a daily or weekly IKEA report, or asks to set up such an automated monitor."
agent_created: true
---

# 宜家 / IKEA 舆情监控 Skill

## 0. 保密红线（最高优先级）
- 监控对象（检索时必须带以排除噪声）：**宜家 / IKEA / Ingka（英格卡集团）/ Inter IKEA（英特宜家集团）**。
- 本项目为**内部私密舆情监控**，默认收件人 `nicky.gu@ingka.ikea.com`（ingka 内部域名，纯内部）。
- 报告含内部研判与未公开事件关联，**不得**外发至任何其他地址、不得公开分享、不得在群聊 / 企业微信 / Teams / 社交媒体等任何外部渠道转发。
- 仅做公开渠道监测（搜索引擎、新闻、监管公示、社媒聚合、黑猫/12315、官方召回页），不抓取内网/员工数据，不做任何违法取证。**不构成法律或合规意见。**

## 1. 输出物
- 一份 HTML 日报：`宜家舆情_{YYYY-MM-DD}.html`（落当前工作区根目录）。
- 可选：通过 agently-cli 私发至收件人（见 §6）。

## 2. 工作流程（每次运行）

### 2.1 检索（WebSearch，至少 8 组，可并行）
检索词务必含 **"宜家家居 IKEA"** 等精准前缀，排除"宜家XX商行 / 超市 / 便利超市"等名字含"宜家"的本地小店噪声。按维度组合（完整词表见 `references/keywords.md`）：

| 维度 | 示例检索词 |
|---|---|
| 监管/处罚 | `宜家家居 IKEA 被处罚 市场监管 {近月}` |
| 产品/质量/召回 | `宜家 召回 质量问题 产品 {近月}`（并直抓官网召回页 `file.app.ikea.cn`、台湾 `ikea.com.tw/zh/recalls`） |
| 社媒/争议 | `宜家 微博 热搜 争议 {近月}`、`小红书 宜家 吐槽 投诉 质量问题 {年}`、`宜家 餐厅 价签 误导`、`宜家 非买勿座 沙发` |
| 经营/关店 | `宜家 关店 裁员 最新消息 {近月}`、`宜家 宜家中国 最新动态 {近月}`、`宜家 抖音 旗舰店` |
| 集团/国际 | `Inter IKEA Group latest news {月} {年}`、`IKEA Reddit discussion controversy {月}`、`IKEA second hand marketplace {国}`、`IKEA Romania Greenpeace`、德/法/美各语种补充检索 |
| 竞品 | `源氏木语 宜家 反超`、`林氏家居 宜家`（跟踪"平替/反超"叙事） |

### 2.2 时间窗过滤（关键）
- 默认仅纳入**过去 24 小时（滚动窗口）**公开舆情——本 skill 主用于每日监控，故窗口收紧为 24h，避免与日报重复堆积。对每条命中项核验发布日期（精确到小时更稳妥）。
- 若用户要求做周报 / 月报或手动深度复盘，可临时放宽至近 30 天或更长，并在报告"窗口"字段与"已排除项"中明确标注。
- **历史旧闻一律排除**：如"全球提价9%"实为 **2021-12-30** Ingka/Reuters 旧闻（新冠供应链危机），不得计入当期。在报告"已排除项"中注明其真实日期与来源（24h 窗口下通常已自动排除，仅作核验兜底）。

### 2.3 情感标注 rubric（统一执行，禁止主观随意）
- 🔴 **负面** = 监管处罚 / 产品召回 / 质量缺陷 / 客诉集中 / 误导消费 / 体验降级 / 供应链可持续争议（如木材砍伐）/ 裁员收缩。
- 🔵 **中性** = 战略调整（关店转小店）/ 价格变动 / 新店开业 / 渠道拓展 / 财报事实，仅陈述无褒贬。
- 🟢 **正面** = ESG 举措（二手平台·减排）/ 正向联名 / 高管任命 / 降价惠民 / 增长型新店。

### 2.4 优先级
- `P0` 需立即升级（实体抗议、正式监管/FSC投诉、数据泄露）
- `P1` 本周跟进（处罚、召回、集中客诉、营销翻车、裁员）
- `P2` 常规监测（渠道拓展、联名、正面ESG、国际新店、Reddit产品讨论）

### 2.5 跨期去重（cross-period dedup）
- 24h 滚动窗口下，超过 24 小时的旧事件本就不计入；本步主要处理"昨日已报、今日仍在 24h 窗口内持续发酵"的事件。
- 运行前用 Glob 读取工作区 `宜家舆情_*.html` **近 2 天**文件，提取已报事件标题/URL 归一化建"已报事件库"。
- 本轮新命中若与库内同指（同一事件持续发酵），在报告末尾 `<section class="repeat">` 标注"持续（昨日已报）/ 新增量"，避免把持续事件误报为全新突发；纯新事件正常进入"今日速览"。

### 2.6 生成 HTML 报告
- 复用本 skill 的 `assets/template.html`：含图例(rubric+优先级)、顶部 P0 重点预警（若有）、今日速览（按优先级排序）、六大板块（① 品牌经营 / ② 产品·质量·召回 / ③ 客诉与社媒 / ④ ESG·可持续·供应链 / ⑤ 国际·竞品·法律 / ⑥ 网络安全·隐私·合规）、repeat 区、局限说明。
- 每条带**原文链接**；社媒项尽量附量化互动量（赞/评）用于排序。
- 模板变量：`{{DATE}}` `{{WEEKDAY}}` `{{RECIPIENT}}` `{{WINDOW}}`。

### 2.7 投递（可选，需用户授权收件人）
生成一份简洁 HTML 摘要（`--body-file`）并将完整报告作为附件，用 agently-cli 两段确认发送：

```bash
AGENTLY="$HOME/.workbuddy/binaries/node/workspace/node_modules/@tencent-qqmail/agently-cli-win32-x64/bin/agently-cli.exe"
"$AGENTLY" message +send \
  --to nicky.gu@ingka.ikea.com \
  --subject "宜家/IKEA 舆情监控日报 {DATE}" \
  --body-file ./summary_{DATE}.html \
  --attachment ./宜家舆情_{DATE}.html
# 首次调用返回 confirmation_token + summary；
# 二次调用加 --confirmation-token <token> 完成发送。
# 自动化场景（用户已预授权自身邮箱）可直接追加 --confirmed 跳过交互确认。
```

- 附件/正文路径**相对当前工作目录**；正文支持 HTML（自动识别），单文件 ≤ 1 MB。
- 私密报告无需脱敏；但若某日被要求转发给外部（如 dl.group.cisdp.cn@ingka.com），须先脱敏摘要正文 + 完整版作附件。

## 3. 信源能力与局限（务必在报告"局限"章说明）
- WebSearch 为主力，多关键词可靠；黑猫投诉 / 12315 / 市场监管可抓；微博 / 小红书 / 抖音反爬强，覆盖率约 70–80%，依赖聚合站（什么值得买 / 网易 / 今日头条）转述，精确赞评数偶有出入，不追求 100%。
- Reddit 反爬，用 WebSearch 兜底；英文 / 德文源需补充对应语种检索。
- 仅公开渠道，不构成法律 / 合规意见。

## 4. 频率建议
- 默认**每日 1 次（含周末，凌晨执行）**，配合 24 小时滚动窗口，正好覆盖"昨日此刻—今日此刻"的新增舆情。
- 重大事件（P0）可临时加跑；本地自动化依赖客户端在线，离线不补跑，如需不依赖本地请用云端任务。

## 5. 参考文件
- `references/keywords.md`：公司实体、风险/正面维度关键词、时间窗锚点与已知历史旧闻、优先信源清单。
- `assets/template.html`：HTML 报告模板（含 `{{DATE}}` 等占位符与格式范例）。
