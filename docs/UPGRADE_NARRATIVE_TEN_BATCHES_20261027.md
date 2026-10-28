# 2026-10-27：叙事重设计与提交顺序

本轮将主线与结局 #405 纳入同一串提交，按 #405 → #406 → … → #415 合入。继承的内容不算后续 PR 自身新增。设计依据见 [NARRATIVE_REDESIGN.md](NARRATIVE_REDESIGN.md)。

验收围绕能复述的故事、角色的不同处境与真实交互，不再以每批 500 行、固定 14 问或断言数量衡量质量。重复追问已合并：当前 85 组、343 句基础与追加回答；原 128 组快照独立归档，只恢复旧存档已确认的版本。

- [#405](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/405)：寻找阿禾的主线、五条支线的关键交谈、九则亲历手记与三种结局尾声。保留六证任意顺序、原任务与结局规则。
- [#406](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/406)：两组开场追问，旧稿记忆兼容与新版重读。旧稿不进入问题列表，已确认的旧版和新版记录能共存。
- [#407](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/407)：钟庭八问，针、后门、回程台阶与两次刻痕。
- [#408](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/408)：雨渠八问，阿禾的铆钉、孩子的消息与工头留下的空位。
- [#409](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/409)：书库八问，书记署名、叶开柜、读者的小注与改约手法。
- [#410](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/410)：温室八问，徽的停拍、园丁的拖延与囚徒先站稳的左脚。
- [#411](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/411)：黑曜道八问，替人应声的骑士、误补灯号的修女与离队后仍站直的旗手。
- [#412](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/412)：王冠八问，各自不能替代的原件、未写明的来者与不替人签字的空位。
- [#413](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/413)：支线十问，请求者自己的责任、说清的交易、未被承诺的原谅与完成后不用交货的相见。
- [#414](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/414)：身份十一问，从今天的手腕、影门与停步出发；不凭熟练动作编造师承和身世。
- [#415](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/415)：结局十四问，以领扣、后半夜、第三桶水与撤签，呈现三种选择后仍要面对的生活。

## 本轮验证

逐批来源检查与 Godot 4.6 原生隔离夹具通过；最终累计 1078 项，覆盖当前追问的解锁、逐句确认、基础与追加记忆、保存回滚及归档兼容。静态主线/结局校验与导出内容审计通过。

隔离夹具使用实际 GDScript、数据、控件与存档代码，但不载入完整 World 及其美术资源。4.6.1 全世界 CI 的结果应在每个 PR 的最新提交上核对。本文不沿用旧稿“全量 UI / 9798 项 / npm / campaign 全通过”的声明作为改稿后的证据。

自然游玩、陌生玩家理解、实体手柄与最终环境演出继续开放。任务完成不会凭尾声复活阿禾，未来维修计划也不等于已经接入新的物理场景。
