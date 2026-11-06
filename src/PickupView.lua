-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local Debris=game:GetService('Debris')
local V={};V.__index=V
local function backpack(owner,fallback)
 local character=owner and owner.Character
 local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
 if torso then return torso.CFrame:PointToWorldSpace(Vector3.new(0,.3,.8)),torso end
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 return hr and hr.Position or fallback,nil
end
local function sparkle(parent,color)
 local p=Instance.new('ParticleEmitter');p.Name='MineralGlints'
 p.Texture='rbxasset://textures/ui/VR/circleWhite.png';p.Color=ColorSequence.new(color)
 p.LightEmission=.7;p.LightInfluence=0;p.Brightness=1;p.Rate=1.5;p.Lifetime=NumberRange.new(.65,1.1);p.Speed=NumberRange.new(.1,.4);p.Drag=3
 p.SpreadAngle=Vector2.new(180,180);p.WindAffectsDrag=false
 p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12,.02),NumberSequenceKeypoint.new(.3,.2,.03),NumberSequenceKeypoint.new(1,0)})
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(1,1)})
 p.Parent=parent;return p
end
local function sample(r,source,now)
 local at=source:GetAttribute('SnapshotAt') or now
 if r.sampleAt and at<=r.sampleAt then return end
 local position=source:GetAttribute('Position') or source.Position
 local velocity=source:GetAttribute('Velocity') or Vector3.zero
 r.sampleAt=at
 table.insert(r.samples,{at=at,x=position.X,y=position.Y,z=position.Z,vx=velocity.X,vy=velocity.Y,vz=velocity.Z,
  floor=source:GetAttribute('FloorY'),homing=source:GetAttribute('Homing')==true})
 while #r.samples>5 do table.remove(r.samples,1) end
 r.velocity=velocity
 r.fadeAt=source:GetAttribute('FadeAt');r.expiresAt=source:GetAttribute('ExpiresAt')
end
function V.new(root,parent,audio)
 local player=Players.LocalPlayer
 local self=setmetatable({records={},byId={},parent=parent,root=root,connections={},audio=audio,lastSound=0},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  if (source:GetAttribute('CollectedAt') or 0)>0 then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.Material=Enum.Material.SmoothPlastic;view.Color=source.Color;view.Reflectance=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false;view.Parent=parent
  source.LocalTransparencyModifier=1
  local a=Instance.new('Attachment');a.Position=Vector3.new(0,.13,0);a.Parent=view
  local b=Instance.new('Attachment');b.Position=Vector3.new(0,-.13,0);b.Parent=view
  local trail=Instance.new('Trail');trail.Name='OreMagnetTrail';trail.Attachment0=a;trail.Attachment1=b
  trail.Color=ColorSequence.new(view.Color);trail.Lifetime=.25;trail.MinLength=.08;trail.FaceCamera=true;trail.LightEmission=.55
  trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)})
  trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,1)});trail.Enabled=false;trail.Parent=view
  local glints=sparkle(a,view.Color);glints.Enabled=false
  local glow=Instance.new('PointLight');glow.Name='MineralGlow';glow.Color=source.Color;glow.Range=2.5;glow.Brightness=.18;glow.Shadows=false;glow.Enabled=false;glow.Parent=view
  local id=source:GetAttribute('PickupId')
  local r={view=view,pos=position,trail=trail,glints=glints,glow=glow,size=source.Size,seed=id,ground=source:GetAttribute('GroundImpactSerial') or 0,
   samples={},owner=source:GetAttribute('Owner'),born=source:GetAttribute('SpawnAt') or workspace:GetServerTimeNow()}
  local contactAt=source:GetAttribute('GroundImpactAt')
  if type(contactAt)=='number' and contactAt>0 then r.landAge=math.max(0,contactAt-r.born) end
  self.records[source]=r;self.byId[id]=r;sample(r,source,workspace:GetServerTimeNow())
 end
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source]
  if r then r.removedAt=workspace:GetServerTimeNow();r.trail.Enabled=false;r.glints.Enabled=false end
 end))
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_Collect'):Connect(function()
  local ok,receipt=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_Collect') or '')
  if not ok or type(receipt)~='table' or type(receipt.serial)~='number' or receipt.serial==self.lastReceipt then return end
  self.lastReceipt=receipt.serial
  local now=workspace:GetServerTimeNow()
  if math.abs(now-(receipt.at or 0))>.7 then return end
  local rootPart=player.Character and player.Character:FindFirstChild('HumanoidRootPart');if not rootPart then return end
  local r=self.byId[receipt.pickupId]
  if r and receipt.exhausted==true then r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt) end
  local target=backpack(player,rootPart.Position)
  local anchor=Instance.new('Part');anchor.Name='CollectedMineral';anchor.Size=Vector3.one*.05;anchor.Transparency=1
  anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Position=target;anchor.Parent=parent
  local a=Instance.new('Attachment');a.Parent=anchor
  local burst=sparkle(a,Color3.fromRGB(receipt.r,receipt.g,receipt.b));burst.Rate=0;burst.Speed=NumberRange.new(1,3);burst:Emit(4)
  Debris:AddItem(anchor,burst.Lifetime.Max+.15)
  if audio and os.clock()-self.lastSound>.09 then
   local at=os.clock();self.pickupChain=at-self.lastSound<.6 and math.min(6,(self.pickupChain or 0)+1) or 0
   self.lastSound=at;audio:play('pickup',target,{pitch=1+self.pickupChain*.045})
  end
 end))
 return self
