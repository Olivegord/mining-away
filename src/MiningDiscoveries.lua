--!strict
-- Server-owned discoveries. Mining continues independently of collection.
local Players = game:GetService('Players')
local Discoveries = {}
Discoveries.__index = Discoveries

function Discoveries.new(parent: Instance, config: any, context: (Player) -> any)
 local container = Instance.new('Folder')
 container.Name = 'MiningDiscoveries'
 container.Parent = parent
 local self: any = setmetatable({container=container, config=config, context=context, states={}, random=Random.new(), nextStep=0}, Discoveries)
 self.connection = Players.PlayerRemoving:Connect(function(player) self:Clear(player) end)
 return self
end

function Discoveries:Clear(player: Player)
 local state = self.states[player]
 if not state then return end
 if state.pickup then state.pickup.part:Destroy() end
 if state.gui then state.gui:Destroy() end
 self.states[player] = nil
 player:SetAttribute('MA_DiscoveryKind', nil)
 player:SetAttribute('MA_DiscoveryEndsAt', nil)
end

function Discoveries:Multiplier(player: Player, kind: string): number
 local state = self.states[player]
 local context = self.context(player)
 if state and context and state.runId == context.runId and state.kind == kind and workspace:GetServerTimeNow() < (state.endsAt or 0) then
  return self.config[kind .. 'Multiplier']
 end
 return 1
end

function Discoveries:TrySpawn(player: Player, field: BasePart)
 local context = self.context(player)
 if not context then return end
 local now = workspace:GetServerTimeNow()
 local state = self.states[player]
 if state and state.runId ~= context.runId then self:Clear(player); state=nil end
 if not state then
  state={runId=context.runId, nextSpawn=0}
  self.states[player]=state
 end
 if state.pickup or now < state.nextSpawn or self.random:NextNumber() > self.config.Chance then return end
 local position: Vector3? = nil
 for _=1,16 do
  local candidate = field.CFrame:PointToWorldSpace(Vector3.new(
   self.random:NextNumber(-math.max(0,field.Size.X/2-4), math.max(0,field.Size.X/2-4)),
   field.Size.Y/2+2.5,
   self.random:NextNumber(-math.max(0,field.Size.Z/2-4), math.max(0,field.Size.Z/2-4))))
  local distance = (candidate-context.root.Position).Magnitude
  if distance >= self.config.MinSpawnDistance and distance <= self.config.MaxSpawnDistance then position=candidate; break end
 end
 if not position then return end
 local kind = self.random:NextInteger(1,2)==1 and 'Yield' or 'Speed'
 local title = kind=='Yield' and '2x ORE' or '2x MINING'
 local color = kind=='Yield' and Color3.fromRGB(255,209,89) or Color3.fromRGB(69,226,255)
 local part = Instance.new('Part')
 part.Name = kind .. 'Discovery'
 part.Shape=Enum.PartType.Ball; part.Size=Vector3.one*2
 part.Material=Enum.Material.Neon; part.Color=color
 part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
 part.Position=position :: Vector3
 part:SetAttribute('OwnerUserId',player.UserId)
 part:SetAttribute('ExpiresAt',now+self.config.PickupLifetime)
 part:SetAttribute('DiscoveryKind',kind)
 local billboard=Instance.new('BillboardGui')
 billboard.Size=UDim2.fromScale(7,2); billboard.StudsOffsetWorldSpace=Vector3.new(0,3,0)
 billboard.AlwaysOnTop=false; billboard.LightInfluence=0; billboard.MaxDistance=75; billboard.Parent=part
 local label=Instance.new('TextLabel')
 label.Size=UDim2.fromScale(1,1); label.BackgroundColor3=Color3.fromRGB(12,24,40)
 label.BackgroundTransparency=.15; label.TextColor3=color; label.Font=Enum.Font.GothamBold; label.TextSize=14
 label.AnchorPoint=Vector2.new(.5,.5); label.Position=UDim2.fromScale(.5,.5); label.TextScaled=true
 local cap=Instance.new('UISizeConstraint'); cap.MaxSize=Vector2.new(154,44); cap.Parent=label
 local textCap=Instance.new('UITextSizeConstraint'); textCap.MinTextSize=1; textCap.MaxTextSize=14; textCap.Parent=label
 label.Parent=billboard
 local corner=Instance.new('UICorner'); corner.CornerRadius=UDim.new(0,10); corner.Parent=label
 local prompt=Instance.new('ProximityPrompt')
 prompt.ActionText='Collect'; prompt.ObjectText=title .. ' • ' .. player.DisplayName
 prompt.KeyboardKeyCode=Enum.KeyCode.G; prompt.GamepadKeyCode=Enum.KeyCode.ButtonL1
 prompt.HoldDuration=.15; prompt.MaxActivationDistance=self.config.CollectDistance
 prompt.RequiresLineOfSight=false; prompt.Parent=part
 local pickup={part=part, label=label, title=title, expiresAt=now+self.config.PickupLifetime, kind=kind}
 state.pickup=pickup; state.nextSpawn=now+self.config.MinSpawnInterval
 prompt.Triggered:Connect(function(collector)
  local current=self.context(player)
  local time=workspace:GetServerTimeNow()
  if collector~=player or self.states[player]~=state or state.pickup~=pickup or time>=pickup.expiresAt then return end
  if not current or current.runId~=state.runId or (current.root.Position-part.Position).Magnitude>self.config.CollectDistance then return end
  state.pickup=nil; part:Destroy()
  state.kind=kind; state.endsAt=time+self.config.BoostDuration
  player:SetAttribute('MA_DiscoveryKind',kind)
  player:SetAttribute('MA_DiscoveryEndsAt',state.endsAt)
  player:SetAttribute('MA_Notice',title .. ' discovery collected — 10-second boost!')
  if state.gui then state.gui:Destroy() end
  local gui=Instance.new('ScreenGui'); gui.Name='MiningDiscoveryBoost'; gui.ResetOnSpawn=true; gui.DisplayOrder=30
  local status=Instance.new('TextLabel')
  status.AnchorPoint=Vector2.new(.5,0); status.Position=UDim2.new(.5,0,0,58); status.Size=UDim2.fromOffset(220,34)
  status.BackgroundColor3=Color3.fromRGB(12,24,40); status.TextColor3=color
  status.Font=Enum.Font.GothamBold; status.TextSize=15; status.Parent=gui
  local round=Instance.new('UICorner'); round.CornerRadius=UDim.new(0,10); round.Parent=status
  gui.Parent=player:FindFirstChildOfClass('PlayerGui')
  state.gui=gui; state.status=status; state.title=title
  status.Text=title .. ' • 10s'
 end)
 label.Text=title .. ' • 10s\n' .. player.DisplayName
 part.Parent=self.container
 player:SetAttribute('MA_Notice','Discovery nearby! Collect within 10 seconds for '..title..'.')
