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
-- Paint a cube drone's local render clone. Returns a small record for stepCube.
Fun.CUBE_VIEW_SCALE=.56
-- Drone bodies are muted toward gray; their glowing belly, trail and beam
-- keep the full color.
local function muted(c)
 local l=c.R*.3+c.G*.59+c.B*.11
 return c:Lerp(Color3.new(l,l,l),.45)
end
-- Fun.rolePrimary(role) -> Color3 and Fun.roleStyle(role) -> DigCube style are
-- installed by the client controller from the DigCubeView statics (nil until then).
-- Owner, Nov 22: every drone TYPE looks different, and every drone of one
-- type looks exactly the same (no per-drone palette color any more). The
-- body is the role's attack color, muted; the trail, motes and beam sparks
-- take the role's fixed secondary; a few parts on the cube give each type
-- its own silhouette.
Fun.ROLE_SECONDARY={
 Striker=rgb(255,236,200),Charger=rgb(255,214,90),Ballcaster=rgb(255,120,214),Needler=rgb(40,222,190),
 Bubbler=rgb(160,222,255),Halver=rgb(232,236,255),Gridcutter=rgb(70,226,255),Singularity=rgb(255,96,206),
 Starforge=rgb(255,120,40),Frostbite=rgb(244,252,255),Resonator=rgb(240,255,120),Ramiel=rgb(255,176,186),
 Nomad=rgb(255,170,60),Lancer=rgb(255,70,86),
}
local NEUTRAL=rgb(150,160,172)
function Fun.accentFor(primary,role)
 return Fun.ROLE_SECONDARY[role or ''] or (primary and primary:Lerp(WHITE,.45)) or NEUTRAL
end
-- How much bigger or smaller a type's cube is than the standard one.
Fun.ROLE_SCALE={Charger=1.14,Needler=.84,Singularity=1.06,Ramiel=.94,Lancer=.92,Ballcaster=.96}
local DARK=rgb(32,34,44)
-- One piece of a type's silhouette, fixed to the hull. `at` is in hull
-- half-sizes (x, y, z), `size` in hull sizes.
local function trim(view,body,name,shape,size,at,color,material,turn)
 local s=body.Size
 local p=bare(view,name,Vector3.new(s.X*size[1],s.Y*size[2],s.Z*size[3]),color,material,shape=='Wedge' and 'WedgePart' or nil)
 if shape=='Ball' or shape=='Cylinder' then p.Shape=Enum.PartType[shape] end
 attach(p,body,CFrame.new(s.X*.5*at[1],s.Y*.5*at[2],s.Z*.5*at[3])*(turn or CFrame.new()))
 return p
end
local LOOKS={}
-- Striker, the classic miner: a dark visor across the front and a short mast.
LOOKS.Striker=function(v,b,c,a)
 trim(v,b,'TypeVisor','Block',{.78,.2,.06},{0,.25,-1.02},DARK)
 trim(v,b,'TypeMast','Cylinder',{.42,.07,.07},{.45,1.4,.45},a,nil,CFrame.Angles(0,0,math.pi/2))
 trim(v,b,'TypeMastTip','Ball',{.13,.13,.13},{.45,1.85,.45},c,Enum.Material.Neon)
end
-- Charger, the heavy: a ram across the front and two horns.
LOOKS.Charger=function(v,b,c,a)
 trim(v,b,'TypeRam','Wedge',{.9,.34,.3},{0,-.62,-1.28},DARK,nil,CFrame.Angles(0,math.pi,0))
 for side=-1,1,2 do trim(v,b,'TypeHorn','Wedge',{.12,.34,.3},{side*.7,1.3,-.55},a) end
end
-- Ballcaster: a glowing orb riding in a collar on top.
LOOKS.Ballcaster=function(v,b,c,a)
 trim(v,b,'TypeCollar','Cylinder',{.12,.62,.62},{0,1.08,0},DARK,nil,CFrame.Angles(0,0,math.pi/2))
 trim(v,b,'TypeOrb','Ball',{.46,.46,.46},{0,1.45,0},c,Enum.Material.Neon)
end
-- Needler: a long needle under the belly and two small side fins.
LOOKS.Needler=function(v,b,c,a)
 trim(v,b,'TypeNeedle','Cylinder',{.9,.09,.09},{0,-1.75,0},a,Enum.Material.Metal,CFrame.Angles(0,0,math.pi/2))
 for side=-1,1,2 do trim(v,b,'TypeFin','Block',{.42,.08,.36},{side*1.3,.1,.2},a) end
end
-- Bubbler: a glass dome.
LOOKS.Bubbler=function(v,b,c,a)
 local dome=trim(v,b,'TypeDome','Ball',{.78,.78,.78},{0,1.05,0},a,Enum.Material.Glass)
 dome.Transparency=.45
