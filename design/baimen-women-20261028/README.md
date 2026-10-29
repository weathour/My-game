# 白门楼九位女性人物美术

田秀、马三娘、钱绮罗、祝青蘅、陶小满、柳晚晴、蕾娜、秦雁和陆知微的**九张首轮透明全身母版**已生成并完成本轮素材检查。2026-10-28，用户看过九人母版对照后要求“继续”；本批九版作为后续制作基础。九人的全身立绘已接入剧情、卡片与人物面板，独立战斗头像和待机、跑步、攻击、辅助动作也已接入；本轮专项检查和渲染证据见下方。

[打开九人审看页](index.html)：可切换浅米、深绿和棋盘底，并排对照九人、打开单张原图，也可查看游戏内卡片和动作 GIF。另有 Godot 渲染的[浅底](preview-light.png)、[深底](preview-dark.png)和[棋盘底](preview-checker.png)预览。

| 人物 | 本轮提交审看图 | 实际使用的提示词 |
| --- | --- | --- |
| F03 田秀（女医者） | [全身母版](source/F03-tianxiu-master-v1.png) | [提示词](prompts/F03-tianxiu-used-v1.txt) |
| F07 马三娘（女匪首） | [全身母版](source/F07-masanniang-master-v1.png) | [提示词](prompts/F07-masanniang-used-v1.txt) |
| F04 钱绮罗（鬼市行商） | [全身母版](source/F04-qianqiluo-master-v2.png) | [提示词](prompts/F04-qianqiluo-used-v2.txt) |
| F05 祝青蘅（荒祠道士） | [全身母版](source/F05-zhuqingheng-master-v1.png) | [提示词](prompts/F05-zhuqingheng-used-v1.txt) |
| F08 陶小满（女铸师） | [全身母版](source/F08-taoxiaoman-master-v1.png) | [提示词](prompts/F08-taoxiaoman-used-v1.txt) |
| F09 柳晚晴（旧楼歌伎） | [全身母版](source/F09-liuwanqing-master-v1.png) | [提示词](prompts/F09-liuwanqing-used-v1.txt) |
| F02 蕾娜（女剑士） | [全身母版](source/F02-leina-master-v2.png) | [提示词](prompts/F02-leina-used-v2.txt) |
| F06 秦雁（城防弩手） | [全身母版](source/F06-qinyan-master-v1.png) | [提示词](prompts/F06-qinyan-used-v1.txt) |
| F10 陆知微（官署簿吏） | [全身母版](source/F10-luzhiwei-master-v1.png) | [提示词](prompts/F10-luzhiwei-used-v1.txt) |

## 制作与版本

本批使用内置 ImageGen 的透明背景选项，先独立生成九人，再分别参考钱绮罗和蕾娜的 v1 调整画幅留白，选其 v2 供审看。两人的 [v1 钱绮罗](source/F04-qianqiluo-master-v1.png)及 [v1 蕾娜](source/F02-leina-master-v1.png)仍保留供比较，用户要求继续后，以这两张 v2 及其他七人的 v1 作为后续制作基础；具体表现仍可按反馈调整。生成记录、所用提示词、参考关系和 SHA-256 见[素材清单](manifest.json)；`prompts/` 中不带版本后缀的是起初的外观设计稿，`*-used-v1.txt`／`*-used-v2.txt` 才是实际使用的提示词。

头像和战斗源图以各自母版为身份参考；贾苇索的像素头像及动作图只用作像素技法参考。每人独立生成像素头像及动作图，实际提交的文本分别保存为 `*-portrait-used-v1.txt`／`*-combat-used-v1.txt`，来源及参考关系见[派生记录](derivatives.json)。动作按右向 4×5 组织待机、跑步、主要攻击和独立辅助动作；源图须逐帧量测，不能假定每一格都能直接使用。也保留[头像](prompts/avatar-template.txt)、[待机](prompts/combat-idle-template.txt)、[移动](prompts/combat-move-template.txt)和[攻击](prompts/combat-attack-template.txt)通用草稿，供调整时参考。

本批保留 30 张生成源：9 张选用母版、2 张留白调整前的候选、9 张像素头像源、9 张战斗动作源，以及蕾娜的一张两帧补画源。

