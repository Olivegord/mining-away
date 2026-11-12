--!strict
-- Compact mineral HUD and contextual fleet commands. Presentation only.
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local interfaceKit=nil
local HUD = {}
HUD.__index = HUD
local C = {
 panel=Color3.fromRGB(24,29,49), line=Color3.fromRGB(10,15,31),
 text=Color3.fromRGB(245,245,241), muted=Color3.fromRGB(192,197,199),
 blue=Color3.fromRGB(28,132,216), green=Color3.fromRGB(30,153,95),
 red=Color3.fromRGB(218,56,79), track=Color3.fromRGB(16,21,38),
 gold=Color3.fromRGB(255,219,102), violet=Color3.fromRGB(135,58,211),
}
local function frame(parent: Instance, name: string, color: Color3): Frame
 local f = Instance.new('Frame')
 f.Name=name; f.BackgroundColor3=color; f.BorderSizePixel=0
 f.ZIndex=parent:IsA('GuiObject') and parent.ZIndex+1 or 2; f.Parent=parent
 local c=Instance.new('UICorner'); c.CornerRadius=UDim.new(0,3); c.Parent=f
 return f
end
local function text(parent: Instance, name: string, x: number, y: number, w: number, h: number, size: number, color: Color3): TextLabel
 local t=Instance.new('TextLabel'); t.Name=name; t.Position=UDim2.fromOffset(x,y); t.Size=UDim2.fromOffset(w,h)
 t.BackgroundTransparency=1; t.TextColor3=color; t.TextSize=size; t.Font=Enum.Font.SourceSansBold
 t.TextXAlignment=Enum.TextXAlignment.Left; t.TextTruncate=Enum.TextTruncate.AtEnd; t.Text=''
 t.ZIndex=parent:IsA('GuiObject') and parent.ZIndex+1 or 2; t.Parent=parent
 return t
end
local function plain(f: GuiObject)
 if interfaceKit then interfaceKit.unskin(f) end
 f.BackgroundTransparency=1; f.Active=false
 for _,child in f:GetChildren() do if child:IsA('UIStroke') or child:IsA('UIGradient') then child:Destroy() end end
end
-- Fixed screen size, lifted clear of the plot and crystals.
function HUD.styleWorldLabel(gui: BillboardGui)
 if gui.Name~='TestLabel' then return end
 local anchor=gui.Parent
 if not anchor or not anchor:IsA('BasePart') then return end
 local field=anchor:GetAttribute('FieldId')
 local accent=field and anchor.Color or C.gold
 gui.Size=UDim2.fromOffset(field and 154 or 142,36)
 gui.Enabled=false
 gui.MaxDistance=38
 gui.AlwaysOnTop=false; gui.LightInfluence=0; gui.Adornee=anchor; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.StudsOffset=Vector3.zero; gui.ExtentsOffset=Vector3.zero
 gui.StudsOffsetWorldSpace=Vector3.new(0,anchor.Size.Y*.5+3,0)
 local names={PackStation='WORKSHOP',PrestigeStation='PRESTIGE',Printer='DRONE PRINTER',Converter='SELL ORE'}
 for _,label in gui:GetChildren() do
  if not label:IsA('TextLabel') then continue end
  if field then label.Text=tostring(field)..'  '..string.upper(anchor.Parent.Name)
  elseif names[anchor.Name] then label.Text=names[anchor.Name] end
  label.AnchorPoint=Vector2.new(.5,.5); label.Position=UDim2.fromScale(.5,.5); label.Size=UDim2.fromScale(1,1)
  label.BackgroundColor3=C.panel; label.BackgroundTransparency=.12
  label.TextColor3=C.text; label.Font=Enum.Font.SourceSansBold
  label.TextScaled=false; label.TextSize=14; label.TextWrapped=false; label.TextStrokeTransparency=1
  label.BorderSizePixel=0
  for _,v in label:GetChildren() do if v:IsA('UISizeConstraint') or v:IsA('UITextSizeConstraint') or v:IsA('UIPadding') then v:Destroy() end end
  local round=label:FindFirstChildOfClass('UICorner') or Instance.new('UICorner')
  round.CornerRadius=UDim.new(0,8); round.Parent=label
  local stroke=label:FindFirstChildOfClass('UIStroke') or Instance.new('UIStroke')
  stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; stroke.Color=accent; stroke.Transparency=0; stroke.Thickness=1.5; stroke.Parent=label
 end
