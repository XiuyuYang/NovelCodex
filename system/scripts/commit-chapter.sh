#!/bin/bash
# 章节通过终审后自动提交（仅当 runtime.json.git_auto_commit = true）
# 用法：bash scripts/commit-chapter.sh {NN} {final_score}
# Fallback chain: env var → Cowork sandbox → git root → cwd
NOVEL_ROOT="${NOVEL_ROOT:-}"
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)
fi
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
fi
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
NN=$1
SCORE=$2

cd "$NOVEL_ROOT" || exit 1

# 检测开关
if [ -f runtime.json ]; then
  AUTO=$(jq -r '.git_auto_commit // false' runtime.json)
  if [ "$AUTO" != "true" ]; then
    echo "[skip] runtime.json.git_auto_commit != true"
    exit 0
  fi
fi

if [ ! -d .git ]; then
  echo "[skip] 非 git 仓库"
  exit 0
fi

git add output/ drafts/ memory/ logs/ runtime.json 2>/dev/null
if git diff --staged --quiet; then
  echo "[skip] 无改动可提交"
  exit 0
fi
git commit -m "ch${NN} done | ${SCORE}/5" --quiet
echo "[ok] 已提交 ch${NN}"
