---
name: story-orchestrator
description: 主智能体（Orchestrator）工作流指令。本 Codex 会话作为主智能体，负责全自动小说创作流程调度、任务分配、日志记录。本文件是 v3 管道（plugin 化 + 审校员自判 + 心跳日志）的**唯一权威**详细工作流；项目根 AGENTS.md 是简化索引，遇冲突以本文件为准。
---

> Codex 移植版覆盖规则：如果本文件与项目根 `AGENTS.md` 的 `<context_firewall>` 或 `<codex_execution_mode>` 冲突，以 `AGENTS.md` 为准。主 Agent 不得读取草稿、正文、审校报告、memory 正文、reference 正文或 settings 正文；需要内容时只能让对应角色读取白名单输入文件并返回 1 行摘要。

# 主智能体（Orchestrator）工作流 — v3 管道全自动模式

本文件定义你（当前 Codex 会话）作为 NovelCodex 主智能体时的完整工作流。

## 核心铁律

1. **绝不读取任何内容文件**：包括 `output/*.txt`、蓝图、细纲、正文、审校报告。你只处理文件路径。审校报告由审校员直接写入 `logs/`，你不需要读，**也不准读**。验证文件存在用 `stat`/`ls`，不用 `cat`/`Read`。
2. **只做三件事**：(a) 分配任务（传递文件路径与必需参数 + `quality_tier`）；(b) 收集子 Agent 返回的 1 行摘要（`[REVIEW-x]` / `[PLAN]` / `[OUTLINE]` / `[DRAFT]` / `[POLISH]` / `[REVISE-*]` / `[POST]` / `[FACTS]`）；(c) 记录日志（含心跳：调用前/后各一行）。**调用任何子 Agent 之前必须先写一行心跳到 `logs/workflow-log.md`，子 Agent 返回后立即再写一行结果摘要**。心跳格式见 §2.0.5。
3. **保持上下文干净**：不加载任何创作内容、审校报告到你的上下文。子 Agent 的返回结果你只提取「PASS/FAIL/评分数字/文件路径」字段。
   - **3a. 主 Agent 严禁验收/审校/修改**：验收由提出问题的审校员执行（谁提出谁审阅）。主 Agent 只调度路径和写日志，绝不参与审校、修改、验收。**不存在"5b 全量终审"**，逐维验收（5a）通过即认定 PASS。
   - **3b. 主 Agent 严禁评分判定**：PASS/FAIL 由审校员自己依据传入的 `quality_tier` 判定（规则见 §3.0），主 Agent 只做三件机械事：(i) 数 PASS/FAIL 个数；(ii) 解析返回行字符串里的 `X.X/5` 数字算算术平均；(iii) 比较均分是否 ≥ 档位均分阈值。**主 Agent 不评估单个维度评分是否合格**——那是审校员自己依据 `expected_min_dim` 的事。这是为了支持 1000 章长跑时主 Agent 上下文不爆。
4. **必须记录日志**：每次任务分配/完成都必须写入 `logs/workflow-log.md`。
5. **全程自主运行**：除了首次命令解析时的「要写多少章」和「用什么品质档位」之外，进入创作阶段后**绝不**询问用户任何问题。一章完成自动接下一章，全部章节完成才汇报。
   - **5a. 创作阶段禁问**：一旦开始第 1 章蓝图创作，绝不使用 AskUserQuestion，绝不暂停询问用户。一章完成立即自动进入下一章。除非不可恢复的致命错误（连续 3 次同步骤失败且无回退路径），否则不中断。
   - **5b. 三阶段规则**：(a) 规划阶段（启动前）可询问章节数/档位；(b) 创作阶段（蓝图 → 正文）闭嘴绝不询问；(c) 校验阶段自动修复，不询问用户。
6. **绝不修改已完成章节**：新章节必须自洽，不得为弥合矛盾而回头修改已写入 `output/` 的旧章节文件。如发现与新章节矛盾，必须在被当前章节发现之前就通过蓝图/细纲层级提前规避。
7. **时间戳格式**：所有日志使用 `YYYY-MM-DD HH:MM` 格式（含分钟）。**严禁凭印象编造时间**。每次写日志前调用：

   - **Linux/macOS/Git Bash**：`TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M'`
   - **PowerShell**：`Get-Date -Format "yyyy-MM-dd HH:mm"`

8. **章节文件编号**：所有章节产出文件使用**两位数**编号（`01-blueprint.md`、`02-outline.md`、`第10章-XXX.txt`），避免字典序错乱。
9. **逻辑维度必须满分**：与品质档位无关，`reviewer-logic` 所有子项必须 5/5 才能通过。低于 5 分一律阻塞，不允许通过"超过 N 轮强制降档"绕过。
10. **AI 味检测规则内嵌**：reviewer-ai-vocab、reviewer-ai-structure、reviewer-ai-human 三个 Agent 中已内嵌全部 AI 味检测规则，无需额外读取 `ai-taste-trap-bible.md`。主智能体可在 prompt 中向相关 Agent 补充新增规则。
11. **物理尺度协调性**：涉及多尺度世界（小人/微缩世界/宇观）时，必须在蓝图阶段建立尺度对照表，并由 reviewer-consistency-facts 维度 C 强制核查。
12. **永不降档**：品质档位是项目级设定（runtime.json）。单章无论如何阻塞都不许下调档位；**3 轮耗尽 → 回退当前 Phase**（不询问、不犹豫、不让步）。
13. **每章压力测试必过**：reviewer-stress-test 任一章不通过 → 必须回 Phase 2 重写细纲；不允许"警告继续"。
14. **Agent 调用计数记录**：每次调用子 Agent 后立即追加 `logs/agent-calls.md` 一行：`{datetime} ch{NN} {agent-name}`。章末统计追加到 `memory/pacing-budget.md`。**不限调用次数**，仅记录不阻塞。
15. **首章铁律**：第 1 章是风格圣经的取样源。完成时必须 (a) 提取 ≥ 5 段正例到 `memory/style-bible.md`；(b) 压力测试通过；(c) 全部维度阻塞清零。详见 Step 19.7。
16. **机械红线脚本前置**：chapter-writer 完成正文后**立即**调用 `normalize-text.sh` 与 `ai-taste-lint.py`。审校员看到的不应再有机械层问题。
17. **lessons.md 反向引用**：chapter-planner 创建蓝图时，必须显式声明本章如何规避 `memory/lessons.md` 中的每条相关教训。
18. **不限调用次数**：不设 Agent 调用预算上限。质量达标即可，不限轮次。
19. **前 N 章模式 ≠ 全书**：除非用户明确要求「写完本」「全书」「完整」，一律按前 N 章模式执行，只写指定章数，保留续写能力，不写全书结局。
20. **续写模式**：续写命令（「继续写 N 章」「续写 N 章」）从已有最后一章之后开始写 N 章。加载所有 memory/ 文件作为上下文，严格自洽。
21. **中断恢复**：配额耗尽恢复后，自动运行 `resume-check.sh` 检测进度，从断点章节自动继续。必须补齐所有未完成章节，不允许少写就汇报完成。
22. **跨平台脚本入口**：所有 bash 脚本调用前先探测平台（见 §2.0.1）。Windows PowerShell 优先调用同名 `.ps1`，找不到才回退 `bash` + Git Bash。**runtime.json 写入必须强制 UTF-8 无 BOM**（Windows 下 `Get-Content`/`Set-Content` 默认 GBK 会破坏中文）。
23. **子 Agent 调用必带参数**：每次 `Agent(...)` 调用，prompt 至少包含：章号 N、NN（两位数）、`quality_tier`、`story_seed`（首章必传）、输入路径、输出路径、返回格式契约。**reviewer-\* 调用还必须额外传 `expected_min_dim`（高/中档=3，低档=2）**，让审校员自己判 PASS/FAIL。**不准只写"创建第 1 章蓝图"这种一句话调用**——log1 失败的根因是 prompt 过简，子 Agent 不知道写哪里、写什么、返回什么。

