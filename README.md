# summary-worker-list

Claude Code skill：每日工作日志自动汇总工具。

从多个数据源（git 提交、本地未提交变更、飞书项目、OKR）自动采集当天工作内容，智能合并写入 `~/summary/yyyymmdd.md`。

## 功能

- 自动汇总今日 git 提交（含 diff 语义摘要）
- 拉取飞书项目已办工作项及沟通要点
- 计划执行评估（完成率 + 风险项）
- OKR 对齐度分析
- 支持主动添加、历史搜索、环境初始化

## 安装

在 Claude Code 中运行：

```
/install-skill https://github.com/lastyouths/summary-worker-list
```

或手动克隆到 skill 目录：

```bash
git clone https://github.com/lastyouths/summary-worker-list ~/.claude/skills/summary-worker-list
```

## 使用

```
/summary-worker-list                   自动汇总今日工作
/summary-worker-list <内容>            直接追加工作项
/summary-worker-list search=<关键词>   搜索历史日志
/summary-worker-list init              检查运行环境
/summary-worker-list -help             显示帮助
```

## 前置条件

- Claude Code CLI
- git（用于提交记录采集）
- 飞书项目 MCP（可选，用于拉取飞书工作项）
- `~/summary/okr.md`（可选，用于 OKR 对齐分析）

## 配置权限

在 `~/.claude/settings.json` 的 `permissions.allow` 中添加：

```json
"Bash(git status *)",
"Bash(git log *)",
"Bash(git diff *)",
"Bash(git config *)",
"Bash(git -C *)",
"Bash(ls ~/summary*)",
"Bash(cat ~/summary*)",
"Bash(mkdir -p ~/summary)",
"Bash(date *)",
"mcp__FeishuProjectMcp__*"
```

## License

MIT
