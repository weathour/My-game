# 战役与界面数据

- `characters.json`：37 张首章人物卡＋固定主角的人名、初版入手等级、技能与前后台／持有说明及入池提示；战斗数据由 `scripts/content/combat_catalog.gd` 与 `roster_kit_data.gd` 提供，初版数值仍待实玩调整。蕾娜的 S06 入池剧情已写，相关路线尚未开放。
- `character_profiles.json`：38 人的人物简介、台词、合作态度及人物资料；人物页读取其中部分内容，肖像及战斗美术仍沿用已有或临时素材。
- `route.json`：36 个作者节点，18 战斗、14 事件、4 泉水；区域图按 `next` 连续横向显示，六段为跳转定位锚点。地图位置为 UI 排版，不是史实坐标。支路不可回刷，展示节点不代表已经开放。
- `story_events.json`：已创作的正式剧情文本与演出配置的唯一入口，目前覆盖 S01—S06、F01、B06、B15—B17 与 S14。每句的稳定 ID 用于剧情续读；事件背景、音乐、人物位置和对白分开记录。旧 `events.json` 不再由运行代码读取，其 S03—S05 叙述已并入此文件。S06 及后续脚本已写并不意味着其路线与战斗已开放；尚未创作事件的路线摘要只用于预览。
- `provinces.json`：转换自 [wonton1984/sanguo-map 的 donghan.js](https://github.com/wonton1984/sanguo-map/blob/main/data/donghan.js)，保留 13 个简化州域坐标。[MIT 声明](sanguo-map-LICENSE.txt)。州域有缺口，仅作界面定位，不用于推断城池归属或锁定最终州制。
- `land.json`：[Natural Earth 110m land](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_land.geojson)，[公有领域条款](https://www.naturalearthdata.com/about/terms-of-use/)。只用于天下图自然海陆轮廓。

人物、路线等数据由正式主线与界面演练共用；演练会话 `chronicle_session.gd` 使用独立 `user://chronicle_ui_v1/` 存档，不写入正式主线或旧版档案。正式主线的实现范围以[当前状态](../../../docs/08_当前实现状态与后续重点.md)为准。
