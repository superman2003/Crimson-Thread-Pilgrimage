# U01：原生确认与旧旅途窗口统一主题

设置、行囊的自绘按钮已有墨青／铜线主题，但共用 Theme 只给原生 Button 设置正文颜色，导致新旅途确认、取消及旧旅途返回按钮仍使用默认样式，窗口标题栏也保留默认灰色；旧旅途 RichTextLabel 正文未指定统一骨白色。

本批在 pilgrimage_interface 的共用主题中补全 Button 的正常、悬停、按下、禁用与焦点状态，使用已有墨青、骨白、铜线和绯红色板、17px 按钮字号。原生按钮没有自绘铜线，因此将焦点边线明确放进 StyleBox。Window 标题沿用已有中文标题字体，嵌入窗口底色改为墨青、细铜外缘，保留引擎标题、关闭按钮和窗口边距几何；RichTextLabel 默认色统一为骨白。没有改写控件交互、存档或关卡数据。

## 实际画面与检查

使用真实 World、真实 ConfirmationDialog/AcceptDialog 控件，私有 ui_redesign_validation.json 存档路径；只打开窗口、聚焦取消并关闭，没有点击开始新旅途或恢复存档。旧旅途长正文截图使用明确标注的重复阅读展示文字，不冒充自然游戏记录。

已打开核对 1280×720 和 960×540 四张最终截图：新旅途确认／取消及关闭按钮均在视口内，取消焦点为铜线；旧旅途正文在滚动区内，返回与关闭按钮不被长文字覆盖。未进行实体手柄体验。

[小屏修改前](../../artifacts/u01_dialog_theme/final_before_native/captures/new_journey_960x540.webp) · [小屏修改后](../../artifacts/u01_dialog_theme/final_after_native/captures/new_journey_960x540.webp) · [长文旧旅途](../../artifacts/u01_dialog_theme/final_after_native/captures/old_journey_960x540.webp) · [1280长文](../../artifacts/u01_dialog_theme/final_after_native/captures/old_journey_1280x720.webp)

最终同夹具、同 runner，仅回退共用主题生产修改，原生 GL 六项预期断言失败，退出 1，零 warning；恢复主题后 57 项通过，退出 0、零 ERROR/warning，前后源码均冻结一致。最终 CPU 六套 ui_redesign、ui_text_order、global_font、settings_remap、ui_world_integration、save_product 全部通过，零 ERROR/warning，冻结一致。每进程上限 180 秒。

较早按钮主题候选的 native 六套均无游戏断言失败，但 ui_text_order、global_font、ui_world_integration 各出现一条未归因 ObjectDB 退出 warning，严格 runner 将整轮判失败，原始日志保留；没有父提交同套对照，故不称它们为旧问题，也不把本 U01 视觉修改当成资源退出修复。最后两轮只重跑了 ui_redesign 真控件截图，没有冒称最终 native 六套全绿。

ui_text_order 继续守护先入树再设文字，标题图仍使用原有共享缓存；本批没有增加树外文字排版或重复解码。默认回归套件数不变，新增检查接入已有 ui_redesign。日志、失败候选、源码快照和 gzip mtime0 原文／归档 SHA256 清单均在 artifacts/u01_dialog_theme。

范围为共享原生弹窗组，地图弹窗和其它使用 Theme 的控件继承样式，但未逐个截图验收。其余页面间距、全部字体设置、所有长文本与实体手柄完整体验、46项最终清单仍 OPEN。PR 基于 #197，目标 main，未合并依赖。

审查补丁：主题里 `Button` 条目会先于引擎默认的 `CheckButton` 条目被查到，设置页无障碍开关因此被连带改成墨色方框。现在把 CheckButton 的各状态样式固定回引擎默认，`ui_redesign` 新增设置开关 normal／hover／pressed／focus 断言；去掉补丁时这 16 项失败，加上后 70 项通过。
