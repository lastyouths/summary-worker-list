---
name: summary-worker-list
description: Summarizes today's completed work and writes it to ~/summary/yyyymmdd.md, with smart deduplication for multiple runs per day. Optionally pushes full report to Feishu Project (subtask or comment) when ~/summary/push.local.env is enabled. Supports cron via bin/install-cron.sh or "/summary-worker-list 设置定时 每日 18:00". Use when the user wants to summarize today's work, record completed tasks, update daily work log, or configure scheduled runs. Triggers on requests like "总结今天的工作", "记录工作内容", "更新工作日志", "设置定时", or "summary today's work". Also handles explicit content passed as args (e.g. "/summary-worker-list 修复了登录bug"), init command for environment setup check, and -help for usage guide.
---

# Summary Worker List

将当天工作内容汇总写入 `~/summary/yyyymmdd.md`，支持一天内多次执行并智能合并，不重复记录已有内容。

## 命令列表

| 命令 | 说明 |
|------|------|
| `/summary-worker-list` | 自动模式：从四个数据源采集并写入 |
| `/summary-worker-list <内容>` | 主动添加：直接将指定内容写入日志 |
| `/summary-worker-list search=<关键词>` | 查询模式：搜索历史日志 |
| `/summary-worker-list init` | 初始化检查：git、飞书 MCP、OKR、推送、定时 |
| `/summary-worker-list 设置定时 每日 18:00` | 安装 cron，到点自动跑 Skill |
| `/summary-worker-list 关闭定时` | 卸载 cron |
| `/summary-worker-list -help` | 显示帮助文档 |

---

## `-help` 命令

当检测到 `-help` 参数时，**直接输出以下帮助内容**，不执行任何其他操作：

```
📋 summary-worker-list — 每日工作日志助手

用法：
  /summary-worker-list                      自动汇总今日工作（git + 飞书 + OKR）
  /summary-worker-list <内容>               直接追加指定工作项，支持分号分隔多项
  /summary-worker-list search=<关键词>      在历史日志中搜索关键词
  /summary-worker-list init                 检查并初始化运行环境
  /summary-worker-list 设置定时 每日 18:00  安装 cron，到点自动汇总（+ 可选推送）
  /summary-worker-list 关闭定时             卸载 cron
  /summary-worker-list -help                显示此帮助

自动模式数据源：
  • git 提交记录  — 今日所有仓库的 commit，附 diff 语义摘要
  • 本地未提交变更 — 正在进行中的工作
  • 飞书项目已办  — 今日已完成的工作项及评论要点
  • OKR 目标      — 对齐分析（需 ~/summary/okr.md）

日志文件：~/summary/yyyymmdd.md（如 ~/summary/20260523.md）
OKR 文件：~/summary/okr.md（手动维护，按季度更新）

飞书推送（可选）：~/summary/push.local.env
  FEISHU_PUSH_ENABLED=true 时，每次写入 md 后自动推送全文到飞书项目
定时任务（可选）：
  /summary-worker-list 设置定时 每日 18:00   ← 推荐：一句话安装 cron
  或 skill/bin/cron.local.env + bin/install-cron.sh
  到点执行 claude -p "/summary-worker-list"；若 push.local.env 已启用则同时推飞书

提示：首次使用建议先运行 /summary-worker-list init 检查环境配置。
```

---

## `init` 命令

当检测到 `init` 参数时，执行环境检查流程。**每项检查均可跳过**，用户选择跳过时直接进入下一项。

### 检查项 1：Git 配置

```bash
git config --global user.name
git config --global user.email
```

**判断逻辑：**
- `user.name` 和 `user.email` 均已设置 → ✅ Git 已配置（显示当前值）
- 任意一项为空 → ⚠️ Git 未完整配置，提示用户：

```
⚠️ Git 用户信息未配置，git 提交将无法正确归因。

建议执行：
  git config --global user.name "你的姓名"
  git config --global user.email "你的邮箱"

[已配置，跳过] [现在配置]
```

