for k=1,9 do
 local id=string.format('N%02d',k)
 local sheet=Image(512,576,ColorMode.RGB)
 for row,name in ipairs({'idle','move','attack','special'}) do
  local image=Image{fromFile='assets/players/chronicle-cast/'..id..'/'..name..'.png'}
  for f=0,3 do
   local frame=Image(image,Rectangle(f*192+32,64,128,128))
   sheet:drawImage(frame,Point(f*128,(row-1)*128))
  end
 end
 local head=Image{fromFile='assets/players/chronicle-cast/'..id..'/head.png'}
 head:resize(64,64)
 sheet:drawImage(head,Point(224,512))
 sheet:resize(1024,1152)
 sheet:saveAs('design/skill-presentation-20261105/characters/'..id..'/qa-contact-sheet.png')
end
