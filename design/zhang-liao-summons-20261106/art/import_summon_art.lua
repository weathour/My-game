-- ImageGen authors original poses. Aseprite alone extracts, registers, palettes and exports.
-- Partial runs write only partial-manifest.json in art/; --script-param publish=true
-- requires the complete reviewed60 actor+16 effect frames before publishing runtime manifest.
local base='design/zhang-liao-summons-20261106/art/'
local output='assets/enemies/baimen/zhang_liao_summons/'
local function read(path) local f=assert(io.open(path,'r'));local v=json.decode(f:read('*a'));f:close();return v end
local m=read(app.params['measurements'] or base..'measurements.json')
assert(m.version==1 and m.review_status=='accepted_for_export','reviewed measured source required')
local old_palettes=read(base..'legacy-palettes.json')
local pc=app.pixelColor
local function round(v)return math.floor(v+.5)end
local function binary(image)
 for p in image:pixels() do local c=p();p(pc.rgbaA(c)>=128 and pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255) or 0)end
end
local function rectkey(b)return string.format('%d,%d,%d,%d',b[1],b[2],b[3],b[4])end
local function components(image)
 local w,h=image.width,image.height;local seen,found={},{}
 for y=0,h-1 do for x=0,w-1 do local index=y*w+x
  if not seen[index] and image:getPixel(x,y)~=0 then
   local queue,head={index},1;seen[index]=true;local x0,y0,x1,y1=x,y,x,y
   while head<=#queue do
    local k=queue[head];head=head+1;local px,py=k%w,math.floor(k/w)
    x0=math.min(x0,px);y0=math.min(y0,py);x1=math.max(x1,px);y1=math.max(y1,py)
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do local nx,ny=px+d[1],py+d[2];local nk=ny*w+nx
     if nx>=0 and nx<w and ny>=0 and ny<h and not seen[nk] and image:getPixel(nx,ny)~=0 then seen[nk]=true;queue[#queue+1]=nk end
    end
   end
   local bounds={x0,y0,x1+1,y1+1};local part=Image(x1-x0+1,y1-y0+1,ColorMode.RGB)
   for _,k in ipairs(queue)do local px,py=k%w,math.floor(k/w);part:drawPixel(px-x0,py-y0,image:getPixel(px,py))end
   found[rectkey(bounds)]={image=part,area=#queue,bbox=bounds}
  end
 end end
 return found
end
local sources={}
for name,s in pairs(m.sources)do
 assert(s.sha256 and #s.sha256==64,'source SHA required')
 local path=s.path:sub(1,1)=='/' and s.path or base..s.path
 local im=Image{fromFile=path};assert(im.width==s.size[1] and im.height==s.size[2],'source dimensions changed '..name)
 binary(im);sources[name]={parts=components(im),record=s}
end
local ordered={};for name,_ in pairs(m.clips)do ordered[#ordered+1]=name end;table.sort(ordered)
local pose_context={};local groups={}
for _,name in ipairs(ordered)do local clip=m.clips[name]
 assert(clip.file:match('^[A-Za-z0-9_.:-]+%.png$'),'unsafe filename')
 assert(#clip.poses==clip.frames and clip.frames>0 and clip.fps>0,'clip frame budget mismatch '..name)
 local group=clip.kind=='effect' and ('fx-'..clip.role) or clip.visual_id
 if not groups[group]then groups[group]={images={},pose_ids={},kind=clip.kind,visual_id=clip.visual_id,width=clip.frame_size[1],height=clip.frame_size[2]}end
 for _,id in ipairs(clip.poses)do assert(not pose_context[id],'source pose reused across clips '..id);pose_context[id]=clip end
end
local rendered={}
for _,p in ipairs(m.poses)do
 local clip=assert(pose_context[p.id],'unmapped reviewed pose '..p.id);local input=assert(sources[p.source],'unknown source')
 local s=input.record;local factor=clip.kind=='effect' and assert(s.fixed_scale,'effect fixed source scale required') or clip.body_height_px/assert(s.standing_body_height,'source body calibration required')
 assert(factor>0,'invalid fixed scale')
 local chosen={};local seen={};local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
 for _,selection in ipairs(p.components)do local k=rectkey(selection.bbox);assert(not seen[k],'duplicate part');seen[k]=true
  local part=assert(input.parts[k],'source component changed '..p.id..' '..k);assert(part.area==selection.area,'component area changed '..p.id)
  chosen[#chosen+1]=part;x0=math.min(x0,part.bbox[1]);y0=math.min(y0,part.bbox[2]);x1=math.max(x1,part.bbox[3]);y1=math.max(y1,part.bbox[4])
 end
 assert(#chosen>0,'empty source pose')
 local joined=Image(x1-x0,y1-y0,ColorMode.RGB)
 for _,part in ipairs(chosen)do joined:drawImage(part.image,Point(part.bbox[1]-x0,part.bbox[2]-y0))end
 joined:resize(math.max(1,round(joined.width*factor)),math.max(1,round(joined.height*factor)))
 local ax,ay=clip.anchor_px[1],clip.anchor_px[2]
 local x=ax-round((p.anchor_source[1]-x0)*factor);local y=ay-round((p.anchor_source[2]-y0)*factor)
 assert(x>0 and y>0 and x+joined.width<clip.frame_size[1] and y+joined.height<clip.frame_size[2],'pose clips or touches canvas '..p.id)
 local frame=Image(clip.frame_size[1],clip.frame_size[2],ColorMode.RGB);frame:drawImage(joined,Point(x,y));binary(frame)
 rendered[p.id]=frame;local group=clip.kind=='effect' and ('fx-'..clip.role) or clip.visual_id
 groups[group].images[#groups[group].images+1]=frame;groups[group].pose_ids[#groups[group].pose_ids+1]=p.id
end
local function animation(images,fps)
 local sprite=Sprite(images[1].width,images[1].height,ColorMode.RGB)
 for i,image in ipairs(images)do if i>1 then sprite:newEmptyFrame()end;sprite:newCel(sprite.layers[1],i,image,Point(0,0));sprite.frames[i].duration=1/fps end
 return sprite
end
app.fs.makeAllDirectories(output)
for group,data in pairs(groups)do
 local sprite=animation(data.images,10);app.activeSprite=sprite
 if data.kind=='effect'then
  app.command.ColorQuantization{ui=false,maxColors=64,withAlpha=true}
 else
  local colors=assert(old_palettes[data.visual_id],'legacy approved palette missing').rgb
  assert(#colors<=63,'legacy colors exceed63 opaque')
  local palette=Palette(#colors+1);palette:setColor(0,Color{r=0,g=0,b=0,a=0})
  for i,c in ipairs(colors)do palette:setColor(i,Color{r=c[1],g=c[2],b=c[3],a=255})end
  sprite:setPalette(palette)
 end
 app.command.ChangePixelFormat{ui=false,format='indexed',dithering='none'}
 if data.kind~='effect'then sprite:saveAs(output..group..'-actor.aseprite')end
 for i,id in ipairs(data.pose_ids)do local image=Image(data.width,data.height,ColorMode.RGB);image:drawSprite(sprite,i,Point(0,0));binary(image);rendered[id]=image end
 sprite:close()
end
local runtime={version=1,status='exported_pending_audit',provenance='res://'..base..'export-manifest.json',clips={}}
local actors,effects=0,0
for _,name in ipairs(ordered)do local clip=m.clips[name];local images={}
 for _,id in ipairs(clip.poses)do images[#images+1]=assert(rendered[id],'unrendered pose '..id)end
 local sprite=animation(images,clip.fps);local tag=sprite:newTag(1,#images);tag.name=clip.role
 local stem=clip.file:sub(1,-5);sprite:saveAs(output..stem..'.aseprite')
 local sheet=Image(clip.frame_size[1]*#images,clip.frame_size[2],ColorMode.RGB)
 for i,image in ipairs(images)do sheet:drawImage(image,Point((i-1)*clip.frame_size[1],0))end
 sheet:saveAs(output..clip.file);sprite:close()
 local value={};for k,v in pairs(clip)do if k~='poses'then value[k]=v end end
 value.frame_size={clip.frame_size[1],clip.frame_size[2]};value.anchor_px={clip.anchor_px[1],clip.anchor_px[2]}
 if clip.world_size then value.world_size={clip.world_size[1],clip.world_size[2]}end
 runtime.clips[name]=value
 if clip.kind=='effect'then effects=effects+#images else actors=actors+#images end
end
if app.params['publish']=='true'then
 assert(actors==60 and effects==16 and #ordered==10,'complete60 actor+16 FX frame package required')
 local f=assert(io.open(output..'manifest.json','w'));f:write(json.encode(runtime));f:close()
else
 local f=assert(io.open(base..'partial-manifest.json','w'));f:write(json.encode(runtime));f:close()
end
print('ZHANG_LIAO_SUMMON_ART_EXPORT_OK actors='..actors..' effects='..effects..' clips='..#ordered)
