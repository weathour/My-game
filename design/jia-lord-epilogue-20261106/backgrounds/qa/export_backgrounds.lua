-- Whole composition retained. 1672x941 near16:9 generated sources -> exact1536x864.
-- Bilinear resampling preserves painted surfaces; no crops, redraws or alpha processing.
for _,name in ipairs({'lord-hall','lord-chamber'}) do
 local source=Sprite{fromFile='design/jia-lord-epilogue-20261106/backgrounds/source/'..name..'-v1.png'}
 app.activeSprite=source
 app.command.SpriteSize{ui=false,width=1536,height=864,method='bilinear'}
 source:saveAs('assets/story/chronicle/'..name..'.png')
 source:close()
end
