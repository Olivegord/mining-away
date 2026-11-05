-- Client-only beam vocabulary. No gameplay clocks, queries, remotes or assets.
-- Native tapered ribbons form the four-point glint; curved ribbons follow
-- explicit world-space paths. Neither depends on bloom or uploaded textures.
local B={}
B.MiningScale=2.4
function B.recoil(age)
 if not age or age<0 or age>=.4 then return 0 end
 return .95*(1-math.exp(-age*90))*math.exp(-age*12)
end
B.startupStyles={Bubbler='Stars',Starforge='Stars',Halver='Ignition',Singularity='Coil',Resonator='Coil'}
local WHITE=Color3.fromRGB(247,250,255)
local DARK=Color3.fromRGB(19,9,32)
local DARK_GLOW=Color3.fromRGB(48,20,68)
local Players=game:GetService('Players')
local TAU=math.pi*2
local live,details=0,0
B.limits={rigs=64,details=12,reservedRigs=4,reservedDetails=2}
B.styles={
 Cutter={body=.30,core=.055,taper=.48,orbit=.32,spin=2.5,star=.24,tail=.65},
 Percussion={body=.36,core=.075,taper=.22,orbit=.37,spin=1.7,star=.36,tail=.55},
 Resonance={body=.25,core=.04,taper=.7,orbit=.4,spin=2,star=.24,tail=.8},
 Combat={body=.22,core=.07,taper=.12,orbit=.2,spin=4,star=.45,tail=.45},
 Branch={body=.10,core=.025,taper=.35,orbit=0,spin=0,star=0,tail=.25},
 Repair={body=.13,core=.025,taper=.82,orbit=.18,spin=1,star=.12,tail=.7},
 Courier={body=.10,core=.02,taper=.35,orbit=.20,spin=-1.8,star=.12,tail=.6},
 Sentry={body=.32,core=.065,taper=.18,orbit=.26,spin=-2,star=.38,tail=.45},
 Lance={body=.24,core=.055,taper=.08,orbit=.24,spin=3,star=.38,tail=.8},
 Orbital={body=1.8,core=.2,taper=.6,orbit=2.1,spin=3.1,star=1.65,tail=1.1},
 Gridcutter={body=.065,core=.018,taper=.15,orbit=.15,spin=0,star=.17,tail=.55},
 Starforge={body=.12,core=.035,taper=.28,orbit=.3,spin=2.7,star=.32,tail=.8},
 Singularity={body=.09,core=.02,taper=.4,orbit=.55,spin=-3,star=.32,tail=.9},
}
local function sequence(a,b,c,d)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.12,b),
  NumberSequenceKeypoint.new(.86,c),NumberSequenceKeypoint.new(1,d)})
end
-- A stable soft body: moving hard transparency cuts read as dropped frames.
local BODY=sequence(.45,.2,.3,.8)
local CORE=sequence(.18,.04,.12,.32)
local EDGE=sequence(.85,.4,.72,1)
local INK=sequence(1,.42,.65,1)
local ARC=sequence(1,.3,.45,1)
local STAR=NumberSequence.new(.18)
local function clamp(v) return math.clamp(v,0,1) end
local function smooth(v) v=clamp(v);return v*v*(3-2*v) end
function B.charge(q)
 q=clamp(q)
 if q<.76 then return smooth(q/.76),0 end
 if q<.9 then return 1-.62*smooth((q-.76)/.14),0 end
 return .38+.32*smooth((q-.9)/.1),smooth((q-.9)/.1)
end
function B.reduced()
 local p=Players.LocalPlayer
 return p and (p:GetAttribute('ReducedMotion')==true or p:GetAttribute('MA_ReducedMotion')==true
  or p:GetAttribute('ReducedEffects')==true or p:GetAttribute('MA_ReducedEffects')==true) or false
end
function B.near(position,distance)
 local camera=workspace.CurrentCamera
 if not camera then return false end
 local delta=camera.CFrame.Position-position
 return delta:Dot(delta)<distance*distance
end
local function attachment(root,name)
 local a=Instance.new('Attachment');a.Name=name;a.Parent=root;return a