若用户选择"现在配置"，引导输入 name 和 email，并用 Shell 工具执行配置命令。

### 检查项 2：飞书 MCP 是否安装

检查 MCP 配置文件中是否含有 `FeishuProject` 相关配置：

```bash
cat ~/.cursor/mcp.json 2>/dev/null | grep -i feishu
```

**判断逻辑：**
- 找到 FeishuProject 配置 → ✅ 飞书 MCP 已安装
- 未找到 → ⚠️ 提示：

```
⚠️ 未检测到飞书 MCP（user-FeishuProject），飞书已办/待办数据将不可用。

配置步骤：在 Cursor 设置 → MCP 中添加 FeishuProject 服务器。

[跳过] [已知晓，继续]
```

用户无需在此步骤实际安装，选择任意选项后继续。

### 检查项 3：OKR 文件配置

```bash
cat ~/summary/okr.md 2>/dev/null | head -5
```

**判断逻辑：**

**情况 A：文件不存在**
```
⚠️ 未找到 OKR 文件（~/summary/okr.md），OKR 对齐分析将不可用。

是否现在创建？（可填入当前季度目标）

[跳过] [创建模板]
```

若选择"创建模板"，使用 Write 工具生成：

```markdown
# OKR

## 2026 Q2（2026-04 ~ 2026-06）

### Objective 1：（请填写目标）
- KR1：（请填写关键结果）
- KR2：（请填写关键结果）
```

**情况 B：文件存在，检查是否偏移（季度过期）**

读取文件中的季度标记（如 `2026 Q2`），与当前日期对比：
- 季度匹配 → ✅ OKR 当前有效（显示 Objective 列表预览）
- 季度已过期 → ⚠️ 提示偏移：

```
⚠️ OKR 文件中的目标为 2026 Q1，当前已是 2026 Q2，目标可能已过期。

建议更新 ~/summary/okr.md 中的季度目标。

[跳过] [已知晓，继续]
```

### 检查项 4：飞书推送配置（可选）

```bash
cat ~/summary/push.local.env 2>/dev/null
```

**判断逻辑：**

**情况 A：文件不存在**
```
⚠️ 未配置飞书推送（~/summary/push.local.env），手动/定时生成不会推送到飞书项目。

是否现在创建配置模板？

[跳过] [创建模板]
```

若选择「创建模板」，从 skill 的 `examples/push.local.env.example` 复制到 `~/summary/push.local.env`（`FEISHU_PUSH_ENABLED=false` 默认关闭）。

**情况 B：文件存在**
- 读取 `FEISHU_PUSH_ENABLED`：
  - `true` → 继续验证
  - `false` 或未设置 → ⚠️ 已配置但未启用
- `FEISHU_PUSH_ENABLED=true` 时：
  - 调用 `get_workitem_brief` 验证 `FEISHU_PARENT_WORK_ITEM_ID` 可达
  - ✅ 显示 mode（subtask/comment）、父项名称与 ID
  - 失败 → ⚠️ 父项不可达，推送将在运行时失败

可选操作：`[现在启用]` → 将 `FEISHU_PUSH_ENABLED` 改为 `true`。

### 检查项 5：定时任务（可选）

```bash
cat ~/.claude/skills/summary-worker-list/bin/cron.local.env 2>/dev/null
crontab -l 2>/dev/null | grep summary-worker-list
which claude
```

**判断逻辑：**

**情况 A：未配置且 crontab 无条目**
```
⚠️ 未启用定时任务。是否安装每日定时调用 Skill？

默认时间：18:03（可在 bin/cron.local.env 修改 CRON_TIME）

[跳过] [安装]
```

若选择「安装」：
1. 若 `bin/cron.local.env` 不存在，从 `cron.local.env.example` 复制并设 `CRON_ENABLED=true`
2. 执行 `bin/install-cron.sh`

**情况 B：`CRON_ENABLED=true` 且 crontab 有条目** → ✅ 显示时间与 claude 路径

