assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game:GetService('RunService'):IsEdit())
local map=workspace.MiningAway.Map;assert(not map:FindFirstChild('QuarryNaturalMeadow'))
local root=Instance.new('Folder');root.Name='QuarryNaturalMeadow'
local rng=Random.new(726319);local v=Vector3.new
local protected={};local occupied={}
local function reserve(p,margin,list)
 local h=p.Size/2;local cf=p.CFrame
 table.insert(list,{x=cf.X,z=cf.Z,rx=math.abs(cf.RightVector.X)*h.X+math.abs(cf.LookVector.X)*h.Z+margin,rz=math.abs(cf.RightVector.Z)*h.X+math.abs(cf.LookVector.Z)*h.Z+margin})
end
for _,f in ipairs(workspace.MiningAway.Fields:GetChildren()) do reserve(f.Field,6,protected) end
for _,p in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetChildren()) do if p:IsA('BasePart') then reserve(p,3,protected) end end
for _,p in ipairs(map.SimpleFlatTestMap:GetDescendants()) do if p:IsA('BasePart') and p.Name:match('Pad$') and p.Name~='HubPad' then reserve(p,3,protected) end end
for _,g in ipairs({map.QuarryMotifScenery,map.QuarryCourtyard,map.QuarryContinuousGround.PatternedAccents,map.QuarryContinuousGround.OriginalDetails}) do
 for _,p in ipairs(g:GetDescendants()) do if p:IsA('BasePart') and p.Size.Y>.3 and p.Name~='GravelCourt' then reserve(p,1,occupied) end end
end
local ray=RaycastParams.new();ray.RespectCanCollide=true
local surfaces={}
for _,region in ipairs(map.QuarryContinuousGround.Terraces:GetChildren()) do
 surfaces[region.Name]={}
 for _,p in ipairs(region:GetChildren()) do if p.Name:match('^Turf') then table.insert(surfaces[region.Name],p) end end
end
surfaces.Hub={map.SimpleFlatTestMap.HubPad}
local function canPlace(x,z,r)
 for _,list in ipairs({protected,occupied}) do for _,b in ipairs(list) do if math.abs(x-b.x)<r+b.rx and math.abs(z-b.z)<r+b.rz then return false end end end
 return true
end
local stats={tall=0,small=0,bush=0,tuft=0,flowers=0,gradients=0};local anchors={}
local templates=map.QuarryContinuousGround.OriginalDetails.Quartz
local small=Instance.new('Model');small.Name='SmallTreeTemplate'
for _,p in ipairs(map.QuarryCourtyard.Quartz.SteppedTree:GetChildren()) do p:Clone().Parent=small end
local function templateFor(region,kind)
 local own=map.QuarryContinuousGround.OriginalDetails:FindFirstChild(region) or templates
 if kind=='small' then return small end
 if region=='Cobalt' and (kind=='tall' or kind=='bush') then return own:FindFirstChild(kind=='tall' and 'Blue Trumpet' or 'Small Mushroom') end
 local needle=({tall='Tree1',bush='Bush',tuft='Grass',flowers='Flowers'})[kind]
 for _,p in ipairs(own:GetChildren()) do if p:IsA('Model') and p.Name:find(needle) then return p end end
 for _,p in ipairs(templates:GetChildren()) do if p:IsA('Model') and p.Name:find(needle) then return p end end