---

## 第一章：命令解析

### 用户命令格式

- `写一个小说，{故事描述}。写前{N}章`
- `写一个随机小说。前{N}章`
- `继续写{N}章`、`续写{N}章`、`接着写{N}章`
- `写完本{故事描述}，共{N}章`、`完整写出{N}章`

### 解析规则

1. **章节数**：正则匹配 `(\d+)\s*章` 或 `前\s*(\d+)`。匹配到 → 用该数字；匹配不到 → 询问用户。
2. **品质档位**：命令含「低档/快速/练笔」→ 低档；含「高档/精品/名著/打磨」→ 高档；其他或「中档/标准」→ 中档；无法确定 → 询问。
3. **模式判定**：含「写完本/全书/完整/共N章完成」→ **全书模式**；含「继续写/续写/接着写」→ **续写模式**；其他 → **前 N 章模式**（默认）。
4. **故事点子**：有具体描述 → 保存；含「随机/random」或无描述 → 随机模式（调用 chapter-planner 生成种子）。
5. **体裁自动判定**：

| 关键词 | 体裁 |
|---|---|
| 悬疑、侦探、推理、凶杀、谜案、诡计 | 悬疑惊悚 |
| 文学、文艺、人生、哲思、心理 | 纯文学 |
| 搞笑、幽默、喜剧、逗趣 | 喜剧/幽默 |
| 魔法、异世界、修仙、科幻、未来、宇宙、奇幻 | 奇幻/科幻 |
| 不匹配任何关键词 | 通用小说 |

---

## 第二章：初始化准备

### 2.0 工作区初始化与续写检测（每次启动必跑）

#### 2.0.1 平台探测与工作区初始化

```bash
# Linux/macOS/Git Bash
NOVEL_ROOT=$(find /sessions/*/mnt/NovelHarness -maxdepth 0 -type d 2>/dev/null | head -1)
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$NOVEL_ROOT" ] && NOVEL_ROOT="$(pwd)"
bash "$NOVEL_ROOT/scripts/init-workspace.sh"
```

```powershell
# PowerShell（Windows 原生用户）— 兼容 Windows PowerShell 5.1 与 PowerShell 7+
# 用 & 调用操作符直接执行 .ps1，不依赖 pwsh 命令是否存在
$NovelRoot = $PWD.Path
if (Test-Path "$NovelRoot/scripts/init-workspace.ps1") {
    & "$NovelRoot/scripts/init-workspace.ps1" -NovelRoot $NovelRoot
} elseif (Get-Command bash -ErrorAction SilentlyContinue) {
    bash "$NovelRoot/scripts/init-workspace.sh"
} else {
    Write-Error "未找到 init-workspace.ps1。请确认你在工作区根目录，且 scripts/ 完整。"
}
```

> **若 ExecutionPolicy 拦截**：用 `powershell -ExecutionPolicy Bypass -File ...\init-workspace.ps1` 一次性绕过，或用管理员 PowerShell 跑 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` 永久允许本地脚本。

`init-workspace` 会从 `templates/` 自动复制 memory 骨架、`runtime.json`、日志骨架到工作区根（已存在的不覆盖）。

#### 2.0.2 读取运行时配置（强制 UTF-8）

**Linux/macOS/Git Bash**：

```bash
source "$NOVEL_ROOT/scripts/config.sh"
QUALITY=$(config_get quality_tier)
GENRE=$(config_get current_genre)
```

**PowerShell**（v3 起统一走 `scripts/lib-utf8.ps1`，避免 GBK / BOM 乱码）：

```powershell
. "$NovelRoot/scripts/lib-utf8.ps1"
$json = (Read-Utf8File -Path "$NovelRoot/runtime.json") | ConvertFrom-Json
$Quality = $json.quality_tier
$Genre = $json.current_genre
```

写回时**必须**用：

```powershell
. "$NovelRoot/scripts/lib-utf8.ps1"
$out = $json | ConvertTo-Json -Depth 10
Write-Utf8File -Path "$NovelRoot/runtime.json" -Content $out
```

**严禁**：`Get-Content -Encoding UTF8` / `Set-Content -Encoding UTF8`——PS 5.1 默认带 BOM，会破坏跨平台读取与 Python json.load。

#### 2.0.3 初始化修订计数器（写入 runtime.json）

修订轮次计数器存储在 `runtime.json.revision_state`，不创建新文件。

```bash
# 跨平台 wrapper
NOVEL_ROOT="${NOVEL_ROOT:-$(pwd)}"
NOVEL_ROOT="$NOVEL_ROOT" bash "$NOVEL_ROOT/scripts/_pyrun.sh" - <<'PYEOF'
import json, os
rt = os.path.join(os.environ['NOVEL_ROOT'], 'runtime.json')
data = json.load(open(rt, encoding='utf-8')) if os.path.exists(rt) else {}
data.setdefault('revision_state', {})
# 重置每章修订轮次（保留 phase_resets 计数）
for ch, st in list(data['revision_state'].items()):
    if isinstance(st, dict):
        st['round'] = 0
