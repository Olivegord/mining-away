--!strict
-- Server-owned effect receipts only. No cosmetic Parts, tweens or animation.
-- Persistent active records let every observer (including late joiners) render
-- the same effect from server time, without trusting clients with gameplay.
local Debris=game:GetService('Debris')
local Effects={}
local live=0
local MAX_LIVE=256
local markers,burns,swarms={},{},{}
local function folder()
 local root=workspace:FindFirstChild('DroneRoleState')
 if not root then root=Instance.new('Folder');root.Name='DroneRoleState';root.Parent=workspace end
 return root
end
local function record(kind,attributes,lifetime)
 if live>=MAX_LIVE then return nil end
 local node=Instance.new('Folder');node.Name=kind
 node:SetAttribute('Kind',kind);node:SetAttribute('StartedAt',workspace:GetServerTimeNow())
 for key,value in pairs(attributes) do node:SetAttribute(key,value) end
 if lifetime then node:SetAttribute('ExpiresAt',workspace:GetServerTimeNow()+lifetime);Debris:AddItem(node,lifetime) end
 live+=1;node.Destroying:Connect(function() live-=1 end)
 node.Parent=folder();return node
end
local function clear(map,owner)
 local old=map[owner];map[owner]=nil;if old then old:Destroy() end
end
local function point(p) return Vector3.new(p.x,p.y,p.z) end
function Effects.Beam(from,to,color,width,lifetime)
 record('Beam',{From=from,Position=to,Color=color,Width=width or .18,Duration=lifetime or .16},(lifetime or .16)+.85)
end
function Effects.Pulse(position,color,first,last,lifetime)
 record('Pulse',{Position=position,Color=color,First=first or .8,Last=last or 5,Duration=lifetime or .3},(lifetime or .3)+.2)
end
function Effects.Projectile(shape,from,to,color,startedAt,windup,flight,actor,target,anchor,beamHold,visualRecovery,ground)
 -- Pending records are owned by the job. Pause can outlast a fixed TTL;
 -- release destroys a canceled shot and contact starts the short cleanup.
 return record('MiningShot',{Shape=shape,From=from,Position=to,Color=color,StartedAt=startedAt,Windup=windup,Duration=flight,Actor=actor,TargetId=target,TargetAnchor=anchor,BeamHold=beamHold,VisualRecovery=visualRecovery,ScanGround=ground})
end
function Effects.ProjectileContact(node,point,normal,fractured,broken,powered,at)
 if not node or not node.Parent then return end
 node:SetAttribute('ContactPoint',point);node:SetAttribute('ContactNormal',normal)
 node:SetAttribute('ContactFracture',fractured);node:SetAttribute('ContactBroken',broken);node:SetAttribute('ContactPowered',powered)
 node:SetAttribute('ContactAt',at)
 Debris:AddItem(node,math.max(.9,(node:GetAttribute('VisualRecovery') or 0)+.10))
end
function Effects.PrismContact(node,origin,endpoint,primary,contacts,at,groundNormal)
 if not node or not node.Parent then return end
 node:SetAttribute('PrismFrom',origin);node:SetAttribute('PrismEnd',endpoint)
 node:SetAttribute('PrismGroundNormal',groundNormal)
 for i,hit in ipairs(contacts) do
  node:SetAttribute('PrismHit'..i,hit.point);node:SetAttribute('PrismNormal'..i,hit.normal)
 end
 node:SetAttribute('PrismHits',#contacts)
 Effects.ProjectileContact(node,primary.point,primary.normal,false,false,false,at)
end
function Effects.NomadContact(node,point,ground,radius,at)
 if not node or not node.Parent then return end
 node:SetAttribute('ContactPoint',point);node:SetAttribute('BlastGround',ground);node:SetAttribute('BlastRadius',radius)
 node:SetAttribute('ContactAt',at)
end
function Effects.NomadShatter(node,at)
 if not node or not node.Parent then return end
 if at then node:SetAttribute('ShatterAt',at) end
 Debris:AddItem(node,5.2)
end
function Effects.Heal(from,to)
 record('Heal',{From=from,Position=to},.4)
end
function Effects.Charge(position,target,impact)
 record('Charge',{From=position,Position=target,Impact=impact==true},1)
end
function Effects.Grow(from,target,planted)
 record('Grow',{From=from,Position=target,Planted=planted},1.8)
end
function Effects.BreakerPhase(position,target,phase,diameter)
 record('Breaker',{From=position,Position=target,Phase=phase,Diameter=diameter},1.8)
end
local function endBurn(owner)
 local old=burns[owner];burns[owner]=nil
 if old and old.Parent then old:SetAttribute('EndedAt',workspace:GetServerTimeNow());Debris:AddItem(old,4.4) end
end
local function watchBurn(owner,node)
 task.delay(8,function()
  if not node.Parent or node:GetAttribute('EndedAt') then return end
  if workspace:GetServerTimeNow()-(node:GetAttribute('ContactAt') or 0)<8 then watchBurn(owner,node)
  elseif burns[owner]==node then endBurn(owner) end
 end)
end
function Effects.ClearAbility(owner)
 clear(swarms,owner);clear(markers,owner);endBurn(owner)
end
function Effects.Ability(owner,event,template)
 local kind=event.kind;local now=workspace:GetServerTimeNow()
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clear(markers,owner)
 elseif kind=='clearScrap' then clear(swarms,owner)
 elseif kind=='orbitalEnd' then endBurn(owner)
 elseif kind=='charge' then
  clear(markers,owner)
  local duration=event.duration or 1.4
  markers[owner]=record('AbilityCharge',{Owner=owner,Ability=event.ability,Duration=duration,Position=point(event.target),Ground=event.target.ground,Radius=event.target.radius},duration+1.15)
 elseif kind=='orbital' then
  clear(markers,owner)
  local node=burns[owner]
  if not node or not node.Parent then
   node=record('Orbital',{Owner=owner,Position=point(event.target),Ground=event.target.ground,Radius=event.target.radius,ContactAt=now})
   burns[owner]=node;if not node then return end;watchBurn(owner,node)
  end
  -- ContactAt commits the complete sample. No replicated geometry moves.
  node:SetAttribute('Position',point(event.target));node:SetAttribute('ContactAt',now)
 elseif kind=='relay' or kind=='recycle' then
  record('AbilityPulse',{Owner=owner,Ability=kind,Position=point(event.target)},.6)
 elseif kind=='scrapStart' then clear(markers,owner)
 elseif kind=='scrapPose' then
  local group=swarms[owner]
  if not group or not group.Parent then
   if not template then return end
   group=record('ScrapSwarm',{Owner=owner,ScrapSwarm=true},13);if not group then return end
   local ref=Instance.new('ObjectValue');ref.Name='Template';ref.Value=template;ref.Parent=group
   swarms[owner]=group
  end
  group:SetAttribute('Expires',event.expires)
  for index,bot in ipairs(event.bots) do
   if index>6 then break end
   local name='ScrapBot_'..bot.id;local node=group:FindFirstChild(name)
   if not node then node=Instance.new('Folder');node.Name=name;node:SetAttribute('ScrapBot',true);node.Parent=group end
   node:SetAttribute('Position',point(bot));node:SetAttribute('Active',bot.active)
   node:SetAttribute('TargetPosition',bot.target and point(bot.target) or point(bot))
   node:SetAttribute('Pulse',bot.pulse);node:SetAttribute('PoseAt',now)
  end
 end
end
return Effects
