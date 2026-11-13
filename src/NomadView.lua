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
local leases={NomadTracker=4,NomadCruiseTracker=4,NomadRocket=10,NomadBlast=4}

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

local function newScanner(parent,projectors,cruise)
 local folder=group(parent,cruise and 'NomadCruiseTracker' or 'NomadTracker')
 if not folder then return nil end
 local root=part(folder,'TrackerAnchor',BLUE,Vector3.one*.05)
 local scan={folder=folder,projectors=projectors,panes={},mounts={},seams={rail(folder,'Join'),rail(folder,'Join')}}
 for _,mount in ipairs(projectors:GetChildren()) do
  scan.mounts[mount.Name]={a=mount:FindFirstChild('A'),b=mount:FindFirstChild('B'),c=mount:FindFirstChild('C'),width=mount.Size.Z}
 end
 scan.glint=part(folder,'ReleaseGlint',GOLD,Vector3.one*.19,Enum.PartType.Ball)
 for i=1,3 do
  local pane={sheet=scanLine(root,true),edges={},feet={},ends={},contour={}}
  for j=1,3 do pane.edges[j]=scanLine(root,false) end
  for j=1,2 do
   pane.feet[j]=rail(folder,'FootRail')
   pane.ends[j]=part(folder,'FootGlint',ICE,Vector3.one*.17,Enum.PartType.Ball)
  end
  for j=1,8 do pane.contour[j]=rail(folder,'CrystalScanEdge') end
  scan.panes[i]=pane
 end
 return scan
end

local OUTER={'OuterLeft','OuterRight'}
local MIDDLE={'MidLeft','Bridge','MidRight'}
local REAR={'RearLeft','Bridge','RearRight'}
local JOINED={'OuterLeft','Bridge','OuterRight'}
local KEEL={'KeelLeft','KeelRight'}
-- Hard switches at the clip's visible cuts. Scale the sequence to the shot clock.
local function scanStage(q)
 if q<.269 then return OUTER end
 if q<.335 then return MIDDLE end
 if q<.470 then return REAR end
 if q<.592 then return JOINED end
 if q<.729 then return KEEL end
 if q<.773 then return KEEL,true end
 return nil
end

local function hideLine(line)
 line.main.Enabled=false
 if line.halo then line.halo.Enabled=false end
end

local function hideRail(line)
 line.core.Transparency=1;line.halo.Transparency=1
end

local function traceCrystal(pane,a,b,ground,params)
 local last
 for i=0,8 do
  local base=a:Lerp(b,i/8)
  local hit=workspace:Raycast(base+VERTICAL*10,-VERTICAL*10,params)
  local point=hit and hit.Instance:GetAttribute('ResourceId') and hit.Position.Y>ground+.16
   and hit.Position+VERTICAL*.08 or nil
  if i>0 then
   local edge=pane.contour[i]
   if point and last and math.abs(last.Y-point.Y)<2 then
    paintRail(edge,last,point,.068,.89)
   else
    paintRail(edge,base,base,0,0)
   end
  end
  last=point
 end
end

local function groundPoint(top,height)
 return Vector3.new(top.X,height,top.Z)
end

