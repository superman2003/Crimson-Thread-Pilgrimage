## 2026-11-09：CI 下载 Godot 时的重试加长（T05）

- 11-08 到 11-09 期间，GitHub Releases 下载间歇性返回 504。原来的 `curl --retry 3` 总共只等约 7 秒，多个 PR 的 runtime、visual 等检查在第一步就失败，测试一项都没跑到。
- 170 个 workflow 的 Godot 下载统一改为 `--retry 8 --retry-delay 15 --retry-all-errors --connect-timeout 30`，可撑过约 2 分钟的短时故障。原来没有重试的 10 处也一并加上。
- 只改下载参数，下载地址、校验值和后续步骤不变；保留各文件原有的换行格式。`tools/download_godot_release.py` 本来就有 5 次指数退避，不需要改。
