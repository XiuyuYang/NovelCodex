# 局部变更提交

自由构思、完成语义审核后，仅输出一个局部 JSON 变更包，不重写整个状态。程序重建并校验完整快照。

字段仅包含 base_version、base_sha256、operations。base_sha256 使用当前文件原始字节的 SHA256，由程序取得，不凭空填写。每项操作为：

- replace：op、collection、id、value；value 是该条目的完整新值，id 保持不变。
- add：同上；新增 events 额外提供 after（前一事件 id；null 表示最前）。
- remove：op、collection、id。

collection 仅可为 events、characters、world、dependencies、foreshadowing。所有集合的条目必须有稳定 id；首次接入旧记录时一次性分配缺失 id 并单独保留旧快照。修改人物只需输出受影响人物条目，未变的人物和事件不要输出。同一包不重复操作相同条目。拆事件时移除旧条目、添加新条目、重定向全部引用和依赖；将旧新映射记入新事件的 supersedes 字段。删除的事件 id 不可复用。

示例形状：
```json
{"base_version":2,"base_sha256":"从当前文件计算的64位散列","operations":[{"op":"replace","collection":"events","id":"E0010","value":{"id":"E0010","arc":"A01","text":"已审核的新事件全文"}}]}
```

运行（将路径替换成实际项目路径）：
```bash
python <skill>/scripts/apply_patch.py current.json patch.json --dry-run
python <skill>/scripts/apply_patch.py current.json patch.json
```

语义审核先于正式提交；dry-run 只校验结构、编号、版本和原句引用，不审核故事合理性。通过正式提交后，current.json 为唯一当前状态；事件和记忆同快照原子替换，旧快照保存到 history/。使用 POSIX 排他锁，拒绝过期版本、散列不符、重复目标、无效引用或悬空依赖。更新事件后会重验未修改卡片的原句，必要时一起修订卡片。事实与引用含义是否一致仍需模型核对。遇到进程崩溃或存储故障，检查命令结果和当前版本后再继续；不要盲目重发或假定未提交。

不要为使用局部输出而承诺局部读取已经实现。这个脚本仍在程序内加载完整状态；模型只需获取与创作有关的原文和索引。向量检索、自动语义审核与长程调度尚需独立实现。
