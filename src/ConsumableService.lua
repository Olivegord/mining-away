-- Bridges saved equipment transactions to the existing authoritative gadgets.
-- One deployment per owner, independent of permanent specialist cooldowns.
local S={};S.__index=S
function S.new(ctx) return setmetatable({ctx=ctx},S) end
function S:clear(p)
 local ctx=self.ctx;local active=p.supply
 if active then
  active.canceled=true
  if active.finishTemporary then active.finishTemporary(false);active.finishTemporary=nil end
  ctx.effects.ClearAbility(tostring(p.player.UserId)..':tool')
  if active.beacon then active.beacon:Destroy();active.beacon=nil end
 end
 if p.busy then return end
 if ctx.saveHealthy(p) and Consumables.refund(ctx.data(p).consumables) then p.dirty=true;p.publishDirty=true end
 p.supply=nil;p.player:SetAttribute('MA_ConsumableActive',nil)
end
function S:command(p,payload,verifiedPosition,verifiedTarget)
 local ctx=self.ctx;local profile=ctx.data(p)
 if type(payload)~='table' or payload.runId~=profile.run.id or not Consumables.ITEMS[payload.kind]
  or type(payload.txId)~='string' or #payload.txId<1 or #payload.txId>100 then return end
 if p.supply or profile.consumables.pending then ctx.notice(p,'Your deployed tool is still working');return end
 if payload.version~=profile.consumables.version or profile.consumables.counts[payload.kind]<1 then ctx.notice(p,'Backpack changed; select an available tool');return end
 local position,reason=verifiedPosition,nil
 if not position then position,reason=ctx.placement(p,payload) end
 if not position then ctx.notice(p,reason);return end
 local record={kind=payload.kind,fieldId=payload.fieldId,position=position,runId=profile.run.id,txId=payload.txId,targetId=verifiedTarget}
 record.state=ctx.abilities.new({},record.runId)
 -- Dry preflight has no effects, damage, inventory writes or cooldown cost.
 local context=ctx.context(p,record);context.emit=function() end
 local ok,message=ctx.abilities.begin(record.state,record.kind,ctx.now(),context)
 if not ok then ctx.notice(p,message);return end
 local started=ctx.transact(p,'tool:'..tostring(payload.version)..':'..payload.txId,function(copy)
  if copy.run.id~=record.runId then return nil,'Run changed' end
  local reserved,why=Consumables.reserve(copy.consumables,record.kind,payload.version,payload.txId,record.runId)
  if not reserved then return nil,why end
  return {kind=record.kind,txId=record.txId}
 end,function()
  -- Transactions still hold the simulation lock in this callback. Start next
  -- tick, after the acknowledged saved inventory becomes the live profile.
  record.state=ctx.abilities.new({},record.runId);p.supply=record
  p.player:SetAttribute('MA_ConsumableActive',record.kind)
 end)
 if not started then ctx.notice(p,'Wait for the current save to finish') end
 return started
end
function S:drop(p,kind,target,point,finish)
 local ctx=self.ctx
 if p.supply or ctx.data(p).consumables.pending then ctx.notice(p,'Your deployed tool is still working');return false end
 local record={kind=kind,fieldId=target.field.id,position=point,targetId=target.id,runId=ctx.data(p).run.id,temporary=true,finishTemporary=finish}
 record.state=ctx.abilities.new({},record.runId)
 local context=ctx.context(p,record);context.emit=function() end
 local ok,why=ctx.abilities.begin(record.state,kind,ctx.now(),context)
 if not ok then ctx.notice(p,why);return false end
 record.state=ctx.abilities.new({},record.runId);p.supply=record
 p.player:SetAttribute('MA_ConsumableActive',kind)
 return true
end
local function beacon(parent,record)
 local item=Consumables.ITEMS[record.kind]
 local part=Instance.new('Part');part.Name=item.name;part.Size=Vector3.new(1.3,.45,1.3)
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
 part.Material=Enum.Material.Metal;part.Color=Color3.fromRGB(table.unpack(item.color))
 part.Position=record.position+Vector3.new(0,.24,0)
 part:SetAttribute('ConsumableKind',record.kind);part:SetAttribute('RunId',record.runId)
 local mast=Instance.new('Part');mast.Name='Signal';mast.Size=Vector3.new(.18,1.3,.18);mast.Material=Enum.Material.Neon;mast.Color=part.Color
 mast.Anchored=true;mast.CanCollide=false;mast.CanQuery=false;mast.CanTouch=false;mast.CastShadow=false
 mast.Position=part.Position+Vector3.new(0,.7,0);mast.Parent=part
 part.Parent=parent;return part
end
function S:step(p,dt)
 local record=p.supply;if not record then return end
 local ctx=self.ctx
 if p.busy or not ctx.healthy(p) then ctx.abilities.pause(record.state,dt);return end
 if record.canceled or ctx.data(p).run.id~=record.runId then self:clear(p);return end
 local context=ctx.context(p,record)
 if not record.started then
  local ok,reason=ctx.abilities.begin(record.state,record.kind,ctx.now(),context)
  if not ok then self:clear(p);ctx.notice(p,record.temporary and reason or (reason..' — tool returned'));return end
  record.started=true;record.beacon=beacon(ctx.root,record)
  ctx.notice(p,Consumables.ITEMS[record.kind].name..' placed')
 end
 ctx.abilities.step(record.state,ctx.now(),dt,context)
 if not record.state.charge and not record.state.burn and not record.state.swarm then
  local unused=ctx.data(p).consumables.pending~=nil
  self:clear(p)
  if unused then ctx.notice(p,'No mining contact — tool returned to backpack') end
 end
end
return S