end
local function ribbon(root,name,a,b,color,opacity)
 local v=Instance.new('Beam');v.Name=name;v.Attachment0=a;v.Attachment1=b
 v.FaceCamera=true;v.Segments=12;v.LightEmission=.65;v.LightInfluence=0;v.Brightness=1
 v.Color=ColorSequence.new(color);v.Transparency=opacity;v.Enabled=false;v.Parent=root
 return v
end
local function pair(root,name,color,opacity)
 local a,b=attachment(root,name..'From'),attachment(root,name..'To')
 return {a=a,b=b,beam=ribbon(root,name,a,b,color,opacity)}
end
function B.new(parent,style,color,detail,chargeLens)
 local priority=style=='Orbital' or style=='Singularity'
 local limit=B.limits.rigs-(priority and 0 or B.limits.reservedRigs)
 if live>=limit or not parent then return nil end
 local root=Instance.new('Part');root.Name='BeamVFX';root.Transparency=1;root.Size=Vector3.one*.025
 root.Anchored=true;root.CanQuery=false;root.CanTouch=false;root.CanCollide=false;root.CastShadow=false
 root.Parent=parent
 local r={root=root,all={},style=style,color=color,profile=B.styles[style] or B.styles.Cutter}
 r.a=attachment(root,'Source');r.b=attachment(root,'Contact')
 r.body=ribbon(root,'TaperedBody',r.a,r.b,color,BODY);r.all[#r.all+1]=r.body
 r.core=ribbon(root,'NeedleCore',r.a,r.b,color:Lerp(WHITE,.65),CORE);r.all[#r.all+1]=r.core
 r.body.Segments=1;r.core.Segments=1
 live+=1
 local counted=true
 root.Destroying:Connect(function()
  if counted then
   counted=false;r.destroyed=true;live-=1
   if live==0 and B.clearChargeCache then B.clearChargeCache() end
   if r.detail then details-=1;r.detail=false end
  end
 end)
 -- Detail leases are acquired only near the viewer, and returned on culling.
 r.wantDetail=detail~=false;r.wantChargeLens=chargeLens~=false
 return r
end
local releaseRich,acquireRich,hideRich,drawRich
local function freeDetail(r)
 if releaseRich then releaseRich(r) end
 if not r.detail then return end
 for _,p in ipairs(r.paths) do p.beam:Destroy();p.a:Destroy();p.b:Destroy() end
 for _,p in ipairs(r.stars) do p.beam:Destroy();p.b:Destroy() end
 r.starSource:Destroy();r.starSource=nil
 for i=#r.all,3,-1 do r.all[i]=nil end
 r.paths=nil;r.stars=nil;r.detail=false;details-=1
 if r.orb then r.orb:Destroy();r.orb=nil end
end
local function addDetail(r)
 local priority=r.style=='Orbital' or r.style=='Singularity'
 local limit=B.limits.details-(priority and 0 or B.limits.reservedDetails)
 if r.detail or not r.wantDetail or details>=limit then return end
 r.detail=true;details+=1;r.paths={};r.stars={}
 if r.style=='Orbital' or r.style=='Singularity' or r.style=='Cutter' then
  local orb=Instance.new('Part');orb.Name='ChargedDarkCore';orb.Shape=Enum.PartType.Ball
  orb.Material=Enum.Material.SmoothPlastic;orb.Color=DARK
  orb.Anchored=true;orb.CanCollide=false;orb.CanTouch=false;orb.CanQuery=false;orb.CastShadow=false
  orb.Transparency=1;orb.Parent=r.root;r.orb=orb
 end
 for i=1,4 do
  local p=pair(r.root,i<=2 and 'OrbitRibbon' or i==3 and 'EdgeFilament' or 'DarkCut',r.color,i<=2 and ARC or i==3 and EDGE or INK)
  if i>=3 then p.beam.Segments=1 end
  if i==4 then p.beam.Color=ColorSequence.new(Color3.fromRGB(22,15,37));p.beam.LightEmission=0;p.beam.Brightness=1 end
  r.paths[i]=p;r.all[#r.all+1]=p.beam
 end
 r.starSource=attachment(r.root,'StarCenter')
 for i=1,4 do
  local a=attachment(r.root,'StarPoint'..i)
  local v=ribbon(r.root,'FourPointStar',r.starSource,a,WHITE,STAR);v.Segments=1
  r.stars[i]={b=a,beam=v};r.all[#r.all+1]=v
 end
end
function B.hide(r,releaseDetail)
 if not r or r.destroyed then return end
 -- A hidden charge must return its lease even when base detail is retained.
 if releaseRich then releaseRich(r) end
 for _,v in ipairs(r.all) do v.Enabled=false end
 if r.orb then r.orb.Transparency=1 end
 if releaseDetail then freeDetail(r) end
end
function B.destroy(r)
 if r then r.root:Destroy() end
end
function B.style(r,style,color)
 if not r or r.destroyed or (r.style==style and r.color==color) then return end
 if releaseRich then releaseRich(r) end
 r.style=style;r.profile=B.styles[style] or B.styles.Cutter;r.color=color
 r.body.Color=ColorSequence.new(color);r.core.Color=ColorSequence.new(color:Lerp(WHITE,.65))
 if r.paths then for i=1,3 do r.paths[i].beam.Color=ColorSequence.new(color) end end
end
function B.startup(r,style)
 if not r or r.destroyed or r.startupStyle==style then return end
 releaseRich(r);r.startupStyle=style
end
local function pose(a,position,tangent)
 local reference=math.abs(tangent.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=tangent:Cross(reference).Unit;local up=back:Cross(tangent).Unit
 -- Beam curves use the attachment's X axis, not its LookVector.
 a.CFrame=CFrame.fromMatrix(position,tangent,up,back)
end
-- The supplied motion reference uses a refracting lens as the main silhouette.
-- Only major effects lease this rig; every pose is an absolute timestamp sample.
local richLive=0
local richLimit=4
local richPool={} -- At most four detached cached rigs, in addition to four active leases.
function B.clearChargeCache()
 for _,h in ipairs(richPool) do h.root:Destroy() end
 table.clear(richPool)
end
local GLASS_COLOR=Color3.fromRGB(245,250,255)
local CYAN=Color3.fromRGB(108,238,255)
local VIOLET=Color3.fromRGB(166,64,255)
local LENS_COLORS={Color3.fromRGB(255,255,0),Color3.fromRGB(0,255,255),Color3.fromRGB(255,0,255),Color3.fromRGB(255,255,0)}
local function visualPart(parent,name,material,color,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
 p.Transparency=1;p.Size=Vector3.one*.02;p.Material=material;p.Color=color
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function richPath(r,name,color,opacity)
 local p=pair(r.rich.root,name,color,opacity or ARC)
 p.beam.Width1=0;r.rich.paths[#r.rich.paths+1]=p;return p
end
releaseRich=function(r)
 local h=r.rich;if not h then return end
 hideRich(r);r.rich=nil
 if h.leased then h.leased=false;richLive-=1 end
 if h.particleSource then
  h.vapor:Clear();h.sparks:Clear();h.particleSource.Parent=h.root
 end
 h.lastEmission=nil;h.root.Parent=nil
 if #richPool>=richLimit then table.remove(richPool,1).root:Destroy() end
 richPool[#richPool+1]=h
end
acquireRich=function(r)
 if r.rich or not r.wantChargeLens or richLive>=richLimit or r.style=='Repair' or r.style=='Courier' or r.style=='Branch' then return end
 local key=r.startupStyle or 'Refraction'
 for i=#richPool,1,-1 do
  local h=richPool[i]
  if h.key==key then
   table.remove(richPool,i);r.rich=h;h.leased=true;richLive+=1
   h.root.Parent=r.root
   if h.particleSource then h.particleSource.Parent=r.root end
   return
  end
 end
 local folder=Instance.new('Folder');folder.Name='RefractionChoreography';folder.Parent=r.root
 local h={root=folder,paths={},comets={},sweeps={},bolts={},debris={},lastEmission=nil,key=key,leased=true}
 r.rich=h;richLive+=1
 folder.Destroying:Connect(function() if h.leased then h.leased=false;richLive-=1 end end)
 if r.startupStyle then
  h.startup=StartupFX.create(folder,r.startupStyle,1)
  return
 end
 h.glass=visualPart(folder,'ClearGlassDistortion',Enum.Material.Glass,GLASS_COLOR,Enum.PartType.Ball)
 h.glass.Reflectance=0
 -- Glass + Highlight is a native renderer technique, verified in this Studio.
 -- Keep it local and optional: above-one transparency is engine-dependent.
 h.mask=Instance.new('Highlight');h.mask.Name='ChromaticDistortionMask'
 h.mask.DepthMode=Enum.HighlightDepthMode.Occluded;h.mask.OutlineTransparency=.999
 h.mask.FillTransparency=1;h.mask.FillColor=Color3.fromRGB(255,255,0);h.mask.Enabled=false;h.mask.Parent=h.glass
 h.core=visualPart(folder,'ChargeOriginCore',Enum.Material.SmoothPlastic,DARK,Enum.PartType.Ball)
 for i=1,4 do
  h.comets[i]={path=richPath(r,'GatheringComet'..i,i%2==0 and CYAN or VIOLET),
   head=visualPart(folder,'CometHead',Enum.Material.Neon,i%2==0 and CYAN or WHITE,Enum.PartType.Ball)}
 end
 for i=1,3 do
  h.sweeps[i]={ink=richPath(r,'DarkSweptLobe'..i,Color3.fromRGB(27,8,59),NumberSequence.new(.18)),
   rim=richPath(r,'VioletSweptRim'..i,VIOLET,NumberSequence.new(.24))}
  h.sweeps[i].ink.beam.LightEmission=0
 end
 for i=1,4 do h.bolts[i]=richPath(r,'DischargeArc'..i,i%2==0 and CYAN or VIOLET,NumberSequence.new(.3)) end
 for i=1,6 do
  local p=visualPart(folder,'OrbitingMineralChip',Enum.Material.Slate,Color3.fromRGB(44,38,62))
  h.debris[i]=p
 end
 h.vapor=Instance.new('ParticleEmitter');h.vapor.Name='VioletDistortionVapor';h.vapor.Texture='rbxasset://textures/particles/smoke_main.dds'
 h.vapor.Enabled=false;h.vapor.Rate=0;h.vapor.Color=ColorSequence.new(VIOLET)
 h.vapor.LightEmission=.35;h.vapor.LightInfluence=0;h.vapor.Brightness=1
 h.vapor.Lifetime=NumberRange.new(.5,1.3);h.vapor.Speed=NumberRange.new(1,3.5);h.vapor.Drag=3
 h.vapor.SpreadAngle=Vector2.new(180,180);h.vapor.Acceleration=Vector3.new(0,.7,0);h.vapor.WindAffectsDrag=false
 h.vapor.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.35,1.9),NumberSequenceKeypoint.new(1,2.8)})
 h.vapor.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,.62),NumberSequenceKeypoint.new(1,1)})
 h.vapor.Rotation=NumberRange.new(-180,180);h.vapor.RotSpeed=NumberRange.new(-55,55)
 h.particleSource=attachment(r.root,'LensParticleSource');h.vapor.Parent=h.particleSource
 h.sparks=Instance.new('ParticleEmitter');h.sparks.Name='LensDischargeSparks';h.sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
 h.sparks.Enabled=false;h.sparks.Rate=0;h.sparks.Color=ColorSequence.new(CYAN);h.sparks.LightEmission=.8;h.sparks.LightInfluence=0;h.sparks.Brightness=1.5
 h.sparks.Lifetime=NumberRange.new(.25,.65);h.sparks.Speed=NumberRange.new(4,11);h.sparks.Drag=4;h.sparks.SpreadAngle=Vector2.new(180,180)
 h.sparks.Acceleration=Vector3.new(0,-2,0);h.sparks.WindAffectsDrag=false;h.sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.11),NumberSequenceKeypoint.new(.15,.24),NumberSequenceKeypoint.new(1,0)})
 h.sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)});h.sparks.Parent=h.particleSource
 -- Emitters are outside the detail Folder because their parent is an Attachment.
 folder.Destroying:Connect(function() h.particleSource:Destroy() end)
