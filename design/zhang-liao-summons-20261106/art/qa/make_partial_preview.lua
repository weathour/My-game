local sheet=Image{fromFile='assets/enemies/baimen/zhang_liao_summons/B17-order_gaoshun.png'}
local board=Image(2304,1280,ColorMode.RGB)
for i=0,5 do
 local frame=Image(sheet,Rectangle(i*768,0,768,640));board:drawImage(frame,Point((i%3)*768,math.floor(i/3)*640))
 if i==0 then frame:saveAs('design/zhang-liao-summons-20261106/art/qa/B17-order_gaoshun-frame0-768x640.png')end
end
board:resize(1536,853)
board:saveAs('design/zhang-liao-summons-20261106/art/qa/B17-order_gaoshun-preview.png')
