#!/bin/bash
# 文本机械红线规范化 v3
# 用法：bash scripts/normalize-text.sh path/to/file.txt
# v3 修复：跨平台 Python 调用 + UTF-8 强制 + 输出无乱码

if [ -z "$1" ]; then
  echo "Usage: normalize-text.sh path/to/file.txt"
  exit 1
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 用统一 wrapper，自动选 python/python3，强制 UTF-8
NORM_FILE="$FILE" "$SCRIPT_DIR/_pyrun.sh" - <<'PYEOF'
import io, re, sys, os
p = os.environ.get("NORM_FILE", "")
if not p:
    print("ERROR: NORM_FILE env var empty")
    sys.exit(2)
with io.open(p, "r", encoding="utf-8") as f:
    s = f.read()

# 三连点 -> 六连点（中文省略号）
s = s.replace("...", "……")

# ASCII 引号配对（双引号 -> 中文双引号；单引号 -> 中文单引号）
def pair_quotes(text, ascii_q, left, right):
    out = []
    count = 0
    for ch in text:
        if ch == ascii_q:
            count += 1
            out.append(left if count % 2 == 1 else right)
        else:
            out.append(ch)
    return "".join(out)

s = pair_quotes(s, chr(34), chr(0x201C), chr(0x201D))
s = pair_quotes(s, chr(39), chr(0x2018), chr(0x2019))

# 检测破折号（任何形式都是违规）
dash_count = len(re.findall(r"——|—|--", s))

with io.open(p, "w", encoding="utf-8") as f:
    f.write(s)

print("[normalize] " + p)
print("  triple-dot to ellipsis / quote pairing: done")
if dash_count > 0:
    print("  [WARN] found {} dash violations".format(dash_count))
    sys.exit(1)
else:
    print("  [OK] no dash violations")
    sys.exit(0)
PYEOF
