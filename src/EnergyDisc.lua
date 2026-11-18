-- The built-in antialiased disc has been verified in a real Studio client.
-- Shape and opacity read without relying on bloom or additive saturation.
local Disc={texture='rbxasset://textures/ui/VR/circleWhite.png'}

-- November 18 owner pass: flat white discs read as big circles that hid the
-- smoke and sparks. Shrinking "light" particles become small sparks stretched
-- along their own velocity; expanding ones become soft smoke. The callers keep
-- their colors, counts and motion.
Disc.smokeTexture='rbxasset://textures/particles/smoke_main.dds'
Disc.SPARK_SCALE=.24 -- spark width relative to the old disc diameter
Disc.SPARK_MAX=.16
Disc.SMOKE_SCALE=.85
Disc.SMOKE_MAX=1.7
function Disc.configure(emitter,diameter,transparency,startScale,endScale,sizeVariation)
 emitter.Texture=Disc.texture
 emitter.FlipbookLayout=Enum.ParticleFlipbookLayout.None
 emitter.LightInfluence=0
 emitter.WindAffectsDrag=false
 emitter.LockedToPart=false
 local expanding=(endScale or 0)>1
 if expanding then
  -- Soft smoke: real smoke texture, slow turn, quieter opacity.
  emitter.Texture=Disc.smokeTexture
  emitter.Orientation=Enum.ParticleOrientation.FacingCamera
  emitter.Squash=NumberSequence.new(0)
  emitter.LightEmission=.12;emitter.Brightness=1
  emitter.Rotation=NumberRange.new(-180,180);emitter.RotSpeed=NumberRange.new(-30,30)
  diameter=math.min(Disc.SMOKE_MAX,diameter*Disc.SMOKE_SCALE)
  local start=diameter*(startScale or .52)
  emitter.Size=NumberSequence.new({
   NumberSequenceKeypoint.new(0,start,start*(sizeVariation or 0)),
   NumberSequenceKeypoint.new(.18,diameter,diameter*(sizeVariation or .13)),
   NumberSequenceKeypoint.new(1,diameter*endScale),
  })
  local t=math.max(transparency,.55)
  emitter.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,1),
   NumberSequenceKeypoint.new(.15,t),
   NumberSequenceKeypoint.new(.6,math.min(.97,t+.12)),
   NumberSequenceKeypoint.new(1,1),
  })
 else
  -- Little sparks: thin hot streaks that point where they fly and shrink out.
  emitter.Orientation=Enum.ParticleOrientation.VelocityParallel
  emitter.Squash=NumberSequence.new({NumberSequenceKeypoint.new(0,2.2),NumberSequenceKeypoint.new(1,.6)})
  emitter.LightEmission=.85;emitter.Brightness=2.2
  diameter=math.min(Disc.SPARK_MAX,diameter*Disc.SPARK_SCALE)
  emitter.Size=NumberSequence.new({
   NumberSequenceKeypoint.new(0,diameter,diameter*(sizeVariation or .13)),
   NumberSequenceKeypoint.new(1,0),
  })
  emitter.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,0),
   NumberSequenceKeypoint.new(.7,math.min(.6,transparency)),
   NumberSequenceKeypoint.new(1,1),
  })
 end
end

-- An attachment sprite lets a handful of motes follow the existing
-- phase-sampled inward trajectories instead of orbiting or drifting at random.
function Disc.sprite(parent,name)
 local anchor=Instance.new('Attachment');anchor.Name=name;anchor.Parent=parent
 local gui=Instance.new('BillboardGui');gui.Name='EnergyDisc';gui.Adornee=anchor
 gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.MaxDistance=110;gui.Enabled=false;gui.Parent=anchor
 local image=Instance.new('ImageLabel');image.Name='Disc';image.BackgroundTransparency=1
 image.Image=Disc.texture;image.Size=UDim2.fromScale(1,1);image.Parent=gui
 return {anchor=anchor,gui=gui,image=image}
end

function Disc.place(sprite,position,diameter,color,opacity)
 sprite.gui.Enabled=opacity>.012
 if not sprite.gui.Enabled then return end
 sprite.anchor.WorldPosition=position
 sprite.gui.Size=UDim2.fromScale(diameter,diameter)
 sprite.image.ImageColor3=color
 sprite.image.ImageTransparency=1-opacity
end

-- The existing four-point glint has transparent corners. Stretch it for
-- high-speed cuts, or leave it small and sharp for slow, tumbling glints.
function Disc.accent(parent,name,color,diameter,mode,face,spread)
 local p=Instance.new('ParticleEmitter');p.Name=name
 Disc.configure(p,diameter,mode=='ink' and .10 or .26,nil,nil,.36)
 p.Enabled=false;p.Rate=0
 local fast=mode=='streak'
 local ink=mode=='ink'
 if mode~='mote' then p.Texture='rbxassetid://77624818077620' end
 if fast or ink then
  p.Orientation=Enum.ParticleOrientation.VelocityParallel
  p.Squash=NumberSequence.new(fast and -.58 or -.34)
 else
  p.Orientation=Enum.ParticleOrientation.FacingCamera;p.Squash=NumberSequence.new(0)
  p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,math.min(.22,diameter*.35)),NumberSequenceKeypoint.new(1,0)})
  p.Rotation=NumberRange.new(-35,35);p.RotSpeed=NumberRange.new(-46,46)
 end
 p.Color=ColorSequence.new(color);p.Brightness=ink and 1 or 1.25
 p.LightEmission=ink and 0 or .75
 p.EmissionDirection=face;p.SpreadAngle=Vector2.new(spread,spread)
 p.Lifetime=fast and NumberRange.new(.12,.25) or ink and NumberRange.new(.22,.43) or NumberRange.new(.34,.57)
 p.Speed=fast and NumberRange.new(11,18) or ink and NumberRange.new(5,11) or NumberRange.new(2,6)
 p.Drag=fast and 7 or 4.6
 p.Acceleration=Vector3.new(0,mode=='mote' and 1.1 or -2.5,0)
 p.Parent=parent
 return p
end

return Disc
