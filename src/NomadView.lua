-- Local rendering from one server-clock shot receipt. All geometry is cosmetic.
local N={}
local DEEP=Color3.fromRGB(38,94,233)
local BLUE=Color3.fromRGB(65,150,255)
local CYAN=Color3.fromRGB(113,220,255)
local ICE=Color3.fromRGB(220,248,255)
local AMBER=Color3.fromRGB(255,142,68)
local GOLD=Color3.fromRGB(255,218,146)
local VERTICAL=Vector3.yAxis
local BLAST_TAIL=4.8
local live={}
local leases={NomadTracker=4,NomadRocket=10,NomadBlast=4}

local function smooth(t)
 t=math.clamp(t,0,1)
 return t*t*(3-2*t)
end

local function part(parent,name,color,size,shape)
 local value=Instance.new('Part')
 value.Name=name;value.Color=color;value.Size=size;value.Shape=shape or Enum.PartType.Block
 value.Material=Enum.Material.Neon;value.Transparency=1;value.Anchored=true;value.CastShadow=false
 value.CanCollide=false;value.CanTouch=false;value.CanQuery=false;value.Parent=parent
 return value
end

local function group(parent,name)
 if (live[name] or 0)>=leases[name] then return nil end
 local value=Instance.new('Folder');value.Name=name;value.Parent=parent
 live[name]=(live[name] or 0)+1
 value.Destroying:Connect(function() live[name]-=1 end)
 return value
end

local function beam(parent,name,a,b,colors,alpha,faceCamera)
 local value=Instance.new('Beam')
 value.Name=name;value.Attachment0=a;value.Attachment1=b;value.FaceCamera=faceCamera
 value.LightEmission=1;value.LightInfluence=0;value.Color=colors;value.Transparency=alpha
 value.Parent=parent
 return value
end

local function falloff(foot,middle,sky)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,foot),NumberSequenceKeypoint.new(.42,middle),NumberSequenceKeypoint.new(1,sky)})
end
local function fadeCurves(foot,middle,sky)
 local curves={}
 for i=0,16 do
  local alpha=i/16
  curves[i]=falloff(1-(1-foot)*alpha,1-(1-middle)*alpha,1-(1-sky)*alpha)
 end
 return curves
end
local SHEET_ALPHA=fadeCurves(.79,.91,.87)
local CORE_ALPHA=fadeCurves(.10,.46,.22)
local HALO_ALPHA=fadeCurves(.50,.79,.60)
local SHEET_COLOR=ColorSequence.new(BLUE,DEEP)
local CORE_COLOR=ColorSequence.new(ICE,CYAN)
local HALO_COLOR=ColorSequence.new(BLUE,DEEP)

local function scanLine(root,isSheet)
 local a=Instance.new('Attachment');a.Parent=root
 local b=Instance.new('Attachment');b.Parent=root
 local alpha=isSheet and SHEET_ALPHA or CORE_ALPHA
 local main=beam(root,isSheet and 'BlueCurtain' or 'IceFilament',a,b,isSheet and SHEET_COLOR or CORE_COLOR,alpha[0],not isSheet)
 if isSheet then main.LightEmission=.42 else main.ZOffset=.02 end
 local halo=not isSheet and beam(root,'CobaltHalo',a,b,HALO_COLOR,HALO_ALPHA[0],true) or nil
 return {a=a,b=b,main=main,halo=halo,alpha=alpha}
end

local function paintLine(line,foot,sky,across,width,gain)
 line.a.WorldCFrame=CFrame.fromMatrix(foot,VERTICAL,across)
 line.b.WorldCFrame=CFrame.fromMatrix(sky,VERTICAL,across)
 line.main.Width0=width;line.main.Width1=width
 local grade=math.clamp(math.round(gain*16),0,16)
 line.main.Transparency=line.alpha[grade]
 line.main.Enabled=grade>0
 line.main.Brightness=.82+.63*gain
 if line.halo then
  line.halo.Width0=width*5;line.halo.Width1=width*5
  line.halo.Transparency=HALO_ALPHA[grade];line.halo.Enabled=grade>0
 end
