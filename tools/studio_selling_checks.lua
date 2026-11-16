-- Native Edit component check; no Play, gameplay commands, or saved profile edits.
assert(not game.RunService:IsRunning() and game.PlaceId==124078027733625)
if shared.SellingCheck then shared.SellingCheck.close() end
local source=game.StarterPlayer.StarterPlayerScripts.ClientDroneControl.Source
local function module(name,nextName)
 local start=assert(source:find('local '..name..' = (function()',1,true))
 local finish=assert(source:find('\nlocal '..nextName..' = (function()',start,true))
 return source:sub(start,finish-1)
end
local W,Finish,Sale=assert(loadstring(module('Workshop','Shops')..module('RockFinish','WorkEffects')..module('SaleView','CommandView')..'\nreturn Workshop,RockFinish,SaleView'))()
local HUD=assert(loadstring(game.ReplicatedStorage.Shared.TacticalHUD.Source))()
Finish.Gems.prepare()
local core=game:GetService('CoreGui')
local gui=Instance.new('ScreenGui');gui.Name='TemporarySellingHUD';gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=core
local root=Instance.new('Frame');root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=gui
local refs={gui=gui,root=root,profile=function() return {run={wallet={Quartz=1234},resources={Stone=500,Ruby=114,Diamond=107},shops={Quartz=true},quartzEarnings=100,index=1,packIndex=1}} end,
 hidden=function() return false end,starterReachable=function() return false end,depotApproach=function() return false end,
 resourceOrder=W.RESOURCE_ORDER,resourceNames=W.RESOURCE_NAMES,resourceColors=W.RESOURCE_COLORS}
for _,name in ipairs({'resources','modal','recall','unload','test','evade','context','enemy','toast','cargoTrack','cargoText'}) do
 local node=Instance.new(name=='cargoText' and 'TextLabel' or (name=='recall' or name=='unload' or name=='test' or name=='evade') and 'TextButton' or 'Frame')
 node.Name=name;node.BackgroundTransparency=1;node.Parent=root;refs[name]=node
end
refs.enemy.Visible=false
local hud=HUD.new(refs)
local fx=Instance.new('Folder');fx.Name='TemporarySellingCheck';fx.Parent=workspace
local world=Instance.new('Folder');world.Parent=fx
local resources=Instance.new('Folder');resources.Name='Resources';resources.Parent=world
local template=game.ServerStorage:FindFirstChild('MiningAwayCrystal')
if template then local rock=template:Clone();rock.Parent=resources;rock.Transparency=1 end
local reduced=false;local beats=0
local fakePlayer={PlayerGui=core,GetAttribute=function(_,name) return name=='ReducedEffects' and false or nil end}
local view=Sale.new({hud=hud,player=fakePlayer,world=world,parent=fx,reducedMotion=function() return reduced end,hidden=function() return false end,
 presentation={cameraBeat=function() beats+=1 end}})
local report={}
local bag={};for _,tier in ipairs(W.CRYSTAL_TIERS) do
 bag[W.saleCargo(tier.material,math.max(1,tier.value),true,7,100)]=1
 bag[W.saleCargo(tier.material,tier.value*8,false,100,0)]=1
end
local receipt={id='component-check',full=true,cargo=bag,cash=3069,resources={Stone=500,Amber=107,Ruby=107,Quartz=107,Violet=107,Diamond=107}}
local camera=workspace.CurrentCamera;local oldCamera=camera.CFrame
local closed=false
local function close()
 if closed then return end;closed=true;view:destroy();hud:destroy();gui:Destroy();fx:Destroy();camera.CFrame=oldCamera;shared.SellingCheck=nil
end
shared.SellingCheck={close=close,view=view,hud=hud,report=report}
local ok,err=xpcall(function()
 hud:update(camera.ViewportSize,world,false);view:receive(receipt);view:receive(receipt)
 assert(#view.queue==1,'duplicate receipt queued')
 view:update(1/60);hud:update(camera.ViewportSize,world,false)
 assert(#view.tiles==10 and view.tiles[1].item.stone and view.tiles[10].item.material=='Diamond')
 assert(view.focus and view.focus.Parent==game.Lighting)
 for _,tile in ipairs(view.tiles) do assert(tile.ore:IsA('BasePart') and not tile.ore.CanCollide) end
 for _,tile in ipairs(view.tiles) do if not tile.item.stone then assert(tile.gem,'native gem fallback') end end
 view.started=os.clock()-.41;view:update(1/60)
 assert(view.tiles[1].sold and not view.tiles[2].sold and #view.flights==3 and beats==1)
 view.started=os.clock()-1.7;view:update(1/60)
 assert(not view.active and not view.focus and beats==10)
 for _,flight in ipairs(view.flights) do flight.at=os.clock()-1 end
 view:update(1/60);assert(#view.flights==0)
 report.sortedObjects=10;report.screenBeats=beats;report.currencyArrivals=true;report.cleanup=true
 reduced=true
 receipt.id='reduced';view:receive(receipt);view:update(1/60);view.started=os.clock()-2;view:update(1/60)
 assert(beats==10,'reduced motion shook camera')
 report.reducedMotion=true
 view:clearGrid();view.flights={};for _,child in ipairs(view.gui:GetChildren()) do if child~=view.title then child:Destroy() end end
 receipt.id='capture';view:receive(receipt);view:update(1/60)
 view.started=os.clock()-.25;view:update(1/60);hud:update(camera.ViewportSize,world,false)
 report.scope='Native Edit component checks; live selling and multiplayer not playtested'
end,debug.traceback)
if not ok then close();error(err) end
return report
