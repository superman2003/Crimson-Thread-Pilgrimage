# 小怪技能与预警素材 v4

本批覆盖六章实际放置的 40 种普通敌人、80 招基础攻击及 10 招精英攻击。逐招审计见 [audit_notes.md](audit_notes.md)，机器可读的技能与出生点对照见 [audit.json](audit.json)。源图、生成提示词、源图检查与游戏运行验证分开记录；交付数量以 [incoming/delivery_status.json](incoming/delivery_status.json) 为准。

## 攻击方式

40 招咬击、挥砍、刺击、反击、连击、冲撞、俯冲、跳刺与退刺使用敌人身体或武器前方的近身判定。特效随敌人移动，沿用实际攻击矩形和左右朝向，不发射独立飞行的刀光或弹幕。俯冲和跳刺的前摇是局部蓄势，生效时转为对应近身攻击范围。

原本设计为投射物、投掷、散射、地波、陷阱、根刺与光束的招式继续使用各自攻击模组。2 招闪移投刃保留原有影刃，并补局部离开／到达表现。不能用一套远程效果替换这些不同动作。

## 素材范围

40 张源图共 414 格：90 组前摇、42 组新增生效表现，以及熔蜡拖尾预警／生效、管弹落地预警、旗手支援引导／连接／完成 6 组额外效果，每组 3 格。50 招已有远程或范围技能的生效素材继续使用 v1；其中 2 招闪移的投刃与新增闪移表现重叠，不能重复计入技能总数。

19 招地面／通道预警直接绘制在实际危险对象上，保留落点、半径、延迟与墙体截断。旗手支援只在真实引导成功并恢复同伴 HP 后显示完成效果，取消、目标失效和角色死亡都清理相应素材。

## 源图与复现

- [requests.json](requests.json)：逐种族、逐攻击 ID 的行序、材质、拓扑和时间参考。
- `prompts/FX_M_<kind>.txt`：标准提示词；`incoming/FX_M_<kind>.txt`：该张实际生成时使用的提示词。
- `incoming/FX_M_<kind>.png`：内置 imagegen 生成的原始 RGBA PNG；同名 JSON 保存原图／提示词／参考图哈希、实际切格和视觉检查记录。
- `godot/assets/vfx/minor_enemy_skills/`：按检查过的源图机械裁切、归一化并打包的运行时图集；危险范围与计时由战斗脚本决定。

```powershell
python art_requests/minor_enemy_skills_v4/build_list.py --check
python tools/build_minor_enemy_skill_art.py --inspect --check
python tools/build_minor_enemy_skill_art.py --check
```

素材由内置 `image_gen.imagegen` 生成，保留真实透明通道。40 张、414 格源图均已检查并接入；5252 项逐招检查、13 套相关回归及 166 张原生截图见 [运行验证](../../artifacts/minor_enemy_skill_art/README.md)。
