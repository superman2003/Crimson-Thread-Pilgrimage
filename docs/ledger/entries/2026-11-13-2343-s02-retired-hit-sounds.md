## 2026-11-13：音效清单把两条被取代的命中音标为退役（S02）

`player_attack_hit_light`／`player_attack_hit_heavy` 自 07-26 起被按敌人材质分级的命中音取代，但清单里仍标着“有素材未接线”，每次盘点都被当成待办；备注里“仍加载在敌人音效表里”也已不符合代码（运行时已无任何引用）。

- 清单校验新增 `retired` 状态：必须写退役原因、不得再带接线字段、运行时代码不得再引用该文件。
- 两条命中音改为 `retired`。清单里真正“有素材未接线”的只剩断弦温室第 2 拍（等花粉风机制）。

验证：`validate_audio_visual_manifest.py` 通过（wired 164、asset_ready 1、retired 2）。
