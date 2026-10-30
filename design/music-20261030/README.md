# 全作通用与白门楼配乐

本目录保存全作通用与白门楼配乐的谱面、音源清单、构建与验证工具。38 首主体、8 个替代编曲和 24 个短提示，共 70 个混音资产，已生成并接入游戏；它们合计约 75.32 分钟，不是 70 首主体曲。范围和当前进度见[实施记录](../../docs/implementation/2026-10-30_通用与白门楼配乐制作.md)。工程检查已完成，完整主观听审尚未完成。

## 制作材料

| 入口 | 内容 |
| --- | --- |
| [compositions/](compositions/) | 世界、军团、人物与短提示的显式谱面；各曲的旋律、声部和形式由各自代码描述。 |
| [scorelib.py](scorelib.py)、[build_score.py](build_score.py) | 谱面基础操作及曲目汇编；构建记录关联输入文件的哈希。 |
| [title-overrides.json](title-overrides.json) | 曲目中文标题和场景说明；具体游戏调用仍以实际目录与运行状态为准。 |
| [instrument-manifest.json](instrument-manifest.json)、[fetch_instruments.py](fetch_instruments.py) | 音源文件、来源、固定版本、哈希及实际乐器名称；样本按需取得并校验。 |
| [audio_engine.py](audio_engine.py) | 从谱面和已核验采样生成 48 kHz 立体声分轨、混音、MIDI、REAPER 工程与报告。 |
| [engine_verify_reaper.py](engine_verify_reaper.py) | 使用独立 REAPER 与虚拟显示检查工程、MIDI、分轨及重新导出的工程一致性。 |
| [master.py](master.py) | 从指定的干渲染目录制作暂存母带、游戏 Ogg 和技术报告；完整 70 项核验后才可使用发布选项。 |
| [production-lock.json](production-lock.json)、[audio-qa.json](audio-qa.json) | 生产锁记录谱面与目录哈希、母带版本和干渲染目录；音频 QA 记录各曲检查结果和 Ogg 哈希。 |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | 本轮所用音源的来源、许可及名称边界。 |

## 播放与曲目

主线标题、菜单和设定中都可进入「音乐鉴赏」，按曲名和用途浏览、播放、暂停或拖动进度条；音乐音量与静音沿用设定。也可以直接打开游戏文件，例如[贾苇索《此行有我》](../../assets/music/chronicle/hero_main.ogg)、[喜剧《歪一步再走》](../../assets/music/chronicle/story_comedy.ogg)、[吕布人形《白门之前》](../../assets/music/chronicle/boss_lubu.ogg)及[吕布战相](../../assets/music/chronicle/boss_lubu_warform.ogg)。完整曲目及用途见[游戏目录](../../assets/data/audio/music_catalog.json)。

## 从谱面重建

从仓库根目录执行。环境需要 Python、NumPy、SciPy、FFmpeg、Git、curl 和 7-Zip；实际版本见[环境记录](checks/environment.json)。首次获取采样需要网络、磁盘空间和时间：清单锁定的 2,082 个文件合计约 1.86 GB，脚本按谱面使用的区域获取并校验，已缓存文件可复用。下例在独立目录重建全部 70 项，不改写现有游戏音频：

```bash
mkdir -p "$HOME/.cache/my-game/music-rebuild"
MUSIC_JOB="$(mktemp -d "$HOME/.cache/my-game/music-rebuild/job-XXXXXX")"
python3 design/music-20261030/build_score.py --output "$MUSIC_JOB/score"
python3 design/music-20261030/audio_engine.py --score "$MUSIC_JOB/score/score.json" --output "$MUSIC_JOB/renders" --tail 8 --fetch
python3 design/music-20261030/master.py --score "$MUSIC_JOB/score/score.json" --renders "$MUSIC_JOB/renders" --output "$MUSIC_JOB/master"
```

`score/` 含汇编谱面与暂存曲目表，`renders/<曲目 ID>/` 含干分轨、混音、MIDI、RPP 和报告；`master/` 含 `masters/*.flac`、`music/*.ogg` 和 `audio-qa.json`。只需部分曲目时可按脚本 `--help` 在命令末尾指定 ID。最终游戏文件已在 `assets/music/chronicle/`；另一次重建如需实际替换游戏资源，给母带命令添加 `--publish`，它只接受通过检查的完整 70 项，并更新游戏曲目表及本目录的 QA 与生产锁。不要把局部暂存误当成完整发布。

可选的工程复验需要 REAPER 和 Xvfb，默认指向本机已安装的 REAPER 7.83 与独立 Xvfb；其他位置用 `--reaper`、`--xvfb` 指定。下面以完整艾玛曲为例，在新目录用独立实例重开工程并比对导出：

```bash
python3 design/music-20261030/engine_verify_reaper.py --cue-dir "$MUSIC_JOB/renders/character_emma" --output "$MUSIC_JOB/reaper-check"
```

REAPER 的使用仍受其现有评估或许可状态约束。此复验不会替代试听。

## 音频与工程链

