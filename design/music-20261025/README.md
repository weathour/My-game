# 第一章与无尽模式原创配乐

2026-10-25。为当前可玩的内容制作，只有音乐，没有台词配音。主代理完成主题写作、谱面编排、REAPER渲染与母带处理；没有使用在线歌曲生成服务，也没有导入巴赫、东方 Project、水仙或 To the Moon 的录音、MIDI或旋律。

## 制作交付

- 游戏音频：[assets/music](../../assets/music/)；14个48 kHz立体声Ogg Vorbis文件，12个循环曲和2个一次性结算短曲。
- 无损母带：[masters](masters/)；48 kHz、24 bit FLAC。
- 可编辑工程：[projects](projects/)；14个REAPER `.rpp`，内含分轨MIDI、乐器、声像、音量、混响及导出区间，无外部歌曲依赖。
- 通用乐谱：[midi](midi/)；14个标准MIDI Type 1，可导入其他DAW；GM音色在其他音源上可能不同。
- 谱面源：[compose.py](compose.py)、[score.json](score.json)；10个独立A/B主题加胜负终止式，编排含力度、留白、声部交接、低音线与高潮回归。
- 曲目规格：[cue-sheet.json](cue-sheet.json)；实际编码时长、LUFS、真峰值、单声道折叠、接缝和文件SHA256见[audio-qa.json](audio-qa.json)。短曲的实际时长以QA为准，已剪去多余尾部静音。

## 曲目与游戏身份

| 音轨 | 使用处 | 写作与音色安排 |
| --- | --- | --- |
| `camp_signal`《等一声回答》 | 主菜单、选档、通讯营地、阅读、无尽营地与波间整备 | 76 BPM，D小调/F大调；钢琴四音讯号D–A–F–E，长笛短回应、大提琴与少量钟音。旋律有呼吸，阅读时不铺满鼓组 |
| `stage_frontpost`《前哨的两条来路》 | `chapter1_stage1`；无尽前段与奖励波 | 136 BPM，D小调；钢琴主题、羽管键琴回答、清楚的低音脉冲。开头建立主旋律，后半扩大音域并回收讯号 |
| `stage_rift`《裂隙另一侧的回声》 | `chapter1_stage2`；无尽中段 | 148 BPM，G小调；小号前景与钢琴答句，以降VI、属和弦及转向大调的第二主题形成推进与回望 |
| `stage_core`《群星失去方向》 | `chapter1_stage3`的Boss前准备；无尽后段 | 156 BPM，E小调；圆号、拨弦键盘、合成低音；中段抽掉部分节奏，再返回主题，避免一直满强度 |
| `elite_ram`《踏破红线》 | `elite_ram_trail`精英冲锋骷髅 | 168 BPM，C小调；短促铜管、钢琴与偏重低鼓，附点位置的推进对应蓄势与冲锋。音乐不替代攻击预警 |
| `elite_splitshot`《四向展开》 | `elite_splitshot`精英分裂骷髅 | 174 BPM，F小调；旋律在高低音区折返，羽管键琴答句与清晰短音分组对应分裂弹；保留中心主旋律，避免极端左右声像 |
| `boss_tree`《根须记住了雨》 | `smallboss_glutton`幽影树人；主线第二关/无尽波6 | 138 BPM，D小调中引入多利亚色彩；木管、拨弦与大提琴低音，连续生长的音型对应吞噬、缠绕与木刺 |
| `boss_rebirth`《第二次渡河》 | `smallboss_rebirth`引渡人；波11 | 150 BPM，A小调；管风琴宣叙与钢琴回答，低音保留行进感；中段削弱织体后再归来。墓碑等待期间保持同一遭遇主题 |
| `boss_rose`《八瓣回旋庭》 | `smallboss_turret`地瑰灵；波16 | 168 BPM，G小调/Bb大调；高音铜管与旋转拨弦音型，第二主题更开阔，对应花弹、分身与八向展开 |
| `boss_spellcore_1`《把回答带回黎明·第一相》 | `boss_spellcore`护盾/第一阶段；主线第三关/波20 | 180 BPM，D小调/F大调；小号与钢琴重述营地讯号，保留较疏的鼓点与音域 |
| `boss_spellcore_2`《把回答带回黎明·第二相》 | 同一Boss真实第二阶段 | 同速、同长、同时间轴；加入高声部拨弦回应和四拍低鼓，主题位置保持 |
| `boss_spellcore_3`《把回答带回黎明·第三相》 | 同一Boss真实第三阶段 | 保留第二相骨架，句首增加上八度弦乐；通过声部与音区加压，三版统一响度，避免只加音量 |
| `victory`《灯亮了》 | 真正通关/层结算 | 钢琴把讯号引向F大调终止；一次播放。主线返营后接回营地曲 |
| `defeat`《信号仍在》 | 当前战局失败 | 低力度钢琴下行与Dm收束；一次播放，给重试界面留空间 |

无尽普通波复用明确的地点主题，20波全部有映射。正式三小Boss与最终Boss优先于精英，精英优先于基础关卡；两精英共存时冲锋优先，死亡后再判断分裂，不按预定秒数猜测。第19波第二只精英未生成就不会误播其音乐。主线当前不会自然生成这两种精英，但无尽已覆盖。

## 制作方法与取法