end

function HUD.attachHealth(view: Model, source: Instance, color: Color3, turret: boolean?)
	local anchor = view.PrimaryPart or view:FindFirstChildWhichIsA('BasePart', true)
	if not anchor then return end
	if anchor:FindFirstChild('TacticalHealth') then return end
	local gui = Instance.new('BillboardGui')
	gui.Name = 'TacticalHealth'; gui.Adornee = anchor; gui.AlwaysOnTop = false; gui.LightInfluence=0
	gui.Size = UDim2.fromScale(turret and 5.5 or 2.6, .3); gui.MaxDistance = turret and 120 or 75
	gui.StudsOffsetWorldSpace = Vector3.new(0, turret and 6 or 2, 0); gui.Parent = anchor
	local track = frame(gui, 'Track', C.panel); track.Size = UDim2.fromScale(1, 1); track.ClipsDescendants = true
	track.AnchorPoint=Vector2.new(.5,.5); track.Position=UDim2.fromScale(.5,.5)
	local cap=Instance.new('UISizeConstraint'); cap.MaxSize=Vector2.new(turret and 84 or 44,6); cap.Parent=track
	local fill = frame(track, 'Fill', color);fill.Position=UDim2.fromScale(0,0)
	local function update()
		local health = source:GetAttribute('HP') or 0
		local maximum = source:GetAttribute('MaxHP') or 1
		fill.Size = UDim2.fromScale(math.clamp(health / math.max(1, maximum), 0, 1), 1)
		gui.Enabled = health > 0 and (turret==true or health<maximum)
	end
	update()
	local hp = source:GetAttributeChangedSignal('HP'):Connect(update)
	local maxHP = source:GetAttributeChangedSignal('MaxHP'):Connect(update)
	gui.Destroying:Connect(function() hp:Disconnect(); maxHP:Disconnect() end)
end

