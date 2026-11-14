-- All observers sample the same server-launched chunks. These views have no
-- collision or damage authority and never replay old impact sounds on join.
local V={};V.__index=V
function V.new(world,parent,audio)
 local self=setmetatable({records={},connections={},audio=audio},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('RockFragment') or self.records[source] then return end
  local from,velocity=source:GetAttribute('Origin'),source:GetAttribute('LaunchVelocity')
  if typeof(from)~='Vector3' or typeof(velocity)~='Vector3' then return end
  local now=workspace:GetServerTimeNow();local impact=source:GetAttribute('ImpactAt') or 0
  if now>(source:GetAttribute('ExpiresAt') or 0) or impact>0 then return end
  local part=Instance.new('Part');part.Name='FlyingRockChunk';part.Size=source.Size;part.Color=source.Color
  part.Material=Enum.Material.Rock;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  part.CFrame=CFrame.new(from);part.Parent=parent
  self.records[source]={part=part,from=from,velocity=velocity,started=source:GetAttribute('StartedAt'),seed=source:GetAttribute('FragmentId') or 0}
 end
 for _,source in ipairs(world:GetDescendants()) do add(source) end
 table.insert(self.connections,world.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 return self
end
function V:update(now)
 for source,r in pairs(self.records) do
  local impact=source:GetAttribute('ImpactAt') or 0
  if not source.Parent or now>(source:GetAttribute('ExpiresAt') or 0) or impact>0 then
   if source.Parent and impact>0 and now-impact<.2 and source:GetAttribute('HitRock') and self.audio then
    self.audio:play('rock_clack',source:GetAttribute('ImpactPosition') or r.part.Position,{pitch=.72,level=.9})
   end
   r.part:Destroy();self.records[source]=nil
  else
   local t=math.max(0,now-r.started)
   r.part.CFrame=CFrame.new(RockCascade.position(r.from,r.velocity,t))*CFrame.Angles(t*5+r.seed,t*3,t*4)
  end
 end
end
function V:destroy()
 self.closed=true
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 for _,r in pairs(self.records) do r.part:Destroy() end
 self.records={}
end
return V