end

function Discoveries:Step()
 local now=workspace:GetServerTimeNow()
 if now<self.nextStep then return end
 self.nextStep=now+.1
 for player,state in pairs(self.states) do
  local context=self.context(player)
  -- Busy profile saves temporarily suppress collection, but do not erase boosts.
  local character=player.Character
  local humanoid=character and character:FindFirstChildOfClass('Humanoid')
  if not player.Parent or not humanoid or humanoid.Health<=0 or (context and context.runId~=state.runId) then self:Clear(player)
  else
   local pickup=state.pickup
   if pickup then
    if now>=pickup.expiresAt then pickup.part:Destroy(); state.pickup=nil
    else pickup.label.Text=pickup.title..' • '..math.ceil(pickup.expiresAt-now)..'s\n'..player.DisplayName end
   end
   if state.kind then
    if now>=state.endsAt then
     state.kind=nil
     if state.gui then state.gui:Destroy(); state.gui=nil end
     player:SetAttribute('MA_DiscoveryKind',nil); player:SetAttribute('MA_DiscoveryEndsAt',nil)
    elseif state.status then state.status.Text=state.title..' • '..math.ceil(state.endsAt-now)..'s' end
   end
  end
 end
end

function Discoveries:Destroy()
 self.connection:Disconnect()
 for player in pairs(self.states) do self:Clear(player) end
 self.container:Destroy()
end
return Discoveries

