#!/bin/bash
# 会话交棒检测与执行
set -e
NOVEL_ROOT="${NOVEL_ROOT:-$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)}"
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
cd "$NOVEL_ROOT"
COMPLETED=$(grep -oE '"last_completed_chapter":[[:space:]]*[0-9]+' runtime.json 2>/dev/null | grep -oE '[0-9]+$' | head -1)
TOTAL=$(grep -oE '"total_chapters_to_write":[[:space:]]*[0-9]+' runtime.json 2>/dev/null | grep -oE '[0-9]+$' | head -1)
BATCH_SIZE=$(grep -oE '"max_chapters_per_session":[[:space:]]*[0-9]+' runtime.json 2>/dev/null | grep -oE '[0-9]+$' | head -1)
COMPLETED=${COMPLETED:-0}; TOTAL=${TOTAL:-0}; BATCH_SIZE=${BATCH_SIZE:-5}
[ "$COMPLETED" -ge "$TOTAL" ] 2>/dev/null && { echo "HANDOFF_REQUIRED=false"; echo "REASON=all_done"; exit 0; }
BATCH_START=$(( ( (COMPLETED - 1) / BATCH_SIZE ) * BATCH_SIZE + 1 ))
CHAPTERS_IN_BATCH=$(( COMPLETED - BATCH_START + 1 ))
if [ "$CHAPTERS_IN_BATCH" -ge "$BATCH_SIZE" ] && [ "$COMPLETED" -lt "$TOTAL" ]; then
  echo "HANDOFF_REQUIRED=true"
  echo "BATCH_START=$BATCH_START"
  echo "BATCH_END=$COMPLETED"
  echo "NEXT_CHAPTER=$(( COMPLETED + 1 ))"
else
  echo "HANDOFF_REQUIRED=false"
  echo "NEXT_CHAPTER=$(( COMPLETED + 1 ))"
fi
