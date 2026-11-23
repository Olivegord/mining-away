-- Client-only color and particle accents for the cube fleet and the square
-- fields. Purely cosmetic: no remotes, damage, rewards or timing. Bundled
-- inside Presentation (exposed as Presentation.Fun) to avoid another
-- top-level local in the client controller.
local Fun={}
local SQUARE='rbxasset://textures/particles/SquareParticle.png'
local SPARKLE='rbxasset://textures/particles/sparkles_main.dds'
local WHITE=Color3.new(1,1,1)
local rgb=Color3.fromRGB
-- Bright, friendly hues that stay distinct from each other and from stone.
Fun.Palette={
 rgb(255,92,120), -- coral
 rgb(66,196,255), -- sky
 rgb(132,226,74), -- lime
 rgb(255,196,44), -- sunflower
 rgb(190,104,255),-- grape
 rgb(255,138,54), -- tangerine
 rgb(40,222,190), -- teal
 rgb(255,120,214),-- bubblegum
}
-- Each square field gets one vivid signature color (CrystalZone order).
Fun.ZoneColors={rgb(255,170,40),rgb(255,72,96),rgb(80,190,255),rgb(176,102,255),rgb(255,150,232)}
local MINERAL={Amber=1,RunRuby=2,Ruby=2,RunQuartz=3,Quartz=3,RunCobalt=3,RunViolet=4,Violet=4,Diamond=5,RunEmerald=5}
function Fun.mineralColor(name)
 local zone=MINERAL[name or '']
 return zone and Fun.ZoneColors[zone] or nil
end
local function reduced()
 local ok,value=pcall(function() return game:GetService('GuiService').ReducedMotionEnabled end)
 return ok and value==true
end
Fun.reduced=reduced
local function hash(text)
 local h=0
 for i=1,#text do h=(h*31+string.byte(text,i))%2147483647 end
 return h
end
function Fun.colorFor(id)
 local n=tonumber(id)
 local index=(n and math.floor(n) or hash(tostring(id)))%#Fun.Palette+1
 return Fun.Palette[index]
