-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local PICKUP_HIGHLIGHT=Color3.fromRGB(255,248,221)
local TRAIL_LIFETIME,TRAIL_LIMIT=.29,12
local GLINT_LIMIT=12
local DISPLAY_RANGE,DISPLAY_LIMIT=62,12
local DISPLAY_TAIL=.28
local HOVER_BOB_RATE,HOVER_TURN_RATE=2*math.pi/1.4,2*math.pi/26
local GEM_GLINT='rbxassetid://77624818077620'
local GLINT_LIFETIME=.46
local function launchTrail(view,tint,halfWidth)
 local a=Instance.new('Attachment');a.Name='LaunchTrailLeft';a.Position=Vector3.new(-halfWidth,0,.04);a.Parent=view
 local b=Instance.new('Attachment');b.Name='LaunchTrailRight';b.Position=Vector3.new(halfWidth,0,.04);b.Parent=view
 local trail=Instance.new('Trail');trail.Name='CargoLaunchTrail'
 trail.Attachment0=a;trail.Attachment1=b;trail.FaceCamera=true
 trail.Lifetime=TRAIL_LIFETIME;trail.MinLength=.045;trail.MaxLength=7.5
 trail.LightEmission=.78;trail.LightInfluence=0
 trail.Color=ColorSequence.new(tint:Lerp(PICKUP_HIGHLIGHT,.85),tint:Lerp(PICKUP_HIGHLIGHT,.22))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.32,.46),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,.90),NumberSequenceKeypoint.new(.32,.52),NumberSequenceKeypoint.new(1,0)})
 trail.Parent=view
 return {trail=trail,a=a,b=b}
end
local function removeTrail(self,r)
 if not r.ribbon then return end
 r.ribbon.trail:Destroy();r.ribbon.a:Destroy();r.ribbon.b:Destroy()
 r.ribbon=nil;self.trailCount-=1
end
local function finishTrail(self,r,now)
 local ribbon=r.ribbon
 if not ribbon then return end
 if not ribbon.untilAt then
  ribbon.trail.Enabled=false;ribbon.untilAt=now+ribbon.trail.Lifetime
 elseif now>=ribbon.untilAt then removeTrail(self,r) end
end
local function makeGlint()
 local anchor=Instance.new('Attachment');anchor.Name='FacetGlint'
 local emitter=Instance.new('ParticleEmitter');emitter.Name='GemSparkle'
 emitter.Texture=GEM_GLINT;emitter.Enabled=false;emitter.Rate=0
 emitter.LightInfluence=0;emitter.LightEmission=.85;emitter.Brightness=2
 emitter.Orientation=Enum.ParticleOrientation.FacingCamera
 emitter.Speed=NumberRange.new(0);emitter.Lifetime=NumberRange.new(GLINT_LIFETIME)
 emitter.LockedToPart=true;emitter.Rotation=NumberRange.new(-18,18)
 emitter.ZOffset=.45;emitter.Parent=anchor
 return {anchor=anchor,emitter=emitter}
end
local function removeIdle(self,r)
 if not r.idle then return end
 r.idle.emitter:Clear()
 r.idle.anchor.Parent=nil;table.insert(self.idlePool,r.idle);r.idle=nil
 self.idleCount-=1
end
local function updateGlint(self,r,age,strength,now)
 if r.idle then
  if now<r.glintUntil then return end
  removeIdle(self,r)
 end
 local clock=age-.5+r.seed*.61
 local cycle=age<.5 and -1 or math.floor(clock/2.65)
 local phase=age<.5 and age or clock%2.65
 if phase>=.24 or strength<.04 or r.glintCycle==cycle or self.idleCount>=GLINT_LIMIT then return end
 r.glintCycle=cycle;r.glintUntil=now+GLINT_LIFETIME
 r.idle=table.remove(self.idlePool) or makeGlint();self.idleCount+=1
 local size=r.view.Size
 local side=r.seed%2==0 and 1 or -1
 r.idle.anchor.Position=Vector3.new(side*size.X*.17,size.Y*.67,-side*size.Z*.08)
 local width=r.physical and 2.85 or 1.8
 local emitter=r.idle.emitter
 emitter.Size=NumberSequence.new({
  NumberSequenceKeypoint.new(0,width),
  NumberSequenceKeypoint.new(1,0),
 })
 emitter.Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,1-strength*.68),
  NumberSequenceKeypoint.new(.13,1-strength),
  NumberSequenceKeypoint.new(.82,1-strength*.80),
  NumberSequenceKeypoint.new(1,1),
 })
 r.idle.anchor.Parent=r.view
 emitter:Emit(1)
