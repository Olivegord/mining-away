-- Local-only feedback. Rest poses and reward objects belong to other systems.
local V={}
function V.releaseAt(source,breakAt)
 return (source:GetAttribute('CrystalSplitAt') or breakAt)+PickupMotion.DELAY
end
local WARM=Color3.fromRGB(255,218,139)
local HOT=Color3.fromRGB(255,249,216)
local CHAR=Color3.fromRGB(12,9,10)
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
function V.new(parent,audio,onSplit)
 local self={pieces={},tints={},clusterTargets={},parent=parent,audio=audio}
 local function track(p,at,from,velocity,duration,ground,spin,weight,tink)
  self.pieces[#self.pieces+1]={p=p,at=at,from=from,v=velocity,duration=duration,ground=ground,spin=spin,weight=weight,tink=tink}
 end
 function self:chips(at,point,normal,tint,count,large,scale,ground)
  if not BeamVFX.near(point,large and 92 or 60) then return end
  if BeamVFX.reduced() then count=math.min(count,large and 2 or 1) end
  local sideways=normal:Cross(Vector3.yAxis)
  sideways=sideways.Magnitude>.01 and sideways.Unit or Vector3.xAxis
  local up=normal:Cross(sideways).Unit
  for i=1,count do
   if #self.pieces>=48 then break end
   local angle=i*2.399+at%3;local spread=sideways*math.cos(angle)+up*math.sin(angle)
   local direction=normal*.7+spread*(large and 1.25 or .66)
   local size=large and scale*(.42+i*.1) or .14+i*.055
   local p=part(parent,'WedgePart',large and 'CrystalBreakPiece' or 'CrystalChip',tint:Lerp(HOT,.34+(i%3)*.13))
   p.Size=Vector3.new(size*.72,size*1.45,size)
   p.CFrame=CFrame.new(point)
   local origin=point+normal*(size*.85+.025)
   p.Position=origin
   track(p,at,origin,direction*8+Vector3.yAxis*(large and 4 or 4.5),
    large and .5 or .37,ground or point.Y-4,Vector3.new(i*1.3,2.6*i,.6*i))
  end
 end
 function self:step(now)
  for i=#self.pieces,1,-1 do
   local e=self.pieces[i];local t=now-e.at
   if t>=e.duration then e.p:Destroy();table.remove(self.pieces,i)
   elseif e.burst then
    local q=t/e.duration;local scale=1-(1-q)^3
    e.p.Size=Vector3.new(1.5,.52,1.5)*e.size*math.max(.06,scale)
    e.p.Transparency=.15+.85*q^.64
   else
    local gravity=e.weight and 96 or 46
    local pos=e.from+e.v*t-Vector3.yAxis*(gravity*.5*t*t)
    local turn=(e.landedAt or t)*(e.weight or 1)
    local rx,ry,rz=turn*9+e.spin.X,turn*7+e.spin.Y,turn*4+e.spin.Z
    local size=e.p.Size
    local rotation=CFrame.Angles(rx,ry,rz)
    local support=PickupMotion.supportHeight(size.X,size.Y,size.Z,rx,ry,rz)
    local floor=e.ground+support-.035
    if e.weight and not e.landedAt and gravity*t>e.v.Y and pos.Y<=floor then
     local speed=math.sqrt(math.max(0,e.v.Y*e.v.Y+2*gravity*(e.from.Y-floor)))
     e.landedAt=t
     local touchAge=math.clamp((e.v.Y+speed)/gravity,0,t)
     e.contact=e.from+Vector3.new(e.v.X*touchAge,floor-e.from.Y,e.v.Z*touchAge)
     if e.tink and audio and t-touchAge<.13 then
      audio:play('crystal_fall_tink',e.contact,{pitch=e.weight<.6 and .84 or 1.15,level=e.tink*math.clamp(speed/20,.55,1.15)})
     end
    end
    if e.landedAt then
     local skid=1-math.clamp((t-e.landedAt)/.13,0,1)
     pos=e.contact+Vector3.new(e.v.X,0,e.v.Z)*(.032*(1-skid^3))
    end
    e.p.CFrame=CFrame.new(pos.X,math.max(floor,pos.Y),pos.Z)*rotation
    e.p.Transparency=math.clamp((t/e.duration-.69)/.31,0,1)
   end
  end
 end
 local function split(self,r,now,prism,nomad)
  local v,s=r.view,r.source
  local frame=r.restPose
  local ground=s:GetAttribute('GroundY') or frame.Position.Y-v.Size.Y*.5
  local strength=math.clamp(v.Size.Magnitude*.30,1.08,2.10)*(prism and 1.30 or 1)
  local clusterSize=prism and (s:GetAttribute('BlastClusterSize') or 1) or 1
  local prismReceipt=prism and s:GetAttribute('CutProjectileFX')==true
  local point=Vector3.new(frame.Position.X,ground+math.max(.8,v.Size.Y*.60),frame.Position.Z)
  local axis=frame.RightVector
  local reduced=BeamVFX.reduced() or V.reducedMotion()
  local player=Players.LocalPlayer
  local owned=player and s:GetAttribute('CrystalBreakOwner')==player.UserId
  if audio and not nomad then
   local volume=owned and 1 or .62
   if not prismReceipt then audio:play(prism and 'prism_blast' or 'crystal_split',point,{level=volume}) end
   audio:play('crystal_impact',point,{level=volume*math.clamp(strength,.9,1.25)})
   audio:play('crystal_release_tink',point,{level=volume})
  end
  if not nomad and (owned or prism) and onSplit and not reduced then onSplit(point,strength,now,prism) end
  if clusterSize<=5 then
   for _,side in ipairs({-1,1}) do
    if #self.pieces>=46 then break end
    local wingColor=prism and CHAR:Lerp(EMBER,side==1 and .29 or .15) or r.baseColor:Lerp(WARM,side==1 and .58 or .27)
    local wing=part(parent,'WedgePart','CrystalSplitFace',wingColor)
    wing.Size=Vector3.new(.82,1.54,1.12)*strength
    local origin=point+axis*side*strength*.24
    wing.CFrame=CFrame.new(origin)*CFrame.Angles(0,side*.5,side*.2)
    track(wing,now,origin,axis*side*(7.4+strength)+Vector3.yAxis*(8.3+strength),.76,ground,
     Vector3.new(side*.7,side*.5,side*.2),.48,side==1 and (owned and .85 or .51) or nil)
   end
  end
  if not reduced then
   if RoleVisuals and not nomad then
    local floor=Vector3.new(point.X,ground+.085,point.Z)
    if not prismReceipt then
     RoleVisuals.Pulse(floor,prism and EMBER or r.baseColor:Lerp(WARM,.68),strength*.55,strength*(prism and 8.6 or 6.6),.58)
     if prism and clusterSize<=5 then RoleVisuals.Pulse(floor+Vector3.yAxis*.13,RED_HIGHLIGHT,strength*.23,strength*5.8,.29) end
    end
    RoleVisuals.ImpactParticles(point,prism and EMBER or r.baseColor:Lerp(WARM,.59),strength*.83,prism and 'PrismBlast' or 'CrystalBreak')
   end
   for i=1,prism and math.clamp(math.floor(26/clusterSize),2,14) or 8 do
    if #self.pieces>=48 then break end
    local theta=i*2.399963+now%3
    local direction=Vector3.new(math.cos(theta),0,math.sin(theta))
    local chipColor=prism and (i%3==0 and RED_HIGHLIGHT or CHAR:Lerp(EMBER,.23)) or r.baseColor:Lerp(HOT,.60+.055*(i%4))
    local chip=part(parent,'WedgePart','CrystalBreakPiece',chipColor)
    local size=strength*(.11+.052*(i%4))
    chip.Size=Vector3.new(size*.55,size*2.1,size)
    chip.Material=i%3==0 and Enum.Material.Neon or Enum.Material.Glass
    local origin=point+direction*.22
    chip.Position=origin
    track(chip,now,origin,direction*((prism and 13 or 7)+2*(i%4))+Vector3.yAxis*(10+1.5*(i%3)),
     .70+.055*(i%4),ground,Vector3.new(i*.83,i*1.47,i*.49),.85,
     (i==2 or i==7) and (owned and .64 or .39) or nil)
   end
   if #self.pieces<48 and clusterSize<=5 then
    local spark=part(parent,'Part','CrystalSplitSpark',prism and RED_HIGHLIGHT or r.baseColor:Lerp(WARM,.77))
    spark.Shape=Enum.PartType.Ball;spark.Material=Enum.Material.Neon
    spark.Size=Vector3.one*.10;spark.Position=point
    self.pieces[#self.pieces+1]={p=spark,at=now,duration=.19,burst=true,size=strength}
   end
  end
 end
 function self:cut(r,now,beat)
  r.cutPulse=r.cutPulseAt==now and math.max(r.cutPulse,beat) or beat
  r.cutPulseAt=now;self.tints[r]=true
  local hp=r.source:GetAttribute('HP') or 10
  local cap=math.max(1,(r.source:GetAttribute('MaxHP') or 10)-10)
  if hp>0 then
   local heat=1-math.clamp(((hp-10)/cap-.035)/.25,0,1)
   r.pressure=heat*heat
  end
 end
 function self:forget(r) self.tints[r]=nil;r.pressure=nil;r.finalLoad=nil end
 function self:applyTints(now)
  local player=Players.LocalPlayer
  local reduced=player and (player:GetAttribute('ReducedFlashing')==true or player:GetAttribute('ReducedEffects')==true or player:GetAttribute('MA_ReducedEffects')==true)
  for r in pairs(self.tints) do
   local view=r.view
   if not view.Parent or view.Transparency>=1 or not r.restColor then
    self:forget(r)
   else
    local age=r.flashAt and now-r.flashAt or math.huge
    local duration=r.flashDuration or .28
    local attack=math.clamp(age/.026,0,1)
    local initial=Feedback.impactWhite(age,duration)*(r.flashStrength or 0)*attack
    local afterglow=math.max(0,1-(now-(r.cutPulseAt or -math.huge))/.18)
    local pulse=(r.cutPulse or 0)*afterglow
    local white=math.max(initial*(reduced and .25 or 1),pulse*(reduced and .015 or .045))
    local pressure=(r.pressure or 0)*afterglow
    local load=r.finalLoad or 0
    white=math.max(white,load*(reduced and .045 or .14))
    local warm=math.max(pressure*(.16+.05*pulse),load*.46)
    view.Color=r.restColor:Lerp(WARM,warm*(reduced and .27 or 1)):Lerp(HOT,white)
    if age>=duration then r.flashAt=nil end
    if not r.flashAt and afterglow<=0 and not r.finalLoad then self:forget(r) end
   end
  end
  for r,blackAt in pairs(self.clusterTargets) do
   if not r.view.Parent or r.view.Transparency>=1 then self.clusterTargets[r]=nil
   elseif now>=blackAt then r.view.Color=CHAR end
  end
 end
 function self:react(r,now)
  local s,v=r.source,r.view
  self.clusterTargets[r]=s:GetAttribute('ClusterBlackAt')
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
   if not prism and not nomad and at<.21 and BeamVFX.near(v.Position,95) and (shot or not broken and (fractured or now>=(r.chipGate or 0))) then
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
    if shot or fractured then
     r.impactAt=now;r.kick=tilt*(heavy and .095 or projectile=='Dart' and .055 or .045)
    end
    self:chips(now,point,normal,r.baseColor,heavy and 6 or fractured and 5 or 3,false,nil,s:GetAttribute('GroundY'))
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
   local release=V.releaseAt(s,breakAt)
   if not r.restPose then r.lastBreakAt=breakAt;return end
   if now<release then
    local nearby=BeamVFX.near(v.Position,92)
    -- Finish the compression first, then hold the complete pose for 90 ms.
    -- The server can already dispatch the crew's next target during this beat.
    local load=math.clamp((now-breakAt)/math.max(.025,release-breakAt-.09),0,1)
    load=1-(1-load)^3
    if nearby and not prism and not nomad and now>=breakAt then
     r.finalLoad=load;self.tints[r]=true
     if not BeamVFX.reduced() and not V.reducedMotion() then
      r.breakSize=r.breakSize or v.Size
      local squash=r.breakSize*Vector3.new(1+.10*load,1-.27*load,1+.10*load)
      v.Size=squash;v.CFrame=r.restPose*CFrame.new(0,-(r.breakSize.Y-squash.Y)*.5,0)
     end
    end
   else
    r.lastBreakAt=breakAt
    if r.breakSize then v.Size=r.breakSize;r.breakSize=nil end
    if now-release<.38 and BeamVFX.near(r.restPose.Position,92) then split(self,r,now,prism,nomad) end
    v.Transparency=1;self:forget(r)
   end
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
  for _,e in ipairs(self.pieces) do e.p:Destroy() end;table.clear(self.pieces);table.clear(self.tints);table.clear(self.clusterTargets)
 end
 return self
end
return V
