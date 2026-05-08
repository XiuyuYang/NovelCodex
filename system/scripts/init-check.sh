#!/bin/bash
# 第 N≥2 章启动前置门禁
# 用法：bash scripts/init-check.sh {N}
# v3：跨平台 Python 调用 + UTF-8 强制

# Fallback chain: env var → Cowork sandbox → git root → cwd
NOVEL_ROOT="${NOVEL_ROOT:-}"
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)
fi
if [ -z "$NOVEL_ROOT" ]; then
  NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
fi
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
cd "$NOVEL_ROOT" || exit 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYRUN="$SCRIPT_DIR/_pyrun.sh"

N=$1
if [ -z "$N" ]; then
  echo "Usage: init-check.sh {chapter_N}"
  exit 2
fi
if [ "$N" -le 1 ] 2>/dev/null; then
  echo "[skip] chapter 1 doesn't need gate check"
  exit 0
fi

ERRORS=""

# 0. 故事圣经必须存在且已填充
if [ ! -f "memory/story-bible.md" ]; then
  ERRORS="${ERRORS}\n  - memory/story-bible.md 不存在（故事宪法文件）"
else
  BIBLE_SIZE=$(stat -c%s "memory/story-bible.md" 2>/dev/null || echo 0)
  if [ "$BIBLE_SIZE" -lt 300 ]; then
    ERRORS="${ERRORS}\n  - story-bible.md 未填充（${BIBLE_SIZE} 字节），请填入核心前提/主角弧线/世界观铁律"
  fi
fi

# 0b. 弧线追踪文件必须存在
if [ ! -f "memory/arcs.md" ]; then
  ERRORS="${ERRORS}\n  - memory/arcs.md 不存在（弧线追踪文件）"
fi


# 1. style-bible 至少 5 段正例（用 ``` 包围的代码块对数）
SAMPLES=$(grep -c '^```' memory/style-bible.md 2>/dev/null || echo 0)
SAMPLES=$((SAMPLES / 2))
if [ "$SAMPLES" -lt 5 ]; then
  ERRORS="${ERRORS}\n  - style-bible.md sample count = ${SAMPLES} (need >= 5)"
fi

# 2. lessons.md 至少 3 条
LESSONS=$(grep -c '^### \[ch' memory/lessons.md 2>/dev/null || echo 0)
if [ "$LESSONS" -lt 3 ]; then
  ERRORS="${ERRORS}\n  - lessons.md count = ${LESSONS} (need >= 3)"
fi

# 3. characters.md 中每个角色必须含虚拟首语
MISSING=$("$PYRUN" - <<'PYEOF'
import io, re
try:
    with io.open('memory/characters.md', 'r', encoding='utf-8') as f:
        c = f.read()
except:
    print(''); raise SystemExit(0)
roles = re.findall(r'^### (\S+)', c, re.M)
roles = [r for r in roles if r != '{角色名}']
missing = []
for r in roles:
    block = c.split('### ' + r, 1)[1].split('\n### ', 1)[0]
    if '虚拟首语' not in block or '尚未有对白' in block or '（待' in block:
        missing.append(r)
print(','.join(missing))
PYEOF
)
if [ -n "$MISSING" ]; then
  ERRORS="${ERRORS}\n  - characters.md missing dummy quote: ${MISSING}"
fi

# 4. 上一章伏笔不能有"待定"
WAITING=$("$PYRUN" - <<'PYEOF'
import io
try:
    with io.open('memory/foreshadowing.md', 'r', encoding='utf-8') as f:
        c = f.read()
except:
    print(0); raise SystemExit(0)
lines = [l for l in c.split('\n') if l.startswith('| F') and '待定' in l]
print(len(lines))
PYEOF
)
if [ "$WAITING" -gt 0 ] 2>/dev/null; then
  ERRORS="${ERRORS}\n  - foreshadowing has ${WAITING} pending items (not allowed)"
fi

# 5. 提示本章是否有伏笔到期
THIS=$(printf '%02d' "$N")
THIS="$THIS" "$PYRUN" - <<'PYEOF'
import io, os, re
this = os.environ.get('THIS', '')
try:
    with io.open('memory/foreshadowing.md', 'r', encoding='utf-8') as f:
        c = f.read()
except:
    raise SystemExit(0)
for line in c.split('\n'):
    if line.startswith('| F') and '|' in line:
        parts = [p.strip() for p in line.split('|')]
        if len(parts) >= 5:
            plan = parts[4]
            if this in plan or plan == this:
                print('[reminder] this chapter is foreshadow-recall: ' + line)
PYEOF

# 总判
if [ -n "$ERRORS" ]; then
  echo "[block] chapter ${N} gate check failed:"
  printf "$ERRORS\n"
  exit 1
fi

echo "[ok] chapter ${N} gate check passed"
exit 0
