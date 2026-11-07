-- Temporary equipment is runtime-only, separate from saved permanent drones.
-- Server inventories, swept projectiles, contact pickups and finite debris.
local S={};S.__index=S
function S.new(ctx)
 local root=Instance.new('Folder');root.Name='FieldTools';root.Parent=ctx.world
 local effects=Instance.new('Folder');effects.Name='ToolImpacts';effects.Parent=ctx.world
 return setmetatable({ctx=ctx,folder=root,effects=effects,items={},serial=0},S)
end
function S:state(p)
 local run=self.ctx.run(p)
 if not p.fieldTools or p.fieldTools.runId~=run then
  self:clear(p);p.fieldTools={runId=run,slots={},selected=0,version=0,found=0,dry=0}
 end
 return p.fieldTools
end
function S:publish(p)
 local s=p.fieldTools;if not s then return end
 local view={slots={},selected=s.selected,version=s.version,runId=s.runId}
 for i=1,ToolRules.SLOTS do
  local item=s.slots[i]
  view.slots[i]=item and {id=item.id,kind=item.kind,hp=item.hp,maxHP=ToolRules.ITEMS[item.kind].uses,state=item.state} or false
 end
 p.player:SetAttribute('MA_FieldTools',self.ctx.encode(view))
 local selected=s.slots[s.selected]
 p.player:SetAttribute('HeldFieldTool',selected and selected.state=='Held' and selected.kind or nil)
 p.player:SetAttribute('HeldFieldToolHP',selected and selected.hp or 0)
end
function S:clear(p)
 for id,item in pairs(self.items) do
  if item.owner==p.player.UserId then if item.part then item.part:Destroy() end;self.items[id]=nil end
 end
 p.fieldTools=nil;p.player:SetAttribute('HeldFieldTool',nil);p.player:SetAttribute('HeldFieldToolHP',0);p.player:SetAttribute('MA_FieldTools',nil)
end
function S:remove(item)
 if item.part then item.part:Destroy();item.part=nil end
 self.items[item.id]=nil
 local p=self.ctx.players[item.owner];local s=p and p.fieldTools
 if s then
  for i=1,ToolRules.SLOTS do if s.slots[i]==item then s.slots[i]=nil;if s.selected==i then s.selected=0 end end end
  s.version+=1;self:publish(p)
 end
end
function S:marker(position,kind,color,normal)
 local m=Instance.new('Part');m.Name=kind;m.Size=Vector3.one*.1;m.Transparency=1;m.Anchored=true
 m.CanCollide=false;m.CanQuery=false;m.CanTouch=false;m.Position=position
 m:SetAttribute('Kind',kind);m:SetAttribute('Color',color);m:SetAttribute('Normal',normal or Vector3.new(0,1,0))
 m:SetAttribute('StartedAt',self.ctx.now());m.Parent=self.effects;self.ctx.debris:AddItem(m,2.2)
end
function S:worldPart(item,position)
 local def=ToolRules.ITEMS[item.kind];local p=Instance.new('Part');p.Name=item.kind
 p.Shape=item.kind=='Crowbar' and Enum.PartType.Block or Enum.PartType.Ball
 p.Size=item.kind=='Crowbar' and Vector3.new(.25,2.4,.3) or Vector3.one*(def.radius*2)
 p.Material=item.kind=='JellyGrenade' and Enum.Material.SmoothPlastic or Enum.Material.Metal
 p.Color=Color3.fromRGB(table.unpack(def.color));p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=true
 p.Position=position;p:SetAttribute('Kind',item.kind);p:SetAttribute('Owner',item.owner);p:SetAttribute('ToolId',item.id)
 p:SetAttribute('HP',item.hp);p:SetAttribute('MaxHP',def.uses);p:SetAttribute('State',item.state)
 p:SetAttribute('ExpiresAt',item.expires)
 if item.state=='Flying' then p:SetAttribute('Origin',item.from);p:SetAttribute('Velocity',item.velocity);p:SetAttribute('StartedAt',item.started) end
 p.Parent=self.folder;item.part=p
 return p
