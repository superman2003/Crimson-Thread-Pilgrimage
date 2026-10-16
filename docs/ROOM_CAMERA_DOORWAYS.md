# 窄入口的房间镜头切换

基线：main / 64ec26851e6d664b54d14bf4347cadb4a9d4cfe6。

进入下一房间原先统一把触发矩形内缩 24px。宽或高不超过 48px 的细长触发区因此没有可进入的内部，周围大厅的镜头会一直保留。现在两个轴分别采用 min(24px, 该轴长度的四分之一)，窄区也保留中间一半作为明确进入区域。

普通房间仍使用原有 24px 进入门槛；退出仍保留原有 24px 容差，镜头限位仍渐变，Boss 高优先锁与区域重建逻辑不变。未修改触发区、路线、碰撞或玩家坐标。

新增 room_camera_doorway_validation.gd，接入 first_court_experience 现有入口：32×400、400×32、48×48、8×8 的中心进入、入口边缘、离开回滞和渐变，以及清理，共 25 项。夹具只验证生产选择器与限位，实际摄像机与章节行为由既有回归覆盖。

Godot 4.6.1 / llvmpipe：first_court_experience 216/0、camera_focus 86/0、ch06_workshop_experience 通过；严格双轮资源导入通过。既有 ObjectDB 退出警告仍保留。完整远端 CI 以 PR 最终提交为准。
