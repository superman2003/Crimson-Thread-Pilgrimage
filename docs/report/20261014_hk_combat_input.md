# 主角输入缓冲与敌人攻击生命周期

日期：2026-10-14。main 基线 `278aec8a5df8ee94097878d0c80e961a0e4f78a2`；承接未合并 PR #46 的 `b1d5cee160d713cb2bfc5df22d443376ebb003da`，该分支相对 main 仅包含六个敌人修复/验证文件。本批在其上继续提交，PR 目标为 main。

## 交付

参考用户提供的《HollowKnight 技术栈分析（详细版）》中输入缓冲、统一状态闸与生命周期思路，在现有 Godot 控制器中补齐普攻/冲刺的短输入窗口。既有跳跃缓冲与土狼时间保留。

- 动作后摇或冲刺冷却结束前最多 0.10 秒的按键可保留到下一次合法执行。Inspector 可调 `action_buffer_time`（0–0.25 秒）；0 秒仍能响应即时输入。
- 同时只保留一个普攻/冲刺指令；新指令替换旧指令，长按不重复，同帧维持冲刺优先。过期指令不会等待长冷却结束后突然执行。
- 保留按下时的攻击方向或冲刺左右方向；执行时朝向与命中框一致。冲刺进行中反向移动不再改变冲刺方向。
- 仍使用 InputMap，沿用键鼠、手柄与重映射。冲刺仍可取消钩索；能力未解锁、冷却、动作状态与世界通道限制不会被缓冲绕过。
- 菜单/地图/对话锁输入时立即清空动作与跳跃缓存；接受伤害、复活、存档点恢复、换构筑和区域交接清空动作缓存。忽略的伤害不清空有效指令。新攻击、治疗、格挡和钩索也会清除旧指令。
- 承接 #46：死亡/离树/非驻留敌人停止产生攻击；攻击效果在命中回调前消耗命中标记，终止时立即退出攻击组；活敌复活清理攻击、冷却、特效与补间。详细范围见 `docs/ENEMY_LIFECYCLE_REGRESSION.md`。

## 最终本地验证

- `npm test`、`npm run test:campaign` 通过；回归运行器 10 项、导入工具 11 项通过。
- Godot 4.6.1 完整资源导入两轮通过。首次导入因完整资源数量在默认 180 秒时限停止；使用 900 秒时限重新完整导入两轮，未放宽错误门禁。
- 实际 Mesa llvmpipe OpenGL 定向四套通过：输入缓冲 32 项、敌人生命周期 31 项、效果寿命 29 项、视线 36 项。
- 输入套件使用生产 Player 场景、InputMap 输入和真实 CharacterBody2D 地面碰撞；额外核对 30/60/120Hz 的模拟时间过期。不计自然流程通关或人工手感验收；该夹具静音。
- 定向输入/生命周期套件退出时有 ObjectDB 警告；严格 SCRIPT ERROR/ERROR 门禁保留。最终完整默认回归 **73 套、0 failures**，全部使用真实 Mesa llvmpipe GL 并保留严格错误门禁。最终输入缓冲套件仍为32项、0失败。通过状态、检查数量、警告数量、逐套日志 SHA256 与源码哈希已存入 `artifacts/hk_combat_input/verification.json`；运行代码与测试文件对应已上传检查点 `57373a9`，后续提交仅补统计证据、进度及新验证脚本的 UID。原始日志保留在本机验证环境；公开上传压缩日志被自动审批以可能包含本机/项目信息为由拦截，故公开证据采用不含日志正文的统计摘要。

## 进度边界

本批完成 C01/A02 的输入与战斗生命周期子项；不将 W00c、T03/T04、六区开启伤害通关或全部空洞骑士对齐标为完成。音频资源 PR #45、桌面发布 PR #38 仍是独立范围，本批没有重复导入它们的内容。未合并 main 或发布游戏。

复现命令（需先安装 Godot 4.6.1、Xvfb 并完整取得运行素材）：

```sh
npm test
npm run test:campaign
python tools/run_godot_import.py --engine "$GODOT" --recovery-mode --timeout 900 --log-dir /tmp/pilgrimage-import
python tools/run_godot_regressions.py --engine "$GODOT" --software-gl --log-dir /tmp/pilgrimage-regressions
```

GitHub Actions 以 PR 最终提交单独验证，当前远端状态见 PR checks；不将运行中的远端任务计作通过。
