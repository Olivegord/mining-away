-- Production crystal frame and projectile observer with API doubles.
local previousIndex=CF.__index
CF.__index=function(frame,key)
 if key=='RightVector' then return Vector3.new(math.cos(frame.yaw),0,-math.sin(frame.yaw)) end
 return previousIndex(frame,key)
end
local fx=Instance.new('Folder');fx.Parent=workspace
local audio={}
local cameraKicks={}
local owner=Instance.new('Player');owner.UserId=42
game:GetService('Players').LocalPlayer=owner
rockDamage.feedback=CrystalImpactView.new(fx,{play=function(_,name) table.insert(audio,name) end},function(_,_,at)
 table.insert(cameraKicks,at)
end)
local source=Instance.new('UnionOperation');source.Parent=workspace
for k,v in pairs({Kind='Crystal',ZoneName='Ruby',FullSize=Vector3.one*3,FullPosition=Vector3.new(0,1.5,0),
 ReferenceCrystal=true,SpawnAt=95,ReadyAt=97,MaxHP=300,HP=300,Stage=0,StageCount=3,GroundY=0}) do source:SetAttribute(k,v) end
local r={source=source,view=source:Clone(),baseColor=source.Color,dirty=true,cutFeedback=rockDamage.feedback,
 lastContactAt=0,lastBreakAt=0,visual=Feel.newStagePresentation(0,false,100,3)}
r.view.Parent=fx
local resources={r}
crystalFrame(resources,100)
local function shot(at,hp,stage)
 source:SetAttribute('CutContactPoint',Vector3.new(0,2,1));source:SetAttribute('CutContactNormal',Vector3.zAxis)
 source:SetAttribute('CutIsShot',true);source:SetAttribute('CutContactAt',at)
 source:SetAttribute('HP',hp);source:SetAttribute('Stage',stage);r.dirty=true
