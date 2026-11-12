-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local PICKUP_HIGHLIGHT=Color3.fromRGB(255,248,221)
local TRAIL_LIFETIME,TRAIL_LIMIT=.29,12
local GLINT_LIMIT,SHEEN_LIMIT=12,12
local REFLECTION_LIGHT=Vector3.new(-.42,.86,.28).Unit
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
local function makeGlint()
 local anchor=Instance.new('Attachment');anchor.Name='FacetGlint'
 local halo=Instance.new('BillboardGui');halo.Name='DottedStar';halo.Adornee=anchor
 halo.AlwaysOnTop=true;halo.LightInfluence=0;halo.MaxDistance=96;halo.Parent=anchor
 local dots={}
 local function dot(x,y,width,brightness)
  local frame=Instance.new('Frame');frame.Name='GlintDot';frame.BorderSizePixel=0
  frame.AnchorPoint=Vector2.new(.5,.5);frame.Position=UDim2.fromScale(.5+x,.5+y)
  local pixels=math.max(1,math.round(width))
  frame.Size=UDim2.new(.012,pixels,.012,pixels)
  local round=Instance.new('UICorner');round.CornerRadius=UDim.new(.5,0);round.Parent=frame
  frame.Parent=halo;dots[#dots+1]={frame=frame,brightness=brightness}
 end
 dot(0,0,2.1,1)
 for _,side in ipairs({-1,1}) do
  for i=1,5 do dot(side*i*.013,side*i*.085,1.62-i*.14,1-i*.12) end
  for i=1,3 do dot(side*i*.088,-side*i*.013,1.55-i*.16,1-i*.18) end
 end
 return {anchor=anchor,halo=halo,dots=dots}
end
local function twinkle(age,start,duration)
 local t=math.clamp((age-start)/duration,0,1)
 return math.sin(math.pi*t)^2
end
local function removeIdle(self,r)
 if not r.idle then return end
 r.idle.anchor.Parent=nil;table.insert(self.idlePool,r.idle);r.idle=nil
 self.idleCount-=1
end
local function updateGlint(self,r,age,strength,eye,now)
 local sinceContact=age-r.arc.contact
 local clock=math.max(0,sinceContact-.55)+r.seed*.53
 local cycle=sinceContact<.55 and -1 or math.floor(clock/2.15)
 local pulse=sinceContact<0 and twinkle(age,.13,.35)
  or cycle==-1 and twinkle(sinceContact,-.035,.39) or twinkle(clock%2.15,0,.42)
 if pulse*strength<.015 then removeIdle(self,r);return end
 -- The fine dots use screen-space depth override only while the gem itself is visible.
 if now>=(r.glintQueryAt or 0) then
  r.glintQueryAt=now+.085
  local ignore={self.parent};if self.player.Character then table.insert(ignore,self.player.Character) end
  self.glintRay.FilterDescendantsInstances=ignore
  local target=r.drawPosition+Vector3.yAxis*r.view.Size.Y*.55
  r.glintBlocked=workspace:Raycast(eye,target-eye,self.glintRay)~=nil
 end
 if r.glintBlocked then removeIdle(self,r);return end
 if not r.idle then
  if self.idleCount>=GLINT_LIMIT then return end
  r.idle=table.remove(self.idlePool) or makeGlint();self.idleCount+=1
  local side=(r.seed+cycle)%2==0 and 1 or -1
  local size=r.view.Size
  r.idle.anchor.Position=Vector3.new(side*size.X*.18,size.Y*.52,-side*size.Z*.12)
  r.idle.anchor.Parent=r.view
  local tint=r.color:Lerp(PICKUP_HIGHLIGHT,.88)
  for _,dot in ipairs(r.idle.dots) do dot.frame.BackgroundColor3=tint end
 end
 local width=(r.physical and 3.35 or 2.45)*(.74+pulse*.26)
 r.idle.halo.Size=UDim2.new(width,16,width,16)
 for _,dot in ipairs(r.idle.dots) do dot.frame.BackgroundTransparency=1-pulse*strength*dot.brightness end
end
local function removeSheen(self,r)
 if not r.sheen then return end
 for _,patch in ipairs(r.sheen) do patch:Destroy() end
 r.sheen=nil;self.sheenCount-=1
end
local function updateSheen(self,r,eye,opacity)
 if not r.sheen then
  if self.sheenCount>=SHEEN_LIMIT then return end
  r.sheen={};self.sheenCount+=1
  for i=1,3 do
   local patch=Instance.new('Part');patch.Name='FacetReflection';patch.Anchored=true
   patch.CanCollide=false;patch.CanTouch=false;patch.CanQuery=false;patch.CastShadow=false
   patch.Material=Enum.Material.Neon;patch.Transparency=1
   patch.Color=r.color:Lerp(PICKUP_HIGHLIGHT,i==1 and .91 or .68);patch.Parent=r.view
   r.sheen[i]=patch
  end
 end
 local pose,size=r.view.CFrame,r.view.Size
 local localEye=pose:PointToObjectSpace(eye)
 local direction=eye-pose.Position
 if direction.Magnitude<.001 then return end
 local halfway=direction.Unit+REFLECTION_LIGHT
 local halfNormal=halfway.Magnitude>.001 and halfway.Unit or REFLECTION_LIGHT
 local tableNormal=pose:PointToWorldSpace(Vector3.yAxis)-pose.Position
 local polished=math.max(0,tableNormal:Dot(halfNormal))^14
 local span=math.min(size.X,size.Z)
 local main,edge,crown=table.unpack(r.sheen)
 main.Size=Vector3.new(span*.42,.003,span*.10)
 edge.Size=Vector3.new(span*.26,.003,span*.026)
 local angle=CFrame.Angles(0,.57,0)
 main.CFrame=pose*CFrame.new(size.X*.012,size.Y*.501,-size.Z*.025)*angle
 edge.CFrame=pose*CFrame.new(size.X*.028,size.Y*.501,size.Z*.058)*angle
 main.Transparency=1-opacity*(.49+.46*polished)
 edge.Transparency=1-opacity*(.34+.54*polished)
 -- Keep the broad accent on the crown face turned toward the viewer.
 local side=math.abs(localEye.X/size.X)>math.abs(localEye.Z/size.Z)
 local yaw=side and (localEye.X>=0 and 0 or math.pi) or (localEye.Z<0 and math.pi*.5 or -math.pi*.5)
 local run=side and size.X or size.Z
 crown.Size=Vector3.new(span*.21,.003,span*.16)
 crown.CFrame=pose*CFrame.Angles(0,yaw,0)*CFrame.new(run*.322,size.Y*.352,span*.04)
  *CFrame.Angles(0,0,-math.atan2(size.Y*.33,run*.20))
 local crownNormal=crown.CFrame:PointToWorldSpace(Vector3.yAxis)-crown.Position
 crown.Transparency=1-opacity*(.38+.54*math.max(0,crownNormal:Dot(halfNormal))^9)
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
 r.fadeAt=source:GetAttribute('FadeAt');r.expiresAt=source:GetAttribute('ExpiresAt')
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
  player=player,trailCount=0,idleCount=0,idlePool={},sheenCount=0,glintRay=RaycastParams.new(),lastTotal=player:GetAttribute('CollectedOreTotal') or 0},V)
 self.glintRay.FilterType=Enum.RaycastFilterType.Exclude;self.glintRay.RespectCanCollide=true
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
    view.Material=Enum.Material.SmoothPlastic;view.MaterialVariant='';view.Reflectance=.62;view.CastShadow=true
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
 local camera=workspace.CurrentCamera
 local cameraPosition=camera and camera.CFrame.Position
 local reducedEffects=self.player:GetAttribute('ReducedEffects')==true or self.player:GetAttribute('MA_ReducedEffects')==true
 local glintStrength=self.player:GetAttribute('ReducedFlashing')==true and .36 or 1
 local reducedMotion=self.reducedMotion and self.reducedMotion()
 local displayAt=now-PickupMotion.DELAY
 local closest,bestDistance=nil,math.huge
 for source,r in pairs(self.records) do
  if not r.collectAt and source.Parent then
   local processed=source:GetAttribute('ProcessedAt')
   local collectedAt=processed or source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.processed=processed~=nil
    r.collectAt=r.processed and collectedAt or now
    r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
    if r.processed then r.pressScale=r.view.Size.Y/math.max(.01,r.size.Y) end
    r.collectTarget=source:GetAttribute(r.processed and 'ProcessedPosition' or 'CollectedPosition')
   end
  end
  local opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  local scale=1;local glow=0;local done=false
  if r.collectAt and r.processed and r.collectTarget then
   local t=math.clamp((now-r.collectAt)/Workshop.PRESS_CONTACT,0,1)
   local close=math.clamp((t-.18)/.82,0,1)^2
   local ease,shrink=PickupMotion.collection(close)
   r.pos=r.collectFrom:Lerp(r.collectTarget,ease)
   scale=math.max(.045,(r.pressScale or .48)*shrink)
   opacity=(r.collectOpacity or 1)*(1-math.clamp((close-.82)/.18,0,1))
   glow=.48*close;done=t>=1
  elseif r.collectAt then
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
   opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  else
   r.removedAt=r.removedAt or now
   -- Destruction can replicate just before its receipt. Keep a tiny grace
   -- window, then fade in place for expiry/cleanup without inventing collection.
   opacity*=1-math.clamp((now-r.removedAt-.06)/.18,0,1);done=now-r.removedAt>=.28
  end
  if r.arc and displayAt<r.born then opacity=0 end
  if done then
   removeTrail(self,r);removeIdle(self,r);removeSheen(self,r);r.view:Destroy()
   self.byId[r.seed]=nil;self.records[source]=nil
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
      self.audio:play('ore_land',point,{level=math.clamp(speed/43,.67,1.18)*(r.physical and 1 or .82),
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
   if newPose then
    r.drawPosition=r.motionPose.Position;r.view.CFrame=r.motionPose
   end
   if opacity~=r.opacity then r.view.Transparency=1-opacity;r.opacity=opacity end
   if r.arc and live and displayAt>=r.born and not seated and cameraPosition then
    local distance=(r.drawPosition-cameraPosition).Magnitude
    if opacity>.02 and distance<(r.sheen and 88 or 82) then updateSheen(self,r,cameraPosition,opacity) else removeSheen(self,r) end
    if not reducedEffects and (not pulling or age<r.landAge+OreDrops.GEM_CONTACT_HOLD) then
     local distanceFade=math.clamp((94-distance)/17,0,1)
     updateGlint(self,r,age,glintStrength*distanceFade*opacity,cameraPosition,now)
    else removeIdle(self,r) end
   else removeIdle(self,r);removeSheen(self,r) end
   if (r.physical or r.hasArc) and cameraPosition then
    local offset=r.drawPosition-cameraPosition
    local distance=offset:Dot(offset)
    local air=r.landAge and age<r.landAge or not r.landAge and age<(r.arcTimeout or 1.2)
    local inFlight=air and live and not pulling and displayAt>=r.born
    if r.ribbon then
     if not inFlight and r.arc then
      removeTrail(self,r)
     elseif not inFlight or reducedEffects then
      if r.ribbon.trail.Enabled then r.ribbon.trail.Enabled=false;r.ribbon.untilAt=now+TRAIL_LIFETIME end
     end
     if r.ribbon and r.ribbon.untilAt and now>=r.ribbon.untilAt then removeTrail(self,r) end
    elseif inFlight and not r.trailUsed and distance<100^2 and self.trailCount<TRAIL_LIMIT and not reducedEffects then
     r.ribbon=launchTrail(r.view,r.color,r.physical and .32 or .16);r.trailUsed=true;self.trailCount+=1
    end
    if r.physical and r.owner==self.player.UserId and live and r.landAge and not seated and not inFlight and not pulling and distance<18^2 and opacity>.35 then
     local rank=distance-(self.valueTarget==r and 8 or 0)
     if rank<bestDistance or (rank==bestDistance and r.seed<closest.seed) then closest=r;bestDistance=rank end
    end
   elseif r.ribbon then
    removeTrail(self,r)
   end
  end
 end
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
 if self.amountGui then self.amountGui:Destroy() end
 if self.valueGui then self.valueGui:Destroy() end
 self.records={};self.byId={}
end
return V
