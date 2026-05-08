# 多智能体小说创作系统 · Agent 清单（v2 管道）

本目录包含全部 Agent 定义文件。系统采用 **主智能体（Orchestrator）+ 审校团（Review Board）** 架构。
本文件是清单与速查；详细工作流见同目录 `orchestrator-workflow.md`（v2 唯一权威）。

## 创作 Agent

| 角色 | 文件 | 模型 | 职责 |
|------|------|------|------|
| **主智能体（Orchestrator）** | 当前会话 | — | 全自动流程调度（详见 `orchestrator-workflow.md`） |
| 大纲规划师 | `chapter-planner.md` | opus | 创建章节蓝图 |
| 细纲扩写师 | `planner-outline.md` | opus | 蓝图 → beat-by-beat 细纲 |
| 蓝图/细纲修改师 | `planner-revise.md` | opus | 根据审校报告精准修改蓝图或细纲 |
| **章节作家**（主路径） | `chapter-writer.md` | opus | 一步出正文 + 机械红线自检（v2 推荐） |
| 初稿作家（备选） | `writer-draft.md` | opus | 两步式备选——只写初稿，不去 AI 味 |
| 润色作家（备选） | `writer-polish.md` | opus | 两步式备选——去 AI 味 + 机械自检 |
| 正文修改师 | `writer-revise.md` | opus | 根据审校报告精准修改正文 |
| 章末后处理 | `post-processor.md` | opus | 格式化、风格提取、memory 更新、git 提交 |
| 事实提取员 | `fact-extractor.md` | sonnet | 从定稿提取结构化事实，检测跨章矛盾 |

## 审校团（13 位）

| 维度 | 文件 | 模型 | 蓝图 | 细纲 | 正文 |
|---|---|---|:---:|:---:|:---:|
| 一致性-事实 | `reviewer-consistency-facts.md` | opus | ✓ | ✓ | ✓ |
| 逻辑（**必满分**） | `reviewer-logic.md` | opus | ✓ | ✓ | ✓ |
| 节奏 | `reviewer-pacing.md` | sonnet | ✓ | ✓ | ✓ |
| 剧情工程 | `reviewer-plot-engineering.md` | opus | ✓ | ✓ | ✓ |
| 一致性-叙事 | `reviewer-consistency-narrative.md` | opus |  | ✓ | ✓ |
| 语言 | `reviewer-language.md` | sonnet |  | ✓ | ✓ |
| 对白 | `reviewer-dialogue.md` | sonnet |  | ✓ | ✓ |
| 描写 | `reviewer-description.md` | sonnet |  | ✓ | ✓ |
| AI 味-词汇 | `reviewer-ai-vocab.md` | sonnet |  | ✓ | ✓ |
| AI 味-结构 | `reviewer-ai-structure.md` | sonnet |  | ✓ | ✓ |
| AI 味-人味 | `reviewer-ai-human.md` | opus |  | ✓ | ✓ |
| 读者沉浸 | `reviewer-reader-immersion.md` | opus |  |  | ✓ |
| 叙事压力测试 | `reviewer-stress-test.md` | opus |  |  | ✓ |
| **合计** | | | **4** | **11** | **13** |

## 核心铁律

1. **主智能体绝不读取内容文件**（蓝图/细纲/正文/审校报告）——只处理文件路径
2. **审校团绝不修改文件**——只输出含 1-5 评分的审校报告
3. **谁提出谁审阅**——问题由发现者验收，主 Agent 严禁验收
4. **修改统一**——蓝图/细纲由 `planner-revise`，正文由 `writer-revise`
5. **四档品质**——低档（≥2.5）/ 中档（≥3.5）/ 高档（≥4.5）/ 最高档 highest（≥5.0 且最低单维 5），逻辑维度全档位必满分 5/5
6. **永不降档**——3 轮耗尽时回退当前 Phase，不下调品质档位
7. **每个 Agent 必返回 1 行 v2 契约摘要**——主 Agent 不解析多行内容（详见各 Agent 文件末尾的「v2 管道架构：最终返回格式」段）

## v2 返回 tag 速查

| Agent | 返回 tag |
|---|---|
| chapter-planner | `[PLAN] ch={NN} file=... bytes=... scenes=...` |
| planner-outline | `[OUTLINE] ch={NN} file=... bytes=... beats=...` |
| planner-revise | `[REVISE-BP] / [REVISE-OL] done: ...` |
| chapter-writer | `[DRAFT] ch={NN} file=... words=... lint=PASS` |
| writer-draft（备选） | `[DRAFT-RAW] ch={NN} file=... words=...` |
| writer-polish（备选） | `[POLISH] ch={NN} file=... words=... lint=PASS` |
| writer-revise | `[writer-revise] {file}: 修改 N 处, ...` |
| reviewer-* | `[REVIEW-{维度}] {score}/5 {PASS\|FAIL} \| report=...` |
| post-processor | `[POST] ch={NN} done: ...` 后附 `[FACTS]` 块 |
| fact-extractor | `[FACTS] ch={NN} new=... conflicts=... file=memory/facts.md` |

## 快速开始

对本会话（主智能体）说：

```
写一个小说，{故事点子}。写前 {N} 章
```

或随机：

```
写一个随机小说。前 {N} 章
```

或续写：

```
继续写 {N} 章
```

或全书模式：

```
写完本小说，{故事点子}，共 {N} 章，高档品质
```
