# NovelCodex — 剧情生长

使用现成模型和 grow-story Skill，从一句话迭代完整、简洁的剧情框架。创作、连续性审核、局部变更提交分别进行；通过检查后统一更新事件、人物、设定和伏笔。

## 使用

在本仓库根目录打开支持项目 Skills 的 Codex，调用 `$grow-story`。若未自动发现，让执行实例读取 `.agents/skills/grow-story/SKILL.md`。

示例：使用 $grow-story，从我的故事种子创建完整简版，再自主完成一轮生长；只生成剧情框架，审核后用局部变更更新记录。

项目记录规范见 [state.md](.agents/skills/grow-story/references/state.md)，局部提交协议见 [delta.md](.agents/skills/grow-story/references/delta.md)，连续性审核见 [continuity.md](.agents/skills/grow-story/references/continuity.md)。首次使用需按记录规范初始化 current.json；目前没有一键初始化和自动长程调度器。

## 运行环境与测试

Python 3，Linux/macOS/WSL。合并脚本使用 fcntl，目前不直接支持原生 Windows。

```sh
python .agents/skills/grow-story/scripts/test_apply_patch.py
python .agents/skills/grow-story/scripts/apply_patch.py <current.json> <patch.json> --dry-run
python .agents/skills/grow-story/scripts/apply_patch.py <current.json> <patch.json>
```

局部包由模型生成，程序重建完整状态，校验版本、编号、来源引文和依赖，保存旧版本后原子发布。结构校验不证明剧情合理或记忆语义正确，提交前仍需审核。

## 当前验证范围

12 项程序测试通过（含双进程同基线竞争提交）；已完成一组 6 候选的连续性审核，以及鱼缸故事局部提交试跑。试跑发现过人物卡概括过强的问题，已用局部修复包修复。长篇稳定性、向量检索、自动语义审核尚未验证或实现。

本次版本以新版内容替换旧文件树；旧章节生成系统只保留于 Git 提交历史，不在当前工作树中。

并行探索与串行提交规范见 [parallel.md](.agents/skills/grow-story/references/parallel.md)。它是供执行实例遵循的协调流程，尚非无人值守并行调度器。
