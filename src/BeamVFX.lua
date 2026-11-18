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
 Prism={body=.24,core=.079,taper=.78,orbit=0,spin=0,star=.20,tail=0},
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
function B.fadePrism(r,opacity)
 r.body.Transparency=sequence(1,1-.95*opacity,1-.92*opacity,1-.76*opacity)
 r.core.Transparency=sequence(1,1-.99*opacity,1-.98*opacity,1-.93*opacity)
 r.corona.Transparency=sequence(1,1-.25*opacity,1-.20*opacity,1-.06*opacity)
end
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
 local priority=style=='Orbital' or style=='Singularity' or style=='Prism'
 local limit=B.limits.rigs-(priority and 0 or B.limits.reservedRigs)
 if live>=limit or not parent then return nil end
 local root=Instance.new('Part');root.Name='BeamVFX';root.Transparency=1;root.Size=Vector3.one*.025
 root.Anchored=true;root.CanQuery=false;root.CanTouch=false;root.CanCollide=false;root.CastShadow=false
 root.Parent=parent
 local r={root=root,all={},style=style,color=color,profile=B.styles[style] or B.styles.Cutter}
 r.a=attachment(root,'Source');r.b=attachment(root,'Contact')
 r.body=ribbon(root,'TaperedBody',r.a,r.b,color,BODY);r.all[#r.all+1]=r.body
 r.core=ribbon(root,'NeedleCore',r.a,r.b,color:Lerp(WHITE,.65),CORE);r.all[#r.all+1]=r.core
 if style=='Prism' then
  r.body.Segments=20;r.core.Segments=20
  r.body.Brightness=1.45
  r.core.Color=ColorSequence.new(color:Lerp(WHITE,.86))
  r.core.Brightness=2.5
  r.corona=ribbon(root,'PrismCorona',r.a,r.b,color,EDGE);r.corona.Segments=20
  B.fadePrism(r,1)
  r.all[#r.all+1]=r.corona
 else r.body.Segments=1;r.core.Segments=1 end
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
 if not r or r.destroyed then return end
 if releaseRich then releaseRich(r) end
 r.root:Destroy()
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
local richLimit=8
local richPoolLimit=10 -- Mixed preview styles can need overlapping refraction rigs.
local richPool={} -- Six detached cached rigs maximum; active lease limit stays four.
function B.clearChargeCache()
 for _,h in ipairs(richPool) do h.root:Destroy() end
 table.clear(richPool)
end
local CYAN=Color3.fromRGB(108,238,255)
local VIOLET=Color3.fromRGB(166,64,255)
local FLARE_BLUE=Color3.fromRGB(70,170,255)
local FLARE_VIOLET=Color3.fromRGB(170,90,255)
local WISP_BLUE=Color3.fromRGB(44,36,255)
local BLACK=Color3.new(0,0,0)
local STONE=Color3.fromRGB(58,62,90)
local SOFT_GLOW='rbxasset://textures/ui/AvatarExperience/glowLight.png'
-- November 18, third pass. Built against real Studio renders this time.
-- What the first two passes got wrong and this one fixes:
--  * The game is bright daylight, so glowing lines washed out. A soft dark
--    "void" circle now grows behind the charge (always facing the camera) and
--    a soft colored aura sits on the core, so the neon has something to read
--    against, like the reference's darkened scene.
--  * The focus hangs below the cube instead of inside its belly.
--  * Every layer eases in and out; nothing blinks for a single frame.
--  * Real charges are either the long first ignition (about 2.6 s, the full
--    sequence) or a quick re-ignite between rocks (well under half a second,
--    one compact pop). The sequence is never squeezed into a flicker.
-- Sequence of the long charge, following the reference video: dark core and
-- void; cubes lift and circle; white bolts fall in faster and faster;
-- glittering ribbons spiral in; two lens flares orbit and close; rings
-- tighten; the core swells black and throws spikes; then the neon glitch
-- pops (flat two-color orb, blotches, RGB-split edge, blue wisps, spikes).
B.FULL_CHARGE=1.4 -- seconds; shorter charges use the compact re-ignite
B.GLITCH_TIME=.74 -- seconds of glitch at the end of a long charge
B.POP_TIME=.18 -- seconds per pop
B.GLITCH_TAIL=.07 -- seconds the last collapsing pop overlaps the beam
B.ORB_RADIUS=1.25 -- studs, first pop at scale 1
-- Two flat frames per pop: {base, blotch}. Never blended.
B.GLITCH_PAIRS={
 {Color3.fromRGB(255,255,0),Color3.fromRGB(255,0,0)},
 {Color3.fromRGB(255,0,170),BLACK},
 {Color3.fromRGB(255,0,0),Color3.fromRGB(255,255,0)},
 {Color3.fromRGB(0,255,60),BLACK},
 {Color3.fromRGB(0,40,255),Color3.fromRGB(0,255,60)},
 {Color3.fromRGB(0,255,60),BLACK},
 {Color3.fromRGB(0,40,255),Color3.fromRGB(0,255,60)},
 {Color3.fromRGB(0,40,255),BLACK},
}
B.GLITCH_SPLIT={Color3.fromRGB(0,255,255),Color3.fromRGB(255,0,255),Color3.fromRGB(255,255,0)}
local SOLID=NumberSequence.new(0)
local SOFT=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.05),NumberSequenceKeypoint.new(1,1)})
local HALO=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.7,.6),NumberSequenceKeypoint.new(1,1)})
local TRAIL=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.6,.25),NumberSequenceKeypoint.new(1,1)})
local WISP=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.4),NumberSequenceKeypoint.new(.7,.5),NumberSequenceKeypoint.new(1,1)})
local function visualPart(parent,name,material,color,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
 p.Transparency=1;p.Size=Vector3.one*.02;p.Material=material;p.Color=color
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function richPath(r,name,color,opacity)
 local p=pair(r.rich.root,name,color,opacity or ARC)
 p.beam.Width1=0;r.rich.paths[#r.rich.paths+1]=p;return p
end
-- A bright core line with a wider tinted glow around it.
local function glowPath(r,name,tint)
 local halo=richPath(r,name..'Glow',tint,HALO);halo.beam.LightEmission=.35;halo.beam.Brightness=1.6
 local core=richPath(r,name,WHITE,TRAIL);core.beam.LightEmission=1;core.beam.Brightness=2
 return {core=core,halo=halo}
end
releaseRich=function(r)
 local h=r.rich;if not h then return end
 if B.onChargeEnd and not h.launched then B.onChargeEnd(r) end
 hideRich(r);r.rich=nil
 if h.leased then h.leased=false;richLive-=1 end
 if h.particleSource then
  local source=h.particleSource
  if h.emitted then
   local tail=Instance.new('Part');tail.Name='LensParticleTail'
   tail.Anchored=true;tail.CanCollide=false;tail.CanQuery=false;tail.CanTouch=false;tail.CastShadow=false
   tail.Size=Vector3.one*.05;tail.Transparency=1;tail.CFrame=r.root.CFrame;tail.Parent=workspace
   h.particleSource=source:Clone()
   h.vapor=h.particleSource:FindFirstChild('VioletDistortionVapor')
   h.sparks=h.particleSource:FindFirstChild('LensDischargeSparks')
   source.Parent=tail
   game:GetService('Debris'):AddItem(tail,1.6)
  end
  h.particleSource.Parent=h.root
 end
 -- Glitter is world-space; parking its attachment leaves emitted specks alone.
 if h.glitterSource then h.glitterSource.Parent=h.root end
 h.emitted=nil;h.lastEmission=nil;h.lastGlitter=nil;h.lastVapor=nil;h.lastPulse=nil;h.launched=nil;h.root.Parent=nil
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
   if h.glitterSource then h.glitterSource.Parent=r.root end
   return
  end
 end
 -- A Part (not a Folder) so beam attachments resolve relative to the focus.
 local folder=visualPart(r.root,'RefractionChoreography',Enum.Material.SmoothPlastic,WHITE)
 folder.CFrame=r.root.CFrame
 local h={root=folder,paths={},comets={},sweeps={},bolts={},debris={},blotches={},spikes={},wisps={},rings={},flares={},
  lastEmission=nil,key=key,leased=true}
 r.rich=h;richLive+=1
 folder.Destroying:Connect(function() if h.leased then h.leased=false;richLive-=1 end end)
 if r.startupStyle then
  h.startup=StartupFX.create(folder,r.startupStyle,1)
  return
 end
 h.glass=visualPart(folder,'ChromaticRelease',Enum.Material.Neon,B.GLITCH_PAIRS[1][1],Enum.PartType.Ball)
 for i=1,4 do h.blotches[i]=visualPart(folder,'GlitchBlotch'..i,Enum.Material.Neon,BLACK,Enum.PartType.Ball) end
 h.split=visualPart(folder,'GlitchSplit',Enum.Material.Neon,B.GLITCH_SPLIT[1],Enum.PartType.Ball)
 h.core=visualPart(folder,'ChargeOriginCore',Enum.Material.SmoothPlastic,DARK,Enum.PartType.Ball)
 h.rim=visualPart(folder,'ChargeOriginRim',Enum.Material.Neon,VIOLET,Enum.PartType.Ball)
 -- Soft dark circle behind everything, and a soft colored glow on the core.
 h.void=EnergyDisc.sprite(h.glass,'ChargeVoid');h.void.image.Image=SOFT_GLOW
 h.aura=EnergyDisc.sprite(h.glass,'ChargeAura');h.aura.image.Image=SOFT_GLOW
 for i=1,3 do
  local line=glowPath(r,'InwardStream'..i,CYAN)
  h.comets[i]={path=line.core,halo=line.halo,head=EnergyDisc.sprite(h.glass,'InwardSpark')}
 end
 for i=1,2 do
  local edge=richPath(r,'SlashEdge'..i,WHITE,ARC)
  local ink=richPath(r,'SlashInk'..i,DARK,ARC)
  ink.beam.LightEmission=0
  h.sweeps[i]={edge=edge,ink=ink}
 end
 for i=1,3 do
  local line=glowPath(r,'IncomingBolt'..i,CYAN)
  h.bolts[i]={path=line.core,halo=line.halo,head=EnergyDisc.sprite(h.glass,'BoltHead')}
 end
 for i=1,4 do
  local path=richPath(r,'WedgeSpike'..i,WHITE,SOLID);path.beam.Segments=1;path.beam.LightEmission=1
  h.spikes[i]=path
 end
 for i=1,3 do
  local path=richPath(r,'GlitchWisp'..i,WISP_BLUE,WISP);path.beam.LightEmission=.3
  h.wisps[i]=path
 end
 for i=1,2 do
  h.rings[i]={richPath(r,'CoreRing'..i..'A',WHITE,ARC),richPath(r,'CoreRing'..i..'B',WHITE,ARC)}
 end
 for i=1,2 do
  local color=i==1 and FLARE_BLUE or FLARE_VIOLET
  local wide=richPath(r,'LensFlare'..i,color,SOFT);wide.beam.Segments=10;wide.beam.LightEmission=.4;wide.beam.Brightness=1.8
  local core=richPath(r,'LensFlareCore'..i,WHITE,SOFT);core.beam.Segments=10;core.beam.LightEmission=1
  local glow=EnergyDisc.sprite(h.glass,'FlareGlow');glow.image.Image=SOFT_GLOW
  h.flares[i]={wide=wide,core=core,glow=glow,color=color}
 end
 h.flare=h.flares[1].wide
 for i=1,8 do h.debris[i]=visualPart(folder,'LiftedCube'..i,Enum.Material.SmoothPlastic,STONE) end
 h.vapor=Instance.new('ParticleEmitter');h.vapor.Name='VioletDistortionVapor'
 EnergyDisc.smoke(h.vapor,1.1,.72)
 h.vapor.Enabled=false;h.vapor.Rate=0;h.vapor.Color=ColorSequence.new(VIOLET)
 h.vapor.Lifetime=NumberRange.new(.8,1.5);h.vapor.Speed=NumberRange.new(.6,1.6);h.vapor.Drag=2.5
 h.vapor.SpreadAngle=Vector2.new(180,180);h.vapor.Acceleration=Vector3.new(0,.5,0)
 h.particleSource=attachment(r.root,'LensParticleSource');h.vapor.Parent=h.particleSource
 h.sparks=Instance.new('ParticleEmitter');h.sparks.Name='LensDischargeSparks'
 EnergyDisc.configure(h.sparks,.67,.57,.60,.42)
 h.sparks.Enabled=false;h.sparks.Rate=0;h.sparks.Color=ColorSequence.new(CYAN)
 h.sparks.Lifetime=NumberRange.new(.26,.52);h.sparks.Speed=NumberRange.new(2,5);h.sparks.Drag=5;h.sparks.SpreadAngle=Vector2.new(180,180)
 h.sparks.Acceleration=Vector3.new(0,-1,0);h.sparks.Parent=h.particleSource
 -- Round glitter dots left along the ribbons (world space, stay where dropped).
 h.glitterSource=attachment(r.root,'InflowGlitterSource')
 h.glitter=Instance.new('ParticleEmitter');h.glitter.Name='InflowGlitter'
 h.glitter.Texture=EnergyDisc.texture;h.glitter.LightEmission=1;h.glitter.LightInfluence=0;h.glitter.Brightness=2.5
 h.glitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16),NumberSequenceKeypoint.new(1,0)})
 h.glitter.Transparency=NumberSequence.new(0,1);h.glitter.Lifetime=NumberRange.new(.35,.7)
 h.glitter.Speed=NumberRange.new(0,.4);h.glitter.SpreadAngle=Vector2.new(180,180);h.glitter.Drag=3
 h.glitter.Enabled=false;h.glitter.Rate=0;h.glitter.LockedToPart=false;h.glitter.Color=ColorSequence.new(WHITE,CYAN)
 h.glitter.Parent=h.glitterSource
 folder.Destroying:Connect(function() h.particleSource:Destroy();h.glitterSource:Destroy() end)
