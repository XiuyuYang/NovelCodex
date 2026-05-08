#!/bin/bash
# 全局一致性审计：每 N 章运行一次
set -e
NOVEL_ROOT="${NOVEL_ROOT:-$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)}"
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
cd "$NOVEL_ROOT"
INTERVAL=${1:-20}
COMPLETED=$(grep -oE '"last_completed_chapter":[[:space:]]*[0-9]+' runtime.json 2>/dev/null | grep -oE '[0-9]+$' | head -1)
COMPLETED=${COMPLETED:-0}
AUDIT_DUE=$(( COMPLETED % INTERVAL == 0 && COMPLETED > 0 ))
if [ "$AUDIT_DUE" -ne 1 ]; then
  echo "AUDIT_DUE=false"
  echo "NEXT_AUDIT_AT=$(( (COMPLETED / INTERVAL + 1) * INTERVAL ))"
  exit 0
fi
ISSUES=0
[ ! -f "memory/story-bible.md" ] && { echo "[FAIL] story-bible.md missing"; ISSUES=$((ISSUES+1)); }
[ ! -f "memory/arcs.md" ] && { echo "[FAIL] arcs.md missing"; ISSUES=$((ISSUES+1)); }
if [ -f "memory/foreshadowing.md" ]; then
  OVERDUE=$(grep -c "超期\|逾期" memory/foreshadowing.md 2>/dev/null || echo 0)
  [ "$OVERDUE" -gt 0 ] && { echo "[FAIL] $OVERDUE overdue foreshadows"; ISSUES=$((ISSUES+1)); }
fi
echo "AUDIT_RESULT=$([ $ISSUES -eq 0 ] && echo PASSED || echo BLOCKED)"
[ $ISSUES -gt 0 ] && exit 1 || exit 0
