-- Production PickupView with Roblox API doubles. Does not validate pixels/audio.
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS pickup view '..name) end
local pl=player(91000);players.LocalPlayer=pl;players.list={pl}
function players:GetPlayerByUserId(id) return id==pl.UserId and pl or nil end
local torso=fixturePart(pl.Character,'UpperTorso',Vector3.new(0,3,0),Vector3.new(2,2,1))
local root=Instance.new('Folder');root.DescendantAdded=signal();root.DescendantRemoving=signal();root.Parent=workspace
local fx=Instance.new('Folder');fx.Parent=workspace
local source=fixturePart(root,'OreFragment',Vector3.new(0,.22,0),Vector3.new(.48,.58,.44))
for k,v in pairs({PickupId=1,Owner=pl.UserId,SpawnAt=realTime-.2,SnapshotAt=realTime,FloorY=.22,Position=source.Position,Velocity=Vector3.zero,GroundImpactSerial=0}) do source:SetAttribute(k,v) end
local audio={calls={}}
function audio:play(kind,position,options) table.insert(self.calls,{kind=kind,position=position,options=options}) end
local view=PickupView.new(root,fx,audio)
local r=assert(view.records[source])
check('rotating fragment stays supported above the authoritative floor',function()
 view:update(1/60,realTime)
 assert(r.drawPosition.Y>=.22 and r.view.Size.Y==.58)
 assert(source.LocalTransparencyModifier==1 and not r.view.CanCollide and not r.view.CanQuery)
end)
check('scattered ore is one plain collectible visual',function()
 local camera=workspace.CurrentCamera;workspace.CurrentCamera={CFrame=CFrame.new(0,4,8)}
 source:SetAttribute('SnapshotAt',realTime+.01);source:SetAttribute('Velocity',Vector3.new(10,16,0))
 view:update(1/60,realTime+.01)
 assert(#r.view:GetDescendants()==0 and r.view.Name=='CollectibleOre')
 pl:SetAttribute('ReducedEffects',true);view:update(1/60,realTime+.02)
 assert(#r.view:GetDescendants()==0)
 pl:SetAttribute('ReducedEffects',false);workspace.CurrentCamera=camera
end)
check('landing settles the fragment without adding another mining sound',function()
 source:SetAttribute('GroundImpactAt',realTime);source:SetAttribute('GroundImpactSerial',1)
 view:update(1/60,realTime+.02);assert(r.landAge and #audio.calls==0)
 view:update(1/60,realTime+.2);assert(#audio.calls==0)
end)
check('confirmed collection arrives at the visible backpack instead of the torso center',function()
 realTime+=.3;source:SetAttribute('CollectedAt',realTime);source:SetAttribute('CollectedPosition',torso.Position)
 view:update(1/60,realTime)
 view:update(1/60,realTime+.11)
 assert(r.pos.Z>.3 and r.pos.Y>1 and r.view.Size.Y<.58)
 view:update(1/60,realTime+.25)
 assert(view.records[source]==nil and view.byId[1]==nil and not r.view.Parent)
end)
check('pickup number shows the server total for grouped receipts',function()
 local function collect(serial,total)
  pl:SetAttribute('MA_Collect',http:JSONEncode({serial=serial,total=total,units=1,at=realTime,quiet=true}))
  view:update(1/60,realTime)
 end
 collect(1,3)
 assert(view.amountGui.Enabled and view.amountGui.Adornee==torso and view.amountText.Text=='+3 ore')
 realTime+=.1;collect(4,8)
 assert(view.amountText.Text=='+8 ore','coalesced receipts hid some collected ore')
 view:update(1/60,realTime+1)
 assert(not view.amountGui.Enabled)
 realTime+=1;collect(5,10)
 assert(view.amountText.Text=='+2 ore' and view.amountGui.Enabled)
end)
check('destroy disconnects observers without granting or changing units',function()
 source:SetAttribute('Units',7);view:destroy();assert(view.closed and source:GetAttribute('Units')==7)
 for _,connection in ipairs(view.connections) do assert(connection.on==false) end
end)
check('stale landing state received after registration settles without replaying audio',function()
 local late=fixturePart(root,'OreFragment',Vector3.new(2,.22,0),Vector3.new(.48,.58,.44))
 for k,v in pairs({PickupId=2,Owner=pl.UserId,SpawnAt=realTime-4,SnapshotAt=realTime,FloorY=.22,Position=late.Position,
  Velocity=Vector3.zero,OreLaunchOrigin=late.Position,OreLaunchVelocity=Vector3.new(6,20,0),GroundImpactSerial=0}) do late:SetAttribute(k,v) end
 local renderer=PickupView.new(root,fx,audio);local record=assert(renderer.records[late])
 assert(record.landAge==nil)
 local sounds=#audio.calls
 late:SetAttribute('GroundImpactAt',realTime-3);late:SetAttribute('GroundImpactPosition',Vector3.new(2,.22,0))
 late:SetAttribute('GroundImpactSpeed',12);late:SetAttribute('GroundImpactSerial',1)
 renderer:update(1/60,realTime)
 assert(record.landAge==1 and #audio.calls==sounds and record.contact==nil)
 local angle=record.view.CFrame.yaw
 renderer:update(1/60,realTime+10)
 assert(math.abs(record.view.CFrame.yaw-angle)<1e-8,'settled fragment keeps spinning')
 assert(#audio.calls==sounds,'late observer replayed old contact audio')
 renderer:destroy()
end)
check('ordinary ore clinks once when its buffered landing data arrives',function()
 local loose=fixturePart(root,'OreFragment',Vector3.new(2,3,0),Vector3.new(.6,.7,.5))
 local launch=Vector3.new(6,20,0)
 for k,v in pairs({PickupId=70,Owner=pl.UserId,SpawnAt=realTime,SnapshotAt=realTime,FloorY=.22,
  Position=loose.Position,Velocity=launch,OreLaunchOrigin=loose.Position,OreLaunchVelocity=launch}) do loose:SetAttribute(k,v) end
 local renderer=PickupView.new(root,fx,audio)
 local sounds=#audio.calls
 local contact=Vector3.new(5,.22,0)
 loose:SetAttribute('GroundImpactAt',realTime+.82)
 renderer:update(1/60,realTime+.85)
 assert(#audio.calls==sounds,'played before the displayed landing')
 renderer:update(1/60,realTime+.94)
 assert(#audio.calls==sounds and not renderer.records[loose].landCue,'missing packet consumed the landing')
 loose:SetAttribute('GroundImpactPosition',contact);loose:SetAttribute('GroundImpactSpeed',28)
 renderer:update(1/60,realTime+.96)
 assert(#audio.calls==sounds+1 and audio.calls[#audio.calls].kind=='ore_land'
  and (audio.calls[#audio.calls].position-contact).Magnitude<1e-6)
 renderer:update(1/60,realTime+1.06)
 assert(#audio.calls==sounds+1,'landing cue replayed')
 renderer:destroy();loose:Destroy()
end)
check('physical launch trail fades on the displayed landing and never reappears during collection',function()
 local camera=workspace.CurrentCamera;workspace.CurrentCamera={CFrame=CFrame.new(0,4,8)}
 local cargo=fixturePart(root,'RawCrystalCargo',Vector3.new(0,3,0),Vector3.new(1.48,1.70,1.42))
 cargo.Material=Enum.Material.Glass
 for k,v in pairs({PickupId=3,Owner=pl.UserId,PhysicalCargo=true,CargoValue=10,SpawnAt=realTime,SnapshotAt=realTime,
  FloorY=.22,Position=cargo.Position,Velocity=Vector3.new(7,30,0),OreLaunchOrigin=cargo.Position,
  OreLaunchVelocity=Vector3.new(7,30,0)}) do cargo:SetAttribute(k,v) end
 local renderer=PickupView.new(root,fx,audio);local record=assert(renderer.records[cargo])
 local sounds=#audio.calls
 renderer:update(1/60,realTime+.2)
 local ribbon=assert(record.ribbon)
 assert(ribbon.trail.Enabled and ribbon.trail.Parent==record.view and not renderer.valueGui)
 assert(record.view.Material==Enum.Material.SmoothPlastic)
 assert(cargo.LocalTransparencyModifier==1 and not record.idle)
 cargo:SetAttribute('GroundImpactAt',realTime+.98)
 cargo:SetAttribute('GroundImpactPosition',Vector3.new(4,.22,0))
 cargo:SetAttribute('GroundImpactSpeed',23)
 renderer:update(1/60,realTime+1.03);assert(ribbon.trail.Enabled and #audio.calls==sounds,'landing cue ran ahead of the buffered ore')
 renderer:update(1/60,realTime+1.10)
 assert(not ribbon.trail.Enabled and renderer.valueGui.Enabled and renderer.valueGui.Adornee==record.view)
 assert(#audio.calls==sounds+1 and audio.calls[#audio.calls].kind=='ore_land' and audio.calls[#audio.calls].position.X==4)
 assert(not record.idle,'bloom appeared before the ore settled')
 cargo:SetAttribute('CollectedAt',realTime+1.16)
 renderer:update(1/60,realTime+1.16)
 renderer:update(1/60,realTime+1.37)
 assert(renderer.records[cargo]==nil)
 assert(#audio.calls==sounds+1,'landing sound replayed during collection')
 assert(not record.ribbon and renderer.trailCount==0 and not ribbon.trail.Parent)
 renderer:destroy();workspace.CurrentCamera=camera
end)
check('a finished gem stays hidden until release, then hits the ground with one clink',function()
 local cargo=fixturePart(root,'QueuedGem',Vector3.new(0,3,0),Vector3.new(1.55,1.16,1.4))
 cargo.Material=Enum.Material.Metal;cargo.Reflectance=.28
 local born=realTime+.135
 local launch=Vector3.new(7,45,0)
 for k,v in pairs({PickupId=4,Owner=pl.UserId,PhysicalCargo=true,CleanCargoArc=true,SpawnAt=born,SnapshotAt=born,
  FloorY=.22,Position=cargo.Position,Velocity=launch,OreLaunchOrigin=cargo.Position,OreLaunchVelocity=launch}) do cargo:SetAttribute(k,v) end
 local renderer=PickupView.new(root,fx,audio)
 local r=assert(renderer.records[cargo])
 assert(r.view.Material==Enum.Material.Metal and r.view.Reflectance==.28)
 renderer:update(1/60,born+.099)
 assert(r.view.Transparency==1 and not r.ribbon)
 renderer:update(1/60,born+.101)
 assert(r.view.Transparency==0)
 local sounds=#audio.calls
 local contact=born+r.arc.contact+PickupMotion.DELAY
 renderer:update(1/60,contact-.015)
 assert(#audio.calls==sounds and r.view.Position.Y>r.view.Size.Y*.5)
 renderer:update(1/60,contact+.001)
 assert(#audio.calls==sounds+1 and audio.calls[#audio.calls].kind=='ore_land')
 local landed=r.view.CFrame
 assert(math.abs(landed.Position.Y-r.view.Size.Y*.5)<1e-8 and landed.Position.X==r.arc.landX)
 renderer:update(1/60,contact+.27)
 assert(#audio.calls==sounds+1 and (r.view.Position-landed.Position).Magnitude<1e-8 and r.view.CFrame.yaw==landed.yaw,
  'gem moved or chimed again after touchdown')
 renderer:destroy();cargo:Destroy()
end)
check('grounded gems flash thin dotted stars in place and share one price label',function()
 local camera=workspace.CurrentCamera;workspace.CurrentCamera={CFrame=CFrame.new(0,2,0)}
 local pile=Instance.new('Folder');pile.DescendantAdded=signal();pile.DescendantRemoving=signal();pile.Parent=workspace
 local visuals=Instance.new('Folder');visuals.Parent=workspace
 local sources={}
 for i=1,80 do
  local drop=fixturePart(pile,'SettledCargo',Vector3.new(i*.75,.22,0),Vector3.new(1.48,1.70,1.42))
  for k,v in pairs({PickupId=10+i,Owner=i==1 and pl.UserId+1 or pl.UserId,PhysicalCargo=true,CargoValue=i,
   SpawnAt=realTime-4,SnapshotAt=realTime,GroundImpactAt=realTime-3,FadeAt=realTime+10,ExpiresAt=realTime+15,
   FloorY=.22,Position=drop.Position,Velocity=Vector3.zero,
   CleanCargoArc=true,OreLaunchOrigin=drop.Position-Vector3.xAxis*.6,OreLaunchVelocity=Vector3.new(2.3,25,0)}) do drop:SetAttribute(k,v) end
  sources[i]=drop
 end
 local reducedMotion=false
 local renderer=PickupView.new(pile,visuals,audio,function() return reducedMotion end)
 renderer:update(1/60,realTime+.2)
 local poses,sizes={},{}
 for i,source in ipairs(sources) do
  local record=renderer.records[source];poses[i]=record.view.CFrame;sizes[i]=record.view.Size
 end
 local mostLit=0
 for i=1,240 do
  renderer:update(1/60,realTime+.2+i/60)
  mostLit=math.max(mostLit,renderer.idleCount)
 end
 local lit=0
 for i,source in ipairs(sources) do
  local record=renderer.records[source]
  if record.idle then
   lit+=1
   assert(record.idle.anchor.Parent==record.view and record.idle.halo.Adornee==record.idle.anchor)
   assert(#record.idle.dots==13 and record.idle.dots[1].frame.BackgroundTransparency<1)
  end
  assert(math.abs(record.view.Position.Y-record.view.Size.Y*.5)<1e-8,'gem failed to sit on the ground')
  assert(record.view.Position==poses[i].Position and record.view.CFrame.yaw==poses[i].yaw and record.view.Size==sizes[i],
   'idle ore moved, rotated or changed size')
 end
 assert(mostLit>0 and mostLit<=12 and renderer.idleCount==lit)
 assert(renderer.idleCount+#renderer.idlePool<=12,'glint pool exceeded the visual budget')
 local gui=renderer.valueGui
 assert(gui.Adornee==renderer.records[sources[2]].view and renderer.valueText.Text=='2 Q')
 assert(#visuals:GetChildren()==81,'cargo allocated more than one price label')
 workspace.CurrentCamera.CFrame=CFrame.new(15,2,0)
 renderer:update(1/60,realTime+5)
 assert(renderer.valueGui==gui and math.abs(gui.Adornee.CFrame.Position.X-15)<.7)
 local first=renderer.records[sources[2]]
 sources[2]:SetAttribute('Units',4)
 renderer:update(1/60,realTime+6)
 assert(first.view.Size.X>sizes[2].X,'combining a settled pile did not refresh the pose')
 reducedMotion=true
 renderer:update(1/60,realTime+6.1)
 assert(math.abs(first.view.Position.Y-first.view.Size.Y*.5)<1e-8,'reduced motion moved the resting ore')
 local pose=first.view.CFrame
 renderer:update(1/60,realTime+13)
 assert(first.view.CFrame==pose and first.view.Transparency>0,'expiry did not fade a static pile in place')
 sources[2]:SetAttribute('FadeAt',realTime+20);sources[2]:SetAttribute('ExpiresAt',realTime+25)
 renderer:update(1/60,realTime+13.1)
 assert(first.view.Transparency==0 and first.view.CFrame==pose,'renewing a static pile failed to reset the fade')
 pl:SetAttribute('ReducedEffects',true);renderer:update(1/60,realTime+13.2)
 assert(renderer.idleCount==0,'reduced effects left dotted stars on screen')
 pl:SetAttribute('ReducedEffects',false)
 renderer:destroy();visuals:Destroy();pile:Destroy();workspace.CurrentCamera=camera
end)
print(checks..' production PickupView checks with API doubles; native presentation NOT VERIFIED')