end
hideRich=function(r)
 local h=r.rich;if not h then return end
 if h.startup then StartupFX.hide(h.startup);return end
 h.glass.Transparency=1;h.mask.Enabled=false;h.core.Transparency=1
 for _,p in ipairs(h.paths) do p.beam.Enabled=false end
 for _,p in ipairs(h.debris) do p.Transparency=1 end
 for _,p in ipairs(h.comets) do p.head.Transparency=1 end
 h.vapor.Enabled=false;h.sparks.Enabled=false
end
local function curve(path,a,b,ta,tb,bend,width)
 if width<=.002 then
  if path.beam.Enabled then path.beam.Enabled=false end
  return
 end
 pose(path.a,a,ta);pose(path.b,b,tb)
 path.beam.CurveSize0=bend;path.beam.CurveSize1=bend
 path.beam.Width0=width
 if not path.beam.Enabled then path.beam.Enabled=true end
end
-- Reference choreography: orbiting inflow first, one brief lens swell late
-- in charge, contraction, then complete handoff to the released beam.
-- q is authoritative charge progress. No layer owns or extends gameplay time.
function B.lensEnvelope(q)
 if q==nil or q<.64 or q>=1 then return 0 end
 if q<.79 then return smooth((q-.64)/.15) end
 return 1-smooth((q-.79)/.21)
