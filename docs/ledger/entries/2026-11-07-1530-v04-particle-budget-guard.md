## 2026-11-07：粒子节点须走战斗视觉预算（V04）

- **核对**：V04 的下一交付列着“其它粒子预算”。核对后，游戏运行时的脚本和场景里没有任何 `GPUParticles2D`／`CPUParticles2D` 节点，全部特效都是经 `combat_visual_policy.attach_secondary` 记账的 Node2D 装饰（总量 24、动作／状态／环境分项限额）。所以眼下不存在预算外的粒子。
- **守门**：新增 `tools/audit_particle_budget.py`，已接进 `npm run test:campaign`。它扫描 `godot/` 下全部运行时文件（脚本、场景、旅途功能、插件），只豁免 `*_validation.gd` 和 `godot/tests/`；场景文件不论叫什么名字都不豁免。规则：
  - 场景里不允许放粒子节点；
  - 脚本只能用 `var 名 := XParticles2D.new()` 构造粒子，注释、字符串和类型标注不算构造；
  - 这个变量必须交给 `attach_secondary` 记账；
  - 必须显式设置 `名.amount`，且不超过 24。预算按节点计 1 个单位，不看发射量，所以另加这条上限。

  自检覆盖了上面每一种情形。
