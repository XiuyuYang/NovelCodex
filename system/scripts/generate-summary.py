#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""扫描 logs/workflow-log.md 与 memory/ 生成 output/_summary.md"""
import io, os, re, sys

# 跨平台 UTF-8 输出
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

NOVEL_ROOT = os.environ.get("NOVEL_ROOT") or os.getcwd()

def read(rel):
    p = os.path.join(NOVEL_ROOT, rel)
    if not os.path.exists(p):
        return ""
    with io.open(p, "r", encoding="utf-8") as f:
        return f.read()

def write(rel, content):
    p = os.path.join(NOVEL_ROOT, rel)
    d = os.path.dirname(p)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(p, "w", encoding="utf-8") as f:
        f.write(content)

log = read("logs/workflow-log.md")
budget = read("memory/pacing-budget.md")
fore = read("memory/foreshadowing.md")

scores = re.findall(r"第\s*(\d+)\s*章.*?终审.*?评分[:：]\s*([0-9.]+)", log)
chapters = sorted(set(s[0] for s in scores), key=int)

lines = ["# 全书汇总报告\n\n"]
lines.append("## 章节评分\n\n")
lines.append("| 章号 | 终审评分 |\n|------|---------|\n")
for ch in chapters:
    chapter_scores = [float(s[1]) for s in scores if s[0] == ch]
    if chapter_scores:
        lines.append("| ch{:0>2} | {:.2f} |\n".format(ch, chapter_scores[-1]))

if chapters:
    all_scores = [float(s[1]) for s in scores]
    lines.append("\n**平均**：{:.2f} / 5\n".format(sum(all_scores)/len(all_scores)))
    lines.append("**最高**：{:.2f}\n".format(max(all_scores)))
    lines.append("**最低**：{:.2f}\n".format(min(all_scores)))

if fore:
    pending = len(re.findall(r"^\|\s*F\d+", fore, re.M))
    lines.append("\n## 伏笔健康度\n\n")
    lines.append("活跃契约（待回收）：{} 条\n".format(pending))
    lines.append("详见 memory/foreshadowing.md\n")

if budget:
    lines.append("\n## 字数与节奏\n\n详见 memory/pacing-budget.md\n")

write("output/_summary.md", "".join(lines))
print("[written] output/_summary.md")
