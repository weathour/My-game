-- ImageGen authors pixels; Aseprite extracts reviewed connected parts and exports.
-- Required: python3 design/baimen-enemies-20261028/audit_exports.py --id=E01 --preflight
-- aseprite --batch --script-param id=E01 --script scripts/tools/import_baimen_enemy_art.lua
-- Optional measurements=/absolute/measurements.json output=/tmp/isolated-test (fixtures).
local id = assert(app.params["id"], "--script-param id=<visual_id> required")
assert(id:match("^[A-Z0-9_]+$"), "invalid visual id")
local base = "design/baimen-enemies-20261028/characters/" .. id .. "/"
local measurement_path = app.params["measurements"] or base .. "measurements.json"
local f = assert(io.open(measurement_path, "r")); local m = json.decode(f:read("*a")); f:close()
assert(m.version == 1 and m.id == id, "measurement identity/version mismatch")
assert(m.review_status == "accepted_for_export", "source must be reviewed before export")
local output = app.params["output"] or "assets/enemies/baimen/" .. id
output = output:gsub("/$", "") .. "/"
app.fs.makeAllDirectories(output)
local parent = measurement_path:match("^(.*[/\\])") or ""
local pc = app.pixelColor
local function source_path(path)
  return path:sub(1,1) == "/" and path or parent .. path
end
local function round(n) return math.floor(n + .5) end
local function key(r) return string.format("%d,%d,%d,%d",r[1],r[2],r[3],r[4]) end
local function binary(image)
  for pixel in image:pixels() do
    local c = pixel()
    pixel(pc.rgbaA(c) >= 128 and pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255) or 0)
  end
