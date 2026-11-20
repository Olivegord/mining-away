-- Apply the reviewed correction to the already-authored Ruby scenery only.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning())
local root=workspace.MiningAway
assert(root:GetAttribute('QuarrySceneryAuthored'))
local map=root.Map
local bed=root.Fields.Ruby.Field
local crowns,ground,leaves=0,0,0
for _,p in ipairs(map.DronerevolutionTerraces:GetDescendants()) do
 if not p:IsA('BasePart') then continue end
 if p.MaterialVariant=='QuarryBiome_Crimson' then
  local noise=math.noise(p.Position.X*.058,p.Position.Z*.058)
  p.Color=Color3.fromRGB(248,237,221):Lerp(Color3.fromRGB(221,215,204),math.clamp(.5+noise,0,1))
  leaves+=1
 elseif p.Name=='RubyEdgeWeathering' and p.MaterialVariant=='QuarryPhoto_Pebble' then
  local noise=math.noise(p.Position.X*.058,p.Position.Z*.058)
  p.Material=Enum.Material.Slate;p.MaterialVariant='QuarryBiome_Shale'
  p.Color=Color3.fromRGB(174,195,223):Lerp(Color3.fromRGB(116,132,156),math.clamp(.45+noise,0,1))
  ground+=1
 end
end
for _,group in ipairs(map.RubyCrimsonBluffs:GetChildren()) do
 if group.Name~='FracturedCliff' then continue end
 local plates={}
 for _,p in ipairs(group:GetChildren()) do
  if p.Name=='SplitRockFace' then table.insert(plates,p)
  elseif p.Name=='BrokenCrown' then p:Destroy() end
 end
 assert(#plates==5)
 local height=plates[3].Size.Y
 for i,p in ipairs(plates) do
  local crown=Instance.new('WedgePart');crown.Name='JaggedCrown';crown.Anchored=true
  crown.CanCollide=false;crown.CanQuery=false;crown.CanTouch=false
  crown.TopSurface=Enum.SurfaceType.Smooth;crown.BottomSurface=Enum.SurfaceType.Smooth
  crown.Size=Vector3.new(p.Size.Z*.99,height*(.12+.025*(i%3)),p.Size.X*1.02)
  crown.CFrame=p.CFrame*CFrame.new(0,p.Size.Y*.5+crown.Size.Y*.5-.15,0)*CFrame.Angles(0,i%2==0 and math.pi*.5 or -math.pi*.5,0)
  crown.Color=Color3.fromRGB(208,220,240);crown.Material=Enum.Material.Slate;crown.MaterialVariant='QuarryBiome_Shale';crown.Parent=group
  crowns+=1
 end
end
assert(crowns==25 and leaves>0 and ground>0)
return {crowns=crowns,scarletGroundParts=leaves,shaleOverlayParts=ground,fieldPosition=tostring(bed.Position),fieldSize=tostring(bed.Size)}
