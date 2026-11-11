-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local PICKUP_HIGHLIGHT=Color3.fromRGB(255,248,221)
local TRAIL_LIFETIME,TRAIL_LIMIT=.24,12
local function launchTrail(view,tint)
 local a=Instance.new('Attachment');a.Name='LaunchTrailLeft';a.Position=Vector3.new(-.23,0,.04);a.Parent=view
 local b=Instance.new('Attachment');b.Name='LaunchTrailRight';b.Position=Vector3.new(.23,0,.04);b.Parent=view
 local trail=Instance.new('Trail');trail.Name='CargoLaunchTrail'
 trail.Attachment0=a;trail.Attachment1=b;trail.FaceCamera=true
 trail.Lifetime=TRAIL_LIFETIME;trail.MinLength=.035;trail.MaxLength=5.2
 trail.LightEmission=.78;trail.LightInfluence=0
 trail.Color=ColorSequence.new(tint:Lerp(PICKUP_HIGHLIGHT,.80),tint:Lerp(PICKUP_HIGHLIGHT,.34))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.14),NumberSequenceKeypoint.new(.46,.36),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,.86),NumberSequenceKeypoint.new(.46,.51),NumberSequenceKeypoint.new(1,0)})
 trail.Parent=view
 return {trail=trail,a=a,b=b}
end
local function removeTrail(self,r)
 if not r.ribbon then return end
 r.ribbon.trail:Destroy();r.ribbon.a:Destroy();r.ribbon.b:Destroy()
 r.ribbon=nil;self.trailCount-=1
end
local function backpack(owner,fallback)
 local character=owner and owner.Character
 local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
 if torso then return torso.CFrame:PointToWorldSpace(Vector3.new(0,.3,.8)),torso end
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 return hr and hr.Position or fallback,nil
end
local function pickupNumber(parent)
 local gui=Instance.new('BillboardGui');gui.Name='OrePickupAmount';gui.Size=UDim2.fromOffset(130,44)
 gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.MaxDistance=120;gui.Enabled=false
 local text=Instance.new('TextLabel');text.Name='Amount';text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
 text.Font=Enum.Font.GothamBold;text.TextSize=24;text.TextColor3=Color3.fromRGB(255,224,124)
 text.TextStrokeColor3=Color3.fromRGB(38,27,12);text.TextStrokeTransparency=.14;text.Parent=gui;gui.Parent=parent
 return gui,text
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
 r.units=source:GetAttribute('Units') or 1
 r.fadeAt=source:GetAttribute('FadeAt');r.expiresAt=source:GetAttribute('ExpiresAt')
