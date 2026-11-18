-- Four reusable local aftermath rigs. The charge hands off its existing smoke
-- to this independent clock; returning the lens lease cannot erase the launch.
local A={}
local active,pool={},{}
local connection
local BLUE=Color3.fromRGB(114,201,255)
-- Chromatic refraction visibly separates RGB channels; carry those saturated
-- output hues into the dust rather than tinting all fragments beam-blue.
local popColors={Color3.new(0,0,1),Color3.new(0,1,1),Color3.new(1,0,1),
 Color3.new(0,1,0),Color3.new(1,1,0),Color3.new(1,0,0)}
function A.palette(color,index)
 return popColors[(index-1)%#popColors+1]
end
local function part(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Transparency=1;p.Size=Vector3.one*.025;p.Parent=parent;return p
end
-- Where the charge's energy goes at ignition (the reference shows this
-- clearly): the lifted cubes are thrown outward, a flash blooms at the source,
-- lightning forks out, thin shock arcs race away, the dark void blows open and
-- a smoke cloud lingers. All of it outlives the charge rig and the drone.
A.LIMIT=8
local SOFT='rbxasset://textures/ui/AvatarExperience/glowLight.png'
local WHITE=Color3.new(1,1,1)
local function smooth(v) v=math.clamp(v,0,1);return v*v*(3-2*v) end
local function hash(n)
 local x=math.sin(n*12.9898)*43758.5453
 return x-math.floor(x)
end
local function line(root,name,width)
 local a=Instance.new('Attachment');a.Parent=root
 local b=Instance.new('Attachment');b.Parent=root
 local beam=Instance.new('Beam');beam.Name=name;beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=true
 beam.Segments=10;beam.LightEmission=1;beam.LightInfluence=0;beam.Brightness=2;beam.Color=ColorSequence.new(WHITE)
 beam.Width0=width;beam.Width1=width;beam.Enabled=false;beam.Parent=root
 return {a=a,b=b,beam=beam}
end
local function create()
 local root=part(nil,'LaserLaunchAftermath')
 local f={root=root,smoke={},chips={},plane=PlaneBurst.create(root,BLUE),cubes={},zig={},arcs={}}
 for i=1,8 do
  local p=part(root,'BlastCube');p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(58,62,90);f.cubes[i]=p
 end
 f.flash=EnergyDisc.sprite(root,'IgnitionFlash');f.flash.image.Image=SOFT
 f.dark=EnergyDisc.sprite(root,'IgnitionVoid');f.dark.image.Image=SOFT
 for i=1,8 do f.zig[i]=line(root,'IgnitionFork',.06);f.zig[i].beam.Segments=1 end
 for i=1,3 do
  f.arcs[i]=line(root,'ShockArc',.1)
  f.arcs[i].beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(1,1)})
 end
 local source=Instance.new('Attachment');source.Name='IgnitionPuffSource';source.Parent=root
 f.puff=Instance.new('ParticleEmitter');f.puff.Name='IgnitionSmoke'
 EnergyDisc.smoke(f.puff,1.5,.5)
 f.puff.Enabled=false;f.puff.Rate=0;f.puff.Lifetime=NumberRange.new(.9,1.6);f.puff.Speed=NumberRange.new(4,9);f.puff.Drag=4
 f.puff.SpreadAngle=Vector2.new(180,180);f.puff.Acceleration=Vector3.new(0,1.2,0);f.puff.Parent=source
 f.puffSource=source
 for i=1,6 do
  local a=Instance.new('Attachment');a.Name='SmokeSector';a.Parent=root
  local e=Instance.new('ParticleEmitter');e.Name='PersistentBeamSmoke'
  EnergyDisc.configure(e,1.46,.71,.52,1.26)
  e.Enabled=false;e.Rate=0;e.LockedToPart=false;e.VelocityInheritance=0;e.WindAffectsDrag=false
  e.Lifetime=NumberRange.new(1.25,1.8);e.Speed=NumberRange.new(.15,.4);e.Drag=3
  e.SpreadAngle=Vector2.new(40,40);e.Color=ColorSequence.new(BLUE)
  e.LightEmission=.25;e.LightInfluence=0;e.Brightness=1.1
  e.Rotation=NumberRange.new(-180,180);e.RotSpeed=NumberRange.new(-18,18);e.Parent=a
  f.smoke[i]={a=a,e=e}
 end
 -- Six small chromatic accents preserve the distinct flash colors.
 for i=1,6 do
  local p=part(root,'ElectricColorFragment');p.Material=Enum.Material.Neon;p.Color=A.palette(BLUE,i)
  p.Size=Vector3.new(.035+(i%3)*.009,.035,.075+(i%4)*.025);f.chips[i]=p
 end
 return f
