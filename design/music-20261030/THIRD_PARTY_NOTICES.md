# 本轮配乐音源来源与许可

以下是本轮 [instrument-manifest.json](instrument-manifest.json) 中列入的音源来源；当前清单 SHA256 为 `675b67fbda3658b61b021286feb8792124c4aba6bb2d89363f0c612865214ce8`，见[引擎冻结记录](engine-evidence/engine-freeze.json)。声道修复与一处圆号短音区域的本地增益修正不改变音源提交、原文件哈希或缓存原件；上游值与本地覆盖均留在清单，逐曲使用情况以渲染报告为准。项目运行音频、冻结分轨与原始采样库是不同材料：原始采样缓存留在仓库外，游戏已接入本轮 70 个混音资产。

| 音源 | 来源及当前固定版本 | 许可记录与用途 |
| --- | --- | --- |
| VSCO 2 Community Edition | [Versilian Studios／VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE)，清单所列 commit `6dd651d55dde97fd4028699be9d4481f26917891`。 | 清单记为 CC0 1.0；用于所列管弦、钢琴及打击采样。上游许可文件与逐样本信息由清单及下载回执保留。 |
| Versilian Community Sample Library（VCSL） | [Versilian Studios／VCSL](https://github.com/sgossner/VCSL)，清单所列 commit `dfcf4a4918771eee884b96ad4493de82ef84daf6`。 | 上游 README 将音源标为 CC0 1.0；具体所用乐器与路径见清单。 |
| FreePats Spanish Classical Guitar | [FreePats 古典吉他](https://freepats.zenvoid.org/Guitar/acoustic-guitar.html)，清单所列 2019-06-18 采样包；归档 SHA256 `ef2fb7de0cc0ab561c4ebc28494f3fc2962596e4f32f16d6c96b8a385c7c098b`。 | 所附说明标为 CC0 1.0；当前作为尼龙弦古典吉他采样。 |
| Karoryfer Fashionbass | [sfzinstruments／Fashionbass](https://github.com/sfzinstruments/karoryfer.fashionbass)，清单所列 commit `0703973b300a6bacb837602be9b588ab64732a72`。 | 上游许可文件为 CC0 1.0；当前用于电贝斯，具体取样区间以清单为准。 |
| Karoryfer Emilyguitar | [sfzinstruments／Emilyguitar](https://github.com/sfzinstruments/karoryfer.emilyguitar)，清单所列 commit `b4920dc662fd9cad6dcaccdeecffdd91c8725d8c`。 | 上游许可文件为 CC0 1.0；当前用于空心电吉他，具体取样区间以清单为准。 |

`actual_name` 表示实际音源，`status` 区分采样、映射和程序合成。西洋长笛不标作中国笛，越南 đàn tranh 不标作中国古筝，映射到管弦低音鼓的 `taiko` 不标作日本太鼓，映射到音乐会竖琴的 `pluck` 不标作中国弹拨乐器。每曲的实际音轨及替代情况以渲染报告为准。

下载程序默认缓存到 `~/.cache/my-game/music-instruments/`，按清单验证 Git blob 哈希或归档 SHA256，并保存本地 SHA256 回执；原始音源库不纳入本仓库。清单当前列有 2,082 个文件、合计 1,860,631,202 字节，实际任务按谱面所需区域选取，缓存占用依已取得文件而不同。CC0 来源的许可与现成参考曲目的旋律、谱本或录音是不同事项；若采用其他现成素材，需分别记录其来源与可用范围。项目其他素材的状态见仓库根目录的 [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)。