end
function V.new(root,parent,audio)
 local player=Players.LocalPlayer
 local self=setmetatable({records={},byId={},parent=parent,root=root,connections={},audio=audio,lastSound=0,
  player=player,trailCount=0,lastTotal=player:GetAttribute('CollectedOreTotal') or 0},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  if (source:GetAttribute('CollectedAt') or 0)>0 then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false;view.Parent=parent
  source.LocalTransparencyModifier=1
  local id=source:GetAttribute('PickupId')
  local r={view=view,pos=position,size=source.Size,color=source.Color,seed=id,physical=source:GetAttribute('PhysicalCargo')==true,
   samples={},owner=source:GetAttribute('Owner'),born=source:GetAttribute('SpawnAt') or workspace:GetServerTimeNow()}
  local contactAt=source:GetAttribute('GroundImpactAt')
  if type(contactAt)=='number' and contactAt>0 then r.landAge=math.max(0,contactAt-r.born) end
  if r.physical then
   local value=Instance.new('BillboardGui');value.Name='CargoWorth';value.Size=UDim2.fromOffset(66,18)
   value.StudsOffsetWorldSpace=Vector3.new(0,1.14,0);value.MaxDistance=18;value.Enabled=false;value.Parent=view
   local text=Instance.new('TextLabel');text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
   text.Text=tostring(source:GetAttribute('CargoValue') or 0)..' Q';text.TextSize=13;text.Font=Enum.Font.GothamBold
   text.TextColor3=PICKUP_HIGHLIGHT;text.TextStrokeTransparency=.18;text.Parent=value;r.valueLabel=value
  end
  self.records[source]=r;self.byId[id]=r;sample(r,source,workspace:GetServerTimeNow())
 end
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source]
  if r then r.removedAt=workspace:GetServerTimeNow() end
 end))
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_Collect'):Connect(function()
  local ok,receipt=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_Collect') or '')
  if not ok or type(receipt)~='table' or type(receipt.serial)~='number' or receipt.serial==self.lastReceipt then return end
  self.lastReceipt=receipt.serial
  local units=receipt.units or 0
  if type(receipt.total)=='number' then
   units=math.max(0,receipt.total-self.lastTotal);self.lastTotal=math.max(receipt.total,self.lastTotal)
  end
  local now=workspace:GetServerTimeNow()
  if math.abs(now-(receipt.at or 0))>.7 then return end
  local rootPart=player.Character and player.Character:FindFirstChild('HumanoidRootPart');if not rootPart then return end
  local r=self.byId[receipt.pickupId]
  if r and receipt.exhausted==true then
   r.collectAt=r.collectAt or now;r.collectFrom=r.collectFrom or r.drawPosition or r.pos
   r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  end
  local target,torso=backpack(player,rootPart.Position)
  if type(units)=='number' and units>0 then
   if not self.amountGui then self.amountGui,self.amountText=pickupNumber(parent) end
   if now-(self.amountAt or -math.huge)<.4 then self.amount+=units
   else self.amount=units;self.amountStarted=now end
   local arrival=now+(r and r.physical and .18 or 0)
   self.amountAt=arrival
   self.amountGui.Adornee=torso or rootPart
   self.amountText.Text='+'..self.amount..(receipt.physical and ' cargo' or ' ore')
  end
  if audio and not receipt.quiet then self.soundAt=now+(r and r.physical and .18 or 0);self.soundTarget=target end
 end))
 return self
