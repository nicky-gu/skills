---
name: privacy-compliance-daily-digest
description: 生成《国内数据隐私 / 合规 / 数据出境每日日报（深读版）》——面向企业甲方的数据合规分析师 skill。每天定时抓取国家网信办/工信部/TC260/地方通管局等官方一手信源，按五板法（监管立法 / 执法处罚 / 数据出境 / 合规义务 / 企业动态）聚类去重打分，输出带字体颜色区分的 HTML 深读版报告并邮件投递。适用于需每日跟踪国内数据隐私、个人信息保护与数据出境合规动态的自动化 / 简报场景。本 skill 是 daily-digest-methodology 在数据合规垂直领域的专项落地。
---

# 国内数据隐私 / 合规 / 数据出境每日日报 · 执行规范

面向企业甲方的数据合规分析师。把国家网信办、工信部、TC260、各地通管局等官方一手信源，稳定地变成**"该关注什么 + 该做什么动作"**的每日深读版 HTML 报告。

本 skill 是 `daily-digest-methodology` 在数据合规垂直领域的专项落地：通用流水线（信源管理 → 窗口采集 → 跨期去重 → 结构化精选 → 深度分析 → 持续跟踪 → 可信交付）照用，本文档只补充本垂直的**五板分类、信源清单、评分公式、配色与 HTML 模板、交付命令**。

> 环境-specific 默认值（按你的环境调整）：工作区 `C:/Users/Nicky Gu/WorkBuddy/Claw`；投递邮箱 `dl.group.cisdp.cn@ingka.com`；邮件用 `agently-cli`（绝对路径见【交付】）。

## 核心原则（先记住这四条）

1. **甲方视角**：日报是"给甲方看的分析"，不是法规条文堆砌。重"该关注什么 + 该做什么动作"。
2. **合规底线**：全程防御 / 合规视角，**绝不提供任何规避监管、绕过合规审查或危害数据安全的操作指引**。
3. **颜色区分 + 正文可读**：邮件正文放完整可读报告（非仅附件），并用字体颜色区分内容类型，方便一眼扫读。
4. **链接不可删**：每条新闻必须附原文链接（来自 WebFetch / WebSearch 抓到的官方或权威 article URL）。URL 不属于敏感信息，不得以任何理由删除；速览、五板、深读、降级区每一条都要带链接。

## 窗口约束

只收录**最近 24 小时**内披露或活跃的事件（以运行时刻往前 24h）。历史旧案、本周早些时候发布但今日无新进展的重大事项，进入「📎 近期重大（跟踪区）」降级显示，不充数进主板。周末 / 节假日天然低谷，在文内标注。

## 五板分类（映射到本垂直）

- ① **监管与立法动态（红）** — 网信办 / 工信部 / 人大 / 标准委等的法规、规章、征求意见稿、解释
- ② **执法与处罚通报（橙）** — 各地网信办 / 通管局 App 违规通报、个人信息保护违法处罚、数据安全处罚
- ③ **数据出境与跨境（绿）** — 数据出境安全评估、标准合同备案、负面清单、跨境流动试点、认证
- ④ **合规义务与标准（蓝）** — 企业需落实的合规动作、国标 / 行标 / 团标、实施倒计时、审计与评估办法
- ⑤ **企业动态与行业观察（紫）** — 企业数据治理实践、行业报告、重大数据相关并购 / 融资、专家解读

## 信源分级与评分

- **信源权重**：T1 官方一手（监管机构公告 / 官方解读 / 法规原文）= 3；T1.5 官方渠道（政府新闻发布会 / 权威媒体转载官方稿）= 2；T2 媒体 / KOL / 社区 = 1。
- **确定性评分**：`score = 信源权重 × 影响级别 × 甲方相关性`
  - 影响级别：全国生效 / 强制 = 3，地方 / 行业 = 2，一般 = 1
  - 甲方相关性：普遍适用企业 = 1.5
  - 例：`★13.5 T1` = 3 × 3 × 1.5
- **取舍**：`score ≥ 2.0` 且去重后取前 ≤ 10 条进主板，否则进📎跟踪区。

## 跨期去重与降级显示（防连日重复）

