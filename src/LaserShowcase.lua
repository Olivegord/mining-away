-- Stationary local viewmodels, never fleet members or server reward sources.
-- Reuses the production laser, specialist, particle and hardware renderers.
local Showcase={}
local definitions={
 {name='REGULAR LASER',role='Striker',color=Color3.fromRGB(114,201,255)},
 {name='BUBBLER',role='Bubbler',color=Color3.fromRGB(105,224,255)},
 {name='SPIRAL',role='Singularity',color=Color3.fromRGB(182,137,255)},
 {name='COMBAT LASER',role='Combat',color=Color3.fromRGB(255,116,99)},
 {name='HALVER',role='Halver',color=Color3.fromRGB(255,179,77)},
 {name='GRIDCUTTER',role='Gridcutter',color=Color3.fromRGB(255,92,109)},
}
local period,charge,attack=7.9,3.2,4.5 -- Longer readable charge, still only 0.2 seconds idle.
local function clean(model)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('SurfaceGui') or v:IsA('Sound') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA('Beam') or v:IsA('Trail') or v:IsA('ParticleEmitter') or v:IsA('Light') then v.Enabled=false end
 end
end
local function part(parent,name,position,size,color)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.Size=size;p.Position=position;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Parent=parent;return p
end
local function label(p,text)
 local g=Instance.new('SurfaceGui');g.Face=Enum.NormalId.Top;g.CanvasSize=Vector2.new(640,160);g.Parent=p
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1
 t.Text=text;t.TextColor3=Color3.fromRGB(236,243,255);t.TextSize=45;t.Font=Enum.Font.GothamBold;t.Parent=g
