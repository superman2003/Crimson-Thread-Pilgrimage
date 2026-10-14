# 六章 Boss 材质分层候选：从寂冠核心倒推

本批是 **24 个原创音频候选 + 7 个试听文件**，不是运行时已接入版本。音源、生成器、报告完全隔离在三个 `proposals/reverse_audio` 目录中。没有修改 Godot、现有生成器、验证脚本或 CI。

## 为什么补这一层

已阅读 `docs/spec/20260726160400000_音效与音乐设计规格.md`、音频优化收尾清单、`tools/generate_sfx_pack.py`、`tools/generate_ambience_pack.py`、`audio_visual_manifest.json`，并只读检查 `enemy_actor.gd` 的挂点。

现有六章环境音、音乐和 Boss 轻/重攻击已存在，因此本批不重复交付六条通用 drone。具体缺口是：前摇使用共享 `boss_windup_light/lethal`；非致命 Boss 受击使用重甲档；现有重攻击将 whoosh、主体、材质录在同一文件内，主体在约 0.30s 出现。本批提出六区身份预警、**以触发时刻为冲击原点**的攻击主体/材质分轨和短受击音，供下一轮做受控 A/B。

`baseline_audit.json` 来自真实水合 OGG，不是 LFS 指针。检查了两种共享预警及六章重攻击，均非静音。原重攻击约 1s；此次短板是可分层控制和身份识别，不是声称旧包全部不可用。基线和候选响度并未匹配，不能拿试听音量直接判优劣。

## 听什么

打开 [audition.html](audition.html)，或播放 `assets/proposals/reverse_audio/audition/reverse_ch06_to_ch01.ogg`。网页只使用本地相对路径，不联网。若浏览器限制本地音频，可在仓库根目录用 `python -m http.server 8000` 后访问对应 HTML。

48 秒总试听按 CH06→CH01；每章 8 秒。每章内部：0.25s 预警、1.50s 攻击主体独奏、2.75s 材质独奏、4.00s 两轨同步叠加、5.50s 受击。总试听不另做归一化，保留单素材增益。详细 cue sheet 在 `manifest.json`。24 个 stem 为 48kHz、单声道、PCM16 WAV；7 个试听为 OGG Vorbis q5，采用相同增益混合后编码，解码误差会轻微改变峰值。

| 顺序 | 区域 | 原创合成材质 | 交付 stem 前缀 |
|---|---|---|---|
| 1 | 寂冠核心 | 制止的近音簇、向内压强、短暂凹口 | `ch06_` |
| 2 | 黑曜巡礼路 | 闷壳行军感、低频重量、灰粒 | `ch05_` |
| 3 | 断弦温室 | 弦纤维瞬态、木裂、两段回弹 | `ch04_` |
| 4 | 盐白档案馆 | 非整数盐晶泛音、纸粒、离散碎屑 | `ch03_` |
| 5 | 铸雨渠 | 不协和铁片、水压噪声、细雨尾粒 | `ch02_` |
| 6 | 苔钟庭 | 闷青铜、摩擦噪声、非整数共鸣 | `ch01_` |

每章都有 `warning`（0.60s）、`attack_body`（0.90s）、`attack_detail`（0.90s）、`hurt`（0.46s）。这里的“六 Boss”沿用项目的六章 Boss 分组，不声称为全部 20 个概念 Boss 定制。

## 来源、参数、授权

全部声音由本目录 Python 工具从正弦振荡器、调频、带通伪随机噪声、指数包络及粒子延迟合成；没有外部采样、现成音色库、人声、第三方游戏录音或旋律复刻。新合成音频按 CC0-1.0 提供，既有资产授权不受影响。逐音 seed、频率、泛音比、噪声频带中心和目标峰值见 `manifest.json`，完整 DSP 参数以 `build_pack.py` 为准。

预警共享两击节奏（0 / 0.17s）维持语义，再由材质形成章节差异；没有使用安全钟的完整旋律。主体和材质同采样率、同长度、同起点，**没有各自插入不同预延迟**。素材不含长混响，不模拟人声。“晶体/木/水”等是合成设计意图，尚未经过玩家听辨确认。

## 复现与验证

依赖 Python 3.10+、NumPy、SciPy、ffmpeg。执行：

```bash
python tools/proposals/reverse_audio/build_pack.py
python tools/proposals/reverse_audio/build_pack.py --verify-only
# 可选：对已有水合原始资产重新审计，仅读取输入目录
python tools/proposals/reverse_audio/audit_baseline.py /path/to/godot/assets/audio
```

