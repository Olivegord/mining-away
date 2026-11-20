-- Stage only Workspace["VERSION 1"]. Called after the WindVortexV1 module bundle.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335 and game.RunService:IsEdit())
assert(not workspace:FindFirstChild("VERSION 1"), "Workspace.VERSION 1 already exists")
local ray = RaycastParams.new()
ray.RespectCanCollide = true
local function floor(x,z)
 local hit = assert(workspace:Raycast(Vector3.new(x,15,z),Vector3.new(0,-25,0),ray))
 assert(math.abs(hit.Position.Y-4)<.2 and hit.Normal.Y>.98, "Version 1 requires open depot ground")
 return hit.Position
end
local center, switchAt = floor(-17,-7), floor(-14,11)
local model = Instance.new("Model")
model.Name = "VERSION 1"
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model:SetAttribute("WindVortexVersion",1)
local function part(parent,name,frame,size,color)
 local p = Instance.new("Part")
 p.Name=name; p.Size=size; p.CFrame=frame; p.Color=color; p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false
 p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
 p.Parent=parent
 return p
end
local ivory = Color3.fromRGB(245,234,202)
local origin = part(model,"VortexOrigin",CFrame.new(center),Vector3.new(.1,.1,.1),ivory)
origin.Transparency=1
model.PrimaryPart=origin
for _,group in ipairs(WindVortexV1.groups) do
 for i=1,group[2] do
  local name = group[1]..i
  local a = Instance.new("Attachment"); a.Name=name.."Root"; a.Parent=origin
  local z = Instance.new("Attachment"); z.Name=name.."Tip"; z.Parent=origin
  local b = Instance.new("Beam")
  b.Name=name; b.Attachment0=a; b.Attachment1=z; b.Segments=10; b.FaceCamera=true
  b.LightEmission=group[1]=="Skirt" and .01 or .36
  b.LightInfluence=0; b.Brightness=group[1]=="Skirt" and .8 or 1.2
  b.Enabled=false; b.Parent=origin
 end
end
local debris = Instance.new("Folder"); debris.Name="Debris"; debris.Parent=model
local rng = Random.new(29997)
for i=1,WindVortexV1.gritCount do
 local k=rng:NextNumber(.20,1.0)^1.6
 local shade=rng:NextInteger(46,91)
 local p=part(debris,"Chip"..i,origin.CFrame,Vector3.new(.16+1.14*k,.12+.68*k,.12+.89*k),Color3.fromRGB(shade,shade-6,shade-14))
 p.Material=Enum.Material.Slate; p.Transparency=1
end
for i=1,WindVortexV1.plateCount do
 local shade=rng:NextInteger(66,97)
 local p=part(debris,"Plate"..i,origin.CFrame,Vector3.new(rng:NextNumber(1.35,2.8),rng:NextNumber(.26,.55),rng:NextNumber(1.3,2.5)),Color3.fromRGB(shade,shade-6,shade-13))
 p.Material=Enum.Material.Slate; p.Transparency=1
end
local function emission(name,texture,color,rates,sizes,alpha)
 local p=Instance.new("ParticleEmitter"); p.Name=name; p.Texture=texture; p.Enabled=false; p.Rate=0
 p.Color=ColorSequence.new(color); p.Lifetime=rates; p.Size=sizes; p.Transparency=alpha
 p.LightInfluence=.35; p.SpreadAngle=Vector2.new(78,78); p.Rotation=NumberRange.new(-180,180)
 p.Parent=origin
 return p
end
local K=NumberSequenceKeypoint.new
local dust=emission("DustShelf","rbxasset://textures/particles/smoke_main.dds",Color3.fromRGB(142,132,112),
 NumberRange.new(.45,.84),NumberSequence.new({K(0,.3),K(.12,1.5),K(.6,2.7),K(1,3.9)}),
 NumberSequence.new({K(0,1),K(.11,.65),K(.45,.77),K(1,1)}))
dust.Speed=NumberRange.new(9,20); dust.Drag=3.4; dust.Acceleration=Vector3.new(0,-4,0); dust.RotSpeed=NumberRange.new(-45,45)
local grit=emission("StoneGrit","rbxasset://textures/particles/sparkles_main.dds",Color3.fromRGB(135,124,103),
 NumberRange.new(.24,.57),NumberSequence.new({K(0,.12),K(.10,.31),K(.73,.16),K(1,.02)}),
 NumberSequence.new({K(0,.6),K(.08,.12),K(.76,.35),K(1,1)}))
grit.Speed=NumberRange.new(10,24); grit.Drag=1; grit.Acceleration=Vector3.new(0,-36,0)
grit.Orientation=Enum.ParticleOrientation.VelocityParallel
local station=part(model,"Replay",CFrame.new(switchAt+Vector3.new(0,.68,0)),Vector3.new(4.9,1.35,2.5),Color3.fromRGB(51,63,67))
local gui=Instance.new("SurfaceGui"); gui.Name="Legend"; gui.Face=Enum.NormalId.Top
gui.CanvasSize=Vector2.new(490,250); gui.LightInfluence=.12; gui.Parent=station
local label=Instance.new("TextLabel"); label.Name="Version"; label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1
label.Text="WIND   /   V1"; label.TextSize=59; label.Font=Enum.Font.GothamBold; label.TextColor3=ivory; label.Parent=gui
local prompt=Instance.new("ProximityPrompt"); prompt.Name="CastWindV1"; prompt.ActionText="Cast vortex"; prompt.ObjectText="Wind • Version 1"
prompt.MaxActivationDistance=9; prompt.RequiresLineOfSight=false; prompt.Parent=station
-- Freeze the first airborne crown for the Studio editor. Runtime starts with a clear floor.
local rig=WindVortexV1.bind(model)
WindVortexV1.pose(rig,1.155)
local encoding=game:GetService("EncodingService")
local blob=game:GetService("SerializationService"):SerializeInstancesAsync({model})
local encoded=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(blob,Enum.CompressionAlgorithm.Zstd)))
shared.WindV1Stage={encoded=encoded,model=model,rig=rig,pose=WindVortexV1.pose,apply=function()
 assert(game.RunService:IsEdit() and not workspace:FindFirstChild(model.Name))
 floor(-17,-7); floor(-14,11)
 model.Parent=workspace
 return model:GetFullName()
end}
return {bytes=#encoded, descendants=#model:GetDescendants()}
