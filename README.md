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