end
function S:onRock(p,r)
 if not self.ctx.healthy(p) or not self.ctx.root(p) then return end
 local s=self:state(p);local total,owned=0,0
 for _,v in pairs(self.items) do if v.state~='Held' then total+=1;if v.owner==p.player.UserId then owned+=1 end end end
 if total>=ToolRules.MAX_DROPS or owned>=ToolRules.MAX_OWNER_DROPS then return end
 local kind=ToolRules.drop(s,self.ctx.random(),self.ctx.random());if not kind then return end
 self.serial+=1
 local ground=r.part:GetAttribute('GroundY') or r.position.Y
 local item={id=tostring(p.player.UserId)..':'..self.serial,owner=p.player.UserId,runId=s.runId,kind=kind,hp=ToolRules.ITEMS[kind].uses,
  state='Drop',expires=self.ctx.now()+ToolRules.WORLD_LIFETIME,collectAt=self.ctx.now()+.5}
 self.items[item.id]=item;s.found+=1;s.dry=0
 local radius=ToolRules.ITEMS[kind].radius or .65
 item.pos=Vector3.new(r.position.X,ground+r.part.Size.Y+.85,r.position.Z)
 item.settleVelocity=Vector3.new(math.cos(self.serial)*6,12,math.sin(self.serial)*6)
 item.settleUntil=self.ctx.now()+1.25;item.floor=ground+(kind=='Crowbar' and 1.35 or radius)
 self:worldPart(item,item.pos)
 self:marker(item.part.Position,'Drop',item.part.Color)
 self.ctx.notice(p,ToolRules.ITEMS[kind].name..' dropped — touch to collect')
end
function S:collect(p,item)
 local s=self:state(p);local hr=self.ctx.root(p)
 if not hr or not self.ctx.healthy(p) or item.owner~=p.player.UserId or item.runId~=s.runId
  or (item.state~='Drop' and item.state~='Recover') or self.ctx.now()<item.collectAt or not item.part
  or (hr.Position-item.part.Position).Magnitude>3.8 or not self.ctx.clear(hr.Position,item.part.Position,p.player.Character) then return false end
 local slot
 for i=1,ToolRules.SLOTS do if s.slots[i]==item then slot=i;break end end
 if not slot then for i=1,ToolRules.SLOTS do if not s.slots[i] then slot=i;break end end end
 if not slot then return false end
 item.state='Held';item.part:Destroy();item.part=nil;item.expires=nil;s.slots[slot]=item;s.version+=1
 self:publish(p);self.ctx.notice(p,ToolRules.ITEMS[item.kind].name..' · slot '..slot)
 return true
end
function S:command(p,action,payload)
 local s=self:state(p)
 if type(payload)~='table' or payload.runId~=s.runId or payload.version~=s.version then return end
 if action=='EquipFieldTool' then
  local slot=payload.slot
  if not ToolRules.finite(slot) or slot%1~=0 or slot<0 or slot>ToolRules.SLOTS then return end
  if slot>0 and (not s.slots[slot] or s.slots[slot].state~='Held') then return end
  s.selected=slot;s.version+=1;self:publish(p);return
 end
 local item=s.slots[s.selected];local hr=self.ctx.root(p)
 if not item or item.state~='Held' or item.id~=payload.id or not hr or not ToolRules.vector(payload.aim)
  or self.ctx.now()<(s.nextUse or 0) then return end
 local def=ToolRules.ITEMS[item.kind]
 if item.kind=='Crowbar' then
  local r=type(payload.resourceId)=='string' and #payload.resourceId<=160 and self.ctx.resources[payload.resourceId]
  if not r or (r.part.Position-hr.Position).Magnitude>def.range+r.part.Size.Magnitude*.2 then return end
  if not self.ctx.hit(p,r,math.min((r.maxHP-10)*.16,70),hr.Position,'Crowbar') then return end
  item.hp-=1;self:marker(r.part.Position,'Crowbar',r.field.color)
  if item.hp<=0 then self:marker(hr.Position,'Shatter',Color3.fromRGB(table.unpack(def.color)));self:remove(item) end
 else
  -- Origin comes from the server character. The client sends aim, never speed,
  -- gravity, a hit position, damage, or a result to trust.
  local from=ToolRules.origin(hr.Position,hr.CFrame.LookVector)
  if not self.ctx.clear(hr.Position,from,p.player.Character) then return end
  local velocity=ToolRules.launch(item.kind,from,payload.aim);if not velocity then return end
  item.hp-=1;item.state='Flying';item.from=from;item.pos=from;item.velocity=velocity;item.started=self.ctx.now();item.expires=item.started+8
  self:worldPart(item,from)
 end
 s.nextUse=self.ctx.now()+def.cooldown;s.version+=1;self:publish(p)
