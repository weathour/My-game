local id='M07'
local sheet=Image(768,960,ColorMode.RGB)
for i,clip in ipairs({'idle','move','attack','special','hit'}) do
 local im=Image{fromFile='assets/players/chronicle-cast/'..id..'/'..clip..'.png'}
 sheet:drawImage(im,Point(0,(i-1)*192))
end
sheet:saveAs('design/skill-presentation-20261105/characters/'..id..'/export-contact-sheet.png')