end
local function plant(region,kind,group)
 if region=='Cobalt' and kind=='small' then kind='bush' end
 local t=templateFor(region,kind);if not t then return end
 local clone=t:Clone();clone.Name=kind
 local scale=({tall=rng:NextNumber(.65,.95),small=rng:NextNumber(.58,.82),bush=rng:NextNumber(.65,.95),tuft=rng:NextNumber(.7,1.1),flowers=rng:NextNumber(.65,1.0)})[kind]
 clone:ScaleTo(clone:GetScale()*scale)
 local cf,size=clone:GetBoundingBox();local radius=math.max(size.X,size.Z)/2+1
 for attempt=1,160 do
  local ss=surfaces[region];local surface=ss[rng:NextInteger(1,#ss)]
  local x=surface.Position.X+rng:NextNumber(-surface.Size.X*.44,surface.Size.X*.44)
  local z=surface.Position.Z+rng:NextNumber(-surface.Size.Z*.44,surface.Size.Z*.44)
  if (kind=='flowers' or kind=='tuft') and anchors[region] and #anchors[region]>0 and attempt<60 then
   local a=anchors[region][rng:NextInteger(1,#anchors[region])];local angle=rng:NextNumber(0,math.pi*2);local d=rng:NextNumber(a.r+3,a.r+13)
   x,z=a.x+math.cos(angle)*d,a.z+math.sin(angle)*d
  end
  if not canPlace(x,z,radius) then continue end
  local y=surface.Position.Y+surface.Size.Y/2;local top;local clear=true
  for _,offset in ipairs({v(0,0,0),v(radius,0,radius),v(-radius,0,radius),v(radius,0,-radius),v(-radius,0,-radius)}) do
   local h=workspace:Raycast(v(x,y+2,z)+offset,v(0,-3,0),ray)
   if not h or h.Normal.Y<.98 or not h.Instance.MaterialVariant:match('^QuarryRestoredTurf_') then clear=false;break end
   top=math.max(top or h.Position.Y,h.Position.Y)
  end
  if not clear then continue end
  local pivot=clone:GetPivot();local bottom=cf.Position.Y-size.Y/2
  clone:PivotTo(CFrame.new(x,top+(pivot.Y-bottom),z)*CFrame.Angles(0,rng:NextNumber(-math.pi,math.pi),0)*pivot.Rotation)
  for _,p in ipairs(clone:GetDescendants()) do
   if p:IsA('BasePart') then
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    if p.Material==Enum.Material.LeafyGrass then p.Color=Color3.fromRGB(rng:NextInteger(157,185),rng:NextInteger(202,233),rng:NextInteger(95,132)) end
   elseif p:IsA('LuaSourceContainer') then p:Destroy() end
  end
  clone.Parent=group
  table.insert(occupied,{x=x,z=z,rx=radius,rz=radius})
  if kind=='tall' or kind=='small' or kind=='bush' then anchors[region]=anchors[region] or {};table.insert(anchors[region],{x=x,z=z,r=radius}) end
  stats[kind]+=1;return
 end
 clone:Destroy()
end
for _,region in ipairs({'Quartz','Impact','Ruby','Cobalt','Violet','Emerald','Hub'}) do
 local group=Instance.new('Folder');group.Name=region
 local counts=region=='Hub' and {tall=1,small=2,bush=2,tuft=5,flowers=5} or {tall=3,small=4,bush=4,tuft=12,flowers=9}
 for _,kind in ipairs({'tall','small','bush','tuft','flowers'}) do for i=1,counts[kind] do plant(region,kind,group) end end
 group.Parent=root;task.wait()
end
small:Destroy()
-- Soft yellow-green blooms fade in both axes; the original grass remains visible.
local gradients=Instance.new('Folder');gradients.Name='SunlitGrass';gradients.Parent=root
for _,p in ipairs(map.QuarryMeadowLayers:GetDescendants()) do
 if p:IsA('Part') and tonumber(p.Name:match('%d+'))%2==0 then
  local carrier=Instance.new('Part');carrier.Name='GrassGradient';carrier.Size=v(p.Size.X,.01,p.Size.Z);carrier.CFrame=p.CFrame*CFrame.new(0,p.Size.Y/2+.025,0)
  carrier.Transparency=1;carrier.Anchored=true;carrier.CanCollide=false;carrier.CanTouch=false;carrier.CanQuery=false;carrier.CastShadow=false
  local gui=Instance.new('SurfaceGui');gui.Name='SoftGrassTint';gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(480,480);gui.LightInfluence=1;gui.AlwaysOnTop=false;gui.MaxDistance=450;gui.Parent=carrier
  for i=0,47 do
   local x=(i+.5)/48;local alpha=.16*math.sin(x*math.pi)^2
   local frame=Instance.new('Frame');frame.Name='Blend';frame.BorderSizePixel=0;frame.Position=UDim2.fromScale(i/48,0);frame.Size=UDim2.fromScale(1/48,1);frame.BackgroundColor3=Color3.fromRGB(232,226,108);frame.BackgroundTransparency=1-alpha;frame.Parent=gui
   local fade=Instance.new('UIGradient');fade.Rotation=90;fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.22,.45),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.78,.45),NumberSequenceKeypoint.new(1,1)});fade.Parent=frame
  end
  carrier.Parent=gradients;stats.gradients+=1
 end
end
local se,en=game:GetService('SerializationService'),game:GetService('EncodingService')
local model=buffer.tostring(en:Base64Encode(en:CompressBuffer(se:SerializeInstancesAsync({root}),Enum.CompressionAlgorithm.Zstd)))
shared.NaturalMeadow={apply=function()assert(not root.Parent);root.Parent=map;return stats end}
return game.HttpService:JSONEncode({scenery=model,stats=stats})