end
local function retire(f)
 if f.owner then f.owner.aftermath=nil end
 f.owner=nil;f.phase=nil;f.lastEmission=nil;f.emissionSector=0
 for _,s in ipairs(f.smoke) do s.e:Clear();s.e.Acceleration=Vector3.zero end
 for _,p in ipairs(f.chips) do p.Transparency=1 end
 A.hideBlast(f);f.blast=nil
 PlaneBurst.hide(f.plane);f.root.Parent=nil
 if #pool<A.LIMIT then pool[#pool+1]=f else f.root:Destroy() end
end
function A.hideBlast(f)
 for _,p in ipairs(f.cubes) do p.Transparency=1 end
 for _,z in ipairs(f.zig) do z.beam.Enabled=false end
 for _,z in ipairs(f.arcs) do z.beam.Enabled=false end
 f.flash.gui.Enabled=false;f.dark.gui.Enabled=false
end
-- age is seconds since ignition. Everything is a pure function of age, so any
-- frame rate and a late first frame draw the same burst.
function A.drawBlast(f,age)
 local b=f.blast
 if not b or age>=1 then A.hideBlast(f);return end
 local k=b.scale;local focus=b.focus
 local camera=workspace.CurrentCamera
 local toward=camera and (camera.CFrame.Position-focus) or Vector3.zAxis
 toward=toward.Magnitude>.01 and toward.Unit or Vector3.zAxis
 -- Cubes: hard launch, heavy braking, a little fall, spinning as they shrink out.
 for i,p in ipairs(f.cubes) do
  local c=b.cubes[i]
  if not c or age>.85 then p.Transparency=1 else
   local out=c.position-focus
   out=out.Magnitude>.05 and out.Unit or Vector3.new(math.cos(i*2.4),.2,math.sin(i*2.4)).Unit
   local speed=k*(20+16*hash(i+3))
   local travel=speed*(1-math.exp(-age*6))/6
   local position=c.position+(out+Vector3.yAxis*.25).Unit*travel-Vector3.yAxis*k*4*age*age
   local size=c.size*(1-smooth((age-.25)/.6))
   p.Size=Vector3.one*math.max(.02,size)
   p.CFrame=CFrame.new(position)*CFrame.Angles(age*(9+i),age*(7-i*.6),i)
   p.Transparency=size<=.03 and 1 or 0
  end
 end
 -- Flash: blooms in a couple of frames, then fades from white to the beam color.
 local bloom=1-math.exp(-age*28)
 local fade=1-smooth(age/.34)
 EnergyDisc.place(f.flash,focus+toward*.6*k,k*(1.5+5.5*bloom),WHITE:Lerp(b.color,smooth(age/.25)*.7),fade*smooth(age/.025+.35))
 -- The dark void blows open and thins away.
 local open=smooth(age/.34)
 EnergyDisc.place(f.dark,focus+(b.voidOffset or -toward*3*k),k*(9+11*open)*(b.voidGrow or 1),Color3.new(0,0,0),.72*(1-open))
 -- Lightning forks: two jagged paths. Each strike swells and fades, and the two
 -- are half a beat apart, so one is always handing over to the other.
 for fork=1,2 do
  local clock=age/.11+(fork-1)*.5
  local strike=math.floor(clock);local phase=clock-strike
  local seed=strike*7.3+fork*31+b.seed
  local a=hash(seed)*math.pi*2
  local heading=(f.right*math.cos(a)+f.up*math.sin(a)+Vector3.yAxis*(hash(seed+1)-.3)).Unit
  local side=heading:Cross(toward);side=side.Magnitude>.01 and side.Unit or f.right
  local strength=b.full and math.sin(math.pi*phase)^1.5*(1-smooth(age/.36)) or 0
  local previous=Vector3.zero
  for segment=1,4 do
   local z=f.zig[(fork-1)*4+segment]
   if strength<.03 then z.beam.Enabled=false else
    local point=heading*k*(.8*segment+.4*hash(seed+segment))+side*k*(hash(seed+segment*3)-.5)*1.1
    z.a.Position=b.focus-f.root.Position+previous;z.b.Position=b.focus-f.root.Position+point
    local w=k*.07*strength
    z.beam.Width0=w;z.beam.Width1=w*.8;z.beam.Enabled=true
    previous=point
   end
  end
 end
 -- Shock arcs race outward across the firing plane.
 for i,arc in ipairs(f.arcs) do
  local life=math.clamp(age/.5,0,1)
  if life>=1 or not b.full then arc.beam.Enabled=false else
   local radius=k*(1+4.6*(1-math.exp(-age*8)))
   local a0=hash(b.seed+i*13)*math.pi*2;local span=.9+.5*hash(b.seed+i)
   local function at(a) return (f.right*math.cos(a)+f.up*math.sin(a))*radius end
   local function tan(a) return (-f.right*math.sin(a)+f.up*math.cos(a)) end
   local offset=b.focus-f.root.Position
   local t0,t1=tan(a0),tan(a0+span)
   local up0=f.direction
   arc.a.CFrame=CFrame.fromMatrix(offset+at(a0),t0,up0,t0:Cross(up0))
   arc.b.CFrame=CFrame.fromMatrix(offset+at(a0+span),t1,up0,t1:Cross(up0))
   arc.beam.CurveSize0=radius*span/3;arc.beam.CurveSize1=radius*span/3
   local w=k*.16*(1-smooth(life))*smooth(age/.05)
   arc.beam.Width0=w;arc.beam.Width1=w;arc.beam.Enabled=true
  end
 end