1. **构建事件库**：用 Glob 读 `国内数据隐私合规出境日报_*.html`（最近 3 天、不含今天）；失败则退化为"仅当日窗口内去重"，不得阻塞产出。提取指纹：a) 法规 / 文件编号；b) 关键实体（监管机构 + 文件 / 企业，如「网信办《大型个人信息处理者规定》」「川渝通管局 App 通报」「北京数据出境负面清单」）；c) 一句话主题。汇总成 `已报事件库`（实体 / 主题 → 首报日期 M/D）。
2. **当日匹配**：命中且无实质性新进展（无新规 / 无新解读要点 / 无新处罚 / 无新备案评估进展 / 无实施节点临近）→ 判「重复 / 延续」降级。命中且有新进展 → 保留较高优先级，条目内标「🔁 延续·M/D 首报·今日进展：xxx」。
3. **降级显示**：降级事件不进主板 / 不进速览，集中放报告末尾 `<section class="repeat">`（🔁 历史重复 / 持续跟踪），用 `.dup` 样式（半透明、虚线灰边、灰色小标题、带「复」徽标 + "已于 M/D 首报"），只给一句话状态 / 今日进展 + 原文链接，不展开大段。
4. **单报去重**：同一事件禁止在 overview / 五板 / 深读中重复成多条全文，只留一个主位置。深读可补充新分析，但不得复述该 section 已写事实原文。

## 信息源清单（优先一手官方权威）

- **监管一手**：WebFetch 抓 国家网信办（www.cac.gov.cn）、全国信息安全标准化技术委员会（www.tc260.org.cn）、工业和信息化部（www.miit.gov.cn）的法规 / 公告 / 征求意见稿栏目；务必保留每条原文 URL。
- **地方执法通报**：WebFetch / WebSearch（allowed_domains 指向官方 `*.gov.cn` 域）抓各地网信办 / 通信管理局 App 违规通报、个人信息保护处罚。
- **解读与行业**：WebSearch 抓权威媒体（南都个人信息保护、21 世纪经济报道、第一财经）专家解读、行业报告。
- **禁区**：Reddit 全端点本环境常被反爬封锁，勿用 WebFetch reddit；社区仅用 WebSearch `allowed_domains=["*.gov.cn","cac.gov.cn","tc260.org.cn","miit.gov.cn"]` 等官方域兜底且降权。**严禁主要依赖 WebSearch 二手聚合**；WebSearch 仅作官方源不可达时的兜底，且每条仍须附权威原文链接。

## 报告结构（简体中文，HTML 邮件正文）——内容前置，方法论压末尾

- 首部：`<h1 class="title">标题</h1>` + `<div class="meta">日期 / 窗口 / 定位一句话</div>`
- `<div class="overview">` 今日速览：`<ol>` 列当日最关键 5-6 条（仅全新 / 重大进展），每条 `<a>标题</a>` + 半句关注 / 动作（`<span class="action">` 标绿）
- `<section class="board b1">` 一、① 监管与立法动态 … 每条目 `<div class="item"><h3>标题</h3> <span class="src t1">T1·源名</span> <span class="score">★13.5</span> <p class="fact">事实</p> <p class="action">甲方动作</p> <p class="link">原文：<a href="URL">URL</a></p></div>`
- （②=b2 橙 / ③=b3 绿 / ④=b4 蓝 / ⑤=b5 紫；T1=src t1 绿 / T1.5=src t15 蓝 / T2=src t2 灰）
- `<section class="deep">` ★ 今日深读：背景 / 机制 / 对甲方含义 / 可落地动作，参考原文用 `<a>`
- `<section class="repeat">` 🔁 历史重复 / 持续跟踪（降级显示）
- `<div class="method">` 信息源与方法说明（信源分级 / 评分 / 窗口 / 边界 / 清单）
- 「📎 近期重大（跟踪区）」折叠简报用 `<div class="fold">` 包裹（窗口外但本周重大、值得持续关注的事项）

## 配色规范（唯一权威 = 下方 HTML 模板的 `<style>` 块，严禁偏离）

