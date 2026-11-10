# 给 AI 协作者（Codex / Claude）的仓库规则

这些规则由 CI 强制检查（`.github/workflows/ci-hygiene.yml`）。违反规则的 PR 会直接失败，不需要人工提醒。

## CI：新增检查写成"合同"，不要新增 workflow

- 需要 Godot 的专项检查，一律写到 `.github/contracts/<名字>.yml`，**不要**放进 `.github/workflows/`。
  - 格式和普通 workflow 一样：`on.pull_request.paths` 指定触发路径，一个 `ubuntu` job，步骤照常写下载 Godot、`apt-get`、`git lfs pull`、`run_godot_import.py`、测试命令。
  - `.github/workflows/contracts.yml` 会识别这些准备步骤，每个分片只执行一次，再按顺序运行各合同的测试命令。每份合同有独立的 `RUNNER_TEMP` 和 Godot 用户目录。
  - 一份合同失败不会中断其他合同，最后统一列出所有失败。
- 合同不支持的写法：矩阵、多个 job、`actions/checkout` / `upload-artifact` 以外的 action、`fetch-depth` 不为 1、`${{ github.token / runner.temp / PR head sha }}` 以外的表达式、条件步骤（`always()` / `!cancelled()` 除外）。确实需要这些写法时，留在 `.github/workflows/`，并在 `tools/ci/workflow_allowlist.json` 里写明理由。
- 所有 `pull_request` workflow 都要配置 `concurrency` 和 `cancel-in-progress: true`，这样新推送会取消旧运行。
- 如果一个步骤失败后还应继续执行后续检查，用 `if: ${{ !cancelled() }}`，不要用 `continue-on-error` 或 `|| true`，以免掩盖失败。
- 提交前在本地运行：
  ```bash
  python3 tools/ci/contracts.py lint
  python3 tools/ci/test_contracts.py
  ```

## 仓库体积：大素材不要直接提交进 Git

- 单个 PR 新增或修改的非 LFS 二进制文件，单个不超过 8 MiB，合计不超过 60 MiB（`tools/ci/check_binary_budget.py`）。
- 超出时：
  - 正式素材改走 Git LFS（`.gitattributes`）；
  - 生成过程的草稿、被拒的候选图、参考板不提交，或者只提交缩略图和收据；
  - 确实必须提交的，请维护者给 PR 加上 `large-assets` 标签。
- LFS 有流量配额。CI 里只拉取需要的路径（`--include`），不要 `lfs: true` 全量拉取。

## 本地工作树

- 额外的工作树放在 `~/code/` 下，PR 合并后用 `git worktree remove` 删除。
- 不要用 `--filter=blob:none` 部分克隆后再执行 `git ls-tree -l` 或 `git cat-file -s`：这会逐个下载 blob，中断后会在 `.git/objects/pack/` 里留下几个 GB 的临时包。查看远端的大文件，用 `gh api -H "Accept: application/vnd.github.raw" repos/<repo>/contents/<path>?ref=<sha>` 逐个流式读取。
- 运行 `python3 tools/prune_local_worktrees.py` 可以列出可删除的工作树和残留的临时包（默认只列出，加 `--apply` 才会删除）。

## 台账

每个 PR 新增 `docs/ledger/entries/*.md`，需要时更新 `docs/ledger/status/<编号>.md`。不要直接修改 `docs/UPGRADE_TASK_LEDGER.md`，详见 `docs/ledger/README.md`。