end
function A.cancel(owner,now)
 local f=owner.aftermath
 if not f then return end
 owner.aftermath=nil;f.owner=nil
 if f.phase=='charge' then
  f.phase='settle';f.updatedAt=math.max(f.updatedAt,now or workspace:GetServerTimeNow())
  for _,s in ipairs(f.smoke) do s.e.Acceleration=Vector3.zero end
 end
end
function A.clear()
 for i=#active,1,-1 do retire(table.remove(active,i)) end
 for _,f in ipairs(pool) do f.root:Destroy() end
 table.clear(pool)
 if connection then connection:Disconnect();connection=nil end
end
function A.step(now)
 for i=#active,1,-1 do
  local f=active[i];local age=f.firedAt and now-f.firedAt or 0
  if f.phase=='release' then A.drawBlast(f,math.max(0,age)) end
  if not f.root.Parent or (f.phase=='release' and age>=1.8) or (f.phase=='settle' and now-f.updatedAt>=1.8) then
   table.remove(active,i);retire(f)
  elseif f.phase=='charge' and now-f.updatedAt>.25 then
   if f.owner then A.cancel(f.owner,now) end
  elseif f.phase=='release' then
   -- Brief pressure impulse acts on particles already emitted during charge.
   local pressure=180*math.exp(-math.max(0,age)*35)
   for _,s in ipairs(f.smoke) do s.e.Acceleration=s.radial*pressure; s.e.Drag=7 end
   PlaneBurst.draw(f.plane,f.direction,age/1.1,f.scale)
   for n,p in ipairs(f.chips) do
    local t=age-(n%3)*.004
    local life=1.25+(n%4)*.07
    if t>=0 and t<life then
     local offset=PullMotion.discharge(n,t)*f.scale
     local position=f.root.Position+f.right*offset.X+f.direction*(-offset.Y)+f.up*offset.Z
     local nextOffset=PullMotion.discharge(n,math.min(1.5,t+.008))*f.scale
     local velocity=nextOffset-offset
     local direction=f.right*velocity.X-f.direction*velocity.Y+f.up*velocity.Z
     if direction.Magnitude>.0001 then
      p.CFrame=CFrame.lookAt(position,position+direction, f.direction)*CFrame.Angles(0,0,n*2.399963)
     else p.CFrame=CFrame.new(position) end
     p.Transparency=1-.6*smooth(t/.05)*(1-smooth((t-.45)/(life-.45)))
    else p.Transparency=1 end
   end
  end
 end
 if #active==0 and connection then connection:Disconnect();connection=nil end