-- Flat side readouts appear as their mineral areas are unlocked.
local minerals={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local mineralColors={Color3.fromRGB(180,225,213),Color3.fromRGB(246,112,143),Color3.fromRGB(114,177,255),Color3.fromRGB(198,154,255),Color3.fromRGB(100,229,165)}
local selectorText={
 Working='Mining at pin', FinishingCut='Finishing prior cut', Moving='Miners on the way',
 PairCut='Two lasers cutting',
 Recharging='Miners recharging', Waiting='Waiting at pin', NoMiners='Waiting for miners', Paused='Mining paused',
 BagFull='Backpack full', LooseOre='Move closer to ore', Pressing='Compactor pressing', Surge='Crew surge · +50%', SurgeReady='Surge ready',
 Refilling='Plot refilling', Growing='Crystals growing', Claimed='Other crew mining', NoCrystals='Move pin to crystals',
 Hauling='Hauling to Workshop', Gathering='Vacuum gathering',
}
local function compact(value)
 if value>=1e9 then return string.format('%.1fB',value/1e9) elseif value>=1e6 then return string.format('%.1fM',value/1e6) elseif value>=10000 then return string.format('%.1fk',value/1000) end
 return tostring(math.floor(value))
end
function HUD.new(refs: any)
 interfaceKit=refs.interface
 local self: any=setmetatable({refs=refs,input=UIS:GetLastInputType(),wallets={}},HUD)
 plain(refs.resources)
 for i,key in ipairs(minerals) do
  local row=frame(refs.resources,'Wallet_'..key,C.panel);plain(row)
  local name=text(row,'MineralName',0,0,78,24,18,mineralColors[i]);name.Text=key
  local value=text(row,'Balance',78,0,82,24,20,C.text);value.TextXAlignment=Enum.TextXAlignment.Right
  self.wallets[i]={tile=row,name=name,value=value}
 end
 self.cargo=frame(refs.resources,'CargoCounter',C.panel);plain(self.cargo)
 local name=text(self.cargo,'Caption',0,0,78,24,18,C.muted);name.Text='Backpack'
 refs.cargoText.Parent=self.cargo;refs.cargoText.TextColor3=C.text;refs.cargoText.TextWrapped=false;refs.cargoText.Font=Enum.Font.SourceSansBold
 refs.cargoText.TextXAlignment=Enum.TextXAlignment.Right;refs.cargoText.TextTruncate=Enum.TextTruncate.AtEnd
 refs.cargoTrack.Visible=false
 self.battery=frame(refs.resources,'BatteryCounter',C.panel);plain(self.battery);self.battery.Visible=false
 text(self.battery,'Caption',0,0,78,24,18,C.muted).Text='Battery'
 self.batteryValue=text(self.battery,'Charge',78,0,82,24,18,C.text);self.batteryValue.TextXAlignment=Enum.TextXAlignment.Right
 self.dock=frame(refs.root,'CommandDock',C.panel);plain(self.dock)
 self.selectorStatus=text(self.dock,'SelectorStatus',0,0,0,0,16,C.muted)
 self.selectorStatus.Visible=false;self.selectorStatus.TextStrokeTransparency=.45
 for _,button in {refs.recall,refs.evade} do
  button.Parent=self.dock;plain(button);button.Active=true;button.TextSize=16
  button.TextXAlignment=Enum.TextXAlignment.Left;button.TextStrokeTransparency=1
 end
 refs.unload.Visible=false;refs.test.Visible=false;refs.context.Visible=false
 self.connection=UIS.LastInputTypeChanged:Connect(function(input) self.input=input end)
 for _,v in workspace:GetDescendants() do if v:IsA('BillboardGui') and v.Name=='TestLabel' then HUD.styleWorldLabel(v) end end
 self.worldLabels=workspace.DescendantAdded:Connect(function(v)
  if v:IsA('BillboardGui') and v.Name=='TestLabel' then task.defer(function() if v.Parent then HUD.styleWorldLabel(v) end end) end
 end)
 return self
end

function HUD:blocksPoint(position: Vector2): boolean
 for _,item in Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y) do
  if item:IsDescendantOf(self.refs.gui) and item~=self.refs.root and (item.Active or item:IsA('GuiButton')) then return true end
 end
 return false
end

-- Count authoritative capabilities and orders, not cosmetic beam state. Special
-- jobs and breaker windup keep their assignment; support never inflates miners.
function HUD.activity(folder,ownerId)
 local a={total=0,living=0,miners=0,support=0,assigned=0,delivering=0,hp=0,maximum=0,battery=0,maxBattery=0,charging=0,docking=0}
 if folder then for _,drone in folder:GetChildren() do
  if drone:GetAttribute('Owner')==ownerId then
   a.total+=1
   local health=drone:GetAttribute('HP') or 0
   a.hp+=math.max(0,health);a.maximum+=drone:GetAttribute('MaxHP') or 0
   if health>0 then
    a.living+=1
    if drone:GetAttribute('CanMine')==true then
     a.miners+=1
     local target=drone:GetAttribute('TargetId')
     if (type(target)=='string' and target~='') or (drone:GetAttribute('AutoFieldId') or 0)>0 then a.assigned+=1 end
    else a.support+=1 end
    local state=drone:GetAttribute('State')
    a.battery+=drone:GetAttribute('Battery') or 0;a.maxBattery+=drone:GetAttribute('MaxBattery') or 0
    if state=='Charging' then a.charging+=1 elseif state=='ToCharge' then a.docking+=1 end
    if state=='Collect' or state=='Deliver' or state=='Pickup' or state=='Launch' or state=='Unload' then a.delivering+=1 end
   end
  end
 end end
 return a
