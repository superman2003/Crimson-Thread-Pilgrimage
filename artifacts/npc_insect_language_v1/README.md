# 虫语试听与原生验证

`voice-preview.wav`／`voice-preview.mp3` 依次展示守门朝圣者、管渠童子、失聪铁匠柳、沉默读者的短句。

`native/` 包含实际 Godot 4.6.1 的验证数据和三个角色的待机／发声／聆听取样；小图为正常工厂创建的 NPC，大图为对话头像，使用同一套原画和固定裁切。该隔离场景用于检查实际渲染、声音与状态，不代表自然通关或性能基准。

原生专项覆盖所有 25 位 NPC：实际 SFXWorld 混音非零、短句自然结束、发声与聆听切换、全程固定身体变换与头像窗口、重复回调、快速跳句、换人、关闭与角色卸载。声音从实际混音总线取样，测试进程使用 Dummy 输出，避免在桌面外放测试音。

另覆盖真实对话界面的旧章节分支、史迹静默与关闭清理。`verification.json` 逐角色记录混音样本数、峰值、头像尺寸和状态结果。

`validation/` 保存通过的专项与相关回归日志，`summary.json` 汇总退出码和成功标记。原有 NPC 专项退出时仍报告 ObjectDB 警告；新声音专项的两次音频退场检查均为 pending=0。静态测试套件包含预期失败的模拟子进程，汇总以最终退出码为准。

```powershell
python -X utf8 tools/check_npc_conversation_voice_native.py --engine <Godot-4.6.1.exe>
```

素材来源、发音输入、重建方法和每段声音的哈希见[制作记录](../../art_requests/npc_insect_language_v1/README.md)。
