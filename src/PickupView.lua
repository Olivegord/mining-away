-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local function backpack(owner,fallback)
 local character=owner and owner.Character
 local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
 if torso then return torso.CFrame:PointToWorldSpace(Vector3.new(0,.3,.8)),torso end
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 return hr and hr.Position or fallback,nil
end
local function sample(r,source,now)
 local at=source:GetAttribute('SnapshotAt') or now
 if r.sampleAt and at<=r.sampleAt then return end
 local position=source:GetAttribute('Position') or source.Position
 local velocity=source:GetAttribute('Velocity') or Vector3.zero
 r.sampleAt=at
 table.insert(r.samples,{at=at,x=position.X,y=position.Y,z=position.Z,vx=velocity.X,vy=velocity.Y,vz=velocity.Z,
  floor=source:GetAttribute('FloorY'),homing=source:GetAttribute('Homing')==true})
 while #r.samples>5 do table.remove(r.samples,1) end
 r.velocity=velocity
 r.fadeAt=source:GetAttribute('FadeAt');r.expiresAt=source:GetAttribute('ExpiresAt')
end
function V.new(root,parent,audio)
 local player=Players.LocalPlayer
 local self=setmetatable({records={},byId={},parent=parent,root=root,connections={},audio=audio,lastSound=0},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  if (source:GetAttribute('CollectedAt') or 0)>0 then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false;view.Parent=parent
  source.LocalTransparencyModifier=1
  local id=source:GetAttribute('PickupId')
  local r={view=view,pos=position,size=source.Size,seed=id,
   samples={},owner=source:GetAttribute('Owner'),born=source:GetAttribute('SpawnAt') or workspace:GetServerTimeNow()}
  local contactAt=source:GetAttribute('GroundImpactAt')
  if type(contactAt)=='number' and contactAt>0 then r.landAge=math.max(0,contactAt-r.born) end
  self.records[source]=r;self.byId[id]=r;sample(r,source,workspace:GetServerTimeNow())
 end
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source]
  if r then r.removedAt=workspace:GetServerTimeNow() end
 end))
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_Collect'):Connect(function()
  local ok,receipt=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_Collect') or '')
  if not ok or type(receipt)~='table' or type(receipt.serial)~='number' or receipt.serial==self.lastReceipt then return end
  self.lastReceipt=receipt.serial
  local now=workspace:GetServerTimeNow()
  if math.abs(now-(receipt.at or 0))>.7 then return end
  local rootPart=player.Character and player.Character:FindFirstChild('HumanoidRootPart');if not rootPart then return end
  local r=self.byId[receipt.pickupId]
  if r and receipt.exhausted==true then r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt) end
  local target=backpack(player,rootPart.Position)
  if audio and os.clock()-self.lastSound>.09 then
   local at=os.clock();self.pickupChain=at-self.lastSound<.6 and math.min(6,(self.pickupChain or 0)+1) or 0
   self.lastSound=at;audio:play('pickup',target,{pitch=1+self.pickupChain*.045})
  end
 end))
 return self
end
function V:update(dt,now)
 for source,r in pairs(self.records) do
  if not r.collectAt and source.Parent then
   local collectedAt=source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
    r.collectTarget=source:GetAttribute('CollectedPosition')
   end
  end
  local opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt);local scale=1;local done=false
  if r.collectAt then
   local t=(now-r.collectAt)/.22;local ease,shrink=PickupMotion.collection(t)
   local owner=Players:GetPlayerByUserId(r.owner)
   local target=backpack(owner,r.collectTarget or r.collectFrom)
   r.pos=r.collectFrom:Lerp(target,ease)+Vector3.new(0,math.sin(math.clamp(t,0,1)*math.pi)*.18,0)
   opacity=(r.collectOpacity or 1)*(1-math.clamp((t-.7)/.3,0,1));scale=math.max(.04,shrink);done=t>=1
  elseif source.Parent and not r.removedAt then
   -- Landing pose is persistent state, even when its timestamp arrives too
   -- late to replay a sound. A streamed/stalled observer must still settle.
   local contactAt=source:GetAttribute('GroundImpactAt')
   if not r.landAge and type(contactAt)=='number' and contactAt>0 then
    r.landAge=math.max(0,contactAt-r.born)
   end
   sample(r,source,now)
   local x,y,z=PickupMotion.position(r.samples,now)
   if x then r.pos=Vector3.new(x,y,z) end
   opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  else
   r.removedAt=r.removedAt or now
   -- Destruction can replicate just before its receipt. Keep a tiny grace
   -- window, then fade in place for expiry/cleanup without inventing collection.
   opacity*=1-math.clamp((now-r.removedAt-.06)/.18,0,1);done=now-r.removedAt>=.28
  end
  if done then
   r.view:Destroy()
   self.byId[r.seed]=nil;self.records[source]=nil
  else
   local age=math.max(0,now-PickupMotion.DELAY-r.born)
   local tumble=PickupMotion.tumble(age,r.landAge)
   local rx,ry,rz=r.seed*.71+tumble,r.seed*.9+tumble*.6,r.seed*.43+tumble*.8
   local position=r.pos
   local latest=r.samples[#r.samples]
   if not r.collectAt and latest and latest.floor then
    local support=PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,rx,ry,rz)
    -- Lift the entire trajectory by the rotated support extent, preserving
    -- the small rebound instead of clamping it away under the visible mesh.
    position=Vector3.new(position.X,math.max(latest.floor,position.Y)+support-.22,position.Z)
   end
   r.drawPosition=position
   r.view.CFrame=CFrame.new(position)*CFrame.Angles(rx,ry,rz)
   r.view.Size=r.size*scale;r.view.Transparency=1-opacity

  end
 end
end
function V:destroy()
 if self.closed then return end;self.closed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do if source.Parent then source.LocalTransparencyModifier=0 end;r.view:Destroy() end
 self.records={};self.byId={}
end
return V