end
local function bare(parent,name,size,color,material,class)
 local p=Instance.new(class or 'Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.CastShadow=false;p.Size=size;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Parent=parent
 return p
end
local function attach(part,body,offset)
 -- Model:PivotTo moves every part of the render clone rigidly, so accents
 -- stay anchored at a fixed offset from the hull.
 part.CFrame=body.CFrame*offset
end
-- Paint a drone's local render clone. Returns a small record for stepCube.
Fun.CUBE_VIEW_SCALE=.56
local function muted(c,k)
 local l=c.R*.3+c.G*.59+c.B*.11
 return c:Lerp(Color3.new(l,l,l),k or .45)
end
-- Fun.rolePrimary(role) -> Color3 and Fun.roleStyle(role) -> DigCube style are
-- installed by the client controller from the DigCubeView statics (nil until then).
-- Owner, Nov 22: "all drones ... look the exact same, they just have
-- different skins". Every type now has its own body: its own shape, size,
-- proportions and moving parts (Fun.BODIES), in its own color, and every
-- drone of one type looks exactly the same. The Striker stays the classic
-- cube. One small glowing part per body (its eye, lens or core) is where
-- its attack comes from; nothing else on a drone glows or sheds particles.
Fun.ROLE_SECONDARY={
 Striker=rgb(255,236,200),Charger=rgb(255,214,90),Ballcaster=rgb(255,120,214),Needler=rgb(40,222,190),
 Bubbler=rgb(200,240,255),Halver=rgb(232,236,255),Gridcutter=rgb(70,226,255),Singularity=rgb(255,96,206),
 Starforge=rgb(255,220,120),Frostbite=rgb(244,252,255),Resonator=rgb(240,255,120),Ramiel=rgb(255,176,186),
 Nomad=rgb(255,112,64),Lancer=rgb(255,70,86),
}
local NEUTRAL=rgb(150,160,172)
function Fun.accentFor(primary,role)
 return Fun.ROLE_SECONDARY[role or ''] or (primary and primary:Lerp(WHITE,.45)) or NEUTRAL
end
-- How much bigger or smaller a type's body is than the standard one.
Fun.ROLE_SCALE={Charger=1.3,Needler=.8,Singularity=1.08,Ramiel=1.05,Lancer=.95,Ballcaster=1,Gridcutter=1.05,Bubbler=1.1,Nomad=1.1}
-- Where the attack leaves the body (the beam's origin), in body sizes below its middle.
Fun.ROLE_BELLY={Striker=.55,Charger=.55,Ballcaster=.62,Needler=.3,Bubbler=.68,Halver=.5,Gridcutter=.5,Singularity=.5,
 Starforge=.62,Frostbite=.48,Resonator=.78,Ramiel=.72,Nomad=.95,Lancer=1.15}
-- How each type floats while it follows you: bob height (studs) and speed
-- (Hz), how far it leans into turns, and a small hover jitter. Read by the
-- client's drone renderer.
Fun.MOTION={
 Striker={bob=.12,hz=.14},Charger={bob=.05,hz=.08,lean=.6},Ballcaster={bob=.16,hz=.12},Needler={bob=.05,hz=.45,lean=1.6,jitter=.035},
 Bubbler={bob=.38,hz=.09,lean=.4},Halver={bob=.1,hz=.15},Gridcutter={bob=.02,hz=.1,lean=0},Singularity={bob=.18,hz=.07,lean=.5},
 Starforge={bob=.14,hz=.16},Frostbite={bob=.1,hz=.12},Resonator={bob=.08,hz=.2,jitter=.02},Ramiel={bob=.22,hz=.06,lean=0},
 Nomad={bob=.06,hz=.1,lean=1.2},Lancer={bob=.08,hz=.16,lean=1.1},
}
local DARK=rgb(32,34,44)
local NEON=Enum.Material.Neon
local METAL=Enum.Material.Metal
local GLASS=Enum.Material.Glass
-- One part of a body, fixed to the hull at `offset` (studs, hull space).
local function piece(view,body,name,shape,size,offset,color,material,transparency)
 local class=shape=='Wedge' and 'WedgePart' or nil
 local p=bare(view,name,size,color,material,class)
 if shape=='Ball' or shape=='Cylinder' then p.Shape=Enum.PartType[shape] end
 p.Transparency=transparency or 0
 -- Solid bodies cast a shadow on the rock, so you can tell where they hover.
 p.CastShadow=material~=NEON and (transparency or 0)<.5
 attach(p,body,offset)
 return p
end
local UP=CFrame.Angles(0,0,math.pi/2) -- a cylinder standing up (its axis is X)
local ALONG=CFrame.Angles(0,math.pi/2,0) -- a cylinder lying along Z
local BODIES={}
-- Striker, the classic miner: the cube, a white lid, a dark visor and a lens underneath.
BODIES.Striker=function(v,b,u,col,acc,core,anim)
 b.Transparency=0
 piece(v,b,'TypeLid','Block',Vector3.new(u*.88,u*.08,u*.88),CFrame.new(0,u*.5+.035,0),col:Lerp(WHITE,.6))
 piece(v,b,'TypeVisor','Block',Vector3.new(u*.8,u*.2,u*.06),CFrame.new(0,u*.12,-u*.51),DARK)
 piece(v,b,'TypeLens','Cylinder',Vector3.new(u*.1,u*.52,u*.52),CFrame.new(0,-u*.52,0)*UP,core,NEON)
end
-- Charger, the heavy: a wide anvil over a dark hammer block with a glowing face, and two horns.
BODIES.Charger=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeAnvil','Block',Vector3.new(u*1.5,u*.5,u*1.05),CFrame.new(0,u*.18,0),col)
 piece(v,b,'TypeAnvilTop','Block',Vector3.new(u*1.36,u*.07,u*.92),CFrame.new(0,u*.46,0),col:Lerp(WHITE,.4))
 piece(v,b,'TypeHammer','Block',Vector3.new(u*.8,u*.42,u*.8),CFrame.new(0,-u*.27,0),DARK:Lerp(col,.3),METAL)
 piece(v,b,'TypeFace','Block',Vector3.new(u*.84,u*.06,u*.84),CFrame.new(0,-u*.5,0),core,NEON)
 for side=-1,1,2 do piece(v,b,'TypeHorn','Wedge',Vector3.new(u*.16,u*.44,u*.4),CFrame.new(side*u*.6,u*.64,-u*.28),acc) end
end
-- Ballcaster: a sphere in a dark belt, its charged orb glowing underneath.
BODIES.Ballcaster=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeSphere','Ball',Vector3.one*u*1.08,CFrame.new(),col)
 piece(v,b,'TypeBelt','Cylinder',Vector3.new(u*.16,u*1.18,u*1.18),UP,DARK)
 piece(v,b,'TypeOrb','Ball',Vector3.one*u*.42,CFrame.new(0,-u*.44,0),core,NEON)
end
-- Needler: a slim dart with a steel nose and three tail fins.
BODIES.Needler=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeShaft','Cylinder',Vector3.new(u*1.5,u*.34,u*.34),ALONG,col)
 piece(v,b,'TypeNose','Block',Vector3.one*u*.26,CFrame.new(0,0,-u*.78)*CFrame.Angles(math.pi/4,0,math.pi/4),acc:Lerp(WHITE,.3),METAL)
 for k=0,2 do
  piece(v,b,'TypeFin','Wedge',Vector3.new(u*.05,u*.34,u*.34),CFrame.new(0,0,u*.6)*CFrame.Angles(0,0,k*math.pi*2/3)*CFrame.new(0,u*.25,0),acc)
 end
 piece(v,b,'TypeTip','Ball',Vector3.one*u*.16,CFrame.new(0,-u*.22,-u*.2),core,NEON)
end
-- Bubbler: a glass bubble with a solid core bobbing inside it.
BODIES.Bubbler=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeBubble','Ball',Vector3.one*u*1.25,CFrame.new(),acc,GLASS,.55)
 local inner=piece(v,b,'TypeCore','Ball',Vector3.one*u*.5,CFrame.new(),col)
 table.insert(anim,{part=inner,base=CFrame.new(),mode='bob',amp=u*.12,hz=.35})
 piece(v,b,'TypeGlint','Ball',Vector3.one*u*.14,CFrame.new(u*.3,u*.34,-u*.3),WHITE,NEON,.25)
 piece(v,b,'TypeDrip','Ball',Vector3.one*u*.2,CFrame.new(0,-u*.6,0),core,NEON)
end
-- Halver: two halves either side of a glowing seam, a blade on each; the
-- halves part while it cuts.
BODIES.Halver=function(v,b,u,col,acc,core,anim)
 for side=-1,1,2 do
  local at=CFrame.new(side*u*.29,0,0)
  table.insert(anim,{part=piece(v,b,'TypeHalf','Block',Vector3.new(u*.46,u*.95,u*.95),at,col),base=at,mode='part',side=side,amp=u*.16})
  local blade=CFrame.new(side*u*.55,-u*.15,0)
  table.insert(anim,{part=piece(v,b,'TypeBlade','Wedge',Vector3.new(u*.06,u*.5,u*.7),blade,acc:Lerp(WHITE,.4),METAL),base=blade,mode='part',side=side,amp=u*.16})
 end
 piece(v,b,'TypeSeam','Block',Vector3.new(u*.06,u*.9,u*.9),CFrame.new(),core,NEON)
end
-- Gridcutter: a flat square plate with a raised lattice, four prongs and a glowing grid underneath.
BODIES.Gridcutter=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypePlate','Block',Vector3.new(u*1.5,u*.22,u*1.5),CFrame.new(0,u*.05,0),col)
 for k=-1,1 do
  piece(v,b,'TypeLatticeX','Block',Vector3.new(u*1.5,u*.1,u*.08),CFrame.new(0,u*.2,k*u*.5),acc)
  piece(v,b,'TypeLatticeZ','Block',Vector3.new(u*.08,u*.1,u*1.5),CFrame.new(k*u*.5,u*.2,0),acc)
 end
 for x=-1,1,2 do for z=-1,1,2 do piece(v,b,'TypeProng','Block',Vector3.new(u*.12,u*.45,u*.12),CFrame.new(x*u*.62,-u*.25,z*u*.62),DARK) end end
 piece(v,b,'TypeGrid','Block',Vector3.new(u*1.1,u*.04,u*1.1),CFrame.new(0,-u*.08,0),core,NEON)
end
-- Singularity: a dark orb inside a tilted glowing ring that turns.
BODIES.Singularity=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeVoid','Ball',Vector3.one*u*.9,CFrame.new(),rgb(26,18,38))
 local tilt=CFrame.Angles(.38,0,.12)
 for k=1,12 do
  local at=CFrame.Angles(0,k/12*math.pi*2,0)*CFrame.new(0,0,-u*.86)
  table.insert(anim,{part=piece(v,b,'TypeRing','Block',Vector3.new(u*.42,u*.07,u*.12),tilt*at,core,NEON),base=at,tilt=tilt,mode='spin',hz=.22})
 end
end
-- Starforge: a spiky star of three crossed blocks, slowly turning, a hot core underneath.
BODIES.Starforge=function(v,b,u,col,acc,core,anim)
 for _,turn in ipairs({CFrame.new(),CFrame.Angles(math.pi/4,0,0),CFrame.Angles(0,0,math.pi/4)}) do
  table.insert(anim,{part=piece(v,b,'TypeStar','Block',Vector3.one*u*.8,turn,col),base=turn,mode='spin',hz=.12})
 end
 piece(v,b,'TypeEmber','Ball',Vector3.one*u*.3,CFrame.new(0,-u*.58,0),core,NEON)
end
-- Frostbite: a cluster of ice crystals on a frosted base.
BODIES.Frostbite=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeFrost','Block',Vector3.new(u*.72,u*.24,u*.72),CFrame.new(0,-u*.3,0),col:Lerp(WHITE,.35),Enum.Material.Ice)
 for _,c in ipairs({{0,0,0,1.25},{.3,.32,-.12,.95},{-.3,-.26,.18,.85},{.04,.2,.36,.7}}) do
  local len=c[4]
  piece(v,b,'TypeCrystal','Block',Vector3.new(u*.26,u*len,u*.26),CFrame.new(c[1]*u,u*(len*.5-.3),0)*CFrame.Angles(c[2],0,c[3])*CFrame.Angles(0,math.pi/4,0),
   rgb(206,236,255),Enum.Material.Ice,.12)
 end
 piece(v,b,'TypeShine','Ball',Vector3.one*u*.2,CFrame.new(0,-u*.46,0),core,NEON)
end
-- Resonator: a tuning fork; its prongs hum while it works.
BODIES.Resonator=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeYoke','Block',Vector3.new(u*.95,u*.26,u*.36),CFrame.new(0,-u*.2,0),col)
 piece(v,b,'TypeStem','Cylinder',Vector3.new(u*.5,u*.18,u*.18),CFrame.new(0,-u*.52,0)*UP,DARK,METAL)
 for side=-1,1,2 do
  local at=CFrame.new(side*u*.36,u*.32,0)
  table.insert(anim,{part=piece(v,b,'TypeFork','Block',Vector3.new(u*.2,u*.85,u*.32),at,col:Lerp(WHITE,.2),METAL),base=at,mode='hum',side=side,amp=u*.035})
  local tip=CFrame.new(side*u*.36,u*.82,0)
  table.insert(anim,{part=piece(v,b,'TypeForkTip','Ball',Vector3.one*u*.24,tip,core,NEON),base=tip,mode='hum',side=side,amp=u*.05})
 end
end
-- Ramiel: a glass octahedron standing on a point, turning slowly, a red core inside.
BODIES.Ramiel=function(v,b,u,col,acc,core,anim)
 local turn=CFrame.Angles(math.rad(45),0,math.rad(35.26))
 table.insert(anim,{part=piece(v,b,'TypeDiamond','Block',Vector3.one*u*.92,turn,rgb(126,186,255),GLASS,.25),base=turn,mode='spin',hz=.08})
 piece(v,b,'TypeHeart','Ball',Vector3.one*u*.36,CFrame.new(),core,NEON)
end
-- Nomad: a rocket, nose down, fins and a glowing engine on top.
BODIES.Nomad=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeFuselage','Cylinder',Vector3.new(u*1.2,u*.52,u*.52),UP,col)
 piece(v,b,'TypeNose','Ball',Vector3.one*u*.52,CFrame.new(0,-u*.6,0),acc)
 piece(v,b,'TypeStripe','Cylinder',Vector3.new(u*.12,u*.56,u*.56),CFrame.new(0,u*.22,0)*UP,WHITE)
 for k=0,3 do
  local yaw=k*math.pi/2
  piece(v,b,'TypeRocketFin','Wedge',Vector3.new(u*.06,u*.46,u*.36),CFrame.Angles(0,yaw,0)*CFrame.new(0,u*.48,u*.38),acc)
 end
 piece(v,b,'TypeEngine','Cylinder',Vector3.new(u*.08,u*.36,u*.36),CFrame.new(0,u*.64,0)*UP,core,NEON)
end
-- Lancer: a lance standing point-down, a guard disc and three fins.
BODIES.Lancer=function(v,b,u,col,acc,core,anim)
 piece(v,b,'TypeShaft','Cylinder',Vector3.new(u*1.7,u*.26,u*.26),CFrame.new(0,-u*.1,0)*UP,col,METAL)
 piece(v,b,'TypeGuard','Cylinder',Vector3.new(u*.1,u*.85,u*.85),CFrame.new(0,u*.35,0)*UP,acc)
 for k=0,2 do
  piece(v,b,'TypeVane','Wedge',Vector3.new(u*.05,u*.36,u*.3),CFrame.Angles(0,k*math.pi*2/3,0)*CFrame.new(0,u*.6,u*.18),col:Lerp(WHITE,.3))
 end
 piece(v,b,'TypePoint','Block',Vector3.one*u*.24,CFrame.new(0,-u*.98,0)*CFrame.Angles(math.pi/4,0,math.pi/4),core,NEON)
end
Fun.BODIES=BODIES
Fun.LOOKS=BODIES
-- The body color: the type's attack color, a little muted, so the body
-- reads as that type from across the pit while its glowing part, beam and
-- effects stay brighter. A few types have their own (dark Singularity,
-- icy Frostbite, cream Lancer).
-- The Striker keeps the original Mining Away miner's blue body under its
-- original warm beam; the Nomad is a white rocket with orange fins.
local BODY_COLOR={Striker=rgb(70,118,186),Singularity=rgb(52,36,70),Frostbite=rgb(196,226,246),Lancer=rgb(238,228,204),Halver=rgb(78,90,200),Nomad=rgb(232,234,240)}
-- primary (optional) is the role's attack color; role (optional) its name.
-- Without a role every drone is the same neutral cube.
function Fun.paintCube(view,body,id,primary,role)
 local accent=Fun.accentFor(primary,role)
 local color=primary or NEUTRAL
 primary=primary or color
 -- Render smaller than the 3.4-stud gameplay hull so the fleet frames the
 -- action instead of covering it.
 body.Size=body.Size*Fun.CUBE_VIEW_SCALE*(Fun.ROLE_SCALE[role or ''] or 1)
 local u=body.Size.X
 local emitter=view:FindFirstChild('Emmiter')
 if emitter and emitter:IsA('BasePart') then emitter.CFrame=body.CFrame*CFrame.new(0,-u*(Fun.ROLE_BELLY[role or ''] or .5),0) end
 local bodyColor=BODY_COLOR[role or ''] or muted(color,.2)
 body.Color=bodyColor;body.Material=Enum.Material.SmoothPlastic;body.Reflectance=0;body.CastShadow=true
 local anim={}
 local build=BODIES[role or '']
 if build then
  -- The hull stays as the pivot; the type's own body replaces the cube.
  body.Transparency=1;body.CastShadow=false
  pcall(build,view,body,u,bodyColor,accent,primary:Lerp(WHITE,.2),anim)
 else
  local lid=bare(view,'FunCap',Vector3.new(u*.86,.08,u*.86),bodyColor:Lerp(WHITE,.45))
  attach(lid,body,CFrame.new(0,u*.5+.035,0))
 end
 -- A small light where the attack leaves the body, on only while it works.
 local anchor=emitter and emitter:IsA('BasePart') and emitter or body
 local light=Instance.new('PointLight');light.Name='FunLight';light.Color=primary;light.Range=7;light.Brightness=0
 light.Shadows=false;light.Parent=anchor
 return {color=color,body=body,primary=primary,accent=accent,role=role,light=light,anim=anim,u=u,part=0}
end
-- Called every render frame for a drone, after its model is posed. speed in studs/s.
function Fun.stepCube(record,speed,working,hidden,now)
 if not record then return end
 record.light.Brightness=(working and not hidden) and .45 or 0
 local anim=record.anim
 if not anim or #anim==0 or hidden then return end
 local calm=reduced()
 local body=record.body
 local dt=math.clamp(now-(record.at or now),0,.1);record.at=now
 -- Halves part while working and close again after (eased).
 record.part+=((working and 1 or 0)-record.part)*(1-math.exp(-dt*6))
 local frame=body.CFrame
 for _,a in ipairs(anim) do
  local m=a.mode
  local cf=a.base
  if m=='spin' then
   local turn=CFrame.Angles(0,(calm and 0 or now*math.pi*2*(a.hz or .1)*(working and 2.5 or 1))%(math.pi*2),0)
   cf=(a.tilt or CFrame.new())*turn*a.base
  elseif m=='bob' then
   cf=CFrame.new(0,calm and 0 or math.sin(now*math.pi*2*(a.hz or .3))*a.amp,0)*a.base
  elseif m=='part' then
   cf=CFrame.new(a.side*a.amp*record.part,0,0)*a.base
  elseif m=='hum' and working and not calm then
   cf=CFrame.new(a.side*a.amp*math.sin(now*math.pi*2*24),0,0)*a.base
  end
  a.part.CFrame=frame*cf
 end
end
-- A short, bright confetti pop. The anchor removes itself afterward.
local active=0
function Fun.confetti(parent,point,color,strength)
 if reduced() or active>=10 then return end
 local camera=workspace.CurrentCamera
 if camera and (camera.CFrame.Position-point).Magnitude>140 then return end
 strength=math.clamp(strength or 1,.5,3)
 active+=1
 local anchor=bare(parent,'FunConfetti',Vector3.one*.1,WHITE);anchor.Transparency=1;anchor.Position=point
 local light=color:Lerp(WHITE,.55)
 local bits=Instance.new('ParticleEmitter');bits.Texture=SQUARE;bits.Rate=0
 bits.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,light),ColorSequenceKeypoint.new(.5,color),ColorSequenceKeypoint.new(1,color)})
 bits.LightEmission=.35;bits.LightInfluence=.4
 bits.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.38),NumberSequenceKeypoint.new(.8,.3),NumberSequenceKeypoint.new(1,0)})
 bits.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.75,0),NumberSequenceKeypoint.new(1,1)})
 bits.Lifetime=NumberRange.new(.7,1.25);bits.Speed=NumberRange.new(12,22);bits.SpreadAngle=Vector2.new(55,55)
 bits.EmissionDirection=Enum.NormalId.Top;bits.Acceleration=Vector3.new(0,-38,0);bits.Drag=1.6
 bits.Rotation=NumberRange.new(0,360);bits.RotSpeed=NumberRange.new(-420,420);bits.Parent=anchor
 local twinkle=Instance.new('ParticleEmitter');twinkle.Texture=SPARKLE;twinkle.Rate=0
 twinkle.Color=ColorSequence.new(WHITE,light);twinkle.LightEmission=1;twinkle.LightInfluence=0
 twinkle.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(1,0)})
 twinkle.Transparency=NumberSequence.new(0,1);twinkle.Lifetime=NumberRange.new(.35,.6)
 twinkle.Speed=NumberRange.new(5,11);twinkle.SpreadAngle=Vector2.new(180,180);twinkle.Drag=4;twinkle.Parent=anchor
 local flash=Instance.new('PointLight');flash.Color=color;flash.Range=9;flash.Brightness=1.2;flash.Shadows=false;flash.Parent=anchor
 bits:Emit(math.floor(14+8*strength))
 twinkle:Emit(math.floor(6+3*strength))
 task.spawn(function()
  for i=1,8 do task.wait(.03);flash.Brightness=1.2*(1-i/8) end
  flash.Enabled=false
  task.wait(1.4)
  anchor:Destroy();active-=1
 end)
