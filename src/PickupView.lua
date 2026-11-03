-- Owner/run-bound ore. Rendering never grants cargo; collection cues require
-- the server receipt, including partial collection from a full fragment.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local Debris=game:GetService('Debris')
local V={};V.__index=V
local function sparkle(parent,color)
 local p=Instance.new('ParticleEmitter');p.Name='MineralGlints'
 p.Texture='rbxasset://textures/particles/sparkles_main.dds';p.Color=ColorSequence.new(color,Color3.new(1,1,1))
 p.LightEmission=1;p.Rate=2;p.Lifetime=NumberRange.new(.25,.55);p.Speed=NumberRange.new(.2,.8);p.Drag=3
 p.SpreadAngle=Vector2.new(180,180);p.Rotation=NumberRange.new(-180,180);p.RotSpeed=NumberRange.new(-60,60)
 p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12,.06),NumberSequenceKeypoint.new(1,0)})
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
 p.Parent=parent;return p
end
function V.new(root,parent,audio)
 local player=Players.LocalPlayer
 local self=setmetatable({records={},parent=parent,root=root,connections={},audio=audio,lastSound=0},V)
 local function add(source)
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.Material=Enum.Material.Neon;view.Color=source.Color:Lerp(Color3.new(1,1,1),.18);view.Reflectance=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false;view.Parent=parent
  source.LocalTransparencyModifier=1
  local a=Instance.new('Attachment');a.Position=Vector3.new(0,.13,0);a.Parent=view
  local b=Instance.new('Attachment');b.Position=Vector3.new(0,-.13,0);b.Parent=view
  local trail=Instance.new('Trail');trail.Name='OreMagnetTrail';trail.Attachment0=a;trail.Attachment1=b
  trail.Color=ColorSequence.new(view.Color,source.Color);trail.Lifetime=.22;trail.MinLength=.06;trail.FaceCamera=true;trail.LightEmission=1
  trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
  trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)});trail.Enabled=false;trail.Parent=view
  local glints=sparkle(a,view.Color);glints.Enabled=false
  local glow=Instance.new('PointLight');glow.Name='MineralGlow';glow.Color=source.Color;glow.Range=3;glow.Brightness=.6;glow.Shadows=false;glow.Enabled=false;glow.Parent=view
  self.records[source]={view=view,pos=position,trail=trail,glints=glints,glow=glow,size=source.Size,seed=source:GetAttribute('PickupId'),ground=source:GetAttribute('GroundImpactSerial') or 0}
 end
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source];if r then r.view:Destroy();self.records[source]=nil end
 end))
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_Collect'):Connect(function()
  local ok,receipt=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_Collect') or '')
  if not ok or type(receipt)~='table' or type(receipt.serial)~='number' or receipt.serial==self.lastReceipt then return end
  self.lastReceipt=receipt.serial
  if math.abs(workspace:GetServerTimeNow()-(receipt.at or 0))>.7 then return end
  local rootPart=player.Character and player.Character:FindFirstChild('HumanoidRootPart');if not rootPart then return end
  local anchor=Instance.new('Part');anchor.Name='CollectedMineral';anchor.Size=Vector3.one*.05;anchor.Transparency=1
  anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Position=rootPart.Position;anchor.Parent=parent
  local a=Instance.new('Attachment');a.Parent=anchor
  local burst=sparkle(a,Color3.fromRGB(receipt.r,receipt.g,receipt.b));burst.Rate=0;burst.Speed=NumberRange.new(2,5);burst:Emit(9)
  Debris:AddItem(anchor,.65)
  if audio and os.clock()-self.lastSound>.09 then self.lastSound=os.clock();audio:play('pickup',rootPart.Position) end
 end))
 return self
end
function V:update(dt,now)
 local camera=workspace.CurrentCamera;local glints,lights=0,0
 for source,r in pairs(self.records) do
  if source.Parent then
   -- A server contact receipt, including its exact position, survives render
   -- interpolation. Never guess a landing from the smoothed visual's height.
   if AudioFeedback.serial(r,'ground',source:GetAttribute('GroundImpactSerial') or 0,source:GetAttribute('GroundImpactAt'),now) and self.audio then
    local point=source:GetAttribute('GroundImpactPosition')
    if typeof(point)=='Vector3' then self.audio:play('rubble',point,{level=math.clamp((source:GetAttribute('GroundImpactSpeed') or 1)/12,.25,1),pitch=.9+(r.seed%5)*.055}) end
   end
   local velocity=source:GetAttribute('Velocity') or Vector3.zero
   local predicted=(source:GetAttribute('Position') or source.Position)+velocity*math.clamp(now-(source:GetAttribute('SnapshotAt') or now),0,.1)
   r.pos=r.pos:Lerp(predicted,1-math.exp(-math.min(dt,.1)*24))
   r.view.CFrame=CFrame.new(r.pos)*CFrame.Angles(now*.7+r.seed,r.seed*.9,now*.5)
   r.view.Size=r.size*(1+math.sin(now*3+r.seed)*.08)
   r.trail.Enabled=velocity.Magnitude>8
   local distance=camera and (camera.CFrame.Position-r.pos).Magnitude or math.huge
   r.glints.Enabled=distance<65 and glints<24
   if r.glints.Enabled then glints+=1 end
   r.glow.Enabled=distance<24 and lights<4
   if r.glow.Enabled then lights+=1;r.glow.Brightness=.5+math.sin(now*3+r.seed)*.12 end
  end
 end
end
function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do source.LocalTransparencyModifier=0;r.view:Destroy() end
 self.records={}
end
return V
