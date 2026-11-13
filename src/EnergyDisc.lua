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
 local start=diameter*(startScale or .52)
 local finish=diameter*(endScale or .28)
 emitter.Size=NumberSequence.new({
  NumberSequenceKeypoint.new(0,start,start*(sizeVariation or 0)),
  NumberSequenceKeypoint.new(.18,diameter,diameter*(sizeVariation or .13)),
  NumberSequenceKeypoint.new(.67,finish,finish*(sizeVariation or 0)),
  NumberSequenceKeypoint.new(1,0),
 })
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

return Disc
