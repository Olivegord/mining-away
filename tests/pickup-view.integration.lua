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
 for k,v in pairs({PickupId=2,Owner=pl.UserId,SpawnAt=realTime-4,SnapshotAt=realTime,FloorY=.22,Position=late.Position,Velocity=Vector3.zero,GroundImpactSerial=0}) do late:SetAttribute(k,v) end
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
check('physical launch trail fades on the displayed landing and never reappears during collection',function()
 local camera=workspace.CurrentCamera;workspace.CurrentCamera={CFrame=CFrame.new(0,4,8)}
 local cargo=fixturePart(root,'RawCrystalCargo',Vector3.new(0,3,0),Vector3.new(1.48,1.70,1.42))
 for k,v in pairs({PickupId=3,Owner=pl.UserId,PhysicalCargo=true,CargoValue=10,SpawnAt=realTime,SnapshotAt=realTime,
  FloorY=.22,Position=cargo.Position,Velocity=Vector3.new(3,20,0)}) do cargo:SetAttribute(k,v) end
 local renderer=PickupView.new(root,fx,audio);local record=assert(renderer.records[cargo])
 renderer:update(1/60,realTime+.2)
 local ribbon=assert(record.ribbon)
 assert(ribbon.trail.Enabled and ribbon.trail.Parent==record.view and not renderer.valueGui)
 cargo:SetAttribute('GroundImpactAt',realTime+.68)
 renderer:update(1/60,realTime+.73);assert(ribbon.trail.Enabled,'trail ended before the buffered landing pose')
 renderer:update(1/60,realTime+.80)
 assert(not ribbon.trail.Enabled and renderer.valueGui.Enabled and renderer.valueGui.Adornee==record.view)
 renderer:update(1/60,realTime+1.10)
 assert(not record.ribbon and renderer.trailCount==0 and not ribbon.trail.Parent)
 cargo:SetAttribute('CollectedAt',realTime+1.2)
 renderer:update(1/60,realTime+1.20);assert(not record.ribbon)
 renderer:destroy();workspace.CurrentCamera=camera
end)
check('80 resting pieces reuse their poses and share one owner price label',function()
 local camera=workspace.CurrentCamera;workspace.CurrentCamera={CFrame=CFrame.new(0,2,0)}
 local pile=Instance.new('Folder');pile.DescendantAdded=signal();pile.DescendantRemoving=signal();pile.Parent=workspace
 local visuals=Instance.new('Folder');visuals.Parent=workspace
 local sources={}
 for i=1,80 do
  local drop=fixturePart(pile,'SettledCargo',Vector3.new(i*.75,.22,0),Vector3.new(1.48,1.70,1.42))
  for k,v in pairs({PickupId=10+i,Owner=i==1 and pl.UserId+1 or pl.UserId,PhysicalCargo=true,CargoValue=i,
   SpawnAt=realTime-4,SnapshotAt=realTime,GroundImpactAt=realTime-3,FadeAt=realTime+10,ExpiresAt=realTime+15,
   FloorY=.22,Position=drop.Position,Velocity=Vector3.zero}) do drop:SetAttribute(k,v) end
  sources[i]=drop
 end
 local renderer=PickupView.new(pile,visuals,audio)
 renderer:update(1/60,realTime+.2)
 local poses,sizes={},{}
 for i,source in ipairs(sources) do
  local record=renderer.records[source];poses[i]=record.view.CFrame;sizes[i]=record.view.Size
 end
 for i=1,240 do renderer:update(1/60,realTime+.2+i/60) end
 for i,source in ipairs(sources) do
  local record=renderer.records[source]
  assert(record.view.CFrame==poses[i] and record.view.Size==sizes[i],'resting cargo still wrote its pose')
 end
 local gui=renderer.valueGui
 assert(gui.Adornee==renderer.records[sources[2]].view and renderer.valueText.Text=='2 Q')
 assert(#visuals:GetChildren()==81,'cargo allocated more than one price label')
 workspace.CurrentCamera.CFrame=CFrame.new(15,2,0)
 renderer:update(1/60,realTime+5)
 assert(renderer.valueGui==gui and gui.Adornee==renderer.records[sources[20]].view)
 local first=renderer.records[sources[2]]
 sources[2]:SetAttribute('Units',4)
 renderer:update(1/60,realTime+6)
 assert(first.view.Size.X>sizes[2].X,'combining a settled pile did not refresh the pose')
 local pose=first.view.CFrame
 renderer:update(1/60,realTime+13)
 assert(first.view.CFrame==pose and first.view.Transparency>0,'expiry did not fade a static pile in place')
 sources[2]:SetAttribute('FadeAt',realTime+20);sources[2]:SetAttribute('ExpiresAt',realTime+25)
 renderer:update(1/60,realTime+13.1)
 assert(first.view.Transparency==0 and first.view.CFrame==pose,'renewing a static pile failed to reset the fade')
 renderer:destroy();visuals:Destroy();pile:Destroy();workspace.CurrentCamera=camera
end)
print(checks..' production PickupView checks with API doubles; native presentation NOT VERIFIED')
