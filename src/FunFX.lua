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
local function bare(parent,name,size,color,material)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
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
function Fun.paintCube(view,body,id)
 local color=Fun.colorFor(id)
 -- Render the cube smaller than its 3.4-stud gameplay hull so the fleet frames
 -- the action instead of covering it. The emitter moves up to the new belly.
 body.Size=body.Size*Fun.CUBE_VIEW_SCALE
 local s=body.Size
 local emitter=view:FindFirstChild('Emmiter')
 if emitter and emitter:IsA('BasePart') then emitter.CFrame=body.CFrame*CFrame.new(0,-s.Y*.5,0) end
 body.Color=color;body.Material=Enum.Material.SmoothPlastic;body.Reflectance=0
 -- A lighter cap gives the cube a lit top and a darker underside: instant depth.
 local cap=bare(view,'FunCap',Vector3.new(s.X*.86,.08,s.Z*.86),color:Lerp(WHITE,.45))
 attach(cap,body,CFrame.new(0,s.Y*.5+.035,0))
 -- The glowing belly the laser comes out of.
 local glow=bare(view,'FunGlow',Vector3.new(s.X*.62,.06,s.Z*.62),color:Lerp(WHITE,.25),Enum.Material.Neon)
 attach(glow,body,CFrame.new(0,-s.Y*.5-.025,0))
 local light=Instance.new('PointLight');light.Name='FunLight';light.Color=color;light.Range=7;light.Brightness=.2
 light.Shadows=false;light.Parent=glow
 -- A ribbon trail in the cube's color while it cruises.
 local a0=Instance.new('Attachment');a0.Name='FunTrailTop';a0.Position=Vector3.new(0,s.Y*.32,s.Z*.5);a0.Parent=body
 local a1=Instance.new('Attachment');a1.Name='FunTrailBottom';a1.Position=Vector3.new(0,-s.Y*.32,s.Z*.5);a1.Parent=body
 local trail=Instance.new('Trail');trail.Name='FunTrail';trail.Attachment0=a0;trail.Attachment1=a1
 trail.Color=ColorSequence.new(color:Lerp(WHITE,.35),color);trail.LightEmission=.6;trail.LightInfluence=.2
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.1)})
 trail.Lifetime=.32;trail.MinLength=.1;trail.FaceCamera=true;trail.Enabled=false;trail.Parent=body
 -- Little sparkles shed from the belly while lasering.
 local motes=Instance.new('ParticleEmitter');motes.Name='FunMotes';motes.Texture=SPARKLE
 motes.Color=ColorSequence.new(color:Lerp(WHITE,.5),color);motes.LightEmission=.7;motes.LightInfluence=0
 motes.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,0)})
 motes.Transparency=NumberSequence.new(.1,1);motes.Lifetime=NumberRange.new(.5,.9);motes.Rate=0
 motes.Speed=NumberRange.new(1.5,3.5);motes.SpreadAngle=Vector2.new(70,70);motes.EmissionDirection=Enum.NormalId.Bottom
 motes.Acceleration=Vector3.new(0,2,0);motes.Drag=2;motes.Rotation=NumberRange.new(0,360);motes.RotSpeed=NumberRange.new(-120,120)
 motes.Parent=glow
 return {color=color,glow=glow,light=light,trail=trail,motes=motes,glowBase=glow.Color}
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
-- A gentle saturation lift so the palette pops. Client-local, removable.
function Fun.colorPop()
 local lighting=game:GetService('Lighting')
 if lighting:FindFirstChild('FunColorPop') then return end
 local grade=Instance.new('ColorCorrectionEffect');grade.Name='FunColorPop'
 grade.Saturation=.04;grade.Contrast=.04;grade.Brightness=-.02;grade.Parent=lighting
end
return Fun