end
drawRich=function(r,from,to,now,width,charge,releaseAge,scale,afterAge)
 local h=r.rich;if not h then return end
 if charge==nil or charge<0 or charge>=1 or afterAge then hideRich(r);return end
 if h.startup then StartupFX.update(h.startup,CFrame.new(from),charge);return end
 local q=charge
 local major=r.style=='Orbital' and 1 or r.style=='Singularity' and .34 or .2
 local s=major*(scale or 1)
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local vertical=camera and camera.CFrame.UpVector or Vector3.yAxis
 local eye=camera and camera.CFrame.Position-from or Vector3.zAxis*40
 local toward=eye.Magnitude>.01 and eye.Unit or Vector3.zAxis
 local inflow=smooth(q/.12)*(1-smooth((q-.62)/.26))
 local lens=B.lensEnvelope(q)
 local pressure=smooth((q-.36)/.26)*(1-smooth((q-.85)/.13))
 local alive=smooth(q/.1)*(1-smooth((q-.94)/.06))
 local radius=s*(.025+4.475*lens)
 -- The single surface goes clear -> chromatic -> clear, so nested Glass
 -- cannot hide the color layer. It stays exactly on the emitting attachment.
 h.glass.CFrame=CFrame.new(from);h.glass.Size=Vector3.one*radius*2
 h.mask.Enabled=lens>.002
 h.glass.Transparency=lens>.002 and (1+2*lens) or 1
 local colorPulse=smooth((q-.70)/.045)*(1-smooth((q-.975)/.025))
 local colorAt=clamp((q-.73)/.24)*3
 local index=math.min(3,math.floor(colorAt)+1)
 h.mask.FillColor=LENS_COLORS[index]:Lerp(LENS_COLORS[index+1],colorAt-(index-1))
 h.mask.FillTransparency=1+1.2*colorPulse
 h.core.CFrame=CFrame.new(from);h.core.Size=Vector3.one*s*(.35+.9*smooth(q/.65))
 h.core.Transparency=alive>.02 and 0 or 1
 h.particleSource.Position=toward*s*.8
 -- The bright heads travel toward the origin, with tails behind. As the
 -- distortion expands these streaks die down, leaving its silhouette clear.
 for i,item in ipairs(h.comets) do
  -- One inward sweep per charge. Nothing wraps while it is visible.
  local t=clamp((q-(i-1)*.045)/.72)
  local travel=t*t*(2-t)
  local angle=i*TAU/4+travel*2.7
  local orbit=s*(.12+5*(1-travel))
  local trail=orbit+s*(.5+.7*math.sin(t*math.pi))
  local a=Vector3.new(math.cos(angle)*orbit,math.sin(angle*.8+i)*orbit*.45,math.sin(angle)*orbit)
  local b=Vector3.new(math.cos(angle-.9)*trail,math.sin((angle-.9)*.8+i)*trail*.45,math.sin(angle-.9)*trail)
  local ta=Vector3.new(-math.sin(angle),.15,math.cos(angle)).Unit
  local tb=Vector3.new(-math.sin(angle-.9),-.15,math.cos(angle-.9)).Unit
  local visible=inflow*smooth(t/.12)*(1-smooth((t-.82)/.18))
  curve(item.path,a,b,ta,tb,trail*.45,.3*s*visible)
  item.head.CFrame=CFrame.new(from+a);item.head.Size=Vector3.one*math.max(.01,(.22+.1*(i%2))*s*visible)
  item.head.Transparency=1-.95*visible
 end
 for i,item in ipairs(h.sweeps) do
  local a=2.8*smooth(q)+i*TAU/3
  local x=Vector3.new(math.cos(a),.15*math.sin(a*2),math.sin(a)).Unit
  local y=Vector3.new(math.cos(a+1.7),.2,math.sin(a+1.7)).Unit
  local reach=s*(4.5-2*q)
  local start=x*reach*.45;local finish=y*reach*1.7+Vector3.yAxis*.5*s
  local ta=(y+Vector3.yAxis*.4).Unit;local tb=(-x+Vector3.yAxis*.15).Unit
  curve(item.ink,start,finish,ta,tb,reach*1.1,1.1*s*pressure)
  curve(item.rim,start+Vector3.yAxis*.045*s,finish,ta,tb,reach*1.1,.15*s*pressure)
 end
 for i,path in ipairs(h.bolts) do
  local angle=i*TAU/4+2.4*smooth(q)
  local x=Vector3.new(math.cos(angle),.2,math.sin(angle)).Unit
  local y=Vector3.new(math.cos(angle+1),.4,math.sin(angle+1)).Unit
  local reach=s*(1.8+.4*math.sin(q*TAU*2+i))
  curve(path,x*.2*s,y*reach,(x+Vector3.yAxis).Unit,(-y+Vector3.yAxis).Unit,reach*.5,.045*s*pressure)
 end
 for i,p in ipairs(h.debris) do
  local drift=smooth(q/.8)
  local angle=drift*.75+i*2.39996
  local rr=s*(3.8+(i%4)*.7)*(1-.25*q)
  local position=Vector3.new(math.cos(angle)*rr,(math.sin(drift*2+i)*.4+drift*1.1)*s,math.sin(angle)*rr)
  p.CFrame=CFrame.new(from+position)*CFrame.Angles(i*.7+drift*.2,i,drift*.15)
  local size=(.18+(i%4)*.1)*s;p.Size=Vector3.new(size,size*.65,size*1.4)
  p.Transparency=1-alive*.92
 end
 -- Sparse early motes yield to the circle, then stop entirely at release.
 -- Never emit catch-up batches after a late observer or paused render loop.
 if inflow>.05 then
  if h.lastEmission and now>=h.lastEmission+.08 then
   h.vapor:Emit(1);h.sparks:Emit(2);h.lastEmission=now
  elseif not h.lastEmission or now<h.lastEmission then h.lastEmission=now end
 else h.lastEmission=nil end