end
hideRich=function(r)
 local h=r.rich;if not h then return end
 if h.startup then StartupFX.hide(h.startup);return end
 h.glass.Transparency=1;h.core.Transparency=1;h.rim.Transparency=1;h.split.Transparency=1
 for _,p in ipairs(h.blotches) do p.Transparency=1 end
 for _,p in ipairs(h.paths) do p.beam.Enabled=false end
 for _,p in ipairs(h.debris) do p.Transparency=1 end
 for _,p in ipairs(h.comets) do p.head.gui.Enabled=false end
 for _,p in ipairs(h.bolts) do p.head.gui.Enabled=false end
 for _,p in ipairs(h.flares) do p.glow.gui.Enabled=false end
 h.void.gui.Enabled=false;h.aura.gui.Enabled=false
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
local function off(path)
 if path.beam.Enabled then path.beam.Enabled=false end
end
local function hash(n)
 local x=math.sin(n*12.9898)*43758.5453
 return x-math.floor(x)
end
-- When the glitch starts (0..1 of the charge) and how many pops fit.
function B.glitchPlan(duration)
 duration=math.max(.01,duration or .8)
 if duration<B.FULL_CHARGE then return .4,1 end
 local span=math.min(B.GLITCH_TIME,duration*.3)
 return 1-span/duration,math.clamp(math.floor(span/B.POP_TIME+.5),1,4)
