# skills

WorkBuddy / Agent 通用技能收纳仓库。

所有技能统一存放于此，每个技能一个子目录，目录名即技能名，内含 `SKILL.md`：

```
skills/
├── README.md
└── <skill-name>/
    └── SKILL.md
```

## 已收录技能

- `daily-digest-methodology` —— 通用「每日 / 定期信息简报」流水线方法论：多源采集、跨期去重、结构化精选、深度分析（横向切层）、可信交付。适用于安全情报 / AI 动态 / 财经 / 行业研究等任意主题的信息源监控。

## 用法

1. 克隆本仓库。
2. 将所需技能的 `<skill-name>/` 目录复制到 WorkBuddy 用户级技能目录 `~/.workbuddy/skills/`（或项目级 `<workspace>/.workbuddy/skills/`）。
3. 刷新 WorkBuddy 即可在对话中调用。

> 本仓库是技能的"源仓库"，本地 `~/.workbuddy/skills/` 为 WorkBuddy 实际加载位置，两边保持同步即可。