end
-- Halver: split down the middle with a blade on each side.
LOOKS.Halver=function(v,b,c,a)
 trim(v,b,'TypeSeam','Block',{.07,1.04,1.04},{0,0,0},DARK)
 for side=-1,1,2 do trim(v,b,'TypeBlade','Wedge',{.08,.5,.62},{side*1.12,.3,0},a,Enum.Material.Metal) end
end
-- Gridcutter: four prongs at the top corners and a cross-hatched lid.
LOOKS.Gridcutter=function(v,b,c,a)
 for x=-1,1,2 do for z=-1,1,2 do trim(v,b,'TypeProng','Block',{.1,.42,.1},{x*.82,1.32,z*.82},a) end end
 trim(v,b,'TypeGridX','Block',{.86,.05,.07},{0,1.1,0},c,Enum.Material.Neon)
 trim(v,b,'TypeGridZ','Block',{.07,.05,.86},{0,1.1,0},c,Enum.Material.Neon)
end
-- Singularity: a dark cube inside a flat ring.
LOOKS.Singularity=function(v,b,c,a)
 b.Color=DARK:Lerp(c,.22)
 local ring=trim(v,b,'TypeRing','Cylinder',{.05,1.55,1.55},{0,0,0},c,Enum.Material.Neon,CFrame.Angles(0,0,math.pi/2))
 ring.Transparency=.35
end
-- Starforge: a crown of four spikes.
LOOKS.Starforge=function(v,b,c,a)
 for k=0,3 do
  local yaw=k*math.pi/2
  trim(v,b,'TypeSpike','Wedge',{.22,.46,.22},{math.sin(yaw)*.62,1.42,math.cos(yaw)*.62},c,nil,CFrame.Angles(0,yaw,0))
 end
end
-- Frostbite: ice shards growing from the top.
LOOKS.Frostbite=function(v,b,c,a)
 for k,spec in ipairs({{-.35,.6,.2},{.3,.5,-.25},{.05,.8,.05}}) do
  local shard=trim(v,b,'TypeShard','Block',{.16,spec[2],.16},{spec[1],1+spec[2],spec[3]},a,Enum.Material.Ice,CFrame.Angles(.25*k,k,.2*k))
  shard.Transparency=.2
 end
end
-- Resonator: a tuning fork, two prongs with glowing tips.
LOOKS.Resonator=function(v,b,c,a)
 for side=-1,1,2 do
  trim(v,b,'TypeFork','Block',{.1,.7,.1},{side*.34,1.7,0},a,Enum.Material.Metal)
  trim(v,b,'TypeForkTip','Ball',{.17,.17,.17},{side*.34,2.42,0},c,Enum.Material.Neon)
 end
end
-- Ramiel: a floating crystal diamond.
LOOKS.Ramiel=function(v,b,c,a)
 local gem=trim(v,b,'TypeDiamond','Block',{.46,.46,.46},{0,1.75,0},c,Enum.Material.Glass,CFrame.Angles(math.pi/4,0,math.pi/4))
 gem.Transparency=.15
end
-- Nomad: rocket fins at the bottom corners.
LOOKS.Nomad=function(v,b,c,a)
 for k=0,3 do
  local yaw=k*math.pi/2+math.pi/4
  trim(v,b,'TypeRocketFin','Wedge',{.06,.5,.42},{math.sin(yaw)*1.08,-.62,math.cos(yaw)*1.08},a,nil,CFrame.Angles(0,yaw,0))
 end
end
-- Lancer: a long lance barrel and two swept fins at the back.
LOOKS.Lancer=function(v,b,c,a)
 trim(v,b,'TypeLance','Cylinder',{.7,.15,.15},{0,-1.5,0},c,Enum.Material.Metal,CFrame.Angles(0,0,math.pi/2))
 for side=-1,1,2 do trim(v,b,'TypeTailFin','Wedge',{.06,.36,.5},{side*.42,.95,1.1},a) end
