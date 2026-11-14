-- Local-only feedback. Rest poses and reward objects belong to other systems.
local V={}
local WARM=Color3.fromRGB(255,218,139)
local HOT=Color3.fromRGB(255,249,216)
local CHAR=Color3.new(0,0,0)
local EMBER=Color3.fromRGB(255,27,59)
local RED_HIGHLIGHT=Color3.fromRGB(255,119,145)
local Players=game:GetService('Players')
local GuiService=game:GetService('GuiService')
function V.reducedMotion()
 local player=Players.LocalPlayer
 local system=false;pcall(function() system=GuiService.ReducedMotionEnabled end)
 return system or player and (player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true)
end
local function part(parent,class,name,color)
 local p=Instance.new(class);p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false
 p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Parent=parent
 return p
end
function V.new(parent,audio,onSplit,onCameraBeat,findFracture)
 local variation=Random.new()
 local self={pieces={},sparks={},fractures={},tints={},parent=parent,audio=audio}
 local function track(p,at,from,velocity,ground,spin,weight,tink,groundTail)
  local flight=(velocity.Y+math.sqrt(velocity.Y^2+192*math.max(0,from.Y-ground)))/96
  self.pieces[#self.pieces+1]={p=p,at=at,from=from,v=velocity,duration=flight+groundTail,
   ground=ground,spin=spin,weight=weight,tink=tink,size=p.Size}
 end
 function self:chips(at,point,normal,tint,count,large,scale,ground,source)
  if not BeamVFX.near(point,large and 92 or 60) then return end
  if BeamVFX.reduced() then count=math.min(count,large and 2 or 1) end
  local sideways=normal:Cross(Vector3.yAxis)
  sideways=sideways.Magnitude>.01 and sideways.Unit or Vector3.xAxis
  local up=normal:Cross(sideways).Unit
  for i=1,count do
   -- Ordinary contact chips cannot consume the final fracture's fragment budget.
   if #self.pieces>=28 then break end
   local angle=i*2.399+at%3;local spread=sideways*math.cos(angle)+up*math.sin(angle)
   local direction=normal*.7+spread*(large and 1.25 or .66)
   local size=large and scale*variation:NextNumber(.38,1.05) or variation:NextNumber(.23,.65)
   local p=part(parent,'WedgePart',large and 'CrystalBreakPiece' or 'CrystalChip',tint:Lerp(HOT,variation:NextNumber(.02,.21)))
   if source then
    p.Material=source.Material;p.MaterialVariant=source.MaterialVariant;p.Reflectance=source.Reflectance
   end
   p.Size=Vector3.new(size*variation:NextNumber(.56,.92),size*variation:NextNumber(1.12,1.78),size)
   p.CFrame=CFrame.new(point)
   local origin=point+normal*(size*.85+.025)
   p.Position=origin
   local velocity=direction*8+Vector3.yAxis*(large and 4 or 4.5)
   local floor=ground or point.Y-4
   -- The chip's flight ends at the floor, not at an arbitrary particle timeout.
   track(p,at,origin,velocity,floor,Vector3.new(i*1.3,2.6*i,.6*i),.85,nil,1.05)
  end
 end
 local function releaseSparks(point,ground,color,strength,now)
  local player=Players.LocalPlayer
  local lowFlash=player and player:GetAttribute('ReducedFlashing')==true
  local heading=variation:NextNumber(0,2*math.pi)
  for i=1,8 do
   if #self.sparks>=32 then break end
   local streak=i<=5
   local angle=heading+i*2.39996+variation:NextNumber(-.70,.70)
   local direction=Vector3.new(math.cos(angle),0,math.sin(angle))
   local drift=Vector3.new(-direction.Z,0,direction.X)
   local spark=part(parent,'Part',streak and 'CrystalFireworkStreak' or 'CrystalDriftingEmber',color:Lerp(HOT,variation:NextNumber(.35,.88)))
   if not lowFlash then spark.Material=Enum.Material.Neon end
   if not streak then spark.Shape=Enum.PartType.Ball end
   spark.Transparency=1;spark.Size=Vector3.one*.045;spark.Position=point
   self.sparks[#self.sparks+1]={
    p=spark,at=now+variation:NextNumber(0,streak and .09 or .21),from=point,ground=ground,streak=streak,
    duration=streak and variation:NextNumber(1.05,1.85) or variation:NextNumber(2.1,3.2),
    v=direction*variation:NextNumber(streak and 8 or 2.5,streak and 19 or 6),
    lift=variation:NextNumber(streak and 5.5 or 7.5,streak and 14 or 12),
    drift=drift*variation:NextNumber(.32,.88),phase=variation:NextNumber(0,2*math.pi),frequency=variation:NextNumber(3.8,9.5),
    size=math.sqrt(strength)*variation:NextNumber(.085,.19),lowFlash=lowFlash,
   }
  end
 end
 local function sparkPosition(s,t)
  local travel=(1-math.exp(-2.4*t))/2.4
  local bend=math.sin(s.phase+t*s.frequency)-math.sin(s.phase)
  local lift=s.lift*(1-math.exp(-1.8*t))/1.8-1.2*t*t
  local p=s.from+s.v*travel+s.drift*(bend*math.min(t,.65))+Vector3.yAxis*lift
  return Vector3.new(p.X,math.max(s.ground+.08,p.Y),p.Z)
 end
 function self:step(now)
  for i=#self.fractures,1,-1 do
   local half=self.fractures[i];local age=now-half.at
   if age>=1.06 then half.p:Destroy();table.remove(self.fractures,i)
   else
    local open=1-(1-math.clamp(age/.24,0,1))^3
    local settle=math.clamp((age-.24)/.38,0,1)
    local side=half.side
    half.p.CFrame=half.hinge*CFrame.new(side*open*half.gap,0,0)
     *CFrame.Angles(0,side*open*.13,-side*(open*half.angle+(half.reduced and 0 or settle*.10)))*CFrame.new(half.offset)
    half.p.Transparency=math.clamp((age-.67)/.39,0,1)^2
   end
  end
  for i=#self.sparks,1,-1 do
   local s=self.sparks[i];local t=now-s.at
   if t>=s.duration then s.p:Destroy();table.remove(self.sparks,i)
   elseif t>=0 then
    local q=t/s.duration
    local pos=sparkPosition(s,t)
    local tail=sparkPosition(s,math.max(0,t-.075))
    local length=(pos-tail).Magnitude
    local width=s.size*(1-.70*q^2)
    local flicker=s.lowFlash and 0 or .16*(.5+.5*math.sin(s.phase+t*s.frequency*2.1))
    s.p.Transparency=1-math.min(1,t/.025)*(1-q^2)*(1-(s.lowFlash and .44 or .14)-flicker)
    s.p.Size=Vector3.new(width,width,s.streak and math.max(width,length) or width)
    s.p.CFrame=s.streak and length>.001 and CFrame.lookAt(pos:Lerp(tail,.5),pos) or CFrame.new(pos)
   end
  end
  for i=#self.pieces,1,-1 do
   local e=self.pieces[i];local t=now-e.at
   if t>=e.duration then e.p:Destroy();table.remove(self.pieces,i)
   elseif t<0 then continue
   elseif e.burst then
    local q=t/e.duration;local scale=1-(1-q)^3
    e.p.Size=Vector3.new(1.5,.52,1.5)*e.size*math.max(.06,scale)
    e.p.Transparency=.15+.85*q^.64
   else
    local gravity=96
    local pos=e.from+e.v*t-Vector3.yAxis*(gravity*.5*t*t)
    local turn=(e.landedAt or t)*(e.weight or 1)
    local rx,ry,rz=turn*9+e.spin.X,turn*7+e.spin.Y,turn*4+e.spin.Z
    local size=e.size
    local rotation=CFrame.Angles(rx,ry,rz)
    local support=PickupMotion.supportHeight(size.X,size.Y,size.Z,rx,ry,rz)
    local floor=e.ground+support-.035
    if e.weight and not e.landedAt and gravity*t>e.v.Y and pos.Y<=floor then
     local speed=math.sqrt(math.max(0,e.v.Y*e.v.Y+2*gravity*(e.from.Y-floor)))
     local touchAge=math.clamp((e.v.Y+speed)/gravity,0,t)
     e.landedAt=t
     e.rebound=math.min(speed*.20,8)
     e.contact=e.from+Vector3.new(e.v.X*touchAge,floor-e.from.Y,e.v.Z*touchAge)
     if e.tink and audio and t-touchAge<.13 then
      audio:play('crystal_fall_tink',e.contact,{pitch=e.weight<.6 and .84 or 1.15,level=e.tink*math.clamp(speed/20,.55,1.15)})
     end
    end
    if e.landedAt then
     local age=t-e.landedAt
     local skid=1-math.clamp(age/.19,0,1)
     local hop=e.rebound and math.max(0,e.rebound*age-gravity*.5*age*age) or 0
     pos=e.contact+Vector3.new(e.v.X*.065*(1-skid^3),hop,e.v.Z*.065*(1-skid^3))
    end
    local progress=math.clamp(t/e.duration,0,1)
    local scale=math.max(.001,1-progress^2)
    e.p.Size=size*scale
    pos-=Vector3.yAxis*support*(1-scale)
    floor=e.ground+support*scale-.035
    e.p.Transparency=.20*progress^3
    e.p.CFrame=CFrame.new(pos.X,math.max(floor,pos.Y),pos.Z)*rotation
   end
  end
 end
 local function openHalves(r,frame,size,now,reduced)
  local cut=r.source:GetAttribute('CrystalCut')
  local template=cut and findFracture and findFracture(cut)
  if not template then return end
  local left,right=template:FindFirstChild('Left'),template:FindFirstChild('Right')
  if not left or not right then return end
  -- Both halves share the lower seam and open outward around it.
  local foot=Vector3.yAxis*((template:GetAttribute('HingeY') or -.5)*size.Y)
  local hinge=frame*CFrame.new(foot)
  for index,original in ipairs({left,right}) do
   if #self.fractures>=32 then table.remove(self.fractures,1).p:Destroy() end
   local half=original:Clone()
   local side=index==1 and -1 or 1
   local center=original:GetAttribute('CenterRatio')*size
   half.Size=original:GetAttribute('SizeRatio')*size
   half.CFrame=frame*CFrame.new(center);half.Parent=parent
   self.fractures[#self.fractures+1]={p=half,at=reduced and now-.24 or now,hinge=hinge,side=side,reduced=reduced,
    offset=center-foot,gap=math.clamp(size.X*.19,.18,.70),angle=index==1 and .46 or .63}
  end
 end
 local function split(self,r,now,prism,nomad)
  local v,s=r.view,r.source
  local frame=r.splitPose or r.restPose
  local size=r.splitSize or v.Size
  local ground=s:GetAttribute('GroundY') or frame.Position.Y-size.Y*.5
  local fullSize=s:GetAttribute('FullSize') or v.Size
  if type(fullSize)=='number' then fullSize=Vector3.one*fullSize end
  local strength=if prism or nomad then math.clamp(v.Size.Magnitude*.30,1.08,2.10)*(prism and 1.30 or 1)
   else math.clamp(fullSize.Magnitude*.21,.9,2.45)
  local clusterSize=prism and (s:GetAttribute('BlastClusterSize') or 1) or 1
  local prismReceipt=prism and s:GetAttribute('CutProjectileFX')==true
  local point=Vector3.new(frame.Position.X,ground+math.max(.8,size.Y*.60),frame.Position.Z)
  local reduced=BeamVFX.reduced() or V.reducedMotion()
  local player=Players.LocalPlayer
  local owned=player and s:GetAttribute('CrystalBreakOwner')==player.UserId
  if audio and not nomad then
   local volume=owned and 1 or .62
   if not prismReceipt then audio:play(prism and 'prism_blast' or 'crystal_split',point,{level=volume}) end
   audio:play('crystal_impact',point,{level=volume*math.clamp(strength,.9,1.25)})
   audio:play('crystal_release_tink',point,{level=volume})
  end
  if not nomad and onSplit and not V.reducedMotion() then onSplit(point,strength,now,prism,owned) end
  openHalves(r,frame,size,now,reduced)
  if not reduced then
   if not prism and not nomad then releaseSparks(point,ground,r.baseColor,strength,now) end
   if RoleVisuals and not nomad then
    local floor=Vector3.new(point.X,ground+.085,point.Z)
    if not prismReceipt then
     RoleVisuals.Pulse(floor,prism and EMBER or r.baseColor:Lerp(WARM,.68),strength*.55,strength*(prism and 8.6 or 6.6),.58)
     if prism and clusterSize<=5 then RoleVisuals.Pulse(floor+Vector3.yAxis*.13,RED_HIGHLIGHT,strength*.23,strength*5.8,.29) end
    end
    RoleVisuals.ImpactParticles(point,prism and EMBER or r.baseColor,strength*.83,prism and 'PrismBlast' or 'CrystalBreak')
   end
   for i=1,prism and math.clamp(math.floor(26/clusterSize),2,14) or 8 do
    if #self.pieces>=48 then break end
    local theta=i*2.399963+now%3
    local direction=Vector3.new(math.cos(theta),0,math.sin(theta))
    local chipColor=prism and (i%3==0 and RED_HIGHLIGHT or CHAR:Lerp(EMBER,.23)) or r.baseColor:Lerp(HOT,variation:NextNumber(.03,.27))
    local chip=part(parent,'WedgePart','CrystalBreakPiece',chipColor)
    local size=strength*(prism and (.11+.052*(i%4)) or variation:NextNumber(.20,.48))
    chip.Size=Vector3.new(size*.55,size*(prism and 2.1 or variation:NextNumber(1.35,2.65)),size)
    chip.Material=prism and (i%3==0 and Enum.Material.Neon or Enum.Material.Glass) or v.Material
    if not prism then chip.MaterialVariant=v.MaterialVariant;chip.Reflectance=v.Reflectance end
    local origin=point+direction*.22
    chip.Position=origin
   track(chip,now,origin,direction*((prism and 13 or 7)+2*(i%4))+Vector3.yAxis*(10+1.5*(i%3)),
     ground,Vector3.new(i*.83,i*1.47,i*.49),.85,
     (i==2 or i==7) and (owned and .64 or .39) or nil,.99)
   end
   if #self.pieces<48 and clusterSize<=5 then
    local spark=part(parent,'Part','CrystalSplitSpark',prism and RED_HIGHLIGHT or r.baseColor:Lerp(WARM,.77))
    spark.Shape=Enum.PartType.Ball;spark.Material=Enum.Material.Neon
    spark.Size=Vector3.one*.10;spark.Position=point
    self.pieces[#self.pieces+1]={p=spark,at=now,duration=.19,burst=true,size=strength}
   end
  end
 end
 local function darkness(r,now)
  local blend=math.clamp((now-(r.shadeAt or now))/.11,0,1)
  local target=r.targetDarkness or 0
  return target+((r.fromDarkness or target)-target)*(1-blend)^2
 end
 function self:shade(r,color,target,now)
  if r.mineralColor~=color then r.mineralColor=color;self.tints[r]=true end
  if r.targetDarkness~=target then
   local from=r.targetDarkness and darkness(r,now) or target
   r.fromDarkness=not V.reducedMotion() and from or target
   r.targetDarkness=target;r.shadeAt=now
   self.tints[r]=true
  end
 end
 function self:cut(r,now,beat)
  r.cutPulse=r.cutPulseAt==now and math.max(r.cutPulse,beat) or beat
  r.cutPulseAt=now;self.tints[r]=true
 end
 function self:forget(r) self.tints[r]=nil end
 function self:applyTints(now)
  local player=Players.LocalPlayer
  local reduced=player and (player:GetAttribute('ReducedFlashing')==true or player:GetAttribute('ReducedEffects')==true or player:GetAttribute('MA_ReducedEffects')==true)
  for r in pairs(self.tints) do
   local view=r.view
   if not view.Parent or view.Transparency>=1 then
    self:forget(r)
   else
    local charAt=r.clusterAt
    local charred=charAt and now>=charAt
    local shade=charred and 1 or darkness(r,now)
    r.visibleDarkness=shade
    local age=r.flashAt and now-r.flashAt or math.huge
    local duration=r.flashDuration or .28
    local attack=math.clamp(age/.026,0,1)
    local initial=Feedback.impactWhite(age,duration)*(r.flashStrength or 0)*attack
    local afterglow=math.max(0,1-(now-(r.cutPulseAt or -math.huge))/.18)
    local pulse=(r.cutPulse or 0)*afterglow
    local white=math.max(initial*(reduced and .25 or 1),pulse*(reduced and .015 or .045))*(1-shade)
    view.Color=(r.mineralColor or r.baseColor):Lerp(CHAR,shade):Lerp(HOT,white)
    if age>=duration then r.flashAt=nil end
    if not r.flashAt and afterglow<=0 and now>=(r.shadeAt or 0)+.11 and (not charAt or charred) then self:forget(r) end
   end
  end
 end
 function self:requestBreakHold(r,now,request)
  if r.visual.broken or not r.restPose or V.reducedMotion() then return end
  local source=r.source
  local at=source:GetAttribute('CrystalBreakAt') or 0
  if at<=0 or now<at or now-at>=.25 or at<=math.max(r.lastBreakAt or 0,r.breakHoldRequestedAt or 0) then return end
  if (source:GetAttribute('BreakSerial') or 0)==0 then return end
  r.breakHoldRequestedAt=at
  local projectile=source:GetAttribute('CutProjectile')
  local kind
  if projectile=='Prism' then return end -- Ramiel already has a post-beam hold.
  if projectile=='Nomad' then kind=projectile
  else
   local player=Players.LocalPlayer
   if not player or source:GetAttribute('CrystalBreakOwner')~=player.UserId then return end
   local full=source:GetAttribute('FullSize')
   kind=typeof(full)=='Vector3' and full.Magnitude*.21>=1.35 and 'HeavySplit' or 'Split'
  end
  request(kind,r)
 end
 function self:react(r,now)
  local s,v=r.source,r.view
  local clusterAt=s:GetAttribute('ClusterBlackAt')
  if clusterAt~=r.clusterAt then r.clusterAt=clusterAt;self.tints[r]=true end
  local impact=s:GetAttribute('CutContactAt') or 0
  local broken=(s:GetAttribute('BreakSerial') or 0)>0
  local projectile=s:GetAttribute('CutProjectile')
  local prism=projectile=='Prism'
  local nomad=projectile=='Nomad'
  local breakAt=s:GetAttribute('CrystalBreakAt') or 0
  if impact>now and impact>r.lastContactAt then
   r.nextContactAt=impact
  elseif impact>r.lastContactAt then
   r.nextContactAt=nil
   local previousContact=r.lastContactAt
   r.lastContactAt=impact
   local at=now-impact
   local shot=s:GetAttribute('CutIsShot')
   local fractured=s:GetAttribute('CutFractured')
   if not broken and not prism and not nomad and at<.21 and BeamVFX.near(v.Position,95) and (shot or fractured or now>=(r.chipGate or 0)) then
    local heavy=projectile=='Ball'
    r.chipGate=now+.12
    if shot or fractured or impact-previousContact>.30 then
     r.flashAt=now;r.flashDuration=heavy and .18 or shot and .13 or .23
     r.flashStrength=heavy and .22 or shot and .16 or fractured and .13 or .10
     self.tints[r]=true
    end
    local point=s:GetAttribute('CutContactPoint') or v.Position
    local normal=s:GetAttribute('CutContactNormal') or Vector3.yAxis
    local tilt=Vector3.new(-normal.Z,0,normal.X)
    if tilt.Magnitude<.1 then tilt=Vector3.new(.7,0,.3) end
    if (shot or fractured) and not s:GetAttribute('SteadyCrystal') then
     r.impactAt=now;r.kick=tilt*(heavy and .095 or projectile=='Dart' and .055 or .045)
    end
    self:chips(now,point,normal,r.baseColor,heavy and 6 or fractured and 5 or 3,false,nil,s:GetAttribute('GroundY'),s)
    if onCameraBeat and not V.reducedMotion() then
     if fractured and not shot then
      onCameraBeat('Fracture',point,now)
     elseif shot and not s:GetAttribute('CutProjectileFX') and (projectile=='Dart' or projectile=='Ball') then
      onCameraBeat(heavy and 'BallHit' or 'NeedleHit',point,now,.88)
     end
    end
    if fractured and not shot then
     RoleVisuals.Pulse(point+normal*.10,r.baseColor:Lerp(HOT,.55),.19,1.65,.18,normal,.78)
    end
    if shot and not s:GetAttribute('CutProjectileFX') then
     local health=(s:GetAttribute('HP') or 1)/math.max(1,s:GetAttribute('MaxHP') or 1)
     audio:play('crystal_snap',point,{pitch=1.20-.23*health})
     audio:play('crystal_electric',point,{pitch=.95+.12*(1-health)})
     r.chipTail={at=now+.042,point=point,pitch=1.04+.22*(1-health)}
    end
   end
  end
  if r.chipTail and now>=r.chipTail.at then
   local cue=r.chipTail;r.chipTail=nil
   if not broken and now-cue.at<.10 then audio:play('crystal_chip',cue.point,{pitch=cue.pitch}) end
  end
  if broken and breakAt>0 and breakAt>(r.lastBreakAt or 0) then
   if now<breakAt then return end
   r.lastBreakAt=breakAt
   if r.restPose and now-breakAt<.38 and BeamVFX.near(r.restPose.Position,92) then split(self,r,now,prism,nomad) end
   v.Transparency=1;self:forget(r)
   return
  end
  if r.restPose and r.kick then
   local t=r.impactAt and now-r.impactAt or math.huge
   local amount=t<.14 and math.sin(math.pi*t/.14)*(1-t/.14) or 0
   if t>=.14 then r.kick=nil end
   local kick=not BeamVFX.reduced() and not V.reducedMotion() and r.kick or Vector3.zero
   local foot=r.restPose.Position-Vector3.yAxis*(v.Size.Y*.5)
   v.CFrame=CFrame.new(foot)*CFrame.Angles(kick.X*amount,0,kick.Z*amount)*CFrame.new(-foot)*r.restPose
  end
 end
 function self:destroy()
  for _,e in ipairs(self.pieces) do e.p:Destroy() end;table.clear(self.pieces)
  for _,s in ipairs(self.sparks) do s.p:Destroy() end;table.clear(self.sparks)
  for _,half in ipairs(self.fractures) do half.p:Destroy() end;table.clear(self.fractures)
  table.clear(self.tints)
 end
 return self
end
return V