local function drawScanner(scan,stage,pins,ground,now,target,reduced,lowFlash)
 local trace
 if stage and not pins and not reduced and target and target.source.Parent
  and (stage~=scan.lastStage or now>=(scan.nextTrace or 0)) then
  scan.nextTrace=now+.071
  trace=RaycastParams.new();trace.FilterType=Enum.RaycastFilterType.Include
  trace.FilterDescendantsInstances={target.source.Parent}
 end
 local gain=lowFlash and .68 or 1
 local lastInside
 for i,pane in ipairs(scan.panes) do
  local mount=stage and scan.mounts[stage[i]]
  local a,b,c,topA,topB,across
  if mount and mount.a and mount.b then
   topA,topB=mount.a.WorldPosition,mount.b.WorldPosition
   a,b=groundPoint(topA,ground+.065),groundPoint(topB,ground+.065)
   across=(b-a).Unit
   if mount.c then c=groundPoint(mount.c.WorldPosition,ground+.065) end
  end
  if a and not pins then
   if reduced then hideLine(pane.sheet)
   else paintLine(pane.sheet,(a+b)*.5,(topA+topB)*.5,across,mount.width,gain*.84) end
   paintLine(pane.edges[1],a,topA,across,.052,gain*.9)
   paintLine(pane.edges[2],b,topB,across,.069,gain)
   if c and not reduced then paintLine(pane.edges[3],c,mount.c.WorldPosition,across,.035,gain*.70)
   else hideLine(pane.edges[3]) end
   paintRail(pane.feet[1],a,b,.062,gain*.87)
   if c then paintRail(pane.feet[2],b,c,.048,gain*.72) else hideRail(pane.feet[2]) end
   pane.ends[1].Position=a;pane.ends[1].Transparency=1-gain*.65
   pane.ends[2].Position=b;pane.ends[2].Transparency=1-gain*.86
  else
   hideLine(pane.sheet);hideLine(pane.edges[1]);hideLine(pane.edges[3])
   if b and pins then paintLine(pane.edges[2],b,topB,across,.043,gain*.67)
   else hideLine(pane.edges[2]) end
   for _,foot in ipairs(pane.feet) do hideRail(foot) end
   for _,glint in ipairs(pane.ends) do glint.Transparency=1 end
  end
  if a and trace then traceCrystal(pane,a,b,ground,trace)
  elseif not a or pins or reduced or not target or not target.source.Parent or stage~=scan.lastStage then
   for _,edge in ipairs(pane.contour) do hideRail(edge) end
  end
  if i>1 then
   local seam=scan.seams[i-1]
   if a and lastInside and stage==JOINED then paintRail(seam,lastInside,a,.046,gain*.60)
   else hideRail(seam) end
  end
  lastInside=i==1 and a or b
 end
 scan.lastStage=stage
end

function N.clearCruise(drone)
 if not drone.nomadCruise then return end
 drone.nomadCruise.folder:Destroy();drone.nomadCruise=nil
end

function N.cruise(drone,now,world)
 local camera=workspace.CurrentCamera
 local state=drone.source:GetAttribute('State')
 local shot=drone.shotReceipt
 local contact=shot and shot.Parent and shot:GetAttribute('ContactAt')
 local active=shot and shot.Parent and shot:GetAttribute('Shape')=='Nomad' and (not contact or now<contact+.50)
 local position=drone.view:GetPivot().Position
 if not camera or active or state=='Destroyed' or state=='Reprinting' or state=='Docked' or state=='Charging'
  or not BeamVFX.near(position,205) then N.clearCruise(drone);return end
 local scan=drone.nomadCruise
 if not scan then
  scan=newScanner(camera,drone.nomadProjectors,true)
  if not scan then return end
  drone.nomadCruise=scan
  local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.RespectCanCollide=true
  query.FilterDescendantsInstances={workspace.Terrain,world:FindFirstChild('Map')}
  scan.groundQuery=query
 end
 if now>=(scan.nextGround or 0) then
  scan.nextGround=now+.09
  local hit=workspace:Raycast(position,-VERTICAL*110,scan.groundQuery)
  scan.ground=hit and hit.Position.Y or position.Y-(drone.source:GetAttribute('FlightHeight') or 45)
 end
 local slot=drone.source:GetAttribute('FormationSlot') or 1
 local q=((now+slot*.39)/6.30)%.773
 local stage,pins=scanStage(q)
 local player=game:GetService('Players').LocalPlayer
 local reduced=BeamVFX.reduced()
 drawScanner(scan,stage,pins,math.min(scan.ground,position.Y-3.5),now,nil,reduced,
  reduced or (player and player:GetAttribute('ReducedFlashing')==true))
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
 local scale=radius/13
 local blast={root=folder,skirt={},cap={},capAt=at+.25,untilAt=at+BLAST_TAIL,reduced=reduced}
 blast.stem=plumeEmitter(root,'RisingFireAndSmoke',VERTICAL*.58,nil,STEM,scale)
 if not lowFlash then
  blast.fire=plumeEmitter(root,'ImpactFireball',VERTICAL*.80,nil,FLASH,scale)
  local light=Instance.new('PointLight');light.Name='ImpactLight';light.Color=HEAT
  light.Range=math.min(48,radius*3.3);light.Brightness=0;light.Parent=root;blast.light=light
 end
 local count=reduced and 4 or 8
 for i=1,count do
  local a=(i-1)*math.pi*2/count
  local radial=Vector3.new(math.cos(a),0,math.sin(a))
  local direction=(radial+VERTICAL*.22).Unit
  blast.skirt[i]=plumeEmitter(root,'GroundDust',radial*.94+VERTICAL*.24,direction,SKIRT,scale)
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

