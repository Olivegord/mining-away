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
function S:slot(p,s,i)
 if s.slots[i] then return s.slots[i] end
 local kind=ToolRules.SAVED[i];local count=kind and self.ctx.stock(p,kind) or 0
 if count>0 then return {kind=kind,id='saved:'..kind,hp=count,state='Held',saved=true} end
end
function S:refreshStock(p)
 local stamp=self.ctx.stock(p,'Scrap')..':'..self.ctx.stock(p,'Orbital')
 if stamp==p.toolStock then return end
 if stamp=='0:0' and not p.fieldTools then p.toolStock=stamp;return end
 local s=self:state(p);p.toolStock=stamp
 if s.selected>0 and not self:slot(p,s,s.selected) then s.selected=0 end
 s.version+=1;self:publish(p)
end
function S:publish(p)
 local s=p.fieldTools;if not s then return end
 local view={slots={},selected=s.selected,version=s.version,runId=s.runId}
 for i=1,ToolRules.SLOTS do
  local item=self:slot(p,s,i)
  view.slots[i]=item and {id=item.id,kind=item.kind,hp=item.hp,maxHP=item.saved and 3 or ToolRules.ITEMS[item.kind].uses,state=s.attack and s.attack.item==item and 'Windup' or item.state} or false
 end
 p.player:SetAttribute('MA_FieldTools',self.ctx.encode(view))
 local selected=self:slot(p,s,s.selected)
 p.player:SetAttribute('HeldFieldTool',selected and selected.state=='Held' and selected.kind or nil)
 p.player:SetAttribute('HeldFieldToolHP',selected and math.min(ToolRules.ITEMS[selected.kind].uses,selected.hp) or 0)
end
function S:clear(p)
 for id,item in pairs(self.items) do
  if item.owner==p.player.UserId then if item.part then item.part:Destroy() end;self.items[id]=nil end
 end
 p.fieldTools=nil;p.toolStock=nil;p.player:SetAttribute('ToolWindupUntil',nil);p.player:SetAttribute('ToolSwingAt',nil);p.player:SetAttribute('HeldFieldTool',nil);p.player:SetAttribute('HeldFieldToolHP',0);p.player:SetAttribute('MA_FieldTools',nil)
end
function S:previewLoadout(p)
 local s=self:state(p)
 for i,kind in ipairs(ToolRules.ORDER) do
  self.serial+=1
  local item={id=tostring(p.player.UserId)..':'..self.serial,owner=p.player.UserId,runId=s.runId,kind=kind,hp=ToolRules.ITEMS[kind].uses,state='Held'}
  s.slots[i]=item;self.items[item.id]=item
 end
 s.version+=1;self:publish(p)
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
function S:marker(position,kind,color,normal,slab)
 local m=Instance.new('Part');m.Name=kind;m.Size=Vector3.one*.1;m.Transparency=1;m.Anchored=true
 m.CanCollide=false;m.CanQuery=false;m.CanTouch=false;m.Position=position
 m:SetAttribute('Kind',kind);m:SetAttribute('Color',color);m:SetAttribute('Normal',normal or Vector3.new(0,1,0))
 m:SetAttribute('Slab',slab);m:SetAttribute('StartedAt',self.ctx.now());m.Parent=self.effects;self.ctx.debris:AddItem(m,2.2)
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
 if not slot then for i=1,ToolRules.SLOTS do if not self:slot(p,s,i) then slot=i;break end end end
 if not slot then return false end
 item.state='Held';item.part:Destroy();item.part=nil;item.expires=nil;s.slots[slot]=item;s.version+=1
 self:publish(p);self.ctx.notice(p,ToolRules.ITEMS[item.kind].name..' · slot '..slot)
 return true
