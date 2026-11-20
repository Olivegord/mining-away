-- Client-only continuous meadow using xander22's rigged SkinnedGrass.
-- Rendering tiles have no visible boundaries: every blade is individually placed.
local F={};F.__index=F
function F.new(world,parent)
 local self=setmetatable({alive=true,models={}},F)
 task.spawn(function()
  local rs=game:GetService('ReplicatedStorage')
  local assets=rs:WaitForChild('SkinnedGrass',30)
  local planting=world:WaitForChild('FoliagePatches',30)
  if not self.alive then return end
  if not assets or not planting then warn('Mining Away: grass assets/planting data missing');return end
  local ok,result=pcall(function()
   local module=require(assets:WaitForChild('SkinnedGrass'))
   local template=assets.Studio.Models.Model
   self.folder=Instance.new('Folder');self.folder.Name='InteractiveGrass';self.folder.Parent=parent
   self.storage=Instance.new('Folder');self.storage.Name='MiningAwayGrassStorage';self.storage.Parent=rs
   self.grass=module.new({MeshStorage=self.storage,RenderDistance=100,
    RenderInAnimation=false,RenderOutAnimation=false,
    CollisionDistance=55,CollisionRadiusInner=3.5,CollisionRadiusOuter=6,
    CollisionAngle=65,CollisionReturnInfo=TweenInfo.new(1.15,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),
    UseGlobalWind=false,WindDirection=Vector3.new(1,0,.35),WindSpeed=5,
    WindAngleMin=5,WindAngleMax=12,WindDistanceInner=18,WindDistanceOuter=38,
    WindFramerateInner=1,WindFramerateOuter=.25})
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
   local ground={world:WaitForChild('Map'):WaitForChild('ConnectedCliffs')}
   local base=workspace:FindFirstChild('Baseplate');if base then table.insert(ground,base) end
   params.FilterDescendantsInstances=ground
   local function create(marker)
    local roots=game:GetService('HttpService'):JSONDecode(marker:GetAttribute('Blades'))
    local model=template:Clone();model.Name=marker.Name
    local mesh=model:FindFirstChildOfClass('MeshPart')
    model.PrimaryPart=mesh;mesh.PivotOffset=CFrame.new()
    -- Short blades retain the original rig; roots spread across adjacent batches.
    model:ScaleTo(model:GetScale()*.55)
    mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false;mesh.CastShadow=false
    mesh.Reflectance=0;mesh.Material=Enum.Material.SmoothPlastic
    -- Keep the author's four-sided root shading over the original blade mesh.
    -- Slowly varying world-space tones avoid visible color blocks at batch edges.
    local tone=math.clamp((math.noise(marker.Value.X*.008,marker.Value.Z*.008)+.2)*1.7,0,1)
    mesh.Color=Color3.fromRGB(92,158,102):Lerp(Color3.fromRGB(187,192,102),tone)
    for _,decal in ipairs(mesh:GetChildren()) do if decal:IsA('Decal') then
     decal.Color3=Color3.fromRGB(35,80,44):Lerp(Color3.fromRGB(87,94,40),tone)
    end end
    model:PivotTo(CFrame.new(marker.Value))
    local bones={}
    for _,b in ipairs(mesh:GetChildren()) do if b:IsA('Bone') then table.insert(bones,b) end end
    table.sort(bones,function(a,b) return a.Name<b.Name end)
    for n,bone in ipairs(bones) do
     local data=roots[n]
     if data then
      local at=Vector3.new(data[1],data[2],data[3])
      local hit=workspace:Raycast(at+Vector3.new(0,5,0),Vector3.new(0,-10,0),params)
      local height=hit and hit.Position.Y or at.Y
      local yaw=(math.sin(at.X*13.7+at.Z*9.3)*4137)%6.283
      bone.WorldCFrame=CFrame.new(at.X,height-.035,at.Z)*CFrame.Angles(0,yaw,0)*bone.WorldCFrame.Rotation
     else
      bone:SetAttribute('FoliageHidden',true)
      bone.WorldCFrame=CFrame.new(marker.Value-Vector3.new(0,60,0))*bone.WorldCFrame.Rotation
     end
    end
    model.Parent=self.folder;self.models[marker]=model
    self.grass:AddMeshes({model})
   end
   local markers=planting:GetChildren();local queue={};local elapsed=1
   self.connection=game:GetService('RunService').RenderStepped:Connect(function(dt)
    local player=game:GetService('Players').LocalPlayer
    local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    local center=root and root.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
    if not center then return end
    elapsed+=dt
    if elapsed>.3 then
     elapsed=0;queue={}
     for marker,model in pairs(self.models) do if (marker.Value-center).Magnitude>115 then
      self.grass:RemoveMeshes({model});model:Destroy();self.models[marker]=nil
     end end
     for _,marker in ipairs(markers) do
      if not self.models[marker] and (marker.Value-center).Magnitude<95 then table.insert(queue,marker) end
     end
     table.sort(queue,function(a,b) return (a.Value-center).Magnitude>(b.Value-center).Magnitude end)
    end
    -- Bounded construction prevents a large forest from stalling one frame.
    for _=1,3 do
     local marker=table.remove(queue)
     if marker and not self.models[marker] then create(marker) end
    end
    local collisions={}
    for _,other in ipairs(game:GetService('Players'):GetPlayers()) do
     local otherRoot=other.Character and other.Character:FindFirstChild('HumanoidRootPart')
     if otherRoot and (otherRoot.Position-center).Magnitude<55 then table.insert(collisions,otherRoot.Position) end
    end
    self.grass:Step(math.min(dt,.1),collisions,center)
   end)
  end)
  if not ok then warn('Mining Away: grass setup failed: '..tostring(result));self:destroy() end
 end)
 return self
end
function F:destroy()
 self.alive=false
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,model in pairs(self.models) do model:Destroy() end
 self.models={};self.grass=nil
 if self.folder then self.folder:Destroy() end
 if self.storage then self.storage:Destroy() end
end
return F