**情况 C：配置启用但 crontab 无条目** → ⚠️ 提示运行 `bin/install-cron.sh`

**情况 D：找不到 claude CLI** → ⚠️ 定时不可用，仅支持手动运行

卸载定时：`bin/uninstall-cron.sh`

### init 结束汇总

所有检查完成后，输出汇总：

```
✅ 环境检查完成

  Git 配置      ✅ user.name = xxx / user.email = xxx
  飞书 MCP      ✅ 已安装 / ⚠️ 未安装（已跳过）
  OKR 文件      ✅ 2026 Q2 有效 / ⚠️ 已过期（已跳过）/ ⚠️ 不存在（已跳过）
  飞书推送      ✅ subtask → 日报(6997973080) / ⚠️ 未配置 / ⚠️ 未启用
  定时任务      ✅ 18:03 已安装 / ⚠️ 未安装（已跳过）

现在可以运行 /summary-worker-list 开始记录今日工作。
推送已启用时，手动运行也会自动推飞书。
```

---

## 数据源概览

| 数据源 | 时间视角 | 说明 |
|--------|----------|------|
| 本地未提交变更 | **当前**（此刻进行中） | git diff/status，尚未 commit 的工作 |
| git 提交记录 | **今天**（已完成并提交） | 今日所有仓库的 commit message |
| 飞书项目已办 | **计划**（任务流中完成） | 飞书项目今日已办工作项 |
| OKR 季度目标 | **季度**（方向对齐） | 仅作上下文参考，不产生工作项 |

OKR 文件存储位置：`~/summary/okr.md`（手动维护，按季度更新）。

---

## 模式判断

按以下优先级判断模式：

| 用户输入示例 | 模式 |
|---|---|
| `/summary-worker-list -help` | **帮助模式**：输出功能说明，不操作文件 |
| `/summary-worker-list init` | **初始化模式**：逐项检查环境配置 |
| `/summary-worker-list 设置定时` 或含 `设置定时` | **定时安装模式**：解析时间并安装 cron（见下） |
| `/summary-worker-list 关闭定时` 或含 `关闭定时`/`取消定时` | **定时卸载模式**：卸载 cron |
| `/summary-worker-list` | **自动模式**：从四个数据源采集并写入 |
| `/summary-worker-list 修复了登录bug` | **主动添加模式**：直接写入参数内容 |
| `/summary-worker-list search=登录` | **查询模式**：在历史日志中搜索关键词 |
| `/summary-worker-list search=2026-05` | **查询模式**：支持按日期前缀搜索 |

**模式优先级：** `-help` > `init` > `search=` > **设置/关闭定时** > 自动模式 > 主动添加

---

## 定时安装模式（`设置定时`）

当用户输入含 **`设置定时`**（如 `/summary-worker-list 设置定时 每日 18:00`）时进入本模式，**不写入日报 md**。

### 解析时间

从用户消息中提取 `HH:MM` 或 `HH：MM`（全角冒号归一化为半角）：

| 用户输入示例 | 解析结果 |
|-------------|---------|
| `设置定时 每日 18:00` | `18:00` |
| `设置定时 18：00` | `18:00` |
| `设置定时`（无时间） | 默认 `18:03`（避开飞书整点限流） |

无效时间 → 提示用户并使用 `18:03`。

### 执行步骤

**第一步：定位 skill bin 目录**

```bash
SKILL_BIN=~/.claude/skills/summary-worker-list/bin
# Cursor 环境若 skill 在 ~/.cursor/skills/，优先使用该路径
```

**第二步：写入 `cron.local.env`**

```bash
cat > "${SKILL_BIN}/cron.local.env" <<EOF
CRON_ENABLED=true
CRON_TIME=<解析出的时间>
EOF
```

**第三步：安装 crontab**

```bash
"${SKILL_BIN}/install-cron.sh"
```

若 `install-cron.sh` 失败（如找不到 `claude`），输出错误原因及手动命令：

