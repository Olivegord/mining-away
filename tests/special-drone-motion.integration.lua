-- Appended after special-fx.setup.lua and production DroneConfig/Motion modules.
-- Matrix transforms below make joint arcs meaningful; still no Roblox rendering.
local identity={1,0,0,0,1,0,0,0,1}
local function matrix(cf) return cf._rotation or identity end
local function rotate(cf,v)
 local m=matrix(cf)
 return Vector3.new(m[1]*v.X+m[2]*v.Y+m[3]*v.Z,m[4]*v.X+m[5]*v.Y+m[6]*v.Z,m[7]*v.X+m[8]*v.Y+m[9]*v.Z)
end
CF.__index=function(cf,key)
 if key=='Rotation' then local result=CFrame.new();result._rotation=matrix(cf);return result end
 return CF[key]
end
CF.__mul=function(a,b)
 if getmetatable(b)==VM then return a.Position+rotate(a,b) end
 local result=CFrame.new(a.Position+rotate(a,b.Position));local am,bm=matrix(a),matrix(b);local out={}
 for row=0,2 do for col=0,2 do local sum=0;for k=0,2 do sum+=am[row*3+k+1]*bm[k*3+col+1] end;out[row*3+col+1]=sum end end
 result._rotation=out;return result
end
function CFrame.Angles(x,y,z)
 local a,b,c=CFrame.new(),CFrame.new(),CFrame.new()
 a._rotation={1,0,0,0,math.cos(x),-math.sin(x),0,math.sin(x),math.cos(x)}
 b._rotation={math.cos(y),0,math.sin(y),0,1,0,-math.sin(y),0,math.cos(y)}
 c._rotation={math.cos(z),-math.sin(z),0,math.sin(z),math.cos(z),0,0,0,1}
 return a*b*c
end
function CFrame.fromMatrix(position,right,up,back)
 local cf=CFrame.new(position)
 cf._rotation={right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z}
 return cf
end
function CF:Inverse()
 local m=matrix(self);local cf=CFrame.new();cf._rotation={m[1],m[4],m[7],m[2],m[5],m[8],m[3],m[6],m[9]};cf.Position=rotate(cf,-self.Position);return cf
end
function CF:PointToWorldSpace(v) return self.Position+rotate(self,v) end
function CF:ToObjectSpace(cf) return self:Inverse()*cf end
function IM:GetScale() return 1 end

