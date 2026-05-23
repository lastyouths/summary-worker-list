---
name: summary-worker-list
description: Summarizes today's completed work and writes it to ~/summary/yyyymmdd.md, with smart deduplication for multiple runs per day. Use when the user wants to summarize today's work, record completed tasks, or update daily work log. Triggers on requests like "总结今天的工作", "记录工作内容", "更新工作日志", or "summary today's work". Also handles explicit content passed as args (e.g. "/summary-worker-list 修复了登录bug"), init command for environment setup check, and -help for usage guide.
---

# Summary Worker List

将当天工作内容汇总写入 `~/summary/yyyymmdd.md`，支持一天内多次执行并智能合并，不重复记录已有内容。

## 命令列表

| 命令 | 说明 |
|------|------|
| `/summary-worker-list` | 自动模式：从四个数据源采集并写入 |
| `/summary-worker-list <内容>` | 主动添加：直接将指定内容写入日志 |
| `/summary-worker-list search=<关键词>` | 查询模式：搜索历史日志 |
| `/summary-worker-list init` | 初始化检查：验证 git、飞书 MCP、OKR 配置 |
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
  /summary-worker-list -help                显示此帮助

自动模式数据源：
  • git 提交记录  — 今日所有仓库的 commit，附 diff 语义摘要
  • 本地未提交变更 — 正在进行中的工作
  • 飞书项目已办  — 今日已完成的工作项及评论要点
  • OKR 目标      — 对齐分析（需 ~/summary/okr.md）

日志文件：~/summary/yyyymmdd.md（如 ~/summary/20260523.md）
OKR 文件：~/summary/okr.md（手动维护，按季度更新）

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

### init 结束汇总

所有检查完成后，输出汇总：

```
✅ 环境检查完成

  Git 配置      ✅ user.name = xxx / user.email = xxx
  飞书 MCP      ✅ 已安装 / ⚠️ 未安装（已跳过）
  OKR 文件      ✅ 2026 Q2 有效 / ⚠️ 已过期（已跳过）/ ⚠️ 不存在（已跳过）

现在可以运行 /summary-worker-list 开始记录今日工作。
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
| `/summary-worker-list` | **自动模式**：从四个数据源采集并写入 |
| `/summary-worker-list 修复了登录bug` | **主动添加模式**：直接写入参数内容 |
| `/summary-worker-list search=登录` | **查询模式**：在历史日志中搜索关键词 |
| `/summary-worker-list search=2026-05` | **查询模式**：支持按日期前缀搜索 |

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
