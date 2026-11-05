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
local function create()
 local root=part(nil,'LaserLaunchAftermath')
 local f={root=root,smoke={},chips={},plane=PlaneBurst.create(root,BLUE)}
 for i=1,6 do
  local a=Instance.new('Attachment');a.Name='SmokeSector';a.Parent=root
  local e=Instance.new('ParticleEmitter');e.Name='PersistentBeamSmoke';e.Texture='rbxasset://textures/particles/smoke_main.dds'
  e.Enabled=false;e.Rate=0;e.LockedToPart=false;e.VelocityInheritance=0;e.WindAffectsDrag=false
  e.Lifetime=NumberRange.new(1.25,1.8);e.Speed=NumberRange.new(.15,.4);e.Drag=3
  e.SpreadAngle=Vector2.new(40,40);e.Color=ColorSequence.new(BLUE)
  e.LightEmission=.25;e.LightInfluence=0;e.Brightness=1.1
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.32,1.25),NumberSequenceKeypoint.new(1,2.2)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(.12,.68),NumberSequenceKeypoint.new(.55,.8),NumberSequenceKeypoint.new(1,1)})
  e.Rotation=NumberRange.new(-180,180);e.RotSpeed=NumberRange.new(-18,18);e.Parent=a
  f.smoke[i]={a=a,e=e}
 end
 for i=1,18 do
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
 PlaneBurst.hide(f.plane);f.root.Parent=nil
 if #pool<4 then pool[#pool+1]=f else f.root:Destroy() end
end
local function remove(f)
 for i=#active,1,-1 do if active[i]==f then table.remove(active,i);retire(f);return end end
end
function A.cancel(owner)
 if owner.aftermath then remove(owner.aftermath) end
end
function A.clear()
 for i=#active,1,-1 do retire(table.remove(active,i)) end
 for _,f in ipairs(pool) do f.root:Destroy() end
 table.clear(pool)
 if connection then connection:Disconnect();connection=nil end
end
function A.step(now)
 local camera=workspace.CurrentCamera
 local player=game:GetService('Players').LocalPlayer
 local reduced=player and (player:GetAttribute('ReducedEffects') or player:GetAttribute('MA_ReducedEffects') or player:GetAttribute('ReducedMotion') or player:GetAttribute('MA_ReducedMotion'))
 for i=#active,1,-1 do
  local f=active[i];local age=f.firedAt and now-f.firedAt or 0
  local far=camera and (camera.CFrame.Position-f.root.Position).Magnitude>120
  if not f.root.Parent or reduced or far or (f.phase=='release' and age>=1.8) or (f.phase=='charge' and now-f.updatedAt>.25) then
   table.remove(active,i);retire(f)
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
     p.Transparency=math.clamp((t-.45)/(life-.45),0,1)
    else p.Transparency=1 end
   end
  end
 end
 if #active==0 and connection then connection:Disconnect();connection=nil end
end
function A.charge(owner,origin,direction,now,q,scale)
 local f=owner.aftermath
 if not f then
  if #active>=4 then return end
  f=table.remove(pool) or create();f.owner=owner;owner.aftermath=f
  f.phase='charge';f.firedAt=nil;f.root.Parent=workspace;active[#active+1]=f
  if not connection then
   local run=game:GetService('RunService')
   connection=(run.RenderStepped or run.Heartbeat):Connect(function() A.step(workspace:GetServerTimeNow()) end)
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
  s.a.Position=s.radial*(.12+.45*q)*f.scale
  s.e.Acceleration=s.radial*.15
 end
 if q>.32 and q<.99 and (not f.lastEmission or now-f.lastEmission>=.24) then
  for i=1,3 do f.smoke[((f.emissionSector or 0)+i-1)%6+1].e:Emit(1) end
  f.emissionSector=((f.emissionSector or 0)+3)%6
  f.lastEmission=now
 end
end
function A.fire(owner,origin,direction,now,age)
 local f=owner.aftermath
 if not f then return end
 if not age or age<0 or age>.16 then A.cancel(owner);return end
 f.root.CFrame=CFrame.new(origin);f.direction=direction;f.phase='release';f.firedAt=now-age
 -- The launched tail no longer belongs to a charge lease or moving drone.
 f.owner=nil;owner.aftermath=nil
 for _,s in ipairs(f.smoke) do s.e:Emit(2) end
 A.step(now)
end
function A.counts() return #active,#pool end
return A
