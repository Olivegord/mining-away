-- Run after bundling CrystalCuts, RockFinish and studio_bake_gem.lua.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning())
local map=workspace.MiningAway.Map
assert(not shared.MineralLineupStage)
local previous=map:FindFirstChild('MineralLineup')
local archive=Instance.new('Folder');archive.Name='MineralLineupArchive'
assert(not game.ServerStorage:FindFirstChild(archive.Name))
local root=Instance.new('Folder');root.Name='MineralLineup'
local gems=RockFinish.Gems
local geo=gems.geometry
local baseSize=Vector3.new(2.16,1.28,1.94)
local function part(class,name,size,frame,color,parent)
 local p=Instance.new(class);p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=Enum.Material.Neon;p.Parent=parent
 return p
end
local function label(pad,title)
 local gui=Instance.new('SurfaceGui');gui.Name='MineralName';gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(256,128);gui.LightInfluence=0;gui.Parent=pad
 local text=Instance.new('TextLabel');text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,.32);text.Position=UDim2.fromScale(0,.66)
 text.Font=Enum.Font.GothamMedium;text.TextSize=22;text.TextColor3=Color3.fromRGB(220,232,234);text.Text=title; text.Parent=gui
end
local counts={}
for i,key in ipairs(geo.order) do
 local data=geo.describe(key)
 local model=Instance.new('Model');model.Name=key;model:SetAttribute('MineralSample',key)
 local x=(i-3.5)*7.4
 local pad=part('Part','DisplayPad',Vector3.new(5,.16,5),CFrame.new(x,4.10,-12),Color3.fromRGB(27,34,45),model)
 pad.Material=Enum.Material.Slate;label(pad,key=='Cobalt' and 'COBALT · BISMUTH' or string.upper(key))
 local size=baseSize*data.aspect
 local frame=CFrame.new(x,4.65+size.Y*.5,-12)*CFrame.Angles(.07,.38,-.09)
 local anchor=part('Part','SpecimenAnchor',baseSize,frame,Color3.new(1,1,1),model)
 anchor.Transparency=1;anchor:SetAttribute('Mineral',key)
 local preview=bakeGemPreview(key,data,frame,size);preview.Parent=model
 counts[key]=#preview:GetChildren()
 model.Parent=root
 task.wait()
end
-- A real cracked host beside the row lets the owner inspect the rays immediately.
local shell=CrystalCuts.inset(assert(CrystalCuts.build('Crown',{})))
assert(shell:GetAttribute('CoreFissures') and shell:FindFirstChild('CoreGeometry'))
local model=Instance.new('Model');model.Name='CoreSpecimen'
local pad=part('Part','DisplayPad',Vector3.new(5,.16,5),CFrame.new(18.5,4.10,-12),Color3.fromRGB(27,34,45),model)
pad.Material=Enum.Material.Slate;label(pad,'CORE LIGHT')
shell.Name='Shell';shell.Size=Vector3.new(2.7,3.6,2.7);shell.CFrame=CFrame.new(18.5,6.1,-12)*CFrame.Angles(0,.20,0);shell.Parent=model
local color=Color3.fromRGB(120,215,219);RockFinish.apply(shell,color)
model.Parent=root
local camera=workspace.CurrentCamera;local before=camera.CFrame
camera.CFrame=CFrame.new(18.5,7,0)
local record={source=shell,view=shell,baseColor=color,visual={broken=false}}
RockFinish.veins(record,1,false,true)
camera.CFrame=before
assert(record.veinFX,'missing core light rig')
-- Runtime rebuilds effects from the same shell; authoring stores this static pose.
local serializer,encoding=game:GetService('SerializationService'),game:GetService('EncodingService')
local bytes=serializer:SerializeInstancesAsync({root})
local encoded=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
local archived=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(serializer:SerializeInstancesAsync({archive}),Enum.CompressionAlgorithm.Zstd)))
shared.MineralLineupStage={root=root,snapshot={scenery=encoded,archive=archived},counts=counts,
 apply=function()
  assert(map:FindFirstChild('MineralLineup')==previous)
  if previous then archive.Parent=game.ServerStorage;previous.Parent=archive end
  root.Parent=map
  return {path=root:GetFullName(),specimens=5,core=true}
 end}
return {bytes=#encoded,counts=counts,position='x=-18.5..18.5, z=-12, ground=4.18'}
