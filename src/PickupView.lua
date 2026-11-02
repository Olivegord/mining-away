-- All observers see the same owner-bound ore; local interpolation never grants it.
local V={};V.__index=V
function V.new(root,parent)
 local self=setmetatable({records={},parent=parent,root=root,connections={}},V)
 local function add(source)
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.Parent=parent
  source.LocalTransparencyModifier=1
  local a=Instance.new('Attachment');a.Position=Vector3.new(0,.08,0);a.Parent=view
  local b=Instance.new('Attachment');b.Position=Vector3.new(0,-.08,0);b.Parent=view
  local trail=Instance.new('Trail');trail.Name='OreMagnetTrail';trail.Attachment0=a;trail.Attachment1=b
  trail.Color=ColorSequence.new(source.Color);trail.Lifetime=.15;trail.MinLength=.1;trail.FaceCamera=true
  trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,1)});trail.Enabled=false;trail.Parent=view
  self.records[source]={view=view,pos=position,trail=trail,seed=source:GetAttribute('PickupId')}
 end
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source];if r then r.view:Destroy();self.records[source]=nil end
 end))
 return self
end
function V:update(dt,now)
 for source,r in pairs(self.records) do
  if source.Parent then
   local velocity=source:GetAttribute('Velocity') or Vector3.zero
   local predicted=(source:GetAttribute('Position') or source.Position)+velocity*math.clamp(now-(source:GetAttribute('SnapshotAt') or now),0,.1)
   r.pos=r.pos:Lerp(predicted,1-math.exp(-math.min(dt,.1)*24))
   r.view.CFrame=CFrame.new(r.pos)*CFrame.Angles(now*.7+r.seed,r.seed*.9,now*.5)
   r.trail.Enabled=velocity.Magnitude>8
  end
 end
end
function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do source.LocalTransparencyModifier=0;r.view:Destroy() end
 self.records={}
end
return V
