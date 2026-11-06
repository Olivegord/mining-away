-- Server-owned equipment drops from the rock that actually broke. Collection
-- stores a tool; it never starts a boost or competes for ore backpack capacity.
local Players=game:GetService('Players')
local D={};D.__index=D
function D.new(parent,config,context)
 local container=Instance.new('Folder');container.Name='MiningDiscoveries';container.Parent=parent
 local self=setmetatable({container=container,config=config,context=context,states={},random=Random.new(),nextStep=0},D)
 self.connection=Players.PlayerRemoving:Connect(function(player) self:Clear(player) end)
 return self
end
function D:Clear(player)
 local state=self.states[player];if state then state.part:Destroy();self.states[player]=nil end
end
-- Compatibility for preserved controller callers. Discoveries no longer alter
-- damage or currency, including while a stored item is selected.
function D:Multiplier(_player,_kind) return 1 end
function D:TrySpawn(player,field,position,tier)
 local ctx=self.context(player)
 if not ctx or self.states[player] or not ctx.roll then return end
 local kind,definition=ctx.roll(tier,self.random:NextNumber(),self.random:NextNumber())
 if not kind then return end
 local now=workspace:GetServerTimeNow()
 local ground=position or field.Position+Vector3.new(0,field.Size.Y*.5,0)
 local color=Color3.fromRGB(table.unpack(definition.color))
 local part=Instance.new('Part');part.Name=kind..'Capsule';part.Size=Vector3.new(1.25,1.05,.85)
 part.Material=Enum.Material.Metal;part.Color=color;part.Anchored=true
 part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Position=ground+Vector3.new(0,.65,0)
 part:SetAttribute('OwnerUserId',player.UserId);part:SetAttribute('ConsumableKind',kind)
 part:SetAttribute('ExpiresAt',now+self.config.PickupLifetime)
 local label=Instance.new('BillboardGui');label.Name='ToolName';label.Size=UDim2.fromOffset(150,26)
 label.StudsOffsetWorldSpace=Vector3.new(0,1.5,0);label.MaxDistance=36;label.AlwaysOnTop=false;label.Parent=part
 local text=Instance.new('TextLabel');text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=.22
 text.BackgroundColor3=Color3.fromRGB(27,32,43);text.TextColor3=color;text.Font=Enum.Font.SourceSansBold;text.TextSize=16
 text.Text=definition.name;text.Parent=label
 local edge=Instance.new('UICorner');edge.CornerRadius=UDim.new(0,5);edge.Parent=text
 -- One small physical case per owner; the bright inset distinguishes equipment
 -- from the existing mineral fragments without adding an effect cloud.
 local lens=Instance.new('Part');lens.Name='Lens';lens.Size=Vector3.new(.7,.12,.48);lens.Material=Enum.Material.Neon
 lens.Color=color;lens.Anchored=true;lens.CanCollide=false;lens.CanTouch=false;lens.CanQuery=false;lens.CastShadow=false
 lens.Position=part.Position+Vector3.new(0,.58,0);lens.Parent=part
 self.states[player]={part=part,lens=lens,origin=ground,kind=kind,name=definition.name,runId=ctx.runId,started=now,expires=now+self.config.PickupLifetime}
 part.Parent=self.container
 player:SetAttribute('MA_Notice',definition.name..' dropped! Walk over to store it in your tools pocket.')
end
function D:Step()
 local now=workspace:GetServerTimeNow();if now<self.nextStep then return end;self.nextStep=now+.1
 for player,state in pairs(self.states) do
  local ctx=self.context(player)
  if not player.Parent or now>=state.expires or (ctx and ctx.runId~=state.runId) then self:Clear(player)
  else
   local age=now-state.started
   local lift=age<.6 and (math.sin(age/.6*math.pi)*1.8) or math.sin(age*2)*.12
   state.part.Position=state.origin+Vector3.new(0,.65+lift,0);state.lens.Position=state.part.Position+Vector3.new(0,.58,0)
   local fade=math.clamp((now-state.expires+5)/5,0,1);state.part.Transparency=fade;state.lens.Transparency=fade
   if ctx and age>=.6 and (ctx.root.Position-state.part.Position).Magnitude<=self.config.CollectDistance
    and (not ctx.clearPath or ctx.clearPath(state.part.Position,state.part)) and ctx.collect and ctx.collect(state.kind) then
    self:Clear(player)
    player:SetAttribute('MA_Notice',state.name..' stored. Select its tools pocket, then place it in a field.')
   end
  end
 end
end
function D:Destroy()
 self.connection:Disconnect()
 for player in pairs(self.states) do self:Clear(player) end
 self.container:Destroy()
end
return D
