#!/usr/bin/env bash
# 卸载 summary-worker-list 定时任务
set -euo pipefail

MARKER="# summary-worker-list"

if crontab -l 2>/dev/null | grep -q "${MARKER}"; then
  crontab -l 2>/dev/null | grep -v "${MARKER}" | sed '/^$/d' | crontab -
  echo "✅ 已移除 summary-worker-list 定时任务"
else
  echo "ℹ️  未找到 summary-worker-list 定时任务条目"
fi
