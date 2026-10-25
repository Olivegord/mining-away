-- Client-only integration of xander22's SkinnedGrass. See reference/skinned-grass.
local F={};F.__index=F
function F.new(world,parent)
 local self=setmetatable({alive=true,models={}},F)
 task.spawn(function()
  local rs=game:GetService('ReplicatedStorage')
  local assets=rs:WaitForChild('SkinnedGrass',30)
  local patches=world:WaitForChild('FoliagePatches',30)
  if not self.alive then return end
  if not assets or not patches then warn('Mining Away: SkinnedGrass assets/planting markers missing');return end
  local ok,result=pcall(function()
   local module=require(assets:WaitForChild('SkinnedGrass'))
   local template=assets.Studio.Models.Model
   self.folder=Instance.new('Folder');self.folder.Name='InteractiveGrass';self.folder.Parent=parent
   self.storage=Instance.new('Folder');self.storage.Name='MiningAwayGrassStorage';self.storage.Parent=rs
   self.grass=module.new({MeshStorage=self.storage,RenderDistance=110,
    RenderInAnimation=false,RenderOutAnimation=false,
    CollisionDistance=65,CollisionRadiusInner=3.5,CollisionRadiusOuter=6,
    CollisionAngle=65,CollisionReturnInfo=TweenInfo.new(1.15,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),
    UseGlobalWind=false,WindDirection=Vector3.new(1,0,.35),WindSpeed=5,
    WindAngleMin=7,WindAngleMax=16,WindDistanceInner=24,WindDistanceOuter=75,
    WindFramerateInner=1,WindFramerateOuter=.25})
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
   local ground={world:WaitForChild('Map'):WaitForChild('ConnectedCliffs')}
   local base=workspace:FindFirstChild('Baseplate');if base then table.insert(ground,base) end
   params.FilterDescendantsInstances=ground
   for i,marker in ipairs(patches:GetChildren()) do
    if not self.alive then return end
    local model=template:Clone();model.Name=marker.Name
    local mesh=model:FindFirstChildOfClass('MeshPart')
    model.PrimaryPart=mesh;mesh.PivotOffset=CFrame.new()
    local width=marker:GetAttribute('Width') or 8
    -- Scale the real rig as a unit; changing MeshPart.Size alone breaks skinning.
    local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
    for _,b in ipairs(mesh:GetChildren()) do if b:IsA('Bone') then
     local at=b.WorldCFrame.Position
     minX=math.min(minX,at.X);maxX=math.max(maxX,at.X);minZ=math.min(minZ,at.Z);maxZ=math.max(maxZ,at.Z)
    end end
    -- The supplied mesh has a padded 100-stud bounding box around a 14-stud
    -- planting rig. Use blade roots, otherwise each patch becomes a tiny tuft.
    local footprint=math.max(maxX-minX,maxZ-minZ)*1.1
    assert(footprint>0 and footprint<math.huge,'SkinnedGrass template has no planting rig')
    model:ScaleTo(model:GetScale()*width/footprint)
    mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false;mesh.CastShadow=false
    mesh.Material=Enum.Material.SmoothPlastic;mesh.Reflectance=0
    mesh.Color=Color3.fromRGB(104,153,102)
    model:PivotTo(CFrame.new(marker.Value))
    for _,bone in ipairs(mesh:GetChildren()) do if bone:IsA('Bone') then
     local at=bone.WorldCFrame.Position
     local hit=workspace:Raycast(Vector3.new(at.X,marker.Value.Y+10,at.Z),Vector3.new(0,-25,0),params)
     local height=marker.Value.Y
     if hit then height=hit.Position.Y else
      -- Streaming may delay the floor. The server's sampled slope still grounds it.
      local u=math.clamp((at.X-marker.Value.X)/width+.5,0,1)
      local v=math.clamp((at.Z-marker.Value.Z)/(marker:GetAttribute('Depth') or width)+.5,0,1)
      local h00=marker:GetAttribute('H00') or height;local h10=marker:GetAttribute('H10') or height
      local h01=marker:GetAttribute('H01') or height;local h11=marker:GetAttribute('H11') or height
      height=(h00+(h10-h00)*u)*(1-v)+(h01+(h11-h01)*u)*v
     end
     bone.WorldCFrame=CFrame.new(at.X,height-.025,at.Z)*bone.WorldCFrame.Rotation
    end end
    model.Parent=self.folder;table.insert(self.models,model)
    self.grass:AddMeshes({model})
    if i%4==0 then task.wait() end
   end
   if not self.alive then return end
   self.folder:SetAttribute('Patches',#self.models)
   self.connection=game:GetService('RunService').RenderStepped:Connect(function(dt)
    local player=game:GetService('Players').LocalPlayer
    local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    local center=root and root.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
    if not center then return end
    local collisions={}
    -- Read the current characters each frame so respawns and other players work.
    for _,other in ipairs(game:GetService('Players'):GetPlayers()) do
     local otherRoot=other.Character and other.Character:FindFirstChild('HumanoidRootPart')
     if otherRoot and (otherRoot.Position-center).Magnitude<65 then table.insert(collisions,otherRoot.Position) end
    end
    self.grass:Step(math.min(dt,.1),collisions,center)
   end)
  end)
  if not ok then warn('Mining Away: SkinnedGrass setup failed: '..tostring(result));self:destroy() end
 end)
 return self
end
function F:destroy()
 self.alive=false
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,model in ipairs(self.models) do model:Destroy() end
 self.models={};self.grass=nil
 if self.folder then self.folder:Destroy() end
 if self.storage then self.storage:Destroy() end
end
return F
