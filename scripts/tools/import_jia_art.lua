-- ImageGen authors the art. Aseprite slices, registers, quantizes and exports it.
-- Run from repo root: aseprite --batch --script scripts/tools/import_jia_art.lua
local base = "design/jia-combat-20261027/source/"
local output = "assets/players/jia/"
local pc = app.pixelColor
local function round(v) return math.floor(v + 0.5) end
local function binary(image)
  for pixel in image:pixels() do
    local c = pixel()
    pixel(pc.rgbaA(c) >= 128 and pc.rgba(pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c), 255) or 0)
  end
end

-- The authored sheets have irregular gutters. Connected-component extraction
-- separates neighbouring weapons without slicing them at an assumed grid edge.
local function components(name)
  local image = Image { fromFile=base .. name }
  binary(image)
  local w, h = image.width, image.height
  local seen, found = {}, {}
  for y=0,h-1 do
    for x=0,w-1 do
      local key = y*w+x
      if not seen[key] and image:getPixel(x,y) ~= 0 then
        local queue, head = {key}, 1
        seen[key] = true
        local x0,y0,x1,y1 = x,y,x,y
        while head <= #queue do
          local k = queue[head]; head=head+1
          local px,py = k%w,math.floor(k/w)
          x0=math.min(x0,px); x1=math.max(x1,px)
          y0=math.min(y0,py); y1=math.max(y1,py)
          for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local nx,ny=px+d[1],py+d[2]
            local nk=ny*w+nx
            if nx>=0 and nx<w and ny>=0 and ny<h and not seen[nk] and image:getPixel(nx,ny)~=0 then
              seen[nk]=true; queue[#queue+1]=nk
            end
          end
        end
        if #queue > 10000 then
          local part=Image(x1-x0+1,y1-y0+1)
          for _, k in ipairs(queue) do
            local px,py=k%w,math.floor(k/w)
            part:drawPixel(px-x0,py-y0,image:getPixel(px,py))
          end
          found[#found+1]={image=part,x=x0,y=y0,bottom=y1+1}
        end
      end
    end
  end
  return found
end

local function pose(source, near_x, near_y, hip, ground, factor)
  local best, distance
  for _, p in ipairs(source) do
    local d=(p.x-near_x)^2+(p.y-near_y)^2
    if not distance or d<distance then best=p; distance=d end
  end
  assert(distance<40, "source changed; remeasure pose")
  local part=Image(best.image)
  part:resize(round(part.width*factor),round(part.height*factor))
  local x=96-round((hip-best.x)*factor)
  local y=176-round((ground-best.y)*factor)
  assert(x>=0 and y>=0 and x+part.width<=192 and y+part.height<=192,"pose clipped at "..near_x..","..near_y..": "..x..","..y.." + "..part.width..","..part.height)
  local frame=Image(192,192)
  frame:drawImage(part,Point(x,y))
  return frame
end

local dao=components("dao-v1.png")
local spear=components("spear-v1.png")
local attacks=components("attacks-v1.png")
local frames={}
local dao_poses={
  {64,32,166,346},{376,32,478,346},{689,32,791,346},{1003,33,1105,346},
  {42,377,180,650},{366,378,496,650},{676,379,810,650},{985,376,1124,650},
  {49,671,180,945},{359,675,496,945},{678,674,810,945},{997,675,1124,945},
  {22,948,157,1229},{343,953,470,1229},{635,982,773,1229},{1004,952,1105,1229}
}
for _, p in ipairs(dao_poses) do frames[#frames+1]=pose(dao,p[1],p[2],p[3],p[4],80/314) end
local spear_poses={
  {36,37,157,328},{336,36,460,328},{645,37,771,328},{948,36,1078,328},
  {30,352,171,624},{349,361,480,624},{653,354,790,624},{946,360,1095,624},
  {25,644,171,918},{342,646,480,918},{653,646,790,918},{957,648,1095,918}
}
for _, p in ipairs(spear_poses) do frames[#frames+1]=pose(spear,p[1],p[2],p[3],p[4],80/292) end
-- Reject the merged last-row source poses and the backward spearhead variants.
-- Use the clean right-facing anticipation, extension, lunge and recovery.
frames[#frames+1]=pose(spear,321,943,461,1206,80/292)
frames[#frames+1]=pose(attacks,466,556,610,839,80/330)
frames[#frames+1]=pose(attacks,890,581,1040,839,80/330)
frames[#frames+1]=pose(spear,321,943,461,1206,80/292)

local function animation(images,fps,quantize)
  local sprite=Sprite(images[1].width,images[1].height)
  for i, im in ipairs(images) do
    if i>1 then sprite:newEmptyFrame() end
    sprite:newCel(sprite.layers[1],i,im,Point(0,0))
    sprite.frames[i].duration=1/fps
  end
  if quantize then
    app.activeSprite=sprite
    app.command.ColorQuantization{ui=false,maxColors=64,withAlpha=true}
    app.command.ChangePixelFormat{ui=false,format="indexed",dithering="none"}
  end
  return sprite
end
local function render(sprite,i)
  local im=Image(sprite.width,sprite.height)
  im:drawSprite(sprite,i,Point(0,0))
  return im
end
local palette=animation(frames,10,true)
for i=1,#frames do frames[i]=render(palette,i) end
palette:close()
local function export(name,images,fps)
  local sprite=animation(images,fps,false)
  local tag=sprite:newTag(1,#images); tag.name=name
  sprite:saveAs(output .. name .. ".aseprite")
  local sheet=Image(#images*images[1].width,images[1].height)
  for i, im in ipairs(images) do sheet:drawImage(im,Point((i-1)*im.width,0)) end
  sheet:saveAs(output .. name .. ".png")
  sprite:close()
end
for _, clip in ipairs({
  {"dao-idle",1,4,5},{"dao-run",5,12,11},{"dao-attack",13,16,16},
  {"spear-idle",17,20,5},{"spear-run",21,28,11},{"spear-attack",29,32,16}
}) do
  local images={}
  for i=clip[2],clip[3] do images[#images+1]=frames[i] end
  export(clip[1],images,clip[4])
end
-- Dedicated face source preserves the grin at HUD scale.
local head=Image{fromFile=base .. "portrait-v1.png"}
binary(head)
head=Image(head,head:shrinkBounds())
head:resize(round(head.width*62/head.height),62)
local portrait=Image(64,64)
portrait:drawImage(head,Point(math.floor((64-head.width)/2),1))
local portrait_sprite=animation({portrait},1,true)
portrait=render(portrait_sprite,1)
portrait_sprite:close()
portrait:resize(128,128)
export("jia-head",{portrait},1)

local effects=Image{fromFile=base .. "vfx-v2.png"}
binary(effects)
local rows={
  {name="slash",y=120,h=370,pivot_y=285,x={20,290,650,975,1254},centers={165,480,802,1110}},
  {name="thrust",y=560,h=215,pivot_y=660,x={20,290,690,987,1254},centers={165,480,822,1110}},
  {name="sweep",y=840,h=330,pivot_y=1005,x={20,295,650,970,1254},centers={157,475,802,1104}}
}
for _, row in ipairs(rows) do
  local images={}
  for i=1,4 do
    local part=Image(effects,Rectangle(row.x[i],row.y,row.x[i+1]-row.x[i],row.h))
    part:resize(round(part.width*.3),round(part.height*.3))
    local im=Image(128,128)
    im:drawImage(part,Point(64-round((row.centers[i]-row.x[i])*.3),64-round((row.pivot_y-row.y)*.3)))
    images[#images+1]=im
  end
  local sprite=animation(images,18,true)
  for i=1,4 do images[i]=render(sprite,i) end
  sprite:close()
  export("vfx-"..row.name,images,18)
end
print("JIA_ART_IMPORT_OK 32 actor frames / 12 effect frames / portrait")
