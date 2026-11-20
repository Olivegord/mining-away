-- Native Edit component check; no Play, gameplay commands, or saved profile edits.
assert(not game.RunService:IsRunning() and game.PlaceId==124078027733625 and game.GameId==10774898335)
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
 view:receive({kind='preview',id=receipt.id,cargo=bag});view.started=os.clock()-1;view:update()
 view:receive(receipt)
 local started=os.clock();local maxTokens=0
 while not view.finished and os.clock()-started<6 do
  view:update();maxTokens=math.max(maxTokens,#view.ledgerFlights)
  task.wait(1/60)
 end
 assert(view.finished and beats==3 and view.ledger.rows.Money.amount==169)
 for _,tile in ipairs(view.tiles) do
  assert(tile.settled and tile.ore.Parent and tile.worth.Parent, 'sold rock and payout must remain readable')
 end
 report.seconds=os.clock()-started;report.maxTokens=maxTokens
 local a,b,c=table.unpack(view.tiles)
 assert(a.bonusAt<a.hitAt and b.hitAt>a.hitAt and c.hitAt>b.hitAt)
 report.bonusLead=a.hitAt-a.bonusAt
 -- Check the actual sale sound voice uses the uploaded rock recording and a bounded natural tail.
 local Sound=assert(loadstring(module('AudioFeedback','SentryMotion')..module('Soundscape','PullMotion')..'\nreturn Soundscape'))()
 local sound=Sound.new(fx);sound.effectsGroup.Volume=0;sound.musicGroup.Volume=0
 local good,why=pcall(function()
  game:GetService('ContentProvider'):PreloadAsync({sound.bank['96292866549392']})
  local voice,anchor,_,duration=sound:_voice('sale_stone',nil,false,{rockSize=3})
  assert(voice.SoundId=='rbxassetid://96292866549392' and voice.PlaybackRegionsEnabled and duration>1)
  report.rockSoundDuration=duration;voice:Destroy()
 end)
 sound:destroy();assert(good,why)
end,debug.traceback)
close();assert(ok,err);return report