end

local function rail(parent,name)
 return {core=part(parent,name,ICE,Vector3.one*.08),halo=part(parent,name..'Halo',BLUE,Vector3.one*.08)}
end

local function paintRail(line,a,b,width,opacity)
 local delta=b-a
 if opacity<=.01 or delta.Magnitude<=.01 then
  line.core.Transparency=1;line.halo.Transparency=1
  return
 end
 local pose=CFrame.lookAt(a+delta*.5,b)
 line.core.CFrame=pose;line.halo.CFrame=pose
 line.core.Size=Vector3.new(width,width,delta.Magnitude)
 line.halo.Size=Vector3.new(width*4,width*2.6,delta.Magnitude)
 line.core.Transparency=1-opacity;line.halo.Transparency=1-opacity*.27
end

local function newScanner(parent)
 local folder=group(parent,'NomadTracker')
 if not folder then return nil end
 local root=part(folder,'TrackerAnchor',BLUE,Vector3.one*.05)
 local scan={folder=folder,panes={},seams={rail(folder,'Join'),rail(folder,'Join')}}
 for i=1,3 do
  local pane={sheet=scanLine(root,true),edges={},feet={},ends={}}
  for j=1,3 do pane.edges[j]=scanLine(root,false) end
  for j=1,2 do
   pane.feet[j]=rail(folder,'FootRail')
   pane.ends[j]=part(folder,'FootGlint',ICE,Vector3.one*.17,Enum.PartType.Ball)
  end
  scan.panes[i]=pane
 end
 return scan
end

-- Original wing, ring and keel slits from 44f061c, measured at the fitted hull scale.
-- The off-screen patrol carries this same layout over the field at its old visible height.
local PROJECTOR_SCALE=1.4885967
local SCAN_HEIGHT=38
local ROCKET_REVEAL_HEIGHT=34
local KEEL_OFFSET=.96*PROJECTOR_SCALE
local projectors={}
local function projector(name,ax,ay,az,bx,bz,returnDepth)
 local a=Vector3.new(ax,ay-.048,az)*PROJECTOR_SCALE
 local b=Vector3.new(bx,ay-.048,bz)*PROJECTOR_SCALE
 local delta=b-a
 local c=returnDepth and b+delta.Unit:Cross(VERTICAL)*(returnDepth*PROJECTOR_SCALE)
 projectors[name]={a=a,b=b,c=c,width=delta.Magnitude}
end
projector('OuterLeft',-1.23,-.14,.11,-4.42,.61,-.35)
projector('OuterRight',1.23,-.14,.11,4.42,.61,-.35)
projector('MidLeft',-3.85,-.17,.24,-1.17,-.12,.48)
projector('Bridge',-1.22,-.18,.48,1.22,.48,.42)
projector('MidRight',1.17,-.17,-.12,3.85,.24,-.48)
projector('RearLeft',-3.85,-.17,.70,-1.17,.34,.48)
projector('RearRight',1.17,-.17,.34,3.85,.70,-.48)
projector('KeelLeft',-.76,-.43,-.47,-.19,-.96)
projector('KeelRight',.76,-.43,-.47,.19,-.96)

local OUTER={'OuterLeft','OuterRight'}
local MIDDLE={'MidLeft','Bridge','MidRight'}
local REAR={'RearLeft','Bridge','RearRight'}
local JOINED={'OuterLeft','Bridge','OuterRight'}
local KEEL={'KeelLeft','KeelRight'}
local SCAN_STAGES={
 {at=0,banks=OUTER,pitch=.64,gain=.64},
 {at=.269,banks=MIDDLE,pitch=.82,gain=.82},
 {at=.335,banks=REAR,pitch=.70,gain=.70},
 {at=.470,banks=JOINED,pitch=1.04,gain=.90},
 {at=.592,banks=KEEL,pitch=1.21,gain=1},
 {at=.729,banks=KEEL,pitch=1.34,gain=.31,pins=true},
}

