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
local glass=assert(model:FindFirstChild('RamielGlass'))
local facets={}
for _,part in ipairs(glass:GetDescendants()) do
 if part:IsA('BasePart') and part~=rig.core then facets[part]={part.Transparency,part.Parent} end
end
local pivot,aim=CFrame.new(1,16,2),Vector3.new(1,4,-13)
local verticalCenters={}
local function sample(referenceTime,recovery)
 local charge=math.clamp((referenceTime-19.04)/4.94,0,1)
 DroneConfig.poseRamiel(rig,pivot,aim,charge,recovery,0,false,2.55)
 local upper,lower=rig.halves[1].bands[1].near,rig.halves[2].bands[1].near
 for facet,original in pairs(facets) do
  assert(facet.Transparency==original[1] and facet.Parent==original[2],'facet was replaced or faded')
  assert(facet.Size.Magnitude>.02 and facet.Position.Magnitude<24,'invalid glass deformation')
 end
 for _,half in ipairs(rig.halves) do
  for _,band in ipairs(half.bands) do
   local y=band.far and (band.near.Position.Y+band.far.Position.Y)*.5 or band.near.Position.Y
   verticalCenters[band]=verticalCenters[band] or y
   assert(math.abs(verticalCenters[band]-y)<.0001,'the slab changed height during the attack')
  end
  for _,pair in ipairs(half.mirrors) do
   local y=pair[1].Position.Y
   verticalCenters[pair]=verticalCenters[pair] or y
   assert(math.abs(verticalCenters[pair]-y)<.0001,'the central crystal bobbed')
  end
 end
 local corner=upper.CFrame:PointToWorldSpace(Vector3.new(upper.Size.X*.5,0,upper.Size.Z*.5))-upper.Position
 return upper.Size.X,upper.Position.Y-lower.Position.Y,upper.Position-pivot.Position,corner
end
local idleWidth,idleGap=sample(19.04)
local previousWidth,previousGap=idleWidth,idleGap
for i=1,300 do
 local time=19.04+i*4.94/300
 local width,gap,offset=sample(time)
 assert(math.abs(width-previousWidth)<.16 and math.abs(gap-previousGap)<.20,'shape jumped between sampled frames')
 assert(math.abs(offset.X)<.001 and math.abs(offset.Z)<.001,'the slab center drifted away from the axis')
 previousWidth,previousGap=width,gap
end
local narrow,narrowGap=sample(20.04)
local tucked,tuckedGap=sample(20.84)
local before,_,_,cornerBefore=sample(21.18)
local expanding,_,_,cornerAfter=sample(21.74)
local wide,wideGap=sample(23.98)
assert(narrow<idleWidth*.23 and narrowGap>idleGap,'first separation did not pinch around the fixed axis')
assert(tucked>narrow*2 and tuckedGap>=narrowGap,'bands did not widen around the core')
assert(wide>tucked*1.30 and wideGap>tuckedGap,'wide shooting shape did not expose the core')
assert(expanding>before*1.32 and cornerBefore.Unit:Dot(cornerAfter.Unit)<.75,
 'the final wave did not widen and sweep its corners around the axis')
for _,half in ipairs(rig.halves) do
 for j=1,2 do
  local slab=half.bands[j].near
  assert(slab.Size.X>slab.Size.Z*1.28,'firing shell did not resolve into elongated slabs')
 end
 assert(#half.mirrors==4 and half.mirrors[4][2]:IsA('WedgePart'),'central jagged glass was lost')
end
local fired,firedGap=sample(23.98,0)
assert(math.abs(wide-fired)<1e-6 and math.abs(wideGap-firedGap)<1e-6,'discharge skipped a pose')
local _,kickGap,kick=sample(23.98,.09)
assert(math.abs(kickGap-wideGap)<1e-6 and kick.Z>.26,'discharge moved vertically or lost its horizontal recoil')
local held,heldGap=sample(23.98,2.54)
assert(math.abs(held-wide)<1e-6 and math.abs(heldGap-wideGap)<1e-6,'shape drifted during the beam')
local returned,returnedGap=sample(23.98,2.55+DroneConfig.RamielCloseTime)
assert(math.abs(returned-idleWidth)<1e-6 and math.abs(returnedGap-idleGap)<1e-6,'recovery did not repack the octahedron')
model:Destroy()
local prototype=Instance.new('UnionOperation')
prototype.Name='RamielHull';prototype.Size=Vector3.one*2.7;prototype.Parent=game:GetService('ReplicatedStorage')
local shellModel=newModel('Ramiel',true)
local shellRig=assert(DroneConfig.ramielRig(shellModel))
assert(shellRig.closed.LocalTransparencyModifier==0 and shellRig.slices[1].LocalTransparencyModifier==1,'the closed travel hull shows panel seams')
DroneConfig.poseRamiel(shellRig,pivot,aim,.6,nil,0,false)
assert(shellRig.closed.LocalTransparencyModifier==1 and shellRig.slices[1].LocalTransparencyModifier==0,'the closed hull blocked the attack')
DroneConfig.poseRamiel(shellRig,pivot,nil,0,nil,0,false)
assert(shellRig.closed.LocalTransparencyModifier==0 and shellRig.slices[1].LocalTransparencyModifier==1,'the travel hull did not close again')
shellModel:Destroy();prototype:Destroy()
print('PASS Ramiel keeps fixed-height glass layers and uses one closed hull for flight')
