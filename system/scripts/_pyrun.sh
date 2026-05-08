#!/bin/bash
# Python 跨平台调用 wrapper
# 解决 Windows 上 python3 不存在的问题，并强制 UTF-8 输出
# 用法：bash scripts/_pyrun.sh script.py [args...]

# 强制 Python 用 UTF-8 处理 IO（避免 Windows cp936 终端乱码）
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1

# 自动选择可用的 Python 解释器
PY=""
for cmd in python3 python py; do
    if command -v "$cmd" >/dev/null 2>&1; then
        # 排除 Windows Store 的 stub（执行后会显示安装提示，返回非 0）
        VER=$("$cmd" --version 2>&1)
        case "$VER" in
            "Python "*)
                PY="$cmd"
                break
                ;;
        esac
    fi
done

if [ -z "$PY" ]; then
    echo "[ERROR] No Python interpreter found. Install Python 3 from https://www.python.org/downloads/" >&2
    exit 127
fi

exec "$PY" "$@"
