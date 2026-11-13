-- A brief hold of the rendered world. The server and input keep their own clocks.
local Freeze={}
Freeze.__index=Freeze
local beats={
 Split={.055,24}, HeavySplit={.085,32}, Breaker={.075,34},
 Orbital={.105,44}, Prism={.115,46}, Nomad={.115,50}, Star={.105,52},
}
function Freeze.new(player)
 return setmetatable({player=player,last=-math.huge,emitters={},hidden={}},Freeze)
end
function Freeze:request(kind,position)
 local beat=beats[kind]
 local camera=workspace.CurrentCamera
 if not beat or not camera or self.untilAt or camera:GetAttribute('FleetCamera') then return end
 local root=self.player.Character and self.player.Character:FindFirstChild('HumanoidRootPart')
 if ((root and root.Position or camera.CFrame.Position)-position).Magnitude>beat[2] then return end
 if (camera.CFrame.Position-position).Magnitude>beat[2]+25 then return end
 local _,visible=camera:WorldToViewportPoint(position)
 if not visible then return end
 local duration=beat[1]
 if not self.pending or duration>self.pending then self.pending=duration end
end
function Freeze:release()
 if self.actors then self.actors:Destroy();self.actors=nil end
 for part,modifier in pairs(self.hidden) do if part.Parent then part.LocalTransparencyModifier=modifier end end
 for emitter,scale in pairs(self.emitters) do if emitter.Parent then emitter.TimeScale=scale end end
 table.clear(self.emitters);table.clear(self.hidden)
 self.untilAt=nil;self.cameraFrame=nil;self.focus=nil;self.fov=nil;self.camera=nil
end
local function actorPose(self,character)
 local model=Instance.new('Model')
 for _,part in ipairs(character:GetDescendants()) do
  if not part:IsA('BasePart') or part.Transparency>=1 or part.LocalTransparencyModifier>=1 then continue end
  local archivable=part.Archivable;part.Archivable=true
  local pose=part:Clone();part.Archivable=archivable
  for _,child in ipairs(pose:GetDescendants()) do
   if child:IsA('JointInstance') or child:IsA('Constraint') or child:IsA('Attachment') and not child:IsA('Bone')
    or child:IsA('LuaSourceContainer') or child:IsA('Sound') or child:IsA('LayerCollector')
    or child:IsA('BasePart') or child:IsA('Light') or child:IsA('PostEffect') then child:Destroy() end
  end
  pose.CFrame=part.CFrame;pose.Anchored=true;pose.CanCollide=false;pose.CanTouch=false;pose.CanQuery=false
  pose.LocalTransparencyModifier=part.LocalTransparencyModifier
  pose.Parent=model
  self.hidden[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1
  for _,decal in ipairs(part:GetChildren()) do
   if decal:IsA('Decal') then self.hidden[decal]=decal.LocalTransparencyModifier;decal.LocalTransparencyModifier=1 end
  end
 end
 model.Parent=self.actors
end
function Freeze:beginFrame(now,reduced,localFX)
 if self.untilAt then
  if now<self.untilAt and not reduced and self.camera==workspace.CurrentCamera then return true,0 end
  local elapsed=now-self.last
  self:release()
  return false,elapsed
 end
 local duration=self.pending;self.pending=nil
 if not duration or reduced or now-self.last<.9 then return false,0 end
 local camera=workspace.CurrentCamera;if not camera or camera:GetAttribute('FleetCamera') then return false,0 end
 self.last=now;self.untilAt=now+duration;self.camera=camera
 self.cameraFrame=camera.CFrame;self.focus=camera.Focus;self.fov=camera.FieldOfView
 local function particles(part)
  if part:IsA('ParticleEmitter') and self.emitters[part]==nil then
   self.emitters[part]=part.TimeScale
   part.TimeScale=0
  end
 end
 for _,part in ipairs(localFX:GetDescendants()) do particles(part) end
 for _,child in ipairs(workspace:GetChildren()) do
  if child.Name=='DroneRoleClientEffects' or child.Name=='LaserLaunchAftermath' or child.Name=='ScrapBotPresentation' then
   for _,part in ipairs(child:GetDescendants()) do particles(part) end
  end
 end
 self.actors=Instance.new('Folder');self.actors.Name='ImpactFreezePoses'
 for _,player in ipairs(game:GetService('Players'):GetPlayers()) do
  local character=player.Character
  local root=character and character:FindFirstChild('HumanoidRootPart')
  if root and (root.Position-camera.CFrame.Position).Magnitude<140 then
   for _,part in ipairs(character:GetDescendants()) do particles(part) end
   actorPose(self,character)
  end
 end
 self.actors.Parent=workspace
 return true,0
end
function Freeze:render()
 if not self.untilAt then return end
 local camera=self.camera
 camera.CFrame=self.cameraFrame;camera.Focus=self.focus;camera.FieldOfView=self.fov
 -- The default camera's occlusion pass can update character visibility.
 for part in pairs(self.hidden) do if part.Parent then part.LocalTransparencyModifier=1 end end
end
return Freeze