end
-- Which pop the charge is in: index, 0..1 progress through it, pop count.
function B.glitchState(q,duration)
 if q==nil then return nil end
 local start,count=B.glitchPlan(duration)
 if q<start then return nil end
 local x=clamp((q-start)/(1-start))*count
 local k=math.min(count,math.floor(x)+1)
 return k,clamp(x-(k-1)),count
end
-- Orb size inside one pop: a very fast swell, then a quick shrink. Later pops are smaller.
function B.popSize(k,u)
 u=clamp(u)
 return (1-.13*(k-1))*smooth(u/.1)*(1-.82*clamp((u-.1)/.9)^.75)
end
local function hideOrb(h)
 h.glass.Transparency=1;h.split.Transparency=1
 for _,p in ipairs(h.blotches) do p.Transparency=1 end
end
local function drawOrb(h,center,radius,frame)
 h.glass.CFrame=CFrame.new(center)
 if radius<=.01 then hideOrb(h);return 0 end
 local player=Players.LocalPlayer
 local gentle=player and player:GetAttribute('ReducedFlashing')==true
 local colors=B.GLITCH_PAIRS[(frame-1)%#B.GLITCH_PAIRS+1]
 h.glass.Size=Vector3.one*radius*2;h.glass.Color=colors[1]
 h.glass.Transparency=gentle and .6 or 0
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.xAxis
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 local back=camera and -camera.CFrame.LookVector or Vector3.zAxis
 local side=(frame%2==0) and 1 or -1
 h.split.Size=Vector3.one*radius*2.05;h.split.Color=B.GLITCH_SPLIT[frame%#B.GLITCH_SPLIT+1]
 h.split.CFrame=CFrame.new(center+right*side*radius*.16-back*radius*.1)
 h.split.Transparency=gentle and .75 or 0
 for i,p in ipairs(h.blotches) do
  local a=hash(frame*7+i)*TAU;local b=hash(frame*13+i*3)*.9-.45
  local dir=back+right*math.cos(a)*1.1+up*math.sin(a)*1.1+up*b
  dir=dir.Magnitude>.01 and dir.Unit or back
  local blotch=radius*(i<=2 and .62 or .5)*(.8+.4*hash(frame*5+i))
  p.Size=Vector3.one*blotch*2
  p.CFrame=CFrame.new(center+dir*(radius-blotch*.55))
  p.Color=i<=2 and colors[2] or BLACK
  p.Transparency=gentle and .65 or 0
 end
 return radius
end
-- Flat wedges in the view plane: zero width at the orb, wide at the tip.
local function drawSpikes(h,k,seed,strength,inner,colors)
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.xAxis
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 for i,path in ipairs(h.spikes) do
  if strength<=.01 or hash(seed*3.1+i)<.15 then off(path) else
   local a=hash(seed*5.3+i*1.7)*TAU
   local dir=right*math.cos(a)+up*math.sin(a)
   local length=k*(1.6+2*hash(seed+i*2.3))*strength
   path.a.Position=dir*inner;path.b.Position=dir*(inner+length)
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=0;path.beam.Width1=k*(.3+.45*hash(seed*2+i))*strength
   path.beam.Color=ColorSequence.new(colors[(i-1)%#colors+1])
   path.beam.Enabled=true
  end
 end
end
local SPIKE_PALE={WHITE,CYAN,WHITE,Color3.fromRGB(190,220,255)}
-- Where the charge gathers: a little below the emitter, on the beam line.
function B.focus(from,to,k)
 local delta=to-from
 local length=delta.Magnitude
 if length<.01 then return from,Vector3.new(0,-1,0) end
 local direction=delta/length
 return from+direction*math.min(1.7*k,length*.4),direction
end
local function chargeScale(r,scale)
 return (r.style=='Orbital' and 2.2 or r.style=='Singularity' and 1.1 or 1)*(scale or 1)
end
drawRich=function(r,from,to,now,width,charge,releaseAge,scale,afterAge,chargeDuration)
 local h=r.rich;if not h then return end
 if charge==nil or charge<0 or charge>=1 or afterAge then hideRich(r);return end
 if B.onCharge then B.onCharge(r,from,now,charge) end
 if h.startup then StartupFX.update(h.startup,CFrame.new(from),charge);return end
 local q=charge
 local k=chargeScale(r,scale)
 local duration=math.max(.01,chargeDuration or .8)
 local full=duration>=B.FULL_CHARGE
 -- A quick re-ignite stays compact so a busy field does not strobe.
 local snap=full and 1 or math.clamp(duration/.4,.45,1)*.7
 local t=q*duration
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local focus,direction=B.focus(from,to,k)
 local eye=camera and camera.CFrame.Position-focus or Vector3.zAxis*40
 local toward=eye.Magnitude>.01 and eye.Unit or Vector3.zAxis
 h.root.CFrame=CFrame.new(focus)
 h.scale=k;h.duration=duration
 if h.tint~=r.color then
  h.tint=r.color
  h.vapor.Color=ColorSequence.new(r.color:Lerp(DARK,.35));h.sparks.Color=ColorSequence.new(r.color)
  h.rim.Color=r.color:Lerp(VIOLET,.5)
  for _,item in ipairs(h.comets) do item.halo.beam.Color=ColorSequence.new(r.color:Lerp(CYAN,.5)) end
  for _,item in ipairs(h.bolts) do item.halo.beam.Color=ColorSequence.new(r.color:Lerp(WHITE,.25)) end
  for _,item in ipairs(h.sweeps) do item.edge.beam.Color=ColorSequence.new(r.color:Lerp(WHITE,.7)) end
 end
 LaunchAftermath.charge(r,from,direction,now,q,scale)
 local across=direction:Cross(math.abs(direction.Y)>.94 and Vector3.zAxis or Vector3.yAxis).Unit
 local upright=across:Cross(direction).Unit
 local pop,u,pops=B.glitchState(q,duration)
 h.pop=pop;h.pops=pops
 -- Inflow layers hand over to the glitch across a short blend, not a cut.
 local start=B.glitchPlan(duration)
 local calm=1-smooth((q-start+.03)/.03)
 local build=smooth(q/(full and .55 or .3)) -- overall gathering strength
 -- Void: the dark the neon reads against. It swells with the charge.
 local voidSize=k*snap*(4+9*build)*(1+.04*math.sin(now*5))
 if pop then voidSize=k*snap*(11+2.5*B.popSize(pop,u)) end
 EnergyDisc.place(h.void,focus-toward*3*k,voidSize,BLACK,.9*smooth(q/.12))
 -- Core: small and dark with a bright rim; it swells black before the glitch.
 local swell=full and math.sin(math.pi*clamp((q-.58)/(start-.58))) or 0
 local coreRadius=k*snap*(.16+.16*build+.62*swell)
 local alive=smooth(q/.06)*calm
 h.core.CFrame=CFrame.new(focus);h.core.Size=Vector3.one*coreRadius*2
 h.core.Color=swell>.2 and BLACK or DARK
 h.core.Transparency=1-alive
 h.rim.CFrame=CFrame.new(focus-toward*coreRadius*.2);h.rim.Size=Vector3.one*coreRadius*(2.5+.2*math.sin(now*9))
 h.rim.Transparency=1-alive*(.45-.3*swell)
 EnergyDisc.place(h.aura,focus-toward*.4*k,k*snap*(1.6+2.4*build+1.5*swell)*(1+.06*math.sin(now*11)),
  r.color:Lerp(VIOLET,.35),(.35+.3*build)*smooth(q/.08)*calm)
 h.particleSource.WorldPosition=focus+toward*k*.4
 -- Glitch orb.
 local orbRadius=0
 if pop then
  local frame=(pop-1)*2+(u>.55 and 2 or 1)
  local player=Players.LocalPlayer
  if player and player:GetAttribute('ReducedFlashing')==true then frame=(pop-1)*2+1 end
  if not full then frame=frame+math.floor(now*.9)%4*2 end -- re-ignites vary their colors
  h.frame=frame
  orbRadius=drawOrb(h,focus,B.ORB_RADIUS*k*snap*B.popSize(pop,u),frame)
 else hideOrb(h) end
 h.orbRadius=orbRadius
 -- Wedge spikes ease out as the black core peaks and at the low point of each pop.
 if pop and u>.55 then
  local colors=B.GLITCH_PAIRS[(h.frame-1)%#B.GLITCH_PAIRS+1]
  drawSpikes(h,k*snap,pop*11+1,smooth((u-.55)/.2),orbRadius,pop%2==0 and {colors[1],WHITE,CYAN,Color3.fromRGB(255,255,0)} or SPIKE_PALE)
 elseif not pop and swell>.6 then
  drawSpikes(h,k,7,smooth((swell-.6)/.3),coreRadius,SPIKE_PALE)
 else drawSpikes(h,k,0,0,0,SPIKE_PALE) end
 -- Blue wisps wrap the orb; each flat frame has its own layout.
 for i,path in ipairs(h.wisps) do
  if not pop then off(path) else
   local seed=h.frame*17+i*5
   local a0=hash(seed)*TAU;local span=1.1+.7*hash(seed+1)
   local radius=orbRadius*(1.25+.35*i)+k*snap*(.35+.25*i)
   local tilt=(hash(seed+2)-.5)*1.2
   local e1=(across*math.cos(tilt)+direction*math.sin(tilt)).Unit
   local function at(a) return e1*math.cos(a)*radius+upright*math.sin(a)*radius end
   local function tan(a) return (-e1*math.sin(a)+upright*math.cos(a)).Unit end
   curve(path,at(a0),at(a0+span),tan(a0),tan(a0+span),radius*span/3,k*snap*(.35+.3*hash(seed+3)))
   path.beam.Width1=k*.05
  end
 end
 -- Thin rings tighten around the core and hug the orb through the glitch.
 local ringAlpha=smooth((q-(full and .42 or .1))/.12)
 for i,ring in ipairs(h.rings) do
  local radius=(pop and orbRadius*1.12+k*snap*(.12+.16*i) or coreRadius+k*snap*(.5+.5*i)*(1.6-.6*build))
  local tilt=.5+i*.9+now*(i==1 and .9 or -.65)
  local e1=(across*math.cos(tilt)+direction*math.sin(tilt)*.55).Unit
  local e2=e1:Cross(toward).Unit
  local widthNow=k*.045*ringAlpha
  curve(ring[1],e1*radius,-e1*radius,e2,-e2,radius*4/3,widthNow);ring[1].beam.Width1=widthNow
  curve(ring[2],-e1*radius,e1*radius,-e2,e2,radius*4/3,widthNow);ring[2].beam.Width1=widthNow
 end
 -- Cubes lift from below, circle slowly, tumble, and get drawn in at the end.
 local gather=smooth((q-.55)/.4)
 for i,cube in ipairs(h.debris) do
  if not full then cube.Transparency=1 else
   local begin=.02+.035*i
   local lift=smooth((q-begin)/.4)
   local angle=i*2.399963+now*(.35+.05*(i%3))
   local radial=across*math.cos(angle)+upright*math.sin(angle)
   local ring=k*(2.3+2*hash(i+2))*(1-.45*gather)
   local below=k*(7+2*hash(i+9))*(1-lift)+k*(2.6*hash(i+4)-1.1)
   local bob=k*.2*math.sin(now*1.9+i)
   cube.Size=Vector3.one*k*(.3+.32*hash(i+6))
   cube.CFrame=CFrame.new(focus+direction*(below+bob)+radial*ring)*CFrame.Angles(now*(.7+i*.13),now*(1.1-i*.09),i)
   cube.Transparency=1-smooth((q-begin)/.1)
  end
 end
 -- Crescent slashes sweep past the core; width eases in and out.
 for i,item in ipairs(h.sweeps) do
  local clock=t/.26+(i-1)*.5
  local n=math.floor(clock);local phase=clock-n
  local seed=n*3.7+i*19
  local strength=full and math.sin(math.pi*phase)^2*calm*smooth(q/.08) or 0
  if strength<.02 or hash(seed)<.25 then off(item.edge);off(item.ink) else
   local radius=k*(1.1+1.3*hash(seed+1))
   local tilt=(hash(seed+2)-.5)*2.4
   local e1=(across*math.cos(tilt)+direction*math.sin(tilt)).Unit
   local a0=hash(seed+3)*TAU+phase*2.2
   local span=1.1
   local function at(a) return e1*math.cos(a)*radius+upright*math.sin(a)*radius end
   local function tan(a) return (-e1*math.sin(a)+upright*math.cos(a)).Unit end
   curve(item.edge,at(a0+span),at(a0),-tan(a0+span),-tan(a0),radius*span/3,k*.26*strength)
   curve(item.ink,at(a0+span),at(a0),-tan(a0+span),-tan(a0),radius*span/3,k*.16*strength)
  end
 end
 -- White bolts fall into the core, arriving faster and faster.
 for i,bolt in ipairs(h.bolts) do
  local clock,phase,n
  if full then
   clock=t/.5+q*t/.42+(i-1)/3
   n=math.floor(clock);phase=(clock-n)/.72
  else
   n=i;phase=(q-(i-1)*.16)/.5
  end
  local seed=n*5.1+i*31
  if phase<0 or phase>1 or q>.97 or (full and hash(seed)<.15) then
   off(bolt.path);off(bolt.halo);bolt.head.gui.Enabled=false
  else
   local a=hash(seed+1)*TAU
   local dir=(across*math.cos(a)+upright*math.sin(a)+direction*(hash(seed+2)*1.1-.3)).Unit
   local far=k*snap*(5.5+2.5*hash(seed+4))
   local function distance(p) return far*(1-clamp(p)^2.2)+k*.15 end
   local head=dir*distance(phase)
   local tail=dir*distance(phase-.28)
   local fade=smooth(phase/.15)*(1-smooth((phase-.88)/.12))
   local sideways=dir:Cross(toward)
   sideways=sideways.Magnitude>.01 and sideways.Unit or across
   local kink=(hash(seed+3)-.5)*.5
   local span=(tail-head).Magnitude
   local ta,tb=(dir+sideways*kink).Unit,(dir-sideways*kink).Unit
   curve(bolt.path,head,tail,ta,tb,span*.3,k*snap*.2*fade)
   curve(bolt.halo,head,tail,ta,tb,span*.3,k*snap*.5*fade)
   EnergyDisc.place(bolt.head,focus+head,k*snap*.42,WHITE,fade)
  end
 end
 -- Glittering ribbons spiral in through the air.
 local heads={}
 for i,item in ipairs(h.comets) do
  local p=full and clamp((q-.14-(i-1)*.05)/.42) or 0
  local index=i*3-2
  local _,_,captured=PullMotion.sample(index,0)
  local a,va=PullMotion.sample(index,p*captured)
  local b,vb=PullMotion.sample(index,math.max(0,p*captured-.3))
  local visible=full and smooth(p/.1)*(1-smooth((p-.88)/.12))*calm or 0
  local arch=Vector3.yAxis*k*(i==1 and 1.5 or i==2 and .8 or .3)
  local head=a*k*1.45+arch*math.sin(math.pi*p)
  local tail=b*k*1.45+arch*math.sin(math.pi*math.max(0,p-.25))
  local span=(tail-head).Magnitude
  if visible>.01 and va.Magnitude>.01 and vb.Magnitude>.01 and span>.002 then
   curve(item.path,head,tail,-va.Unit,-vb.Unit,span*.3,k*.2*visible)
   curve(item.halo,head,tail,-va.Unit,-vb.Unit,span*.3,k*.55*visible)
   heads[#heads+1]=focus+head;heads[#heads+1]=focus+head:Lerp(tail,.35);heads[#heads+1]=focus+head:Lerp(tail,.7)
  else off(item.path);off(item.halo) end
  EnergyDisc.place(item.head,focus+head,k*.36,WHITE,visible)
 end
 -- Lens flares orbit on opposite sides and close in on the core.
 local fp=full and clamp((q-.36)/(start-.36)) or 0
 local flareAlpha=full and math.sin(math.pi*fp)^.6*calm or 0
 for i,flare in ipairs(h.flares) do
  if flareAlpha<=.01 then
   off(flare.wide);off(flare.core);flare.glow.gui.Enabled=false
  else
   local angle=.6+(i-1)*math.pi+2.6*fp
   local radius=k*(3-2.5*smooth(fp))
   local center=(across*math.cos(angle)+upright*math.sin(angle))*radius+direction*k*.4
   local length=k*(2+2.2*math.sin(math.pi*fp))*(.94+.06*math.sin(now*43+i))
   flare.wide.a.Position=center-right*length;flare.wide.b.Position=center+right*length
   flare.core.a.Position=center-right*length*.6;flare.core.b.Position=center+right*length*.6
   flare.wide.beam.Width0=k*.42*flareAlpha;flare.wide.beam.Width1=flare.wide.beam.Width0
   flare.core.beam.Width0=k*.12*flareAlpha;flare.core.beam.Width1=flare.core.beam.Width0
   flare.wide.beam.Enabled=true;flare.core.beam.Enabled=true
   EnergyDisc.place(flare.glow,focus+center,k*1.5,flare.color:Lerp(WHITE,.35),flareAlpha*.75)
  end
 end
 -- Never emit catch-up batches after a late observer or paused render loop.
 if smooth(q/.12)*calm>.05 then
  if h.lastEmission and now>=h.lastEmission+.09 then
   h.sparks:Emit(1);h.lastEmission=now;h.emitted=true
  elseif not h.lastEmission or now<h.lastEmission then h.lastEmission=now end
  if #heads>0 and (not h.lastGlitter or now<h.lastGlitter or now>=h.lastGlitter+.016) then
   h.lastGlitter=now
   h.glitterSource.WorldPosition=heads[math.floor(now*97)%#heads+1]
   h.glitter:Emit(1)
  end
  if full and q>.25 and (not h.lastVapor or now<h.lastVapor or now>=h.lastVapor+.35) then
   h.lastVapor=now;h.vapor:Emit(1);h.emitted=true
  end
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
 local thickness=p.body*width*scale*B.WidthScale*(1+launchPressure*(r.style=='Prism' and .10 or .35))
 r.body.Width0=thickness;r.body.Width1=thickness*p.taper;r.body.Enabled=width>.002
 r.core.Width0=p.core*width*scale*B.WidthScale;r.core.Width1=p.core*width*scale*.6*B.WidthScale;r.core.Enabled=width>.002
 if r.corona then
  r.corona.Width0=thickness*(3.4+launchPressure*1.5);r.corona.Width1=thickness*2.3
  r.corona.Enabled=not reduced and width>.08
 end
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
  -- The last pop keeps collapsing over the first frames of the beam. Only
  -- the orb remains: inflow and charge audio end on authoritative release.
  if h and not h.startup and releaseAge and releaseAge>=0 and releaseAge<B.GLITCH_TAIL then
   hideRich(r)
   local k=h.scale or chargeScale(r,scale)
   local focus=B.focus(from,to,k)
   local _,pops=B.glitchPlan(h.duration)
   local remaining=1-releaseAge/B.GLITCH_TAIL
   local snap=(h.duration or 1)>=B.FULL_CHARGE and 1 or math.clamp((h.duration or .4)/.4,.45,1)*.7
   drawOrb(h,focus,B.ORB_RADIUS*k*snap*B.popSize(pops,1)*remaining,h.frame or pops*2)
   local camera=workspace.CurrentCamera
   local toward=camera and (camera.CFrame.Position-focus).Unit or Vector3.zAxis
   EnergyDisc.place(h.void,focus-toward*3*k,k*snap*11*(1+.4*(1-remaining)),Color3.new(0,0,0),.9*remaining)
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