- 五板 pill：①红 `#d32f2f` / ②橙 `#e65100` / ③绿 `#2e7d32` / ④蓝 `#1565c0` / ⑤紫 `#6a1b9a`
- 信源标签：T1 绿 `#2e7d32` / T1.5 蓝 `#1565c0` / T2 灰 `#757575`
- score ★ 橙 `#e65100` 加粗；事实深灰 `#333`；甲方动作绿 `#2e7d32` 加粗；原文链接蓝 `#1565c0`
- 速览块浅红底 `#fff4f4` + 红左边框 `#d32f2f`；深读块浅紫底 `#f3f0ff` + 紫边框 `#6a1b9a`；方法说明浅灰底 `#f5f5f5` 灰字 `#555`；折叠简报虚线浅灰框
- 降级样式：`.dup` / `.repeat` 用 `#bbb`(虚线边) / `#666`(灰标题) / `#9e9e9e`(复徽标底) / `#eee`(降级区底) / `#fafafa`(降级条底)；半透明 `opacity:.55`
- 字体统一 `-apple-system,"Microsoft YaHei","PingFang SC",sans-serif`

## HTML 模板（直接套用，仅替换内容，整段原样输出）

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<style>
  body{font-family:-apple-system,"Microsoft YaHei","PingFang SC",sans-serif;color:#1a1a1a;line-height:1.65;max-width:780px;margin:0 auto;padding:18px;background:#fff;}
  .title{font-size:21px;font-weight:700;color:#0d1b3e;border-bottom:3px solid #0d1b3e;padding-bottom:8px;margin:0 0 6px;}
  .meta{color:#666;font-size:13px;margin:0 0 16px;}
  .overview{background:#fff4f4;border-left:4px solid #d32f2f;padding:10px 14px;border-radius:4px;margin:14px 0;}
  .overview ol{margin:6px 0;padding-left:20px;} .overview li{margin:6px 0;}
  .board{margin:20px 0;} .board-h{font-size:16px;color:#fff;display:inline-block;padding:5px 12px;border-radius:4px;margin:0 0 10px;}
  .b1 .board-h{background:#d32f2f;} .b2 .board-h{background:#e65100;} .b3 .board-h{background:#2e7d32;} .b4 .board-h{background:#1565c0;} .b5 .board-h{background:#6a1b9a;}
  .item{border:1px solid #ececec;border-radius:6px;padding:10px 13px;margin:10px 0;}
  .item h3{margin:0 0 6px;font-size:15px;color:#111;}
  .src{font-size:12px;color:#fff;padding:1px 7px;border-radius:3px;margin-right:6px;}
  .t1{background:#2e7d32;} .t15{background:#1565c0;} .t2{background:#757575;}
  .score{color:#e65100;font-weight:700;font-size:13px;}
  .fact{color:#333;margin:5px 0;} .action{color:#2e7d32;font-weight:600;margin:5px 0;}
  .link{color:#1565c0;font-size:13px;margin:5px 0;word-break:break-all;}
  .deep{background:#f3f0ff;border:1px solid #6a1b9a;border-radius:8px;padding:14px 16px;margin:20px 0;} .deep h2{color:#6a1b9a;margin-top:0;}
  .fold{color:#888;font-size:13px;background:#fafafa;border:1px dashed #ddd;border-radius:6px;padding:8px 12px;margin:10px 0;}
  .method{background:#f5f5f5;border-radius:6px;padding:12px 14px;color:#555;font-size:13px;margin-top:18px;}
  .item.dup{opacity:.55;border:1px dashed #bbb;background:#fafafa;}
  .item.dup h3{color:#666;font-size:14px;}
  .dup-badge{display:inline-block;font-size:11px;color:#fff;background:#9e9e9e;padding:1px 6px;border-radius:3px;margin-right:6px;}
  .repeat{margin:18px 0;} .repeat-h{font-size:15px;color:#555;background:#eeeeee;display:inline-block;padding:5px 12px;border-radius:4px;margin:0 0 8px;}
  a{color:#1565c0;}
</style>
</head>
<body>
  <h1 class="title">国内数据隐私 / 合规 / 数据出境每日日报（深读版）</h1>
  <div class="meta">日期：YYYY-MM-DD（周X）｜窗口：近24h｜定位：给企业甲方看的"该关注什么 + 该做什么"</div>
  <div class="overview"><strong>📌 今日速览（一眼看完）</strong><ol>
    <li><a href="URL">标题</a> —— <span class="action">动作半句</span></li>
  </ol></div>
  <section class="board b1"><h2 class="board-h">一、① 监管与立法动态</h2>
    <div class="item"><h3>标题</h3><span class="src t1">T1·源名</span><span class="score">★13.5</span>
      <p class="fact">事实：…</p><p class="action">甲方动作：…</p><p class="link">原文：<a href="URL">URL</a></p></div>
  </section>
  <section class="board b2"><h2 class="board-h">二、② 执法与处罚通报</h2>…</section>
  <section class="board b3"><h2 class="board-h">三、③ 数据出境与跨境</h2>…</section>
  <section class="board b4"><h2 class="board-h">四、④ 合规义务与标准</h2>…</section>
  <section class="board b5"><h2 class="board-h">五、⑤ 企业动态与行业观察</h2>…</section>
  <section class="deep"><h2>★ 今日深读：主题</h2>…背景/机制/含义/动作…<p class="link">参考原文：<a href="URL">…</a></p></section>
  <section class="repeat"><h2 class="repeat-h">🔁 历史重复 / 持续跟踪（降级显示）</h2>
    <div class="item dup"><h3><span class="dup-badge">复</span>事件标题（已于 M/D 首报）</h3><p class="fact">一句话状态/今日进展</p><p class="link">原文：<a href="URL">URL</a></p></div>
  </section>
  <div class="method"><strong>信息源与方法说明（简版）</strong><br>…信源分级/评分/窗口/边界/清单…</div>
</body>
</html>
```

## 深读板块要求

必须有"深度"：解释机制与原理、给出甲方视角的判断、避免堆砌事实。必须附参考原文链接列表。优先采用「横向切层」模式（把当日多条表面无关的新闻串成同一结构的不同层级），并串联历史维度形成连续性；每条深读给 6 条分优先级的可落地动作。

## 交付

1. **保存**：先 `cd C:/Users/Nicky Gu/WorkBuddy/Claw`，写入绝对路径 `C:/Users/Nicky Gu/WorkBuddy/Claw/国内数据隐私合规出境日报_YYYY-MM-DD.html`（务必用此绝对路径，勿写入其他子目录）。
2. **邮件同步**（自动两段确认，无需人工干预）：
   - agently-cli 绝对路径：`C:/Users/Nicky Gu/.workbuddy/binaries/node/workspace/node_modules/@tencent-qqmail/agently-cli-win32-x64/bin/agently-cli.exe`
   - 先 `cd C:/Users/Nicky Gu/WorkBuddy/Claw` 再执行；先 `agently-cli auth status` 确认 `logged_in=true`，未登录则仅文件交付并在报告注明。
   - 发送命令（`--body-file` 与 `--attachment` 必须传相对路径文件名，不要传绝对路径，否则报 `--body-file must be a relative path`；因前置已 cd 到 Claw，直接用文件名即可）：
     `agently-cli message +send --to dl.group.cisdp.cn@ingka.com --subject "国内数据隐私合规出境日报 YYYY-MM-DD（深读版）" --body-file 国内数据隐私合规出境日报_YYYY-MM-DD.html --attachment 国内数据隐私合规出境日报_YYYY-MM-DD.html`
   - 若返回 `confirmation_required=true` 且含 `confirmation_token`：立即在同一运行内用完全相同的命令（含 `--to` 和 `--body-file` 相对文件名）追加 `--confirmation-token <token>` 重跑完成发送，不要转文件交付、不要等待用户。
   - 若内容被安全过滤拒绝（`content_rejected`）：正文改为"安全摘要 + 引导看附件"——敏感细节可隐去，但每条新闻原文 URL 必须保留；完整报告仍作附件重试一次；仍失败则文件交付并注明。
3. **对话内交付**：通过 `deliver_attachments` 交付该文件。

## 调度示例（automation）

```
FREQ=DAILY;BYHOUR=12;BYMINUTE=0   # 每天中午 12:00（本机时区）
```