local BLACKOUT={}
local function scanStage(q)
 if q>=Feel.NomadBeamCutoff then return BLACKOUT,#SCAN_STAGES+1 end
 for i=#SCAN_STAGES,1,-1 do
  if q>=SCAN_STAGES[i].at then return SCAN_STAGES[i],i end
 end
end

-- The old cruise clock is independent of travel distance. Keep cycling while
-- approaching, then play the keel -> two filaments -> blackout ending once.
local SCAN_SECONDS=6.30
local function patternAt(age,windup)
 local cutoff=windup-1.8
 if age>=cutoff then return BLACKOUT,#SCAN_STAGES+1,age-cutoff end
 local closing=SCAN_STAGES[5].at
 local closeAt=math.max(0,cutoff-(Feel.NomadBeamCutoff-closing)*SCAN_SECONDS)
 local q,phaseAge
 if age>=closeAt then
  phaseAge=age-closeAt
  q=closing+phaseAge/SCAN_SECONDS
 else
  phaseAge=age%(Feel.NomadBeamCutoff*SCAN_SECONDS)
  q=phaseAge/SCAN_SECONDS
 end
 local stage,index=scanStage(q)
 local stageAge=age>=closeAt and phaseAge-(stage.at-closing)*SCAN_SECONDS
  or phaseAge-stage.at*SCAN_SECONDS
 return stage,index,stageAge
end

local function hideLine(line)
 line.main.Enabled=false
 if line.halo then line.halo.Enabled=false end
end

local function hideRail(line)
 line.core.Transparency=1;line.halo.Transparency=1
end

local function groundPoint(top,height)
 return Vector3.new(top.X,height,top.Z)
end

local function drawScanner(scan,stage,center,bearing,ground,reduced,lowFlash)
 local virtualHull=groundPoint(center,ground+SCAN_HEIGHT)-bearing*KEEL_OFFSET
 local frame=CFrame.lookAt(virtualHull,virtualHull+bearing)
 local floor=ground+.065
 local gain=lowFlash and .68 or 1
 local previous
 for i,pane in ipairs(scan.panes) do
  local mount=projectors[stage.banks[i]]
  local a,b,topA,topB,across
  if mount then
   topA,topB=frame:PointToWorldSpace(mount.a),frame:PointToWorldSpace(mount.b)
   a,b=groundPoint(topA,floor),groundPoint(topB,floor)
   across=(b-a).Unit
  end
  if mount and not stage.pins then
   if reduced then hideLine(pane.sheet)
   else
    paintLine(pane.sheet,(a+b)*.5,(topA+topB)*.5,across,mount.width,gain*.84)
   end
   paintLine(pane.edges[1],a,topA,across,.052,gain*.9)
   paintLine(pane.edges[2],b,topB,across,.069,gain)
   paintRail(pane.feet[1],a,b,.062,gain*.87)
   local topC=mount.c and frame:PointToWorldSpace(mount.c)
   local c=topC and groundPoint(topC,floor)
   if c and not reduced then paintLine(pane.edges[3],c,topC,across,.035,gain*.70)
   else hideLine(pane.edges[3]) end
   if c then paintRail(pane.feet[2],b,c,.048,gain*.72) else hideRail(pane.feet[2]) end
   pane.ends[1].Position=a;pane.ends[1].Transparency=1-gain*.65
   pane.ends[2].Position=b;pane.ends[2].Transparency=1-gain*.86
  else
   hideLine(pane.sheet)
   hideLine(pane.edges[1]);hideLine(pane.edges[3])
   if b and stage.pins then paintLine(pane.edges[2],b,topB,across,.043,gain*.67)
   else hideLine(pane.edges[2]) end
   for _,foot in ipairs(pane.feet) do hideRail(foot) end
   for _,glint in ipairs(pane.ends) do glint.Transparency=1 end
  end
  if i>1 then
   local seam=scan.seams[i-1]
   if a and previous and stage.banks==JOINED then paintRail(seam,previous,a,.046,gain*.60)
   else hideRail(seam) end
  end
  previous=i==1 and a or b
 end
end

