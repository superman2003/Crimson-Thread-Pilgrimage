# U05 旅记与对话：World 会话阅读位置

对应 `SILKSONG_ALIGNMENT_REVISED_PLAN.md` 的 U05「旅记与对话」，推进长文本、字幕与中断恢复可靠性。基于 main `e17ff53206dca1d983d6f2018be3a28926ae9bbd`，独立于 U04/S03 分支。

## 行为

区域拥有的 HUD 重建会销毁原有阅读缓存。现在两个有界阅读器归属于同一个 World 节点的会话元数据，替换 HUD 复用阅读器；它们不引用旧 HUD、NPC、文本或主存档。新 World 即便使用相同文件路径，也不继承旧会话。存档槽发生变化时清空当前阅读身份，不复活退休会话。

HUD 退出时只捕获旅记滚动位置和未提交字幕的揭示/滚动数字。正常关闭已提交对话仍删除书签，读取缓存不会提交交谈、推进愿望、发放奖励或写入主存档。上限沿用两类阅读器各 64 条、内容指纹和数值约束。

异步滚动恢复保留原会话代次。切槽发生在 await 前，或发生在 call_deferred 尚未开始时，即便新页面的 key 和正文相同，旧位置都不会应用到新页面。

## 验证

- Godot 4.6.1 headless + Dummy 音频，以仓库原生 UI 脚本、实际字体/UI/VFX 资源运行。
- `WORLD_READING_SESSION checks=355 failures=0`：严格元数据、会话/槽位隔离、有界淘汰、无正文缓存、真实 UI 销毁与重建、异步滚动竞争和已提交字幕不重播。
- 未修改的 `BUILD_SLOTS_UI_VALIDATION checks=58 failures=0`：装备界面、旅记键盘/手柄输入事件及内容变更后的书签失效回归。
- `tools/run_world_reading_session_contract.py` 要求导入/运行退出码为零、无 ERROR/SCRIPT ERROR/USER ERROR、各套成功标记，分别保留 120 秒时限。第二套即便第一套失败也会执行。
- 新增独立 CI；既有集成测试、三个 runtime 分片及其严格条件不变。

本地上述两套均通过。完整 World 流程与桌面导出交由现有 CI；未在本地完成真实 GPU、实体手柄、不同字号与自然阅读理解验收。不是跨进程持久书签，也不关闭 U05 最终验收。
