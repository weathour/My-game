-- ImageGen authors all pixels; Aseprite only extracts, registers and quantizes.
-- Measurements are reviewed for each source revision, never inferred from a grid.
-- aseprite --batch --script-param id=F03 --script scripts/tools/import_baimen_women_art.lua
local root = "design/baimen-women-20261028/"
local file = assert(io.open(root .. "export-measurements.json", "r"))
local measurements = json.decode(file:read("*a")); file:close()
local pc = app.pixelColor
local function round(v) return math.floor(v + 0.5) end
local function binary(image)
  for pixel in image:pixels() do
    local c = pixel()
    pixel(pc.rgbaA(c) >= 128 and pc.rgba(pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c), 255) or 0)
  end
end
local function source(record)
  local image = Image{fromFile=root .. record.path}
  assert(image.width == record.size[1] and image.height == record.size[2], "source dimensions changed: " .. record.path)
  binary(image)
  return image
end
local function animation(images, fps, quantize)
  local sprite = Sprite(images[1].width, images[1].height)
  for i, im in ipairs(images) do
    if i > 1 then sprite:newEmptyFrame() end
    sprite:newCel(sprite.layers[1], i, im, Point(0, 0))
    sprite.frames[i].duration = 1 / fps
  end
  if quantize then
    app.activeSprite = sprite
    app.command.ColorQuantization{ui=false, maxColors=64, withAlpha=true}
    app.command.ChangePixelFormat{ui=false, format="indexed", dithering="none"}
  end
  return sprite
end
local function render(sprite, i)
  local image = Image(sprite.width, sprite.height)
  image:drawSprite(sprite, i, Point(0, 0))
  binary(image)
  return image
end
local function export(output, name, images, fps)
  local sprite = animation(images, fps, false)
  local tag = sprite:newTag(1, #images); tag.name = name
  sprite:saveAs(output .. name .. ".aseprite")
  local sheet = Image(#images * images[1].width, images[1].height)
  for i, im in ipairs(images) do sheet:drawImage(im, Point((i-1)*im.width, 0)) end
  sheet:saveAs(output .. name .. ".png")
  sprite:close()
end
local function components(image)
  local w,h = image.width,image.height
  local seen,found = {},{}
  for y=0,h-1 do for x=0,w-1 do
    local key=y*w+x
    if not seen[key] and image:getPixel(x,y)~=0 then
      local queue,head={key},1
      seen[key]=true
      local x0,y0,x1,y1=x,y,x,y
      while head<=#queue do
        local k=queue[head]; head=head+1
        local px,py=k%w,math.floor(k/w)
        x0=math.min(x0,px); x1=math.max(x1,px)
        y0=math.min(y0,py); y1=math.max(y1,py)
        for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
          local nx,ny=px+d[1],py+d[2]
          local nk=ny*w+nx
          if nx>=0 and nx<w and ny>=0 and ny<h and not seen[nk] and image:getPixel(nx,ny)~=0 then
            seen[nk]=true; queue[#queue+1]=nk
          end
        end
      end
      if #queue>=100 then
        local part=Image(x1-x0+1,y1-y0+1)
        for _,k in ipairs(queue) do
          local px,py=k%w,math.floor(k/w)
          part:drawPixel(px-x0,py-y0,image:getPixel(px,py))
        end
        found[#found+1]={image=part,x=x0,y=y0,w=x1-x0+1,h=y1-y0+1,area=#queue}
      end
    end
  end end
  return found
end
local function pose(parts, p, factor)
  local r=p.component_bbox
  local found
  for _,part in ipairs(parts) do
    if part.x==r[1] and part.y==r[2] and part.w==r[3]-r[1] and part.h==r[4]-r[2] then found=part; break end
  end
  assert(found and found.area==p.component_area,"component changed; remeasure " .. p.label)
  local cropped=Image(found.image)
  cropped:resize(round(cropped.width*factor), round(cropped.height*factor))
  local x = 96-round((p.hip-r[1])*factor)
  local y = 176-round((p.ground-r[2])*factor)
  assert(x >= 0 and y >= 0 and x+cropped.width <= 192 and y+cropped.height <= 192, "pose clips output at " .. p.label)
  local frame = Image(192, 192)
  frame:drawImage(cropped, Point(x, y))
  return frame
end
local count = 0
for _, character in ipairs(measurements.characters) do
  if not app.params["id"] or app.params["id"] == character.id then
    assert(character.review_status == "accepted_for_export", "source not reviewed: " .. character.id)
    assert(#character.poses == 20, "requires four idle, eight run, four attack and four cast poses")
    local output = "assets/players/baimen-women/" .. character.id .. "/"
    app.fs.makeAllDirectories(output)
    local sources = {combat={parts=components(source(character.combat)),factor=80/character.standing_body_height}}
    for name,record in pairs(character.extra_sources or {}) do
      sources[name]={parts=components(source(record)),factor=80/record.standing_body_height}
    end
    local factor = 80 / character.standing_body_height
    local frames = {}
    for _, p in ipairs(character.poses) do
      local input=assert(sources[p.source or "combat"],"unknown pose source")
      frames[#frames+1] = pose(input.parts, p, input.factor)
    end
    local shared = animation(frames, 10, true)
    for i=1, #frames do frames[i] = render(shared, i) end
    shared:close()
    for _, clip in ipairs({{"idle",1,4,5},{"run",5,12,11},{"attack",13,16,16},{"cast",17,20,10}}) do
      local images = {}
      for i=clip[2],clip[3] do images[#images+1] = frames[i] end
      export(output, clip[1], images, clip[4])
    end
    local head = source(character.portrait)
    head = Image(head, head:shrinkBounds())
    local head_factor = math.min(62/head.width,62/head.height)
    head:resize(round(head.width*head_factor),round(head.height*head_factor))
    local portrait = Image(64,64)
    portrait:drawImage(head, Point(math.floor((64-head.width)/2), math.floor((64-head.height)/2)))
    local editable = animation({portrait},1,true)
    editable:saveAs(output .. "head.aseprite")
    portrait = render(editable,1); editable:close()
    portrait:resize(128,128); portrait:saveAs(output .. "head.png")
    count = count + 1
    print("BAIMEN_CHARACTER_EXPORT_OK " .. character.id .. " 20 actor frames, 64px editable portrait, scale=" .. factor)
  end
end
assert(count > 0, "no accepted character matched; measurements required")
