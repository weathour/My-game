local head=Image(384,384,ColorMode.RGB)
local attack=Image(768,1728,ColorMode.RGB)
local idle=Image(768,1728,ColorMode.RGB)
local move=Image(768,1728,ColorMode.RGB)
for i=10,18 do
 local dir='assets/players/chronicle-cast/'..string.format('N%02d',i)..'/'
 local n=i-10
 head:drawImage(Image{fromFile=dir..'head.png'},Point((n%3)*128,math.floor(n/3)*128))
 attack:drawImage(Image{fromFile=dir..'attack.png'},Point(0,n*192))
 idle:drawImage(Image{fromFile=dir..'idle.png'},Point(0,n*192))
 move:drawImage(Image{fromFile=dir..'move.png'},Point(0,n*192))
end
head:saveAs('design/skill-presentation-20261105/characters/N10/qa-heads-N10-N18.png')
attack:saveAs('design/skill-presentation-20261105/characters/N10/qa-attacks-N10-N18.png')
idle:saveAs('design/skill-presentation-20261105/characters/N10/qa-idle-N10-N18.png')
move:saveAs('design/skill-presentation-20261105/characters/N10/qa-move-N10-N18.png')