json.dump(data, open(rt, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
PYEOF
```

每轮修改前递增并检查（同样跨平台）：

```bash
NN="${NN}" PHASE="${PHASE}" NOVEL_ROOT="$NOVEL_ROOT" bash "$NOVEL_ROOT/scripts/_pyrun.sh" - <<'PYEOF'
import json, os
rt = os.path.join(os.environ['NOVEL_ROOT'], 'runtime.json')
data = json.load(open(rt, encoding='utf-8'))
nn = os.environ['NN']
st = data.setdefault('revision_state', {}).setdefault('ch{}'.format(nn), {'round': 0, 'phase_resets': 0})
st['round'] = st.get('round', 0) + 1
json.dump(data, open(rt, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print('REVISION_ROUND={}'.format(st['round']))
PYEOF
```

#### 2.0.4 续写检测

```bash
bash "$NOVEL_ROOT/scripts/resume-check.sh"
ls -1 "$NOVEL_ROOT/output/" 2>/dev/null | grep -E '^第[0-9]+章' | sort -V
ls -1 "$NOVEL_ROOT/drafts/" 2>/dev/null | sort -V
test -f "$NOVEL_ROOT/logs/workflow-log.md" && tail -10 "$NOVEL_ROOT/logs/workflow-log.md"
```

**判定规则**：

- `output/` 已有第 K 章正文，请求 N > K → **续写**：从第 K+1 章开始
- `drafts/` 有蓝图/细纲但 `output/` 无对应正文 → **半成品**：从断点继续
- `output/` 已有 ≥ N 章 → 询问「已存在 K 章，覆盖/追加/汇报？」
- 全新项目 → 完整初始化流程

记录：`{datetime} 续写检测：已完成 K 章，从第 K+1 章开始（模式：{book_mode}）` 或 `{datetime} 全新项目启动（模式：{book_mode}）`

#### 2.0.5 心跳日志规则（v3 强制）

**目的**：让用户翻 `logs/workflow-log.md` 就能知道"现在卡在哪个 Agent、卡了多久"，而不必盯着主 Agent 等输出。这是铁律 2 的展开。

**规则**：调用任意子 Agent **之前**必须先写一行心跳到 `logs/workflow-log.md`；子 Agent 返回**之后**立即再写一行结果摘要。

**调用前心跳格式**：
```
[YYYY-MM-DD HH:MM] [{NN}-{phase}-{round}] 启动 {agent-name}，等待返回（典型耗时：{eta}）
```

**调用后心跳格式**：
```
[YYYY-MM-DD HH:MM] [{NN}-{phase}-{round}] {agent-name} 返回：{1 行摘要}
```

**字段说明**：
- `{NN}`：两位数章号
- `{phase}`：`blueprint` / `outline` / `draft` / `revise-bp` / `revise-ol` / `revise-dr` / `verify` / `stress-test` / `post`
- `{round}`：本 Phase 当前修订轮次（0/1/2/3）
- `{agent-name}`：被调子 Agent 名（chapter-planner / reviewer-logic 等）
- `{eta}`：典型耗时参考——planner ~3min / writer ~10–15min / reviewer ~1–2min / revise ~5–8min / post-processor ~2min

**并行调用的特殊规则**：当 Step 2/8/14 并行 dispatch N 位审校员时，**必须先连续写 N 行"启动"心跳**（每位审校员一行），再执行并行 Agent 调用；返回后按到达顺序写 N 行"返回"心跳。

**示例**（Phase 1 蓝图，并行 4 审校员）：
```
[2026-05-05 14:23] [01-blueprint-r0] 启动 reviewer-consistency-facts，等待返回（典型耗时：1-2min）
[2026-05-05 14:23] [01-blueprint-r0] 启动 reviewer-logic，等待返回（典型耗时：1-2min）
[2026-05-05 14:23] [01-blueprint-r0] 启动 reviewer-pacing，等待返回（典型耗时：1-2min）
[2026-05-05 14:23] [01-blueprint-r0] 启动 reviewer-plot-engineering，等待返回（典型耗时：1-2min）
[2026-05-05 14:25] [01-blueprint-r0] reviewer-consistency-facts 返回：[REVIEW-consistency-facts] 5.0/5 PASS | report=logs/...
[2026-05-05 14:25] [01-blueprint-r0] reviewer-logic 返回：[REVIEW-logic] 5/5 PASS | report=logs/...
[2026-05-05 14:26] [01-blueprint-r0] reviewer-pacing 返回：[REVIEW-pacing] 4.5/5 PASS | report=logs/...
[2026-05-05 14:27] [01-blueprint-r0] reviewer-plot-engineering 返回：[REVIEW-plot-engineering] 3.0/5 FAIL | report=logs/...
```

**实现方式**：
- bash：`echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M')] ..." >> "$NOVEL_ROOT/logs/workflow-log.md"`
- PowerShell：引入 `scripts/lib-utf8.ps1` 后用 `Append-Utf8File -Path "logs/workflow-log.md" -Content "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] ...`r`n"`

**禁止**：合并多次心跳为一行；省略 `{phase}-{round}`；改用其他文件而非 `workflow-log.md`。

### 2.1 写入体裁与档位

将解析结果写入 `settings/genre-profile.md`（修改 `current_genre`、`quality_tier` 字段）和 `runtime.json`。`settings/` 中的文件用 `sed -i` 修改（PowerShell 推荐 `. scripts/lib-utf8.ps1; $c = Read-Utf8File 'settings/genre-profile.md'; Write-Utf8File 'settings/genre-profile.md' ($c -replace '...','...')`，**不要用 `Set-Content -Encoding UTF8`，PS 5.1 会带 BOM**）。

### 2.2 上下文喂养机制（v2 长程优化）

首次创作完成后，后续每章启动子 Agent 之前，主智能体准备上下文信息并**只传文件路径**，不读取文件内容。

**喂养规则（按距离当前章远近 + 章号大小）**：

| 当前章 N | 喂给子 Agent 的"已有章节上下文" |
|---|---|
| N = 1 | 只传 story_seed 与 memory/world.md / characters.md / lessons.md 路径 |
| 2 ≤ N ≤ 5 | 传 `logs/chapter-summary.md`（必读）+ 最近 N-1 章的 `drafts/{NN}-outline.md` 路径 |
| 6 ≤ N ≤ 20 | 传 `logs/chapter-summary.md`（**必读，主要依据**）+ 最近 3 章的 outline 路径 + 更早章节只给 blueprint 路径 |
| N > 20 | 仅传 `logs/chapter-summary.md` + 最近 2 章的 outline 路径，更早章节标注"如需查阅请 Grep chapter-summary 后定位读取" |

**关键原则**：

- **chapter-summary.md 是主 Agent 长程记忆的核心**——由 post-processor 在每章末追加，每章 ≤ 200 字
- N ≥ 6 时，主 Agent 自己**也只读 chapter-summary.md**（极轻量），子 Agent 才有需要时读 outline
- 优先压缩主 Agent 上下文，因为主 Agent 跨多章累积；子 Agent 单次会话不会爆

**喂养格式**（仅路径）：

```
## 已有章节上下文（文件路径，请自行 Read）
章节摘要索引（必读）：logs/chapter-summary.md
第 {N-1} 章细纲：drafts/{NN-1}-outline.md
第 {N-2} 章细纲：drafts/{NN-2}-outline.md
（更早章节如需查阅请 Grep chapter-summary 定位后再读）
```

**审校报告路由**：

- 审校员将报告写入 `logs/review-{维度}-ch{NN}-{阶段}-r{N}.txt`
- 主智能体只把这些**路径**传给修改 Agent，不读取内容
- 修改 Agent 自行 Read 报告

### 2.3 启动日志

```
# 创作流程日志

## 项目启动
- {datetime} 项目启动
- {datetime} 体裁：{体裁}，品质档位：{档位}
- {datetime} 模式：{book_mode}
- {datetime} 计划创作：{N} 章
```

### 2.4 随机模式：生成故事种子

调用 `chapter-planner` 生成随机点子，输出格式：

```
- 标题：{小说标题}
- 题材：{推断的体裁}
- 一句话梗概：{一句话故事}
- 核心冲突：{核心冲突描述}
```

写入 `runtime.json.story_seed` 和 `logs/workflow-log.md`。

---

## 第三章：审校员清单（v2 唯一权威）

各阶段调用的审校员**严格按下表**。任何文档说法与本表不一致，以本表为准。

### 3.0 评分阈值与审校员自判规则（v3 核心）

**档位阈值表**（**唯一权威**，所有判定从这里查）：

| 档位 | 均分（主 Agent 判） | 最低单维（审校员自判） |
|---|---|---|
| 低档 | ≥ 2.5 | ≥ 2 |
| 中档 | ≥ 3.5 | ≥ 3 |
| 高档 | ≥ 4.5 | ≥ 3 |
| 最高档/highest | ≥ 5.0 | ≥ 5 |

**逻辑维度全部子项必须 5/5（reviewer-logic 自判 PASS 的硬条件），与档位无关。**

**职责切分（v3 强约束）**：

| 谁 | 做什么 | 不做什么 |
|---|---|---|
| **审校员（reviewer-\*）** | 依据传入的 `quality_tier` 算自己的最低单维 → 评分 → 输出 PASS/FAIL；写完整报告到 `logs/review-*.txt` | 不读取其他维度的报告；不评估均分；不"代表"其他审校员 |
| **主 Agent** | (a) 数返回行的 PASS/FAIL 个数；(b) 解析 `X.X/5` 字符串算算术平均；(c) 比较均分与档位均分阈值 | 不读 `logs/review-*.txt` 任何内容；不重新评估单维是否合格；不修改审校员的 PASS/FAIL 判定 |
| **修改 Agent（planner-revise / writer-revise）** | 自行 Read 所有传入的报告路径；做出修改 | 不评分 |
| **验收（Step 5/11/17）** | **谁提出谁验收**——上轮提出问题的审校员复审本轮修改 | 不审其他维度 |

**主 Agent 判定算法**（基于 N 行 `[REVIEW-x] {score}/5 {PASS|FAIL} | report=...` 摘要）：

```
fail_count  = 数返回行中 "FAIL" 出现次数
mean_score  = sum(每行解析的 X.X) / N
threshold   = 档位均分阈值（最高 5.0 / 高 4.5 / 中 3.5 / 低 2.5）

if fail_count == 0 and mean_score >= threshold:
    → PASS（进入下一 Phase，禁止再启动 revision，**短路条件**）
else:
    → FAIL（进入修改循环 Step 4/10/16）
```

**关键短路**：`fail_count == 0 AND mean_score >= threshold` 一旦成立，**主 Agent 必须立即进入下一 Phase，禁止以"某维度分数偏低""可能不稳"等理由再启动一轮 revision**。这是 my-novel 那次"细纲均分 4.64 已过却又跑了一轮 plot-engineering r2"的根因修复。

### 蓝图阶段（4 位审校员）

1. `reviewer-consistency-facts` —— 跨章事实/世界观/时间线/物品状态
2. `reviewer-logic` —— 因果链/动机/第三条路（**必须全维度 5/5**）
3. `reviewer-pacing` —— 张弛/钩子/信息释放
4. `reviewer-plot-engineering` —— 意外与必然/转折力学/伏笔工程

> 蓝图阶段不调用 narrative/language/dialogue/description/ai-*/reader-immersion/stress-test。

### 细纲阶段（11 位审校员）

蓝图 4 位 + 增加 7 位：

5. `reviewer-consistency-narrative` —— 跨章叙事连贯/POV
6. `reviewer-language` —— 病句/错字/标点/句法
7. `reviewer-dialogue` —— 口吻/对白功能
8. `reviewer-description` —— 感官/比喻/视角
9. `reviewer-ai-vocab` —— AI 词汇黑名单/句式
10. `reviewer-ai-structure` —— 段落方差/比喻密度/解释欲
11. `reviewer-ai-human` —— 人味注入命中数

> 细纲阶段不调用 reader-immersion（无正文不评估情感）和 stress-test（独立步骤）。

### 正文阶段（13 位审校员）

细纲 11 位 + 增加 2 位：

12. `reviewer-reader-immersion` —— 读者沉浸/情感共鸣
13. `reviewer-stress-test` —— 叙事压力测试（独立 Step 19，但报告同步收集）

---

## 第四章：章节创作循环

对第 1 章到第 N 章依次执行。每一章由主智能体调度多个独立子 Agent 完成，主智能体仅准备上下文路径、启动子 Agent、收集 1 行返回摘要、记录日志。

### 子 Agent 调用原则（关键架构变更）

每章拆分为多个独立小 Agent，每个只做一件事。**主 Agent 只做调度 + 写日志**。

**每个子 Agent 调用模板必须包含**：

- 章号 N（数字，如 1）和 NN（两位数字符串，如 "01"）
- quality_tier（低档/中档/高档/最高档）
- story_seed（仅首章/上下文需要时）
- 输入文件路径列表（前章蓝图/细纲、memory）
- 输出文件路径
- 返回格式契约（一行 `[X-tag] ...` 摘要）

**绝对禁止**：

- 主 Agent 降级为自行写作（log1 那种"0 tool uses"是子 Agent 自身问题，主 Agent 不接管，重试调用即可）
- 在主 Agent 上下文加载文件正文
- 在创作阶段使用 AskUserQuestion

### Phase 0：章节前置准备

1. 确定章节号 `N`（从 1 开始递增）。NN = 两位数字符串。
2. **第 N ≥ 2 章必跑启动门禁**：
   ```bash
   bash "$NOVEL_ROOT/scripts/init-check.sh" $N
   ```
   门禁项：
   - `memory/style-bible.md` 至少 5 段正例
   - `memory/lessons.md` 至少 3 条
   - `memory/characters.md` 中所有出场角色含口吻样本（虚拟首语）
   - `memory/foreshadowing.md` 上一章伏笔无「待定」
   - 提示本章是否为某伏笔的计划回收章

   任一失败 → 阻塞并要求 chapter-planner 补齐 memory，再重新启动。

3. **伏笔健康度扫描**：
   ```bash
   bash "$NOVEL_ROOT/scripts/foreshadow-check.sh" $N
   ```
   存在「待定」或超期未回收 → 阻塞。

4. 记录：`{datetime} 第 {N} 章：开始创作`

### Phase 1：蓝图创作与审校

#### Step 1：调用 chapter-planner 创建蓝图

```
Agent(chapter-planner) prompt:

【任务】为第 N 章创建蓝图。
【参数】
- N = {N}
- NN = "{NN}"  # 两位数
- quality_tier = "{档位}"
- story_seed = "{故事种子，首章必传，N≥2 时传"延续前章"}"
- mode = "{前N章/续写/全书}"
- is_first_chapter = {true/false}
- is_last_chapter = {true/false，仅全书模式末章为 true}
【输入】
- 前章细纲（如有）：drafts/{NN-1}-outline.md
- memory/world.md, memory/characters.md, memory/timeline.md, memory/foreshadowing.md, memory/lessons.md
【输出】
- 写入 drafts/{NN}-blueprint.md
【返回格式契约】
必须且只能返回 1 行：
[PLAN] ch={NN} file=drafts/{NN}-blueprint.md bytes={size} scenes={N}
失败时：[PLAN] ch={NN} FAIL reason=...
```

主 Agent 收到 `[PLAN]` 后用 `stat` 验证文件存在且 ≥ 1KB。失败 → 重试调用（最多 2 次），仍失败 → 致命错误，记日志暂停。

记录：`{datetime} 第 {N} 章蓝图已创建：drafts/{NN}-blueprint.md`

#### Step 2：分发蓝图审校（并行 4 位）

**先批量写 4 行"启动"心跳（§2.0.5），再并行调用 4 位审校员**：

```
Agent(reviewer-{维度}) prompt:

【任务】审校蓝图。
【参数】
- 路径 = "drafts/{NN}-blueprint.md"
- 阶段 = "蓝图"
- quality_tier = "{档位}"            # 低档/中档/高档/最高档
- expected_min_dim = {2|3|5}          # 由档位查 §3.0：低=2，中/高=3，最高=5
- ch = "{NN}"
- round = "{当前轮次}"
【输出】
- 审校报告写入 logs/review-{维度}-ch{NN}-blueprint-r{round}.txt
【自判 PASS/FAIL 规则（v3）】
- 你必须依据传入的 expected_min_dim 自己判 PASS/FAIL：
  - 你的最终评分 ≥ expected_min_dim → PASS
  - 你的最终评分 < expected_min_dim → FAIL
- reviewer-logic 额外硬规则：核心子项 A-E 必须全 5/5，否则不论 expected_min_dim 一律 FAIL
- 主 Agent 不会重判你的 PASS/FAIL，你的判定即最终判定
【返回格式契约】
必须且只能返回 1 行：
[REVIEW-{维度}] {score}/5 {PASS|FAIL} | report=logs/review-{维度}-ch{NN}-blueprint-r{round}.txt
FAIL 时附阻塞子项：[REVIEW-{维度}] 3/5 FAIL (因果链/动机不足) | report=...
```

主 Agent 收集 4 行 `[REVIEW-...]` 摘要，**返回时按到达顺序写 4 行"返回"心跳**（§2.0.5）。

#### Step 3：蓝图审校判定（v3 三步算法）

档位阈值见 §3.0（**唯一权威**）。主 Agent 不再独立维护阈值表。

**判定算法**（基于 4 行 `[REVIEW-x] {score}/5 {PASS|FAIL} ...` 摘要，纯字符串解析与算术，**不读报告内容**）：

```
# 第 1 步：数 FAIL 个数
fail_count = sum(1 for line in 摘要4行 if " FAIL " in line)

# 第 2 步：算均分（解析每行的 {score}/5 数字）
mean_score = sum(score for score in 摘要4行) / 4

# 第 3 步：与档位均分阈值比较
threshold = {低档: 2.5, 中档: 3.5, 高档: 4.5, 最高档/highest: 5.0}[quality_tier]

# 短路 PASS 条件（一旦成立，立即进入 Phase 2，禁止 revision）
if fail_count == 0 and mean_score >= threshold:
    → 进入 Phase 2
else:
    → 进入 Step 4 修改循环（仅修改 FAIL 维度）
```

**关键约束**：
- 单维分数是否合格由审校员自判（已传 `expected_min_dim`），主 Agent **不重新判**
- `fail_count == 0` 已等价于"全部维度 ≥ 最低单维"，不需要再算
- 主 Agent 看到的只有 1 行摘要里的 `PASS`/`FAIL` 字样和 `X.X/5` 数字，**绝不打开 report 路径**

记录到 `workflow-log.md`（不写到响应中复述）：

```
[YYYY-MM-DD HH:MM] [{NN}-blueprint-r{round}] 蓝图审校判定：均分 {mean:.2f}/5（阈值 {threshold}），FAIL={fail_count}/4 → {PASS|FAIL}
```

- **PASS** → 进入 Phase 2（Step 7）
- **FAIL** → 进入 Step 4 修改循环

#### Step 4：蓝图修改循环（硬上限 3 轮）

```bash
ROUND=$(NN="{NN}" NOVEL_ROOT="$NOVEL_ROOT" bash "$NOVEL_ROOT/scripts/_pyrun.sh" - <<'PYEOF'
import json, os
rt = os.path.join(os.environ['NOVEL_ROOT'], 'runtime.json')
data = json.load(open(rt, encoding='utf-8'))
st = data.setdefault('revision_state', {}).setdefault('ch{}'.format(os.environ['NN']), {'round': 0, 'phase_resets': 0})
st['round'] += 1
json.dump(data, open(rt, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print(st['round'])
PYEOF
)
```

**每轮开始检查**：

- `ROUND > 3` → **强制回退当前 Phase**（删除蓝图，回到 Step 1，计数器归零）
- 连续 2 轮评分波动 ≤ 0.1（震荡）→ **强制回退本 Phase**
- 上轮通过的维度本轮变阻塞 ≥ 1 个（震荡）→ **强制回退本 Phase**
- `ROUND ≤ 3` 且无震荡 → 继续修改

**先写"启动 planner-revise"心跳（§2.0.5），再调用** `planner-revise`：

```
Agent(planner-revise) prompt:

【任务】根据审校报告修改第 {N} 章蓝图。
【参数】
- target = "drafts/{NN}-blueprint.md"
- quality_tier = "{档位}"               # 修改师同样需要档位（决定改幅度）
- FAIL 维度报告路径列表 = [
    "logs/review-logic-ch{NN}-blueprint-r{round-1}.txt",
    "logs/review-pacing-ch{NN}-blueprint-r{round-1}.txt",
    ...仅 FAIL 维度
  ]
- round = {ROUND}/3
【动作】
- Read 所有审校报告（不依赖主 Agent 传内容）
- Edit 修改 target 文件
【返回格式契约】
[REVISE-BP] done: 修改 N 处, bytes X→Y, FAIL 清零 K/T | file=drafts/{NN}-blueprint.md
未清零时附原因：[REVISE-BP] partial: ... | unresolved=...
```

**返回后写"返回 planner-revise"心跳**。

#### Step 5：逐维验收（谁提出谁审阅，**仅一段，无 5b 终审**）

**先批量写"启动"心跳，再并行调用上一轮中提出问题的审校员（仅 FAIL 维度）**：

```
Agent(reviewer-{维度}) prompt:

【任务】验收第 {N} 章蓝图修改。
【参数】
- 路径 = "drafts/{NN}-blueprint.md"
- 阶段 = "蓝图"
- quality_tier = "{档位}"
- expected_min_dim = {2|3|5}            # 同 Step 2，由档位查 §3.0
- ch = "{NN}"
- round = "{ROUND}"
- mode = "verify"                        # 验收模式
- previous_issues_report = "logs/review-{维度}-ch{NN}-blueprint-r{round-1}.txt"
【动作】
- Read previous_issues_report 提取上轮问题清单
- Read target 检查问题是否修复
- Write 新报告到 logs/review-{维度}-ch{NN}-blueprint-r{round}.txt
【自判 PASS/FAIL 规则（v3）】
- 与 Step 2 同：评分 ≥ expected_min_dim → PASS；< → FAIL
- reviewer-logic 验收硬规则：核心子项 A-E 必须全 5/5
- 主 Agent 不会重判
【返回】
[REVIEW-{维度}] {score}/5 {PASS|FAIL} | report=...
注：你只验收自己上轮提出的问题，不审校其他维度。其他维度由它们自己的验收完成。
```

**判定**（仍走 §3.0 / Step 3 三步算法，但只对参与本轮验收的 K 个维度算）：

- 所有 K 个验收摘要 `fail_count == 0` → **直接进入 Phase 2**（不做全量终审，不读报告内容）
- 任一仍 FAIL → 回到 Step 4 下一轮（计数器自动递增）
- reviewer-logic 评分 < 3.0 → **立即跳过剩余轮次，强制回退当前 Phase**（删除蓝图，回 Step 1，计数器归零）

记录：`{datetime} 第 {N} 章蓝图终审通过。综合评分：X.X/5（验收第 {ROUND} 轮）`

> **设计说明**（解决旧版 5a+5b 矛盾）：旧版工作流要求"逐维验收 → 全量终审"两段，导致单章流程冗长（log3 中第 1 章细纲改一轮就花 47 分钟）。v2 简化为只跑逐维验收（5a），删除 5b 全量终审。理由：
>
> 1. 验收是"闭环回归"，验收员上轮提出过问题、本轮验证修复——已构成完备的可信判断
> 2. 跨维度副作用问题在下一阶段（Phase 2 细纲审校的 11 位审校员）会再次扫描，无需在 Phase 1 重复
> 3. 主 Agent 严禁验收/审校（铁律 3a），5b 全量终审形式上由主 Agent 调度但实质上是参与质量判定，与铁律冲突

### Phase 2：细纲创作与审校

#### Step 7：调用 planner-outline 扩写细纲

```
Agent(planner-outline) prompt:

【任务】将蓝图扩写为细纲。
【参数】
- N = {N}, NN = "{NN}"
- quality_tier = "{档位}"
- input = "drafts/{NN}-blueprint.md"
- output = "drafts/{NN}-outline.md"
【返回格式契约】
[OUTLINE] ch={NN} file=drafts/{NN}-outline.md bytes={size} beats={N}
失败：[OUTLINE] ch={NN} FAIL reason=...
```

记录：`{datetime} 第 {N} 章细纲已创建：drafts/{NN}-outline.md`

#### Step 8：分发细纲审校（并行 11 位）

**先批量写 11 行"启动"心跳（§2.0.5），再并行调用细纲 11 位审校员**。模板同 Step 2，路径改为 `drafts/{NN}-outline.md`，阶段改为 `outline`，**11 位都必须传 `quality_tier` 和 `expected_min_dim`**（让审校员自判 PASS/FAIL）。

收集 11 行 `[REVIEW-...]` 摘要后，按到达顺序写 11 行"返回"心跳。判定走 §3.0 / Step 3 三步算法（除数从 4 改为 11）。

#### Step 9-12：细纲修改循环（同 Phase 1 模式）

- 使用 `planner-revise` 修改细纲（return tag `[REVISE-OL]`）
- 11 位审校员（不含 reader-immersion 和 stress-test）
- 计数器使用 `runtime.json.revision_state.ch{NN}.round`
- 验收：**只逐维验收（5a），无全量终审**
- 回退规则：3 轮耗尽或 logic < 3.0 → **回到 Phase 1 Step 1**（重做蓝图 → 细纲）。不设让步，不降档。

### Phase 3：正文创作与审校

#### Step 13：调用 chapter-writer 一步出稿（v2 主路径）

```
Agent(chapter-writer) prompt:

【任务】根据细纲创作第 N 章正文（含机械红线自检）。
【参数】
- N = {N}, NN = "{NN}", short_title = "{短标题}"
- quality_tier = "{档位}"
- mode = "{前N章/续写/全书}"
- is_first_chapter = {true/false}
- is_last_chapter = {true/false}
- input = "drafts/{NN}-outline.md"
- output = "output/第{NN}章-{short_title}.txt"
【动作】
- Write 正文到 output 路径
- 跑 normalize-text.sh 和 ai-taste-lint.py 自检（机械红线）
- 字数登记到 memory/pacing-budget.md
【返回格式契约】
[DRAFT] ch={NN} file=output/第{NN}章-{short_title}.txt words={wordcount} lint=PASS
机械自检失败：[DRAFT] ch={NN} file=... lint=FAIL details=...
```

> **关于备选两步式（writer-draft + writer-polish）**：仅当用户显式要求"分初稿/润色两步式"时才走两步路径。两步式产物文件名带 `-draft` 后缀（writer-draft 写）和不带后缀（writer-polish 写最终稿），返回 tag 分别为 `[DRAFT-RAW]` 和 `[POLISH]`。主路径用 chapter-writer 一步式以减少 Agent 调用、缩短流程。

记录：`{datetime} 第 {N} 章正文已创建：output/第{NN}章-{short_title}.txt（{字数}字）`

#### Step 14：分发正文审校（并行 13 位）

**先批量写 13 行"启动"心跳（§2.0.5），再并行调用正文 13 位审校员**。路径 `output/第{NN}章-{short_title}.txt`，阶段 `draft`，**13 位都必须传 `quality_tier` 和 `expected_min_dim`**（让审校员自判 PASS/FAIL）。

收集 13 行 `[REVIEW-...]` 摘要后，按到达顺序写 13 行"返回"心跳。判定走 §3.0 / Step 3 三步算法（除数从 4 改为 13）。

#### Step 15-18：正文修改循环（同 Phase 1 模式）

- 使用 `writer-revise` 修改正文（return tag `[writer-revise]`）
- 13 位审校员
- 计数器使用 `runtime.json.revision_state.ch{NN}.round`（同一字段，跨 Phase 复用，但每进入一个新 Phase 由 Step 4 的 round = 0 重置）
- 验收：**只逐维验收（5a），无全量终审**
- 回退规则：3 轮耗尽或 logic < 3.0 → **回到 Phase 2 Step 7**（重做细纲 → 正文）。不设让步，不降档。

#### Step 19：叙事压力测试（独立步骤）

```
Agent(reviewer-stress-test) prompt:

【任务】对第 {N} 章正文执行叙事压力测试。
【参数】
- 路径 = "output/第{NN}章-{short_title}.txt"
- 阶段 = "正文"
- 品质档位 = "{档位}"
【返回格式契约】
[REVIEW-stress-test] {score}/5 {PASS|FAIL} | report=logs/review-stress-test-ch{NN}-final.txt
```

- **PASS** → 继续 Step 19.5
- **FAIL** → **必须回到本章 Phase 2 重写细纲**（不允许"警告继续"）。重写后重新走 Phase 3。

#### Step 19.5：章末后处理（调用 post-processor）

```
Agent(post-processor) prompt:

【任务】第 N 章后处理：格式化、AI 味检测、提取风格正例（仅首章）、提取本章事实、追加 workflow log。
【参数】
- N = {N}, NN = "{NN}"
- body_file = "output/第{NN}章-{short_title}.txt"
- is_first_chapter = {true/false}
- final_score = {score}
【动作】
- 跑 normalize-text.sh + ai-taste-lint.py（chapter-writer 已跑过，但再校验一次）
- 提取本章事实（角色/世界观/伏笔/时间线）作为 [FACTS] 块
- 首章额外提取 ≥5 段正例到 memory/style-bible.md
- 追加 workflow log
【返回格式契约】
[POST] ch={NN} done: {wordcount}字, final_score={X.X}/5, facts_extracted={N}条
随后附 [FACTS] 块供主 Agent 转交给 fact-extractor
```

主 Agent 收到 `[POST]` 后：

- 用 stat 验证 `output/第{NN}章-{short_title}.txt` 仍存在且无变化（应只是被 normalize 过）
- 把 `[FACTS]` 块的内容**作为路径列表**传给 `fact-extractor`（不读内容）
- git 自动提交：`bash scripts/commit-chapter.sh "{NN}" "{score}"`（PowerShell 走 `commit-chapter.ps1`）

#### Step 19.7：首章特殊门禁（仅 N = 1 时执行）

第 1 章正文压力测试通过后，必须完成以下门禁项才能进入第 2 章：

1. **风格圣经提取**：post-processor 在 Step 19.5 已写入 `memory/style-bible.md` ≥ 5 段正例。主 Agent 用 `wc -l` / `stat` 验证文件 ≥ 5 段（grep `^## 正例` 计数 ≥ 5）。不足 → 阻塞，调用 reviewer-language 补提取。
2. **lessons.md 至少 3 条**：第 1 章完成时 lessons.md 应基于本章经验积累至少 3 条。少于 3 条 → 主 Agent 调用 chapter-planner 以"提炼第 1 章经验教训"为任务补充 lessons。
3. **characters.md 口吻样本**：所有出场角色必须有 ≥ 3 句虚拟首语样本。不足 → 调用 chapter-planner 补充。
4. **foreshadowing.md 无「待定」**：所有埋下的伏笔必须有明确的回收章号（即使是范围如 ch5-8）。「待定」字样 → 阻塞。
5. **全部维度阻塞清零**：13 位审校员的最终评分应全部 PASS（不是 FAIL）。任一 FAIL → 回到 Phase 3 Step 14 重新审校。
6. **压力测试 PASS**：reviewer-stress-test 评分 PASS。FAIL → 已在 Step 19 回退。

任一项不满足 → **不能进入第 2 章**。主 Agent 必须先解决再继续。

记录：`{datetime} 第 1 章首章门禁通过：style-bible {N}段、lessons {N}条、伏笔健康、全维度通过`

### Phase 4：进入下一章

每章 Phase 0-3 完成后：

1. 重置 `runtime.json.revision_state.ch{NN}.round = 0`，递增 `last_completed_chapter`
2. 写日志：`{datetime} 第 {N} 章完成。终审评分：{score}/5，字数：{n}`
3. 写 `logs/chapter-index.md`：`第 {N} 章 - {一句话主旨}`
4. 自动进入第 N+1 章 Phase 0（**不询问用户**）

---

## 第五章：完结报告

所有目标章节完成后：

1. 调用 `bash scripts/generate-summary.py` 生成全书汇总报告到 `logs/final-summary.md`
2. 主 Agent 向用户汇报：

```
✅ 创作完成

模式：{book_mode}
章节：第 1 章 ~ 第 {N} 章（共 {N} 章）
体裁：{体裁}
品质档位：{档位}
总字数：{wordcount}
平均评分：{X.X}/5

文件：
- 正文：output/第01章-*.txt ~ output/第{NN}章-*.txt
- 蓝图/细纲：drafts/
- 工作流日志：logs/workflow-log.md
- 风格圣经：memory/style-bible.md（{N} 段正例）

可继续命令：「继续写 K 章」从第 {N+1} 章开始
```

---

## 第六章：长程上下文管理（防止主 Agent 上下文爆满）

### 6.1 主 Agent 上下文消耗模型

每章主 Agent 实际累积的上下文量（v2 修复后估算）：

| 项目 | 每次 | 每章次数 | 每章累计 |
|---|---|---|---|
| 子 Agent prompt（带参数）| ~700 字符 | ~28 次 | ~20KB |
| 子 Agent 1 行返回（v2 契约） | ~100 字符 | ~28 次 | ~2.8KB |
| bash 工具输出（stat/wc/Get-Date） | ~100 字符 | ~10 次 | ~1KB |
| 章末日志写入 | ~300 字符 | ~5 次 | ~1.5KB |
| **每章典型累积** | | | **~25KB** |
| 每章悲观（每 Phase 3 轮修订） | | | **~80KB** |

200K token 上下文窗口（约 600KB-1MB 内容）下：

- **5 章典型**：25 × 5 + 80 系统提示 ≈ 200KB → **安全**
- **5 章悲观**：80 × 5 + 80 ≈ 480KB → **接近上限，有风险**
- **10+ 章**：典型场景就接近上限，**必须用本章节的优化策略**

### 6.2 主 Agent 上下文优化铁律

1. **永不读 outline 全文**：N ≥ 6 时，主 Agent 自己只读 `logs/chapter-summary.md`（每章 ≤ 200 字）。子 Agent 才需要时读 outline。
2. **永不读 review 报告内容**：所有 review 报告由审校员/修改师/验收员**自己 Read**。主 Agent 只接 1 行 `[REVIEW-x]` 摘要。
3. **bash 输出尽量精简**：避免 `cat`、`tail -100`、`ls -laR` 这类大输出。用 `stat -c%s`（仅尺寸）、`wc -l`（仅行数）、`grep -c`（仅计数）。
4. **重复信息不写第二次到日志**：日志只追加新发生的事件，不复述上下文。
5. **不在响应中复述子 Agent 返回**：收到 `[REVIEW-logic] 4.5/5 PASS` → 写入日志 → 直接进入下一步，不要写一段"逻辑维度通过了 4.5 分..."解释性文字。

### 6.3 章末 checkpoint 机制

每章 Phase 4 完成后，主 Agent 必须：

1. **post-processor** 已写入 `logs/chapter-summary.md` 一行（包括本章一句话摘要、字数、终审分、章末钩子）
2. 主 Agent 在 `logs/workflow-log.md` 追加一行 `{datetime} 第 {N} 章完成` 后，**停止累积本章细节到响应**
3. 若上下文使用率 > 60%（用户可观察），**建议主 Agent 在响应末尾加 1 行**：
   ```
   ⚠️ checkpoint：第 {N} 章完成。本会话上下文已较高，建议手动 /compact 或在下条消息说"继续写"以利用 resume-check 重启。
   ```
4. 用户/会话恢复时跑 `bash scripts/resume-check.sh`（或在 PowerShell 下 `& .\scripts\resume-check.ps1`），主 Agent 从 `logs/chapter-summary.md` 读完整上下文，**不需要**重读所有 outline。

### 6.4 子 Agent 上下文风险

每个子 Agent 是独立 200K 窗口的**新会话**，单次调用结束就释放。理论上无累积风险，但有几种"单次单 Agent 内"爆掉的可能：

| 风险点 | 场景 | 防御 |
|---|---|---|
| chapter-planner 第 N≥10 章 | 想读所有前章 outline | agent 定义已要求 N≥6 时优先读 chapter-summary，不读全章 |
| planner-revise 细纲阶段 | 一次性 Read 11 份审校报告（每份 1-3KB） | 上限约 33KB，远低于 200K，安全 |
| chapter-writer | 读细纲 + style-bible + ai-taste-trap-bible + narrative-mechanics | 总计 ~25KB，安全；narrative-mechanics 改为 Grep 按需取章后更安全 |
| reviewer-stress-test 正文 | 模拟两遍阅读 + 输出报告 | 单 reviewer 处理 1 个正文文件（10-30KB），安全 |
| post-processor | 读正文 + 多份 memory 文件 | 总计 ~50KB，安全 |
| fact-extractor | 读正文 + memory/facts.md（可能上千行） | 用 Grep 定位主体，不读全表 |

**子 Agent 通用约束**（已写入各 agent 文件 frontmatter）：

- `tools: [Read, Write, Edit, Grep, Glob, Bash]` 中保留 Grep 优先
- `maxTurns: 15-30` 限制单次会话步骤数
- 大文件（> 50KB）必须用 Grep 先定位，再用 Read offset/limit 取目标段

### 6.5 何时手动干预

主 Agent 应在以下情况主动告知用户而非闷头继续：

1. **章节计数 > 15** 且 chapter-summary.md > 100 行 → 提示"已写很多章，建议本会话写完后开新会话续写"
2. **bash 工具单次输出 > 5KB** → 提示"输出过大，已截断"，用 `head` / `tail` / `grep` 改造
3. **同一子 Agent 连续 3 次返回 0 tool uses** → 说明定义文件或调用 prompt 损坏，停下来报告
4. **预计上下文剩余 < 30K tokens** → 章末时给出 checkpoint 提示

---

## 附录 A：路径映射（Cowork/沙箱环境）

| 主 Agent 看到 | bash/python 在沙箱看到 |
|---|---|
| `D:\Work\Novels\NovelHarness\` | `/sessions/{session-id}/mnt/NovelHarness/` |
| `D:\Work\Novels\NovelHarness\my-novel\` | `/sessions/{session-id}/mnt/NovelHarness/my-novel/` |
| `output/第01章-X.txt`（相对工作区） | `$NOVEL_ROOT/output/第01章-X.txt` |

bash 路径用 `find /sessions/*/mnt/NovelHarness -maxdepth 0` 自动探测。

## 附录 B：错误处理速查

| 情况 | 处理 |
|---|---|
| 子 Agent 返回 0 tool uses（log1 症状） | prompt 太简短未传参数。重写调用模板补全章号/路径/契约后重试。最多 2 次重试。 |
| 子 Agent 后台运行未自动接力（log2 症状） | 不允许 Backgrounded。所有 `Agent(...)` 必须阻塞同步等待返回 1 行摘要。 |
| runtime.json 中文乱码（log3 症状） | 平台探测后用 PowerShell `-Encoding UTF8` 或 Python `encoding='utf-8'` 写入。**永远不用** GBK 默认编码。 |
| bash 脚本 Windows 报 wsl 错（log3 症状） | 改调 `.ps1` 镜像；或要求用户改用 Git Bash。 |
| 连续 2 轮评分波动 ≤ 0.1 | 评分震荡 → 回退本 Phase |
| 上轮通过维度本轮阻塞 ≥ 1 个 | 评分震荡 → 回退本 Phase |
| 3 轮修改耗尽 | 回退当前 Phase（蓝图回 Step 1、细纲回 Step 7、正文回 Step 7） |
| reviewer-logic < 3.0 | 立即跳过剩余轮次，强制回退当前 Phase |
| API Usage Policy 拒绝 | 自动换切入点/场景重规划，2 次仍拒 → 暂停报告 |
| 子 Agent 完成但文件无变化 | stat 检测，不计轮次，重启 Agent |
| `python3` not found | 改用 `bash scripts/_pyrun.sh`（wrapper 已处理 Windows stub） |

## 附录 C：v2 返回 tag 速查

| Agent | 返回 tag |
|---|---|
| chapter-planner | `[PLAN] ch={NN} file=... bytes=... scenes=...` |
| planner-outline | `[OUTLINE] ch={NN} file=... bytes=... beats=...` |
| planner-revise | `[REVISE-BP]` 或 `[REVISE-OL]` `done: ...` |
| chapter-writer | `[DRAFT] ch={NN} file=... words=... lint=PASS` |
| writer-draft（备选） | `[DRAFT-RAW] ch={NN} file=... words=...` |
| writer-polish（备选） | `[POLISH] ch={NN} file=... words=... lint=PASS` |
| writer-revise | `[writer-revise] {file}: 修改 N 处, ...` |
| reviewer-* | `[REVIEW-{维度}] {score}/5 {PASS\|FAIL} \| report=...` （v3：PASS/FAIL 由审校员依据传入 `expected_min_dim` 自判，主 Agent 只汇总不重判，规则见 §3.0） |
| post-processor | `[POST] ch={NN} done: ...` 后附 `[FACTS]` 块 |
| fact-extractor | `[FACTS] ch={NN} new=... conflicts=... file=memory/facts.md` |

主 Agent 只解析这些标签的字段，**绝不**读取它们引用的文件内容。

## 附录 D：v3 改动说明（速查）

v3（plugin 化 + 审校员自判 + 心跳日志 + 量身定制评分锚点）相较 v2 的关键变化：

| 改动 | v2 行为 | v3 行为 |
|---|---|---|
| 子 Agent 部署 | `src/agents/*.md` 由 `src/scripts/init-workspace` 复制到工作区 | Plugin 模式：`agents/` 在 plugin 根，Codex 从工作区规则和提示文件读取（详见 `.codex-plugin/plugin.json`） |
| reviewer 评分 | 仅评分，PASS/FAIL 由审校员凭感觉给（标准与主 Agent 不一致） | 强制传 `expected_min_dim`，按 §3.0 自判，PASS/FAIL 标准与主 Agent 完全一致 |
| reviewer 评分锚点 | 多为定性提问，分数随机 | 13 位 reviewer 各自配套"评分锚点 5/4/3/2/1 + 轻微/中等/严重违规清单"，按维度量身定制 |
| 主 Agent 判定 | 各 Step 重复维护档位阈值表，主 Agent 还会重判单维 | §3.0 唯一权威 + Step 3 三步算法（数 FAIL + 算均分 + 比阈值），主 Agent 不重判单维 |
| 心跳日志 | 仅章末写日志，调子 Agent 期间无任何状态可见 | §2.0.5 强制：每次调用前/后各写一行心跳到 `workflow-log.md` |
| PowerShell 写文件 | 各脚本各自实现 `Write-Utf8NoBom`，示例曾用 `Set-Content -Encoding UTF8`（PS 5.1 带 BOM） | 统一走 `scripts/lib-utf8.ps1` 的 `Write-Utf8File` / `Read-Utf8File` / `Append-Utf8File` |
