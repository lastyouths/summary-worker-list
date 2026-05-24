#!/usr/bin/env bash
# 安装 summary-worker-list 定时任务（调用 Skill 日报功能）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/cron.local.env"
MARKER="# summary-worker-list"
SUMMARY_DIR="${HOME}/summary"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

CRON_ENABLED="${CRON_ENABLED:-false}"
CRON_TIME="${CRON_TIME:-18:03}"

if [[ "$CRON_ENABLED" != "true" ]]; then
  echo "⚠️  CRON_ENABLED 不为 true，请编辑 ${ENV_FILE} 后重试"
  exit 1
fi

if [[ ! "$CRON_TIME" =~ ^([0-9]|[01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
  echo "⚠️  CRON_TIME 格式无效（需 HH:MM，如 18:03）: ${CRON_TIME}"
  exit 1
fi

IFS=: read -r CRON_HOUR CRON_MIN <<< "$CRON_TIME"
CRON_HOUR=$((10#${CRON_HOUR#0}))
CRON_MIN=$((10#${CRON_MIN#0}))

CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "⚠️  未找到 claude CLI，无法安装定时任务"
  echo "    请安装 Claude Code 或手动运行 /summary-worker-list"
  exit 1
fi

MCP_CONFIG="${HOME}/.cursor/mcp.json"
MCP_ARGS=()
if [[ -f "$MCP_CONFIG" ]]; then
  MCP_ARGS=(--mcp-config "$MCP_CONFIG")
else
  echo "⚠️  未找到 ~/.cursor/mcp.json，定时任务将无法使用飞书 MCP"
fi

mkdir -p "$SUMMARY_DIR"

CRON_CMD="${CRON_MIN} ${CRON_HOUR} * * * ${CLAUDE_BIN} -p \"/summary-worker-list\""
if ((${#MCP_ARGS[@]})); then
  CRON_CMD+=" ${MCP_ARGS[*]}"
fi
CRON_CMD+=" --permission-mode bypassPermissions --add-dir ${HOME}/git ${SUMMARY_DIR} >> ${SUMMARY_DIR}/cron.log 2>&1 ${MARKER}"

EXISTING="$(crontab -l 2>/dev/null | grep -v "${MARKER}" || true)"
{
  echo "$EXISTING" | sed '/^$/d'
  echo "$CRON_CMD"
} | crontab -

echo "✅ 定时任务已安装"
echo "   时间: 每天 ${CRON_TIME}"
echo "   命令: claude -p \"/summary-worker-list\""
echo "   日志: ${SUMMARY_DIR}/cron.log"
echo "   卸载: ${SCRIPT_DIR}/uninstall-cron.sh"