`build_pack.py` 只向本批三个目录写入；默认重生成候选/试听/manifest/HTML，再验证。`--verify-only` 不改 WAV，只重新测量报告。此次环境 NumPy 2.3.5、SciPy 1.17.0；具体 ffmpeg 版本记录于报告。确定性承诺是相同环境中的 PCM 一致性，跨库版本浮点差异需重核 SHA-256。

当前 `validation.json`：**31/31 文件通过，24/24 stem 固定种子重建与 PCM 逐样本一致**。每项提供文件哈希、时长、sample peak、4×重采样 true-peak 估计、ffmpeg true peak、积分 LUFS、RMS、DC、数字零占比、−60dBFS 首尾静音长度、削波样本数和首尾值。检查还包括 6 对主体/材质叠加峰值。

- 全部文件 0 削波样本；全包 ffmpeg 测得最高 true peak 为 −6.82 dBTP，保留叠加空间。
- 单 stem 峰值目标：预警 −9、主体 −10、材质 −16、受击 −13 dBFS；并非统一响度目标。
- stem 约 0.3–1.3ms 内超过 −60dBFS；首尾样本为零。试听中的空白是有意分隔，不记作素材静音缺陷。
- 短瞬态的积分 LUFS 受门限与长度强烈影响，记录它不等于用它决定混音。低于 −60dBFS RMS、true peak 高于 −3 dBTP、削波或重合成不一致会失败。
- **所有素材 `loop=false`**，无循环资源，不使用“首尾为零”冒充无缝循环验证。Godot 导入必须关闭循环；试听 OGG 同样不循环。

以上是文件和信号层检查，**没有完成耳机/音箱实听、游戏内掩蔽、空间衰减、玩家听辨或操作公平性验收**。

## 给运行时整合者的挂接清单

本表只是下一批实施清单，未修改任何以下运行时文件。

| 候选 | 已有逻辑位置（只读核对） | 整合方式与限制 |
|---|---|---|
| `chNN_warning` | `enemy_actor.gd::_play_attack_sfx("windup")` | 先作为章节身份的低增益附层试验；保留共享轻/致命危险档语义。不要直接覆盖 lethal，也不要让 0.60s 文件长度改变实际前摇。前摇短于素材时应取消/淡出，不能让残留提示拖进下一招。 |
| `chNN_attack_body` + `chNN_attack_detail` | `_play_attack_sfx` 的 Boss active 分支、`_boss_sfx_key` | 两轨同帧触发于真实攻击/冲击事件，unity 叠加作为离线参考；游戏先各降低 6dB 再实听。不能在保留原完整 heavy 文件的同时无条件再叠两轨。原 heavy 约 0.30s 后才有主体，这批立即有冲击，必须逐招核对动画与 hitbox 时间。 |
| `chNN_hurt` | `take_hit` 的非致命 `_hit_tier_key()` 分支 | 仅 Boss、确认造成伤害、非终结一击时做替换式 A/B。保留 `hit_kill`；多段攻击需并发预算/短间隔合并，避免连续短爆音。 |
| 全部 | 现有 SFXEnemy → SFX 总线路由 | 本批 mono 适合现有 2D 定位；不自带空间化。加混响后重新测叠加峰值和可懂度，不用提升 Master 掩盖问题。 |

特别注意：ch02 已叠 `ch02_beat_water_hammer`，ch05 已叠 `ch05_beat_silent_order`。A/B 时必须计入这些层，避免水浪和预警叠重。CH06 的相变/三乐章音乐不在本批范围。不要把文件所在仓库根路径直接写成 Godot `res://`：候选尚在项目外，批准后才复制到项目音频目录、分配新 key、更新 manifest 和导出包含规则。清单状态只能标 `proposal_not_wired`，不能标 `wired`。

## 尚需人工验收

1. 低音量下是否能分辨预警与受击；盲听六章身份（尤其苔钟/寂冠与盐晶/断弦的混淆）。先在匹配听感响度后比较旧/新。
2. 在每章实际 BGM、环境床、原生额外 beat、快速连续攻击下，是否清楚且不刺耳；耳机与小音箱分别验收。
3. 逐招确认预警开始/结束、攻击落点、受击时刻，不因音尾提示错误闪避窗口；暂停、离房、死亡、取消攻击时不遗留预警。
4. 主体/材质层可独立调低，混响与定位后再查峰值；慢机并发下不偷掉危险预警。验证通过后才能决定是否把音源复制进运行时。
