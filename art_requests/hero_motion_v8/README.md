# 主角能力动作 v8

九类人物动作，46 个选定新绘姿势：格挡 6、疗伤 6、钩索 4、贴墙 4、相位 4、共鸣 6、投射 6、控制 6、防御起手 4。替换原 36 格，正式独特帧由 138 增至 148。待机与 `attack_2` 尚未补绘。

`sources/*.png` 是 image_gen 的原始交付；同名 `.txt` 保存实际提示词。初次生成以正式 v4 跑步和对应的原动作作参考。选定 `guard_v2.png`，避免即时格挡首格剑身过低；选定 `skill_defense_v3.png`，保留用户指出的第二格手臂修正。原防御第二格双臂挤在头后，v2 将剑柄移至额头前上方并分开肘部，v3 再清理背景。所有未选稿原样保存，不重复计入 46 个姿势。

- `requests.json`：动作范围、选稿、旧稿与原因。
- `previous_animations.json`：接入前的九条生产动画记录。
- `source_slices.json`：实际尺寸、逐格区域、独立主体数、源图与提示词哈希。不能假定所有图片尺寸相同或各列等宽。
- `calibration.json`：正式跑步的脸部连通区域作为比例参考，每张源图使用一个固定倍率，不逐帧改变大小。

打包仅执行主体隔离、裁取、普通缩放与透明留边；没有补画姿势、变形扩帧或插帧。地面足底为 280 行；贴墙使用躯干高度注册，并将前靴接触点注册到 x218，对应现有 34px 宽碰撞体。运行时画布为 384×384。九条动画原来的 0.4 秒标称长度与循环设置保留，实际攻击、治疗及格挡进度继续由控制器决定。钩索保留四格语义；防御有效阶段由 `guard` 接管。

```powershell
python -X utf8 art_requests/hero_motion_v8/audit_sources.py --check
npm run build:hero-motion-v8
python -X utf8 tools/validate_hero_v3.py
npm run test:hero-motion-native -- --engine <Godot-4.6.1-console路径>
```

运行时证据与攻击线条清理见 [本批报告](../../docs/report/20261105_hero_motion_v8.md)。源图交付不单独构成游戏验收。
