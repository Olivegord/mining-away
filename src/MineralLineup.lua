-- Authored specimens remain in Edit. Play substitutes the exact drop renderer,
-- with no pickup IDs, rewards, attraction or expiry.
local L={}
function L.new(parent,add,finish)
 local map=workspace:FindFirstChild('MiningAway')
 map=map and map:FindFirstChild('Map')
 local root=map and map:FindFirstChild('MineralLineup')
 local self={sources={},hidden={},finish=finish}
 if not root then return self end
 local born=workspace:GetServerTimeNow()-10
 for i,key in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
  local model=root:FindFirstChild(key)
  local anchor=model and model:FindFirstChild('SpecimenAnchor')
  if anchor then
   -- Feed inert local samples through PickupView.add and its entire update
   -- path: mesh, opacity, pose, ground glow, strand, motes and glints.
   local source=anchor:Clone();source.Name='RawCrystalCargo'
   source.Size=Vector3.new(table.unpack(Workshop.ROCK_SIZE))
   local floor=model.DisplayPad.Position.Y+model.DisplayPad.Size.Y*.5+.22
   local position=Vector3.new(anchor.Position.X,floor,anchor.Position.Z)
   source.Position=position;source.Transparency=0
   for name,value in pairs({PickupId=-i,PhysicalCargo=true,Units=1,Mineral=key,
    Position=position,Velocity=Vector3.zero,FloorY=floor,SnapshotAt=born+2,SpawnAt=born,
    GroundImpactAt=born+1,GroundImpactPosition=position,GroundImpactSpeed=0,
    OreLaunchOrigin=position+Vector3.yAxis,OreLaunchVelocity=Vector3.new(.01,1,0),CleanCargoArc=true}) do
    source:SetAttribute(name,value)
   end
   source.Parent=parent;self.sources[#self.sources+1]=source
   add(source)
   for _,p in ipairs(model.PreviewGeometry:GetDescendants()) do
    if p:IsA('BasePart') then p.LocalTransparencyModifier=1;self.hidden[#self.hidden+1]=p end
   end
  end
 end
 local specimen=root:FindFirstChild('CoreSpecimen')
 local shell=specimen and specimen:FindFirstChild('Shell')
 if shell then
  local clone=shell:Clone();clone.Parent=parent;clone.LocalTransparencyModifier=0
  self.core={source=clone,view=clone,baseColor=Color3.fromRGB(120,215,219),visual={broken=false}}
  self.coreHidden={shell};self.coreFX={};shell.LocalTransparencyModifier=1
  for _,p in ipairs(shell:GetDescendants()) do
   if p:IsA('BasePart') then p.LocalTransparencyModifier=1;self.coreHidden[#self.coreHidden+1]=p
   elseif p:IsA('Beam') or p:IsA('ParticleEmitter') then self.coreFX[p]=p.Enabled;p.Enabled=false end
  end
  -- Clear authored presentation from the clone; it gets the live renderer.
  for _,child in ipairs(clone:GetChildren()) do if child.Name~='CoreGeometry' then child:Destroy() end end
 end
 return self
end
function L.update(self,now,reducedMotion,reducedEffects)
 if self.core then self.finish.veins(self.core,now,reducedEffects,reducedMotion) end
end
function L.destroy(self)
 for _,source in ipairs(self.sources) do source:Destroy() end
 for _,p in ipairs(self.hidden) do if p.Parent then p.LocalTransparencyModifier=0 end end
 if self.core then self.core.view:Destroy() end
 for p,enabled in pairs(self.coreFX or {}) do if p.Parent then p.Enabled=enabled end end
 for _,p in ipairs(self.coreHidden or {}) do if p.Parent then p.LocalTransparencyModifier=0 end end
end
return L
