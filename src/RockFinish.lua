-- Box-mapped side faces keep the gradient attached as the rock shrinks.
local Finish={}
local STONE=Color3.fromRGB(117,115,112)
local SHADE=Color3.fromRGB(15,13,14)
Finish.StoneLight=Color3.fromRGB(188,177,164)
local GRADIENT='rbxassetid://117998501972844'
local FACES={Enum.NormalId.Front,Enum.NormalId.Right,Enum.NormalId.Back,Enum.NormalId.Left}

function Finish.apply(view,mineral)
 local tint=STONE:Lerp(mineral,.22)
 view.Material=Enum.Material.Concrete
 view.MaterialVariant=''
 view.Reflectance=0
 view.Color=tint
 local gradient={}
 for _,face in ipairs(FACES) do
  local shadow=Instance.new('Decal')
  shadow.Name='StoneBaseGradient'
  shadow.Face=face
  shadow.ColorMap=GRADIENT
  shadow.Color3=SHADE
  shadow.LocalTransparencyModifier=view.Transparency
  shadow.Parent=view
  gradient[#gradient+1]=shadow
 end
 return tint,gradient
end

function Finish.setVisibility(gradient,transparency)
 for _,shadow in ipairs(gradient) do shadow.LocalTransparencyModifier=transparency end
end

function Finish.setDarkness(gradient,darkness)
 local tint=SHADE:Lerp(Color3.new(0,0,0),darkness)
 for _,shadow in ipairs(gradient) do shadow.Color3=tint end
end

function Finish.configureDust(emitter,color,fine)
 emitter.Texture='rbxasset://textures/particles/smoke_main.dds'
 emitter.LightInfluence=fine and .30 or .85
 emitter.LightEmission=fine and .20 or 0
 emitter.Brightness=1
 emitter.Rotation=NumberRange.new(-180,180)
 emitter.RotSpeed=NumberRange.new(-42,42)
 emitter.Color=fine and ColorSequence.new(color,color:Lerp(Color3.new(0,0,0),.30))
  or ColorSequence.new(color:Lerp(Finish.StoneLight,.38),color)
end


return Finish
