local base='design/zhang-liao-summons-20261106/art/'
local output='assets/enemies/baimen/zhang_liao_summons/'
local f=assert(io.open(output..'manifest.json','r'));local m=json.decode(f:read('*a'));f:close()
local layouts={}
for key,clip in pairs(m.clips)do
 local sheet=Image{fromFile=output..clip.file};local w,h=clip.frame_size[1],clip.frame_size[2]
 local frames={};local x0,y0,x1,y1=w,h,0,0
 for i=0,clip.frames-1 do
  local frame=Image(sheet,Rectangle(i*w,0,w,h));local b=frame:shrinkBounds()
  x0=math.min(x0,b.x);y0=math.min(y0,b.y);x1=math.max(x1,b.x+b.width);y1=math.max(y1,b.y+b.height);frames[#frames+1]=frame
 end
 local crop=Rectangle(math.max(0,x0-24),math.max(0,y0-24),math.min(w,x1+24)-math.max(0,x0-24),math.min(h,y1+24)-math.max(0,y0-24))
 local columns=clip.frames==6 and 3 or (clip.frames==8 and 4 or 3);local rows=math.ceil(clip.frames/columns)
 local preview=Image(crop.width*columns,crop.height*rows,ColorMode.RGB)
 for i,frame in ipairs(frames)do
  local part=Image(frame,crop);preview:drawImage(part,Point(((i-1)%columns)*crop.width,math.floor((i-1)/columns)*crop.height))
 end
 local stem=clip.file:sub(1,-5);preview:saveAs(base..'qa/'..stem..'-preview.png')
 layouts[key]={file=stem..'-preview.png',columns=columns,rows=rows,frame_order='left-to-right then top-to-bottom, zero-based0..frames-1',crop_xywh={crop.x,crop.y,crop.width,crop.height},release_frame=clip.release_frame,contact_frame=clip.contact_frame}
end
local q=assert(io.open(base..'qa/preview-layouts.json','w'));q:write(json.encode(layouts));q:close()
print('SUMMON_ART_STATIC_PREVIEWS_OK10')
