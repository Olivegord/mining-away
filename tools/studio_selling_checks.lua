-- Native Edit component check; no Play, gameplay commands, or saved profile edits.
assert(not game.RunService:IsRunning() and game.PlaceId==124078027733625)
if shared.SellingCheck then shared.SellingCheck.close() end
local source=game.StarterPlayer.StarterPlayerScripts.ClientDroneControl.Source
local function module(name,nextName)
 local start=assert(source:find('local '..name..' = (function()',1,true))
 local finish=assert(source:find('\nlocal '..nextName..' = (function()',start,true))
 return source:sub(start,finish-1)
end
local W,Finish,Sale=assert(loadstring(
 module('EnergyDisc','Workshop')..module('Workshop','Shops')..module('Shops','Feel')..module('RockFinish','WorkEffects')
 ..'\nlocal BeamVFX={reduced=function() return false end,near=function() return true end}\n'
 ..module('RoleVisuals','NomadView')..module('SaleView','CommandView')..'\nreturn Workshop,RockFinish,SaleView'))()
local HUD=assert(loadstring(game.ReplicatedStorage.Shared.TacticalHUD.Source))()
Finish.Gems.prepare()
local core=game:GetService('CoreGui')
local gui=Instance.new('ScreenGui');gui.Name='TemporarySellingHUD';gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=core
local root=Instance.new('Frame');root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=gui
local snapshot={revision=4,run={id='test-sale-run',wallet={Quartz=1234},resources={},shops={Quartz=true},quartzEarnings=100,index=1,packIndex=1}}
local refs={gui=gui,root=root,profile=function() return snapshot end,
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
local reduced=false;local beats=0;local committed=0;local confirmed;local cues={}
local fakePlayer={PlayerGui=core,GetAttribute=function(_,name) return name=='ReducedEffects' and false or nil end}
local view=Sale.new({hud=hud,player=fakePlayer,world=world,parent=fx,reducedMotion=function() return reduced end,hidden=function() return false end,
 presentation={cameraBeat=function() beats+=1 end},confirm=function(id) confirmed=id end,
 onCommitted=function() committed+=1 end,cancel=function() end,audio={play=function(_,name) cues[name]=(cues[name] or 0)+1 end}})
local report={}
local bag={};for _,tier in ipairs(W.CRYSTAL_TIERS) do
 bag[W.saleCargo(tier.material,math.max(1,tier.value),true,7,100)]=1
 bag[W.saleCargo(tier.material,tier.value*8,false,100,0)]=1
end
local receipt={id='component-check',runId=snapshot.run.id,revision=5,full=true,cargo=bag,cash=3069,resources={Stone=500,Amber=107,Ruby=107,Quartz=107,Violet=107,Diamond=107}}
local camera=workspace.CurrentCamera;local oldCamera=camera.CFrame
local closed=false
local function close()
 if closed then return end;closed=true;view:destroy();hud:destroy();gui:Destroy();fx:Destroy();camera.CFrame=oldCamera;shared.SellingCheck=nil
end
shared.SellingCheck={close=close,view=view,hud=hud,report=report}
local ok,err=xpcall(function()
 hud:update(camera.ViewportSize,world,false)
 view:receive({kind='preview',id=receipt.id,cargo=bag});view:receive({kind='preview',id=receipt.id,cargo=bag})
 view.started=os.clock()-1;view:update(1/60)
 assert(#view.tiles==10 and view.tiles[1].item.stone and view.tiles[10].item.material=='Diamond')
 assert(view.prompt.Visible and view.focus and view.focus.Parent==game.Lighting)
 assert(beats==0 and #view.flights==0 and not view.cascadeAt,'preview cashed out without E')
 for _,tile in ipairs(view.tiles) do
  assert(tile.ore:IsA('BasePart') and not tile.ore.CanCollide)
  if not tile.item.stone then assert(tile.gem,'native gem fallback') end
 end
 local sample=view.tiles[1].ore
 local center=camera:WorldToViewportPoint(sample.Position)
 local right=camera:WorldToViewportPoint(sample.Position+camera.CFrame.RightVector*sample.Size.X)
 report.rockWidthPixels=math.floor(right.X-center.X)
 assert(report.rockWidthPixels>camera.ViewportSize.Y*.21,'rock is too small relative to the screen')
 view:confirm();view:confirm();assert(confirmed==receipt.id and view.pendingAt and cues.sale_confirm==1)
 snapshot.revision=5;snapshot.run.wallet.Quartz+=receipt.cash;snapshot.run.resources=table.clone(receipt.resources)
 snapshot.recentSales={receipt};view:receiveProfile(snapshot);view:receive(receipt)
 assert(not view.prompt.Visible and committed==1,'profile and remote duplicated the sale')
 hud:update(camera.ViewportSize,world,false)
 assert(hud.wallets[1].value.Text=='1234' and hud.wallets[2].value.Text=='0','wallet jumped before tokens arrived')
 view:update(1/60);assert(beats==0 and #view.flights==0,'confirmation has no anticipation beat')
 view.cascadeAt=os.clock()-.40;view:update(1/60);assert(beats==0 and view.firstHit>=.55)
 assert(view.breakInterval>=.22 and view.gemWindup>=.10)
 view.cascadeAt=os.clock()-.60;view:update(1/60)
 local first=view.tiles[1]
 assert(first.hitAt and not first.sold and not view.tiles[2].hitAt and #view.flights==5 and beats==1)
 local money,amber,stone=view.flights[1],view.flights[2],view.flights[4]
 assert(money.view.Name=='MoneyCoin' and amber.view.Name=='MaterialFleck')
 assert(view.readouts[1].view.Text=='+$1' and view.readouts[2].view.Text=='+0.07 Amber chips')
 local cashLabel=view.readouts[1]
 assert(cashLabel.view.TextColor3.G>cashLabel.view.TextColor3.R)
 assert(cashLabel.view.UITextSizeConstraint.MaxTextSize>=33 and view.readouts[2].view.UITextSizeConstraint.MaxTextSize>=23)
 assert(cashLabel.duration>=1.6)
 local function point(token) return Vector2.new(token.view.Position.X.Offset,token.view.Position.Y.Offset) end
 view:updatePayouts(amber.at+.01,false);local a=point(amber)
 view:updatePayouts(amber.at+.06,false);local b=point(amber)
 view:updatePayouts(amber.at+.11,false);local c=point(amber)
 assert((b-a).Magnitude>(c-b).Magnitude and (c-b).Magnitude>0,'drift failed to decelerate continuously')
 view:updatePayouts(money.at+.24,false);assert(not money.pullAt)
 view:updatePayouts(money.at+.46,false)
 assert(money.pullAt and not amber.pullAt and view.readouts[1].view.TextTransparency==0)
 view:updatePayouts(money.pullAt+money.duration+.01,false);hud:update(camera.ViewportSize,world,false)
 assert(cashLabel.view.TextTransparency==0,'cash text faded before arrival')
 assert(hud.wallets[1].value.Text=='1235' and cues.sale_credit==1 and not amber.pullAt)
 local burst=assert(fx:FindFirstChild('GemRewardParticles'))
 assert(burst.AirborneSparks.Lifetime.Min>=.81 and burst.ImpactAccent.Lifetime.Max>1.45,'gem particles need a visible tail')
 view.cascadeAt=os.clock()-4
 view.lastBreakAt=os.clock()-1
 view:update(1/60)
 assert(not first.sold and not view.tiles[2].hitAt and beats==1,'a stalled schedule began the next rock prematurely')
 for index=1,#view.tiles do
  local tile=view.tiles[index]
  assert(tile.hitAt and not tile.sold)
  tile.hitAt=os.clock()-.09;view.lastBreakAt=os.clock()-.40
  view:update(1/60)
  assert(tile.sold)
  if index<#view.tiles then
   assert(not view.tiles[index+1].hitAt)
   view:update(1/60);assert(view.tiles[index+1].hitAt and beats==index+1)
   assert(not view.tiles[index+2] or not view.tiles[index+2].hitAt)
  end
  if index==1 then assert(burst.Parent==fx,'breaking the next rock cleared the prior gem particles') end
 end
 assert(view.active and beats==10)
 local wave=view.active.dustAt
 view:updatePayouts(wave+.12,false)
 assert(stone.pullAt and not amber.pullAt,'material types did not get separate pull waves')
 view:updatePayouts(wave+2,false);view:updatePayouts(wave+3,false)
 view.tiles[10].hitAt=os.clock()-1.6;view:update(1/60)
 hud:update(camera.ViewportSize,world,false)
 assert(not view.active and not view.focus and #view.flights==0 and #view.readouts==0)
 assert(cues.sale_credit>1 and cues.sale_dust_credit>0 and cues.sale_finish==1)
 assert(hud.wallets[1].value.Text=='4303' and hud.wallets[2].value.Text=='5','arrival credits missed the authoritative totals')
 local pending={id='receipt-first',runId=snapshot.run.id,revision=6}
 hud:beginSale(pending,{Money=9});hud:currencyHit(pending.id,'Money',4,false)
 local offset=hud:pendingSaleBalances(snapshot,os.clock());assert(offset.Money==4)
 snapshot.revision=6;snapshot.run.wallet.Quartz+=9
 offset=hud:pendingSaleBalances(snapshot,os.clock());assert(offset.Money==-5)
 hud:currencyHit(pending.id,'Money',5,false)
 offset=hud:pendingSaleBalances(snapshot,os.clock());assert(offset.Money==nil)
 report.deceleratingDrift=true;report.materialWaves=true;report.replicationOrder=true
 report.sortedObjects=10;report.screenBeats=beats;report.currencyArrivals=true;report.cleanup=true
 report.sequentialBreaks=true;report.sharedGemParticles=true
 reduced=true
 local steady=table.clone(receipt);steady.id='reduced';view:receive(steady);view:update(1/60)
 view.cascadeAt=os.clock()-3;view:update(1/60);assert(beats==10,'reduced motion shook camera')
 report.reducedMotion=true
 view:clearGrid()
 for _,flight in ipairs(view.flights) do flight.view:Destroy() end
 table.clear(view.flights)
 reduced=false
 view:receive({kind='preview',id='capture',cargo=bag})
 view.started=os.clock()-.65;view:update(1/60);hud:update(camera.ViewportSize,world,false)
 report.scope='Native Edit component checks; live selling and multiplayer not playtested'
end,debug.traceback)
if not ok then close();error(err) end
return report
