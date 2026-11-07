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
local function skin(f: GuiObject, color: Color3)
 if interfaceKit then interfaceKit.skin(f,color,10);return end
 f.BackgroundColor3=color; f.BackgroundTransparency=.12
 local stroke=f:FindFirstChildOfClass('UIStroke') or Instance.new('UIStroke')
 stroke.Color=C.line; stroke.Thickness=1; stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; stroke.Transparency=.3; stroke.Parent=f
 local g=f:FindFirstChildOfClass('UIGradient'); if g then g:Destroy() end
 local round=f:FindFirstChildOfClass('UICorner'); if round then round.CornerRadius=UDim.new(0,3) end
end
local function card(parent: Instance, name: string, color: Color3?): Frame
 local f=frame(parent,name,color or C.panel); f.Active=true; skin(f,color or C.panel); return f
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

-- The only permanent panels are mineral balances and backpack space.
local minerals={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local mineralColors={Color3.fromRGB(180,225,213),Color3.fromRGB(246,112,143),Color3.fromRGB(114,177,255),Color3.fromRGB(198,154,255),Color3.fromRGB(100,229,165)}
local function compact(value)
 if value>=1e9 then return string.format('%.1fB',value/1e9) elseif value>=1e6 then return string.format('%.1fM',value/1e6) elseif value>=10000 then return string.format('%.1fk',value/1000) end
 return tostring(math.floor(value))
end
local function quietPanel(parent,name)
 local f=card(parent,name);plain(f);f.BackgroundTransparency=.08;f.BackgroundColor3=C.panel;f.Active=false
 local round=f:FindFirstChildOfClass('UICorner');if round then round.CornerRadius=UDim.new(0,10) end
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(76,88,113);stroke.Transparency=.4;stroke.Thickness=1;stroke.Parent=f
 return f
end
function HUD.new(refs: any)
 interfaceKit=refs.interface
 local self: any=setmetatable({refs=refs,input=UIS:GetLastInputType(),wallets={}},HUD)
 plain(refs.resources)
 for i,key in ipairs(minerals) do
  local tile=quietPanel(refs.resources,'Wallet_'..key)
  local dot=frame(tile,'Mineral',mineralColors[i]);dot.Size=UDim2.fromOffset(8,8);dot.Position=UDim2.fromOffset(10,10)
  local name=text(tile,'MineralName',24,3,80,20,16,mineralColors[i]);name.Text=key
  local value=text(tile,'Balance',10,23,90,25,22,C.text)
  self.wallets[i]={tile=tile,name=name,value=value}
 end
 self.cargo=quietPanel(refs.resources,'CargoCounter')
 local name=text(self.cargo,'Caption',10,3,100,20,16,C.muted);name.Text='Backpack'
 refs.cargoText.Parent=self.cargo;refs.cargoText.TextColor3=C.text;refs.cargoText.TextWrapped=false;refs.cargoText.Font=Enum.Font.SourceSansBold
 refs.cargoTrack.Parent=self.cargo;refs.cargoTrack.Position=UDim2.new(0,8,1,-5);refs.cargoTrack.Size=UDim2.new(1,-16,0,3)
 refs.cargoTrack.BackgroundColor3=C.track
 self.gain=text(self.cargo,'CollectedGain',0,54,120,22,18,C.gold);self.gain.Visible=false
 self.collectedTotal=Players.LocalPlayer:GetAttribute('CollectedOreTotal') or 0
 self.dock=frame(refs.root,'CommandDock',C.panel);plain(self.dock)
 self.status=quietPanel(self.dock,'SquadStatus');self.order=text(self.status,'CurrentOrder',10,0,180,40,16,C.text)
 for _,button in {refs.recall,refs.evade} do button.Parent=self.dock;button.TextSize=16 end
 refs.unload.Visible=false;refs.test.Visible=false;refs.context.Visible=false
 self.hint=text(refs.root,'Controls',0,0,380,24,16,C.text);self.hint.TextXAlignment=Enum.TextXAlignment.Center;self.hint.TextStrokeTransparency=.25
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
 local a={total=0,living=0,miners=0,support=0,assigned=0,delivering=0,hp=0,maximum=0}
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
 local columns=w<500 and 3 or 6
 local width=math.min(w-24,738);local gap=6;local tileWidth=math.floor((width-(columns-1)*gap)/columns)
 local rows=math.ceil(6/columns);local bottom=8+rows*58
 r.resources.Position=UDim2.fromOffset(12,8);r.resources.Size=UDim2.fromOffset(width,rows*58-6);r.resources.Visible=not hidden
 for i,entry in ipairs(self.wallets) do
  entry.tile.Position=UDim2.fromOffset(((i-1)%columns)*(tileWidth+gap),math.floor((i-1)/columns)*58);entry.tile.Size=UDim2.fromOffset(tileWidth,52)
  entry.name.Position=UDim2.fromOffset(w<620 and 18 or 24,3);entry.name.TextSize=w<620 and 14 or 16
  entry.name.Size=UDim2.fromOffset(tileWidth-(w<620 and 22 or 29),20);entry.value.Size=UDim2.fromOffset(tileWidth-20,25)
  entry.value.Text=compact(wallet[minerals[i]] or 0)
 end
 self.cargo.Position=UDim2.fromOffset((5%columns)*(tileWidth+gap),math.floor(5/columns)*58);self.cargo.Size=UDim2.fromOffset(tileWidth,52)
 local cargoCaption=self.cargo:FindFirstChild('Caption');cargoCaption.TextSize=w<620 and 14 or 16;cargoCaption.Size=UDim2.fromOffset(tileWidth-16,20)
 r.cargoText.Position=UDim2.fromOffset(10,23);r.cargoText.Size=UDim2.fromOffset(tileWidth-20,24);r.cargoText.TextSize=20
 r.cargoText.Text=r.cargoText.Text:gsub('^Backpack ','')
 local backpack=Players.LocalPlayer:GetAttribute('BackpackUnits') or 0
 local capacity=Players.LocalPlayer:GetAttribute('BackpackCapacity') or 40
 local full=backpack>=capacity
 self.cargo.BackgroundColor3=full and C.red:Lerp(C.panel,.45) or C.panel
 local now=os.clock();local collected=Players.LocalPlayer:GetAttribute('CollectedOreTotal') or 0
 if collected>self.collectedTotal then
  self.gainUnits=(now-(self.gainAt or -10)<.65 and (self.gainUnits or 0) or 0)+collected-self.collectedTotal
  self.gainAt=now;self.gain.Text='+'..self.gainUnits..' ore'
 end
 self.collectedTotal=collected
 local age=now-(self.gainAt or -10);self.gain.Visible=age<.85
 self.gain.Position=UDim2.fromOffset(0,52-age*8);self.gain.TextTransparency=math.clamp((age-.5)/.35,0,1)
 local activity=HUD.activity(world:FindFirstChild('Drones'),Players.LocalPlayer.UserId)
 local working=activity.assigned;local delivering=activity.delivering
 if working>0 or delivering>0 then self.hasWorked=true end
 local showRecall=working>0 or delivering>0
 self.dock.Visible=not hidden and (showRecall or fighting)
 local touch=self.input==Enum.UserInputType.Touch or UIS.TouchEnabled
 local actions=(showRecall and 1 or 0)+(fighting and 1 or 0);local bw=touch and 80 or 100
 local dockWidth=math.min(w-24,180+actions*(bw+6));local reserve=touch and 116 or 12
 self.dock.Size=UDim2.fromOffset(dockWidth,40);self.dock.Position=UDim2.fromOffset((w-dockWidth)/2,h-reserve-40)
 local statusWidth=dockWidth-actions*(bw+6)
 self.status.Size=UDim2.fromOffset(statusWidth,40);self.order.Size=UDim2.new(1,-20,1,0)
 self.order.Text=fighting and 'Fleet fighting' or full and 'Backpack full' or string.format('%d mining · %d hauling',working,delivering)
 local x=statusWidth+6
 for _,entry in ipairs({{r.recall,showRecall},{r.evade,fighting}}) do
  entry[1].Visible=entry[2];if entry[2] then entry[1].Position=UDim2.fromOffset(x,0);entry[1].Size=UDim2.fromOffset(bw,40);x+=bw+6 end
 end
 r.recall.Text=touch and 'Recall' or 'Recall [R]';r.evade.Text=touch and 'Evade' or 'Evade [Q]'
 r.unload.Visible=false;r.test.Visible=false;r.context.Visible=false
 self.hint.Visible=not hidden and h>=400 and not self.hasWorked and not self.dock.Visible
 self.hint.Text=touch and 'Tap a rock to send your drone' or 'Click a rock · drag to queue'
 self.hint.Size=UDim2.fromOffset(math.min(w-24,380),24);self.hint.Position=UDim2.fromOffset((w-math.min(w-24,380))/2,h-reserve-32)
 r.enemy.Position=UDim2.fromOffset((w-math.min(280,w-24))/2,bottom+8);r.enemy.Size=UDim2.fromOffset(math.min(280,w-24),36)
 local toastWidth=math.min(350,w-24)
 r.toast.Size=UDim2.fromOffset(toastWidth,42);r.toast.Position=UDim2.fromOffset((w-toastWidth)/2,bottom+(r.enemy.Visible and 50 or 8))
end

function HUD:destroy()
 self.connection:Disconnect()
 self.worldLabels:Disconnect()
end
return HUD

