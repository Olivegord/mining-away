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
 module('EnergyDisc','Workshop')..module('Workshop','Shops')..module('Shops','Feel')..module('Mining','Feedback')..module('RockFinish','WorkEffects')
 ..'\nlocal BeamVFX={reduced=function() return false end,near=function() return true end}\n'
 ..module('RoleVisuals','NomadView')..module('RockModifierView','PickupDisplay')
 ..module('PickupDisplay','PickupView')..module('SaleView','CommandView')..'\nreturn Workshop,RockFinish,SaleView'))()
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
local modified=W.saleCargo('Amber',20,true,7,100,6,'Crown')
local plain=W.saleCargo('Amber',26,true,7,100)
local gem=W.saleCargo('Diamond',120,false,100,0)
local bag={[modified]=1,[plain]=1,[gem]=1}
local receipt={id='component-check',runId=snapshot.run.id,revision=5,full=true,cargo=bag,cash=169,resources={Stone=200,Amber=16,Diamond=100}}
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
 local first,second,last=table.unpack(view.tiles)
 local money,amber=view.ledger.rows.Money,view.ledger.rows.Amber
 assert(first.item.key==modified and second.item.key==plain and last.item.material=='Diamond')
 assert(view.prompt.Visible and view.focus and view.focus.Parent==game.Lighting)
 assert(beats==0 and #view.flights==0 and not view.cascadeAt,'preview cashed out without E')
 assert(view.ledger.panel.Position.X.Offset>camera.ViewportSize.X*.5 or camera.ViewportSize.X<650)
 assert(first.display.outline.Enabled and first.display.outline.Adornee==first.ore and first.display.rings)
 assert(last.gem,'native gem fallback')
 local sample=first.ore
 local center=camera:WorldToViewportPoint(sample.Position)
 local right=camera:WorldToViewportPoint(sample.Position+camera.CFrame.RightVector*sample.Size.X)
 report.rockWidthPixels=math.floor(right.X-center.X)
 assert(report.rockWidthPixels>0 and report.rockWidthPixels<=80,'rock should fit a padded left-side grid')
 assert(center.X<camera.ViewportSize.X*.5 or camera.ViewportSize.X<650)
 view:confirm();view:confirm();assert(confirmed==receipt.id and view.pendingAt and cues.sale_confirm==1)
 snapshot.revision=5;snapshot.run.wallet.Quartz+=receipt.cash;snapshot.run.resources=table.clone(receipt.resources)
 snapshot.recentSales={receipt};view:receiveProfile(snapshot);view:receive(receipt)
 assert(not view.prompt.Visible and committed==1,'profile and remote duplicated the sale')
 hud:update(camera.ViewportSize,world,false)
 assert(hud.wallets[1].value.Text=='1234','wallet jumped before the addition')
 view.cascadeAt=os.clock()-.4;view:update();assert(beats==0)
 view.cascadeAt=os.clock()-1;view:update()
 assert(first.hitAt and not second.hitAt and beats==1 and #view.flights==0)
 assert(money.history[1].view.Text=='+ $20' and amber.history[1].view.Text=='+ 0.07')
 assert(money.amount==0 and amber.amount==0,'base terms posted before the modifier')
 local burst=assert(fx:FindFirstChild('GemRewardParticles'))
 assert(burst.AirborneSparks.Lifetime.Min>=.81 and burst.ImpactAccent.Lifetime.Max>1.45)
 view.pendingTerms.modifierAt=os.clock()-1;view:update()
 assert(money.history[1].view.Text:find('Charged',1,true) and amber.history[1].view.Text:find('Frosted',1,true))
 assert(money.amount==0 and not second.hitAt,'modifier did not get a separate beat')
 first.hitAt=os.clock()-.09;view.lastBreakAt=os.clock()-1;view.pendingTerms.addAt=os.clock()-1;view:update()
 assert(first.sold and not second.hitAt and money.total.Text=='$23' and amber.total.Text=='0.09')
 hud:update(camera.ViewportSize,world,false);assert(hud.wallets[1].value.Text=='1257')
 view:update();assert(second.hitAt and beats==2 and burst.Parent==fx)
 local lines=money.history
 assert(lines[1].view.Text=='+ $26' and lines[2].view.Text=='+ $23')
 view.ledger:update(os.clock()+1,false)
 assert(lines[2].view.Position.Y.Offset<lines[1].view.Position.Y.Offset,'prior addend did not move up')
 second.hitAt=os.clock()-.09;view.lastBreakAt=os.clock()-1;view.pendingTerms.addAt=os.clock()-1;view:update()
 assert(second.sold and not last.hitAt and money.total.Text=='$49')
 view:update();assert(last.hitAt and beats==3)
 last.hitAt=os.clock()-2;view.pendingTerms.addAt=os.clock()-1;view:update();view:update()
 assert(view.finished and view.active and view.prompt.Visible and view.ledger.progress.Text=='Sale complete')
 assert(money.total.Text=='$169' and amber.total.Text=='0.16' and view.ledger.rows.Diamond.total.Text=='1')
 assert(view.ledger.rows.Stone.total.Text=='2' and cues.sale_finish==1)
 view.started=os.clock()-50;view:update();assert(view.finished and view.active,'completed sale dismissed itself')
 hud:update(camera.ViewportSize,world,false);assert(hud.wallets[1].value.Text=='1403')
 view:confirm();assert(not view.active and not view.focus and not view.ledger)
 local pending={id='receipt-first',runId=snapshot.run.id,revision=6}
 hud:beginSale(pending,{Money=9});hud:currencyHit(pending.id,'Money',4,false)
 local offset=hud:pendingSaleBalances(snapshot,os.clock());assert(offset.Money==4)
 snapshot.revision=6;snapshot.run.wallet.Quartz+=9
 offset=hud:pendingSaleBalances(snapshot,os.clock());assert(offset.Money==-5)
 hud:currencyHit(pending.id,'Money',5,false)
 offset=hud:pendingSaleBalances(snapshot,os.clock());assert(offset.Money==nil)
 report.scope='Native Edit component checks'
 report.sequentialBreaks=beats;report.modifierBeat=true;report.stickyTotals=true;report.replicationOrder=true

end,debug.traceback)
close()
if not ok then error(err) end
return report
