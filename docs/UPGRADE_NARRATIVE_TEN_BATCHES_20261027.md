# 2026-10-27：世界观与剧情十批升级

基线 main a559a1b8。十个 PR 按前后基底串接；每批只统计自己的差异，禁止把继承内容重复计数。现有 #405 的规范统一、人物重逢与结局确认保持独立，本轮以证据驱动的可选追问推进剧情理解。

| 批次 | PR | 主题 | 非文档改动 | 全量专项检查 |
| --- | --- | --- | ---: | ---: |
| 01 | [#406](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/406) | 追问系统、保存与旅记 | 764 | 65 |
| 02 | [#407](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/407) | 苔钟庭的承诺与归途 | 495 | 233 |
| 03 | [#408](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/408) | 雨渠的身份与工坊生活 | 495 | 401 |
| 04 | [#409](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/409) | 书库的改字证据链 | 495 | 569 |
| 05 | [#410](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/410) | 温室的养护与控制 | 495 | 737 |
| 06 | [#411](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/411) | 军册、灯号与返乡 | 495 | 905 |
| 07 | [#412](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/412) | 冠核的总锁与决定权 | 495 | 1073 |
| 08 | [#413](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/413) | 五条可选支线的人物动机 | 495 | 1241 |
| 09 | [#414](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/414) | 主角身份与能力成长 | 500 | 1409 |
| 10 | 当前 PR | 三结局后果与回访边界 | 513 | 1587 |

合计非文档改动 5242 行，平均 524.2 行。再剔除 CI 53 行及 UID 3 行，代码、测试与运行时数据仍为 5186 行，平均 518.6 行。内容不是格式重排：新增 128 组实际交互问题、512 段基础及追加回答。每个问题的题面、人物台词、主角手记、证据来源和追加条件均接入实际交谈与旅记。

## 解锁与交付

六章问答以实际证词和已观察设施为基础，战后追加回应。支线动机在接下请求时开放，完成后回应关系变化。主角身份追问依据实际能力与设施，持有证词后追加理解。终局问答仅属于已选择的分支，并与相关支线完成状态交叉回收。

关闭回答不提交；读完并成功保存才写入人物旅记。后续证据不自动改写旧记忆，须重新阅读追加版本。来源与回答指纹变化、离开人物、父交谈隐藏、切区、死亡、保存失败与重复确认均有明确检查。

## 证据与范围

每批数据校验和 Godot 4.6.1 严格无头专项均通过，检查数为该批全量状态而非相加成果。最终正式 World UI 集成、原叙事 9798 项、npm test、campaign 通过；初始两轮严格导入通过。远端检查以精确 PR head 为准，已观察系统及多个内容批次专项成功，其余仍可能排队。

#405 与本轮 HEAD 的 merge-tree 无冲突，不等于已合入该 PR。自动组件及真实控件验证不替代原生画面、实体控制器或自然流程验收；N01–N05、T04 最终项继续开放。各批详情见 docs/report/20261027_story_01.md 至 story_10.md。
