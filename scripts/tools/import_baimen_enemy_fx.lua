-- Original ImageGen VFX only; measured source regions, fixed scale across the sequence.
local id=assert(app.params["id"], "effect id required")
local base="design/baimen-enemies-20261028/effects/" .. id .. "/"
local file=assert(io.open(base .. "measurements.json","r")); local m=json.decode(file:read("*a"));file:close()
assert(m.review_status=="accepted_for_export" and m.id==id,"reviewed effect measurements required")
local source=Image{fromFile=base .. m.source.path}
assert(source.width==m.source.size[1] and source.height==m.source.size[2],"source dimensions changed")
local pc=app.pixelColor
local function binary(image)
 for p in image:pixels() do local c=p();p(pc.rgbaA(c)>=128 and pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255) or 0) end
end
local width,height=m.frame_size[1],m.frame_size[2]
local sprite=Sprite(width,height,ColorMode.RGB)
local function round(n) return math.floor(n+.5) end
for i,frame in ipairs(m.frames) do
 local r=frame.region
 assert(r[1]>=0 and r[2]>=0 and r[3]<=source.width and r[4]<=source.height,"region outside source")
 local cropped=Image(source,Rectangle(r[1],r[2],r[3]-r[1],r[4]-r[2]));binary(cropped)
 cropped:resize(math.max(1,round(cropped.width*m.scale)),math.max(1,round(cropped.height*m.scale)))
 local x=m.anchor_px[1]-round((frame.anchor_source[1]-r[1])*m.scale)
 local y=m.anchor_px[2]-round((frame.anchor_source[2]-r[2])*m.scale)
 assert(x>=0 and y>=0 and x+cropped.width<=width and y+cropped.height<=height,"effect would clip " .. i)
 local canvas=Image(width,height,ColorMode.RGB);canvas:drawImage(cropped,Point(x,y))
 if i>1 then sprite:newEmptyFrame() end
 sprite:newCel(sprite.layers[1],i,canvas,Point(0,0));sprite.frames[i].duration=1/m.fps
end
app.activeSprite=sprite
app.command.ColorQuantization{ui=false,maxColors=64,withAlpha=true}
app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"}
local output="assets/enemies/baimen/fx/" .. id .. "/";app.fs.makeAllDirectories(output)
local tag=sprite:newTag(1,#m.frames);tag.name=id
sprite:saveAs(output .. "effect.aseprite")
local sheet=Image(width*#m.frames,height,ColorMode.RGB)
for i=1,#m.frames do
 local frame=Image(width,height,ColorMode.RGB);frame:drawSprite(sprite,i,Point(0,0));binary(frame)
 sheet:drawImage(frame,Point((i-1)*width,0))
end
sheet:saveAs(output .. "effect.png");sprite:close()
local metadata={version=1,effect_id=id,status="exported_pending_audit",frame_size={width,height},frames=#m.frames,fps=m.fps,
 anchor_px={m.anchor_px[1],m.anchor_px[2]},provenance="res://" .. base .. "export-manifest.json"}
local f=assert(io.open(output .. "manifest.json","w"));f:write(json.encode(metadata));f:close()
print("BAIMEN_ENEMY_FX_EXPORT_OK " .. id .. " frames=" .. #m.frames)
