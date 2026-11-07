## 2026-11-07：粒子节点须走战斗视觉预算（V04）

- **核对**：V04 的下一交付列着“其它粒子预算”。核对后，游戏运行时的脚本和场景里没有任何 `GPUParticles2D`／`CPUParticles2D` 节点，全部特效都是经 `combat_visual_policy.attach_secondary` 记账的 Node2D 装饰（总量 24、动作／状态／环境分项限额）。所以眼下不存在预算外的粒子。
- **守门**：新增 `tools/audit_particle_budget.py`，已接进 `npm run test:campaign`：
  - 运行时场景（`.tscn`）不允许放粒子节点；
  - 运行时脚本只有同时交给 `attach_secondary` 记账时，才能创建粒子节点；
  - 校验脚本不受此限。
  自检覆盖了上面四种情形。以后加粒子必须先进预算，否则 CI 失败。
