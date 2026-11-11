-- Client-only beam vocabulary. No gameplay clocks, queries, remotes or assets.
-- Native tapered ribbons form the four-point glint; curved ribbons follow
-- explicit world-space paths. Neither depends on bloom or uploaded textures.
local B={}
B.MiningScale=1 -- Restore the first installed beam proportions.
B.WidthScale=.4
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
 Prism={body=1.1,core=.08,taper=.84,orbit=.23,spin=1.8,star=.32,tail=.45},
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
   if B.onChargeEnd then B.onChargeEnd(r) end
   LaunchAftermath.cancel(r)
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
 LaunchAftermath.cancel(r)
 if releaseRich then releaseRich(r) end
 if not r.detail then return end
 for _,p in ipairs(r.paths) do p.beam:Destroy();p.a:Destroy();p.b:Destroy() end
 for _,p in ipairs(r.stars) do p.beam:Destroy();p.b:Destroy() end
 r.starSource:Destroy();r.starSource=nil
 PlaneBurst.destroy(r.plane);r.plane=nil
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
 r.plane=PlaneBurst.create(r.root,r.color)
 r.starSource=attachment(r.root,'StarCenter')
 for i=1,4 do
  local a=attachment(r.root,'StarPoint'..i)
  local v=ribbon(r.root,'FourPointStar',r.starSource,a,WHITE,STAR);v.Segments=1
  r.stars[i]={b=a,beam=v};r.all[#r.all+1]=v
 end
end
function B.hide(r,releaseDetail)
 if not r or r.destroyed then return end
 LaunchAftermath.cancel(r)
 -- A hidden charge must return its lease even when base detail is retained.
 if releaseRich then releaseRich(r) end
 for _,v in ipairs(r.all) do v.Enabled=false end
 if r.plane then PlaneBurst.hide(r.plane) end
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
 if r.plane then for _,ray in ipairs(r.plane.rays) do ray.beam.Color=ColorSequence.new(color:Lerp(WHITE,.2)) end end
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
local richPoolLimit=6 -- Mixed preview styles can need overlapping refraction rigs.
local richPool={} -- Six detached cached rigs maximum; active lease limit stays four.
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
 if B.onChargeEnd and not h.launched then B.onChargeEnd(r) end
 hideRich(r);r.rich=nil
 if h.leased then h.leased=false;richLive-=1 end
 if h.particleSource then
  h.vapor:Clear();h.sparks:Clear();h.particleSource.Parent=h.root
 end
 h.lastEmission=nil;h.lastPulse=nil;h.launched=nil;h.root.Parent=nil
 if #richPool>=richPoolLimit then table.remove(richPool,1).root:Destroy() end
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
 h.glass=visualPart(folder,'ChromaticRelease',Enum.Material.Neon,GLASS_COLOR,Enum.PartType.Ball)
 h.collars={}
 for i=1,4 do h.collars[i]=richPath(r,'FocusVane'..i,CYAN,ARC) end
 h.core=visualPart(folder,'ChargeOriginCore',Enum.Material.Neon,CYAN,Enum.PartType.Ball)
 for i=1,8 do
  h.comets[i]={path=richPath(r,'InwardStream'..i,i%2==0 and CYAN or VIOLET),
   head=visualPart(folder,'InwardSpark',Enum.Material.Neon,i%2==0 and CYAN or WHITE,Enum.PartType.Ball)}
 end
 for i=1,3 do
  local edge=richPath(r,'InwardTendrilEdge'..i,VIOLET,ARC)
  local ink=richPath(r,'InwardTendrilInk'..i,DARK,ARC)
  ink.beam.LightEmission=0
  h.sweeps[i]={edge=edge,ink=ink}
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
 h.glass.Transparency=1;h.core.Transparency=1
 for _,vane in ipairs(h.collars) do vane.beam.Enabled=false end
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
-- Original pre-revision flash, preserved independently of the longer inflow.
function B.lensEnvelope(q)
 if q==nil or q<.64 or q>=1 then return 0 end
 if q<.79 then return smooth((q-.64)/.15) end
 return 1-smooth((q-.79)/.21)
end
function B.flashProgress(q,duration)
 duration=math.max(.01,duration or .8)
 return 1-(1-q)*duration/math.min(.8,duration)-.1
end
local function drawFlash(h,from,direction,flashQ,s)
 local lens=B.lensEnvelope(flashQ)
 local radius=math.max(.01,s*(.025+2.8*lens))
 h.glass.CFrame=CFrame.lookAt(from,from+direction)
 h.glass.Size=Vector3.new(radius*2,radius*2,radius*.63)
 local index=math.min(4,math.floor(clamp((flashQ-.73)/.24)*3)+1)
 h.glass.Color=LENS_COLORS[index]
 local player=Players.LocalPlayer
 local reduced=player and player:GetAttribute('ReducedFlashing')==true
 h.glass.Transparency=1-(reduced and .21 or .83)*lens
end
drawRich=function(r,from,to,now,width,charge,releaseAge,scale,afterAge,chargeDuration)
 local h=r.rich;if not h then return end
 if charge==nil or charge<0 or charge>=1 or afterAge then hideRich(r);return end
 if B.onCharge then B.onCharge(r,from,now,charge) end
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
 local flashQ=B.flashProgress(q,chargeDuration)
 h.flashDuration=math.min(.8,math.max(.01,chargeDuration or .8))
 if h.tint~=r.color then
  h.tint=r.color
  for _,vane in ipairs(h.collars) do vane.beam.Color=ColorSequence.new(r.color:Lerp(WHITE,.55)) end
  h.vapor.Color=ColorSequence.new(r.color);h.sparks.Color=ColorSequence.new(r.color)
  for i,item in ipairs(h.comets) do
   local color=r.color:Lerp(WHITE,i%2==0 and .64 or .26)
   item.path.beam.Color=ColorSequence.new(color);item.head.Color=color
  end
 end
 local delta=to-from
 LaunchAftermath.charge(r,from,delta.Unit,now,q,scale)
 local alive=smooth(q/.12)*(1-smooth((q-.82)/.18))
 -- The single surface goes clear -> chromatic -> clear, so nested Glass
 -- cannot hide the color layer. It stays exactly on the emitting attachment.
 local direction=delta.Unit
 local across=direction:Cross(math.abs(direction.Y)>.94 and Vector3.zAxis or Vector3.yAxis).Unit
 local upright=across:Cross(direction).Unit
 -- Four narrow vanes close in the firing plane. Their radius and speed
 -- communicate how close the charge is, even with several drones in view.
 local lock=smooth((q-.12)/.73)
 local vaneAlpha=smooth(q/.18)*(1-smooth((q-.78)/.19))
 for i,vane in ipairs(h.collars) do
  local angle=(i-1)*math.pi*.5+lock*.63
  local radial=across*math.cos(angle)+upright*math.sin(angle)
  local tangent=across*-math.sin(angle)+upright*math.cos(angle)
  local center=radial*s*(3.7-2.86*lock)-direction*s*(.87-.87*lock)
  local span=s*(1.06-.56*lock)
  curve(vane,center-tangent*span,center+tangent*span,tangent,tangent,0,s*.34*vaneAlpha)
 end
 drawFlash(h,from,direction,flashQ,s)
 local focus=smooth(q/.78)
 h.core.CFrame=CFrame.new(from);h.core.Size=Vector3.one*s*(.26+1.05*focus)
 h.core.Color=r.color:Lerp(WHITE,.26+.63*focus)
 h.core.Transparency=1-alive*.94
 h.particleSource.Position=toward*s*.8
 -- The video's streams are moving inward immediately. Their curvature is
 -- generated by attraction acting on momentum, not an orbit angle animation.
 for i,item in ipairs(h.comets) do
  local a,va,captured=PullMotion.sample(i,q)
  local b,vb=PullMotion.sample(i,math.max(0,q-.13))
  local visible=smooth(q/.035)*(1-smooth((q-captured+.035)/.035))
  local head=a*s*4.6;local tail=b*s*4.6
  local span=(tail-head).Magnitude
  if va.Magnitude>.01 and vb.Magnitude>.01 and span>.002 then
   curve(item.path,head,tail,-va.Unit,-vb.Unit,span*.27,(i%2==0 and .24 or .16)*s*visible)
  else item.path.beam.Enabled=false end
  item.head.CFrame=CFrame.new(from+head)
  item.head.Size=Vector3.one*math.max(.01,.25*s*visible)
  item.head.Transparency=1-visible
 end
 -- Small ink curls have separate arrivals and deform along attracted paths.
 -- No shared orbit angle or reset: each short ribbon is drawn into the mouth.
 for i,item in ipairs(h.sweeps) do
  local start=.035+(i-1)*.12
  local finish=.72+(i-1)*.065
  local t=clamp((q-start)/(finish-start))
  local _,_,captured=PullMotion.sample(i*2,0)
  local progress=t*captured
  local a,va=PullMotion.sample(i*2,progress)
  local b,vb=PullMotion.sample(i*2,math.max(0,progress-.09-.018*i))
  local visible=smooth(t/.12)*(1-smooth((t-.82)/.18))
  local head=a*s*2;local tail=b*s*2
  local span=(tail-head).Magnitude
  if span>.002 and va.Magnitude>.01 and vb.Magnitude>.01 then
   local breadth=s*(.30+.07*math.sin(t*11+i*2.1))*visible
   curve(item.edge,head,tail,-va.Unit,-vb.Unit,span/3,breadth)
   curve(item.ink,head,tail,-va.Unit,-vb.Unit,span/3,breadth*.66)
  else
   item.edge.beam.Enabled=false;item.ink.beam.Enabled=false
  end
 end
 -- Fine charge motes stop at release; the separately owned smoke persists.
 -- Never emit catch-up batches after a late observer or paused render loop.
 if inflow>.05 then
  if h.lastEmission and now>=h.lastEmission+.08 then
   h.sparks:Emit(2);h.lastEmission=now
  elseif not h.lastEmission or now<h.lastEmission then h.lastEmission=now end
 else h.lastEmission=nil end
end

-- width is the caller's authoritative-envelope result. Charge never changes
-- contact timing. releaseAge is from the server start, never local creation.
function B.draw(r,from,to,now,width,charge,releaseAge,scale,chargeDuration)
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
 local thickness=p.body*width*scale*B.WidthScale*(1+launchPressure*.35)
 r.body.Width0=thickness;r.body.Width1=thickness*p.taper;r.body.Enabled=width>.002
 r.core.Width0=p.core*width*scale*B.WidthScale;r.core.Width1=p.core*width*scale*.6*B.WidthScale;r.core.Enabled=width>.002
 if not r.detail then return end
 if charge~=nil and charge>=0 and charge<1 then
  acquireRich(r);drawRich(r,from,to,now,width,charge,releaseAge,scale,nil,chargeDuration)
 else
  local h=r.rich
  if h and not h.launched then
   h.launched=true
   if B.onChargeEnd then B.onChargeEnd(r) end
   if releaseAge and releaseAge>=0 and releaseAge<=.16 and B.onCue then B.onCue('launch',from,now,1) end
  end
  LaunchAftermath.fire(r,from,direction,now,releaseAge)
  -- Ignition overlaps the final color cuts by 80 ms at normal charge speed.
  -- Only the lens remains: inflow and charge audio end on authoritative release.
  if h and not h.startup and releaseAge and releaseAge>=0 and releaseAge<h.flashDuration*.1 then
   hideRich(r)
   local major=r.style=='Orbital' and 1 or r.style=='Singularity' and .34 or .2
   drawFlash(h,from,direction,.9+releaseAge/h.flashDuration,major*scale)
  else releaseRich(r) end
 end
 if r.rich and r.rich.startup then
  -- The selected cloud style is the charge silhouette, not another overlay.
  for _,v in ipairs(r.all) do if v.Enabled then v.Enabled=false end end
  if r.orb then r.orb.Transparency=1 end
  return
 end
 local gather,glint=0,0
 if charge~=nil then gather,glint=B.charge(charge) end
 local release=releaseAge and releaseAge>=0 and (1-clamp(releaseAge/.18))^2 or 0
 -- Restore the first version's small emitting glint. Release spreads in
 -- a fixed plane perpendicular to the laser; nothing turns into a bright ball.
 local energy=charge~=nil and gather or width
 local radius=p.orbit*scale
 if r.orb then r.orb.Transparency=1 end
 -- Regular lens charges hand their ring to the independent aftermath clock.
 if r.wantChargeLens and not r.startupStyle and r.style~='Repair' and r.style~='Courier' and r.style~='Branch' then
  PlaneBurst.hide(r.plane)
 else PlaneBurst.draw(r.plane,direction,releaseAge and releaseAge/1.1,scale) end
 for i=1,2 do
  local path=r.paths[i];path.beam.Enabled=false
  if charge==nil and (r.style=='Resonance' or r.style=='Repair') then
   local bend=(i==1 and 1 or -1)*.12*math.sin(now*1.3)
   pose(path.a,Vector3.zero,(direction+side*bend).Unit)
   pose(path.b,delta,(direction-side*bend).Unit)
   path.beam.CurveSize0=length*.33;path.beam.CurveSize1=length*.33
   path.beam.Width0=p.core*width*scale*.65*B.WidthScale;path.beam.Width1=0
   path.beam.Enabled=width>.02
  elseif charge==nil and (r.style=='Cutter' or r.style=='Combat' or r.style=='Lance' or r.style=='Sentry' or r.style=='Starforge') then
   local t=(now*1.7+(i-1)*.5)%1
   local visibility=math.sin(math.pi*t)^2
   path.a.Position=delta*t;path.b.Position=delta*math.min(1,t+.055)
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=p.core*width*scale*B.WidthScale*visibility;path.beam.Width1=0
   path.beam.Enabled=width>.02 and visibility>.02
  elseif charge==nil and r.style=='Courier' then
   local t=1-((now*.8+(i-1)*.5)%1)
   path.a.Position=delta*t;path.b.Position=delta*math.max(0,t-.12)
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=.035*energy*scale*B.WidthScale;path.beam.Width1=.012*energy*scale*B.WidthScale
   path.beam.Enabled=width>.02
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