end
local function components(image)
  local w,h=image.width,image.height
  local seen, found = {}, {}
  for y=0,h-1 do for x=0,w-1 do
    local index=y*w+x
    if not seen[index] and image:getPixel(x,y) ~= 0 then
      local queue,head={index},1
      local x0,y0,x1,y1=x,y,x,y
      seen[index]=true
      while head<=#queue do
        local k=queue[head]; head=head+1
        local px,py=k%w,math.floor(k/w)
        x0=math.min(x0,px); y0=math.min(y0,py); x1=math.max(x1,px); y1=math.max(y1,py)
        for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
          local nx,ny=px+d[1],py+d[2]
          local nk=ny*w+nx
          if nx>=0 and nx<w and ny>=0 and ny<h and not seen[nk] and image:getPixel(nx,ny)~=0 then
            seen[nk]=true; queue[#queue+1]=nk
          end
        end
      end
      local part=Image(x1-x0+1,y1-y0+1,ColorMode.RGB)
      for _,k in ipairs(queue) do
        local px,py=k%w,math.floor(k/w)
        part:drawPixel(px-x0,py-y0,image:getPixel(px,py))
      end
      local bounds={x0,y0,x1+1,y1+1}
      found[key(bounds)]={image=part,bbox=bounds,area=#queue}
    end
  end end
  return found
end
local inputs={}
for name,record in pairs(m.sources) do
  assert(record.sha256 and #record.sha256==64, "source sha256 required; run preflight")
  local image=Image{fromFile=source_path(record.path)}
  assert(image.width==record.size[1] and image.height==record.size[2], "source dimensions changed " .. name)
  assert(record.standing_body_height>0, "source body calibration required " .. name)
  binary(image)
  inputs[name]={parts=components(image),factor=m.canvas.body_height_px/record.standing_body_height}
end
local width,height=m.canvas.size[1],m.canvas.size[2]
local anchor=m.canvas.anchor
assert(width>0 and height>0 and anchor[1]>=0 and anchor[1]<=width and anchor[2]>=0 and anchor[2]<=height, "invalid frame/anchor")
local poses,ordered={},{}
for _,p in ipairs(m.poses) do
  assert(not poses[p.id], "duplicate pose id " .. p.id)
  local input=assert(inputs[p.source], "unknown source for " .. p.id)
  assert(#p.components>0, "empty pose " .. p.id)
  local chosen,seen={},{}
  local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
  for _,part in ipairs(p.components) do
    local k=key(part.bbox)
    assert(not seen[k], "duplicate component in " .. p.id); seen[k]=true
    local actual=assert(input.parts[k], "component shape changed; remeasure " .. p.id .. " " .. k)
    assert(actual.area==part.area, "component area changed; remeasure " .. p.id)
    chosen[#chosen+1]=actual
    x0=math.min(x0,part.bbox[1]); y0=math.min(y0,part.bbox[2]); x1=math.max(x1,part.bbox[3]); y1=math.max(y1,part.bbox[4])
  end
  local joined=Image(x1-x0,y1-y0,ColorMode.RGB)
  for _,part in ipairs(chosen) do joined:drawImage(part.image, Point(part.bbox[1]-x0,part.bbox[2]-y0)) end
  joined:resize(math.max(1,round(joined.width*input.factor)), math.max(1,round(joined.height*input.factor)))
  local x=anchor[1]-round((p.anchor_source[1]-x0)*input.factor)
  local y=anchor[2]-round((p.anchor_source[2]-y0)*input.factor)
  assert(x>=0 and y>=0 and x+joined.width<=width and y+joined.height<=height, "pose clips output " .. p.id)
  local frame=Image(width,height,ColorMode.RGB)
  frame:drawImage(joined, Point(x,y)); binary(frame)
  poses[p.id]=frame; ordered[#ordered+1]=p.id
end
assert(#ordered>0, "no reviewed poses")
local function animation(images,fps)
  local sprite=Sprite(width,height,ColorMode.RGB)
  for i,image in ipairs(images) do
    if i>1 then sprite:newEmptyFrame() end
    sprite:newCel(sprite.layers[1],i,image,Point(0,0))
    sprite.frames[i].duration=1/fps
  end
  return sprite
end
local all={}; for _,name in ipairs(ordered) do all[#all+1]=poses[name] end
local shared=animation(all,10)
app.activeSprite=shared
app.command.ColorQuantization{ui=false,maxColors=64,withAlpha=true}
app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"}
shared:saveAs(output .. "actor.aseprite")
for i,name in ipairs(ordered) do
  local image=Image(width,height,ColorMode.RGB)
  image:drawSprite(shared,i,Point(0,0)); binary(image); poses[name]=image
end
shared:close()
local manifest={version=1,visual_id=id,status="exported_pending_audit",body_height_px=m.canvas.body_height_px,
  anchor_px={anchor[1],anchor[2]},faces_left=m.faces_left or false,action_clips={},clips={},provenance="res://" .. base .. "export-manifest.json"}
for action,clip in pairs(m.action_clips or {}) do
  assert(m.clips[clip], "action maps unknown clip " .. action)
  manifest.action_clips[action]=clip
end
if next(manifest.action_clips)==nil then manifest.action_clips=nil end
local clip_names={"idle","move","attack","special","hit"}
local extra_names={}
for name,_ in pairs(m.clips) do
  if name~="idle" and name~="move" and name~="attack" and name~="special" and name~="hit" then extra_names[#extra_names+1]=name end
end
table.sort(extra_names)
for _,name in ipairs(extra_names) do clip_names[#clip_names+1]=name end
for _,name in ipairs(clip_names) do
  assert(name:match("^[a-z0-9_]+$"), "invalid clip filename")
  local clip=assert(m.clips[name], "required clip " .. name)
  assert(#clip.poses>0 and clip.fps>0, "invalid clip " .. name)
  local frames={}
  for _,pose_id in ipairs(clip.poses) do frames[#frames+1]=assert(poses[pose_id], "unknown pose " .. pose_id) end
  local sprite=animation(frames,clip.fps)
  local tag=sprite:newTag(1,#frames); tag.name=name
  sprite:saveAs(output .. name .. ".aseprite")
  local sheet=Image(width*#frames,height,ColorMode.RGB)
  for i,image in ipairs(frames) do sheet:drawImage(image,Point((i-1)*width,0)) end
  sheet:saveAs(output .. name .. ".png"); sprite:close()
  manifest.clips[name]={file=name .. ".png",frame_size={width,height},frames=#frames,fps=clip.fps,
    windup_frame=clip.windup_frame or 0,contact_frame=clip.contact_frame or math.min(1,#frames-1)}
end
local portrait_path=source_path(m.portrait.path)
local portrait=Image{fromFile=portrait_path}
assert(portrait.width==m.portrait.size[1] and portrait.height==m.portrait.size[2], "portrait dimensions changed")
-- Preserve the full standing illustration's original RGBA bytes; no avatar crop.
local from=assert(io.open(portrait_path,"rb")); local bytes=from:read("*a"); from:close()
local to=assert(io.open(output .. "portrait.png","wb")); to:write(bytes); to:close()
local editable=app.open(portrait_path); editable:saveAs(output .. "portrait.aseprite"); editable:close()
local metadata=assert(io.open(output .. "manifest.json","w")); metadata:write(json.encode(manifest)); metadata:close()
print("BAIMEN_ENEMY_EXPORT_OK " .. id .. " poses=" .. #ordered .. " shared_palette<=64")
