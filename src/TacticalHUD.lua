--!strict
-- Reference-led HUD: Bee Swarm slim meters, Pet Sim compact icons. Presentation only.
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local Config = require(script.Parent.DroneConfig)
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
local function portrait(parent: Frame, color: Color3)
 local vp=Instance.new('ViewportFrame'); vp.Name='DronePortrait'; vp.BackgroundTransparency=1
 vp.Position=UDim2.fromScale(.08,.05); vp.Size=UDim2.fromScale(.84,.73); vp.ZIndex=parent.ZIndex+1
 vp.Ambient=Color3.fromRGB(185,185,200); vp.LightColor=Color3.new(1,1,1); vp.LightDirection=Vector3.new(-1,-2,-3); vp.Parent=parent
 task.spawn(function()
 local template=game.ReplicatedStorage:FindFirstChild('Drone') or workspace:FindFirstChild('Drone') or workspace:WaitForChild('Drone',10)
 if not template or not template:IsA('Model') then return end
 -- Model containers can replicate before their parts. Wait for the authored shell.
 if not template:FindFirstChild('Mesh') then template:WaitForChild('Mesh',10) end
 if not vp.Parent then return end
 local model=template:Clone()
 for _,v in model:GetDescendants() do
  if v:IsA('LuaSourceContainer') or v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Sound') or v:IsA('BillboardGui') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true; v.CanCollide=false; v.LocalTransparencyModifier=0; v.Color=v.Color:Lerp(color,.65) end
 end
 local body=model:FindFirstChild('Mesh') or model:FindFirstChildWhichIsA('BasePart',true)
 if body and body:IsA('BasePart') then
  model.PrimaryPart=body; model:PivotTo(CFrame.new())
  local trim=Instance.new('Part'); trim.Name='Chassis'; trim.Anchored=true; trim.CanCollide=false
  trim.Size=Vector3.new(body.Size.X*1.02,.13,body.Size.Z*1.02); trim.Color=C.line
  trim.CFrame=body.CFrame*CFrame.new(0,-body.Size.Y*.35,0); trim.Parent=model
  for _,side in {-1,1} do
   local optic=Instance.new('Part'); optic.Name='Optic'; optic.Anchored=true; optic.CanCollide=false
   optic.Size=Vector3.new(body.Size.X*.6,.1,.03); optic.Color=color; optic.Material=Enum.Material.Neon
   optic.CFrame=body.CFrame*CFrame.new(0,-body.Size.Y*.2,side*(body.Size.Z*.5+.02)); optic.Parent=model
  end
 end
 model.Parent=vp
 local camera=Instance.new('Camera'); camera.FieldOfView=32; camera.CFrame=CFrame.lookAt(Vector3.new(5,3.5,6),Vector3.zero)
 camera.Parent=vp; vp.CurrentCamera=camera
 end)
end

-- Fixed screen size, lifted clear of the plot and crystals.
function HUD.styleWorldLabel(gui: BillboardGui)
 if gui.Name~='TestLabel' then return end
 local anchor=gui.Parent
 if not anchor or not anchor:IsA('BasePart') then return end
 local field=anchor:GetAttribute('FieldId')
 local accent=field and anchor.Color or C.gold
 gui.Size=UDim2.fromOffset(field and 154 or 142,36)
 gui.Enabled=field==nil
 gui.MaxDistance=38
 gui.AlwaysOnTop=false; gui.LightInfluence=0; gui.Adornee=anchor; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.StudsOffset=Vector3.zero; gui.ExtentsOffset=Vector3.zero
 gui.StudsOffsetWorldSpace=Vector3.new(0,anchor.Size.Y*.5+3,0)
 local names={PackStation='UPGRADE PACKS',PrestigeStation='FLEET UPLINK',Printer='DRONE PRINTER',Converter='SELL ORE'}
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