```bash
claude -p "/summary-worker-list" \
  --mcp-config ~/.cursor/mcp.json \
  --permission-mode bypassPermissions \
  --add-dir ~/git ~/summary
```

**第四步：确认并输出**

```bash
crontab -l 2>/dev/null | grep summary-worker-list
```

向用户报告：

```
✅ 定时已设置：每天 <HH:MM> 自动执行 /summary-worker-list
   cron 日志：~/summary/cron.log
   飞书推送：由 ~/summary/push.local.env 的 FEISHU_PUSH_ENABLED 决定
   卸载：/summary-worker-list 关闭定时
```

---

## 定时卸载模式（`关闭定时` / `取消定时`）

当用户输入含 **`关闭定时`** 或 **`取消定时`** 时：

1. 执行 `"${SKILL_BIN}/uninstall-cron.sh"`
2. 若存在 `cron.local.env`，将 `CRON_ENABLED=false` 写入
3. 输出：`✅ 已关闭定时任务`

---

## 查询模式执行步骤（search 参数）

当检测到 `search=<keyword>` 参数时，进入查询模式，**不写入任何文件**。

### 查询流程

**第一步：解析关键词**

从参数中提取关键词，例如：
- `search=登录` → 关键词：`登录`
- `search=2026-05` → 按日期前缀过滤文件，关键词匹配全文
- `search=fix` → 关键词：`fix`

**第二步：扫描文件**

```bash
KEYWORD="<用户关键词>"
ls ~/summary/*.md 2>/dev/null | sort -r
```

使用 Read 工具逐个读取匹配的日志文件（若关键词含日期格式如 `2026-05`，只读取文件名包含该前缀的文件，否则读取全部）。

**第三步：匹配并输出结果**

在读取的文件中找出包含关键词的工作项行，以如下格式汇总展示给用户：

```
## 搜索结果：「登录」

### 2026-05-20
- ✔ 修复了登录 bug（session 过期未清理）

### 2026-05-18
- ✔ 重构登录模块，拆分 token 刷新逻辑

共找到 2 条记录，跨 2 天。
```

- 按日期**倒序**排列（最近的在前）
- 仅展示匹配行及其所在日期
- 若无匹配结果，告知"未找到包含「xxx」的工作记录"

---

## 写入模式执行步骤

### 第一步：确定文件路径并读取已有内容

```bash
DATE=$(date +%Y%m%d)
FILE=~/summary/${DATE}.md
mkdir -p ~/summary
```

使用 Read 工具读取 `$FILE`（文件不存在则视为空）。同时读取 OKR 文件 `~/summary/okr.md`（不存在则跳过，仅作参考）。

### 第二步：采集各数据源（自动模式）

**数据源 1 — 本地未提交变更（当前视角）**：

```bash
for repo in ~/git/*/; do
  if [ -d "$repo/.git" ]; then
    status=$(git -C "$repo" status --short 2>/dev/null)
    if [ -n "$status" ]; then
      echo "=== $(basename $repo) ==="
      echo "$status"
    fi
  fi
done
```

提取有未提交变更的仓库及修改的文件/功能，描述为"正在进行中"的工作。

**数据源 2 — 当天 git 提交记录 + diff 语义摘要（今天视角）**：

**Step 2a：收集今日 commit message**

```bash
DATE_STR=$(date +%Y-%m-%d)
for repo in ~/git/*/; do
  if [ -d "$repo/.git" ]; then
    commits=$(git -C "$repo" log --oneline \
      --after="${DATE_STR} 00:00:00" \
      --before="${DATE_STR} 23:59:59" \
      --format="%s" 2>/dev/null)
    if [ -n "$commits" ]; then
      echo "=== $(basename $repo) ==="
      echo "$commits"
    fi
  fi
done
```

将每条 commit message 转换为工作项（去掉 emoji/前缀标签如 `feat:`/`fix:`/`docs:` 等，保留核心描述）。同一仓库多条高度相关提交可合并为一项。

