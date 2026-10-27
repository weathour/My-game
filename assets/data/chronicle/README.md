# 新界面演练数据

- `characters.json`：37 张首章人物卡＋固定主角；取自当前卡池草案。技能名、基础等级与演练数值是 UI 接入样例，不是已定战斗平衡。女剑士的实际入池节点未定，因此未硬接路线门槛。
- `route.json`：36 个作者节点，分六段显示；18 战斗、14 事件、4 泉水。地图位置为 UI 排版，不是史实坐标。支路不可回刷。
- `provinces.json`：转换自 [wonton1984/sanguo-map 的 donghan.js](https://github.com/wonton1984/sanguo-map/blob/main/data/donghan.js)，保留 13 个简化州域坐标。[MIT 声明](sanguo-map-LICENSE.txt)。州域有缺口，仅作界面定位，不用于推断城池归属或锁定最终州制。
- `land.json`：[Natural Earth 110m land](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_land.geojson)，[公有领域条款](https://www.naturalearthdata.com/about/terms-of-use/)。只用于天下图自然海陆轮廓。

这些 UI 演练数据由 `chronicle_session.gd` 加载，使用独立 `user://chronicle_ui_v1/` 存档，不写入旧版角色/主线档案。