end
shot(101.01,285,0)
crystalFrame(resources,101)
assert(not r.dirty and r.lastContactAt==0 and r.nextContactAt==101.01 and #audio==0,'future contact was consumed on a settled rock')
crystalFrame(resources,101.02)
assert(r.lastContactAt==101.01 and r.flashAt==101.02 and #audio==2,'settled rock lost the scheduled shot')
assert(audio[1]=='crystal_snap' and audio[2]=='crystal_electric')
crystalFrame(resources,101.075)
assert(audio[3]=='crystal_chip')
crystalFrame(resources,101.25)
assert(#audio==3)

shot(102.01,220,1)
crystalFrame(resources,102)
assert(r.visual.stage==0 and #cues==0 and #audio==3,'fracture ran before the shot')
crystalFrame(resources,102.01)
assert(r.visual.stage==0 and r.flashAt==102.01 and #audio==5,'fracture skipped the contact hold')
crystalFrame(resources,102.06)
assert(r.visual.stage==1 and #cues==1 and audio[6]=='crystal_chip','the retained contact did not crack once')

shot(103.01,0,3)
source:SetAttribute('BreakSerial',1);source:SetAttribute('CrystalBreakAt',103.01);source:SetAttribute('CrystalSplitAt',103.12);source:SetAttribute('CrystalBreakOwner',42)
crystalFrame(resources,103)
assert(r.view.Transparency==0 and not r.visual.broken and #audio==6,'break hid before the shot landed')
crystalFrame(resources,103.01)
assert(r.view.Transparency==0 and r.breakSize and #audio==8,'finishing hit did not show its brief hold')
local height=r.view.Size.Y
crystalFrame(resources,103.14)
local held=r.view.Size
crystalFrame(resources,103.205)
assert(r.view.Transparency==0 and held.Y<height*.8 and (r.view.Size-held).Magnitude<1e-6 and not r.visual.broken,
 'the compressed rock moved during the hold')
assert(#audio==8 and #cameraKicks==0 and splitParticles==0,'release cues ran during the hold')
crystalFrame(resources,103.23)
assert(r.view.Transparency==1 and r.lastBreakAt==103.01 and #audio==11 and #cues==1,
 'split failed to play its impact and crystal tink once')
assert(audio[9]=='crystal_split' and audio[10]=='crystal_impact' and audio[11]=='crystal_release_tink'
 and #cameraKicks==1 and cameraKicks[1]==103.23 and splitParticles==1)
local late={source=source,view=source:Clone(),baseColor=source.Color,dirty=true,cutFeedback=rockDamage.feedback,
 lastContactAt=103.01,lastBreakAt=103.01,visual=Feel.newStagePresentation(3,true,103.08,3)}
late.view.Parent=fx
crystalFrame({late},103.08)
assert(late.view.Transparency==1 and #audio==11 and #cues==1 and #cameraKicks==1 and splitParticles==1,'a late observer replayed a prior hit')
for frame=1,60 do crystalFrame(resources,103.23+frame/60) end
assert(#audio==14 and audio[12]=='crystal_fall_tink' and audio[14]=='crystal_fall_tink'
 and #rockDamage.feedback.pieces==0,'falling shards did not play one tink per selected contact and clean up')

workspace.CurrentCamera=Instance.new('Camera');workspace.CurrentCamera.Parent=workspace
workspace.ChildAdded=signal()
local roleFolder=Instance.new('Folder');roleFolder.Name='DroneRoleState';roleFolder.ChildAdded=signal();roleFolder.Parent=workspace
local function receipt(actor,start,shape,windup)
 local node=Instance.new('Folder');node.Parent=roleFolder
 for k,v in pairs({Kind='MiningShot',Shape=shape or 'Ball',Actor=actor,StartedAt=start,Windup=windup or 0,Duration=.25,
  From=Vector3.new(0,2,0),Position=Vector3.new(0,2,8),Color=Color3.new(1,1,1),TargetId='live'}) do node:SetAttribute(k,v) end
 return node
end
local node=receipt('gunner',110,'Ball',.28)
local muzzle=Instance.new('Attachment');muzzle.WorldPosition=Vector3.new(0,2,0)
local aiming={source=Instance.new('Model'),shotMuzzle=muzzle,beam={holder=fx}}
local aimView=Instance.new('Part');aimView.Parent=fx;aimView.Position=Vector3.new(0,2,8)
local aimSource=Instance.new('Part');aimSource:SetAttribute('HP',80)
local aimTarget={id='live',view=aimView,source=aimSource}
RoleEffectView.aim(aiming,aimTarget,110)
local sight=assert(aiming.sight)
local initial=sight.line.Attachment1.WorldPosition.Z
assert(sight.line.Enabled and initial>1 and initial<3 and sight.dot.Transparency==1)
node:SetAttribute('TargetAnchor',Vector3.new(.30,0,-.48));aiming.shotReceipt=node
aimView.Position=Vector3.new(1,2,7)
RoleEffectView.aim(aiming,aimTarget,110.16)
assert(sight.dot.Position.X>1.2 and sight.line.Attachment0==muzzle,'sight missed the moving receipt anchor')
assert(sight.dot.Transparency<1 and sight.line.Attachment1.WorldPosition.Z>initial+3)
local dash=sight.line.Transparency[2].Time*sight.length
local alpha=sight.line.Transparency[3].Value
aimView.Position=Vector3.new(1,2,5)
RoleEffectView.aim(aiming,aimTarget,110.16)
assert(math.abs(sight.line.Transparency[2].Time*sight.length-dash)<1e-6,'dash stretched with target range')
RoleEffectView.aim(aiming,aimTarget,110.23)
assert(math.abs(sight.line.Transparency[3].Value-alpha)>.005,'dash pattern did not move in a hold')
RoleEffectView.aim(aiming,aimTarget,110.39)
assert(not sight.line.Enabled and sight.dot.Transparency==1)
aimSource:Destroy();aimView:Destroy();muzzle:Destroy();aiming.source:Destroy()
local shotAudio={}
local observer=RoleEffectView.new({play=function(_,name,_,options) table.insert(shotAudio,{name,options}) end})
local gunner={}
local drones={gunner=gunner,late={}}
local targets={live={view=r.view}}
observer:step(110.03,drones,targets)
assert(not observer.records[node].projectile and gunner.shotReceipt==node and shotAudio[1][1]=='coil_load')
observer:step(110.16,drones,targets)
local loaded=assert(observer.records[node].load)
local gathered=loaded.core.Size.X
observer:step(110.26,drones,targets)
assert(loaded.core.Size.X>gathered and loaded.core.Transparency<.35 and loaded.ring.rays[1].beam.Enabled,
 'the loading pose did not build a visible charge')
observer:step(110.32,drones,targets)
assert(observer.records[node].projectile and gunner.shotReceipt==node)
assert(not observer.records[node].load and not loaded.root.Parent,'the charge stayed behind when the shot fired')
assert(shotAudio[2][1]=='coil_fire')
node:SetAttribute('ContactAt',110.54);node:SetAttribute('ContactFracture',true)
observer:step(110.53,drones,targets)
assert(observer.records[node].projectile and #shotAudio==2,'projectile vanished or hit before contact')
observer:step(110.54,drones,targets)
assert(not observer.records[node].projectile and shotAudio[3][1]=='coil_hit' and shotAudio[3][2].level>1)
assert(observer.records[node].after and not observer.records[node].trail.Enabled,'shot wake disappeared with the projectile head')
local old=receipt('late',110.01);old:SetAttribute('ContactAt',110.27)
roleFolder.ChildAdded:Fire(old)
local fresh=receipt('late',110.33,'Dart');fresh:SetAttribute('ContactAt',110.59)
roleFolder.ChildAdded:Fire(fresh)
observer:step(110.60,drones,targets)
assert(#shotAudio==4 and shotAudio[4][1]=='needle_hit' and not drones.late.shotReceipt,'fresh receipt without a projectile lost impact or old contact replayed')
observer:step(111.22,drones,targets)
assert(#shotAudio==4 and not observer.records[node].after and observer.trails==0 and observer.heads==0 and #observer.bursts==0,'contact replayed or shot visuals leaked')
local prismCore=Instance.new('Part');prismCore.Parent=fx
local prism={core=prismCore,scale=1}
RoleEffectView.ramielCharge(prism,.45,.19,nil,false)
local chargeField=assert(prism.chargeField)
local early=chargeField.light[2].Position.Magnitude
RoleEffectView.ramielCharge(prism,.85,.68,nil,false)
assert(chargeField.light[2].Position.Magnitude<early*.55 and chargeField.rings[1].plane.rays[1].beam.Enabled,
 'Ramiel charge did not visibly converge before firing')
RoleEffectView.ramielCharge(prism,1,.4,.23,false)
assert(not prism.chargeField and not chargeField.root.Parent,'Ramiel charge leaked past release')
local beamCalls,kicks={},0
RoleVisuals.Beam=function(...) table.insert(beamCalls,{...}) end
local discharge=RoleEffectView.new(nil,function() kicks+=1 end)
local cast=receipt('ramiel',115,'Prism',2.48)
cast:SetAttribute('Duration',.06)
roleFolder.ChildAdded:Fire(cast)
local prismDrones={ramiel={ramiel=prism}}
discharge:step(117.52,prismDrones,targets)
assert(#beamCalls==0 and kicks==0,'Ramiel fired before contact')
cast:SetAttribute('ContactAt',117.54)
cast:SetAttribute('ContactPoint',Vector3.new(0,2,8))
discharge:step(117.55,prismDrones,targets)
assert(#beamCalls==1 and kicks==1)
local beam=beamCalls[1]
assert(math.abs((beam[1]-prismCore.Position).Magnitude-.85)<1e-6 and beam[4]<=.60 and beam[5]>=.65 and beam[6]=='Prism')
discharge:step(117.60,prismDrones,targets)
assert(#beamCalls==1 and kicks==1,'Ramiel discharge replayed')
discharge:destroy();cast:Destroy()
prismCore:Destroy()
observer:destroy();rockDamage.feedback:destroy();fx:Destroy()
print('PASS crystal contact clock keeps projectile, flash, fracture, split and audio in order without replay')
