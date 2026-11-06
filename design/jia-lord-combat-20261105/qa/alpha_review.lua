local pc=app.pixelColor
for _,name in ipairs({'dao','spear'}) do
 local image=Image{fromFile='design/jia-lord-combat-20261105/source/'..name..'-actions-v1.png'}
 for p in image:pixels() do local c=p();p(pc.rgbaA(c)>=128 and pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255) or 0) end
 image:saveAs('design/jia-lord-combat-20261105/qa/'..name..'-alpha-review.png')
end
