-- The built-in antialiased disc has been verified in a real Studio client.
-- Shape and opacity read without relying on bloom or additive saturation.
local Disc={texture='rbxasset://textures/ui/VR/circleWhite.png'}

function Disc.configure(emitter,diameter,transparency,startScale,endScale,sizeVariation)
 emitter.Texture=Disc.texture
 emitter.Orientation=Enum.ParticleOrientation.FacingCamera
 emitter.Squash=NumberSequence.new(0)
 emitter.FlipbookLayout=Enum.ParticleFlipbookLayout.None
 emitter.LightEmission=.36
 emitter.LightInfluence=0
 emitter.Brightness=1.05
 emitter.WindAffectsDrag=false
 emitter.LockedToPart=false
 -- Dust spreads as it dissipates; solid light particles shrink from birth.
 local expanding=(endScale or 0)>1
 if expanding then
  local start=diameter*(startScale or .52)
  emitter.Size=NumberSequence.new({
   NumberSequenceKeypoint.new(0,start,start*(sizeVariation or 0)),
   NumberSequenceKeypoint.new(.18,diameter,diameter*(sizeVariation or .13)),
   NumberSequenceKeypoint.new(1,diameter*endScale),
  })
 else
  emitter.Size=NumberSequence.new({
   NumberSequenceKeypoint.new(0,diameter,diameter*(sizeVariation or .13)),
   NumberSequenceKeypoint.new(1,0),
  })
 end
 emitter.Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,math.min(.97,transparency+.20)),
  NumberSequenceKeypoint.new(.12,transparency),
  NumberSequenceKeypoint.new(.78,math.min(.97,transparency+.11)),
  NumberSequenceKeypoint.new(1,1),
 })
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