end

-- width is the caller's authoritative-envelope result. Charge never changes
-- contact timing. releaseAge is from the server start, never local creation.
function B.draw(r,from,to,now,width,charge,releaseAge,scale)
 if not r or r.destroyed or not r.root.Parent then return end
 width=clamp(width);scale=scale or 1
 if charge and charge>=1 and width==0 then B.hide(r,true);return end
 local near=B.near(from,r.style=='Orbital' and 340 or 110)
 local reduced=B.reduced()
 if not near or reduced then freeDetail(r) else addDetail(r) end
 local delta=to-from;local length=delta.Magnitude
 if length<.015 then B.hide(r);return end
 local direction=delta/length
 local reference=math.abs(direction.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local side=direction:Cross(reference).Unit;local up=side:Cross(direction).Unit
 r.root.CFrame=CFrame.new(from);r.a.Position=Vector3.zero;r.b.Position=delta
 local p=r.profile
 -- Keep body opacity stable; release pressure carries the width motion.
 local launchPressure=releaseAge and releaseAge>=0 and (1-clamp(releaseAge/.14))^2 or 0
 local thickness=p.body*width*scale*(1+launchPressure*.35)
 r.body.Width0=thickness;r.body.Width1=thickness*p.taper;r.body.Enabled=width>.002
 r.core.Width0=p.core*width*scale;r.core.Width1=p.core*width*scale*.6;r.core.Enabled=width>.002
 if not r.detail then return end
 if charge~=nil and charge>=0 and charge<1 then
  acquireRich(r);drawRich(r,from,to,now,width,charge,releaseAge,scale)
 else releaseRich(r) end
 if r.rich and r.rich.startup then
  -- The selected cloud style is the charge silhouette, not another overlay.
  for _,v in ipairs(r.all) do if v.Enabled then v.Enabled=false end end
  if r.orb then r.orb.Transparency=1 end
  return
 end
 local gather,glint=0,0
 if charge~=nil then gather,glint=B.charge(charge) end
 local release=releaseAge and releaseAge>=0 and (1-clamp(releaseAge/.18))^2 or 0
 -- The shrinking chromatic lens becomes the launch flash. The same native
 -- core and curved shock front span the boundary; firing never cuts them off.
 local launch=r.style=='Cutter' and not r.startupStyle
 local flash=launch and (charge and smooth((charge-.94)/.06) or release) or 0
 local energy=charge~=nil and gather or width
 local radius=p.orbit*scale*(charge~=nil and (1.25-.6*gather) or .7)
 if r.orb then
  r.orb.Position=from;r.orb.Size=Vector3.one*math.max(.025,radius*gather*.8)
  r.orb.Transparency=charge~=nil and 0 or 1
  if r.rich then r.orb.Transparency=1 end
  r.orb.Color=DARK:Lerp(DARK_GLOW,gather*.6)
  r.orb.Material=Enum.Material.SmoothPlastic
  if flash>.002 then
   r.orb.Material=Enum.Material.Neon;r.orb.Color=WHITE
   r.orb.Size=Vector3.one*math.max(.025,2.2*scale*flash)
   r.orb.Transparency=0
  end
 end
 local angle=charge~=nil and smooth(charge)*2.4 or 2.4+(releaseAge or now)*p.spin*.35
 -- Two deliberately separated hooked arcs, not a full glowing shell.
 for i=1,2 do
  local path=r.paths[i];local a=angle+(i-1)*math.pi;local b=a+1.9
  local center=direction*.06
  local x=side*math.cos(a)+up*math.sin(a);local y=side*math.cos(b)+up*math.sin(b)
  local ta=side*-math.sin(a)+up*math.cos(a);local tb=side*-math.sin(b)+up*math.cos(b)
  pose(path.a,center+x*radius,ta);pose(path.b,center+y*radius,tb)
  path.beam.CurveSize0=radius*.72;path.beam.CurveSize1=radius*.72
  path.beam.Width0=math.max(.001,p.body*.11*energy*scale);path.beam.Width1=0
  path.beam.Enabled=energy>.02 and p.orbit>0
  if charge==nil then
   if r.style=='Resonance' or r.style=='Repair' then
    -- Paired longitudinal waves carry support/resonance, with both ends
    -- fixed to their real contacts rather than orbiting an unrelated center.
    local bend=(i==1 and 1 or -1)*.16*math.sin(now*(r.style=='Repair' and 1.3 or 3))
    pose(path.a,Vector3.zero,(direction+side*bend).Unit)
    pose(path.b,delta,(direction-side*bend).Unit)
    path.beam.CurveSize0=length*.33;path.beam.CurveSize1=length*.33
    path.beam.Width0=p.core*width*scale*.65;path.beam.Width1=0
   elseif r.style=='Courier' then
    -- Two short gold transfer ticks travel toward the cargo mount.
    local t=1-((now*.8+(i-1)*.5)%1)
    path.a.Position=delta*t;path.b.Position=delta*math.max(0,t-.12)
    path.beam.CurveSize0=0;path.beam.CurveSize1=0
    path.beam.Width0=.035*energy*scale;path.beam.Width1=.012*energy*scale
   elseif r.style=='Cutter' or r.style=='Combat' or r.style=='Sentry' then
    path.beam.Enabled=release>.01 -- quiet sustained worker/threat silhouette
   end
  end
  if flash>.002 then
   local burstRadius=scale*(.6+1.8*(1-flash))
   pose(path.a,center+x*burstRadius,ta);pose(path.b,center+y*burstRadius,tb)
   path.beam.CurveSize0=burstRadius*.72;path.beam.CurveSize1=burstRadius*.72
   path.beam.Width0=.35*scale*flash;path.beam.Width1=0;path.beam.Enabled=true
  end
 end
 -- Parallel rim + normally blended dark seam. Endpoint offsets shrink to
 -- zero at contact, so no filament can protrude beyond the verified surface.
 for i=3,4 do
  local path=r.paths[i];local offset=side*(i==3 and .22 or -.13)*thickness
  path.a.Position=offset;path.b.Position=delta
  path.beam.CurveSize0=0;path.beam.CurveSize1=0
  path.beam.Width0=thickness*(i==3 and .08 or .14);path.beam.Width1=0
  path.beam.Enabled=width>.02
  if charge~=nil and (r.style=='Orbital' or r.style=='Singularity') then
   local a=angle+i*1.7
   local x=side*math.cos(a)+up*math.sin(a)
   path.a.Position=x*radius*.35;path.b.Position=x*radius*1.4+direction*radius*.18
   path.beam.Width0=radius*.22*gather;path.beam.Width1=0;path.beam.Enabled=gather>.02
  end
 end
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or side
 local vertical=camera and camera.CFrame.UpVector or up
 local star=p.star*scale*math.max(release,glint*.3)
 local starCenter=r.style=='Orbital' and charge==nil and Vector3.yAxis*2.5 or Vector3.zero
 r.starSource.Position=starCenter
 -- Concave four-cardinal needle silhouette, with quiet gaps between rays.
 for i,path in ipairs(r.stars) do
  local axis=i==1 and right or i==2 and vertical or i==3 and -right or -vertical
  path.b.Position=starCenter+axis*star
  path.beam.Width0=star*.22;path.beam.Width1=0;path.beam.Enabled=star>.008 and not reduced
 end
end
function B.counts() return live,details,richLive,#richPool end
-- Main geometry, fine trace, star and flecks have separate shutdown clocks.
-- Reuse the rig; no emitter/Part allocation occurs when a cast ends.
function B.after(r,from,to,now,age,scale)
 if not r or r.destroyed or age<0 then return end
 if (to-from).Magnitude<.015 then B.hide(r,true);return end
 local lifetime=r.profile.tail;local q=clamp(age/lifetime)
 if q>=1 then B.hide(r,true);return end
 local trace=(1-clamp(age/.14))^2
 B.draw(r,from,to,now,trace*.16,nil,nil,scale)
 r.body.Enabled=false
 if not r.detail or B.reduced() then return end
 local delta=to-from
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 local decay=(1-q)^2;local radius=r.profile.star*(scale or 1)*decay*.45
 local drift=Vector3.yAxis*(.08+.15*(1-math.exp(-age*3)))
 r.starSource.Position=delta+drift
 for i,path in ipairs(r.stars) do
  local axis=i==1 and right or i==2 and up or i==3 and -right or -up
  path.b.Position=delta+drift+axis*radius
  path.beam.Width0=radius*.22;path.beam.Width1=0;path.beam.Enabled=radius>.008
 end
 r.core.Enabled=false
 for i,path in ipairs(r.paths) do
  if i<=2 then
   local center=delta*(.32+i*.22)+up*(.1*(1-math.exp(-age*2)))
   path.a.Position=center-right*.035*decay;path.b.Position=center+right*.035*decay
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=.045*decay;path.beam.Width1=.012*decay;path.beam.Enabled=decay>.04
  elseif i==3 then
   path.a.Position=Vector3.zero;path.b.Position=delta;path.beam.Width0=.025*trace;path.beam.Width1=0;path.beam.Enabled=trace>.02
  else path.beam.Enabled=false end
 end
end
return B