local function newRocket(parent,reduced)
 local root=group(parent,'NomadRocket')
 if not root then return nil end
 local body=part(root,'Capsule',Color3.fromRGB(234,97,97),Vector3.new(.66,.38,.38),Enum.PartType.Cylinder)
 body.Material=Enum.Material.SmoothPlastic
 local nose=part(root,'IvoryNose',ICE,Vector3.new(.43,.38,.38),Enum.PartType.Ball)
 nose.Material=Enum.Material.SmoothPlastic
 local flame=part(root,'AmberTail',GOLD,Vector3.new(.42,.19,.19),Enum.PartType.Ball)
 local fins={}
 for i=1,4 do fins[i]=part(root,'PetalFin',Color3.fromRGB(177,55,89),Vector3.new(.31,.22,.07));fins[i].Material=Enum.Material.SmoothPlastic end
 local trail
 if not reduced then
  local a=Instance.new('Attachment');a.Position=Vector3.new(-.28,-.09,0);a.Parent=body
  local b=Instance.new('Attachment');b.Position=Vector3.new(-.28,.09,0);b.Parent=body
  trail=Instance.new('Trail');trail.Name='RocketEmber';trail.Attachment0=a;trail.Attachment1=b
  trail.Color=ColorSequence.new(GOLD,AMBER);trail.Transparency=NumberSequence.new(.16,1)
  trail.WidthScale=NumberSequence.new(1,0);trail.LightEmission=1;trail.FaceCamera=true
  trail.Lifetime=.24;trail.MinLength=.04;trail.Parent=body
 end
 return {root=root,body=body,nose=nose,flame=flame,fins=fins,trail=trail}
end

local function drawRocket(rocket,from,to,t,steady)
 local delta=to-from
 local direction=delta.Unit
 local u=t*(.28+.72*t)
 local side=direction:Cross(Vector3.xAxis).Unit
 local drift=steady and 0 or math.sin(t*math.pi*2)*math.sin(t*math.pi)*.36
 local position=from+delta*u+side*drift
 local pose=CFrame.fromMatrix(position,direction,side)
 rocket.body.CFrame=pose;rocket.body.Transparency=0
 rocket.nose.CFrame=pose*CFrame.new(.31,0,0);rocket.nose.Transparency=0
 rocket.flame.CFrame=pose*CFrame.new(-.46,0,0);rocket.flame.Transparency=.15
 for i,fin in ipairs(rocket.fins) do
  fin.CFrame=pose*CFrame.Angles(i*math.pi*.5+(steady and 0 or t*.7),0,0)*CFrame.new(-.25,.20,0)*CFrame.Angles(0,0,-.28)
  fin.Transparency=0
 end
end

local function stopRocket(rocket,now)
 if rocket.tailAt then return end
 rocket.tailAt=now
 for _,piece in ipairs(rocket.root:GetChildren()) do piece.Transparency=1 end
 if rocket.trail then rocket.trail.Enabled=false end
end

local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SOOT=Color3.fromRGB(49,44,48)
local COPPER=Color3.fromRGB(191,80,41)
local ASH=Color3.fromRGB(109,92,86)
local HEAT=Color3.fromRGB(255,248,217)
local function cooling(mid,last)
 return ColorSequence.new({ColorSequenceKeypoint.new(0,HEAT),ColorSequenceKeypoint.new(.10,GOLD),
  ColorSequenceKeypoint.new(.36,mid),ColorSequenceKeypoint.new(1,last)})
end
local function smokeTone(first,middle)
 return ColorSequence.new({ColorSequenceKeypoint.new(0,first),ColorSequenceKeypoint.new(.18,middle),
  ColorSequenceKeypoint.new(.61,ASH),ColorSequenceKeypoint.new(1,SOOT)})
end
local function billowOpacity(mid,falloff)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,.92),NumberSequenceKeypoint.new(.13,mid),
  NumberSequenceKeypoint.new(.62,falloff),NumberSequenceKeypoint.new(1,1)})
