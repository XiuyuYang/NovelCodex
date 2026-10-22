# NovelCodex

This root is intentionally small.

```text
NovelCodex/
+-- start-novel-codex.bat
+-- novels/
+-- system/
```

- `system/` contains the NovelCodex engine, agent rules, scripts, templates, references, settings, and tests.
- `novels/` contains generated books. Each book has its own `runtime.json`, `drafts/`, `output/`, `logs/`, `memory/`, and `resume-this-novel.bat`.

## Start A New Novel

Double-click:

```bat
start-novel-codex.bat
```

On a successful start, NovelCodex creates a new folder under `novels/` for that book's process files and results.

## Resume Work

Resume a book from that book's own folder:

```bat
novels\<book-folder>\resume-this-novel.bat
```

Resume runs are bound to the folder that contains `resume-this-novel.bat`. They are open-ended: each resume moves that book's target to the chapter after the latest completed chapter, and the Codex prompt keeps advancing that one-chapter frontier until you stop it or a real blocker occurs.

## Metadata Tools

Check progress without reading creative content:

```powershell
.\system\scripts\novel-status.ps1 -SystemRoot .\system -NovelRoot .\novels\<book-folder> -WorkflowTail 20
```

Generate the safe resume prompt:

```powershell
.\system\scripts\novel-next-prompt.ps1 -SystemRoot .\system -NovelRoot .\novels\<book-folder>
```

Inspect quota/tool errors:

```powershell
.\system\scripts\novel-health.ps1 -SystemRoot .\system -NovelRoot .\novels\<book-folder>
```

Full low-context diagnosis for resuming after quota recovery:

```powershell
.\system\scripts\novel-doctor.ps1 -SystemRoot .\system -NovelRoot .\novels\<book-folder>
```

Review gate used by the orchestration flow after reviewer batches:

```powershell
.\system\scripts\review-gate.ps1 -NovelRoot .\novels\<book-folder> -Chapter 01 -Phase draft
```

Targeted consistency lookup used inside planner/writer/reviewer roles:

```powershell
.\system\scripts\consistency-lookup.ps1 -NovelRoot .\novels\<book-folder> -Query "<entity/location/rule>"
```

## 剧情生长 Skill（实验版）

新增的 `grow-story` 位于 [.agents/skills/grow-story](.agents/skills/grow-story)。它从种子迭代完整、简洁的剧情框架，支持人物与跨剧情连续性审核、局部 JSON 变更及原子保存。现有 `system/` 章节工作流和启动脚本未接入此新流程。

在仓库根目录开启支持项目 Skills 的 Codex 会话，明确调用 `$grow-story`；若客户端未自动发现，可让它读取 `.agents/skills/grow-story/SKILL.md`。首次使用先按 `references/state.md` 创建项目状态；修改时按 `references/delta.md` 生成局部包，再审核和提交。

示例请求：使用 $grow-story，从一句话故事生成完整简版，再自主完成一轮生长；只输出剧情框架，采用前检查连续性，采用后同步记录。

脚本需要 Python 3 和 POSIX（Linux/macOS/WSL）；目前使用 `fcntl`，不直接支持原生 Windows。运行测试：

```sh
python .agents/skills/grow-story/scripts/test_apply_patch.py
```

已通过 11 项合并程序测试，以及一组 6 案例的连续性审核实验。结构校验不证明故事合理；长篇稳定性、向量检索和自动语义审核尚未验证或实现。人物卡当前按受影响条目替换，并非字段级最小补丁。
