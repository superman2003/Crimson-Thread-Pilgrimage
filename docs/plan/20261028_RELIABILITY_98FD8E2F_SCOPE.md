# 2026-10-28 设置、阅读与音频可靠性：十批升级范围

状态：**十个功能 PR 已提交，本地专项通过；远端 CI 与人工验收分别核对**。本说明最初按用户要求先行公开，防止并行 agent 重复开发；现已回填实际交付登记。说明本身不计入原定十个功能 PR。

## 依据与基线

- 升级依据：[修订方案](../SILKSONG_ALIGNMENT_REVISED_PLAN.md)、[任务台账](../UPGRADE_TASK_LEDGER.md)。沿用原任务编号，不新建替代台账。
- 基线：main `a9457669a4a1a08f885c96c95c80a069d059f7ff`（#415 已合入）。
- 本轮工作标识：`reliability-98fd8e2f`；说明分支：`codex/reliability-98fd8e2f-scope-20261028`。
- 提交前已读取两份开放的认领 PR 及其实际文档：
  - [#416](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/416)，头 `763ec11a583b85cd08918c23b16dec6b0907888a`：十项工作台、训练记录、行程、契约结算、资源与存档总览。
  - [#417](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/417)，头 `109f33377ee0fe72be06e0dd898483158f8ecaeb`：战斗碰撞、时间窗口、钩索、弹反、命中后果与效果生命周期。
- 以下范围避开上述两组已认领生产方法。开放 PR 不能揭示尚未发表的工作；本文件用于公开协调，不宣称已经排除所有并行冲突。

## 十批拟交付范围

下面的现状来自基线生产脚本检查；每项仍须先建立复现或明确新增行为，再实施。发现已有完整实现时，不重复提交：先修订本说明，撤回该项并登记替代范围。

| 批次 | 台账编号与名称 | 已有行为及本轮增量 | 认领文件／方法 | 计划验收 |
| --- | --- | --- | --- | --- |
| R01 | U06 设置无障碍 / T02 存档迁移 | 普通设置已有暂存写入、逐字段回读与待保存提示；补齐替换目标失败、并发暂存命名、安装中断后的可恢复写入协议，保留旧设置字节。此项仅处理偏好文件，不修改游戏存档格式。 | `godot/scripts/settings_persistence.gd`：`save`、`_install` 与恢复辅助；新增 `preference_file_transaction.gd` | 写入／校验／替换逐步注入失败；两个写入者交错；旧文件和已验证候选可恢复；失败不显示已保存。 |
| R02 | U06 设置无障碍 | 设置方案已有预览、当前设置变化检查和先写后应用；将未注入 writer 时的直接临时文件 rename 路径接入与 R01 相同的校验／可恢复协议，统一失败和重试行为。保留现有确认流程，不另造方案 UI。 | `godot/scripts/settings_profiles.gd::apply`；仅必要时调整 `settings_profiles_desk.gd::_confirm` 的错误展示 | 按键、仅画面、仅手柄及全部范围；写入失败时 InputMap／实时画面均不变；重新确认后一次成功应用。 |
| R03 | U06 设置无障碍 | 分享码已有大小上限、版本检查和完整动作校验；本轮针对本地已存方案加载仅检查两层 Dictionary 的边界，增加损坏条目隔离、明确原因及可继续管理的行为，严格校验事件与重复输入，保持合法历史 build_menu 迁移。 | `settings_profiles.gd::configure`、`quote` 的输入边界；`settings_profile_codec.gd::decode`、`restore`；`settings_profiles_desk.gd` 的损坏条目展示 | 混合好坏方案、未知事件／字段、重复输入、旧版合法记录；好方案仍可用，坏方案不静默覆盖原文件或变成有效默认方案。 |
| R04 | U06 设置无障碍 | 已有三秒中立漂移测量、最少样本、设备切换取消与建议暂存；深化失焦、暂停、断连重连与短间隔重复采样下的测量归属，避免过期建议作用到另一次测量。 | `stick_calibration.gd`；`controller_comfort_dialog.gd` 的采样、测量开始／暂存及窗口生命周期；必要时 `controller_preferences.gd::devices` | 两设备切换、同编号重连、失焦后恢复、重复开始／暂存、低采样率；确认前不改 InputMap 或原死区。 |
| R05 | U06 设置无障碍 / U02 契印装备UI | 已有最后有效输入、设备专用绑定选择和断连退回；补齐修饰键鼠标组合的完整提示、物理／逻辑键标签边界以及多个绑定的确定选择，使提示与实际绑定一致。 | `input_prompt_bindings.gd::binding_label`、`action_label`；只在需要时调整 `observe` 的有效事件判断 | Ctrl／Shift／Alt／Meta 加鼠标、物理与逻辑键、无绑定、设备专用与通用手柄绑定；不改输入冲突政策或实际动作绑定。 |
| R06 | U05 旅记与对话 | 已有显示全文、上下翻页与进度；补齐重复 configure、正文／滚动容器被释放、重排与长文本下的阅读控件重绑定和边界，不让全文展示触发交谈推进。 | `dialogue_reader.gd::configure`、`refresh`、`turn`；新增阅读视口辅助 | 同控件重复配置不叠加按钮／回调；字号与宽度改变、空文、长文、容器退役；翻页／全文不写故事、奖励或存档。 |
| R07 | T02 存档迁移 / U05 旅记与对话 | 旧旅途已有分页、只读详情与源哈希核对；深化浏览 UI 对异常查询返回、非 Dictionary 条目、越界页和详情失效的隔离，保留可读记录与原关闭退路。 | `journey_history_browser.gd::request_page`、`select_entry`、`open`；新增归档页面输入适配辅助 | 好坏条目混合、空／异常回调、页数变化、详情失效和重复打开；不恢复、删除、修复或覆盖归档文件。 |
| R08 | U03 战斗HUD / U06 设置无障碍 / T03 性能与生命周期 | 危险字幕已有仅观察真实前摇、遮挡过滤、分组与有界轮询；缓存样式／字号更新，补齐重复 setup、旧 UI 退役和关闭字幕后的显示清理，避免每帧重新分配样式或保留失效控件。 | `danger_captions.gd::setup`、`refresh` 与控件生命周期；必要时 `danger_caption_groups.gd::render` | 稳态复用同一样式；开关／字号／对比度变化及时更新；重建／退役后无重复面板；原观察条件、排序及扫描上限不放宽。 |
| R09 | S01 音乐叙事 / T03 性能与生命周期 | 已有探索续播、战斗层、Boss 与摇篮曲互斥；对资源缺失／加载失败建立可回退的音乐状态切换，避免先设置激活标志或暂停探索后无法成功进入目标曲，保留后续重试。 | `audio_director.gd::start_boss_music`、`set_boss_phase`、`start_lullaby` 及对应恢复辅助；新增 `music_transition_commit.gd` | 缺失 Boss／阶段／摇篮曲、重复请求、失败后重试及交错退出；不得误停仍有效曲目，旧回调不得停止新播放。 |
| R10 | S03 环境混音 / S02 角色战斗音 | NPC 声音地标已有距离衰减、触发时射线遮挡（12 dB）、危险提示抢先与失效源退役；本轮增加短播放期间源／听者移动和门体变化的有界空间更新，保持原声音地标发现规则。 | `audio_director.gd::play_npc_landmark`、`_retire_invalid_landmarks`；`spatial_enemy_alert.gd` 的可复用空间刷新接口；新增 `landmark_spatial_refresh.gd` | 同世界源／听者移动、门开启／关闭、跨世界／隐藏／释放及危险提示中断；空间检查有预算，不新增看不见 NPC 的文字、ID 或坐标提示。 |

表内未带目录的生产脚本均位于 `godot/scripts/`。表外生产文件不视为被本轮认领。

## 文件与提交协作规则

1. 本说明 PR 只新增本文件，不修改共享总台账、计数器、默认回归清单或其他 agent 分支。
2. 功能分支统一使用 `codex/reliability-98fd8e2f-rNN-*`。每批新增验证／运行器／工作流／报告分别使用：
   - `godot/scripts/reliability_98fd8e2f_rNN_validation.gd`
   - `tools/run_reliability_98fd8e2f_rNN.py`
   - `.github/workflows/reliability-98fd8e2f-rNN.yml`
   - `docs/report/20261028_reliability_98fd8e2f_rNN.md`
3. R01 → R02 共用偏好写入协议；R02 → R03 共用设置方案模型。按该依赖顺序串接并注明前置，不能把继承改动重复计作本批新增。其余批次尽量独立基于最新 main。
4. R09 → R10 按 #447 → #448 串接，只认领表列音乐切换和 NPC 地标方法，不认领整个 AudioDirector；保留既有房型混响交接、用户音量事务、全局声部预约与敌人危险声规则。
5. R01 为实现启动读取前恢复，额外仅接入 `pilgrimage_interface.gd::_load_accessibility` 的恢复调用两行，已在 #438 和报告登记；不修改其余界面方法。不触碰 #416 的十项生产文件／新增模块，或 #417 的 Player、Enemy、扫掠与攻击效果方法。也不重写 `main_level.gd`、`build_system.gd`、`world_state.gd`、剧情 JSON、地形、角色和音频素材。
6. 每个功能 PR 发布前重新读取 main、开放 PR 与实际变更文件；同文件不同方法也必须检查 diff。遇到重叠时先在本说明更新边界，不能覆盖或强推其他 agent 的工作。共享新函数优先拆入本轮独立辅助脚本。
7. 不整体格式化公共文件，不删除原验证，不放宽 CI／资源错误门禁，不合并或关闭任何 PR。说明和功能 PR 都保留供用户审查。

## 完成与验证边界

每批须包含实际生产行为、针对生产方法的正常／异常边界回归、适用的已有回归复验和独立报告。失败注入应证明确实拒绝坏路径，不能仅测试新辅助函数自身。

偏好写入、控件、InputMap、音频和物理射线分别按实际涉及范围验证。Godot 版本、输入 SHA、已运行命令、失败与未验证部分逐 PR 如实记录；文件数、行数、断言数均不替代功能验收。

本文件首发时仅登记范围；当前实际验证结果见下表及各功能报告。实体手柄、中文长文实读、耳机／扬声器听感、自然六区全流程和最终发行包仍待分别验收；不关闭 46 项最终任务。十个功能 PR 另行提交，本说明不会冒充其中一项。

## 实际交付登记

说明 PR #419 不计入以下十个功能 PR。实施基线为 main `63981173d0a357c4dc0249d2d8bb0f5546522f43`；依赖批次另从其前置功能头开始。没有合并或关闭任何 PR。

| 批次 | 功能 PR | 本地 Godot 4.6.1 专项 |
| --- | --- | --- |
| R01 | [#438](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/438) | 26 项通过 |
| R02 | [#439](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/439) | 23 项通过 |
| R03 | [#440](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/440) | 21 项通过 |
| R04 | [#442](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/442) | 11 项通过 |
| R05 | [#443](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/443) | 12 项通过 |
| R06 | [#444](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/444) | 10 项通过 |
| R07 | [#445](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/445) | 9 项通过 |
| R08 | [#446](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/446) | 7 项通过 |
| R09 | [#447](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/447) | 11 项通过 |
| R10 | [#448](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/448) | 11 项通过 |

#438 → #439 → #440，以及 #447 → #448 为依赖链；其余独立面向 main。R01 另复验旧文件系统检查 33 项；R02/R03、R09/R10 的组合回归已分别记录。R10 组合复验发现运行器漏拷新依赖并修复，未删减旧断言。R08 本地只验证实际生产显示层，不冒充完整 Enemy/World。远端 CI 状态须按每个 PR 的最新 head 查询，本地结果不回填为远端通过。最终自然流程、实体设备、声音实听和发布包仍待验收。