end
local function displayOrder(a,b)
 if a.displayDistance==b.displayDistance then return a.seed<b.seed end
 return a.displayDistance<b.displayDistance
end
local function updateDisplays(self,now,reducedMotion,reducedEffects)
 local candidates=self.displayCandidates
 table.sort(candidates,displayOrder)
 local count=math.min(#candidates,DISPLAY_LIMIT)
 local free=self.freeDisplays;table.clear(free)
 for i=1,count do candidates[i].displayWanted=true end
 for _,rig in ipairs(self.displays) do
  local r=rig.record
  if r and r.displayWanted then
   rig.releaseAt=nil
  elseif r then
   rig.releaseAt=rig.releaseAt or now
   local tail=math.clamp(1-(now-rig.releaseAt)/DISPLAY_TAIL,0,1)*r.displayStrength
   if tail>.02 and (not r.expiresAt or now<r.expiresAt) then
    PickupDisplay.draw(rig,r,r.displayGround,now,tail,reducedMotion,reducedEffects)
   else
    PickupDisplay.hide(rig);r.displayRig=nil;rig.record=nil;rig.outline.Adornee=nil
   end
  end
  if not rig.record then table.insert(free,rig) end
 end
 for i=1,count do
  local r=candidates[i]
  r.displayWanted=nil
  local rig=r.displayRig or table.remove(free)
  if not rig and #self.displays<DISPLAY_LIMIT then
   rig=PickupDisplay.new(self.parent,#self.displays+1);table.insert(self.displays,rig)
  end
  if rig then
   r.displayRig=rig;rig.releaseAt=nil
   PickupDisplay.draw(rig,r,r.displayGround,now,r.displayStrength,reducedMotion,reducedEffects)
  end
 end
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
local function cargoWorth(parent)
 local gui=Instance.new('BillboardGui');gui.Name='CargoWorth';gui.Size=UDim2.fromOffset(66,18)
 gui.StudsOffsetWorldSpace=Vector3.new(0,1.14,0);gui.MaxDistance=18;gui.Enabled=false;gui.Parent=parent
 local text=Instance.new('TextLabel');text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
 text.TextSize=13;text.Font=Enum.Font.GothamBold;text.TextColor3=PICKUP_HIGHLIGHT
 text.TextStrokeTransparency=.18;text.Parent=gui
 return gui,text
end
local function sample(r,source,now)
 -- A stationary pile can be combined or renewed without changing pose.
 r.units=source:GetAttribute('Units') or 1
 r.expiresAt=source:GetAttribute('ExpiresAt')
 local at=source:GetAttribute('SnapshotAt') or now
 if r.sampleAt and at<=r.sampleAt then return end
 local position=source:GetAttribute('Position') or source.Position
 local velocity=source:GetAttribute('Velocity') or Vector3.zero
 r.sampleAt=at
 table.insert(r.samples,{at=at,x=position.X,y=position.Y,z=position.Z,vx=velocity.X,vy=velocity.Y,vz=velocity.Z,
  floor=source:GetAttribute('FloorY'),homing=source:GetAttribute('Homing')==true,seated=source:GetAttribute('PressSocket')~=nil})
 while #r.samples>5 do table.remove(r.samples,1) end
end
function V.new(root,parent,audio,reducedMotion)
 local player=Players.LocalPlayer
 local self=setmetatable({records={},byId={},parent=parent,root=root,connections={},audio=audio,lastSound=0,reducedMotion=reducedMotion,
  player=player,trailCount=0,idleCount=0,idlePool={},displays={},freeDisplays={},displayCandidates={},lastTotal=player:GetAttribute('CollectedOreTotal') or 0},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  if (source:GetAttribute('CollectedAt') or 0)>0 or (source:GetAttribute('ProcessedAt') or 0)>0 then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false
  if view.Material==Enum.Material.Glass then view.Material=Enum.Material.SmoothPlastic;view.MaterialVariant='' end
  source.LocalTransparencyModifier=1;view.Transparency=1;view.Parent=parent
  local id=source:GetAttribute('PickupId')
  local r={view=view,pos=position,size=source.Size,color=source.Color,seed=id,physical=source:GetAttribute('PhysicalCargo')==true,
   samples={},owner=source:GetAttribute('Owner'),cargoValue=source:GetAttribute('CargoValue') or 0,
   born=source:GetAttribute('SpawnAt') or workspace:GetServerTimeNow()}
  local origin=source:GetAttribute('OreLaunchOrigin')
  local velocity=source:GetAttribute('OreLaunchVelocity')
  if typeof(origin)=='Vector3' and typeof(velocity)=='Vector3' and math.abs(velocity.X)+math.abs(velocity.Z)>.01 then
   r.hasArc=true
   local floor=source:GetAttribute('FloorY')
   if source:GetAttribute('CleanCargoArc') and type(floor)=='number' then
    r.arc=OreDrops.rawArc(origin.X,origin.Y,origin.Z,velocity.X,velocity.Y,velocity.Z,floor)
    r.landAge=r.arc.contact
    view.CastShadow=true
   end
   local height=math.max(0,origin.Y-(source:GetAttribute('FloorY') or origin.Y))
   r.arcTimeout=(velocity.Y+math.sqrt(velocity.Y^2+2*PickupMotion.GRAVITY*height))/PickupMotion.GRAVITY+.18
  end
  local contactAt=source:GetAttribute('GroundImpactAt')
  if not r.arc and type(contactAt)=='number' and contactAt>0 then r.landAge=math.max(0,contactAt-r.born) end
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
 local camera=workspace.CurrentCamera
 local cameraPosition=camera and camera.CFrame.Position
 local reducedEffects=self.player:GetAttribute('ReducedEffects')==true or self.player:GetAttribute('MA_ReducedEffects')==true
 local reducedFlashing=self.player:GetAttribute('ReducedFlashing')==true
 local glintStrength=reducedFlashing and .36 or 1
 local reducedMotion=self.reducedMotion and self.reducedMotion()
 local displayAt=now-PickupMotion.DELAY
 local closest,bestDistance=nil,math.huge
 table.clear(self.displayCandidates)
 for source,r in pairs(self.records) do
  if not r.collectAt and source.Parent then
   local processed=source:GetAttribute('ProcessedAt')
   local collectedAt=processed or source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.processed=processed~=nil
    r.courierCollected=source:GetAttribute('CourierCollected')==true
    r.collectAt=r.processed and collectedAt or now
    r.collectFrom=r.drawPosition or r.pos
    if r.processed then r.pressScale=r.view.Size.Y/math.max(.01,r.size.Y) end
    r.collectTarget=source:GetAttribute(r.processed and 'ProcessedPosition' or 'CollectedPosition')
   end
  end
  local opacity,scale,glow,done=1,1,0,false
  if r.collectAt and r.processed and r.collectTarget then
   local t=math.clamp((now-r.collectAt)/Workshop.PRESS_CONTACT,0,1)
   local close=math.clamp((t-.18)/.82,0,1)^2
   local ease,shrink=PickupMotion.collection(close)
   r.pos=r.collectFrom:Lerp(r.collectTarget,ease)
   scale=math.max(.045,(r.pressScale or .48)*shrink)
   opacity=1-math.clamp((close-.82)/.18,0,1)
   glow=.48*close;done=t>=1
  elseif r.collectAt then
   local t=(now-r.collectAt)/(r.physical and .18 or .22);local ease,shrink=PickupMotion.collection(t)
   local owner=Players:GetPlayerByUserId(r.owner)
   local target=r.courierCollected and r.collectTarget or backpack(owner,r.collectTarget or r.collectFrom)
   local lift=math.sin(math.clamp(t,0,1)*math.pi)
   r.pos=r.collectFrom:Lerp(target,ease)+Vector3.new(0,lift*.52,0)
   opacity=1-math.clamp((t-.7)/.3,0,1)
   scale=math.max(.04,shrink*(1+.24*lift));glow=.55*lift;done=t>=1
  elseif source.Parent and not r.removedAt then
   -- Landing pose is persistent state, even when its timestamp arrives too
   -- late to replay a sound. A streamed/stalled observer must still settle.
   local contactAt=source:GetAttribute('GroundImpactAt')
   if not r.landAge and type(contactAt)=='number' and contactAt>0 then
    r.landAge=math.max(0,contactAt-r.born)
   end
   sample(r,source,now)
   opacity=PickupMotion.expiryOpacity(now,r.expiresAt,reducedEffects or reducedFlashing)
  else
   r.removedAt=r.removedAt or now
   -- Keep the record briefly in case its collection receipt arrives late.
   opacity=0;done=now-r.removedAt>=.28
  end
  if r.arc and displayAt<r.born then opacity=0 end
  if done then
   finishTrail(self,r,now);removeIdle(self,r)
   if r.ribbon then r.view.Transparency=1
   else
    r.view:Destroy();self.byId[r.seed]=nil;self.records[source]=nil
   end
  else
   local latest=r.samples[#r.samples]
   local live=source.Parent~=nil and not r.collectAt and not r.removedAt
   local seated=live and source:GetAttribute('PressSocket')~=nil
   local pulling=live and latest and latest.homing
   if r.arc and not r.arcExit and (pulling or seated or source:GetAttribute('CargoArcEnded')) then r.arcExit=latest.at end
   local age=math.max(0,displayAt-r.born)
   local socketScale=seated and .48 or 1
   -- Regular ore fragments and large workshop cargo both land. Wait for the
   -- contact position/speed to replicate before consuming this one-shot cue.
   if r.hasArc and r.landAge and age>=r.landAge and not r.landCue and (live or r.arc) then
    local point=source:GetAttribute('GroundImpactPosition')
    local speed=source:GetAttribute('GroundImpactSpeed') or 0
    if r.arc then point=Vector3.new(r.arc.landX,r.arc.floor-.22,r.arc.landZ);speed=r.arc.speed end
    if age-r.landAge>=.28 then r.landCue=true
    elseif typeof(point)=='Vector3' and speed>0 then
     r.landCue=true
     if self.audio then
      self.audio:play('ore_land',point,{level=math.clamp(speed/43,.67,1.18)*(r.arc and 1.12 or r.physical and 1 or .82),
       pitch=(r.physical and .84 or 1.02)+(r.seed%4)*.028})
     end
    end
   end
   local resting=live and r.landAge and age>=r.landAge+(r.arc and 0 or PickupMotion.SETTLE_TIME)
    and PickupMotion.isResting(latest) and seated==latest.seated and now>=latest.at+PickupMotion.DELAY
   local arcMix=r.arc and (not r.arcExit and 1 or 1-math.clamp((displayAt-r.arcExit)/.12,0,1)) or 0
   local newPose=not (resting and r.restSample==latest and r.restUnits==r.units)
   if newPose then
    if live then
     local x,y,z=PickupMotion.position(r.samples,now)
     if x then r.pos=Vector3.new(x,y,z) end
     if arcMix>0 then
      local ax,ay,az=OreDrops.rawPose(r.arc,age)
      r.pos=r.pos:Lerp(Vector3.new(ax,ay,az),arcMix)
     end
    end
    r.socketScale=(r.socketScale or 1)+(socketScale-(r.socketScale or 1))*(1-math.exp(-math.min(dt,.1)*22))
    if math.abs(r.socketScale-socketScale)<.001 then r.socketScale=socketScale end
    local targetPull=pulling and 1 or 0
    r.pull=(r.pull or 0)+(targetPull-(r.pull or 0))*(1-math.exp(-math.min(dt,.1)*18))
    if r.pull<.001 then r.pull=0 end
    local pile=1+math.min(.45,math.max(0,math.sqrt(r.units or 1)-1)*.11)
    scale*=pile*(1+.14*r.pull)*r.socketScale
    glow=math.max(glow,.34*r.pull)
    local rx,ry,rz
    if r.arc then
     local remaining=reducedMotion and 0 or 1-math.clamp(age/math.max(.01,r.arc.contact*.87),0,1)
     rx=remaining^1.2*math.pi*.63;ry=(r.seed*.92)%6.283+.45*remaining;rz=.14*math.sin(remaining*math.pi)
    else
     local tumble=reducedMotion and 0 or PickupMotion.tumble(age,r.landAge)
     rx,ry,rz=r.seed*.71+tumble,r.seed*.9+tumble*.28,r.seed*.43+tumble*.21
    end
    local position=r.pos
    if not seated and not r.collectAt and latest and latest.floor then
     local support=PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,rx,ry,rz)*scale
     local raised=math.max(latest.floor+support-.22,position.Y)
     if r.arc then raised=math.max(raised,position.Y+r.size.Y*.5*scale-.22) end
     position=Vector3.new(position.X,raised,position.Z)
    end
    r.motionPose=CFrame.new(position)*CFrame.Angles(rx,ry,rz)
    if scale~=r.drawScale then r.drawScale=scale;r.view.Size=r.size*scale end
    if glow~=(r.glow or 0) then r.glow=glow;r.view.Color=r.color:Lerp(PICKUP_HIGHLIGHT,glow) end
    r.restSample=resting and r.pull==0 and r.socketScale==socketScale and latest or nil
    r.restUnits=r.units
   end
   local landingAge=r.landAge and age-r.landAge
   local hoverAge=landingAge and landingAge-(r.arc and OreDrops.GEM_CONTACT_HOLD or PickupMotion.SETTLE_TIME)
   local arcLanded=live and r.arc and not r.arcExit and landingAge>=0
   -- Once a landed gem starts hovering, transient stationary snapshot changes
   -- must not restart its lift. Only an actual pickup or socket ends the hover.
   local hovering=live and not seated and not pulling and hoverAge and hoverAge>=0
    and (r.hoverStartedAt~=nil or resting or arcLanded)
   local wasHovering=r.hoverAlpha~=nil
   if hovering then
    r.hoverStartedAt=r.hoverStartedAt or (now-hoverAge)
    local t=math.clamp((now-r.hoverStartedAt)/.72,0,1)
    r.hoverAlpha=t*t*(3-2*t)
    r.hoverTime=reducedMotion and 0 or hoverAge
   elseif wasHovering then
    -- Carry the displayed lift into homing, then hand off to its real trajectory.
    r.hoverAlpha*=math.exp(-math.min(dt,.1)*18)
    if not live or seated or r.hoverAlpha<.003 then r.hoverAlpha=nil end
   end
   if not hovering then r.hoverStartedAt=nil end
   if newPose or hovering or wasHovering then
    local pose=r.motionPose
    if r.hoverAlpha then
     local t=r.hoverTime
     local lift=(r.physical and 1.52 or 1.04)+(reducedMotion and 0 or .045*math.sin(t*HOVER_BOB_RATE+r.seed))
     local yaw=t*HOVER_TURN_RATE
     pose=CFrame.new(0,lift*r.hoverAlpha,0)*pose*CFrame.Angles(0,yaw,0)
      *CFrame.Angles(.22*r.hoverAlpha,0,-.32*r.hoverAlpha)
    end
    r.drawPosition=pose.Position;r.view.CFrame=pose
   end
   local floor=arcLanded and r.arc.floor or latest.floor
   if live and not seated and not pulling and landingAge and landingAge>=0 and floor and cameraPosition
    and (not r.expiresAt or now<r.expiresAt) then
    local ground=Vector3.new(r.pos.X,floor-.21,r.pos.Z)
    local distance=(ground-cameraPosition).Magnitude
    if distance<DISPLAY_RANGE then
     r.displayGround=ground
     if r.arc then r.displayLandedAt=now-landingAge end
     -- Use the landing point to rank displays. A hovering pose must never
     -- move its glow and outline to another gem across adjacent render frames.
     r.displayDistance=distance-(r.displayRig and 2.5 or 0)
     -- Start the display on the same buffered contact frame as the clink.
     local contactStrength=1-.8*math.exp(-landingAge*11)
     r.displayStrength=contactStrength*math.clamp((DISPLAY_RANGE-distance)/10,0,1)*opacity
     table.insert(self.displayCandidates,r)
    end
   end
   if opacity~=r.opacity then r.view.Transparency=1-opacity;r.opacity=opacity end
   local canGlint=landingAge and ((landingAge<.24 and (live or r.collectAt)) or (live and not seated and not pulling))
   if (r.arc or r.physical) and landingAge and landingAge>=0 and not reducedEffects and cameraPosition and (canGlint or r.idle) then
    local distanceFade=math.clamp((72-(r.drawPosition-cameraPosition).Magnitude)/12,0,1)
    updateGlint(self,r,landingAge,canGlint and glintStrength*distanceFade*opacity or 0,now)
   else removeIdle(self,r) end
   if (r.physical or r.hasArc) and cameraPosition then
    local offset=r.drawPosition-cameraPosition
    local distance=offset:Dot(offset)
    local air=r.landAge and age<r.landAge or not r.landAge and age<(r.arcTimeout or 1.2)
    local inFlight=air and live and not pulling and displayAt>=r.born
    if r.ribbon then
     if not inFlight or reducedEffects or r.ribbon.untilAt then finishTrail(self,r,now) end
    elseif inFlight and not r.trailUsed and distance<100^2 and self.trailCount<TRAIL_LIMIT and not reducedEffects then
     r.ribbon=launchTrail(r.view,r.color,r.physical and .32 or .16);r.trailUsed=true;self.trailCount+=1
    end
    if r.physical and r.owner==self.player.UserId and live and r.landAge and not seated and not inFlight and not pulling and distance<18^2 and opacity>.35 then
     local rank=distance-(self.valueTarget==r and 8 or 0)
     if rank<bestDistance or (rank==bestDistance and r.seed<closest.seed) then closest=r;bestDistance=rank end
    end
   elseif r.ribbon then
    finishTrail(self,r,now)
   end
  end
 end
 updateDisplays(self,now,reducedMotion,reducedEffects)
 if closest~=self.valueTarget then
  self.valueTarget=closest
  if closest then
   if not self.valueGui then self.valueGui,self.valueText=cargoWorth(self.parent) end
   self.valueGui.Adornee=closest.view;self.valueText.Text=tostring(closest.cargoValue)..' Q';self.valueGui.Enabled=true
  elseif self.valueGui then self.valueGui.Enabled=false;self.valueGui.Adornee=nil end
 end
end
function V:destroy()
 if self.closed then return end;self.closed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do if source.Parent then source.LocalTransparencyModifier=0 end;r.view:Destroy() end
 for _,glint in ipairs(self.idlePool) do glint.anchor:Destroy() end
 for _,rig in ipairs(self.displays) do rig.base:Destroy() end
 if self.amountGui then self.amountGui:Destroy() end
 if self.valueGui then self.valueGui:Destroy() end
 self.records={};self.byId={}
end
return V