end

function HUD.nextStationHint(profile: any, pinned: boolean?, depotApproach: boolean?): string?
 local run=profile and profile.run
 if not run then return nil end
 local showDepot=not pinned or depotApproach==true
 local offer=run.pendingOffer
 if offer then
  if showDepot or run.packIndex==1 then return offer.opened==false and 'Open pack at counter' or 'Pick a card at counter' end
  return nil
 end
 local balance=run.wallet.Quartz or 0
 local incoming=profile.deliveryQuartz or 0
 local price=profile.nextPackPrice
 local packReady=price and balance>=price
 local packIncoming=price and balance+incoming>=price
 if run.packIndex==0 or showDepot then
  local prestige=showDepot and profile.prestigePreview
  if prestige and prestige.eligible and (run.packIndex>0 or not packReady) then return 'Prestige ready' end
  if packReady then return 'Pack Counter ready' end
  if prestige and prestige.saleRequired and incoming>0 and prestige.earnings<prestige.saleRequired
   and prestige.earnings+incoming>=prestige.saleRequired then return 'Prestige after sale' end
  if packIncoming then return 'Pack Counter next' end
 end
 return nil
end
function HUD.firstCutHint(input: Enum.UserInputType, reachable: boolean): string
 if not reachable then return 'Follow the Crystal Run signs' end
 if input==Enum.UserInputType.Touch then return 'Tap crystals to pin' end
 if input.Name:match('^Gamepad') then return 'Pin crystals [RB]' end
 return 'Click crystals to pin'
end
function HUD.packHoldHint(input: Enum.UserInputType): string
 if input==Enum.UserInputType.Touch then return 'Hold to open pack' end
 if input.Name:match('^Gamepad') then return 'Hold X to open pack' end
 return 'Hold E to open pack'
end
function HUD.needsFirstCutHint(profile: any, pinned: boolean): boolean
 local run=profile and profile.run
 if not run then return false end
 return not pinned and run.index==1 and run.packIndex==0 and run.quartzEarnings==0