local roles={'Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}
local dominant={Bubbler='PressureBulb',Halver='ShearBlade',Gridcutter='GantryRail',Singularity='ContainmentSegment',Starforge='ChimneyCap',Frostbite='CryoTank',Resonator='TuningProng'}
local function newModel(role,readable)
 local model=Instance.new('Model');model.Parent=workspace
 local shell=Instance.new('Part');shell.Name='Mesh';shell.Size=Vector3.new(2,1,2);shell.Parent=model;model.PrimaryPart=shell
 local emitter=Instance.new('Part');emitter.Name='Emmiter';emitter.Parent=shell
 DroneConfig.decorate(model,role,nil,readable)
 return model,shell
end
local function newResource(id)
 local resource=Instance.new('Part');resource.Parent=workspace
 for key,value in pairs({EffectDrone=id,EffectSerial=1,EffectStartedAt=10,EffectDuration=3,EffectPausedAt=0}) do resource:SetAttribute(key,value) end
 return resource
end
local checks=0
local bounds={}
for _,role in ipairs(roles) do
 local model,shell=newModel(role);local original=#model:GetDescendants()
 assert(model.PrimaryPart==shell and model:FindFirstChild('Mesh')==shell,'authored shell preserved')
 assert(model:FindFirstChild(dominant[role]),role..' lacks dominant hardware')
 if role=='Halver' then
  local hinge=model:FindFirstChild('JawHinge');local axle=rotate(hinge.CFrame,Vector3.new(1,0,0))
  assert(math.abs(axle.Y)>.999,'jaw rotates about an axle misaligned with its hinge')
 end
 assert(original<=27,'hardware budget exceeded: '..role)
 DroneConfig.decorate(model,role);assert(#model:GetDescendants()==original,'decoration duplicated')
 local min,max=Vector3.new(100,100,100),Vector3.new(-100,-100,-100)
 for _,part in ipairs(model:GetDescendants()) do if part:IsA('BasePart') then
  for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local v=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5)
   min=Vector3.new(math.min(min.X,v.X),math.min(min.Y,v.Y),math.min(min.Z,v.Z));max=Vector3.new(math.max(max.X,v.X),math.max(max.Y,v.Y),math.max(max.Z,v.Z))
  end end end
  if part~=shell and part.Parent~=shell then assert(not part.CanCollide and not part.CanQuery and not part.CanTouch,'cosmetic collision') end
 end end
 local extent=max-min;bounds[role]=extent
 assert(extent.X<4.6 and extent.Y<4 and extent.Z<4.5,'appendage scale overwhelmed shell: '..role)
 local record=assert(SpecialDroneMotion.new(model,role));local source=Instance.new('Model');source:SetAttribute('DroneId','test');source:SetAttribute('State','SpecialMine')
 local resource=newResource('test')
 SpecialDroneMotion.step(record,source,resource,10)
 local initial={};for _,item in ipairs(record.parts) do initial[item.part]=item.part.CFrame.Position end
 SpecialDroneMotion.step(record,source,resource,11.5)
 local moves=false;for _,item in ipairs(record.parts) do if (item.part.Position-initial[item.part]).Magnitude>.005 then moves=true end end
 assert(moves,role..' tools did not articulate')
 local current={};for _,item in ipairs(record.parts) do current[item.part]=item.part.Position end
 SpecialDroneMotion.step(record,source,resource,11.5)
 for _,item in ipairs(record.parts) do assert((item.part.Position-current[item.part]).Magnitude<1e-8,'same timestamp drift') end
 resource:SetAttribute('EffectPausedAt',11.5);SpecialDroneMotion.step(record,source,resource,100)
 for _,item in ipairs(record.parts) do assert((item.part.Position-current[item.part]).Magnitude<1e-8,'save pause changed pose') end
 resource:SetAttribute('EffectPausedAt',0);resource:SetAttribute('EffectStartedAt',98.5)
 SpecialDroneMotion.step(record,source,resource,100)
 for _,item in ipairs(record.parts) do assert((item.part.Position-current[item.part]).Magnitude<1e-8,'resume phase jumped') end
 resource:SetAttribute('EffectStartedAt',10);resource:SetAttribute('EffectDepleted',true);source:SetAttribute('State','Recover')
 SpecialDroneMotion.step(record,source,nil,12.4);assert(record.active,'final recovery lost target reference')
 source:SetAttribute('State','Follow');SpecialDroneMotion.step(record,source,nil,12.41);SpecialDroneMotion.step(record,source,nil,12.7)
 for _,item in ipairs(record.parts) do assert((item.part.Position-item.base.Position).Magnitude<1e-8,'recall left moved hardware') end
 source:SetAttribute('State','SpecialMine');resource:SetAttribute('EffectCancelledSerial',1);SpecialDroneMotion.step(record,source,resource,11.5);assert(not record.active,'cancelled timeline replayed')
 model:Destroy();source:Destroy();resource:Destroy();checks+=1
end
assert(bounds.Halver.X>bounds.Starforge.X*1.5,'wide shear and vertical furnace too similar')
assert(bounds.Starforge.Y>bounds.Frostbite.Y*1.8,'furnace and low cryogenic sled too similar')
assert(bounds.Frostbite.Z>bounds.Resonator.Z*1.4,'long tanks and tuning comb too similar')
local resource=newResource('fps')
for _,fps in ipairs({30,60,144}) do
 local phase
 for frame=0,fps*3 do phase=SpecialDroneMotion.phase(resource,'fps',10+frame/fps) end
 assert(phase==1,'different end phase at '..fps)
 assert(math.abs(SpecialDroneMotion.phase(resource,'fps',11.5)-.5)<1e-10,'different shared-time pose')
end
assert(SpecialDroneMotion.phase(resource,'wrong',11)==nil,'foreign timeline accepted')
assert(SpecialDroneMotion.phase(resource,'fps',0/0)==nil,'nonfinite clock accepted')
print(checks..' distinct specialist assembly, joint, pause, cancellation and shared-time API-double checks passed; not Studio visual validation')

for _,test in ipairs({
 {role='Needler',part='DartRail',state='SpecialMine',shot=true},
 {role='Ballcaster',part='LaunchRing',state='SpecialMine',shot=true},
 {role='Vacuum',part='WideIntake',state='Vacuum'},
 {role='Dart',part='MineralSeeder',state='Plant'},
}) do
 local model=newModel(test.role)
 local motion=assert(SpecialDroneMotion.new(model,test.role))
 local source=Instance.new('Model');source:SetAttribute('State',test.state)
 local hardware=assert(model:FindFirstChild(test.part));local initial=hardware.Position
 local shot
 if test.shot then
  shot=Instance.new('Folder');shot.Parent=workspace;shot:SetAttribute('StartedAt',10)
  shot:SetAttribute('Windup',test.role=='Ballcaster' and .56 or .20)
 end
 local posedAt=shot and (10+shot:GetAttribute('Windup')*.68) or 10.09
 SpecialDroneMotion.step(motion,source,nil,posedAt,.09,shot)
 local working=hardware.Position
 assert((working-initial).Magnitude>.08,test.role..' hardware stayed still while working')
 if shot then
  shot:SetAttribute('PausedAt',posedAt)
  SpecialDroneMotion.step(motion,source,nil,12,.016,shot)
  assert((hardware.Position-working).Magnitude<1e-6,'shot hardware ignored the replicated pause')
  shot:SetAttribute('PausedAt',0)
  local fireAt=10+shot:GetAttribute('Windup')
  SpecialDroneMotion.step(motion,source,nil,fireAt-.001,1/60,shot)
  local loaded=hardware.Position
  SpecialDroneMotion.step(motion,source,nil,fireAt+.001,1/60,shot)
  assert((hardware.Position-loaded).Magnitude<.022,'release snapped away from the loaded pose')
  SpecialDroneMotion.step(motion,source,nil,fireAt+.070,1/60,shot)
  assert(hardware.Position.Z>loaded.Z+.03,'recoil never overshot the loaded pose')
  shot:Destroy()
 end
 source:SetAttribute('State','Follow')
 for frame=1,60 do SpecialDroneMotion.step(motion,source,nil,12+frame/60,1/60,shot) end
 assert((hardware.Position-initial).Magnitude<.001,'hardware did not settle after work')
 model:Destroy();source:Destroy()
end
print('PASS local dart and ball launch hardware, vacuum intake and seeders move and settle')

local model=newModel('Ramiel',true)
local rig=assert(DroneConfig.ramielRig(model))
local pivot,aim=CFrame.new(1,16,2),Vector3.new(1,4,-13)
local hold=.42
local function sample(charge,recovery,reduced)
 DroneConfig.poseRamiel(rig,pivot,aim,charge,recovery,0,reduced,hold)
end
local pieces={}
for _,half in ipairs(rig.halves) do
 for _,slab in ipairs(half.sweeps) do pieces[slab]={sweep=true} end
 for j=1,2 do pieces[half.bands[j].near]={} end
end
local upper=rig.halves[1]
local cap=upper.bands[3].near
sample(.36/4.94)
local splitWidth=cap.Size.X
assert(cap.LocalTransparencyModifier==0 and rig.closedParts[1].LocalTransparencyModifier==1
 and upper.bands[1].near.LocalTransparencyModifier==1,'the diamond did not split into two solid pointed halves')
sample(1.04/4.94)
assert(cap.LocalTransparencyModifier==0 and cap.Size.X<splitWidth*.30,'the end cap did not pinch into the narrow column')
local narrowWidth=cap.Size.X
sample(1.85/4.94)
local blockWidth=upper.bands[1].near.Size.X
assert(blockWidth>splitWidth*.40 and upper.bands[1].near.LocalTransparencyModifier==0,'the broad center of the stack did not form')
sample(1)
assert(upper.bands[1].near.Size.X>blockWidth*1.60,'the last wave did not flare out into crossed slabs')
assert(cap.Size.X<=narrowWidth+1e-6,'the end cap widened again after pinching')
for frame=0,300 do
 sample(frame/300)
 for part,state in pairs(pieces) do
  local visible=part.LocalTransparencyModifier<.96
  if visible then
   assert(not state.gone,'an outgoing layer reappeared')
   local offset=part.Position-pivot.Position
   local distance=math.abs(offset.Y)
   assert(distance>=(state.distance or 0)-1e-6,'a layer reversed towards the core')
   assert(part.Size.X>=(state.width or 0)-1e-6,'a layer shrank during outward growth')
   state.distance,state.width=distance,part.Size.X
   assert(Vector3.new(offset.X,0,offset.Z).Magnitude<1e-5,'a layer wandered off the diamond axis')
  elseif state.distance then state.gone=true end
 end
end
for part,state in pairs(pieces) do
 assert(state.distance and state.width,'a layer never appeared')
 if state.sweep then
  assert(state.gone and state.distance>.52 and part.LocalTransparencyModifier==1,
   'the outgoing slab failed to move up the stack and disappear')
 else
  assert(not state.gone and part.LocalTransparencyModifier==0,'the crossed shell did not hold')
 end
end
for _,half in ipairs(rig.halves) do
 local equator,shoulder=half.bands[1],half.bands[2]
 assert(equator.near.Size.X>equator.near.Size.Z*1.28 and shoulder.near.Size.X>shoulder.near.Size.Z*1.28)
 assert(math.abs(rotate(equator.near.CFrame,Vector3.xAxis):Dot(rotate(shoulder.near.CFrame,Vector3.xAxis)))<.02,
  'the slabs did not cross in the held pose')
end
local slab=rig.halves[1].bands[1].near
local before=slab.Position
local axes={}
for _,half in ipairs(rig.halves) do
 for _,band in ipairs(half.bands) do axes[band.near]=rotate(band.near.CFrame,Vector3.xAxis) end
end
sample(1,hold-.01)
assert((slab.Position-before).Magnitude<1e-6,'the crossed slabs moved during the shot')
local closeAt=hold+DroneConfig.RamielCloseTime
for frame=1,59 do
 local progress=frame/60
 local steering=pivot*CFrame.Angles(0,math.sin(progress*math.pi*2)*.64,0)
 DroneConfig.poseRamiel(rig,steering,nil,1,hold+DroneConfig.RamielCloseTime*progress,0,false,hold)
 for part,axis in pairs(axes) do
  assert((rotate(part.CFrame,Vector3.xAxis)-axis).Magnitude<1e-6,'an open piece turned back with flight steering')
  local outward=math.abs(part.Position.Y-pivot.Position.Y)
  local state=pieces[part] or {};pieces[part]=state
  assert(outward>=(state.distance or 0)-1e-6,'a departing piece slid back towards the core')
  state.distance=outward
 end
end
assert(slab.Position.Y>before.Y and slab.LocalTransparencyModifier>0 and rig.closedParts[1].LocalTransparencyModifier==1,
 'the departing slabs reversed or the hull appeared before the hard latch')
sample(0)
assert(slab.LocalTransparencyModifier==1 and rig.closedParts[1].LocalTransparencyModifier==0)
sample(.15,nil,true)
assert(rig.halves[1].sweeps[1].LocalTransparencyModifier==1,'reduced motion still showed the travelling slabs')
model:Destroy()
print('PASS Ramiel grows and discards each outgoing layer once, crosses the new slabs, and swaps to the closed hull')

local prototype=Instance.new('UnionOperation')
prototype.Name='RamielHull';prototype.Size=Vector3.one*2.7;prototype.Parent=game:GetService('ReplicatedStorage')
local shellModel=newModel('Ramiel',true)
local shellRig=assert(DroneConfig.ramielRig(shellModel))
assert(shellRig.closed.LocalTransparencyModifier==0)
DroneConfig.poseRamiel(shellRig,pivot,aim,1,nil,0,false,hold)
for _,half in ipairs(shellRig.halves) do
 for _,mirror in ipairs(half.mirrors) do
  local pyramid=mirror.pyramid
  assert(pyramid and pyramid:IsA('BasePart') and pyramid.Size.X>pyramid.Size.Y
   and pyramid.LocalTransparencyModifier==0,'the firing gap lost a faceted pyramid')
 end
end
DroneConfig.poseRamiel(shellRig,pivot,aim,1,closeAt-1/144,0,false,hold)
assert(shellRig.closed.LocalTransparencyModifier==1,'the travel hull appeared before the latch')
DroneConfig.poseRamiel(shellRig,pivot,nil,0,nil,0,false)
assert(shellRig.closed.LocalTransparencyModifier==0)
shellModel:Destroy();prototype:Destroy()
print('PASS Ramiel finishes its open pose with eight faceted pyramids and latches into one closed hull')