end
local STEM={sizes={2.8,8.8,10.4},life=NumberRange.new(1.42,2.45),speed=NumberRange.new(19,28),
 drag=1.33,rise=3.6,spread=Vector2.new(13,15),color=cooling(COPPER,SOOT),alpha=billowOpacity(.27,.48),emission=.19}
local CAP={sizes={4.5,12.9,15.5},life=NumberRange.new(1.82,3.25),speed=NumberRange.new(12,21),
 drag=2.2,rise=2.6,spread=Vector2.new(21,16),color=smokeTone(Color3.fromRGB(204,117,66),Color3.fromRGB(132,76,53)),
 alpha=billowOpacity(.32,.52),emission=.035}
local SKIRT={sizes={1.8,5.8,8.9},life=NumberRange.new(.84,1.78),speed=NumberRange.new(27,37),
 drag=2.25,rise=1.1,spread=Vector2.new(19,9),color=smokeTone(Color3.fromRGB(168,133,103),ASH),
 alpha=billowOpacity(.44,.63),emission=.03}
local FLASH={sizes={2.2,12.1,14.3},life=NumberRange.new(.27,.51),speed=NumberRange.new(10,17),
 drag=1.9,rise=1.7,spread=Vector2.new(66,66),color=cooling(AMBER,COPPER),alpha=billowOpacity(.10,.55),emission=.92}

local function plumeEmitter(root,name,offset,direction,spec,scale)
 local anchor=Instance.new('Attachment')
 anchor.CFrame=direction and CFrame.lookAt(offset,offset+direction) or CFrame.new(offset)
 anchor.Parent=root
 local emitter=Instance.new('ParticleEmitter');emitter.Name=name;emitter.Texture=SMOKE
 emitter.Enabled=false;emitter.Rate=0;emitter.LockedToPart=false
 emitter.Orientation=Enum.ParticleOrientation.FacingCamera
 emitter.EmissionDirection=direction and Enum.NormalId.Front or Enum.NormalId.Top
 emitter.Lifetime=spec.life;emitter.Speed=spec.speed
 emitter.Drag=spec.drag;emitter.Acceleration=VERTICAL*spec.rise
 emitter.SpreadAngle=spec.spread
 emitter.Rotation=NumberRange.new(0,360);emitter.RotSpeed=NumberRange.new(-39,39)
 emitter.Color=spec.color;emitter.Transparency=spec.alpha
 local sizes=spec.sizes
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,sizes[1]*scale),
  NumberSequenceKeypoint.new(.27,sizes[2]*scale,sizes[2]*scale*.21),NumberSequenceKeypoint.new(1,sizes[3]*scale)})
 emitter.LightEmission=spec.emission;emitter.LightInfluence=.18
 emitter.Parent=anchor
 return emitter
end

local function newBlast(parent,ground,radius,reduced,lowFlash,at)
 local folder=group(parent,'NomadBlast')
 if not folder then return nil end
 local root=part(folder,'PlumeOrigin',HEAT,Vector3.one*.05)
 root.Position=ground+VERTICAL*.24
 local scale=math.clamp(radius/13,1,2.8)
 local blast={root=folder,skirt={},cap={},capAt=at+.25,untilAt=at+BLAST_TAIL,reduced=reduced}
 blast.stem=plumeEmitter(root,'RisingFireAndSmoke',VERTICAL*.58,nil,STEM,scale)
 if not lowFlash then
  blast.fire=plumeEmitter(root,'ImpactFireball',VERTICAL*.80,nil,FLASH,scale)
  local light=Instance.new('PointLight');light.Name='ImpactLight';light.Color=HEAT
  light.Range=math.min(48,radius*3.3);light.Brightness=0;light.Parent=root;blast.light=light
 end
 local count=reduced and 4 or 8
 local reach=math.clamp(radius/20,1,1.45)
 for i=1,count do
  local a=(i-1)*math.pi*2/count
  local radial=Vector3.new(math.cos(a),0,math.sin(a))
  local direction=(radial+VERTICAL*.22).Unit
  blast.skirt[i]=plumeEmitter(root,'GroundDust',radial*.94+VERTICAL*.24,direction,SKIRT,scale)
  blast.skirt[i].Speed=NumberRange.new(SKIRT.speed.Min*reach,SKIRT.speed.Max*reach)
  blast.cap[i]=plumeEmitter(root,'RollingSmokeCap',radial*(1.7*scale)+VERTICAL*((10.8+(i%3)*.97)*scale),direction,CAP,scale)
 end
 if not reduced then
  local sparks=Instance.new('ParticleEmitter');sparks.Name='HotMineralSparks';sparks.Rate=0;sparks.Enabled=false
  EnergyDisc.configure(sparks,.54,.16,.8,.22)
  sparks.Color=ColorSequence.new(GOLD,AMBER)
  sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(69,69)
  sparks.Lifetime=NumberRange.new(.44,1.15);sparks.Speed=NumberRange.new(19,34)
  sparks.Drag=2.1;sparks.Acceleration=-VERTICAL*28;sparks.Parent=root;blast.sparks=sparks
 end
 return blast
