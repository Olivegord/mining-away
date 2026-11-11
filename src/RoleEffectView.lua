-- Observe server-authored receipts. Every client renders locally, regardless
-- of ownership. State records also cover late joins and canceled abilities.
local View={}
local Players=game:GetService('Players')
local WHITE=Color3.fromRGB(255,248,231)
local PRISM_RED=Color3.fromRGB(249,22,60)
local TRAIL_LIMIT,SHOT_LIMIT,BURST_LIMIT=12,18,12

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
 trail.Lifetime=ball and .16 or .085;trail.MinLength=.055;trail.MaxLength=ball and 5 or 3.5
 trail.Color=ColorSequence.new(color:Lerp(WHITE,.35),color)
 trail.WidthScale=NumberSequence.new(1,0)
 trail.Transparency=NumberSequence.new(.16,1);trail.Parent=part
 return trail
end

local function burst(self,from,direction,color,ball,impact,grade,at)
 local camera=workspace.CurrentCamera
 if not camera or #self.bursts>=BURST_LIMIT or BeamVFX.reduced() or not BeamVFX.near(from,76) then return end
 local node=shotPart(camera,'ShotSparks',Vector3.one*.025,color,false,1)
 node.CFrame=CFrame.lookAt(from,from+direction)
 local sparks=Instance.new('ParticleEmitter')
 sparks.Texture='rbxasset://textures/particles/sparkles_main.dds';sparks.Enabled=false
 local spread=impact and (ball and 76 or 37) or (ball and 34 or 17)
 sparks.EmissionDirection=Enum.NormalId.Front;sparks.SpreadAngle=Vector2.new(spread,spread)
 sparks.Color=ColorSequence.new(WHITE,color);sparks.LightInfluence=0;sparks.LightEmission=.8
 sparks.Lifetime=NumberRange.new(.12,ball and .56 or .34)
 sparks.Speed=NumberRange.new(impact and 9 or 6,(ball and 19 or 24)*grade);sparks.Drag=ball and 3.8 or 5.6
 sparks.Acceleration=Vector3.new(0,-5,0)
 sparks.Size=NumberSequence.new((ball and .28 or .16)*grade,0);sparks.Transparency=NumberSequence.new(.04,1)
 sparks.Parent=node;sparks:Emit(ball and math.floor((impact and 14 or 7)*grade) or (impact and 8 or 4))
 local flash=shotPart(node,'ShotFlash',Vector3.one*.04,color:Lerp(WHITE,.57),ball,.09)
 flash.CFrame=node.CFrame
 local ring=ball and PlaneBurst.create(node,color) or nil
 self.bursts[#self.bursts+1]={node=node,flash=flash,ring=ring,direction=direction,at=at,scale=(ball and (impact and 1 or .47) or .46)*grade,ball=ball}
end
local function stepBursts(self,now)
 for i=#self.bursts,1,-1 do
  local b=self.bursts[i];local age=math.max(0,now-b.at)
  if age>=.61 or not b.node.Parent or BeamVFX.reduced() then
   b.node:Destroy();table.remove(self.bursts,i)
  else
   local flash=math.clamp(1-age/(b.ball and .095 or .062),0,1)
   local player=Players.LocalPlayer
   b.flash.Transparency=1-(player and player:GetAttribute('ReducedFlashing') and .23 or .82)*flash
   b.flash.Size=(b.ball and Vector3.one or Vector3.new(.36,.36,1.85))*math.max(.04,b.scale*(1.15-.65*flash))
   if b.ring then PlaneBurst.draw(b.ring,b.direction,age/.24,b.scale*.88) end
  end
 end
end

local function clearProjectile(self,r,now,carryTail)
 local part=r.projectile or r.after
 if r.trail and carryTail and r.projectile then
  part.Transparency=1;if r.shell then r.shell.Transparency=1 end
  r.trail.Enabled=false;r.after=part;r.afterUntil=now+r.trail.Lifetime
 else
  if part then part:Destroy() end
  if part then self.heads-=1 end
  if r.trail then self.trails-=1;r.trail=nil end
  r.after=nil
 end
 r.projectile=nil
end

function View.new(audio)
 local self={records={},connections={},root=nil,trails=0,heads=0,bursts={}}
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
    if typeof(from)~='Vector3' or typeof(to)~='Vector3' or type(at)~='number' or type(duration)~='number' or duration<=0 or (to-from).Magnitude<.01 then continue end
    local windup=node:GetAttribute('Windup') or 0
    local age=(paused>0 and math.min(paused,now) or now)-at
    local progress=(age-windup)/duration
    local drone=droneIndex and droneIndex[node:GetAttribute('Actor')]
    local contactAt=node:GetAttribute('ContactAt')
    local landed=contactAt and now>=contactAt
    if drone and not r.bound and age>=0 and (progress<1 and not landed or node:GetAttribute('Shape')=='Prism' and age<windup+.35) then
     r.bound=true
     local previous=drone.shotReceipt
     if not previous or at>(previous:GetAttribute('StartedAt') or 0) then drone.shotReceipt=node end
    end
    local anchor=node:GetAttribute('TargetAnchor')
    local target=resources and resources[node:GetAttribute('TargetId') or '']
    if typeof(anchor)=='Vector3' and target and target.view.Parent and target.view.Transparency<1 then
     to=target.view.CFrame:PointToWorldSpace(anchor*target.view.Size)
    end
    local shape=node:GetAttribute('Shape')
    local ball=shape=='Ball'
    local color=node:GetAttribute('Color')
    if not color then continue end
    if shape=='Prism' then
     if landed and not r.impacted then
      r.impacted=true
      local point=node:GetAttribute('ContactPoint') or to
      local origin=drone and (drone.ramiel and drone.ramiel.core.Position or drone.view:GetPivot().Position) or from
      local travel=point-origin
      if now-contactAt<.18 and travel.Magnitude>.1 and BeamVFX.near(point,132) then
       RoleVisuals.setTime(contactAt)
       local reduced=BeamVFX.reduced() or Players.LocalPlayer:GetAttribute('ReducedFlashing')==true
       RoleVisuals.Beam(origin,point,PRISM_RED,reduced and 1.45 or 4.1,.36,'Prism')
       if not reduced then
        burst(self,point+(node:GetAttribute('ContactNormal') or -travel.Unit)*.25,
         node:GetAttribute('ContactNormal') or -travel.Unit,PRISM_RED,true,true,1.35,now)
       end
       if audio then audio:play('prism_fire',origin);audio:play('coil_hit',point,{level=1.25,pitch=.77}) end
      end
     end
     continue
    end
    local muzzle=drone and drone.shotMuzzle and drone.shotMuzzle.WorldPosition
    if muzzle and ((muzzle-from).Magnitude>=2.5 or (to-muzzle).Magnitude<=1) then muzzle=nil end
    if ball and windup>0 and not r.loaded and age>=0 and progress<0 and not landed then
     r.loaded=true
     if paused<=0 and age<.11 and audio then audio:play('coil_load',muzzle or from) end
    end
    if landed and not r.impacted then
     r.impacted=true
     local point=node:GetAttribute('ContactPoint') or to
     local travel=point-(r.launchFrom or from)
     if now-contactAt<.16 and travel.Magnitude>.01 then
      local normal=node:GetAttribute('ContactNormal') or -travel.Unit
      local fractured=node:GetAttribute('ContactFracture') or node:GetAttribute('ContactBroken')
      local grade=fractured and 1.3 or (node:GetAttribute('ContactPowered') and 1.12 or .88)
      burst(self,point+normal*(ball and .34 or .065),normal,color,ball,true,grade,now)
      if audio then audio:play(ball and 'coil_hit' or 'needle_hit',point,{level=grade,pitch=fractured and .91 or 1}) end
     end
    end
    local resolved=landed or (not contactAt and (progress>1+.16/duration or (not target and progress>=1)))
    if resolved then
     if r.projectile then clearProjectile(self,r,now,true) end
     r.started=true
    elseif progress>=0 and not r.started and (r.projectile or BeamVFX.near(from,140)) then
     local value=r.projectile
     if not value and self.heads<SHOT_LIMIT then
      local camera=workspace.CurrentCamera
      if not camera then continue end
      value=shotPart(camera,'MiningProjectile',ball and Vector3.one*.81 or Vector3.new(.15,.15,1.48),color:Lerp(WHITE,.53),ball)
      r.projectile=value;self.heads+=1
      if ball and not BeamVFX.reduced() then r.shell=shotPart(value,'EnergyShell',Vector3.one*1.07,color,true,.47) end
      r.launchFrom=muzzle or from
      if self.trails<TRAIL_LIMIT and not BeamVFX.reduced() then
       r.trail=addRibbon(value,color,ball);self.trails+=1
      end
     end
     from=r.launchFrom or from
     local delta=to-from
     if delta.Magnitude<.01 then continue end
     local direction=delta.Unit
     if not r.fired then
      r.fired=true
      if paused<=0 and age-windup<.12 then
       burst(self,from+direction*.17,direction,color,ball,false,1,now)
       if audio then audio:play(ball and 'coil_fire' or 'needle_fire',from) end
      end
     end
     if not value then continue end
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
  stepBursts(self,now)
  RoleVisuals.setTime(nil);RoleVisuals.step(now)
 end
 function self:destroy()
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  for _,r in pairs(self.records) do clearProjectile(self,r,0,false) end
  for _,b in ipairs(self.bursts) do b.node:Destroy() end
  table.clear(self.bursts);table.clear(self.records);RoleVisuals.destroy()
 end
 return self
end
return View
