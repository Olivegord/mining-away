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
check('fast scatter has a short trail and reduced effects suppresses it',function()
 local camera=workspace.CurrentCamera;workspace.CurrentCamera={CFrame=CFrame.new(0,4,8)}
 source:SetAttribute('SnapshotAt',realTime+.01);source:SetAttribute('Velocity',Vector3.new(10,16,0))
 view:update(1/60,realTime+.01)
 assert(r.trail.Enabled and r.trail.Lifetime<.2 and r.glints.Rate<2 and not r.view:FindFirstChildWhichIsA('Sparkles'))
 pl:SetAttribute('ReducedEffects',true);view:update(1/60,realTime+.02)
 assert(not r.trail.Enabled and not r.glints.Enabled)
 pl:SetAttribute('ReducedEffects',false);workspace.CurrentCamera=camera
end)
check('ground sound waits for the buffered visible contact and fires once',function()
 source:SetAttribute('GroundImpactAt',realTime);source:SetAttribute('GroundImpactPosition',Vector3.new(0,.22,0))
 source:SetAttribute('GroundImpactSpeed',12);source:SetAttribute('GroundImpactSerial',1)
 view:update(1/60,realTime+.02);assert(#audio.calls==0)
 view:update(1/60,realTime+.12);assert(#audio.calls==1 and audio.calls[1].kind=='rubble')
 view:update(1/60,realTime+.2);assert(#audio.calls==1)
end)
check('confirmed collection arrives at the visible backpack instead of the torso center',function()
 realTime+=.3;source:SetAttribute('CollectedAt',realTime);source:SetAttribute('CollectedPosition',torso.Position)
 view:update(1/60,realTime)
 view:update(1/60,realTime+.11)
 assert(r.pos.Z>.3 and r.pos.Y>1 and r.view.Size.Y<.58)
 view:update(1/60,realTime+.23)
 assert(view.records[source]==nil and view.byId[1]==nil and r.view.Transparency==1)
 assert(r.view.EnergyCleanup and r.view.EnergyCleanup<1.5)
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
print(checks..' production PickupView checks with API doubles; native presentation NOT VERIFIED')
