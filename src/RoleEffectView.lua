-- Observe server-authored receipts. Every client renders locally, regardless
-- of ownership. State records also cover late joins and canceled abilities.
local View={}
local Debris=game:GetService('Debris')
local WHITE=Color3.fromRGB(255,248,231)
local TRAIL_LIMIT=12

local function shotPart(parent,name,size,color,ball,transparency)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.Color=color;part.Material=Enum.Material.Neon
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 if ball then part.Shape=Enum.PartType.Ball end
 part.Transparency=transparency or 0;part.Parent=parent
 return part
end

local function addRibbon(part,color,ball)
 local a=Instance.new('Attachment');a.Position=Vector3.new(0,ball and -.26 or -.085,.08);a.Parent=part
 local b=Instance.new('Attachment');b.Position=Vector3.new(0,ball and .26 or .085,.08);b.Parent=part
 local trail=Instance.new('Trail');trail.Name=ball and 'EnergyWake' or 'NeedleTrace'
 trail.Attachment0=a;trail.Attachment1=b;trail.FaceCamera=true;trail.LightInfluence=0;trail.LightEmission=.88
 trail.Lifetime=ball and .17 or .10;trail.MinLength=.055;trail.MaxLength=ball and 5 or 4
 trail.Color=ColorSequence.new(color:Lerp(WHITE,.35),color)
 trail.WidthScale=NumberSequence.new(1,0)
 trail.Transparency=NumberSequence.new(.16,1);trail.Parent=part
 return trail
end

local function sparks(from,direction,color,ball,impact)
 if BeamVFX.reduced() or not BeamVFX.near(from,76) then return end
 local node=shotPart(workspace.CurrentCamera,'ShotSparks',Vector3.one*.025,color,false,1)
 node.CFrame=CFrame.lookAt(from,from+direction)
 local burst=Instance.new('ParticleEmitter')
 burst.Texture='rbxasset://textures/particles/sparkles_main.dds';burst.Enabled=false
 burst.EmissionDirection=Enum.NormalId.Front;burst.SpreadAngle=Vector2.new(impact and 46 or 28,impact and 46 or 28)
 burst.Color=ColorSequence.new(WHITE,color);burst.LightInfluence=0;burst.LightEmission=.72
 burst.Lifetime=NumberRange.new(.08,ball and .24 or .16);burst.Speed=NumberRange.new(4,ball and 13 or 18);burst.Drag=8
 burst.Size=NumberSequence.new(ball and .21 or .13,0);burst.Transparency=NumberSequence.new(.11,1)
 burst.Parent=node;burst:Emit(ball and 8 or 5);Debris:AddItem(node,.29)
end

local function clearProjectile(self,r,now,carryTail)
 local part=r.projectile or r.after
 if r.trail and carryTail and r.projectile then
  part.Transparency=1;if r.shell then r.shell.Transparency=1 end
  r.trail.Enabled=false;r.after=part;r.afterUntil=now+r.trail.Lifetime
 else
  if part then part:Destroy() end
  if r.trail then self.trails-=1;r.trail=nil end
  r.after=nil
 end
 r.projectile=nil
end

