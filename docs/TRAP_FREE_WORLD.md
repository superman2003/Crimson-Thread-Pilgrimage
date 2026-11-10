# 关卡陷阱撤除与运行素材核对

六章关卡撤除地刺、假苔地板、钟隙、孢子箱、落钟、捷径伏击、假灯等环境陷阱。44 处手工布置与 140 处生成配置布置已清空，当前 Soulbox 蓝图的 36 个陷阱规划引用及规格镜像同步清空。

`main_level.gd` 不再安排陷阱生成任务。旧 `_hazard`、贴图与接触回调保留为空兼容入口，旧数据也无法创建画面、碰撞、伤害或地刺反弹面。两套旧素材目录内 16 张陷阱 PNG 及各自的导入描述共 32 个文件删除，素材生成器不再输出它们。截图中的紫色地刺对应旧 `gothicvania/demo/hazard_spikes.png`。

地图、灰盒、多层扩建和手工箱庭生成器同步改为输出空陷阱列表；地图提示已更新。角色的攻击、玩家战具以及越出地图后的复位仍沿用原有机制。这里的撤除范围是关卡环境陷阱。

静靴、防潮线结保留原名称、任务来源、物品 ID、槽位和存档解锁，原陷阱缩小效果改为装备时增加 5% 地面移动速度，两者继续互斥。持有未装备不生效，卸下恢复原速度；角色碰撞与绘制尺寸不随装备变化。

## 素材依赖

旧 `validate_enemy_runtime_manifest_coverage.py` 默认检查早期单一攻击与 `runtime_keyframes` 布局，和当前运行选择不一致。默认入口现复用按实际优先级解析的核对器；`--legacy` 可单独检查历史布局。

运行层按原画优先级选择 onion、v8、Boss 行为、v7、motion、基础 manifest，并合并当前战斗指令。核对 40 种小怪、6 位章节 Boss、25 位 NPC，以及储备 Boss 库；检查实际图集加载、PNG 完整性、裁切范围、逻辑画布、攻击各阶段和特效注册。`falling_clapper` 的敌人兜底引用指向自己的原画 manifest，不再指向同名陷阱贴图。

资源闭包从真实 World/Main 场景、项目设置和数据目录开始。带格式占位的动态路径模板单列，方法说明不作为文件路径；没有把模板报告成素材缺失，也没有把静态检查当作任意动态路径的完整证明。

两份历史素材来源清单同步移除已退役陷阱，避免清单仍登记已删除文件。对应旧素材库检查不再要求陷阱存在；GothicVania 检查只验证保留的旧素材库，不再错误要求当前主角使用旧像素角色。

运行：

```sh
npm run test:trap-free
npm run test:runtime-assets
python tools/check_trap_free_world_native.py --engine /path/to/godot
```

CI 由 `.github/contracts/trap-free-world.yml` 执行：测试真实地图再生成、素材依赖、六章和 World 入口、旧入口无效、奖励迁移和配装、普通战斗命中、前两章流程。

## 证据及边界

见 [原生验证及截图](../artifacts/trap_free_world_v1/README.md)。原生测试使用 Godot 4.6.1、GLCompatibility、Dummy 音频与独立用户目录；图片为实际场景入口截图。逐项程序检查与入口截图不能替代六章自然通关、逐房视觉验收或主观动作流畅度验收。

当前实际运行地图的 `npm test` 与章节检查通过。额外执行 `test:generated-maps` 时，未启用的生成地图恢复点几何审计报出 54 项既有问题；逐文件比较父版本得到相同的 54 项，本次没有修改其地形或恢复点，详见 `validation/generated-geometry-baseline.json`。没有将这项检查记录为通过。
