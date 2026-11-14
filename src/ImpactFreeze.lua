-- Hold only the breaking crystal's presentation. Camera and world clocks run normally.
local Freeze={}
Freeze.__index=Freeze
local beats={
 Split={1/60,24}, HeavySplit={2/60,32}, Nomad={.055,50},
}
function Freeze.new(player)
 return setmetatable({player=player,last=-math.huge,held={},pending={}},Freeze)
end
function Freeze:request(kind,record)
 local beat=beats[kind]
 local camera=workspace.CurrentCamera
 if not beat or not camera or camera:GetAttribute('FleetCamera') then return end
 local position=record.restPose.Position
 local root=self.player.Character and self.player.Character:FindFirstChild('HumanoidRootPart')
 if ((root and root.Position or camera.CFrame.Position)-position).Magnitude>beat[2] then return end
 if (camera.CFrame.Position-position).Magnitude>beat[2]+25 then return end
 local _,visible=camera:WorldToViewportPoint(position)
 if visible then self.pending[record]=kind end
end
function Freeze:beginFrame(now,dt,reduced)
 local camera=workspace.CurrentCamera
 local disabled=reduced or not camera or camera:GetAttribute('FleetCamera')
 if self.untilAt and (disabled or now+math.min(dt*.15,.004)>=self.untilAt) then
  table.clear(self.held);self.untilAt=nil;self.nomadAt=nil
 end
 if not disabled and not self.untilAt and now-self.last>=.9 then
  local duration=0
  for record,kind in pairs(self.pending) do
   self.held[record]=true
   duration=math.max(duration,beats[kind][1])
   if kind=='Nomad' then self.nomadAt=record.breakHoldRequestedAt end
  end
  if duration>0 then self.last=now;self.untilAt=now+duration end
 end
 table.clear(self.pending)
end
function Freeze:holds(record)
 return self.held[record] or self.nomadAt~=nil and record.breakHoldRequestedAt==self.nomadAt
  and record.source:GetAttribute('CutProjectile')=='Nomad'
end
function Freeze:holdsNomad(at)
 return self.nomadAt~=nil and math.abs(self.nomadAt-at)<.001
end
return Freeze