function View.new(audio)
 local self={records={},connections={},root=nil,trails=0}
 local function attach(root)
  if self.root==root then return end
  self.root=root
  local function observe(node)
   if node:IsA('Folder') then self.records[node]={samples={}} end
  end
  for _,node in ipairs(root:GetChildren()) do observe(node) end
  self.connections[#self.connections+1]=root.ChildAdded:Connect(observe)
 end
 local root=workspace:FindFirstChild('DroneRoleState');if root then attach(root) end
 self.connections[#self.connections+1]=workspace.ChildAdded:Connect(function(node) if node.Name=='DroneRoleState' then attach(node) end end)
 function self:step(now,droneIndex,resources)
  for node,r in pairs(self.records) do
   local kind=node:GetAttribute('Kind');local owner=node -- isolate overlapping old/new effects for the same player
   if not node.Parent then
    clearProjectile(self,r,now,false)
    if r.started and kind=='AbilityCharge' then RoleVisuals.Ability(owner,{kind='clearCharge'}) end
    if r.started and kind=='Orbital' and not r.ended then RoleVisuals.Ability(owner,{kind='orbitalEnd'}) end
    self.records[node]=nil
   elseif kind=='MiningShot' then
    if r.after and now>=r.afterUntil then clearProjectile(self,r,now,false) end
    local from=node:GetAttribute('From');local to=node:GetAttribute('Position')
    local at=node:GetAttribute('StartedAt');local duration=node:GetAttribute('Duration');local paused=node:GetAttribute('PausedAt') or 0
    if typeof(from)~='Vector3' or typeof(to)~='Vector3' or type(at)~='number' or not duration or (to-from).Magnitude<.01 then continue end
    local progress=((paused>0 and paused or now)-at)/duration
    local drone=droneIndex and droneIndex[node:GetAttribute('Actor')]
    if drone and not r.bound and progress>=0 and progress<1 then
     r.bound=true
     local previous=drone.shotReceipt
     if not previous or at>(previous:GetAttribute('StartedAt') or 0) then drone.shotReceipt=node end
    end
    local contactAt=node:GetAttribute('ContactAt')
    local landed=contactAt and now>=contactAt
    local anchor=node:GetAttribute('TargetAnchor')
    local target=resources and resources[node:GetAttribute('TargetId') or '']
    if typeof(anchor)=='Vector3' and target and target.view.Parent and target.view.Transparency<1 then
     to=target.view.CFrame:PointToWorldSpace(anchor*target.view.Size)
    end
    local ball=node:GetAttribute('Shape')=='Ball'
    local color=node:GetAttribute('Color')
    if not color then continue end
    if landed and r.projectile and not r.impacted and now-contactAt<.20 then
     r.impacted=true
     if r.bound and drone then drone.shotImpactAt=now end
     local point=node:GetAttribute('ContactPoint') or to
     local travel=point-(r.launchFrom or from)
     if travel.Magnitude>.01 then
      sparks(point-travel.Unit*.04,-travel.Unit,color,ball,true)
      if ball then
       RoleVisuals.setTime(contactAt)
       RoleVisuals.Pulse(point,color,.23,1.85,.19)
      end
     end
    end
    local resolved=landed or (not contactAt and (progress>1+.16/duration or (not target and progress>=1)))
    if resolved then
     if r.projectile then clearProjectile(self,r,now,true) end
     r.started=true
    elseif progress>=0 and not r.started and (r.projectile or BeamVFX.near(from,140)) then
     local value=r.projectile
     if not value then
      local camera=workspace.CurrentCamera
      if not camera then continue end
      value=shotPart(camera,'MiningProjectile',ball and Vector3.one*.73 or Vector3.new(.14,.14,1.07),color:Lerp(WHITE,.58),ball)
      r.projectile=value
      if ball and not BeamVFX.reduced() then r.shell=shotPart(value,'EnergyShell',Vector3.one*1.06,color,true,.58) end
      local muzzle=drone and drone.shotMuzzle and drone.shotMuzzle.WorldPosition
      if muzzle and (muzzle-from).Magnitude<2.5 and (to-muzzle).Magnitude>1 then r.launchFrom=muzzle end
      from=r.launchFrom or from
      if self.trails<TRAIL_LIMIT and not BeamVFX.reduced() then
       r.trail=addRibbon(value,color,ball);self.trails+=1
      end
      if now-at<.13 and (to-from).Magnitude>.01 then
       sparks(from,(to-from).Unit,color,ball,false)
       if audio then audio:play('shot',from,{pitch=ball and .61 or 1.13,level=ball and .76 or .66}) end
      end
     end
     from=r.launchFrom or from
     local delta=to-from
     if delta.Magnitude<.01 then continue end
     local direction=delta.Unit
     local center=from:Lerp(to,math.min(progress,1))-direction*(value.Size.Z*.5)
     value.CFrame=CFrame.lookAt(center,center+direction)
     if r.shell then r.shell.CFrame=value.CFrame end
    end
   elseif kind=='Orbital' then
    local at=node:GetAttribute('ContactAt');local position=node:GetAttribute('Position');local ended=node:GetAttribute('EndedAt')
    if typeof(position)=='Vector3' and type(at)=='number' and now>=at then
     MotionBuffer.push(r.samples,at,CFrame.new(position))
     local pose=MotionBuffer.pose(r.samples,now)
     -- Do not replay completed strikes to a late joiner.
     if not ended or r.started then
      if not r.ended then
       RoleVisuals.setTime(at)
       RoleVisuals.Ability(owner,{kind='orbital',startedAt=node:GetAttribute('StartedAt') or at,target={x=pose.Position.X,y=pose.Position.Y,z=pose.Position.Z,
        ground=node:GetAttribute('Ground'),radius=node:GetAttribute('Radius')}})
       r.started=true
       if ended then RoleVisuals.setTime(ended);RoleVisuals.Ability(owner,{kind='orbitalEnd'});r.ended=true end
      end
     end
    end
   elseif not r.started and kind and kind~='ScrapSwarm' then
    local at=node:GetAttribute('StartedAt');local position=node:GetAttribute('Position')
    local from=node:GetAttribute('From')
    local needsFrom=kind=='Beam' or kind=='Heal' or kind=='Charge' or kind=='Grow' or kind=='Breaker'
    local ready=not needsFrom or typeof(from)=='Vector3'
    if kind=='Beam' or kind=='Pulse' then ready=ready and node:GetAttribute('Color')~=nil and type(node:GetAttribute('Duration'))=='number' end
    if kind=='Beam' then ready=ready and type(node:GetAttribute('Width'))=='number' end
    if kind=='Pulse' then ready=ready and type(node:GetAttribute('First'))=='number' and type(node:GetAttribute('Last'))=='number' end
    if kind=='Grow' then ready=ready and type(node:GetAttribute('Planted'))=='boolean' end
    if kind=='Charge' then ready=ready and type(node:GetAttribute('Impact'))=='boolean' end
    if kind=='Breaker' then ready=ready and type(node:GetAttribute('Phase'))=='string' end
    if kind=='AbilityCharge' or kind=='AbilityPulse' then ready=ready and type(node:GetAttribute('Ability'))=='string' end
    if ready and type(at)=='number' and typeof(position)=='Vector3' and now>=at then
     r.started=true
     local age=now-at
     local expires=node:GetAttribute('ExpiresAt') or at+1
     -- Short contact cues are never replayed as fresh hits after a late join.
     if now<expires and (age<=.35 or kind=='AbilityCharge' or kind=='Pulse' or kind=='Beam') then
      RoleVisuals.setTime(at)
      local from=node:GetAttribute('From');local color=node:GetAttribute('Color')
      if kind=='Beam' then RoleVisuals.Beam(from,position,color,node:GetAttribute('Width'),node:GetAttribute('Duration'))
      elseif kind=='Pulse' then RoleVisuals.Pulse(position,color,node:GetAttribute('First'),node:GetAttribute('Last'),node:GetAttribute('Duration'))
      elseif kind=='Heal' then RoleVisuals.Heal(from,position)
      elseif kind=='Charge' then RoleVisuals.Charge(from,position,node:GetAttribute('Impact'))
      elseif kind=='Grow' then RoleVisuals.Grow(from,position,node:GetAttribute('Planted'))
      elseif kind=='Breaker' then RoleVisuals.BreakerPhase(from,position,node:GetAttribute('Phase'),node:GetAttribute('Diameter'))
      elseif kind=='AbilityCharge' or kind=='AbilityPulse' then
       RoleVisuals.Ability(owner,{kind=kind=='AbilityCharge' and 'charge' or node:GetAttribute('Ability'),ability=node:GetAttribute('Ability'),duration=node:GetAttribute('Duration') or 1.4,target={x=position.X,y=position.Y,z=position.Z,ground=node:GetAttribute('Ground'),radius=node:GetAttribute('Radius')}})
      end
     end
    end
   end
  end
  RoleVisuals.setTime(nil);RoleVisuals.step(now)
 end
 function self:destroy()
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  for _,r in pairs(self.records) do clearProjectile(self,r,0,false) end
  table.clear(self.records);RoleVisuals.destroy()
 end
 return self
end
return View
