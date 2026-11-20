-- Native Edit component checks. Temporary GUI only; no Play or profile mutation.
assert(not game:GetService('RunService'):IsRunning())
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
if shared.BackpackCheck then shared.BackpackCheck.close() end
local HUD=assert(loadstring(game.ReplicatedStorage.Shared.TacticalHUD.Source))()
local gui=Instance.new('ScreenGui');gui.Name='TemporaryBackpackCheck';gui.DisplayOrder=90;gui.Parent=game:GetService('CoreGui')
local root=Instance.new('Frame');root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=gui
local refs={root=root,gui=gui,resourceOrder={},resourceColors={}}
for _,name in ipairs({'resources','modal','recall','unload','test','evade','context','enemy','toast','cargoTrack','cargoText'}) do
 local item=Instance.new(name=='cargoText' and 'TextLabel' or (name=='recall' or name=='evade') and 'TextButton' or 'Frame')
 item.BackgroundTransparency=1;item.Parent=root;refs[name]=item
end
local hud=HUD.new(refs)
refs.resources.Position=UDim2.fromOffset(18,80);refs.resources.Size=UDim2.fromOffset(180,100)
hud.cargo.Size=UDim2.fromOffset(180,58);hud.growth.Visible=false;hud.dock.Visible=false
for _,w in hud.wallets do w.tile.Visible=false end
refs.cargoText.Position=UDim2.fromOffset(78,0);refs.cargoText.Size=UDim2.fromOffset(102,24);refs.cargoText.TextSize=18
local character=Instance.new('Model');local part=Instance.new('Part');part.Name='HumanoidRootPart';part.Parent=character
local lowFlash=false
local player={Character=character,GetAttribute=function(_,key) return key=='ReducedFlashing' and lowFlash end}
local world=Instance.new('Folder');world:SetAttribute('PackCounterPosition',Vector3.new(100,0,0))
local p={capacity=10,cargoUnits=3,run={id='fixture',cargo={}}}
local function draw(n,now)
 p.cargoUnits=n;refs.cargoText.Text=tostring(n)..'/10'
 return hud:updateBackpack(p,player,world,now,180,false)
end
local report={}
local function close() hud:destroy();gui:Destroy();character:Destroy();world:Destroy();shared.BackpackCheck=nil end
shared.BackpackCheck={close=close}
local ok,err=xpcall(function()
 assert(draw(3,10)==36 and not hud.sellGuide.Visible)
 assert(hud.cargoSlots[3].fill.Size.X.Scale==1 and hud.cargoSlots[4].fill.Size.X.Scale==0)
 assert(draw(8,11)==58 and hud.sellGuide.Visible)
 assert(hud.bagPickupAt==11 and hud.cargoSlots[8].fill.BackgroundColor3~=hud.cargoSlots[1].fill.BackgroundColor3)
 assert(draw(10,12)==58)
 assert(hud.cargoSlots[10].fill.Size.X.Scale==1)
 draw(0,13);assert(hud.bagPickupAt==nil and not hud.sellGuide.Visible)
 p.run.id='next';draw(6,14);assert(hud.bagPickupAt==nil)
 lowFlash=true;draw(8,15);assert(hud.cargoSlots[8].fill.BackgroundColor3==hud.cargoSlots[1].fill.BackgroundColor3)
 p.capacity=17;p.cargoUnits=8
 hud:updateBackpack(p,player,world,16,180,false)
 assert(hud.cargoSlots[5].fill.Size.X.Scale>0 and hud.cargoSlots[5].fill.Size.X.Scale<1)
 assert(#hud.cargoSlots==10)
 local a,c=HUD.backpackState({capacity=20,run={cargo={Amber=3,Ruby=4}}});assert(a==7 and c==20)
 assert(HUD.backpackState(nil)==0)
 p.capacity=10;draw(10,20)
 hud:updateBackpack(p,player,world,21,180,true);assert(not hud.sellGuide.Visible)
 draw(10,22)
 task.wait()
 assert(hud.sellGuide.TextBounds.X<=hud.sellGuide.AbsoluteSize.X,'Sell direction text clips')
 report.checks='empty, pickup, near-full, full, sale clear, prestige reset, reduced flashing, 17-slot upgrade, legacy profile, combat suppression, native text fit'
 report.guide=hud.sellGuide.Text
 report.width=hud.sellGuide.TextBounds.X
end,debug.traceback)
if not ok then close();error(err) end
close()
return report