巴赫方向取“独立声部可辨、一个动机能够被回答和发展”的方法；本作是现代游戏配乐，没有宣称是严格复原的巴洛克赋格。[Henle对三声部Sinfonias的介绍](https://www.henle.de/us/Sinfonias-Three-Part-Inventions/HN-1592)提供了相应声部概念背景。

东方方向取主题前景、快速键盘线条、明亮合成铜管、弹幕战斗的连续推动感。ZUN在[4Gamer本人访谈](https://www.4gamer.net/specials/shanghai_alice/zone_z.shtml)中谈到从制作游戏音乐出发开发游戏；这里将音乐与遭遇身份一起设计。具体调性、旋律、配器和“根须/冲锋/花瓣”等对应关系是本项目的原创选择，访谈并不证明这些配方必然有效。

已实际采用的制作工具是[REAPER 7.83 Linux](https://www.reaper.fm/download.php)，通过官方[ReaScript](https://www.reaper.fm/sdk/reascript/reascript.php)建立并渲染真实DAW工程。Lua负责执行谱面，不通过随机生成音符替代作曲。最初也查阅了[LMMS导出](https://docs.lmms.io/user-manual/production/exporting)与[FluidSynth离线渲染](https://www.fluidsynth.org/api/group__file__renderer.html)；REAPER在本机可同时完成MIDI、内置音源、混响、工程保存和批量渲染，因而没有再安装一套音源链。

游戏侧沿Godot自己的[Ogg循环属性](https://docs.godotengine.org/en/4.6/classes/class_audiostreamoggvorbis.html)播放。最终Boss三相是同一时间轴的三份完整编曲，切换保留播放位置并使用线性互补增益；其他场景曲交叉淡化。没有引入Wwise/FMOD，也没有把攻击节奏绑定音乐拍点。

## 工程、循环与混音

每个循环工程连续演奏两轮，第一轮建立乐器释放和混响，第二轮提取为完整音乐周期；循环末端只作128采样点的波形斜率校正。没有在每轮首尾加入明显淡入淡出。胜负短曲保留自然衰减，剪去多余静音，不循环。

REAPER使用随附的Synthy McSynthface原声钢琴与Major General MIDI（Sonivox EAS）音源，以及Zita-Rev1移植混响。各轨有独立音区、力度、音量和克制的声像；先降低伴奏与鼓组，再控制母带。母带32 Hz高通、15.5 kHz低通，修正过宽的侧声道，以线性增益统一响度，不用重度限制器抹平乐句强弱。目标为营地−23 LUFS、普通/精英/小Boss−21 LUFS、最终Boss−20 LUFS、胜利−22 LUFS、失败−24 LUFS；这是一组项目混音选择，不是所谓行业强制标准。

首次前哨导出的单声道折叠损失约4.8 dB，未通过检查；已缩窄侧声道并重新完成母带。最终每首都检查非空信号、有限采样、源端无削波、编码后的真峰值、响度、长度、单声道折叠及循环接缝。最终Boss三版必须同采样数；胜负曲须自然结束，禁止循环。详细数值以QA文件为准。

谱面自查覆盖小节拍数、音域、音符长度/边界、同声部同音重叠以及14项唯一ID。运行时验证由`music_context_smoke.gd`、相关生命周期回归与导出包内容检查负责。自动检查能够证明文件与状态行为，不替代人类音乐审听、正常速度完整游玩或不同扬声器上的主观混音评价；本轮没有这些人类验收证据。

## 复现与继续编辑

本机REAPER位于`/home/weathour/.local/opt/reaper-7.83/reaper_linux_x86_64/REAPER/reaper`，隔离配置位于`/tmp/mygame-reaper-session/`。官方安装包SHA256为`76c49970fd9520b2beabf6485e3ae1ccbe434bc935c68aa6e5a143b0e0ab6594`，与[官方散列](https://www.reaper.fm/download.php?hashes=1)核对后解压；没有购买、账号登录或下载付费采样库。

在仓库根目录运行：

```bash
python3 design/music-20261025/compose.py
mkdir -p /tmp/mygame-reaper-session
/home/weathour/.local/opt/reaper-7.83/reaper_linux_x86_64/REAPER/reaper -newinst -nosplash -cfgfile /tmp/mygame-reaper-session/reaper.ini design/music-20261025/render.lua
python3 design/music-20261025/master.py
```

`render.lua`写入`/tmp/mygame-music-render/`；REAPER结束后再运行母带步骤。Python后处理使用本机已有NumPy/SciPy与FFmpeg，没有给游戏增加依赖。也可以直接打开RPP逐音编辑，重新渲染对应文件，再将cue ID传给`master.py`只重做该曲。RPP是母带处理前的工程；游戏实际母带还包括`master.py`记录的EQ、宽度、接缝和增益。循环工程的两轮是制作预滚与正式循环，游戏只包含一轮。

REAPER当前使用官方60天完整功能评估；超过试用期继续使用DAW需取得相应许可。游戏只播放导出的Ogg，不需要安装REAPER。音源/混响实现及声音库随REAPER安装，仓库不复制或再分发这些插件或声音库。Sonivox原始引擎/声音库的Apache-2.0来源和JSFX移植的GPLv3+说明保留于随附插件头部；钢琴/MDA与混响来源同样见插件说明。发行素材说明见[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)，不要将原创曲目当作全项目其他美术已清权的证据。