function N.step(r,node,now,from,to,age,windup,progress,drone,target,audio,onImpact,onFlash)
 local camera=workspace.CurrentCamera
 local ground=node:GetAttribute('ScanGround') or to.Y-1
 local contactAt=node:GetAttribute('ContactAt')
 local landed=contactAt and now>=contactAt
 local near=camera and BeamVFX.near(Vector3.new(to.X,ground,to.Z),150)
 local player=game:GetService('Players').LocalPlayer
 local reduced=BeamVFX.reduced()
 local steady=game:GetService('GuiService').ReducedMotionEnabled or (player and player:GetAttribute('ReducedMotion')==true)
 local lowFlash=reduced or (player and player:GetAttribute('ReducedFlashing')==true)
 local projectors=drone and drone.nomadProjectors
 local muzzle=drone and drone.shotMuzzle
 if muzzle and (muzzle.WorldPosition-from).Magnitude>2.5 then muzzle=nil end
 if not landed and age>=0 and age<windup and near then
  local q=age/windup
  local stage,pins=scanStage(q)
  if projectors and projectors.Parent then
   N.clearCruise(drone)
   if r.scan and r.scan.projectors~=projectors then r.scan.folder:Destroy();r.scan=nil end
   r.scan=r.scan or newScanner(camera,projectors)
   if r.scan then
    drawScanner(r.scan,stage,pins,ground,now,target,reduced,lowFlash)
    local glint=r.scan.glint
    if muzzle and q>=.916 then
     local rise=smooth((q-.916)/.026)
     glint.Position=muzzle.WorldPosition
     glint.Transparency=1-(lowFlash and .49 or .85)*rise
    else glint.Transparency=1 end
   end
  elseif r.scan then r.scan.folder:Destroy();r.scan=nil end
  if audio and audio.setLoop and stage and (node:GetAttribute('PausedAt') or 0)<=0 then
   audio:setLoop(node,'orbital_charge',Vector3.new(to.X,ground+4,to.Z),pins and .24 or .23+.42*smooth(q),.58+.52*q)
  elseif audio and audio.stopLoop then audio:stopLoop(node,stage==nil) end
 else
  if r.scan then r.scan.folder:Destroy();r.scan=nil end
  if audio and audio.stopLoop then audio:stopLoop(node) end
 end
 if not landed and progress>=0 and progress<1.12 and near and not (r.rocket and r.rocket.tailAt) then
  if not r.fired then
   r.fired=true
   r.launchFrom=muzzle and muzzle.WorldPosition or from
   if audio and progress<.20 then audio:play('coil_fire',r.launchFrom,{pitch=1.32,level=.79}) end
  end
  r.rocket=r.rocket or newRocket(camera,reduced)
  if r.rocket then drawRocket(r.rocket,r.launchFrom,to,math.min(progress,1),steady) end
 elseif r.rocket then
  stopRocket(r.rocket,now)
  if now-r.rocket.tailAt>=.25 then r.rocket.root:Destroy();r.rocket=nil end
 end
 if not landed then return end
 local ageSince=now-contactAt
 local floor=node:GetAttribute('BlastGround')
 if typeof(floor)~='Vector3' then return end
 local radius=node:GetAttribute('BlastRadius') or 13
 if not r.impacted then
  r.impacted=true
  if ageSince<.20 and near then
   RoleVisuals.setTime(contactAt)
   RoleVisuals.Pulse(floor+VERTICAL*.10,GOLD,1.2,radius*2.64,.67)
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
  if now-shatterAt<.24 and near then
   RoleVisuals.setTime(shatterAt)
   RoleVisuals.Pulse(floor+VERTICAL*.18,COPPER,radius*.46,radius*3.06,.82)
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
