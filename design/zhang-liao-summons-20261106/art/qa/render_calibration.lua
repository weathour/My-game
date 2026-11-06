-- Diagnostic markers on a COPY of source pose0; original and runtime art untouched.
-- Cyan=crown/core top y20; green=own-robe hem y326; orange=virtual scroll ground y344.
local pc=app.pixelColor
local source=Image{fromFile='design/zhang-liao-summons-20261106/art/source/M04_WAR-chengong-v1.png'}
for p in source:pixels()do local c=p();p(pc.rgbaA(c)>=128 and pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255)or 0)end
local region=Image(source,Rectangle(35,0,310,355))
for _,r in ipairs({{20,pc.rgba(30,215,245,255)},{326,pc.rgba(64,245,115,255)},{344,pc.rgba(255,151,45,255)}})do
 for x=0,309 do region:drawPixel(x,r[1],r[2])end
end
region:resize(620,710)
region:saveAs('design/zhang-liao-summons-20261106/art/qa/M04_WAR-core-calibration-markers.png')
local core=Image(source,Rectangle(130,20,122,306));core:resize(244,612)
core:saveAs('design/zhang-liao-summons-20261106/art/qa/M04_WAR-core-window.png')
