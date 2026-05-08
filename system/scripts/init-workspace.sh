#!/bin/bash
# 工作区初始化：从 templates/ 复制骨架到工作区根
# 已存在的文件不覆盖。支持 Linux/macOS/Windows(Git Bash)
# 用法: bash init-workspace.sh [NOVEL_ROOT]
set -e

# ── 确定工作区根目录 ──
NOVEL_ROOT="${NOVEL_ROOT:-}"
if [ -z "$NOVEL_ROOT" ] && [ -n "$1" ]; then
  NOVEL_ROOT="$1"
fi
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"

if [ ! -d "$NOVEL_ROOT" ]; then
  echo "[ERROR] NOVEL_ROOT not found: $NOVEL_ROOT"
  echo "Usage: bash init-workspace.sh /path/to/novel"
  exit 1
fi

if [ ! -f "$NOVEL_ROOT/AGENTS.md" ]; then
  echo "[WARN] AGENTS.md not found at $NOVEL_ROOT - trying parent dir"
  if [ -f "$NOVEL_ROOT/../AGENTS.md" ]; then
    NOVEL_ROOT=$(cd "$NOVEL_ROOT/.." && pwd)
    echo "[INFO] Corrected NOVEL_ROOT=$NOVEL_ROOT"
  else
    echo "[ERROR] No AGENTS.md found. Is $NOVEL_ROOT a NovelCodex workspace?"
    exit 1
  fi
fi

# v3 plugin 自检：确保工作区已含 .codex-plugin/plugin.json
if [ ! -f "$NOVEL_ROOT/.codex-plugin/plugin.json" ]; then
  echo "[WARN] No .codex-plugin/plugin.json in $NOVEL_ROOT - plugin metadata may not be loaded."
  echo "       Copy .codex-plugin/ + agents/ + scripts/ + templates/ from plugin root."
fi

cd "$NOVEL_ROOT" || exit 1
echo "init-workspace @ $NOVEL_ROOT"

# ── 1. 创建运行时目录 ──
mkdir -p output drafts logs memory
echo "  [+] dirs: output/ drafts/ logs/ memory/"

# ── 2. 从模板复制 memory 骨架（仅不存在的文件） ──
COPIED=0
SKIPPED=0
MEMORY_FILES="README.md world.md characters.md timeline.md foreshadowing.md \
              locations.md style-bible.md lessons.md pacing-budget.md \
              planner-notes.md writer-notes.md"
for f in $MEMORY_FILES; do
  if [ ! -f "memory/$f" ]; then
    if [ -f "templates/memory/$f" ]; then
      cp "templates/memory/$f" "memory/$f"
      COPIED=$((COPIED + 1))
    else
      touch "memory/$f"
      echo "  [~] memory/$f (empty - template missing)"
    fi
  else
    SKIPPED=$((SKIPPED + 1))
  fi
done
echo "  [+] memory: $COPIED copied, $SKIPPED skipped"

# ── 3. 创建 runtime.json（仅不存在时） ──
if [ ! -f "runtime.json" ]; then
  if [ -f "templates/runtime.json.template" ]; then
    cp templates/runtime.json.template runtime.json
  else
    # 模板不存在则内联创建
    NOW_ISO=$(TZ='Asia/Shanghai' date '+%Y-%m-%dT%H:%M:%S+08:00' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S+08:00')
    cat > runtime.json <<JSON
{
  "current_genre": "通用小说",
  "quality_tier": "中档",
  "book_mode": "前N章",
  "total_chapters_to_write": 3,
  "last_completed_chapter": 0,
  "max_revision_rounds": 5,
  "git_auto_commit": true,
  "two_digit_chapter_naming": true,
  "schema_version": 3,
  "created_at": "${NOW_ISO}"
}
JSON
  fi
  echo "  [+] runtime.json"
else
  echo "  [.] runtime.json (exists)"
fi

# ── 4. 创建日志文件（仅不存在时） ──
NOW=$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M' 2>/dev/null || date '+%Y-%m-%d %H:%M')

if [ ! -f "logs/workflow-log.md" ]; then
  cat > logs/workflow-log.md <<LOG
# 创作流程日志

## 项目信息
- 初始化时间：$NOW
- 体裁：待配置
- 品质档位：待配置
- 模式：待配置
- 计划创作：待配置
- 状态：待配置

LOG
  echo "  [+] logs/workflow-log.md"
fi

if [ ! -f "logs/chapter-index.md" ]; then
  cat > logs/chapter-index.md <<IDX
# 章节索引

| 章号 | 短标题 | 一句话主旨 | 字数 |
|------|--------|-----------|------|
IDX
  echo "  [+] logs/chapter-index.md"
fi

if [ ! -f "logs/agent-calls.md" ]; then
  cat > logs/agent-calls.md <<AGENT
# Agent 调用记录

| 时间 | 章号 | Agent 类型 | 任务 | 成功/失败 | 轮次 |
|------|------|-----------|------|----------|------|
AGENT
  echo "  [+] logs/agent-calls.md"
fi

echo ""
echo "init-workspace done. Ready for chapter creation."
