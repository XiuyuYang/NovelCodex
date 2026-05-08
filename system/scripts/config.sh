#!/bin/bash
# 运行时配置读写工具：runtime.json 在工作区根，是当前小说的唯一权威源
# 用法：
#   source scripts/config.sh
#   config_get quality_tier        # 读取
#   config_set quality_tier 高档    # 写入
#   config_show                    # 全量

# Fallback chain: env var → Cowork sandbox → git root → cwd
NOVEL_ROOT="${NOVEL_ROOT:-}"
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)
fi
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
fi
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
RUNTIME="$NOVEL_ROOT/runtime.json"

config_get() {
  jq -r ".${1}" "$RUNTIME"
}

config_set() {
  local key=$1
  local val=$2
  local tmp=$(mktemp)
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    jq ".${key} = ${val}" "$RUNTIME" > "$tmp"
  elif [[ "$val" == "true" || "$val" == "false" ]]; then
    jq ".${key} = ${val}" "$RUNTIME" > "$tmp"
  else
    jq ".${key} = \"${val}\"" "$RUNTIME" > "$tmp"
  fi
  mv "$tmp" "$RUNTIME"
}

config_show() {
  jq . "$RUNTIME"
}