end
function V:update(dt,now)
 if self.soundAt and now>=self.soundAt then
  if now-self.lastSound>.09 then
   self.pickupChain=now-self.lastSound<.6 and math.min(6,(self.pickupChain or 0)+1) or 0
   self.lastSound=now;self.audio:play('pickup',backpack(self.player,self.soundTarget),{pitch=1+self.pickupChain*.045})
  end
  self.soundAt=nil
 end
 if self.amountGui then
  local age=math.max(0,now-self.amountAt)
  local reduced=self.player:GetAttribute('ReducedEffects')==true
  self.amountGui.Enabled=now>=self.amountAt and age<.93 and self.amountGui.Adornee.Parent~=nil
  if self.amountGui.Enabled then
   local rise=reduced and 0 or .78*(1-math.exp(-math.max(0,now-self.amountStarted)*4))
   self.amountGui.StudsOffset=Vector3.new(1.72,1.05+rise,0)
   self.amountText.TextSize=reduced and 24 or 24+math.floor(6*math.max(0,1-age/.18))
   local fade=math.clamp((age-.53)/.40,0,1)
   self.amountText.TextTransparency=fade;self.amountText.TextStrokeTransparency=.14+.86*fade
  end
 end
 for source,r in pairs(self.records) do
  if not r.collectAt and source.Parent then
   local processed=source:GetAttribute('ProcessedAt')
   local collectedAt=processed or source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.processed=processed~=nil
    r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
    r.collectTarget=source:GetAttribute(r.processed and 'ProcessedPosition' or 'CollectedPosition')
   end
  end
  local opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  local scale=1;local glow=0;local done=false
  if r.collectAt then
   local t=(now-r.collectAt)/(r.physical and .18 or .22);local ease,shrink=PickupMotion.collection(t)
   local owner=Players:GetPlayerByUserId(r.owner)
   local target=(r.processed and r.collectTarget) or backpack(owner,r.collectTarget or r.collectFrom)
   local lift=math.sin(math.clamp(t,0,1)*math.pi)
   r.pos=r.collectFrom:Lerp(target,ease)+Vector3.new(0,lift*.52,0)
   opacity=(r.collectOpacity or 1)*(1-math.clamp((t-.7)/.3,0,1))
   scale=math.max(.04,shrink*(1+.24*lift));glow=.55*lift;done=t>=1
  elseif source.Parent and not r.removedAt then
   -- Landing pose is persistent state, even when its timestamp arrives too
   -- late to replay a sound. A streamed/stalled observer must still settle.
   local contactAt=source:GetAttribute('GroundImpactAt')
   if not r.landAge and type(contactAt)=='number' and contactAt>0 then
    r.landAge=math.max(0,contactAt-r.born)
   end
   sample(r,source,now)
   local x,y,z=PickupMotion.position(r.samples,now)
   if x then r.pos=Vector3.new(x,y,z) end
   opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  else
   r.removedAt=r.removedAt or now
   -- Destruction can replicate just before its receipt. Keep a tiny grace
   -- window, then fade in place for expiry/cleanup without inventing collection.
   opacity*=1-math.clamp((now-r.removedAt-.06)/.18,0,1);done=now-r.removedAt>=.28
  end
  if done then
   removeTrail(self,r);r.view:Destroy()
   self.byId[r.seed]=nil;self.records[source]=nil
  else
   local latest=r.samples[#r.samples]
   local socket=source.Parent and source:GetAttribute('PressSocket')
   local seated=socket and not r.collectAt
   r.socketScale=(r.socketScale or 1)+((seated and .48 or 1)-(r.socketScale or 1))*(1-math.exp(-math.min(dt,.1)*22))
   local pulling=latest and latest.homing and not r.collectAt and not r.removedAt
   local targetPull=pulling and 1 or 0
   r.pull=(r.pull or 0)+(targetPull-(r.pull or 0))*(1-math.exp(-math.min(dt,.1)*18))
   if r.pull<.001 then r.pull=0 end
   local pile=1+math.min(.45,math.max(0,math.sqrt(r.units or 1)-1)*.11)
   scale*=pile*(1+.14*r.pull)*r.socketScale
   glow=math.max(glow,.34*r.pull)
   local age=math.max(0,now-PickupMotion.DELAY-r.born)
   local tumble=PickupMotion.tumble(age,r.landAge)
   local rx,ry,rz=r.seed*.71+tumble,r.seed*.9+tumble*.6,r.seed*.43+tumble*.8
   local position=r.pos
   if not seated and not r.collectAt and latest and latest.floor then
    local support=PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,rx,ry,rz)*scale
    -- Lift the entire trajectory by the rotated support extent, preserving
    -- the small rebound instead of clamping it away under the visible mesh.
    position=Vector3.new(position.X,math.max(latest.floor,position.Y)+support-.22,position.Z)
   end
   if r.physical then
    local camera=workspace.CurrentCamera
    local air=r.landAge and age<r.landAge or not r.landAge and age<1.2
    local inFlight=air and not r.collectAt and not r.removedAt and not pulling
    local inView=camera and (position-camera.CFrame.Position).Magnitude<100
    if r.ribbon then
     if not inFlight or self.player:GetAttribute('ReducedEffects')==true then
      if r.ribbon.trail.Enabled then r.ribbon.trail.Enabled=false;r.ribbon.untilAt=now+TRAIL_LIFETIME end
     end
     if r.ribbon.untilAt and now>=r.ribbon.untilAt then removeTrail(self,r) end
    elseif inFlight and not r.trailUsed and inView and self.trailCount<TRAIL_LIMIT and self.player:GetAttribute('ReducedEffects')~=true then
     r.ribbon=launchTrail(r.view,r.color);r.trailUsed=true;self.trailCount+=1
    end
    if r.valueLabel then
     r.valueLabel.Enabled=r.owner==self.player.UserId and r.landAge~=nil and not seated and not inFlight and not pulling and not r.collectAt and not r.removedAt
      and camera~=nil and (position-camera.CFrame.Position).Magnitude<18 and opacity>.35
    end
   end
   r.drawPosition=position
   r.view.CFrame=CFrame.new(position)*CFrame.Angles(rx,ry,rz)
   r.view.Size=r.size*scale;r.view.Transparency=1-opacity
   if glow~=(r.glow or 0) then r.glow=glow;r.view.Color=r.color:Lerp(PICKUP_HIGHLIGHT,glow) end
  end
 end
end
function V:destroy()
 if self.closed then return end;self.closed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do if source.Parent then source.LocalTransparencyModifier=0 end;r.view:Destroy() end
 if self.amountGui then self.amountGui:Destroy() end
 self.records={};self.byId={}
end
return V
