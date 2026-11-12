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
local SHEET_ALPHA=fadeCurves(.79,.90,.984)
local CORE_ALPHA=fadeCurves(.10,.37,.965)
local HALO_ALPHA=fadeCurves(.50,.76,.998)
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
  line.halo.Width0=width*6;line.halo.Width1=width*4.3
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
  local pane={sheet=scanLine(root,true),edges={},feet={},ends={},contour={}}
  for j=1,3 do pane.edges[j]=scanLine(root,false);pane.feet[j]=rail(folder,'FootRail') end
  for j=1,2 do pane.ends[j]=part(folder,'FootGlint',ICE,Vector3.one*.17,Enum.PartType.Ball) end
  for j=1,8 do pane.contour[j]=rail(folder,'CrystalScanEdge') end
  scan.panes[i]=pane
 end
 return scan
end

-- Offset passes move as a rake, swing across it, then converge on one point.
-- The last hold uses the same three panels with shorter stagger and width.
local SCAN_POSES={
 {0,-11,-7,-.47,7.7,2.0},
 {.15,-4,-3,-.24,8.1,2.2},
 {.30,7,3,.16,8.1,2.1},
 {.39,8,5,.46,7.5,1.9},
 {.53,1,6,.94,6.7,1.55},
 {.65,-4,2,1.21,5.6,1.4},
 {.76,-1,-1,1.38,3.0,.81},
 {.87,0,0,1.48,1.10,.35},
 {1,0,0,1.48,1.10,.35},
}
local function scanPose(q)
 for i=2,#SCAN_POSES do
  local b=SCAN_POSES[i]
  if q<=b[1] then
   local a=SCAN_POSES[i-1]
   local t=smooth((q-a[1])/(b[1]-a[1]))
   return a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t,a[4]+(b[4]-a[4])*t,a[5]+(b[5]-a[5])*t,a[6]+(b[6]-a[6])*t
  end
 end
 return 0,0,1.48,1.10,.35
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

local function drawScanner(scan,from,to,ground,q,now,target,reduced,steady)
 local flat=Vector3.new(to.X-from.X,0,to.Z-from.Z)
 local bearing=flat.Magnitude>.05 and flat.Unit or Vector3.zAxis
 local across=VERTICAL:Cross(bearing)
 local sample=steady and (q<.4 and .15 or q<.75 and .53 or .92) or q
 local x,z,yaw,width,stagger=scanPose(sample)
 local along=across*math.cos(yaw)+bearing*math.sin(yaw)
 local normal=VERTICAL:Cross(along)
 local floor=Vector3.new(to.X,ground+.065,to.Z)+across*x+bearing*z
 local height=math.max(8,from.Y-ground)
 local envelope=smooth(q/.09)*(1-smooth((q-.923)/.077))
 local query
 if not reduced and target and target.source.Parent and now>=(scan.nextTrace or 0) then
  scan.nextTrace=now+.071
  query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include
  query.FilterDescendantsInstances={target.source.Parent}
 end
 local last
 for i,pane in ipairs(scan.panes) do
  local index=i-2
  local center=floor+along*(index*(width+.22))+normal*(index*stagger)
  local a=center-along*width*.5
  local b=center+along*width*.5
  local slide=steady and 0 or .035*math.sin(q*13+i*.94)
  local localGain=envelope*(.81+.19*smooth(q/.22+i*.08)+slide)
  local lock=smooth((q-.74)/.13)
  local top=VERTICAL*(height*(.79+.19*lock))
  paintLine(pane.sheet,center,center+top,along,width,reduced and 0 or localGain*.83)
  local inward=along*math.min(.43,width*.22)
  paintLine(pane.edges[1],a,a+top,along,.055,localGain*.95)
  paintLine(pane.edges[2],b,b+top,along,.084,localGain*1.08)
  paintLine(pane.edges[3],b-inward,b-inward+top,along,.034,reduced and 0 or localGain*.71)
  local returnDepth=normal*math.min(1.40,width*.28)
  paintRail(pane.feet[1],a,b,.063,localGain*.88)
  paintRail(pane.feet[2],a,a+returnDepth,.046,localGain*.68)
  paintRail(pane.feet[3],b,b-returnDepth,.054,localGain*.8)
  if last then paintRail(scan.seams[i-1],last,a,.049,localGain*.57) end
  last=b
  for j,glint in ipairs(pane.ends) do
   glint.Position=j==1 and a or b
   glint.Transparency=1-localGain*(j==1 and .64 or .87)
  end
  if query then traceCrystal(pane,a,b,ground,query)
  elseif reduced or not target or envelope<.12 then
   for _,edge in ipairs(pane.contour) do edge.core.Transparency=1;edge.halo.Transparency=1 end
  end
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

function N.step(r,node,now,from,to,age,windup,progress,target,audio,onImpact)
 local camera=workspace.CurrentCamera
 local ground=node:GetAttribute('ScanGround') or to.Y-1
 local contactAt=node:GetAttribute('ContactAt')
 local landed=contactAt and now>=contactAt
 local near=camera and BeamVFX.near(Vector3.new(to.X,ground,to.Z),150)
 local player=game:GetService('Players').LocalPlayer
 local reduced=BeamVFX.reduced()
 local steady=game:GetService('GuiService').ReducedMotionEnabled or (player and player:GetAttribute('ReducedMotion')==true)
 local lowFlash=reduced or (player and player:GetAttribute('ReducedFlashing')==true)
 if not landed and age>=0 and age<windup and near then
  r.scan=r.scan or newScanner(camera)
  local q=age/windup
  if r.scan then drawScanner(r.scan,from,to,ground,q,now,target,reduced,steady) end
  if audio and audio.setLoop and q>.06 and (node:GetAttribute('PausedAt') or 0)<=0 then
   audio:setLoop(node,'orbital_charge',Vector3.new(to.X,ground+4,to.Z),.23+.42*smooth(q),.58+.52*q)
  elseif audio and audio.stopLoop then audio:stopLoop(node) end
 else
  if r.scan then r.scan.folder:Destroy();r.scan=nil end
  if audio and audio.stopLoop then audio:stopLoop(node) end
 end
 if not landed and progress>=0 and progress<1.12 and near and not (r.rocket and r.rocket.tailAt) then
  if not r.fired then
   r.fired=true
   if audio and progress<.20 then audio:play('coil_fire',from,{pitch=1.32,level=.79}) end
  end
  r.rocket=r.rocket or newRocket(camera,reduced)
  if r.rocket then drawRocket(r.rocket,from,to,math.min(progress,1),steady) end
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