end
function HUD:update(view: Vector2, world: Instance, fighting: boolean)
 local r=self.refs;local w=view.X
 local hidden=r.hidden()
 local p=r.profile();local wallet=p and p.run and p.run.wallet or {}
 local width=160;local rowHeight=24;local shown=0
 for i,entry in ipairs(self.wallets) do
  local unlocked=minerals[i]=='Quartz' or (p and p.run and p.run.shops and p.run.shops[minerals[i]]==true)
  entry.tile.Visible=unlocked==true
  if unlocked then
   entry.tile.Position=UDim2.fromOffset(0,shown*rowHeight);entry.tile.Size=UDim2.fromOffset(width,rowHeight);shown+=1
   entry.value.Text=compact(wallet[minerals[i]] or 0)
  end
 end
 local activity=HUD.activity(world:FindFirstChild('Drones'),Players.LocalPlayer.UserId)
 local batteryVisible=activity.maxBattery>0
 local height=(shown+1+(batteryVisible and 1 or 0))*rowHeight
 local sideY=8 -- Keep the flat list above the mobile movement controls.
 r.resources.Position=UDim2.fromOffset(0,sideY);r.resources.Size=UDim2.fromOffset(width,height);r.resources.Visible=not hidden
 self.cargo.Position=UDim2.fromOffset(0,shown*rowHeight);self.cargo.Size=UDim2.fromOffset(width,rowHeight)
 self.battery.Visible=batteryVisible
 self.battery.Position=UDim2.fromOffset(0,(shown+1)*rowHeight);self.battery.Size=UDim2.fromOffset(width,rowHeight)
 local charge=math.floor(100*activity.battery/math.max(1,activity.maxBattery)+.5)
 self.batteryValue.Text=activity.charging>0 and activity.charging..' charging' or activity.docking>0 and 'Docking' or charge..'%'
 self.batteryValue.TextColor3=activity.charging>0 and C.green or charge<25 and C.gold or C.text
 r.cargoText.Position=UDim2.fromOffset(78,0);r.cargoText.Size=UDim2.fromOffset(width-78,rowHeight);r.cargoText.TextSize=18
 local backpack=Players.LocalPlayer:GetAttribute('BackpackUnits') or 0
 local capacity=Players.LocalPlayer:GetAttribute('BackpackCapacity') or 100
 local full=backpack>=capacity
 r.cargoText.TextColor3=full and C.gold or C.text
 local working=activity.assigned;local delivering=activity.delivering
 local pin=Players.LocalPlayer:GetAttribute('MA_Selector')
 local pinned=pin~=nil
 local status=Players.LocalPlayer:GetAttribute('MA_SelectorStatus')
 local guidance
 if not fighting and status~='Paused' and world:GetAttribute('FieldToolsEnabled')==false then
  guidance=r.packReadyToOpen and r.packReadyToOpen() and HUD.packHoldHint(self.input)
   or HUD.nextStationHint(p,pinned,pinned and r.depotApproach(pin))
  if not guidance and HUD.needsFirstCutHint(p,pinned) then
   guidance=HUD.firstCutHint(self.input,r.starterReachable())
  end
 end
 local statusText=guidance or (pinned and type(status)=='string' and selectorText[status]) or nil
 local showRecall=working>0 or delivering>0 or pinned
 local showStatusRow=showRecall or statusText~=nil
 self.dock.Visible=not hidden and (showStatusRow or fighting)
 local touch=self.input==Enum.UserInputType.Touch or UIS.TouchEnabled
 local actions=(showStatusRow and 1 or 0)+(fighting and 1 or 0);local buttonHeight=touch and 44 or 24
 local recallWidth=showRecall and (statusText and 84 or width) or 0
 local dockWidth=statusText and math.min(w,232) or width
 self.dock.Size=UDim2.fromOffset(dockWidth,actions*buttonHeight)
 self.dock.Position=UDim2.fromOffset(0,sideY+height+24)
 r.recall.Visible=showRecall;r.recall.Position=UDim2.fromOffset(0,0);r.recall.Size=UDim2.fromOffset(recallWidth,buttonHeight)
 r.evade.Visible=fighting;r.evade.Position=UDim2.fromOffset(0,showStatusRow and buttonHeight or 0);r.evade.Size=UDim2.fromOffset(width,buttonHeight)
 self.selectorStatus.Visible=statusText~=nil
 self.selectorStatus.Text=statusText or ''
 self.selectorStatus.TextColor3=(guidance or status=='Working' or status=='PairCut' or status=='BagFull' or status=='Surge' or status=='SurgeReady') and C.gold or C.text
 local statusX=showRecall and recallWidth+4 or 0
 self.selectorStatus.Position=UDim2.fromOffset(statusX,0)
 self.selectorStatus.Size=UDim2.fromOffset(math.max(0,dockWidth-statusX),buttonHeight)
 r.recall.Text=touch and 'Recall' or 'Recall [R]';r.evade.Text=touch and 'Evade' or 'Evade [Q]'
 r.unload.Visible=false;r.test.Visible=false;r.context.Visible=false
 r.enemy.Position=UDim2.fromOffset((w-math.min(280,w-24))/2,8);r.enemy.Size=UDim2.fromOffset(math.min(280,w-24),36)
 local toastWidth=math.min(350,w-24)
 r.toast.Size=UDim2.fromOffset(toastWidth,42);r.toast.Position=UDim2.fromOffset((w-toastWidth)/2,(r.enemy.Visible and 50 or 8))
end

function HUD:destroy()
 self.connection:Disconnect()
 self.worldLabels:Disconnect()
end
return HUD