end
function S:target(p,hr,def,id,position)
 local ctx=self.ctx
 local r=type(id)=='string' and #id<=160 and ctx.resources[id]
 if not r or r.paid or not r.part.Parent or not ToolRules.vector(position)
  or (position-hr.Position).Magnitude>def.range or not ctx.eligible(p,r,hr.Position) then return end
 local offset=r.part.CFrame:PointToObjectSpace(position)/r.part.Size
 local face=math.max(math.abs(offset.X),math.abs(offset.Y),math.abs(offset.Z))
 if face>.7 or face<.30 or not ctx.clear(hr.Position,position,p.player.Character,r.part) then return end
 return r,Vector3.new(math.clamp(offset.X,-.5,.5),math.clamp(offset.Y,-.5,.5),math.clamp(offset.Z,-.5,.5))
end
function S:command(p,action,payload)
 local s=self:state(p)
 if type(payload)~='table' or payload.runId~=s.runId or payload.version~=s.version or s.attack then return end
 if action=='EquipFieldTool' then
  local slot=payload.slot
  if not ToolRules.finite(slot) or slot%1~=0 or slot<0 or slot>ToolRules.SLOTS then return end
  local item=self:slot(p,s,slot)
  if slot>0 and (not item or item.state~='Held') then return end
  s.selected=slot;s.version+=1;self:publish(p);return
 end
 local item=self:slot(p,s,s.selected);local hr=self.ctx.root(p)
 if not item or item.state~='Held' or item.id~=payload.id or not hr or self.ctx.now()<(s.nextUse or 0) then return end
 local def=ToolRules.ITEMS[item.kind]
 local target,offset=self:target(p,hr,def,payload.resourceId,payload.point)
 if def.gadget then
  if not target then self.ctx.notice(p,'Click a nearby rock to deploy');return end
  if self.ctx.gadget(p,item,target,target.part.CFrame:PointToWorldSpace(offset*target.part.Size)) and not item.saved then self:remove(item) end
  return
 end
 if not target then self.ctx.notice(p,'Click a spot on a nearby rock');return end
 local now=self.ctx.now()
 s.attack={item=item,target=target,offset=offset,at=now+def.windup,run=s.runId}
 s.nextUse=now+def.cooldown;s.version+=1
 p.player:SetAttribute('ToolWindupUntil',s.attack.at)
 self:marker(hr.Position,item.kind..'Windup',Color3.fromRGB(table.unpack(def.color)))
 self:publish(p)
end
function S:release(p,s,attack)
 local ctx=self.ctx;local item=attack.item;local def=ToolRules.ITEMS[item.kind];local hr=ctx.root(p)
 s.attack=nil;p.player:SetAttribute('ToolWindupUntil',nil);p.player:SetAttribute('ToolSwingAt',ctx.now())
 if not hr or not ctx.healthy(p) or s.runId~=attack.run then self:publish(p);return end
 local target=attack.target
 if target and (target.paid or not target.part.Parent) then target=nil end
 if not target then self:publish(p);return end
 local aim=target.part.CFrame:PointToWorldSpace(attack.offset*target.part.Size)
 if (aim-hr.Position).Magnitude>def.range+1 or not ctx.clear(hr.Position,aim,p.player.Character,target.part) then self:publish(p);return end
 if def.melee then
  local part=target.part;local center=part.Position;local originalHeight=part.Size.Y
  local cut=math.clamp(.5+attack.offset.Y,.35,.65);local slab=item.kind=='Greatsword' and not target.slice and part.Size*Vector3.new(1,1-cut,1) or nil
  local fraction=item.kind=='Greatsword' and .5 or item.kind=='Sledgehammer' and .32 or .16
  local cap=item.kind=='Greatsword' and 720 or item.kind=='Sledgehammer' and 320 or 70
  if not ctx.hit(p,target,math.min((target.maxHP-10)*fraction,cap),hr.Position,item.kind,aim) then self:publish(p);return end
  item.hp-=1
  self:marker(slab and (center+Vector3.new(0,(originalHeight-slab.Y)*.5,0)) or aim,item.kind,target.field.color,nil,slab)
  if item.kind=='Sledgehammer' then
   ctx.hazards:blast(center+Vector3.new(0,1,0),7,12,'heavy')
   local n=0
   for _,r in ipairs(target.field.resources) do
    if r~=target and not r.paid and (r.part.Position-center).Magnitude<8 and ctx.hit(p,r,math.min(55,(r.maxHP-10)*.12),hr.Position,'Crowbar') then n+=1;if n>=3 then break end end
   end
  end
  if item.hp<=0 then self:marker(hr.Position,'Shatter',Color3.fromRGB(table.unpack(def.color)));self:remove(item);return end
 else
  local delta=aim-hr.Position
  local flat=Vector3.new(delta.X,0,delta.Z);local look=flat.Magnitude>.05 and flat.Unit or hr.CFrame.LookVector
  local from=ToolRules.origin(hr.Position,look)
  if not ctx.clear(hr.Position,from,p.player.Character) then from=hr.Position+Vector3.new(0,1.3,0) end
  local velocity
  if def.molten then
   local top=target.part.Position.Y+target.part.Size.Y*.5
   aim=Vector3.new(aim.X,top,aim.Z):Lerp(Vector3.new(target.part.Position.X,top,target.part.Position.Z),.04)
   from=aim+Vector3.new(0,4.6,0);velocity=Vector3.new(0,-3,0)
   if not ctx.clear(from,aim,p.player.Character,target.part) then self:publish(p);return end
  else
   aim=aim:Lerp(target.part.Position,.035)
   velocity=ToolRules.launch(item.kind,from,aim)
  end
  if not velocity then self:publish(p);return end
  item.hp-=1;item.state='Flying';item.from=from;item.pos=from;item.velocity=velocity;item.started=ctx.now();item.expires=item.started+8;item.sampleAge=0
  self:worldPart(item,from);self:marker(from,item.kind..'Release',Color3.fromRGB(table.unpack(def.color)))
 end
 s.version+=1;self:publish(p)
