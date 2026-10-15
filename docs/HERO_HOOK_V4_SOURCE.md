# 钩索独立源表检查点（2026-10-12）

> 文档状态校准（2026-10-15）：本文包含钩索源素材准备与后续集成两个历史阶段；早期“尚未接入”只指素材检查点，后文集成结果不追溯改写早期状态。当前钩索需已取得能力，默认K／X，操作以[玩家指南](RELEASE_PLAYER_GUIDE.md)为准。

恢复基线：PR #15 `97550d6`，该提交远端 CI 已通过。

使用内置 imagegen，参考既有 movement.png（身份与服装）和 traversal.png（动作用途），新增版本化源表 `godot/assets/sprites/player/generated_hero_v3/sources/actions/hook_throw_v4.png`。旧源表保留。先保存源图与制作说明，再接入透明帧、验证和实机证据。

生成提示：

Use case: identity-preserve. Asset type: ORIGINAL game character hook-throw animation source sheet for Crimson Thread Pilgrimage. Reference image 1 locks identity, outfit, palette, linework, side-view art style. Reference image 2 shows old traversal poses; create ONLY four replacement hook-throw poses, not the other actions. Preserve the same young dark-haired ponytail character, red scarf, teal split cape, dark tunic, brown boots, gold needle hilt, facing RIGHT. New square transparent PNG arranged EXACTLY 2 columns by 2 rows, four isolated full-body poses in order: upper left anticipation with needle drawn back; upper right release with right arm extended and a short separate hooked needle on a red thread; lower left tension/pull with both arms bracing and a bent knee; lower right recovery with thread reeled back and needle lowered. Same physical body proportions and scale in all four cells. Feet near each cell's 82% height, body at 55% cell width. Keep complete hair, cape, boots, needle and thread INSIDE their own cell with at least 12% cell-width transparent margin on every cell edge; constrain any red thread to a short self-contained arc. No strand can cross into another cell or touch another character. Transparent gutters between poses; NO background, NO floor, NO labels, NO grid lines, NO ornaments or particle effects. Actual alpha transparency, no painted checkerboard. Keep the art as a crisp hand-drawn 2D side-view sprite, no stylistic or costume redesign.

初检：四姿态在新源图中分离，可避免旧表中两名角色被线连接。生成器没有严格满足所有格内余量要求，因此仍采用连通区域提取，不把格线作为裁切边界。尚未接入运行时，不代表已完成动作验收。

源边问题复核：五张旧源表在真实画布边界均无 alpha>128 像素；上一检查点的16项指不足8像素余量，不能把它们直接称为已确认源画截断。后续分别记录真实画布边界像素和安全余量警告。

后续集成完成：新表四帧已接入，其他76帧哈希不变。当前输出裁切、真实不透明画布边界与活跃相连姿态均为0；20项安全余量警告保留。运行时拉动保持受力姿态并在正常结束后收线。验证来源与边界见 HERO_AND_LARGE_ROCK_UPGRADE.md 及 artifacts/hero_rock_upgrade/checkpoint3/verification.json。