**Step 2b：对今日变更做 diff 语义分析（代码变更理解）**

若 Step 2a 有提交，对有提交的仓库执行：

```bash
# 获取今日变更的文件统计
git -C "$repo" diff --stat HEAD~1 HEAD 2>/dev/null | tail -1

# 抽取关键变更文件的 diff（只取前 100 行避免过长）
git -C "$repo" diff HEAD~1 HEAD -- \
  $(git -C "$repo" diff --name-only HEAD~1 HEAD 2>/dev/null | grep -v '__init__' | head -3) \
  2>/dev/null | head -100
```

将 diff 内容交由 AI 分析，生成一句**代码变更语义摘要**（20 字以内），描述"改了什么、为什么改"，补充到该仓库的工作项后面，格式：

```markdown
- ✔ 修复并发竞态 bug（Redis key 命名统一）`+47/-23 行`
```

若今日无提交则跳过 Step 2b。

**数据源 3 — 飞书项目已办工作项 + 沟通要点（计划视角）**：

**Step 3a：今日已办工作项**

```
CallMcpTool: user-FeishuProject / list_todo
  action: "done"
  page_num: 1
```

从返回结果中筛选出**今天**（与当前日期匹配）处理完成的工作项，提取标题作为工作项描述。超过 50 条则继续翻页。

**Step 3b：今日沟通要点（工作项评论）**

对 Step 3a 中今日已办的工作项（最多取 5 个），逐个查询今日评论：

```
CallMcpTool: user-FeishuProject / list_workitem_comments
  work_item_id: <work_item_id>
  project_key: <project_key>
```

筛选 `create_time` 在今天的评论，提取评论内容摘要（每条 15 字以内）。若有评论则在日志末尾追加：

```markdown
## 沟通要点

- 「修复并发竞态」：评审通过，待发布（@张三）
- 「席位卡死修复」：测试发现边界 case，需补充
```

若无今日已办工作项或评论为空，整个「沟通要点」区块省略。MCP 调用失败则静默跳过，不阻塞整体流程。

**数据源 4 — OKR 季度目标（季度视角，仅参考）**：

读取 `~/summary/okr.md`，了解当前季度目标。此数据源**不直接产生工作项**，但用于：
- 判断今日工作是否与 OKR 对齐，在备注中写一句对齐说明
- 若今日无工作与 OKR 相关，也无需强行关联

**主动添加模式**：直接使用用户传入的参数。若含分号，按分号拆分为多项。

### 第三步：计划符合度评估

拉取飞书今日待办（含未完成项）：

```
CallMcpTool: user-FeishuProject / list_todo
  action: "todo"
  page_num: 1
```

将"今日待办"与"今日实际完成（Step 3a 已办 + git 提交）"做对比，生成：

```markdown
## 计划执行评估

| 指标 | 值 |
|------|-----|
| 计划项数 | N 项 |
| 完成项数 | M 项 |
| 完成率 | M/N % |

### ⚠️ 未完成风险项
- 「xxx」：计划今日完成，未见提交或已办记录 → 风险：延期
- 「yyy」：超出原定排期 N 天 → 风险：阻塞下游
```

- 若完成率 ≥ 80%，风险等级标为 🟢 正常
- 若完成率 60%–79%，标为 🟡 注意
- 若完成率 < 60%，标为 🔴 风险
- 若无飞书待办数据或 MCP 失败，跳过此区块

### 第四步：OKR 对齐度分析

若 `~/summary/okr.md` 存在，将今日所有工作项与每个 Objective 的 KR 做语义匹配，生成：

```markdown
## OKR 对齐

| Objective | 今日覆盖 KR | 对齐度 |
|-----------|------------|--------|
| O1「xxx」 | KR1 ✔ KR2 ✔ KR3 — | 67% |
| O2「yyy」 | KR1 — KR2 — | 0% |

> 今日重点支撑 O1，O2 本周无进展，注意节奏。
```