end
function A.charge(owner,origin,direction,now,q,scale)
 local f=owner.aftermath
 if not f then
  if #active>=A.LIMIT then return end
  f=table.remove(pool) or create();f.owner=owner;owner.aftermath=f
  f.phase='charge';f.firedAt=nil;f.root.Parent=workspace;active[#active+1]=f
  if not connection then
   local run=game:GetService('RunService')
   connection=(run.RenderStepped or run.Heartbeat):Connect(function() if not A.isHeld or not A.isHeld() then A.step(workspace:GetServerTimeNow()) end end)
  end
 end
 f.root.CFrame=CFrame.new(origin);f.updatedAt=now;f.scale=math.min(scale or 1,1.5)
 local color=owner.color or BLUE
 if f.color~=color then
  f.color=color
  for _,s in ipairs(f.smoke) do s.e.Color=ColorSequence.new(color) end
  for i,p in ipairs(f.chips) do p.Color=A.palette(color,i) end
  for _,r in ipairs(f.plane.rays) do r.beam.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.2)) end
 end
 f.direction=direction
 local ref=math.abs(direction.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 f.right=direction:Cross(ref).Unit;f.up=f.right:Cross(direction).Unit
 for i,s in ipairs(f.smoke) do
  local angle=i*math.pi/3
  s.radial=f.right*math.cos(angle)+f.up*math.sin(angle)
  s.a.Position=s.radial*(.54-.32*q)*f.scale
  s.e.Acceleration=-s.radial*.25
 end
 if q>.32 and q<.99 and (not f.lastEmission or now-f.lastEmission>=.28) then
  for i=1,2 do f.smoke[((f.emissionSector or 0)+i-1)%6+1].e:Emit(1) end
  f.emissionSector=((f.emissionSector or 0)+2)%6
  f.lastEmission=now
 end
end
function A.fire(owner,origin,direction,now,age)
 local f=owner.aftermath
 if not f then return end
 if not age or age<0 or age>.16 then A.cancel(owner,now);return end
 f.root.CFrame=CFrame.new(origin);f.direction=direction;f.phase='release';f.firedAt=now-age
 -- The launched tail no longer belongs to a charge lease or moving drone.
 f.owner=nil;owner.aftermath=nil
 f.blast=owner.blast;owner.blast=nil
 if f.blast then
  f.puffSource.WorldPosition=f.blast.focus
  f.puff.Color=ColorSequence.new(f.blast.color:Lerp(Color3.new(1,1,1),.35),f.blast.color:Lerp(Color3.new(0,0,0),.4))
  f.puff:Emit(f.blast.full and 9 or 3)
 end
 for _,s in ipairs(f.smoke) do s.e:Emit(1) end
 A.step(now)
end
function A.counts() return #active,#pool end
return A