function HUD.new(refs: any)
 interfaceKit=refs.interface
 local self: any=setmetatable({refs=refs,health=-1,tween=nil,input=UIS:GetLastInputType()},HUD)
 self.dock=frame(refs.root,'CommandDock',C.panel); plain(self.dock)
 self.dockScale=Instance.new('UIScale'); self.dockScale.Parent=self.dock
 self.status=card(self.dock,'SquadStatus'); self.status.BackgroundTransparency=0
 self.order=text(self.status,'CurrentOrder',8,0,150,22,11,C.green)
 self.living=text(self.status,'Living',150,0,180,22,11,C.text); self.living.TextXAlignment=Enum.TextXAlignment.Right
 local track=frame(self.status,'HealthTrack',C.track);track.Position=UDim2.fromScale(0,0);track.Size=UDim2.fromScale(1,1);track.ClipsDescendants=true;track.BackgroundTransparency=1
 self.fill=frame(track,'Fill',C.green);self.fill.Size=UDim2.fromScale(1,1)
 self.order.ZIndex=track.ZIndex+3;self.living.ZIndex=track.ZIndex+3
 -- The fleet roster lives in its menu; the work stays visible.
 self.roles={}
 for _,b in {refs.recall,refs.evade,refs.unload} do
  b.Parent=self.dock;b.Font=Enum.Font.SourceSansBold;b.TextSize=16;skin(b,b==refs.recall and C.green or b==refs.evade and C.red or C.blue);b.TextColor3=C.text;b.TextStrokeTransparency=1
 end
 refs.evade.Name='Evade'
 refs.test.Parent=refs.root;refs.test.Font=Enum.Font.SourceSansBold;refs.test.TextSize=16;skin(refs.test,C.violet);refs.test.TextColor3=C.text
 self.hint=text(refs.root,'Controls',0,0,500,16,10,C.text);self.hint.TextXAlignment=Enum.TextXAlignment.Center;self.hint.TextStrokeColor3=Color3.new(0,0,0);self.hint.TextStrokeTransparency=.3
 -- Two short, flat label/value meters closely follow the Bee Swarm reference.
 plain(refs.resources)
 self.coins=card(refs.resources,'CreditsCounter',C.blue);self.coins.BackgroundTransparency=0
 self.cargo=card(refs.resources,'CargoCounter',C.green);self.cargo.BackgroundTransparency=0
 refs.credits.Parent=self.coins;refs.credits.TextColor3=C.gold;refs.credits.Font=Enum.Font.SourceSansBold;refs.credits.TextWrapped=false;refs.credits.TextTruncate=Enum.TextTruncate.AtEnd
 for _,name in ipairs({'Icon_coin','Icon_crystal'}) do local icon=refs.resources:FindFirstChild(name);if icon then icon.Visible=false end end
 self.creditCaption=text(self.coins,'Caption',0,0,58,26,11,Color3.fromRGB(35,38,40));self.creditCaption.BackgroundTransparency=0;self.creditCaption.BackgroundColor3=C.line;self.creditCaption.Text='Credits';self.creditCaption.TextXAlignment=Enum.TextXAlignment.Center
 self.cargoCaption=text(self.cargo,'Caption',0,0,52,26,11,Color3.fromRGB(35,38,40));self.cargoCaption.BackgroundTransparency=0;self.cargoCaption.BackgroundColor3=C.line;self.cargoCaption.Text='Backpack';self.cargoCaption.TextXAlignment=Enum.TextXAlignment.Center
 refs.cargoTrack.Parent=self.cargo;refs.cargoTrack.BackgroundColor3=C.track;refs.cargoTrack.ClipsDescendants=true
 local cargoRound=refs.cargoTrack:FindFirstChildOfClass('UICorner');if cargoRound then cargoRound.CornerRadius=UDim.new(0,0) end
 for _,fill in refs.cargoTrack:GetChildren() do if fill:IsA('Frame') then
  fill.Position=UDim2.fromScale(0,0);local round=fill:FindFirstChildOfClass('UICorner');if round then round.CornerRadius=UDim.new(0,0) end
 end end
 refs.cargoText.Parent=self.cargo;refs.cargoText.TextColor3=C.gold;refs.cargoText.Font=Enum.Font.SourceSansBold;refs.cargoText.TextWrapped=false;refs.cargoText.TextTruncate=Enum.TextTruncate.AtEnd;refs.cargoText.ZIndex=refs.cargoTrack.ZIndex+2
 self.testMode=text(refs.root,'TestMode',0,0,420,16,10,C.gold);self.testMode.Text='TESTING  •  NO RESTOCK';self.testMode.TextXAlignment=Enum.TextXAlignment.Center;self.testMode.TextStrokeColor3=Color3.new(0,0,0);self.testMode.TextStrokeTransparency=.35
 refs.fleet.Parent=refs.root;refs.cards.Parent=refs.root
 for _,b in {refs.fleet,refs.cards} do
  skin(b,b==refs.fleet and C.blue or C.violet);b.Active=true
 end
 for _,label in {refs.fleetText,refs.cardsText} do label.TextSize=10;label.Font=Enum.Font.SourceSansBold;label.TextColor3=C.text;label.TextStrokeColor3=Color3.new(0,0,0);label.TextStrokeTransparency=.2 end
 skin(refs.context,C.panel);skin(refs.enemy,C.red:Lerp(C.panel,.5));skin(refs.toast,C.blue:Lerp(C.panel,.6))
 for _,panel in {refs.context,refs.enemy,refs.toast} do
  for _,label in panel:GetDescendants() do if label:IsA('TextLabel') then label.TextColor3=C.text end end
 end
 plain(refs.objective);refs.objectiveText.TextColor3=C.text;refs.objectiveText.TextStrokeColor3=Color3.new(0,0,0);refs.objectiveText.TextStrokeTransparency=.25
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

