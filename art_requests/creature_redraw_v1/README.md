# 怪物动作清单重绘 v1

按 `docs/research/20261111_creature_redraw_list.json` 的排序分批交付。
首批完成 `rust_crown_guardian` 的 `walk`（32 张）和 `idle`（16 张），对应清单第 1、3 项。
第二批完成盐白裁判、静冠核心、孢铃匠、根笼猎手、苔铃幼虫、蜡枪兵、纸页决斗者、锈潜者的走路，共 160 张。
第三批完成水轮骑士、盐书螨、藤蔓爬虫、黑曜枪兵、廊道重甲、齿轮哨卫、排水蛭、抹除执达员的走路，共 128 张。
按 #588 审查后修订的 261 段有效清单，累计完成 18 段、336 张原画，剩余 243 段。首版 284 段中不播放的 23 段已移出重绘范围。逐项状态保存在 `progress.json`，以角色／片段名对应。

全部新姿势来自内置 image_gen；`sources/` 保留选中的原始透明 PNG 和
实际提示词，`jobs/` 记录原图、提示词及输入参考的 SHA256。
首版待机因贴边拒收，仅保留缩略图和收据。

`tools/creature_redraw_art.py` 只裁切、统一整张图的注册比例、固定落脚位置、
打包图集；不会生成姿势，不会逐帧调大小，不会复制或混合端点来补帧。
每个片段保留原帧数、帧率、循环规则，运行画布、节点比例和偏移不变。
`motion_redraw_manifest.json` 继承完整生产图层，仅替换明确登记的两个片段；
旧原画及 v7/v8 可重复构建输入保留。

重建与复核：

```sh
python tools/creature_redraw_art.py --kind rust_crown_guardian
python tools/creature_redraw_art.py --all --check
python tools/build_creature_frame_fit.py --only rust_crown_guardian
python tools/build_creature_frame_fit.py --check
python tools/audit_motion_scale_consistency.py
```

待机：平均轮廓变化 0.276 → 0.0492，接缝 0.0694，16 张像素均不相同。
走路：平均轮廓变化 0.316 → 0.0548，接缝 0.0985，32 张像素均不相同。
新片段的变化与整体平移 2px 的比值为 0.701／0.780，低于清单的 3 倍门槛。
这些指标衡量轮廓连续性；实际游戏中的造型和步态仍由原生回归及人工观感验收。

逐帧前后图和半速并排动画在 `artifacts/creature_redraw_v1/`。