- `✔` 表示今日工作可关联到该 KR，`—` 表示无关联
- 对齐度 = 有关联 KR 数 / 总 KR 数
- 整季无进展的 KR 标注 `⚠️ 长期未触达`
- OKR 文件不存在时整块省略

### 第五步：合并去重写入

- 对比新工作项与已有内容，只追加尚未记录的条目
- 判断重复标准：语义相同即为重复，即使描述文字略有不同
- 已有内容保持原样，不修改、不重新排序
- 若无新增内容，告知用户"本次无新增内容"，不修改文件

使用 Write 工具将完整内容写回 `$FILE`。

**主动添加模式**完成写入后，同样进入第六步（若推送已启用）。

### 第六步：飞书项目推送（可选）

**触发条件**（同时满足才执行）：
- 已完成第五步（或主动添加模式）且 `$FILE` 存在
- `~/summary/push.local.env` 存在
- 其中 `FEISHU_PUSH_ENABLED=true`

不满足则跳过，不报错。查询/init/help 模式不执行本步。

**读取配置：**

```bash
source ~/summary/push.local.env 2>/dev/null
```

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `FEISHU_PUSH_ENABLED` | 是否推送 | `false` |
| `FEISHU_PROJECT_KEY` | 空间 key | 必填 |
| `FEISHU_PUSH_MODE` | `subtask` 或 `comment` | `subtask` |
| `FEISHU_PARENT_WORK_ITEM_ID` | 父工作项（日报锚点） | 必填 |
| `FEISHU_SUBTASK_NAME_PREFIX` | 子任务名前缀 | `工作日报` |
| `FEISHU_SUBTASK_TEMPLATE_ID` | 执行任务模板 ID | `3108870` |
| `FEISHU_SUBTASK_TYPE` | 执行任务类型 key | `684a82a87e6822379d07e7a5` |
| `FEISHU_PARENT_FIELD_KEY` | 父级关联字段 | `field_66e52a` |
| `FEISHU_SUBTASK_CONTENT_FIELD` | 子任务正文写入字段（备注） | `field_8a70c7` |

**推送内容：** 读取 `$FILE` **全文**（不做精简），写入子任务的**备注**字段（`field_8a70c7`），UI 中可见。

#### 模式 A：`subtask`（默认，同日幂等）

子任务名称：`${FEISHU_SUBTASK_NAME_PREFIX} ${DATE_STR}`，例如 `工作日报 2026-05-24`。

**Step 6a：查找已有子任务**

1. 读 `~/summary/.feishu-push.json`，若存在键 `$DATE`（yyyymmdd）且含 `work_item_id` → 使用该 ID
2. 否则调用 `get_workitem_brief`：
   - `work_item_id`: `FEISHU_PARENT_WORK_ITEM_ID`
   - `fields`: `["field_a6eb80"]`
   - 在返回的子任务列表中按**精确名称**匹配 `${FEISHU_SUBTASK_NAME_PREFIX} ${DATE_STR}`

**Step 6b：更新或创建**

- **已找到** → `update_field`：
  ```
  work_item_id: <子任务 ID>
  project_key: FEISHU_PROJECT_KEY
  fields: [{ field_key: FEISHU_SUBTASK_CONTENT_FIELD, field_value: <全文 md> }]
  ```
- **未找到** → `create_workitem`：
  ```
  project_key: FEISHU_PROJECT_KEY
  work_item_type: FEISHU_SUBTASK_TYPE
  fields:
    - { field_key: "name", field_value: "<子任务名>" }
    - { field_key: "template", field_value: FEISHU_SUBTASK_TEMPLATE_ID }
    - { field_key: FEISHU_PARENT_FIELD_KEY, field_value: FEISHU_PARENT_WORK_ITEM_ID }
    - { field_key: FEISHU_SUBTASK_CONTENT_FIELD, field_value: <全文 md> }
  ```

**Step 6c：写缓存**

更新 `~/summary/.feishu-push.json`：