end
-- Particles (owner, Nov 22): every round particle is one plain, crisp
-- circle; the engine's default sparkle and the soft glow/flare blobs are
-- swapped for it as they appear. And every drone type has its own particle
-- look (shape, spin, stretch), applied to the particles its effects make.
Fun.CIRCLE='rbxasset://textures/ui/VR/circleWhite.png'
Fun.SQUARE=SQUARE
Fun.STAR='rbxassetid://77624818077620'
Fun.ROUND={['']=true,[SPARKLE]=true,['rbxasset://textures/sparkle.png']=true,['rbxasset://textures/glow.png']=true,
 ['rbxasset://textures/particles/flare_main.dds']=true,['rbxasset://textures/ui/AvatarExperience/glowLight.png']=true}
-- shape: circle | square (tumbling) | diamond (a square turned 45 degrees,
-- still) | bar (a short slab along its flight) | needle (a long thin one) |
-- star. spin in degrees/s; squash stretches along the flight.
-- Owner, Nov 22: "not unique in size, texture, everything ... too fast and
-- linear. when in doubt, either make them floaty and lingery, or have lots
-- of drag and initial speed". Each type: a shape, a size, and one of two
-- motions:
--  float: slow, long-lived, drifting (rise > 0 floats up, < 0 settles down)
--  burst: a hard initial speed killed by heavy drag, then a linger
Fun.ROLE_PARTICLE={
 Striker={shape='circle',scale=1,motion='burst',drag=7},
 Charger={shape='square',spin=260,scale=1.7,motion='burst',drag=9,kick=1.8,gravity=-10},
 Ballcaster={shape='diamond',scale=1.3,motion='float',rise=1.2},
 Needler={shape='needle',squash=2.6,scale=.55,motion='burst',drag=10,kick=2.2},
 Bubbler={shape='circle',grow=true,scale=1.9,motion='float',rise=2.4},
 Halver={shape='bar',squash=1.4,scale=1.1,motion='burst',drag=6,kick=1.4},
 Gridcutter={shape='square',spin=0,scale=.6,motion='float',rise=0},
 Singularity={shape='diamond',spin=320,scale=.9,motion='float',rise=-.4},
 Starforge={shape='star',spin=120,scale=1.25,motion='float',rise=2},
 Frostbite={shape='diamond',squash=1.2,scale=.75,motion='float',rise=-1.2},
 Resonator={shape='circle',pulse=true,scale=1.2,motion='burst',drag=5},
 Ramiel={shape='diamond',spin=90,scale=1.6,motion='float',rise=.3},
 Nomad={shape='square',spin=420,scale=1.4,motion='burst',drag=8,kick=2},
 Lancer={shape='needle',squash=3.4,scale=1,motion='burst',drag=7,kick=1.6},
}
-- Every particle varies more (owner, Nov 22: "add lots more randomness to
-- particles"): a wider size envelope, longer and shorter lives, faster and
-- slower ones, any starting angle and a spin either way. Once per emitter.
local function scaled(seq,k,spread)
 local ok,keys=pcall(function() return seq.Keypoints end)
 if not ok or type(keys)~='table' then return nil end
 local out={}
 for _,kp in ipairs(keys) do
  local v=kp.Value*k
  table.insert(out,NumberSequenceKeypoint.new(kp.Time,v,math.max(kp.Envelope*k,v*spread)))
 end
 return NumberSequence.new(out)
end
local function widen(range,lo,hi)
 local ok,r=pcall(function() return NumberRange.new(range.Min*lo,range.Max*hi) end)
 return ok and r or nil
end
function Fun.randomize(emitter)
 if emitter:GetAttribute('Randomized') then return end
 emitter:SetAttribute('Randomized',true)
 pcall(function()
  local size=scaled(emitter.Size,1,.45)
  if size then emitter.Size=size end
  emitter.Lifetime=widen(emitter.Lifetime,.7,1.6) or emitter.Lifetime
  -- Slower, never faster, and nothing flies on in a straight line: a fast
  -- particle gets drag so it bursts out, stops and lingers.
  emitter.Speed=widen(emitter.Speed,.5,1) or emitter.Speed
  if emitter.Speed.Max>10 and emitter.Drag<4 then emitter.Drag=4 end
  local spread=emitter.SpreadAngle
  emitter.SpreadAngle=Vector2.new(math.min(180,spread.X+18),math.min(180,spread.Y+18))
  if emitter.Orientation~=Enum.ParticleOrientation.VelocityParallel then
   emitter.Rotation=NumberRange.new(0,360)
   local spin=math.max(math.abs(emitter.RotSpeed.Min),math.abs(emitter.RotSpeed.Max),40)
   emitter.RotSpeed=NumberRange.new(-spin*1.4,spin*1.4)
  end
 end)
end
-- How much bigger a drone type's own particles are than the effect's base.
-- Owner, Nov 22 (latest): effects should show things, not be overused; at
-- 2.4x the break particles became big blobs that covered the dig.
Fun.ROLE_PARTICLE_SCALE=1.45
function Fun.styleParticle(emitter,role)
 local look=Fun.ROLE_PARTICLE[role or '']
 if not look or not emitter:IsA('ParticleEmitter') then return end
 emitter:SetAttribute('RoleParticle',role)
 -- Much larger than the base effect (owner: "make the unique particles
 -- much larger"), with a wide size spread so no two read the same.
 local size=scaled(emitter.Size,Fun.ROLE_PARTICLE_SCALE*(look.scale or 1),.5)
 if size then emitter.Size=size end
 local shape=look.shape
 emitter.FlipbookLayout=Enum.ParticleFlipbookLayout.None
 if shape=='circle' then
  emitter.Texture=Fun.CIRCLE
  if look.grow then
   local ok,s=pcall(function() return emitter.Size.Keypoints[1].Value end);s=ok and s or .5
   emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s*.4),NumberSequenceKeypoint.new(.7,s*1.2),NumberSequenceKeypoint.new(1,0)})
  elseif look.pulse then
   local ok,s=pcall(function() return emitter.Size.Keypoints[1].Value end);s=ok and s or .5
   emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s),NumberSequenceKeypoint.new(.25,s*.45),NumberSequenceKeypoint.new(.5,s),NumberSequenceKeypoint.new(.75,s*.45),NumberSequenceKeypoint.new(1,0)})
  end
 elseif shape=='star' then
  emitter.Texture=Fun.STAR
  emitter.Rotation=NumberRange.new(0,360);emitter.RotSpeed=NumberRange.new(-(look.spin or 0),look.spin or 0)
 else
  emitter.Texture=Fun.SQUARE
  if shape=='diamond' then
   emitter.Rotation=NumberRange.new(45,45)
   emitter.RotSpeed=NumberRange.new(-(look.spin or 0),look.spin or 0)
  elseif shape=='square' then
   emitter.Rotation=NumberRange.new(0,(look.spin or 0)>0 and 360 or 0)
   emitter.RotSpeed=NumberRange.new(-(look.spin or 0),look.spin or 0)
  else -- bar, needle: slabs pointing where they fly
   emitter.Rotation=NumberRange.new(0,0);emitter.RotSpeed=NumberRange.new(0,0)
   emitter.Orientation=Enum.ParticleOrientation.VelocityParallel
  end
 end
 if look.squash then emitter.Squash=NumberSequence.new(-look.squash) end
 pcall(function()
  local speed,life=emitter.Speed,emitter.Lifetime
  if look.motion=='float' then
   emitter.Speed=NumberRange.new(speed.Min*.2,math.max(1.5,speed.Max*.35))
   emitter.Drag=1.4
   emitter.Lifetime=NumberRange.new(math.max(.9,life.Min*2),math.max(2.2,life.Max*2.6))
   emitter.Acceleration=Vector3.new(0,look.rise or 0,0)
  else
   local k=look.kick or 1.3
   emitter.Speed=NumberRange.new(math.max(8,speed.Max*k*.6),math.max(14,speed.Max*k*1.1))
   emitter.Drag=look.drag or 6
   emitter.Lifetime=NumberRange.new(math.max(.5,life.Min*1.4),math.max(1.1,life.Max*2))
   emitter.Acceleration=Vector3.new(0,look.gravity or -3,0)
  end
 end)
