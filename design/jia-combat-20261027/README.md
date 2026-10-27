# 贾苇索战斗素材

日期：2026-10-27。素材已制作、接入并完成程序复验；用户已确认的[起家立绘](../jia-weisuo-20261027/jia-standing-v1.png)作为人物母版。[机械师动作源图](../mechanic-rework-20261013/source/character-animations.png)仅作像素风格与制作流程参考。

适用于后续角色的步骤与验收要求见[角色战斗美术制作流程](../../docs/art/角色战斗美术制作流程.md)。

内置 ImageGen 生成的RGBA源图保留在 [source](source/)，对应提示词在 [prompts](prompts/)。`vfx-v2.png`用于导出；合并或枪头朝后的候选动作未采用，长枪攻击第4帧复用准备帧。

## Aseprite 导出

从仓库根目录执行以下命令会重新导出 `assets/players/jia/`：

```bash
/home/weathour/programs/aseprite-src/build/bin/aseprite --batch --script scripts/tools/import_jia_art.lua
```

脚本按连通区域提取不规则源帧，依据人工量测的髋部与地面锚点统一定位及固定比例缩放，人物帧共用不超过64色与二值透明；源图变化后需重新核对选帧和锚点，不能按假定网格盲切。

运行素材保留PNG与可编辑 `.aseprite`：刀／枪各有待机4帧、奔跑8帧、攻击4帧，共32个人物帧；`slash`／`thrust`／`sweep`各4帧，共12帧特效。人物帧为192×192，锚点 `(96, 176)`；站姿身体80像素，乘0.9得到世界高度72，奔跑与攻击的俯身不强行拉高。

HUD头像另由 ImageGen 单独绘制，源图为 [portrait-v1.png](source/portrait-v1.png)，[提示词](prompts/portrait.txt)保留；Aseprite按64像素原生尺寸整理后导出128像素头像，已接入并复核。最终人物与特效见[预览图](preview.png)、[动作预览](preview.gif)及[素材清单](manifest.json)，清单记录6张源图、6组提示词及10张运行PNG的哈希。

## 接入边界

贾苇索独立战斗形象替换旧剑士临时素材，其他角色保持原样。刀与长枪分别对应持武器动作；左右镜像与现有八向移动结合，攻击和特效朝实际目标。成功施放才播放攻击，手动技能优先普攻，姿态从接触帧开始匹配即时伤害；攻击不锁移动、不改战斗数值。特效沿战斗时间推进，暂停与结束沿既有生命周期处理；独立头像用于三角HUD。

测试结果和截图见[实施记录](../../docs/implementation/2026-10-27_贾苇索战斗美术接入.md)；程序验证不代替用户审看动作和实战观感。
