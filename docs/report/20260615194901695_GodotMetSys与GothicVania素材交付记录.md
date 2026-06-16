# Godot MetSys与GothicVania素材交付记录

时间：2026-06-15 19:49:01

## 本轮交付

- 替换主角、敌人、Boss、平台、背景、陷阱、钥匙、机关、Boss 门等运行时素材。
- 接入 `KoBeWi/Metroidvania-System` 插件、autoload、settings、MapData。
- 新增 `MetSysBridge`，把 Demo 房间访问、收集物存储、机关和 Boss 结果写入 MetSys save data。
- 加固重复存储保护，避免重复拾取或读档后再次触发 MetSys `store_object()` 断言。

## 验证结果

- `python .\tools\validate_gothicvania_assets.py`：通过，24 个 Demo 素材、14 个主角动画。
- `python .\tools\validate_background_layers.py`：通过，5 层背景均为 8192x720。
- `python .\tools\validate_level_pacing.py`：通过，宽度 6400、怪物 5、最小间距 700px、仅近战。
- `python .\tools\validate_demo_geometry.py`：通过，首段跳跃台阶可达。
- `D:\Godot\godot.cmd --headless --path .\godot --script res://scripts/metsys_validation.gd`：通过，7 cells、探索 2、注册 5、存储 1、重复存储安全。
- `D:\Godot\godot.cmd --headless --path .\godot --script res://scripts/demo_validation.gd`：通过。
- `D:\Godot\godot.cmd --headless --path .\godot --script res://scripts/combat_validation.gd`：通过，左键攻击、右键 60 能量回血、E 技能、F 交互、怪物近战 AI。
- `D:\Godot\godot.cmd --headless --path .\godot --script res://scripts/inventory_map_validation.gd`：通过。
- `npm test`：通过。

## 运行说明

从工作区执行：

```powershell
D:\Godot\godot.cmd --path .\godot
```

如果屏幕上已有旧 Godot 游戏窗口，需要先关闭旧窗口，再启动上述命令，避免看到旧进程缓存画面。
