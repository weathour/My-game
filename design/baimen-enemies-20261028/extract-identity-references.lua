-- Crop the project's existing six named portrait cells for identity reference only.
-- This does not draw, replace or finalize any character design.
local source = Image{fromFile="assets/ui/chronicle/cards/named-transparent.png"}
assert(source.width == 1448 and source.height == 1086, "reference atlas changed")
local entries = {B18=0, B17=1, M03_WAR=2, M04_WAR=3, B16=4, B15=5}
for id,index in pairs(entries) do
  local output = "design/baimen-enemies-20261028/characters/" .. id .. "/references/"
  app.fs.makeAllDirectories(output)
  local cell = Image(source, Rectangle(index%4*362, math.floor(index/4)*543, 362, 543))
  cell:saveAs(output .. "current-identity.png")
  print("IDENTITY_REFERENCE_EXTRACTED " .. id)
end
