--!strict
-- Reference-led HUD: Bee Swarm slim meters, Pet Sim compact icons. Presentation only.
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local Config = require(script.Parent.DroneConfig)
local HUD = {}
HUD.__index = HUD
local C = {
 panel=Color3.fromRGB(66,69,72), line=Color3.fromRGB(210,214,216),
 text=Color3.fromRGB(245,245,241), muted=Color3.fromRGB(192,197,199),
 blue=Color3.fromRGB(105,188,217), green=Color3.fromRGB(132,187,120),
 red=Color3.fromRGB(223,112,114), track=Color3.fromRGB(53,55,57),
 gold=Color3.fromRGB(223,203,125), violet=Color3.fromRGB(169,149,201),
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
 t.BackgroundTransparency=1; t.TextColor3=color; t.TextSize=size; t.Font=Enum.Font.GothamBold
 t.TextXAlignment=Enum.TextXAlignment.Left; t.TextTruncate=Enum.TextTruncate.AtEnd; t.Text=''
 t.ZIndex=parent:IsA('GuiObject') and parent.ZIndex+1 or 2; t.Parent=parent
 return t
end
local function skin(f: GuiObject, color: Color3)
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
 gui.MaxDistance=field and 230 or 100
 gui.AlwaysOnTop=false; gui.LightInfluence=0; gui.Adornee=anchor; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.StudsOffset=Vector3.zero; gui.ExtentsOffset=Vector3.zero
 gui.StudsOffsetWorldSpace=Vector3.new(0,anchor.Size.Y*.5+(field and 19 or 6),0)
 local names={PackStation='UPGRADE PACKS',PrestigeStation='FLEET UPLINK',Printer='DRONE PRINTER',Converter='SELL ORE'}
 for _,label in gui:GetChildren() do
  if not label:IsA('TextLabel') then continue end
  if field then label.Text=tostring(field)..'  '..string.upper(anchor.Parent.Name)
  elseif names[anchor.Name] then label.Text=names[anchor.Name] end
  label.AnchorPoint=Vector2.new(.5,.5); label.Position=UDim2.fromScale(.5,.5); label.Size=UDim2.fromScale(1,1)
  label.BackgroundColor3=C.panel; label.BackgroundTransparency=.12
  label.TextColor3=C.text; label.Font=Enum.Font.GothamBold
  label.TextScaled=false; label.TextSize=14; label.TextWrapped=false; label.TextStrokeTransparency=1
  label.BorderSizePixel=0
  for _,v in label:GetChildren() do if v:IsA('UISizeConstraint') or v:IsA('UITextSizeConstraint') or v:IsA('UIPadding') then v:Destroy() end end
  local round=label:FindFirstChildOfClass('UICorner') or Instance.new('UICorner')
  round.CornerRadius=UDim.new(0,3); round.Parent=label
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
 local self: any=setmetatable({refs=refs,health=-1,tween=nil,input=UIS:GetLastInputType()},HUD)
 self.dock=frame(refs.root,'CommandDock',C.panel); plain(self.dock)
 self.dockScale=Instance.new('UIScale'); self.dockScale.Parent=self.dock
 self.status=card(self.dock,'SquadStatus'); self.status.BackgroundTransparency=.28
 self.order=text(self.status,'CurrentOrder',8,0,150,22,11,C.green)
 self.living=text(self.status,'Living',150,0,180,22,11,C.text); self.living.TextXAlignment=Enum.TextXAlignment.Right
 local track=frame(self.status,'HealthTrack',C.track);track.Position=UDim2.fromScale(0,0);track.Size=UDim2.fromScale(1,1);track.ClipsDescendants=true
 self.fill=frame(track,'Fill',Color3.fromRGB(48,86,57));self.fill.Size=UDim2.fromScale(1,1)
 self.order.ZIndex=track.ZIndex+3;self.living.ZIndex=track.ZIndex+3
 self.roles={}; self.roleOrder={'Starter','Dart','Striker','Medic','Charger'}
 for _,name in self.roleOrder do
  local color=Config.Types[name] and Config.Types[name].Color or C.blue
  local slot=card(self.dock,name,C.panel);slot.BackgroundTransparency=.3;portrait(slot,color)
  local count=text(slot,'Count',0,0,50,20,15,C.text);count.TextXAlignment=Enum.TextXAlignment.Right
  count.TextStrokeColor3=Color3.new(0,0,0);count.TextStrokeTransparency=.2;count.ZIndex=slot.ZIndex+3
  local title=text(slot,'Role',2,0,50,14,9,C.text);title.AnchorPoint=Vector2.new(0,1);title.Position=UDim2.new(0,2,1,-4);title.Text=name;title.TextXAlignment=Enum.TextXAlignment.Center
  self.roles[name]={frame=slot,count=count,title=title}
 end
 for _,b in {refs.recall,refs.test,refs.evade} do
  b.Parent=self.dock;b.Font=Enum.Font.GothamBold;b.TextSize=12;skin(b,C.panel);b.TextColor3=C.text;b.TextStrokeTransparency=1
 end
 refs.evade.Name='Evade'
 self.hint=text(refs.root,'Controls',0,0,500,16,10,C.text);self.hint.TextXAlignment=Enum.TextXAlignment.Center;self.hint.TextStrokeColor3=Color3.new(0,0,0);self.hint.TextStrokeTransparency=.3
 -- Two short, flat label/value meters closely follow the Bee Swarm reference.
 plain(refs.resources)
 self.coins=card(refs.resources,'CreditsCounter');self.coins.BackgroundTransparency=0
 self.cargo=card(refs.resources,'CargoCounter');self.cargo.BackgroundTransparency=0
 refs.credits.Parent=self.coins;refs.credits.TextColor3=C.gold;refs.credits.Font=Enum.Font.GothamBold;refs.credits.TextWrapped=false;refs.credits.TextTruncate=Enum.TextTruncate.AtEnd
 local coin=refs.resources:FindFirstChild('Icon_coin');if coin then coin.Visible=false end
 self.creditCaption=text(self.coins,'Caption',0,0,58,26,11,Color3.fromRGB(35,38,40));self.creditCaption.BackgroundTransparency=0;self.creditCaption.BackgroundColor3=C.line;self.creditCaption.Text='Credits';self.creditCaption.TextXAlignment=Enum.TextXAlignment.Center
 self.cargoCaption=text(self.cargo,'Caption',0,0,52,26,11,Color3.fromRGB(35,38,40));self.cargoCaption.BackgroundTransparency=0;self.cargoCaption.BackgroundColor3=C.line;self.cargoCaption.Text='Cargo';self.cargoCaption.TextXAlignment=Enum.TextXAlignment.Center
 refs.cargoTrack.Parent=self.cargo;refs.cargoTrack.BackgroundColor3=C.track;refs.cargoTrack.ClipsDescendants=true
 local cargoRound=refs.cargoTrack:FindFirstChildOfClass('UICorner');if cargoRound then cargoRound.CornerRadius=UDim.new(0,0) end
 for _,fill in refs.cargoTrack:GetChildren() do if fill:IsA('Frame') then
  fill.Position=UDim2.fromScale(0,0);local round=fill:FindFirstChildOfClass('UICorner');if round then round.CornerRadius=UDim.new(0,0) end
 end end
 refs.cargoText.Parent=self.cargo;refs.cargoText.TextColor3=C.gold;refs.cargoText.Font=Enum.Font.GothamBold;refs.cargoText.TextWrapped=false;refs.cargoText.TextTruncate=Enum.TextTruncate.AtEnd;refs.cargoText.ZIndex=refs.cargoTrack.ZIndex+2
 self.testMode=text(refs.root,'TestMode',0,0,420,16,10,C.gold);self.testMode.Text='TESTING  •  NO RESTOCK';self.testMode.TextXAlignment=Enum.TextXAlignment.Center;self.testMode.TextStrokeColor3=Color3.new(0,0,0);self.testMode.TextStrokeTransparency=.35
 refs.fleet.Parent=refs.root;refs.cards.Parent=refs.root
 for _,b in {refs.fleet,refs.cards} do
  plain(b);b.Active=true
  local round=b:FindFirstChildOfClass('UICorner');if round then round:Destroy() end
  for _,v in b:GetChildren() do if v:IsA('Frame') and v.Name:sub(1,5)~='Icon_' then v.Visible=false end end
 end
 for _,label in {refs.fleetText,refs.cardsText} do label.TextSize=10;label.Font=Enum.Font.GothamBold;label.TextColor3=C.text;label.TextStrokeColor3=Color3.new(0,0,0);label.TextStrokeTransparency=.2 end
 skin(refs.context,C.panel);skin(refs.enemy,C.panel);skin(refs.toast,C.panel)
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
 local short=h<480
 local wide=w>=700
 local touch=self.input==Enum.UserInputType.Touch or UIS.TouchEnabled
 local pad=string.find(self.input.Name,'Gamepad')~=nil
 local total,living,hp,maximum=0,0,0,0
 local counts: {[string]: number}={}
 local order,priority='FOLLOWING',0
 local priorities={Follow=1,Return=2,Travel=3,Mine=4,Attack=5}
 local labels={Follow='FOLLOWING',Return='RECALLING',Travel='MOVING',Mine='MINING',Attack='ATTACKING'}
 local folder=world:FindFirstChild('Drones')
 if folder then for _,drone in folder:GetChildren() do
  if drone:GetAttribute('Owner')==Players.LocalPlayer.UserId then
   total+=1; local health=drone:GetAttribute('HP') or 0
   hp+=math.max(0,health); maximum+=drone:GetAttribute('MaxHP') or 0
   local role=drone:GetAttribute('Role') or drone:GetAttribute('Type')
   local key=Config.Types[role] and role or 'Starter'
   -- Keep a lost role visible while it reprints, with a zero active count.
   counts[key]=counts[key] or 0
   if health>0 then
    living+=1; counts[key]+=1
    local state=drone:GetAttribute('State'); local rank=priorities[state] or 0
    if rank>priority then order=labels[state]; priority=rank end
   end
  end
 end end
 if total==0 then order='CONNECTING' elseif living==0 then order='REPRINTING' end
 self.order.Text=order;self.order.TextColor3=C.text
 self.living.Text=string.format('%d / %d DRONES   •   %d%%',living,total,math.floor(hp/math.max(1,maximum)*100+.5))
 local ratio=math.clamp(hp/math.max(1,maximum),0,1)
 if math.abs(ratio-self.health)>.001 then
  if self.tween then self.tween:Cancel() end
  self.health=ratio;self.fill.BackgroundColor3=ratio<.3 and Color3.fromRGB(104,45,51) or Color3.fromRGB(48,86,57)
  self.tween=TweenService:Create(self.fill,TweenInfo.new(.18),{Size=UDim2.fromScale(ratio,1)}); self.tween:Play()
 end
 local visibleRoles={}
 for _,name in self.roleOrder do
  local slot=self.roles[name]; slot.frame.Visible=counts[name]~=nil and (not short or wide)
  slot.count.Text='×'..(counts[name] or 0)
  if counts[name]~=nil then table.insert(visibleRoles,name) end
 end
 local testing=Players.LocalPlayer:GetAttribute('MA_TestingEnabled')==true
 local actions=1+(testing and 1 or 0)+(fighting and 1 or 0)
 local count=math.max(1,#visibleRoles)
 local slotWidth=wide and (short and 44 or 52) or 58
 local portraitWidth=count*slotWidth+(count-1)*6
 local actionWidth=wide and (short and 76 or 88) or 0
 local baseWidth=wide and math.max(300,portraitWidth+12+actions*(actionWidth+6)-6) or 366
 local available=w-((touch and short and w>=700) and 260 or 24)
 local scale=math.min(1,available/baseWidth)
 self.dockScale.Scale=scale
 local buttonHeight=math.ceil(46/scale)
 local portraitHeight=wide and 54 or 58
 local actionY=wide and 26 or (short and 26 or 90)
 local dockHeight=wide and (26+math.max(portraitHeight,buttonHeight)) or actionY+buttonHeight
 local reserve=touch and (short and (w>=700 and 12 or 76) or 112) or 12
 local dockY=h-reserve-dockHeight*scale
 self.dock.Position=UDim2.fromOffset((w-baseWidth*scale)/2,dockY);self.dock.Size=UDim2.fromOffset(baseWidth,dockHeight);self.dock.Visible=not r.modal.Visible
 self.status.Size=UDim2.fromOffset(baseWidth,22);self.order.Size=UDim2.fromOffset(baseWidth-163,20)
 self.living.Position=UDim2.new(1,-152,0,0);self.living.Size=UDim2.fromOffset(144,20)
 self.living.Text=string.format('%d/%d drones  •  %d%%',living,total,math.floor(ratio*100+.5))
 local left=wide and 0 or (baseWidth-portraitWidth)/2
 for i,name in visibleRoles do
  local slot=self.roles[name]
  slot.frame.Position=UDim2.fromOffset(left+(i-1)*(slotWidth+6),26);slot.frame.Size=UDim2.fromOffset(slotWidth,portraitHeight)
  slot.count.Size=UDim2.new(1,-4,0,20);slot.title.Size=UDim2.new(1,-4,0,14)
 end
 if not wide then actionWidth=(baseWidth-(actions-1)*6)/actions end
 local x=wide and (baseWidth-actions*(actionWidth+6)+6) or 0
 local index=0
 for _,entry in {{r.recall,true},{r.test,testing},{r.evade,fighting}} do
  local b,visible=entry[1],entry[2];b.Visible=visible
  if visible then b.Position=UDim2.fromOffset(x+index*(actionWidth+6),actionY);b.Size=UDim2.fromOffset(actionWidth,buttonHeight);index+=1 end
 end
 r.recall.Text='Recall'..(touch and '' or (pad and '  [B]' or '  [R]'))
 local remaining=math.max(0,(Players.LocalPlayer:GetAttribute('MA_TestReadyAt') or 0)-workspace:GetServerTimeNow())
 r.test.Text=remaining>0 and string.format('%.1fs',remaining) or ('Reroll'..(touch and '' or (pad and '  [Y]' or '  [T]')))
 r.test.Active=remaining==0; r.test.Selectable=r.test.Active
 r.evade.Text='Evade'..(touch and '' or (pad and '  [X]' or '  [Q]'))
 self.hint.Position=UDim2.fromOffset((w-500)/2,dockY-24); self.hint.Visible=not touch and not r.modal.Visible and not short and not r.context.Visible
 self.hint.Text=pad and 'RT INTERACT    RB COMMAND FIELD' or 'CLICK A FIELD TO SEND YOUR FLEET  •  1–5 SELECT FIELD'
 -- Match the reference's compact rectangular meters rather than tall cards.
 local rw=math.min(470,w-24)
 local resourceHeight=26
 r.resources.Size=UDim2.fromOffset(rw,resourceHeight);r.resources.Position=UDim2.fromOffset((w-rw)/2,8);r.resources.Visible=not r.modal.Visible
 local coinWidth=math.floor((rw-6)*.46)
 self.coins.Position=UDim2.fromOffset(0,0);self.coins.Size=UDim2.fromOffset(coinWidth,resourceHeight)
 self.cargo.Position=UDim2.fromOffset(coinWidth+6,0);self.cargo.Size=UDim2.fromOffset(rw-coinWidth-6,resourceHeight)
 r.credits.Position=UDim2.fromOffset(65,0);r.credits.Size=UDim2.new(1,-69,1,0);r.credits.TextSize=w<360 and 12 or 14
 self.creditCaption.Size=UDim2.fromOffset(58,resourceHeight);self.cargoCaption.Size=UDim2.fromOffset(52,resourceHeight)
 r.cargoText.Position=UDim2.fromOffset(58,0);r.cargoText.Size=UDim2.new(1,-62,1,0);r.cargoText.TextSize=w<360 and 11 or 13;r.cargoText.Text=r.cargoText.Text:gsub('^Cargo ','')
 r.cargoTrack.Position=UDim2.fromOffset(52,0);r.cargoTrack.Size=UDim2.new(1,-52,1,0)
 local noRestock=Players.LocalPlayer:GetAttribute('MA_NoRestock')==true
 self.testMode.Visible=noRestock and not r.modal.Visible;self.testMode.Size=UDim2.fromOffset(rw,16);self.testMode.Position=UDim2.fromOffset((w-rw)/2,37)
 for i,b in {r.fleet,r.cards} do
  b.Position=UDim2.fromOffset(12+(i-1)*52,54);b.Size=UDim2.fromOffset(46,46);b.Visible=not r.modal.Visible
  local label=i==1 and r.fleetText or r.cardsText;label.Position=UDim2.fromOffset(0,32);label.Size=UDim2.new(1,0,0,14)
  for _,icon in b:GetChildren() do if icon:IsA('Frame') and icon.Name:sub(1,5)=='Icon_' then icon.Position=UDim2.fromOffset(8,1);icon.Size=UDim2.fromOffset(30,30) end end
 end
 r.objective.Size=UDim2.fromOffset(248,48);r.objective.Position=UDim2.fromOffset(w-260,54);r.objective.Visible=not r.modal.Visible and w>=1000 and not fighting and not short
 r.objectiveText.Position=UDim2.fromOffset(0,0);r.objectiveText.Size=UDim2.fromScale(1,1);r.objectiveText.TextSize=11
 for _,icon in r.objective:GetChildren() do if icon:IsA('Frame') and icon.Name:sub(1,5)=='Icon_' then icon.Visible=false end end
 local contextWidth=math.min(wide and 390 or baseWidth,w-24)
 local contextHeight=h<300 and 50 or 56
 r.context.Size=UDim2.fromOffset(contextWidth,contextHeight); r.context.Position=UDim2.fromOffset((w-contextWidth)/2,dockY-contextHeight-10)
 local showContextIcon=contextWidth>=350
 local contextTextX=showContextIcon and 43 or 10
 r.contextTitle.Position=UDim2.fromOffset(contextTextX,2); r.contextTitle.Size=UDim2.new(1,-contextTextX-117,0,24); r.contextTitle.TextSize=16
 r.contextDetail.Position=UDim2.fromOffset(contextTextX,26); r.contextDetail.Size=UDim2.new(1,-contextTextX-117,0,22); r.contextDetail.TextSize=16; r.contextDetail.TextWrapped=false; r.contextDetail.TextTruncate=Enum.TextTruncate.AtEnd
 r.contextButton.Position=UDim2.new(1,-108,0,(contextHeight-46)/2); r.contextButton.Size=UDim2.fromOffset(102,46); r.contextButton.TextSize=16
 for _,icon in r.context:GetChildren() do if icon:IsA('Frame') and icon.Name:sub(1,5)=='Icon_' then icon.Visible=showContextIcon;icon.Position=UDim2.fromOffset(8,15); icon.Size=UDim2.fromOffset(28,28) end end
 if short and dockY-contextHeight-10<52 then r.context.Position=UDim2.fromOffset((w-contextWidth)/2,52) end
 r.enemy.Position=UDim2.fromOffset((w-300)/2,w<700 and 132 or 82); r.enemy.Size=UDim2.fromOffset(math.min(300,w-24),50)
 r.toast.Size=UDim2.fromOffset(math.min(390,w-24),44); r.toast.Position=UDim2.fromOffset((w-math.min(390,w-24))/2,r.enemy.Visible and 190 or (w<700 and 138 or 82))
 -- Limited vertical room: retain commands, counters and the immediate interaction.
 if short or (r.context.Visible and r.context.Position.Y.Offset<130) then r.toast.Visible=false end
 if short and r.context.Visible then r.enemy.Visible=false end
end

function HUD:destroy()
 self.connection:Disconnect()
 self.worldLabels:Disconnect()
 if self.tween then self.tween:Cancel() end
end
return HUD

