# summary-worker-list

Claude Code skill：每日工作日志自动汇总工具。

从多个数据源（git 提交、本地未提交变更、飞书项目、OKR）自动采集当天工作内容，智能合并写入 `~/summary/yyyymmdd.md`。

可选：推送全文到飞书项目（子任务 / 评论）、cron 定时触发 Skill。

## 功能

- 自动汇总今日 git 提交（含 diff 语义摘要）
- 拉取飞书项目已办工作项及沟通要点
- 计划执行评估（完成率 + 风险项）
- OKR 对齐度分析
- 支持主动添加、历史搜索、环境初始化
- **可选** 飞书项目推送（subtask 同日幂等 / comment 追加评论）
- **可选** cron 定时调用 Skill

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

## 飞书推送（可选）

1. 复制配置模板：

```bash
mkdir -p ~/summary
cp ~/.claude/skills/summary-worker-list/examples/push.local.env.example ~/summary/push.local.env
```

2. 编辑 `~/summary/push.local.env`，设 `FEISHU_PUSH_ENABLED=true`

3. 之后每次 `/summary-worker-list` 写入 md 后自动推送**全文**到飞书项目

| 模式 | 行为 |
|------|------|
| `subtask`（默认） | 在父工作项下创建/更新「工作日报 YYYY-MM-DD」子任务 |
| `comment` | 在父工作项下追加评论 |

推送失败写 `~/summary/push.log`，不影响本地 md。

## 定时任务（可选）

1. 复制并编辑 cron 配置：

```bash
cp ~/.claude/skills/summary-worker-list/bin/cron.local.env.example \
   ~/.claude/skills/summary-worker-list/bin/cron.local.env
# 设 CRON_ENABLED=true，CRON_TIME=18:03
```

2. 安装 crontab：

```bash
~/.claude/skills/summary-worker-list/bin/install-cron.sh
```

3. 卸载：

```bash
~/.claude/skills/summary-worker-list/bin/uninstall-cron.sh
```

定时仅触发 Skill；是否推送飞书由 `push.local.env` 决定。

## 前置条件

- Claude Code CLI（定时任务需要）
- git（用于提交记录采集）
- 飞书项目 MCP（可选，用于拉取/推送飞书工作项）
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
"Bash(crontab *)",
"Bash(~/.claude/skills/summary-worker-list/bin/*)",
"mcp__FeishuProjectMcp__*"
```

## License

MIT
