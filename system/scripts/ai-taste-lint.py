#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""AI 味机械检测器 v2：扫描正文给出量化违规清单
新增：AI高频词黑名单检测（一级/二级/三级禁令）
"""
import io, os, re, sys

# 跨平台 UTF-8 输出（Windows cp936 终端不再乱码）
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

if len(sys.argv) < 2:
    print("usage: python3 ai-taste-lint.py path/to/chapter.txt")
    sys.exit(2)

p = sys.argv[1]
with io.open(p, "r", encoding="utf-8") as f:
    text = f.read()

# 跳过首行标题
lines = text.split("\n")
if lines and re.match(r"^第\s*\d+\s*章", lines[0]):
    body = "\n".join(lines[2:])
else:
    body = text

paragraphs = [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()]
total_chars = sum(len(p) for p in paragraphs)

violations = []

# ============================================================
# 新增：AI高频词黑名单检测（来自用户反馈）
# ============================================================

# 一级禁令词（出现即违规，全章 0 容忍）
LEVEL1_BLACKLIST = [
    ("指节发白", "一级禁令：指节发白（强AI味生理反应）"),
    ("喉结滚动", "一级禁令：喉结滚动（强AI味生理反应）"),
    ("呼吸一滞", "一级禁令：呼吸一滞（强AI味生理反应）"),
    ("瞳孔微缩", "一级禁令：瞳孔微缩（强AI味生理反应）"),
    ("身体一僵", "一级禁令：身体一僵（强AI味生理反应）"),
    ("后背一凉", "一级禁令：后背一凉（强AI味生理反应）"),
    ("心口一紧", "一级禁令：心口一紧（强AI味生理反应）"),
    ("眼底闪过一丝", "一级禁令：眼底闪过一丝（模板神态）"),
    ("眸色一沉", "一级禁令：眸色一沉（模板神态）"),
    ("神色复杂", "一级禁令：神色复杂（模板神态，应改为具体行为）"),
    ("面色微变", "一级禁令：面色微变（模板神态）"),
    ("空气仿佛凝固", "一级禁令：空气仿佛凝固（AI万能环境句）"),
    ("气氛瞬间凝滞", "一级禁令：气氛瞬间凝滞（AI万能环境句）"),
    ("一种莫名的", "一级禁令：一种莫名的（抽象填充词）"),
    ("说不清的情绪", "一级禁令：说不清的情绪（抽象填充词）"),
    ("难以言喻", "一级禁令：难以言喻（抽象填充词，应用具体描写代替）"),
    ("不知为何", "一级禁令：不知为何（应展示困惑而非陈述）"),
]

for word, label in LEVEL1_BLACKLIST:
    cnt = body.count(word)
    if cnt > 0:
        violations.append("{}：出现 {} 次（一级禁令，应清零）".format(label, cnt))

# 二级禁令词（严格控制，全章累计 ≤ 3 次）
LEVEL2_BLACKLIST = [
    ("脚步一顿", "二级禁令"),
    ("手指微微收紧", "二级禁令"),
    ("下意识地", "二级禁令"),
    ("忍不住", "二级禁令"),
    ("愣了一下", "二级禁令"),
    ("怔住了", "二级禁令"),
    ("若有所思", "二级禁令"),
    ("欲言又止", "二级禁令"),
    ("心里一沉", "二级禁令"),
    ("心头一酸", "二级禁令"),
    ("隐隐不安", "二级禁令"),
    ("有种不好的预感", "二级禁令"),
]

l2_total = 0
for word, label in LEVEL2_BLACKLIST:
    cnt = body.count(word)
    l2_total += cnt
    if cnt > 0:
        violations.append("二级禁令「{}」：出现 {} 次（全章累计限 ≤ 3）".format(word, cnt))

if l2_total > 3:
    violations.append("二级禁令词全章累计 {} 次（限 ≤ 3，超标 {} 次）".format(l2_total, l2_total - 3))

# 三级禁令词（隐形AI味，全章 ≤ 8 次）
LEVEL3_WORDS = ["微微", "轻轻", "缓缓", "淡淡", "浅浅", "慢慢", "几分", "些许", "隐隐", "仿佛", "似乎", "大概"]
l3_total = 0
for word in LEVEL3_WORDS:
    cnt = body.count(word)
    l3_total += cnt
if l3_total > 8:
    violations.append("三级弱化修饰词全章累计 {} 次（限 ≤ 8，超标 {} 次）".format(l3_total, l3_total - 8))

# 四级：典型AI模板句检测
AI_TEMPLATES = [
    (r"他微微一怔[，。]", "AI模板句：他微微一怔……"),
    (r"眼底闪过一丝.{2,6}的情绪", "AI模板句：眼底闪过一丝……的情绪"),
    (r"沉默.{1,6}片刻[，。]", "AI模板句：沉默了片刻……"),
    (r"缓缓开口", "AI模板句：缓缓开口"),
    (r"不知为何.{0,10}心里隐隐", "AI模板句：不知为何心里隐隐……"),
    (r"轻轻咬了咬嘴唇", "AI模板句：轻轻咬了咬嘴唇"),
]
for pat, label in AI_TEMPLATES:
    if re.search(pat, body):
        violations.append(label)

# ============================================================
# 原有检测（保留）
# ============================================================

# A. 安全意象重复
SAFE_IMAGES = {
    "萤火虫": 0, "棉花": 0, "气泡膜": 0, "涟漪": 0, "心电图": 0,
    "海浪": 0, "潮水": 0, "镜子": 0, "钝刀": 0, "影子": 0,
}
for img in SAFE_IMAGES:
    cnt = body.count(img)
    if cnt >= 2:
        violations.append("安全意象「{}」出现 {} 次（限 ≤ 1 次/章）".format(img, cnt))

# B. 句式黑名单
BLACKLIST = [
    (r"不是[^，。\\n]{1,20}，是那种", "句式：不是A，是那种B"),
    (r"忽然觉得[^，。\\n]{0,15}自己像", "句式：他忽然觉得，自己像X"),
    (r"隔着[^，。\\n]{1,20}，[^，。\\n]{0,10}成了", "句式：隔着X，他成了Y"),
    (r"往外是[^，。\\n]{1,20}，往里是", "句式：往外是A，往里是B"),
    (r"像在告诉谁", "句式：像在告诉谁"),
    (r"溺水的人", "句式：溺水的人看见X"),
    (r"心电图般|像心电图", "句式：心电图般"),
]
for pat, name in BLACKLIST:
    cnt = len(re.findall(pat, body))
    if cnt > 0:
        violations.append("{}：出现 {} 次（应为 0）".format(name, cnt))

# C. 自问句
self_q = re.findall(r"那是种?什么样的[^？]{1,8}？", body)
if len(self_q) > 1:
    violations.append("自问句解释情绪：{} 次（限 ≤ 1）".format(len(self_q)))

# D. 矛盾词并置
contrast = re.findall(r"又(\\w{1,4})又(\\w{1,4})", body)
real_contrast = [c for c in contrast if c[0] != c[1]]
if len(real_contrast) > 1:
    violations.append("矛盾词并置「又X又Y」：{} 次（限 ≤ 1）".format(len(real_contrast)))

# E. 比喻密度
similes = len(re.findall(r"像[^，。\\n]{2,}[一似]", body))
if total_chars > 0:
    rate = similes * 1000.0 / total_chars
    if rate > 5:
        violations.append("比喻密度过高：每千字 {:.1f} 个，限 ≤ 5".format(rate))

# F. 段落长度方差
short_count = sum(1 for p in paragraphs if len(p) <= 30)
long_count = sum(1 for p in paragraphs if len(p) >= 200)
mid_count = sum(1 for p in paragraphs if 100 <= len(p) <= 150)

if short_count < 3:
    violations.append("≤ 30 字短段不足：{} 个（要求 ≥ 3）".format(short_count))
if long_count < 3:
    violations.append("≥ 200 字长段不足：{} 个（要求 ≥ 3）".format(long_count))
if paragraphs and mid_count * 1.0 / len(paragraphs) > 0.5:
    violations.append("100-150 字段落占比 {:.0%}（AI 温区，限 ≤ 50%）".format(mid_count*1.0/len(paragraphs)))

# G. 干句子比例
def is_dry(p):
    return not re.search(r"像|觉得|似乎|仿佛|宛如|犹如", p)
dry_count = sum(1 for p in paragraphs if is_dry(p))
if paragraphs and dry_count * 1.0 / len(paragraphs) < 0.25:
    violations.append("干句子段落比例 {:.0%}（要求 ≥ 25%）".format(dry_count*1.0/len(paragraphs)))

# H. 连续3段比喻
has_simile = [bool(re.search(r"像", p)) for p in paragraphs]
for i in range(len(has_simile) - 2):
    if has_simile[i] and has_simile[i+1] and has_simile[i+2]:
        violations.append("连续 3 段都有「像」：第 {}-{} 段（要求每 3 段至少 1 段无比喻）".format(i+1, i+3))
        break

# I. 新增：AI模板收尾检测
last_para = paragraphs[-1] if paragraphs else ""
if re.search(r"这不仅是.{2,10}，更是", last_para):
    violations.append("章末AI模板收尾：这不仅是…更是…（解释式升华）")
if re.search(r"而.{2,15}，或许.{2,10}才是", last_para):
    violations.append("章末AI模板收尾：而…或许…才是（哲学独白式）")

# 报告
print("=" * 60)
print("AI 味机械检测 v2：{}".format(p))
print("=" * 60)
print("段落数：{}  正文字数：{}".format(len(paragraphs), total_chars))
print("≤30字短段：{}  100-150字段：{}  ≥200字长段：{}".format(short_count, mid_count, long_count))
print("干句子段落：{}（{:.0%}）  比喻总数（粗）：{}".format(dry_count, dry_count*1.0/max(len(paragraphs),1), similes))
print("一级禁令词命中：{}  二级禁令词累计：{}  三级弱化词累计：{}".format(
    sum(1 for v in violations if "一级禁令" in v),
    l2_total, l3_total))
print("")
if violations:
    print("发现 {} 项违规：".format(len(violations)))
    for v in violations:
        print("  - {}".format(v))
    sys.exit(1)
else:
    print("[OK] 所有检测通过")
    sys.exit(0)