```json
{
  "20260524": {
    "work_item_id": "6997821404",
    "mode": "subtask",
    "name": "工作日报 2026-05-24",
    "pushed_at": "2026-05-24T18:03:12+08:00"
  }
}
```

#### 模式 B：`comment`

直接 `add_comment`（不做幂等，每次追加一条评论）：

```
CallMcpTool: user-FeishuProject / add_comment
  project_key: FEISHU_PROJECT_KEY
  work_item_id: FEISHU_PARENT_WORK_ITEM_ID
  content: <全文 md>
```

#### 失败处理（软失败）

推送失败时：
- **不** rollback 已写入的 `$FILE`
- 追加日志到 `~/summary/push.log`（时间、mode、错误信息、work_item_id 如有）
- 向用户输出：`⚠️ 飞书推送失败，详见 ~/summary/push.log`
- 整体流程视为成功（md 已落盘）

推送成功时输出：`✅ 已推送到飞书项目：<子任务名或父项评论>`

---

## 文件格式

### 日志文件 `~/summary/yyyymmdd.md`

```markdown
# 工作日志 YYYY-MM-DD

> 今日重点：xxx，xxx。（AI 自动生成，15 字以内概括全天工作）

## 完成的工作

- ✔ 工作项描述 `+N/-M 行`             ← git 提交，含 diff 语义摘要和行数统计
- ✔ 工作项描述                         ← 飞书已办，无 diff 标注

## 进行中

- [ ] 工作项描述（未提交）               ← 本地未提交变更，语义描述，不列文件名

## 沟通要点

- 「工作项名」：评论摘要（@相关人）      ← 飞书工作项今日评论，无评论时省略整块

## 计划执行评估

🟢/🟡/🔴 完成率 M/N（M%）

### ⚠️ 未完成风险项
- 「xxx」→ 风险：延期（无提交/已办记录）

## OKR 对齐

| Objective | 今日覆盖 KR | 对齐度 |
|-----------|------------|--------|
| O1「xxx」 | KR1 ✔ KR2 — | 50% |

> 今日重点支撑 O1，O2 本周无进展，注意节奏。（无 OKR 文件时省略整块）

## 备注（可选）

补充说明、遇到的问题、明日待办等。
```

**格式规则：**
- `完成的工作` 用 `- ✔`，`进行中` 用 `- [ ]`，语义一致
- `完成的工作` 不细分来源子标题，git 提交与飞书已办合并排列
- `进行中` 只写功能描述，不暴露文件路径
- `计划执行评估` 用红绿灯标注风险等级，飞书无数据时省略
- `OKR 对齐` 精确到 KR 级，显示对齐百分比，无 OKR 文件时省略
- 摘要行 `>` 由 AI 根据当天工作项自动生成，每次写入时更新

### OKR 文件 `~/summary/okr.md`（手动维护）

```markdown
# OKR

## 2026 Q2（2026-04 ~ 2026-06）

### Objective 1：xxx
- KR1：xxx
- KR2：xxx

### Objective 2：xxx
- KR1：xxx
```

---

## 注意事项

- 文件名格式严格为 `yyyymmdd.md`，如 `20260523.md`
- 自动模式只记录**今天**产生的工作，不凭空推测
- 工作项描述保持简洁（20 字以内），避免冗长
- OKR 文件不存在时跳过对齐分析，不报错
- 主动添加模式直接信任用户输入，无需从数据源提取
- **查询模式（search）只读不写**，不修改任何文件
- search 关键词大小写不敏感，支持中英文
- search 结果超过 20 条时提示用户缩小关键词范围
- 飞书推送为可选能力：`push.local.env` 未启用时不推送
- 定时任务仅触发 Skill；推送是否执行由 `push.local.env` 决定
- `subtask` 模式同日重复运行会**更新**同一子任务，不重复创建
- `comment` 模式每次运行**追加**新评论
- 推送失败写 `~/summary/push.log`，不影响本地 md