end
function Showcase.new(world,parent,config)
 local self={world=world,parent=parent,stations={},nextAttempt=0}
 function self:build()
  local rs=game:GetService('ReplicatedStorage')
  local drone=rs:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
  local rock
  for _,v in ipairs(world:GetDescendants()) do if v:IsA('BasePart') and v:GetAttribute('ResourceId') then rock=v;break end end
  local home=world:GetAttribute('DepotHome')
  if not drone or not rock or typeof(home)~='Vector3' then return false end
  local root=Instance.new('Folder');root.Name='HomeEffectsPreview';root.Parent=parent;self.root=root
  -- The west side of the hub leaves the central walk and ramp approaches clear.
  self.center=home+Vector3.new(-27,0,-31)
  local params=RaycastParams.new()
  params.FilterDescendantsInstances={parent}
  params.RespectCanCollide=true
  local function grounded(pos)
   local hit=workspace:Raycast(pos+Vector3.yAxis*8,-Vector3.yAxis*32,params)
   return Vector3.new(pos.X,hit and hit.Position.Y or home.Y,pos.Z)
  end
  local signPos=grounded(self.center+Vector3.zAxis*18)+Vector3.yAxis*.07
  local sign=part(root,'PreviewTitle',signPos,Vector3.new(24,.12,3),Color3.fromRGB(24,34,49))
  label(sign,'EFFECTS PREVIEW  /  INFINITE ROCKS')
  for i,def in ipairs(definitions) do
   local column=(i-1)%3
   local row=math.floor((i-1)/3)
   local pos=grounded(self.center+Vector3.new((column-1)*13,0,9-row*18))
   local station=Instance.new('Model');station.Name=def.name;station:SetAttribute('EffectsPreview',true);station.Parent=root
   part(station,'DisplayPad',pos+Vector3.yAxis*.06,Vector3.new(9,.12,9),Color3.fromRGB(41,49,58))
   local plaque=part(station,'Nameplate',pos+Vector3.new(0,.15,5.4),Vector3.new(9,.12,1.7),Color3.fromRGB(24,34,49));label(plaque,def.name)
   local target=rock:Clone();target.Name='InfiniteDisplayRock';clean(target)
   for key in pairs(target:GetAttributes()) do target:SetAttribute(key,nil) end
   target.Anchored=true;target.CanCollide=false;target.CanTouch=false;target.CanQuery=false;target.LocalTransparencyModifier=0
   target.Size=Vector3.new(3.4,3.8,3.4);target.CFrame=CFrame.new(pos+Vector3.yAxis*2.02);target.Transparency=0
   target:SetAttribute('ResourceId','preview:'..i);target:SetAttribute('InfiniteHealth',true)
   target:SetAttribute('HP',1e30);target:SetAttribute('MaxHP',1e30);target.Parent=station
   local model=drone:Clone();model.Name='DisplayDrone';clean(model)
   model.PrimaryPart=model.PrimaryPart or model:FindFirstChild('Mesh') or model:FindFirstChildWhichIsA('BasePart',true)
   model:ScaleTo(model:GetScale()*config.Swarm.ModelScale)
   config.decorate(model,def.role=='Combat' and 'Striker' or def.role)
   DroneOutline.attach(model);model.Parent=station;model:PivotTo(CFrame.new(pos+Vector3.yAxis*12))
   local emitter=model:FindFirstChild('Emmiter',true) or model:FindFirstChild('MiningEmitter',true) or model:FindFirstChild('Emitter',true)
   if emitter then emitter.Color=def.color end
   local state=Instance.new('Folder');state.Name='DisplayState';state:SetAttribute('DroneId','preview:'..i);state.Parent=station
   self.stations[#self.stations+1]={model=model,emitter=emitter,source=state,rock=target,def=def,pos=pos,index=i,
    motion=SpecialDroneMotion.new(model,def.role)}
  end
  return true
 end
 function self:suspend()
  if not self.presentation then return end
  for _,s in ipairs(self.stations) do
   if s.beam then self.presentation:destroyMiningBeam(s.beam);s.beam=nil end
   BeamVFX.destroy(s.rig);s.rig=nil;s.cycle=nil
  end
  self.special:destroy();self.special=nil;self.presentation:destroy();self.presentation=nil
  BeamVFX.clearChargeCache()
 end
 function self:step(now,dt)
  if not self.root then
   if now<self.nextAttempt then return end
   self.nextAttempt=now+1;if not self:build() then return end
  end
  if not BeamVFX.near(self.center,85) or BeamVFX.reduced() then self:suspend();return end
  if not self.presentation then
   self.presentation=Presentation.new({parent=self.root})
   self.special=DroneFX.new(self.root,{maxDistance=100,reuseGeometry=true})
   self.special.folder.Name='HomePreviewSpecialEffects'
  end
  for _,s in ipairs(self.stations) do
   if not s.emitter then continue end
   local shifted=now+(s.index-1)*1.15;local cycle=math.floor(shifted/period)
   local t=shifted-cycle*period;local start=now-t
   local active=t>=charge and t<charge+attack
   local special=s.def.role~='Striker' and s.def.role~='Combat'
   if s.cycle~=cycle then
    s.cycle=cycle;s.rock:SetAttribute('EffectCancelledSerial',0);s.rock:SetAttribute('EffectDoneAt',0)
    s.rock:SetAttribute('EffectDepleted',false);s.rock:SetAttribute('EffectType',special and s.def.role or nil)
    s.rock:SetAttribute('EffectDrone','preview:'..s.index);s.rock:SetAttribute('EffectStartedAt',start+charge)
    s.rock:SetAttribute('EffectDuration',attack);s.rock:SetAttribute('EffectSerial',0)
   end
   if special and t>=charge and s.rock:GetAttribute('EffectSerial')==0 then s.rock:SetAttribute('EffectSerial',cycle+1) end
   local state=t<charge and 'Warmup' or active and (special and 'SpecialMine' or 'Mine') or 'Recover'
   if s.state~=state then s.source:SetAttribute('State',state);s.state=state end
   if special and t>=charge+attack*.68 and (s.rock:GetAttribute('EffectDoneAt') or 0)==0 then
    s.rock:SetAttribute('EffectDoneAt',start+charge+attack*.68)
   end
   s.model:PivotTo(CFrame.new(s.pos+Vector3.new(0,12+math.sin(now*1.4+s.index)*.12,0)))
   SpecialDroneMotion.step(s.motion,s.source,s.rock,now)
   if not s.beam then s.beam=self.presentation:createMiningBeam(s.model,s.emitter);s.beam.tint=s.def.color end
   if not s.rig then s.rig=BeamVFX.new(s.beam.holder,s.def.role=='Combat' and 'Combat' or 'Cutter',s.def.color);BeamVFX.startup(s.rig,BeamVFX.startupStyles[s.def.role]) end
   local from=s.beam.origin.WorldPosition;local tip=Vector3.new(from.X,s.rock.Position.Y+s.rock.Size.Y*.5,from.Z)
   s.beam.marker.Position=tip
   if t<charge then BeamVFX.draw(s.rig,from,from-Vector3.yAxis,now,0,t/charge,nil,BeamVFX.MiningScale,charge)
   elseif active and (not special or t-charge<.16) then BeamVFX.draw(s.rig,from,tip,now,special and 0 or 1,nil,t-charge,BeamVFX.MiningScale)
   else BeamVFX.hide(s.rig,false) end
   self.presentation.work:mining(s.beam,{alive=true,isMining=not special,active=active and not special,charging=t<charge,
    paused=false,warmupStart=start,warmupDuration=charge,key=s.index,life=1,style='Cutter',since=start+charge},tip,Vector3.yAxis,active and not special and 1 or 0,0,now)
  end
  self.special:step(now,dt)
  -- These stations only own mining emitters. The main presentation already
  -- updates orbital attacks; running it here duplicates those world effects.
 end
 function self:destroy() self:suspend();if self.root then self.root:Destroy() end end
 return self
end
return Showcase
