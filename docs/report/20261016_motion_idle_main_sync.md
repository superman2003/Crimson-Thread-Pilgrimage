# #94 动作、镜头、待机与最新工房主线的依赖同步

## 精确来源和范围

- 第一父提交：正式 #94 `aa02c4af1876a01c4853a53c9c54fa65d26d881b`，包括外部合入的 #93 固定身体、七披风区域待机。
- 第二父提交：main `07ae21d4c35ae6a33ca45809cf02d96c015ccf66`，包括外部合入的 #91 十九工房及十九次磁盘重启验收。
- 共同基线：`1806e0cf98a12f1d2b7a2cf175803cfe42de0746`。
- 仅同步依赖并本地构造双父 merge commit；没有新增功能，没有改生产算法、待机 helper 或素材，没有执行 GitHub 合并、自动合并、部署或 Release。

## 冲突解决与不变量

实际六处内容冲突为三份升级台账、默认 runner、成功 marker JSON 和 runner 单元测试。Main、生产 GDScript 及 workflow 没有内容冲突。

- 三台账保留双方历史及未完成边界，新增当前组合状态。
- 默认集、固定时钟集、成功 marker 取双方精确并集：总计 106 套，无重复或缺失，含四套叙事；保留 10+9 工房、10+9 次重启的严格完成标记。
- 所有继承的单套 180 秒上限、渲染模式和严格 ERROR/SCRIPT ERROR 检查保持。镜头保留真实 Player 参数，待机保留真实 GL 完整像素契约；负面断言继续执行。
- 57 个非冲突来源差异文件逐字节一致；11 份关键生产脚本、747 个函数记录 SHA-256，均与正式 #94 来源一致。main 本次增量没有修改生产 GDScript，工房数据与验证器原样继承 main。
- Main 场景、main_level.gd 和主集成 workflow 与双亲均一致；motion/melee、room-camera、layered-idle 与 modern-ability-workshops workflow 全部保留。
- fixed_support.png：`2f596483024a92aa621929ab40766088ae7e1ec657d653e5301284d8c775dc30`。
- cloth_eight_phase_rebalanced.png：`222d12909c41bdf26c19b5a4362aca9376140cfae0aca1a8a3be378cc0baf706`。

完整来源/函数哈希见 [verification.json](../../artifacts/motion_idle_main_sync/verification.json)。函数块哈希连同文件哈希用于确认原样保留，不代替运行时验证。

## 本同步提交的实际验证

- `npm test`：PASS，包含 JS 三组 smoke、活动六区几何/唯一性、6 项地图审计负面测试、28 项 runner、11 项 import helper、11 项 GPU runner helper 测试。
- `npm run test:campaign`：PASS，包括路线/通道/叙事及 11628 项世界升级静态检查。
- `python3 tools/test_regression_runner.py`：28 项 PASS。
- `python3 tools/test_workshop_layout_contract.py`：30 项 PASS。
- 默认 106 项集合及 marker、固定时钟并集、来源文件和两图 SHA：PASS。
- 新组合严格导入：尚未运行。
- 新组合真实 GL：尚未运行，等待独占运行窗口。runner 单元测试中的模拟 GL 标记不是实际 GL 证据。
- 新提交完整 106 套远端 CI：待发布后对精确 head/tree 核验。旧 102/103 套结果仅是各自来源的历史证据，不记作本同步提交通过。

## 后续最小受影响门禁

使用显式 Godot 4.6.1、独立规范化 XDG 目录和 0700 runtime 目录，严格双导入后运行：player_layered_idle、player_motion_continuity、player_melee_feedback、room_camera_stability、world_upgrade、world_workshop_group_one、world_workshop_group_two、world_ability_acquisition、world_gameplay_plan、world_route_manifest_integration。保留继承渲染模式和原 180 秒限时。该组合同时覆盖实际 Player 表现与新工房数据/重启在同一树中的接合，未声称是全 106 套本地重跑。若上游精确合并树已给出同源码的对应结果，明确列来源复用，避免重复完整集。

## 仍开放的验收

- 待机坏接点 2→4、6→7、7→1；完整呼吸与跑、攻、落地之间视觉连续性。
- 固定身体加七个披风区域不等于七张全身帧，也不等于完整漂移、循环或跨动作美术验收通过。
- 历史 76 落点性能验收、自然带伤六区体验及原工房夹具的产品体验边界继续开放。
- 本轮仅处理冲突与依赖。未通过改素材、helper、超时或图形模式获得性能绿灯。
