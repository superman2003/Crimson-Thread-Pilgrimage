# 敌人移动衔接原画 v1

首批为 `moss_larva`：6 张转身原画、6 张急停原画。每段另引用一个既有起始姿势，共 7 个运行时帧引用；不把镜像、旧帧或定位标记修正计入新绘姿势数量。当前并未完成其他 45 个角色，也没有给不会跳跃的角色虚构跳落动作。

使用内置 image_gen 绘制，沿用 [motion_onion](../motion_onion/README.md) 的完整定位与比例门槛。332×241 逻辑画布、原有缩放、偏移及核心动作完全保留。预备图中的镜像仅用于标出转身终点，绝不作为交付原画。运行时反方向播放采用整段转身画稿的正常朝向翻转。

## 可复现交付

```sh
python tools/enemy_transition_art.py audit --kind moss_larva
python tools/test_enemy_transition_art.py
python tools/test_motion_onion.py
python tools/audit_motion_scale_consistency.py
python tools/validate_runtime_asset_dependencies.py
```

`jobs/moss_larva.json` 保留每次实际提示词、输入引用 SHA256、原始生成图 SHA256、注册矩阵、逐帧检查结果和选中裁片 SHA256。`sources/` 只提交两张选中的原始生成图，`accepted/` 保留注册裁片。两版急停候选因角点标记不合格被拒收；第三版通过 image_gen 仅修复标记后，重新通过原有严格门槛，未修改门槛或逐帧缩放角色。

被拒整图和预备参考板不进入 Git，`receipts.json` 与 `receipts/` 提供哈希、尺寸和缩略图。审计直接从选中原始生成图重新注册，逐像素比较裁片，并校验正式图集、manifest 和原有核心图层哈希，防止裁片被事后改动。机械重建的镜像参考只参与检查。

新增绘图使用 `prepare --kind ... --action turn|brake`，将打印的两张预备参考交给 image_gen；`deliver` 必须记录实际提示词和实际输入图，拒收必须重绘。当前提示词针对地面角色，飞行和固定角色应先另写符合其运动方式的姿势要求，不能直接套用。

## 游戏接入

`motion_transition_manifest.json` 是固定核心图层的完整扩展。生产读取、依赖审计、比例检查及动作审计使用相同优先级。新画稿的邻帧面积检查仍为原来的 1.5 倍门槛。

转身在真正需要改变朝向时播放，结束才提交水平朝向；急停由实际位移到静止触发。首姿势使用这个实例上一刻实际显示的纹理，避免从任意走路帧跳到指定第一帧。只复制实例的 SpriteFrames 容器，不改变公共缓存、纹理、尺寸、碰撞或 AI 状态机时间。攻击、相变、死亡立即打断；受击继续叠加生产闪白和击退；界面暂停、房间卸载分别暂停和取消过渡。

原生检查命令：

```sh
python tools/check_enemy_transitions_native.py --engine /absolute/path/to/Godot
```

测试使用真实 GL 和 AnimatedSprite2D 播放时钟，包含生产巡逻钩子、每一张新姿势、反向转身、快速改向、暂停、普通/致命受击、攻击截止时间、相变、房间卸载与实例隔离。它是定位构造的组件验收，不能代替自然路线通关或主观观感验收。

实际绘制截图在 `artifacts/enemy_transitions_v1/moss-larva-native.jpg`；源图大小、角色比例和落脚点还需每个角色逐个翻页检查。