end
function V:update(dt,now)
 local camera=workspace.CurrentCamera;local glints,lights=0,0
 local player=Players.LocalPlayer
 local reduced=player:GetAttribute('ReducedEffects')==true or player:GetAttribute('MA_ReducedEffects')==true
 for source,r in pairs(self.records) do
  if not r.collectAt and source.Parent then
   local collectedAt=source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
    r.collectTarget=source:GetAttribute('CollectedPosition')
   end
  end
  local opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt);local scale=1;local done=false
  if r.collectAt then
   local t=(now-r.collectAt)/.22;local ease,shrink=PickupMotion.collection(t)
   local owner=Players:GetPlayerByUserId(r.owner)
   local target=backpack(owner,r.collectTarget or r.collectFrom)
   r.pos=r.collectFrom:Lerp(target,ease)+Vector3.new(0,math.sin(math.clamp(t,0,1)*math.pi)*.18,0)
   opacity=(r.collectOpacity or 1)*(1-math.clamp((t-.7)/.3,0,1));scale=math.max(.04,shrink);done=t>=1
   r.trail.Enabled=not reduced and t<.8
  elseif source.Parent and not r.removedAt then
   -- Landing pose is persistent state, even when its timestamp arrives too
   -- late to replay a sound. A streamed/stalled observer must still settle.
   local contactAt=source:GetAttribute('GroundImpactAt')
   if not r.landAge and type(contactAt)=='number' and contactAt>0 then
    r.landAge=math.max(0,contactAt-r.born)
   end
   -- Queue the authoritative hit until the buffered picture reaches contact.
   if AudioFeedback.serial(r,'ground',source:GetAttribute('GroundImpactSerial') or 0,contactAt,now) then
    local point=source:GetAttribute('GroundImpactPosition')
    if typeof(point)=='Vector3' then r.contact={at=(contactAt or now)+PickupMotion.DELAY,point=point,speed=source:GetAttribute('GroundImpactSpeed') or 1} end
   end
   if r.contact and now>=r.contact.at then
    if self.audio and now-r.contact.at<.35 then self.audio:play('rubble',r.contact.point,{level=math.clamp(r.contact.speed/12,.25,1),pitch=.9+(r.seed%5)*.055}) end
    r.contact=nil
   end
   sample(r,source,now)
   local x,y,z=PickupMotion.position(r.samples,now)
   if x then r.pos=Vector3.new(x,y,z) end
   opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
   local latest=r.samples[#r.samples]
   r.trail.Enabled=not reduced and latest and latest.homing and r.velocity.Magnitude>10 and opacity>.1 or false
  else
   r.removedAt=r.removedAt or now
   -- Destruction can replicate just before its receipt. Keep a tiny grace
   -- window, then fade in place for expiry/cleanup without inventing collection.
   opacity*=1-math.clamp((now-r.removedAt-.06)/.18,0,1);done=now-r.removedAt>=.28
   r.trail.Enabled=false
  end
  if done then
   -- Retire the ore visual and authority immediately; let existing particles
   -- finish on an invisible, bounded cosmetic anchor.
   r.view.Name='FadingOreParticles';r.view.Transparency=1
   r.glints.Enabled=false;r.glow.Enabled=false;r.trail.Enabled=false
   Debris:AddItem(r.view,math.max(r.glints.Lifetime.Max,r.trail.Lifetime)+.1)
   self.byId[r.seed]=nil;self.records[source]=nil
  else
   local age=math.max(0,now-PickupMotion.DELAY-r.born)
   local tumble=PickupMotion.tumble(age,r.landAge)
   local rx,ry,rz=r.seed*.71+tumble,r.seed*.9+tumble*.6,r.seed*.43+tumble*.8
   local position=r.pos
   local latest=r.samples[#r.samples]
   if not r.collectAt and latest and latest.floor then
    local support=PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,rx,ry,rz)
    -- Lift the entire trajectory by the rotated support extent, preserving
    -- the small rebound instead of clamping it away under the visible mesh.
    position=Vector3.new(position.X,math.max(latest.floor,position.Y)+support-.22,position.Z)
   end
   r.drawPosition=position
   r.view.CFrame=CFrame.new(position)*CFrame.Angles(rx,ry,rz)
   r.view.Size=r.size*scale;r.view.Transparency=1-opacity
   local distance=camera and (camera.CFrame.Position-r.pos).Magnitude or math.huge
   r.glints.Enabled=not reduced and not r.removedAt and not r.collectAt and opacity>.15 and distance<45 and glints<8
   if r.glints.Enabled then glints+=1 end
   r.glow.Enabled=not reduced and opacity>.05 and distance<24 and lights<2
   if r.glow.Enabled then lights+=1;r.glow.Brightness=.18*opacity end
  end
 end
end
function V:destroy()
 if self.closed then return end;self.closed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do if source.Parent then source.LocalTransparencyModifier=0 end;r.view:Destroy() end
 self.records={};self.byId={}
end
return V