end
-- Particles made inside fn take the role's look (effects build their
-- emitters synchronously; DescendantAdded below sees them as they appear).
function Fun.withRole(role,fn,...)
 local was=Fun.activeRole
 Fun.activeRole=role
 local result=table.pack(pcall(fn,...))
 Fun.activeRole=was
 if not result[1] then error(result[2],0) end
 return table.unpack(result,2,result.n)
end
local function normalize(emitter)
 if Fun.activeRole and not emitter:GetAttribute('RoleParticle') then
  pcall(Fun.styleParticle,emitter,Fun.activeRole)
 elseif Fun.ROUND[emitter.Texture] then
  emitter.Texture=Fun.CIRCLE;emitter.FlipbookLayout=Enum.ParticleFlipbookLayout.None
 end
 Fun.randomize(emitter)
end
function Fun.particles()
 if Fun.particlesOn then return end
 Fun.particlesOn=true
 local function watch(item)
  if item:IsA('ParticleEmitter') then
   normalize(item)
   item:GetPropertyChangedSignal('Texture'):Connect(function()
    if Fun.ROUND[item.Texture] and not item:GetAttribute('RoleParticle') then item.Texture=Fun.CIRCLE end
   end)
  end
 end
 for _,item in ipairs(workspace:GetDescendants()) do watch(item) end
 workspace.DescendantAdded:Connect(watch)
