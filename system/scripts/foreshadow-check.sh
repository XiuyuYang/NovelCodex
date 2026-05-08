#!/bin/bash
# 伏笔健康度扫描
# 用法：bash scripts/foreshadow-check.sh {current_chapter}
# Fallback chain: env var → Cowork sandbox → git root → cwd
NOVEL_ROOT="${NOVEL_ROOT:-}"
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)
fi
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
fi
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
cd "$NOVEL_ROOT"

CUR=${1:-99}
F="memory/foreshadowing.md"

# 1. 任何"待定"都是违规
WAIT=$(grep -c "| 待定 |" "$F" 2>/dev/null || echo 0)
if [ "$WAIT" -gt 0 ]; then
  echo "⚠️ 发现 $WAIT 条伏笔为「待定」，必须给出计划回收章号"
  grep "| 待定 |" "$F"
  exit 1
fi

# 2. 超期未回收（计划回收章 ≤ 当前章 但状态仍为 埋下/强化/延期）
OVERDUE=$(awk -v cur="$CUR" '
  /^\| F[0-9]+/ {
    n = split($0, a, "|")
    plan = a[5]; gsub(/[ ]/, "", plan)
    status = a[6]; gsub(/[ ]/, "", status)
    if (plan ~ /^[0-9]+$/ && plan + 0 <= cur && status ~ /(埋下|强化|延期)/) {
      print $0
    }
  }
' "$F")
if [ -n "$OVERDUE" ]; then
  echo "⚠️ 超期未回收伏笔："
  echo "$OVERDUE"
  exit 1
fi

echo "✓ 伏笔健康度通过"
exit 0
