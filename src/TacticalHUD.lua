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
 local names={PackStation='PACK SHOP',PrestigeStation='PRESTIGE',Printer='DRONE PRINTER',Converter='SELL ORE'}
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
 Recharging='Miners recharging', Waiting='Waiting at pin', NoMiners='Waiting for miners', Paused='Mining paused',
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
 refs.cargoText.TextXAlignment=Enum.TextXAlignment.Right
 refs.cargoTrack.Visible=false
 self.gain=text(self.cargo,'CollectedGain',0,24,160,22,18,C.gold);self.gain.Visible=false
 self.battery=frame(refs.resources,'BatteryCounter',C.panel);plain(self.battery);self.battery.Visible=false
 text(self.battery,'Caption',0,0,78,24,18,C.muted).Text='Battery'
 self.batteryValue=text(self.battery,'Charge',78,0,82,24,18,C.text);self.batteryValue.TextXAlignment=Enum.TextXAlignment.Right
 self.collectedTotal=Players.LocalPlayer:GetAttribute('CollectedOreTotal') or 0
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
 local a={total=0,living=0,miners=0,support=0,assigned=0,delivering=0,hp=0,maximum=0,battery=0,maxBattery=0,charging=0}
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
    if state=='ToCharge' or state=='Charging' then a.charging+=1 end
    if state=='Collect' or state=='Deliver' or state=='Pickup' or state=='Launch' or state=='Unload' then a.delivering+=1 end
   end
  end
 end end
 return a
end

function HUD:update(view: Vector2, world: Instance, fighting: boolean)
 local r=self.refs;local w,h=view.X,view.Y
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
 self.batteryValue.Text=activity.charging>0 and activity.charging..' charging' or charge..'%'
 self.batteryValue.TextColor3=activity.charging>0 and C.green or charge<25 and C.gold or C.text
 r.cargoText.Position=UDim2.fromOffset(78,0);r.cargoText.Size=UDim2.fromOffset(width-78,rowHeight);r.cargoText.TextSize=18
 r.cargoText.Text=r.cargoText.Text:gsub('^Backpack ',''):gsub(' / ','/')
 local backpack=Players.LocalPlayer:GetAttribute('BackpackUnits') or 0
 local capacity=Players.LocalPlayer:GetAttribute('BackpackCapacity') or 100
 local full=backpack>=capacity
 r.cargoText.TextColor3=full and C.gold or C.text
 local now=os.clock();local collected=Players.LocalPlayer:GetAttribute('CollectedOreTotal') or 0
 if collected>self.collectedTotal then
  self.gainUnits=(now-(self.gainAt or -10)<.65 and (self.gainUnits or 0) or 0)+collected-self.collectedTotal
  self.gainAt=now;self.gain.Text='+'..self.gainUnits..' ore'
 end
 self.collectedTotal=collected
 local age=now-(self.gainAt or -10);self.gain.Visible=age<.85
 self.gain.Position=UDim2.fromOffset(0,(batteryVisible and 48 or 24)-age*8);self.gain.TextTransparency=math.clamp((age-.5)/.35,0,1)
 local working=activity.assigned;local delivering=activity.delivering
 if working>0 or delivering>0 then self.hasWorked=true end
 local pinned=Players.LocalPlayer:GetAttribute('MA_Selector')~=nil
 local status=Players.LocalPlayer:GetAttribute('MA_SelectorStatus')
 local pinText=pinned and type(status)=='string' and selectorText[status] or nil
 local showRecall=working>0 or delivering>0 or pinned
 self.dock.Visible=not hidden and (showRecall or fighting)
 local touch=self.input==Enum.UserInputType.Touch or UIS.TouchEnabled
 local actions=(showRecall and 1 or 0)+(fighting and 1 or 0);local buttonHeight=touch and 44 or 24
 local recallWidth=pinText and 84 or width
 local dockWidth=pinText and math.min(w,224) or width
 self.dock.Size=UDim2.fromOffset(dockWidth,actions*buttonHeight)
 self.dock.Position=UDim2.fromOffset(0,sideY+height+24)
 local y=0
 for _,entry in ipairs({{r.recall,showRecall},{r.evade,fighting}}) do
  entry[1].Visible=entry[2];if entry[2] then entry[1].Position=UDim2.fromOffset(0,y);entry[1].Size=UDim2.fromOffset(entry[1]==r.recall and recallWidth or width,buttonHeight);y+=buttonHeight end
 end
 self.selectorStatus.Visible=pinText~=nil
 self.selectorStatus.Text=pinText or ''
 self.selectorStatus.TextColor3=status=='Working' and C.gold or C.text
 self.selectorStatus.Position=UDim2.fromOffset(recallWidth+4,0)
 self.selectorStatus.Size=UDim2.fromOffset(math.max(0,dockWidth-recallWidth-4),buttonHeight)
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

