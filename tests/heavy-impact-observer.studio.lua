-- Read-only observer for the installed production client. Start in Studio Play,
-- then issue a normal ore order. Records twenty seconds; does not grant damage,
-- edit controllers, change ownership, or play synthetic impact cues.
local player=game:GetService('Players').LocalPlayer
local root=workspace:WaitForChild('MiningAwayPresentation')
local world=workspace:WaitForChild('MiningAway')
local source
for _,n in ipairs(world.Drones:GetChildren()) do if n:GetAttribute('Owner')==player.UserId and n:GetAttribute('Role')=='Charger' then source=n;break end end
assert(source,'Use the Studio role crew')
local view=assert(root:FindFirstChild('View_'..source:GetAttribute('DroneId')))
local result={started=workspace:GetServerTimeNow(),diveSamples={},contacts={},sounds={},maxError=0,frames=0,finished=false}
_G.MiningHeavyReview=result
local lastState='';local connections={}
connections[1]=game:GetService('RunService').RenderStepped:Connect(function() task.defer(function()
 local now=workspace:GetServerTimeNow();result.frames+=1
 local state=source:GetAttribute('State');local impact=source:GetAttribute('BreakerImpact')
 if state=='BreakerDive' then
  local elapsed=now-(source:GetAttribute('BreakerPhaseAt') or now)
  local duration=source:GetAttribute('BreakerDiveDuration') or .28
  local progress=math.clamp(elapsed/duration,0,1)
  local start=source:GetAttribute('BreakerDiveStart')
  local expected=start:Lerp(impact,progress^2.6)
  local actual=view:GetPivot().Position
  local error=(actual-expected).Magnitude;result.maxError=math.max(result.maxError,error)
  table.insert(result.diveSamples,{elapsed=elapsed,progress=progress,height=actual.Y,error=error})
 end
 if state~=lastState and (state=='BreakerImpact' or state=='BreakerRecover') then
  table.insert(result.contacts,{at=now,state=state,phaseAt=source:GetAttribute('BreakerPhaseAt'),contactSerial=source:GetAttribute('BreakerContactSerial'),impactSerial=source:GetAttribute('ImpactSerial'),distance=(view:GetPivot().Position-impact).Magnitude})
 end
 lastState=state
end) end)
connections[2]=root.DescendantAdded:Connect(function(n)
 if n:IsA('Sound') and (n.Name=='breaker_contact' or n.Name=='breaker_fracture') then
  task.defer(function() table.insert(result.sounds,{name=n.Name,id=n.SoundId,pitch=n.PlaybackSpeed,loaded=n.IsLoaded,at=workspace:GetServerTimeNow()}) end)
 end
end)
task.delay(20,function() for _,c in ipairs(connections) do c:Disconnect() end;result.finished=true end)
return {observing=true,drone=source:GetAttribute('DroneId')}