1. 汇编各曲显式谱面及曲名信息，使用音源清单选取对应的多采样音符、力度区间与演奏方式。采样文件缓存于仓库外的 `~/.cache/my-game/music-instruments/`，原始音源库不放入仓库；本地下载回执与清单用于核对具体文件。
2. Python 音频引擎生成未额外添加后期混响的独立分轨、混音、Type 1 MIDI 和 REAPER `.rpp`。采样录音本身可能包含其原有空间声；分轨及原始混音不能当作已经完成母带。
3. REAPER 工程同时保留可播放的冻结分轨和静音的可编辑 MIDI 轨，工程使用相对路径引用分轨。**编辑 MIDI 不会自动改写冻结音频**；需要用相应音源重新渲染并检查，再进行母带。移动工程时应连同其分轨目录一起保留。
4. 母带为原混音加入轻量程序空间处理，对每曲分别作线性响度匹配，不使用压缩器或限制器；检查循环接缝、响度、峰值、单声道及编码结果，生成 FLAC 与 Godot 可用 Ogg。双阶段版本的同轴互补淡化发生在游戏运行时。
5. 谱面、工程、母带、游戏文件、曲目说明及来源有各自记录。技术检查能验证文件与运行条件，不能证明作品的艺术质量或玩家的实际听感。

## 音色名称与使用边界

[instrument-manifest.json](instrument-manifest.json) 的 `actual_name`、`status` 和替代说明记录真实音源。例如当前 `flute` 是西洋长笛，不能标为中国笛；`dan_tranh` 是越南弹拨筝，不是中国古筝；`taiko` 映射至管弦低音鼓，不是真实日本太鼓；`pluck` 映射至音乐会竖琴。最终使用哪些音源，以冻结清单和各曲渲染报告为准。

音源选择与力度、装饰、连音、换气等写法需要逐项验证；某个采样名称不代表具备完整真实演奏技法。合成声部和采样声部应按实际实现标注，不把代理音色当成对应民族乐器实录。

当前引擎按清单选择采样音高、力度区域和录制的轮替样本，具体映射及必要修补写入渲染报告。对原始采样在单声道折叠时能量损失低于 −4 dB 的情况，引擎选择原始左右声道中均方根较强的一路复制到两声道；其他采样保留原立体声，不改写缓存原文件。它没有真实连奏过渡录音，也不通过人为延长循环声波制造无限长音；音符时长与采样覆盖的限制须随作品检查。当前电吉他和电贝斯是干净直入信号，不当作经过真实音箱录制的声音；`pad` 为程序合成音色。

## 当前验证边界

当前音源清单 SHA256 为 `675b67fbda3658b61b021286feb8792124c4aba6bb2d89363f0c612865214ce8`，见[引擎冻结记录](engine-evidence/engine-freeze.json)。当前样本引擎 [11 项测试](engine-evidence/unit-tests-v3_1.txt)通过，完整艾玛曲与主角主题分别用独立 REAPER 重开并重渲染，见[艾玛](engine-evidence/reaper-character-emma-v3.json)和[主角](checks/horn-rr-fixed-reaper-hero/result.json)的工程检查。[人物与剧情 16 条干渲染审计](engine-evidence/characters-16-render-audit-v3.json)记录了声道修复后的哈希、采样格式和分轨重建。干渲染不是母带或艺术验收。

另有一处圆号短音 SFZ 区域在同组样本幅度接近时设置了额外 +12 dB；本轮只对该有效映射设为 0 dB，保留上游原值与原始音源。70 项中 6 项受影响并已重渲，其他 64 项不因版本号而重渲；吕布战相中原有的无音高锣键位映射提示继续保留。比较与复现见[调查](engine-evidence/fhorn-staccato-rr-investigation.json)和[渲染审计](engine-evidence/fhorn-rr-render-audit.json)。

REAPER 7.83 曾将自定义渲染终点舍入，导致 2/4 张辽工程重建短 10 帧；改用精确采样时间选区后，完整长度和分轨重建通过。对照及修复见[边界检查](engine-evidence/reaper-exact-boundary-fix.json)，不依靠补尾或放宽长度断言。

本机最终母带在被 Git 忽略的 `mastering-final-v4/`，输入取自 [production-lock.json](production-lock.json) 所列的五个本地渲染根目录，最后一项包含圆号修复。干分轨、MIDI、RPP 和 FLAC 母带是本地中间产物，不能误称已随版本库交付。谱面、冻结清单与程序可用于重建；要直接搬运既有工程时，须保留其引用的分轨并明确保存位置。

最终 70 个游戏 Ogg 的哈希与 QA 一致；最高真峰值 −4.42 dBTP，最差单声道折叠损失 −1.5244 dB，目标响度最大偏差 0.71 LU，见[交付统计](checks/delivery-summary.json)。64 项已验证预处理与 61 项编码在相同输入、增益及哈希条件下复用，其余重做，见[复用记录](checks/master-reuse-v4.json)。

游戏 headless 205 项、Xvfb + Dummy 94 项检查使用首版素材；最终替换只改波形及增益，长度、目录和路由不变。最终素材另通过重新导入、启动及仓库外导出 PCK 的 213 项检查，见[运行日志](../../docs/implementation/evidence/2026-10-30/music/runtime/)。本轮完整工程验收使用最终素材，音乐路由 headless 205 项、Xvfb + Dummy 播放 90 项、空目录导出包音乐 213 项通过；本次播放未启用 capture，故不含首版 94 项中的 4 项截图断言，两次结果不相加。70 个 Ogg 的 SHA 与音频 QA 一致；谱面和目录从显式源重生成与终版一致，其 SHA 与生产锁一致，详见[验收汇总](../../docs/implementation/evidence/2026-10-30/music/acceptance/summary.json)和[音频记录](../../docs/implementation/evidence/2026-10-30/music/acceptance/acceptance-audio.json)。本地 PCK 是验证包，不是发行程序或线上发布。

会话音频能力测试显示当前执行模型无法直接接收并聆听音频，**完整主观听审尚未完成**；信号测量、文件哈希、REAPER 工程重建与自动化游戏测试都不能替代聆听。播放文件供后续实际听审使用。