end
function S:impact(p,item,point,normal,resource)
 local def=ToolRules.ITEMS[item.kind];item.pos=point+normal*(def.radius or .1)
 item.part.Position=item.pos;item.part:SetAttribute('State','Impact')
 if item.kind=='JellyGrenade' then
  item.state='Stuck';item.fuseAt=self.ctx.now()+def.fuse
  if resource then item.stuck=resource;item.offset=resource.part.CFrame:PointToObjectSpace(item.pos);item.baseSize=resource.part.Size end
  item.part:SetAttribute('State','Stuck');item.part:SetAttribute('FuseAt',item.fuseAt)
 else
  if resource then self.ctx.hit(p,resource,math.min((resource.maxHP-10)*.42,210),item.pos,'BowlingBall') end
  self:marker(point,'BowlingBall',item.part.Color,normal)
  self.ctx.hazards:blast(item.pos,5,18,'heavy')
  if item.hp<=0 then self:marker(item.pos,'Shatter',item.part.Color);self:remove(item);return end
  item.state='Recover';item.collectAt=self.ctx.now()+.65;item.expires=self.ctx.now()+ToolRules.WORLD_LIFETIME
  -- Settle beside the impact, then become a touch pickup. No remote recovery.
  local flat=Vector3.new(normal.X,0,normal.Z)
  if flat.Magnitude<.1 then flat=Vector3.new(1,0,0) else flat=flat.Unit end
  item.settleVelocity=flat*12+Vector3.new(0,13,0);item.settleUntil=self.ctx.now()+1.4
  item.part:SetAttribute('State','Recover');item.part:SetAttribute('ExpiresAt',item.expires)
 end
 local s=p.fieldTools;if s then s.version+=1;self:publish(p) end
end
function S:step(dt)
 local now=self.ctx.now()
 for _,p in pairs(self.ctx.players) do
  local s=p.fieldTools
  if s and (s.runId~=self.ctx.run(p) or not self.ctx.root(p)) then self:clear(p) end
 end
 for _,item in pairs(self.items) do
  local p=self.ctx.players[item.owner]
  if not p or item.runId~=self.ctx.run(p) or (item.expires and now>=item.expires) then self:remove(item)
  elseif item.state=='Flying' then
   local def=ToolRules.ITEMS[item.kind];local age=now-item.started
   -- Substeps bound curved sweep error even after a slow server frame.
   local from=item.pos;local oldAge=item.sampleAge or 0;local steps=math.clamp(math.ceil((age-oldAge)*60),1,12)
   for i=1,steps do
    local at=oldAge+(age-oldAge)*i/steps;local to=ToolRules.position(item.from,item.velocity,def.gravity,at)
    local hit=self.ctx.cast(from,to,def.radius,p.player.Character)
    if hit then self:impact(p,item,hit.Position,hit.Normal,self.ctx.resources[hit.Instance:GetAttribute('ResourceId')]);break end
    from=to;item.pos=to;item.part.Position=to
   end
   item.sampleAge=age
  elseif item.state=='Stuck' then
   local r=item.stuck
   if r and not r.paid and r.part.Parent then
    item.pos=r.part.CFrame:PointToWorldSpace(item.offset*(r.part.Size/item.baseSize));item.part.Position=item.pos
   end
   if now>=item.fuseAt then
    local origin=item.pos
    self:marker(origin,'JellyGrenade',item.part.Color)
    self.ctx.hazards:blast(origin,12,48,'explosion')
    for _,r2 in pairs(self.ctx.resources) do
     if not r2.paid and (r2.part.Position-origin).Magnitude<=12 then
      self.ctx.hit(p,r2,math.min((r2.maxHP-10)*.72,330),origin,'JellyGrenade')
     end
    end
    self:remove(item)
   end
  elseif item.state=='Drop' or item.state=='Recover' then
   if item.settleVelocity and now<item.settleUntil then
    local velocity=item.settleVelocity-Vector3.new(0,180*dt,0);local to=item.pos+velocity*dt
    local radius=ToolRules.ITEMS[item.kind].radius or .65
    local hit=self.ctx.cast(item.pos,to,radius,p.player.Character)
    if hit then
     item.pos=hit.Position+hit.Normal*(item.kind=='Crowbar' and 1.35 or radius)
     item.settleVelocity=nil
    elseif item.floor and to.Y<=item.floor then
     item.pos=Vector3.new(to.X,item.floor,to.Z);item.settleVelocity=nil
    else item.pos=to;item.settleVelocity=velocity end
    item.part.Position=item.pos
   end
   self:collect(p,item)
  end
 end
end
return S
