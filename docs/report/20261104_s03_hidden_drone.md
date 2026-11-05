# W04／S03：走进隐藏房间时，环境里多一层黑潮低鸣

2026-11-04。八条隐藏路线（W04）的隐藏房间，在声音上和普通房间完全一样。音乐包里早有一段专为隐藏区生成的循环低鸣 `hidden_black_tide_drone`（混音档位里也预留了 `hidden_black_tide: L-2`），清单却一直写着“隐藏区环境切换未实现，没有调用”。

## 改动

- `AudioDirector.set_hidden_zone(active)`：
  - 进入隐藏房间时，在 Ambience 总线上用 1.5 秒把低鸣淡入到 -12dB；离开时 1.2 秒淡出并停止。
  - 一直待在隐藏房间里不会重新开始播放。
  - 区域切换（`begin_chapter_transition`）时一并停掉，不会带进下一个区域。
  - 退出场景时，播放器和渐变与其他循环一起释放。
- `main_level._update_room_visit` 在房间变化时，用 `_is_hidden_room` 判断当前房间是否在路线数据 `hidden_route_plan` 里，再通知 AudioDirector。这里不用房间的 `kind` 字段，因为八个隐藏房间的 kind 有 secret、reward、overlook 三种，不统一。
- 清单中 `hidden_black_tide_drone` 改为 `wired`。

## 验证

新套件 `hidden_drone`，共 14 项检查：

- 用正式 AudioDirector 检查：低鸣挂在 Ambience 总线上；是循环播放；淡入到目标音量；停留时不重新开始；离开后淡出并停止；区域切换时也会停掉。
- 在正式 World 中检查：起始区域路线数据里的每个隐藏房间都被识别为隐藏，对应的入口房间不会。

以下相关套件本地通过：

- `hidden_routes`、`audio_landmarks`、`audio_retirement`
- `world_host`、`ending_aftermath`、`ch06_workshop_experience`

软件 GL 下新套件约 11 秒。

## 边界

- 低鸣的音量与听感需要实机试听（S03）。
- 只叠加一层持续音，没有对隐藏房间的混响或滤波做额外处理。
