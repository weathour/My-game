local sprite=Sprite{fromFile='assets/players/jia-campaign/actor.aseprite'}
for weapon=0,1 do
 local sheet=Image(544,768,ColorMode.RGB)
 for i=1,24 do
  local frame=Image(256,256,ColorMode.RGB)
  frame:drawSprite(sprite,weapon*24+i,Point(0,0))
  local cut=Image(frame,Rectangle(64,128,136,128))
  sheet:drawImage(cut,Point(((i-1)%4)*136,math.floor((i-1)/4)*128))
 end
 sheet:resize(1088,1536)
 sheet:saveAs('design/jia-lord-combat-20261105/qa/'..(weapon==0 and 'dao' or 'spear')..'-runtime-contact-sheet.png')
end
sprite:close()
