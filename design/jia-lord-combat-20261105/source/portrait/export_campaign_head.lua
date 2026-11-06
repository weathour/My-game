-- ImageGen authors the independent bust; Aseprite only prepares/export pixels.
local pc=app.pixelColor
local function binary(image)
 for px in image:pixels() do
  local c=px()
  px(pc.rgbaA(c)>=128 and pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255) or 0)
 end
end
local source=Image{fromFile='design/jia-lord-combat-20261105/source/portrait/campaign-head-v1.png'}
binary(source)
local bounds=source:shrinkBounds()
local crop=Image(source,bounds)
local scale=math.min(124/crop.width,124/crop.height)
crop:resize(math.max(1,math.floor(crop.width*scale+.5)),math.max(1,math.floor(crop.height*scale+.5)))
local frame=Image(128,128,ColorMode.RGB)
frame:drawImage(crop,Point(math.floor((128-crop.width)/2),math.floor((128-crop.height)/2)))
binary(frame)
local sprite=Sprite(128,128,ColorMode.RGB)
sprite:newCel(sprite.layers[1],1,frame,Point(0,0))
app.activeSprite=sprite
app.command.ColorQuantization{ui=false,maxColors=64,withAlpha=true}
app.command.ChangePixelFormat{ui=false,format='indexed',dithering='none'}
sprite:saveAs('assets/players/jia-campaign/campaign-head.aseprite')
local png=Image(128,128,ColorMode.RGB)
png:drawSprite(sprite,1,Point(0,0));binary(png)
png:saveAs('assets/players/jia-campaign/campaign-head.png')
local preview=Image(png);preview:resize(512,512)
preview:saveAs('design/jia-lord-combat-20261105/source/portrait/export-review-4x.png')
sprite:close()
print('CAMPAIGN_HEAD_EXPORT_OK native=128 output=128 palette<=64')
