# CH05 灯影相位练习工房

`upgrade_lantern_phase_3` 仍是 pilgrim camp 的可选练习支路，保留原房间坐标、地图矩形、相位闩、双向入口和原有两项奖励。开启下层闩门后，玩家需先跳上检修低台，再登上灯廊高台取得操作手册与松脂；从高台落回地面即可沿原门返回营地。房间提示说明了台阶顺序和安全折返路线。

布局仅针对这一个房间。`tools/build_world_upgrade.py` 从 `world_routes.json` 的 `workshop_layouts` 配置生成两块平台，并把现有奖励挂到高台；重复运行生成器应得到相同配置。其余 19 个能力工房继续使用原布局和各自的移动组合。

验证：`npm run test:campaign` 检查战役数据、路线和升级结构；`npm test` 覆盖游戏数据、运行时 smoke、活动地图几何及回归 runner。Godot 的 `obsidian_experience` 套件还会用生产版 World、Player、相位闩和碰撞平台，实际执行开闩、两级跳台、领取奖励和返回营地。该测试只预置已取得的灯影相位；两个台阶均应可用普通单跳抵达，不依赖双跳。它不模拟首次获得能力的主线流程。
