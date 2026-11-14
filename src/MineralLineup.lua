-- Authored specimens remain in Edit. Play substitutes the exact drop renderer,
-- with no pickup IDs, rewards, attraction or expiry.
local L={}
function L.new(parent,gems,finish)
 local map=workspace:FindFirstChild('MiningAway')
 map=map and map:FindFirstChild('Map')
 local root=map and map:FindFirstChild('MineralLineup')
 local self={records={},gems=gems,finish=finish}
 if not root then return self end
 for _,model in ipairs(root:GetChildren()) do
  local anchor=model:FindFirstChild('SpecimenAnchor')
  if anchor then
   local view,faceted=gems.clone(anchor)
   if faceted then
    view.Name='MineralDisplay';view.Parent=parent
    local record={view=view,frame=anchor.CFrame,hidden={}}
    for _,p in ipairs(model.PreviewGeometry:GetDescendants()) do
     if p:IsA('BasePart') then p.LocalTransparencyModifier=1;record.hidden[#record.hidden+1]=p end
    end
    self.records[#self.records+1]=record
   else view:Destroy() end
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
 for i,r in ipairs(self.records) do
  local t=reducedMotion and 0 or now
  r.view.CFrame=r.frame*CFrame.Angles(0,t*2*math.pi/30,0)+Vector3.yAxis*(.045*math.sin(t*2*math.pi/1.4+i))
  self.gems.update(r.view,1)
 end
 if self.core then self.finish.veins(self.core,now,reducedEffects,reducedMotion) end
end
function L.destroy(self)
 for _,r in ipairs(self.records) do
  r.view:Destroy()
  for _,p in ipairs(r.hidden) do if p.Parent then p.LocalTransparencyModifier=0 end end
 end
 if self.core then self.core.view:Destroy() end
 for p,enabled in pairs(self.coreFX or {}) do if p.Parent then p.Enabled=enabled end end
 for _,p in ipairs(self.coreHidden or {}) do if p.Parent then p.LocalTransparencyModifier=0 end end
end
return L