end

local function startBlast(blast)
 if blast.fire then blast.fire:Emit(14) end
 blast.stem:Emit(blast.reduced and 9 or 18)
 for _,emitter in ipairs(blast.skirt) do emitter:Emit(blast.reduced and 3 or 5) end
 if blast.sparks then blast.sparks:Emit(18) end
end

local function stepBlast(blast,at,now)
 if blast.light then
  local glow=math.max(0,1-(now-at)/.24)^2
  blast.light.Brightness=glow*9
  blast.light.Enabled=glow>.01
 end
 if not blast.rolled and now>=blast.capAt then
  blast.rolled=true
  for _,emitter in ipairs(blast.cap) do emitter:Emit(blast.reduced and 3 or 5) end
  blast.stem:Emit(blast.reduced and 4 or 8)
 end
end

function N.clear(r)
 if not (r.scan or r.rocket or r.blast) then return end
 for _,key in ipairs({'scan','rocket','blast'}) do
  local value=r[key]
  if value then (value.folder or value.root):Destroy();r[key]=nil end
 end
end

function N.step(r,node,now,from,to,age,windup,progress,audio,onImpact,onFlash)
 local camera=workspace.CurrentCamera
 local contactAt=node:GetAttribute('ContactAt')
 local landed=contactAt and now>=contactAt
 local radius=node:GetAttribute('BlastRadius') or 24
 local waveRadius=math.min(54,radius)
 local near=camera and BeamVFX.near(to,math.max(160,120+radius))
 local player=game:GetService('Players').LocalPlayer
 local reduced=BeamVFX.reduced()
 local steady=game:GetService('GuiService').ReducedMotionEnabled or (player and player:GetAttribute('ReducedMotion')==true)
 local lowFlash=reduced or (player and player:GetAttribute('ReducedFlashing')==true)
 local scanFrom=node:GetAttribute('ScanFrom')
 local scanning=not landed and age>=0 and age<windup and typeof(scanFrom)=='Vector3'
 local airborne=not landed and progress>=0 and progress<1.12
 local paused=(node:GetAttribute('PausedAt') or 0)>0
 if scanning and near then
  local q=Feel.nomadScanProgress(age,windup)
  local stage,index,stageAge=patternAt(age,windup)
  -- Quarry fields share a long X axis. Keep the wide projector banks across
  -- that axis; side-entry travel must not turn the curtains edge-on.
  local bearing=Vector3.zAxis
  local center=Feel.nomadPass(scanFrom,from,q)
  local soundPoint=Vector3.new(center.X,to.Y+5,center.Z)
  if stage.banks then
   r.scan=r.scan or newScanner(camera)
   if r.scan then drawScanner(r.scan,stage,center,bearing,to.Y,reduced,lowFlash) end
  elseif r.scan then r.scan.folder:Destroy();r.scan=nil end
  if audio and index~=r.stage and not paused and stageAge<.16 then
   if stage.banks then audio:play('nomad_scan_cut',soundPoint,{level=index==1 and 1.1 or .83,pitch=stage.pitch})
   else audio:play('nomad_scan_off',soundPoint) end
  end
  r.stage=index
  if audio and audio.setLoop and stage.banks and not paused then
   local pulse=math.sin(age*math.pi*2*6)
   audio:setLoop(node,'nomad_scan',soundPoint,stage.gain*(.86+.14*pulse),stage.pitch*(1+.045*pulse))
  elseif audio and audio.stopLoop then audio:stopLoop(node,true) end
 else
  if r.scan then r.scan.folder:Destroy();r.scan=nil end
  if not (airborne and near and not paused) and audio and audio.stopLoop then audio:stopLoop(node,true) end
 end
 if airborne and near and not (r.rocket and r.rocket.tailAt) then
  local t=math.clamp(progress,0,1)
  local start=to:Lerp(from,math.min(1,ROCKET_REVEAL_HEIGHT/(from-to).Magnitude))
  if not r.fired then
   r.fired=true
   if not paused and audio and progress<.12 then audio:play('nomad_release',start) end
  end
  if not r.screeched and progress>=.10 then
   r.screeched=true
   if not paused and audio and progress<.24 then audio:play('nomad_screech',start) end
  end
  if not paused and audio and audio.setLoop then
   local audible=start:Lerp(to,t*(.28+.72*t))+VERTICAL*3
   audio:setLoop(node,'nomad_descent',audible,.34+.94*t,1.34-.46*t)
  end
  r.rocket=r.rocket or newRocket(camera,reduced)
  if r.rocket then drawRocket(r.rocket,start,to,t,steady) end
 elseif r.rocket then
  stopRocket(r.rocket,now)
  if now-r.rocket.tailAt>=.25 then r.rocket.root:Destroy();r.rocket=nil end
 end
 if not landed then return end
 local ageSince=now-contactAt
 local floor=node:GetAttribute('BlastGround')
 if typeof(floor)~='Vector3' then return end
 if not r.impacted then
  r.impacted=true
  if ageSince<.20 and near then
   RoleVisuals.setTime(contactAt)
   RoleVisuals.Pulse(floor+VERTICAL*.10,GOLD,1.2,waveRadius*2.1,.67,VERTICAL,2.45)
   if audio then audio:play('nomad_impact',floor) end
   if onFlash and not lowFlash then onFlash(floor,contactAt) end
   if onImpact and not steady then onImpact(floor,2.7,contactAt) end
  end
 end
 if not r.blast and not r.plumeStarted and ageSince<.85 and near then
  r.blast=newBlast(camera,floor,radius,reduced,lowFlash,contactAt)
  if r.blast then
   r.plumeStarted=true
   if ageSince<.22 then startBlast(r.blast) end
  end
 end
 if r.blast then
  if now<r.blast.untilAt then stepBlast(r.blast,contactAt,now)
  else r.blast.root:Destroy();r.blast=nil end
 end
 local shatterAt=node:GetAttribute('ShatterAt')
 if shatterAt and now>=shatterAt and not r.shattered then
  r.shattered=true
  RoleVisuals.Crater(floor,math.min(34,radius*.96),'Nomad',shatterAt)
  if now-shatterAt<.24 and near then
   RoleVisuals.setTime(shatterAt)
   RoleVisuals.Pulse(floor+VERTICAL*.18,COPPER,waveRadius*.46,waveRadius*2.24,.82,VERTICAL,2.2)
   if r.blast then
    for _,emitter in ipairs(r.blast.skirt) do emitter:Emit(reduced and 2 or 3) end
    if r.blast.sparks then r.blast.sparks:Emit(20) end
   end
   if audio then audio:play('nomad_shatter',floor) end
   if onImpact and not steady then onImpact(floor,4.0,shatterAt) end
  end
 end
end

function N.detach(r,now)
 if r.scan then r.scan.folder:Destroy();r.scan=nil end
 if r.rocket then
  stopRocket(r.rocket,now)
  if now-r.rocket.tailAt<.25 then return false end
 end
 if r.blast and now<r.blast.untilAt then
  if r.blast.light then r.blast.light.Enabled=false end
  return false
 end
 N.clear(r)
 return true
end
return N