function HUD:update(view: Vector2, world: Instance, fighting: boolean)
 local r=self.refs
 local w,h=view.X,view.Y
 local touch=self.input==Enum.UserInputType.Touch or UIS.TouchEnabled
 local total,living,working,delivering=0,0,0,0
 local backpackUnits=Players.LocalPlayer:GetAttribute('BackpackUnits') or 0
 local backpackCapacity=Players.LocalPlayer:GetAttribute('BackpackCapacity') or 40
 local full=backpackUnits>=backpackCapacity
 local hp,maximum=0,0
 local folder=world:FindFirstChild('Drones')
 if folder then for _,drone in folder:GetChildren() do
  if drone:GetAttribute('Owner')==Players.LocalPlayer.UserId then
   total+=1
   local health=drone:GetAttribute('HP') or 0
   hp+=math.max(0,health);maximum+=drone:GetAttribute('MaxHP') or 0
   if health>0 then
    living+=1
    local state=drone:GetAttribute('State')
    if state=='Deliver' or state=='Pickup' or state=='Launch' or state=='Unload' then delivering+=1
    elseif state=='Mine' or state=='Travel' or state=='Attack' then working+=1 end
   end
  end
 end end
 local hidden=r.modal.Visible
 local busy=working>0 or delivering>0 or full or living<total
 if working>0 or delivering>0 then self.hasWorked=true end
 local status
 local queued=Players.LocalPlayer:GetAttribute('QueuedOreCount') or 0
 if delivering>0 then status=string.format('%d mining · %d hauling',working,delivering)
 elseif full then status='Backpack full · return to sell'
 elseif queued>0 then status=string.format('%d working · %d queued',working,queued)
 elseif working>0 then status=string.format('%d / %d working',working,living)
 elseif living<total then status=string.format('%d / %d ready',living,total)
 else status=string.format('%d drones ready',living) end
 self.order.Text=status;self.order.TextSize=16;self.order.TextColor3=C.text
 self.living.Visible=false
 self.fill.Visible=fighting
 self.fill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maximum),0,1),1)
 local character=Players.LocalPlayer.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local converter=workspace:FindFirstChild('Converter')
 local atDepot=root and converter and converter:IsA('BasePart') and (root.Position-converter.Position).Magnitude<18
 local canUnload=backpackUnits>0 and atDepot and not fighting
 local showRecall=working>0 or delivering>0
 local actions=(showRecall and 1 or 0)+(fighting and 1 or 0)+(canUnload and 1 or 0)
 local bw=touch and 90 or 100
 local width=math.min(w-24,196+actions*(bw+6))
 local reserve=touch and 108 or 12
 local stacked=w<600 and actions>1
 local dockHeight=stacked and 76 or 40
 local dockY=h-reserve-dockHeight
 self.dockScale.Scale=1
 self.dock.Size=UDim2.fromOffset(width,dockHeight)
 self.dock.Position=UDim2.fromOffset((w-width)/2,dockY)
 self.dock.Visible=not hidden and (busy or canUnload)
 self.status.Position=UDim2.fromOffset(0,0)
 self.status.Size=UDim2.fromOffset(stacked and width or math.max(100,width-actions*(bw+6)),stacked and 28 or 40)
 self.order.Position=UDim2.fromOffset(10,0);self.order.Size=UDim2.new(1,-20,1,0)
 if stacked then bw=(width-(actions-1)*6)/math.max(1,actions) end
 local x=stacked and 0 or width-actions*(bw+6)+6
 for _,entry in {{r.unload,canUnload},{r.recall,showRecall},{r.evade,fighting}} do
  local button,visible=entry[1],entry[2]
  if button then
   button.Visible=visible
   if visible then
    button.Position=UDim2.fromOffset(x,stacked and 32 or 0);button.Size=UDim2.fromOffset(bw,stacked and 44 or 40);x+=bw+6
   end
  end
 end
 r.test.Visible=Players.LocalPlayer:GetAttribute('MA_TestingEnabled')==true and not hidden
 r.test.Size=UDim2.fromOffset(math.min(208,w-24),32);r.test.Position=UDim2.fromOffset(w-math.min(208,w-24)-12,56)
 r.test.Text=touch and 'Random loadout · 2–5' or 'Random loadout · 2–5 [T]'
 r.recall.Text=touch and 'Recall' or 'Recall [R]'
 r.evade.Text=touch and 'Evade' or 'Evade [Q]'
 if r.unload then r.unload.Text=touch and 'Sell' or 'Sell [U]' end
 self.hint.Visible=not hidden and not self.hasWorked and not busy and not r.context.Visible
 self.hint.Text=Players.LocalPlayer:GetAttribute('AutomationMineEnabled') and 'Click a plot to assign your fleet' or 'Click an ore to assign a drone'
 self.hint.TextSize=16;self.hint.Size=UDim2.fromOffset(math.min(w-24,380),24)
 self.hint.Position=UDim2.fromOffset((w-math.min(w-24,380))/2,h-reserve-32)
 -- One small counter row. No permanent objectives, test banner or portraits.
 local rw=math.min(390,w-164)
 r.resources.Size=UDim2.fromOffset(rw,30);r.resources.Position=UDim2.fromOffset(12,8);r.resources.Visible=not hidden
 local cw=math.floor((rw-6)*.38)
 self.coins.Position=UDim2.fromOffset(0,0);self.coins.Size=UDim2.fromOffset(cw,30)
 self.cargo.Position=UDim2.fromOffset(cw+6,0);self.cargo.Size=UDim2.fromOffset(rw-cw-6,30)
 self.creditCaption.Visible=false;self.cargoCaption.Visible=false
 r.credits.Position=UDim2.fromOffset(9,0);r.credits.Size=UDim2.new(1,-18,1,0);r.credits.TextSize=16
 r.cargoText.Position=UDim2.fromOffset(9,0);r.cargoText.Size=UDim2.new(1,-18,1,0);r.cargoText.TextSize=16
 if w<500 then r.credits.Text=r.credits.Text:gsub('^Quartz ','Q ');r.cargoText.Text=r.cargoText.Text:gsub('^Backpack ','Pack '):gsub(' / ','/') end
 r.cargoTrack.Position=UDim2.new(0,0,1,-3);r.cargoTrack.Size=UDim2.new(1,0,0,3)
 self.testMode.Visible=false;r.objective.Visible=false
 for i,button in {r.fleet,r.cards} do
  button.Position=UDim2.fromOffset(w-102+(i-1)*48,6);button.Size=UDim2.fromOffset(44,44);button.Visible=not hidden
  local caption=i==1 and r.fleetText or r.cardsText
  caption.TextSize=12;caption.Position=UDim2.fromOffset(0,28);caption.Size=UDim2.new(1,0,0,16)
  for _,icon in button:GetChildren() do if icon:IsA('Frame') and icon.Name:sub(1,5)=='Icon_' then
   icon.Position=UDim2.fromOffset(10,0);icon.Size=UDim2.fromOffset(24,24)
  end end
 end
 local contextWidth=math.min(w-24,360)
 local contextY=self.dock.Visible and dockY-64 or h-reserve-56
 r.context.Size=UDim2.fromOffset(contextWidth,56);r.context.Position=UDim2.fromOffset((w-contextWidth)/2,contextY)
 r.contextTitle.Position=UDim2.fromOffset(10,3);r.contextTitle.Size=UDim2.new(1,-116,0,24);r.contextTitle.TextSize=16
 r.contextDetail.Position=UDim2.fromOffset(10,27);r.contextDetail.Size=UDim2.new(1,-116,0,23);r.contextDetail.TextSize=14
 r.contextDetail.TextWrapped=false;r.contextDetail.TextTruncate=Enum.TextTruncate.AtEnd
 r.contextButton.Position=UDim2.new(1,-100,0,6);r.contextButton.Size=UDim2.fromOffset(94,44);r.contextButton.TextSize=16
 for _,icon in r.context:GetChildren() do if icon:IsA('Frame') and icon.Name:sub(1,5)=='Icon_' then icon.Visible=false end end
 r.enemy.Position=UDim2.fromOffset((w-280)/2,52);r.enemy.Size=UDim2.fromOffset(math.min(280,w-24),36)
 local toastWidth=math.min(350,w-24)
 r.toast.Size=UDim2.fromOffset(toastWidth,38);r.toast.Position=UDim2.fromOffset((w-toastWidth)/2,r.enemy.Visible and 94 or 52)
 if h<400 then r.toast.Visible=false end
end

function HUD:destroy()
 self.connection:Disconnect()
 self.worldLabels:Disconnect()
 if self.tween then self.tween:Cancel() end
end
return HUD

