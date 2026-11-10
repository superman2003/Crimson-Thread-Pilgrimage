# NPC 原创虫语“绯鸣”

采用偏口语的含混呢喃，中文对白承载含义。已有 25 位 NPC 各有 6 段短句，共 150 段；每个角色固定基音、共鸣位置、气声、粗粝度及语速。同一个人的音色保持一致，孩子、老人、铁匠、学者和回声角色分别处理。

`design.json` 是完整制作输入，`tools/build_npc_insect_speech.py` 离线合成带元音共鸣、辅音起音、呼吸和词间停顿的 PCM WAV。全部声音为原创程序合成，未采样其他游戏或演员；运行时播放已导入的短句。

短句骨架：

- 招呼：`ki-ru · ma`
- 叙述：`tra-li · mu-ra-ki`、`sha-mu · ri-to`
- 询问：`ti-ri · ka?`
- 安抚：`mu-la · sha-ru`
- 警示：`kra-tik · ra`

台词标点及语气选择短句，句子散列提供轻微声调差异。发音按照短句组织；字幕有自己的逐字和阅读进度。旧段落恢复阅读时不重复打断，快速换句会结束上一句，关闭、换人或卸载角色时结束其发声。

`godot/data/npc_insect_language.json` 记录每个文件的 SHA-256、样本数、时长、音节位置和电平；WAV 为 22,050 Hz、单声道、16 位，便于审查和重建。声音使用既有 SFXWorld 总线和全局声部预算，沿用音效音量控制与对白混音。

重建与检查：

```powershell
python -X utf8 tools/build_npc_insect_speech.py
python -X utf8 tools/build_npc_insect_speech.py --check
npm run test:npc-dialogue-voice
```

游戏内状态为待机、招呼、发声和聆听。复用现有 25 位 NPC 的 400 帧原画：通常为待机 4 帧、交谈 8 帧，灯影修女为 6／6 帧；另各有招呼 2 帧、休息 2 帧。聆听使用安静待机原画，发声使用交谈原画。动画与头像使用相同的原画帧；角色根变换和头像裁切窗口固定。

发声时钟来自真实音频播放位置，不把整段阅读时间当成持续交谈。听感、口音和自然衔接可结合[试听与原生记录](../../artifacts/npc_insect_language_v1/README.md)评估。