end
function S:impact(p,item,point,normal,resource)
 local def=ToolRules.ITEMS[item.kind];item.pos=point+normal*(def.radius or .1)
 item.part.Position=item.pos;item.part:SetAttribute('State','Impact')
 if item.kind=='MoltenTongs' then
  item.state='Molten';item.stuck=resource;item.fuseAt=self.ctx.now()+1.75;item.nextMelt=self.ctx.now()
  item.part:SetAttribute('State','Molten');item.part:SetAttribute('FuseAt',item.fuseAt)
  self:marker(point,'MoltenTongs',item.part.Color,normal)
 elseif item.kind=='JellyGrenade' then
  self:marker(point,'JellyStick',item.part.Color,normal)
  item.state='Stuck';item.fuseAt=self.ctx.now()+def.fuse
  if resource then item.stuck=resource;item.offset=resource.part.CFrame:PointToObjectSpace(item.pos);item.baseSize=resource.part.Size end
  item.part:SetAttribute('State','Stuck');item.part:SetAttribute('FuseAt',item.fuseAt)
 else
  if resource then self.ctx.hit(p,resource,math.min((resource.maxHP-10)*.42,210),item.pos,'BowlingBall',point) end
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
  if s and (s.runId~=self.ctx.run(p) or not self.ctx.root(p)) then self:clear(p)
  elseif s and s.attack and now>=s.attack.at then self:release(p,s,s.attack) end
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
  elseif item.state=='Molten' then
   local r=item.stuck
   if now>=item.fuseAt or not r or r.paid or not r.part.Parent then self:remove(item)
   elseif now>=item.nextMelt then
    item.nextMelt=now+.22
    local top=r.part.Position.Y+r.part.Size.Y*.5
    item.pos=Vector3.new(item.pos.X,top+.4,item.pos.Z);item.part.Position=item.pos
    self.ctx.hit(p,r,math.min(38,(r.maxHP-10)*.115),item.pos+Vector3.new(0,.35,0),'Melt',item.pos)
   end
  elseif item.state=='Stuck' then
   local r=item.stuck
   if r and not r.paid and r.part.Parent then
    item.pos=r.part.CFrame:PointToWorldSpace(item.offset*(r.part.Size/item.baseSize));item.part.Position=item.pos
   end
   if now>=item.fuseAt then
    local origin=item.pos
    self:marker(origin,'JellyGrenade',item.part.Color)
    self.ctx.hazards:blast(origin,12,34,'explosion')
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