end
-- Slow colored motes floating above each square field. Created once.
function Fun.fieldMotes(parent,world)
 if Fun.motesReady then return end
 local map=world and world:FindFirstChild('Map')
 local run=map and map:FindFirstChild('CrystalRun')
 if not run or run:GetAttribute('WholeFields')~=true then return end
 Fun.motesReady=true
 for _,model in ipairs(run:GetChildren()) do
  local field=model:FindFirstChild('Field')
  local zone=field and field:IsA('BasePart') and field:GetAttribute('CrystalZone')
  local color=zone and Fun.ZoneColors[zone]
  if color then
   local size=field.Size
   local area=bare(parent,'FunFieldMotes',Vector3.new(size.X*.9,.2,size.Z*.9),WHITE);area.Transparency=1
   area.CFrame=field.CFrame*CFrame.new(0,size.Y*.5+.6,0)
   local motes=Instance.new('ParticleEmitter');motes.Texture=SPARKLE;motes.Shape=Enum.ParticleEmitterShape.Box
   motes.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward;motes.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
   motes.EmissionDirection=Enum.NormalId.Top;motes.Color=ColorSequence.new(color:Lerp(WHITE,.4),color)
   motes.LightEmission=.9;motes.LightInfluence=0;motes.Rate=reduced() and 0 or 5
   motes.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.3,.45),NumberSequenceKeypoint.new(1,0)})
   motes.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.2),NumberSequenceKeypoint.new(1,1)})
   motes.Lifetime=NumberRange.new(3,5);motes.Speed=NumberRange.new(.6,1.6);motes.SpreadAngle=Vector2.new(25,25)
   motes.Acceleration=Vector3.new(0,.4,0);motes.Rotation=NumberRange.new(0,360);motes.RotSpeed=NumberRange.new(-40,40)
   motes.Parent=area
  end
 end
