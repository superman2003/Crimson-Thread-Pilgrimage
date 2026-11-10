## 2026-11-09：CI 下载 Godot 改走带 token 的 API（T05）

- 11-08 到 11-09 期间，GitHub Releases 下载间歇性返回 504。GitHub 状态页的说明是：匿名访问激增导致超时。CI 用匿名 curl 下载，多个 PR 的 runtime、visual、desktop 等检查都在第一步失败。只把重试加长到约 2 分钟并不够，这个 PR 自己的检查就仍然失败。
- 170 个 workflow 的 Godot 下载改为先用 `gh release download`（带 `github.token`，走 API，不算匿名访问）。失败时退回原来的 curl，并把 curl 的重试加长到 `--retry 8 --retry-delay 15 --retry-all-errors`，原来没有重试的 10 处也一并加上。下载地址、校验值和后续步骤都不变，保留各文件原有换行。
- 发布构建用的 `tools/download_godot_release.py`：
  - 在提供 `GH_TOKEN` 时，第一次尝试同样走 `gh release download`；
  - 下载结果仍按官方 SHA512 校验，不符就退回原来的带重试 HTTP 下载；
  - `release-candidate.yml` 为这一步传入 token；
  - 新增 3 个单元测试。