end
Fun.LOOKS=LOOKS
-- primary (optional) is the role's attack color; role (optional) its name.
-- Without a role every cube looks the same neutral drone.
function Fun.paintCube(view,body,id,primary,role)
 local accent=Fun.accentFor(primary,role)
 local color=primary or NEUTRAL
 primary=primary or color
 -- Render the cube smaller than its 3.4-stud gameplay hull so the fleet frames
 -- the action instead of covering it. The emitter moves up to the new belly.
 body.Size=body.Size*Fun.CUBE_VIEW_SCALE*(Fun.ROLE_SCALE[role or ''] or 1)
 local s=body.Size
 local emitter=view:FindFirstChild('Emmiter')
 if emitter and emitter:IsA('BasePart') then emitter.CFrame=body.CFrame*CFrame.new(0,-s.Y*.5,0) end
 body.Color=muted(color);body.Material=Enum.Material.SmoothPlastic;body.Reflectance=0
 -- A lighter cap gives the cube a lit top and a darker underside: instant depth.
 local cap=bare(view,'FunCap',Vector3.new(s.X*.86,.08,s.Z*.86),muted(color):Lerp(WHITE,.45))
 attach(cap,body,CFrame.new(0,s.Y*.5+.035,0))
 local look=LOOKS[role or '']
 if look then pcall(look,view,body,primary,accent) end
 -- The glowing belly the laser comes out of, in the role's attack color.
 local glow=bare(view,'FunGlow',Vector3.new(s.X*.62,.06,s.Z*.62),primary:Lerp(WHITE,.25),Enum.Material.Neon)
 attach(glow,body,CFrame.new(0,-s.Y*.5-.025,0))
 local light=Instance.new('PointLight');light.Name='FunLight';light.Color=primary;light.Range=7;light.Brightness=.2
 light.Shadows=false;light.Parent=glow
 -- A ribbon trail in the type's secondary color while it cruises.
 local a0=Instance.new('Attachment');a0.Name='FunTrailTop';a0.Position=Vector3.new(0,s.Y*.32,s.Z*.5);a0.Parent=body
 local a1=Instance.new('Attachment');a1.Name='FunTrailBottom';a1.Position=Vector3.new(0,-s.Y*.32,s.Z*.5);a1.Parent=body
 local trail=Instance.new('Trail');trail.Name='FunTrail';trail.Attachment0=a0;trail.Attachment1=a1
 trail.Color=ColorSequence.new(accent:Lerp(WHITE,.35),accent);trail.LightEmission=.6;trail.LightInfluence=.2
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.1)})
 trail.Lifetime=.32;trail.MinLength=.1;trail.FaceCamera=true;trail.Enabled=false;trail.Parent=body
 -- Little sparkles shed from the belly while lasering.
 local motes=Instance.new('ParticleEmitter');motes.Name='FunMotes';motes.Texture=SPARKLE
 motes.Color=ColorSequence.new(accent:Lerp(WHITE,.5),accent);motes.LightEmission=.7;motes.LightInfluence=0
 motes.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,0)})
 motes.Transparency=NumberSequence.new(.1,1);motes.Lifetime=NumberRange.new(.5,.9);motes.Rate=0
 motes.Speed=NumberRange.new(1.5,3.5);motes.SpreadAngle=Vector2.new(70,70);motes.EmissionDirection=Enum.NormalId.Bottom
 motes.Acceleration=Vector3.new(0,2,0);motes.Drag=2;motes.Rotation=NumberRange.new(0,360);motes.RotSpeed=NumberRange.new(-120,120)
 motes.Parent=glow
 return {color=color,primary=primary,accent=accent,role=role,glow=glow,light=light,trail=trail,motes=motes,glowBase=glow.Color}
end
-- Called every render frame for a cube. speed in studs/s.
function Fun.stepCube(record,speed,working,hidden,now)
 if not record then return end
 local calm=reduced()
 local cruising=not hidden and not calm and speed>9
 if record.trail.Enabled~=cruising then record.trail.Enabled=cruising end
 local rate=(working and not hidden and not calm) and 11 or 0
 if record.motes.Rate~=rate then record.motes.Rate=rate end
 -- A steady, small glow: a wide light strobing under every working cube lit
 -- the ground in flickering colored patches and drowned the effects.
 record.light.Brightness=hidden and 0 or (working and .45 or .2)
 record.glow.Color=record.glowBase:Lerp(WHITE,working and .25 or 0)
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
Fun.DARKEN={sun=.5,ambient=.3,outdoor=.28,haze=.45,density=.8,diffuse=.5,clock=17.7}
function Fun.colorPop()
 local lighting=game:GetService('Lighting')
 if lighting:FindFirstChild('FunColorPop') then return end
 local d=Fun.DARKEN
 local function dim(c,k) return Color3.new(c.R*k,c.G*k,c.B*k) end
 pcall(function()
  lighting.Ambient=dim(lighting.Ambient,d.ambient)
  lighting.OutdoorAmbient=dim(lighting.OutdoorAmbient,d.outdoor)
  lighting.EnvironmentDiffuseScale=lighting.EnvironmentDiffuseScale*d.diffuse
 end)
 -- The sun and the haze stay darkened even if something sets them again
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
 -- The sun low, at sunset: long shadows and a warm low light.
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
 -- The original play grade (the color changes were reverted).
 grade.Saturation=-.16;grade.Contrast=.03;grade.Brightness=0;grade.Parent=lighting
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
