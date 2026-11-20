"""Emit a temporary native Edit UI preview; no Play, saved Sources or map edits."""
import sys
from pathlib import Path
from build import module_bundle
fixture = r'''
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning(),'Stop Play before the static UI preview')
assert(not shared.QuartzPoolPreview,'An existing preview must be cleaned first')
local p=Profile.new(770001,58);p.run.wallet.Quartz=240;p.run.credits=240;p.run.packIndex=4
for _,v in ipairs({{'Q_POWER',2},{'Q_CARGO',2},{'Q_OVERDRIVE',1},{'Q_SPLIT',1}}) do
 local entry=Workshop.BY_ID[v[1]];local c=Workshop.card(entry,entry.tier);c.level=v[2];c.effects=Workshop.effects(c,c.level);table.insert(p.run.cards,c)
end
p.prestigePreview={earnings=270,saleRequired=360};p.workshop=Cards.workshopRows(p)
local gui=Instance.new('ScreenGui');gui.Name='QuartzPoolPreview';gui.IgnoreGuiInset=true;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=1000;gui.ResetOnSpawn=false
local sheet=Interface.panel(gui,UDim2.fromOffset(0,0),UDim2.fromOffset(740,629));sheet.Name='Sheet'
local title=Interface.text(sheet,UDim2.fromOffset(70,10),UDim2.fromOffset(570,42),'',30,nil,true)
Interface.icon(sheet,'crystal',UDim2.fromOffset(18,16),UDim2.fromOffset(40,40),Color3.fromRGB(29,132,211))
local subtitle=Interface.text(sheet,UDim2.fromOffset(18,58),UDim2.fromOffset(704,30),'240 Quartz · Duplicates stack',16)
local close=Interface.button(sheet,UDim2.new(1,-58,0,14),UDim2.fromOffset(42,42),'X',function() gui:Destroy();shared.QuartzPoolPreview=nil end)
ShopView.decorate(Interface,sheet,title,subtitle,close)
local body=Instance.new('ScrollingFrame');body.Name='Body';body.Position=UDim2.fromOffset(16,100);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.ScrollBarImageColor3=Color3.fromRGB(29,132,211);body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.Parent=sheet
local function render(width,height)
 sheet.Size=UDim2.fromOffset(width,height);sheet.AnchorPoint=Vector2.new(.5,.5);sheet.Position=UDim2.fromScale(.5,.5)
 title.Size=UDim2.fromOffset(width-150,42);subtitle.Size=UDim2.fromOffset(width-36,30);body.Size=UDim2.fromOffset(width-32,height-116)
 for _,n in ipairs(body:GetChildren()) do n:Destroy() end;body.CanvasPosition=Vector2.zero
 ShopView.render(Interface,body,{profile=p,width=width-36,canBuy=true,onPack=function() end,onBuy=function() end,onPrestige=function() end})
end
shared.QuartzPoolPreview={gui=gui,profile=p,render=render,cleanup=function() gui:Destroy();shared.QuartzPoolPreview=nil end}
gui.Parent=game:GetService('StarterGui')
render(740,629)
return {instances=#gui:GetDescendants(),running=false,temporary=true}
'''
Path(sys.argv[1]).write_text(module_bundle(('DroneCatalog','Consumables','Shops','DroneRoles','Profile','Cards','Interface','ShopView'))+fixture)
