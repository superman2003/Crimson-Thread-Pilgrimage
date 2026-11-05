# 台账源文件

`docs/UPGRADE_TASK_LEDGER.md` 由 `tools/build_ledger.py` 根据本目录生成，**不要直接修改它**。这样，并行的 PR 不会再在同一个文件的顶部互相冲突。

## 每个 PR 要做的事

1. **新增一条记录**：在 `entries/` 新建一个文件，名为 `YYYY-MM-DD-HHMM-主题.md`，例如 `2026-11-05-1430-u01-dialog-reading-size.md`。
   - 主题只用小写字母、数字和连字符，日期和时间用北京时间。
   - 文件内容是一条以 `## YYYY-MM-DD：标题（任务编号 子项）` 开头的记录，后面是正文，只写这一条。
2. **更新任务状态**（如有需要）：修改 `status/<编号>.md`。每个文件只有一行表格：`| 编号 | 当前证据 / 状态 | 下一验收交付 |`。

不要在 PR 里重新生成或修改 `docs/UPGRADE_TASK_LEDGER.md`。PR 合入 main 后，`.github/workflows/ledger.yml` 会自动重新生成它并提交。

## 其他文件

- `header.md`：标题。
- `archive.md`：早期的自由格式历史记录，原样保留，不再追加内容。

## 本地预览与检查

```bash
python3 tools/build_ledger.py --validate   # 只检查本目录的格式（PR 的 CI 也会跑）
python3 tools/build_ledger.py              # 在本地生成台账预览（不要提交生成结果）
python3 tools/test_build_ledger.py         # 生成器自测
```

两个 PR 只有在改同一个任务的 `status/<编号>.md` 时才会冲突。