end
-- The play grade (client-local, on top of the authored washed daylight):
-- the world and the drones sit a step below the authored saturation so the
-- glowing things (beams, gems, the drones' bellies) are the most colorful on
-- screen. Those are Neon or light-emitting, so they also carry the bloom.
-- Owner, Nov 22: "make the map overall darker. i like the pastel look, but
-- it was washing out too many of the brighter effects". The baseline is
-- darkened on the client: less sun and ambient light and haze dim every lit
-- surface, while Neon, beams, particles, lights and gems (emissive) keep
-- their full strength, so the drones' glows and the gems pop. Relative to
-- the authored values, applied once.
-- Owner follow-up: "even darker. ambient should be down ... revert the color
-- changes. so still pastel but very dark. sun at like sunset".
-- Then: "a little brighter again, more contrast with the lighting": a
-- stronger low sun over a low ambient and sharper shadows.
-- Then: "still reads as far too dark -> nighttime": late afternoon (a warm,
-- low but daytime sun) and only a moderate dimming, keeping the contrast.
-- Owner, Nov 22 (latest): "the lighting and textures are very ugly. it
-- looked better in pastel, but that was too bright." The late-afternoon
-- darkening made everything sepia. Back to the authored pastel daylight
-- (soft sun, cool blue shadows, pale haze), about a fifth dimmer: a lower
-- sun brightness and exposure and less fill, a neutral early-afternoon sun,
-- a little contrast so shapes read. Emissive things (beams, gems, glowing
-- parts) are unaffected, so they still pop.
Fun.DARKEN={sun=.8,ambient=.82,outdoor=.76,haze=.7,density=.9,diffuse=.9,clock=14.2,shadow=.32,exposure=-.05,contrast=.07,saturation=-.05}
function Fun.colorPop()
 local lighting=game:GetService('Lighting')
 if lighting:FindFirstChild('FunColorPop') then return end
 local d=Fun.DARKEN
 local function dim(c,k) return Color3.new(c.R*k,c.G*k,c.B*k) end
 pcall(function()
  lighting.Ambient=dim(lighting.Ambient,d.ambient)
  lighting.OutdoorAmbient=dim(lighting.OutdoorAmbient,d.outdoor)
  lighting.EnvironmentDiffuseScale=lighting.EnvironmentDiffuseScale*d.diffuse
  lighting.ShadowSoftness=d.shadow
  lighting.ExposureCompensation=d.exposure
 end)
 -- The sun and the haze stay dimmed even if something sets them again
 -- (a replicated change becomes the new base). The pit lamp owns the
 -- ambient while you are down in the pit, so those are set once here.
 local function hold(object,property,k)
  local written
  local function apply()
   local value=object[property]
   if written~=nil and math.abs(value-written)<1e-4 then return end
   written=value*k
   object[property]=written
  end
  pcall(apply)
  object:GetPropertyChangedSignal(property):Connect(function() pcall(apply) end)
 end
 pcall(hold,lighting,'Brightness',d.sun)
 pcall(function()
  lighting.ClockTime=d.clock
  lighting:GetPropertyChangedSignal('ClockTime'):Connect(function()
   if math.abs(lighting.ClockTime-d.clock)>1e-3 then lighting.ClockTime=d.clock end
  end)
 end)
 for _,air in ipairs(lighting:GetChildren()) do
  if air:IsA('Atmosphere') then
   pcall(hold,air,'Haze',d.haze)
   pcall(function() air.Density=air.Density*d.density end)
  end
 end
 local grade=Instance.new('ColorCorrectionEffect');grade.Name='FunColorPop'
 grade.Saturation=d.saturation;grade.Contrast=d.contrast;grade.Brightness=0;grade.Parent=lighting
end
-- Depth of field for play: sharp from the camera out well past the player,
-- so the whole dig and the crew stay crisp, with only the far walls and
-- skyline softly blurred. Steps aside while a menu blurs the world itself.
function Fun.focus()
 local lighting=game:GetService('Lighting')
 local dof=lighting:FindFirstChild('PlayFocus') or Instance.new('DepthOfFieldEffect')
 -- Owner, Nov 22: "dof is too much". Only a faint blur on the far skyline.
 dof.Name='PlayFocus';dof.NearIntensity=0;dof.FarIntensity=.06;dof.FocusDistance=30;dof.InFocusRadius=110
 dof.Parent=lighting
 return dof
end
function Fun.stepFocus(dof,camera,subject)
 if not dof or not dof.Parent or not camera then return end
 local lighting=dof.Parent
 local pack=lighting:FindFirstChild('PackWorldBlur')
 local menu=lighting:FindFirstChild('FleetDepthOfField')~=nil or (pack and pack:IsA('DepthOfFieldEffect') and pack.FarIntensity>0)
 if dof.Enabled==(menu==true) then dof.Enabled=not menu end
 local distance=subject and (camera.CFrame.Position-subject).Magnitude or 30
 dof.FocusDistance=math.clamp(distance,8,120)
 dof.InFocusRadius=math.max(110,distance*3)
end
return Fun
