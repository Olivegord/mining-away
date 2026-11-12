-- Local rendering from one server-clock shot receipt. All geometry is cosmetic.
local N={}
local DEEP=Color3.fromRGB(38,94,233)
local BLUE=Color3.fromRGB(65,150,255)
local CYAN=Color3.fromRGB(113,220,255)
local ICE=Color3.fromRGB(220,248,255)
local AMBER=Color3.fromRGB(255,142,68)
local GOLD=Color3.fromRGB(255,218,146)
local CLAY=Color3.fromRGB(111,69,72)
local VERTICAL=Vector3.yAxis
local CLOUD_TIME=2.05
local live={}
local leases={NomadTracker=4,NomadRocket=10,NomadMushroom=8}

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

local function newScanner(parent,projectors)
 local folder=group(parent,'NomadTracker')
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

local function newCloud(parent,ground,reduced)
 local root=group(parent,'NomadMushroom')
 if not root then return nil end
 local cap,stem={},{}
 for i=1,reduced and 5 or 8 do
  cap[i]=part(root,'CloudCap',AMBER,Vector3.one*.1,Enum.PartType.Ball)
  cap[i].Material=Enum.Material.SmoothPlastic
 end
 for i=1,3 do
  stem[i]=part(root,'CloudStem',AMBER,Vector3.one*.1,Enum.PartType.Ball)
  stem[i].Material=Enum.Material.SmoothPlastic
 end
 local heart=part(root,'BlastHeart',GOLD,Vector3.one*.1,Enum.PartType.Ball)
 heart.Position=ground+VERTICAL*.42
 local light=Instance.new('PointLight');light.Color=AMBER;light.Range=13;light.Brightness=0;light.Parent=heart
 return {root=root,cap=cap,stem=stem,heart=heart,light=light}
end

local function drawCloud(cloud,ground,age,reduced,lowFlash)
 local bloom=1-math.exp(-age*8.2)
 local rise=smooth(age/.70)
 local cool=smooth((age-.13)/.86)
 local fade=smooth((age-.66)/(CLOUD_TIME-.66))
 local capHeight=.66+2.36*rise+.7*smooth((age-.65)/1.4)
 local stemHeight=.45+2.42*rise
 local core=math.max(0,1-age/.25)^2
 cloud.light.Brightness=not lowFlash and not reduced and 2.35*core or 0
 cloud.heart.Transparency=1-core*(lowFlash and .28 or .76)
 cloud.heart.Size=Vector3.new(2.7,1.65,2.7)*(.13+.87*bloom)
 for i,puff in ipairs(cloud.stem) do
  local step=i/3
  puff.Position=ground+Vector3.new((step-.5)*.28,.18+stemHeight*step,0)
  puff.Size=Vector3.new(1.32-step*.42,.76+step*.49,1.32-step*.42)*(.2+bloom)
  puff.Color=GOLD:Lerp(CLAY,cool*.91)
  puff.Transparency=.24+fade*.76
 end
 for i,puff in ipairs(cloud.cap) do
  local angle=i*math.pi*2/(#cloud.cap-1)
  local radius=i==1 and 0 or (.42+1.06*bloom)*(.95+.14*math.sin(i*2.3))
  puff.Position=ground+Vector3.new(radius*math.cos(angle),capHeight+(i==1 and .40 or .21*math.sin(i*1.9)),radius*math.sin(angle))
  puff.Size=Vector3.new(1.92,1.44,1.84)*(.19+bloom)*(.88+(i%3)*.09)*(1+fade*.14)
  puff.Color=(i%3==0 and GOLD or AMBER):Lerp(CLAY,cool*.88)
  puff.Transparency=.13+fade*.87
 end
end

function N.clear(r)
 if not (r.scan or r.rocket or r.cloud) then return end
 for _,key in ipairs({'scan','rocket','cloud'}) do
  local value=r[key]
  if value then (value.folder or value.root):Destroy();r[key]=nil end
 end
end

function N.step(r,node,now,from,to,age,windup,progress,drone,target,audio,onImpact)
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
 if not r.impacted then
  r.impacted=true
  if ageSince<.20 and near then
   local radius=node:GetAttribute('BlastRadius') or 13
   RoleVisuals.setTime(contactAt)
   RoleVisuals.Pulse(floor+VERTICAL*.085,AMBER,.7,radius*2,.48)
   if not reduced then RoleVisuals.ImpactParticles(floor+VERTICAL*.37,AMBER,1.25,'NomadBlast') end
   if audio then audio:play('prism_blast',floor,{level=.88,pitch=.94}) end
   if onImpact and not steady then onImpact(floor,1.6,contactAt) end
  end
 end
 if ageSince<CLOUD_TIME and near then
  r.cloud=r.cloud or newCloud(camera,floor,reduced)
  if r.cloud then drawCloud(r.cloud,floor,ageSince,reduced,lowFlash) end
 elseif r.cloud then r.cloud.root:Destroy();r.cloud=nil end
end

function N.detach(r,now)
 if r.scan then r.scan.folder:Destroy();r.scan=nil end
 if r.rocket then
  stopRocket(r.rocket,now)
  if now-r.rocket.tailAt<.25 then return false end
 end
 N.clear(r)
 return true
end
return N
