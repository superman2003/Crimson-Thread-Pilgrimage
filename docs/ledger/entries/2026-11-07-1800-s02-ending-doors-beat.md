## 2026-11-07：结局门现形时响起结局门和声（S02）

- **问题**：清单里 ch06 第 3 拍“结局门”（钟声／断弦／绯线和声）早已生成，却一直没有触发点。最终 Boss 倒下后，三扇结局门是无声出现的。
- **修改**：`main_level._spawn_ending_gates(announce)` 在最终 Boss 倒下这条路径上传入 `true`，三扇门现形时播放一次这段和声。重访已完成的区域时，门照旧无声恢复。清单中该条目改为 `wired`，`implemented_in` 写明出处。上一批加的清单校验在改清单之前就报出了这处不一致。
- **验证**：新套件 `ending_doors_beat` 用正式 ch06 关卡，把关卡脚本换成只记录声音请求的探针子类，检查：
  - 最终 Boss 倒下前没有门，也没有和声；
  - 倒下后出现 3 扇门，和声响 1 次；
  - 再次触发倒下或生成请求，不会重播；
  - 重访恢复门时不响。

  7 项全部通过；去掉 `true` 后有 2 项失败。`ending_aftermath`、`narrative_closure` 照常通过。
- **旁注**：`audio_visual_validation.gd` 不在 CI 套件列表里，在 main 上也会在“start platform exists”处报错并卡住，是一个失效的旧套件，这次没有改它。