贾苇索的已确认形象只供人工观察成熟线描、厚涂与材质方向，**没有作为九个新图的生成输入**。九人的性格和视觉区分见[外观矩阵](art-briefs.md)与[人物档案](../../docs/17_人物档案.md)。田秀首版实际为实用高髻，与原先建议的低髻不同；后续素材以该母版为基础，母版与文字设想不强行视作完全一致。

## 检查与后续

所选九图均为 **1024 × 1536 RGBA**。只读检查显示 alpha 范围为 0—254，最外边缘 alpha 不超过 15，具体数值与可见范围见[透明度记录](alpha-audit.json)。浅色、深色和棋盘底经逐图查看，未发现明显残底、整片光晕或人物裁切；Godot 预览渲染正常，见[渲染日志](preview-render.log)。这是插画源图的半透明边缘，**不是**已整理完成的二值 alpha 战斗像素帧。

九人共接入 **9 张全身立绘、9 张独立战斗头像、180 帧战斗动作**；每人 20 帧，分别为待机 4、跑步 8、攻击 4、辅助施法 4。战斗资源为 45 张 PNG 和 45 个可编辑 Aseprite 文件，另外有 9 张独立立绘 PNG：战斗帧为 192×192，锚点 `(96, 176)`，各人物动作共享不超过 63 个不透明颜色并采用二值 alpha；头像以 64×64 原生编辑、最近邻导出为 128×128。逐帧、源图与哈希见[导出清单](export-manifest.json)和[素材复现入口](../../assets/players/baimen-women/README.md)。

蕾娜原动作图攻击行第 3、4 格的剑尖与邻帧披风粘连，不能无污染切出。经[两帧补画](source/F02-leina-attack-fix-v1.png)替换这两帧，其他 18 帧保留原源图；补画实际提示词为[此版本](prompts/F02-leina-attack-fix-used-v1.txt)，补画按恢复站姿统一采用 `80/595` 的尺度登记，不把原 20 格称为全数合格。量测及来源见[逐帧记录](export-measurements.json)和[派生记录](derivatives.json)。

界面专项 headless／真实渲染各 **PASS 525**；[日志](ui-evidence/portraits-headless.log)和[渲染日志](ui-evidence/portraits-rendered.log)为同一组重叠检查，不相加。战斗专项 [headless **PASS 194**](combat-evidence/headless.log)、[真实 OpenGL **PASS 185**](combat-evidence/gl.log)；后者运行时尚未加入 9 项尺寸断言，最新脚本另对 F02／F06／F09 三种尺寸做了[补验 **PASS 74**](combat-evidence/gl-scale.log)，这些结果不相加或合称“真实渲染 194”。贾苇索美术[兼容回归 **PASS 26**](combat-evidence/jia-regression.log)，特效复用的[回归日志为 **PASS 36**](combat-evidence/authored-effects.log)。

Godot 必需的 headless 启动通过，见[启动日志](godot-startup.log)；本轮有效日志经检查无警告和错误。界面证据含 57 张截图及 81 项界面区域量测，早期未完整生成截图的日志单独保留，不作为通过证据。Graphify 受保护更新因缺少 Godot 提取器、遗漏 190 个运行脚本而拒绝候选，保留 STALE 旧图，见[更新日志](graphify-update.log)；这不影响上述游戏专项检查。

[九人动作总览 GIF](combat-evidence/runtime-preview.gif)由 48 张预览帧按 12 fps 汇出，用于观察完整素材动作循环；实际战斗中的攻击从各人物的接触帧起播。27 张战斗、辅助动作与三尺寸截图见[战斗证据](combat-evidence/)，人物页面、卡片与剧情截图见[界面证据](ui-evidence/)。已抽看动作总览、蕾娜守势、秦雁战斗、九人卡片和钱绮罗剧情／详情；截图验证覆盖和效果不等同于全部角色的人工实玩验收。

本轮没有制作独立表情差分或八方向动作。后续结合实玩反馈调整动作观感，并按既有计划继续其他人物；未开放的后续关卡不会因美术接入而开放。
