#!/bin/bash
# 续写/中断恢复检测：检查当前进度，输出续写起点
# 用于配额恢复后或续写命令的自动检测
# 输出 resume_mode: fresh_start | continue_after_output | has_outline_no_output
set -e

NOVEL_ROOT="${NOVEL_ROOT:-}"
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"

cd "$NOVEL_ROOT" 2>/dev/null || { echo "ERROR: cannot access $NOVEL_ROOT"; exit 1; }

# ── 获取时间戳 ──
NOW=$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M' 2>/dev/null || date '+%Y-%m-%d %H:%M')

echo "# Resume Check @ $NOW"
echo ""

# 初始化变量
LAST_NUM=0
BP_NUM=0
OL_NUM=0

# ── 检测 output/ 中的已完成章节 ──
if [ -d "output" ]; then
  COMPLETED=$(ls -1 output/ 2>/dev/null | grep -E '^第[0-9]+章' | sort -V | tail -1)
  if [ -n "$COMPLETED" ]; then
    # 提取章号，兼容 "第01章" 和 "第1章"
    LAST_NUM=$(echo "$COMPLETED" | sed -n 's/^第0*\([0-9]*\)章.*/\1/p')
    [ -z "$LAST_NUM" ] && LAST_NUM=0
    echo "output_last_chapter: $LAST_NUM"
    echo "output_last_file: $COMPLETED"
  else
    echo "output_last_chapter: 0"
  fi
else
  echo "output_last_chapter: 0"
fi

# ── 检测 drafts/ 中的蓝图/细纲 ──
if [ -d "drafts" ]; then
  LAST_BLUEPRINT=$(ls -1 drafts/ 2>/dev/null | grep -E '^[0-9]+-blueprint\.md$' | sort -V | tail -1)
  LAST_OUTLINE=$(ls -1 drafts/ 2>/dev/null | grep -E '^[0-9]+-outline\.md$' | sort -V | tail -1)
  if [ -n "$LAST_BLUEPRINT" ]; then
    BP_NUM=$(echo "$LAST_BLUEPRINT" | sed 's/^0*//' | grep -oE '^[0-9]+')
    echo "drafts_last_blueprint: $BP_NUM"
  else
    echo "drafts_last_blueprint: 0"
  fi
  if [ -n "$LAST_OUTLINE" ]; then
    OL_NUM=$(echo "$LAST_OUTLINE" | sed 's/^0*//' | grep -oE '^[0-9]+')
    echo "drafts_last_outline: $OL_NUM"
  else
    echo "drafts_last_outline: 0"
  fi
else
  echo "drafts_last_blueprint: 0"
  echo "drafts_last_outline: 0"
fi

# ── 判断续写起点 ──
echo ""
if [ "$LAST_NUM" -gt 0 ] 2>/dev/null; then
  NEXT=$((LAST_NUM + 1))
  echo "resume_from_chapter: $NEXT"
  echo "resume_mode: continue_after_output"
  echo "status: has_completed_chapters"
elif [ "$OL_NUM" -gt 0 ] 2>/dev/null; then
  echo "resume_from_chapter: $OL_NUM"
  echo "resume_mode: has_outline_no_output"
  echo "status: has_outline_no_output"
elif [ "$BP_NUM" -gt 0 ] 2>/dev/null; then
  echo "resume_from_chapter: $BP_NUM"
  echo "resume_mode: has_blueprint_no_output"
  echo "status: has_blueprint_no_outline"
else
  echo "resume_from_chapter: 1"
  echo "resume_mode: fresh_start"
  echo "status: no_content"
fi

# ── 检查 runtime.json ──
if [ -f "runtime.json" ]; then
  echo ""
  echo "runtime_json: exists"
  # 兼容 GNU grep 和 BSD grep
  LCC=$(grep -oE '"last_completed_chapter":[[:space:]]*[0-9]+' runtime.json 2>/dev/null | grep -oE '[0-9]+$' || echo "0")
  echo "runtime_last_completed_chapter: ${LCC:-0}"
  # 读取其他关键配置
  MODE=$(grep -oE '"book_mode":[[:space:]]*"[^"]*"' runtime.json 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"' || echo "unknown")
  TIER=$(grep -oE '"quality_tier":[[:space:]]*"[^"]*"' runtime.json 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"' || echo "unknown")
  echo "runtime_book_mode: $MODE"
  echo "runtime_quality_tier: $TIER"
else
  echo ""
  echo "runtime_json: missing"
fi

# ── 检查 workflow-log ──
if [ -f "logs/workflow-log.md" ]; then
  echo ""
  LAST_LOG_CHAPTER=$(tail -20 logs/workflow-log.md 2>/dev/null | grep -oE '第[[:space:]]*[0-9]+[[:space:]]*章' | tail -1 | grep -oE '[0-9]+' || echo "none")
  echo "log_last_mentioned_chapter: ${LAST_LOG_CHAPTER:-none}"
fi

# ── 检查 output/ 章节是否连续 ──
if [ -d "output" ]; then
  ALL_CHAPTERS=$(ls -1 output/ 2>/dev/null | grep -E '^第[0-9]+章' | sort -V)
  if [ -n "$ALL_CHAPTERS" ]; then
    echo ""
    echo "# Chapter sequence:"
    echo "$ALL_CHAPTERS"
  fi
fi
