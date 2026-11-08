-- Custom equipment hotbar, held tools and impact rubble.
local V={};V.__index=V
function V.new(ctx)
 local UIS=game:GetService('UserInputService');local Http=game:GetService('HttpService')
 local players=game:GetService('Players');local player=players.LocalPlayer;local U=ctx.interface
 local self=setmetatable({ctx=ctx,player=player,players=players,uis=UIS,slots={},world={},held={},chips={},connections={},state={slots={},selected=0}},V)
 local gui=Instance.new('Frame');gui.Name='TemporaryToolHotbar';gui.AnchorPoint=Vector2.new(.5,1);gui.BackgroundTransparency=1;gui.Active=true;gui.ZIndex=ctx.parent.ZIndex+2;gui.Parent=ctx.parent;self.gui=gui
 self.hint=U.text(gui,UDim2.fromOffset(0,-23),UDim2.new(1,0,0,20),'',13,U.palette.white,true);self.hint.TextXAlignment=Enum.TextXAlignment.Center
 for i=1,ToolRules.SLOTS do
  local b=U.button(gui,UDim2.fromOffset(0,0),UDim2.fromOffset(78,82),'',function() self:equip(i) end,U.palette.panel)
  b.Name='ToolSlot'..i
  local icon=Instance.new('ViewportFrame');icon.Name='ToolIcon';icon.BackgroundTransparency=1;icon.Size=UDim2.new(1,-8,0,46);icon.Position=UDim2.fromOffset(4,2);icon.Ambient=Color3.fromRGB(205,205,220);icon.LightColor=Color3.new(1,1,1);icon.ZIndex=b.ZIndex+2;icon.Parent=b
  local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(Vector3.new(3,2.5,5),Vector3.zero);camera.FieldOfView=34;camera.Parent=icon;icon.CurrentCamera=camera
  local name=U.text(b,UDim2.fromOffset(3,47),UDim2.new(1,-6,0,17),'',12,U.palette.white,true);name.TextXAlignment=Enum.TextXAlignment.Center
  local count=U.text(b,UDim2.fromOffset(4,3),UDim2.fromOffset(20,16),tostring(i),12,U.palette.white,true)
  local bar=Instance.new('Frame');bar.Name='DurabilityTrack';bar.BorderSizePixel=0;bar.BackgroundColor3=Color3.fromRGB(28,29,38);bar.Size=UDim2.new(1,-12,0,5);bar.Position=UDim2.new(0,6,1,-11);bar.ZIndex=b.ZIndex+2;bar.Parent=b
  local fill=bar:Clone();fill.Name='Durability';fill.Size=UDim2.fromScale(1,1);fill.Position=UDim2.fromOffset(0,0);fill.BackgroundColor3=Color3.fromRGB(156,231,102);fill.Parent=bar
  self.slots[i]={button=b,icon=icon,name=name,fill=fill,key=count}
 end
 self.use=U.button(ctx.parent,UDim2.new(.5,-54,1,-180),UDim2.fromOffset(108,40),'Throw',function() self:activate() end,U.palette.accent);self.use.Name='UseTemporaryTool';self.use.Visible=false
 local function read()
  local ok,state=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_FieldTools') or '')
  self.state=ok and type(state)=='table' and state or {slots={},selected=0}
  for i,slot in ipairs(self.slots) do
   local item=self.state.slots[i];local kind=item and item.kind
   if kind~=slot.kind then
    if slot.model then slot.model:Destroy();slot.model=nil end
    if kind and ToolRules.ITEMS[kind] then slot.model=ToolArt.create(kind,slot.icon)
     local center,extent=slot.model:GetBoundingBox()
     local target=center.Position;local distance=math.max(5,extent.Magnitude*1.8)
     slot.icon.CurrentCamera.CFrame=CFrame.lookAt(target+Vector3.new(.44,.26,1).Unit*distance,target)
    end
    slot.kind=kind
   end
  end
 end
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_FieldTools'):Connect(read));read()
 local starter=game:GetService('StarterGui');local ok,enabled=pcall(function() return starter:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
 self.oldBackpack=ok and enabled
 pcall(function() starter:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
 local function add(part)
  if not part:IsA('BasePart') or self.world[part] or not ToolRules.ITEMS[part:GetAttribute('Kind')] then return end
  local kind=part:GetAttribute('Kind');local model=ToolArt.create(kind,ctx.localFX,part:GetAttribute('State')=='Flying')
  model:PivotTo(part.CFrame);part.LocalTransparencyModifier=1
  self.world[part]={model=model,fill=ToolArt.bar(model.PrimaryPart,part:GetAttribute('HP') or 1,part:GetAttribute('MaxHP') or 1),kind=kind}
 end
 local folder=ctx.world:WaitForChild('FieldTools');for _,p in ipairs(folder:GetChildren()) do add(p) end
 table.insert(self.connections,folder.ChildAdded:Connect(add))
 local effects=ctx.world:WaitForChild('ToolImpacts')
 table.insert(self.connections,effects.ChildAdded:Connect(function(p) self:impact(p) end))
 return self
end
function V:selected() return self.state.slots[self.state.selected or 0] end
function V:equip(slot)
 if self.ctx.hidden() or not self.state.runId then return end
 local item=self.state.slots[slot];if not item or item.state~='Held' then return end
 self.ctx.onSelect()
 self.ctx.command:FireServer('EquipFieldTool',{runId=self.state.runId,version=self.state.version,slot=self.state.selected==slot and 0 or slot})
end
function V:unequip()
 if (self.state.selected or 0)>0 then self.ctx.command:FireServer('EquipFieldTool',{runId=self.state.runId,version=self.state.version,slot=0}) end
end
function V:input(input,processed)
 if processed or self.uis:GetFocusedTextBox() or self.ctx.hidden() then return false end
 local key=input.KeyCode
 local keys={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8}
 if keys[key] then self:equip(keys[key]);return true end
 if key==Enum.KeyCode.Backspace or key==Enum.KeyCode.Escape or key==Enum.KeyCode.ButtonB then if self:selected() then self:unequip();return true end end
 if key==Enum.KeyCode.ButtonL1 then
  for n=1,ToolRules.SLOTS do local i=((self.state.selected or 0)+n-1)%ToolRules.SLOTS+1;local item=self.state.slots[i];if item and item.state=='Held' then self:equip(i);break end end;return true
 end
 if self:selected() and (key==Enum.KeyCode.ButtonR2 or input.UserInputType==Enum.UserInputType.MouseButton1) then self:activate();return true end
 return false
end
function V:contact(screen)
 local camera=workspace.CurrentCamera;local hr=self.player.Character and self.player.Character:FindFirstChild('HumanoidRootPart')
 if not camera or not hr then return end
 local pointer=screen or self.uis:GetMouseLocation()
 local last=self.uis:GetLastInputType();local center=not screen and (last==Enum.UserInputType.Touch or last==Enum.UserInputType.Gamepad1 or not self.uis.MouseEnabled)
 local ray=center and camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2) or camera:ScreenPointToRay(pointer.X,pointer.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.ctx.localFX,self.player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*180,params)
 return hit and hit.Position,hit and hit.Instance
end
function V:activate(screen)
 local item=self:selected();if not item or item.state~='Held' or self.ctx.hidden() then return end
 local point,target=self:contact(screen);local id=target and target:GetAttribute('ResourceId');if not id then return end
 if not screen and self.uis.MouseEnabled and not self.uis.TouchEnabled and self.ctx.blocks(self.uis:GetMouseLocation()) then return end
 self.ctx.command:FireServer('UseFieldTool',{runId=self.state.runId,version=self.state.version,id=item.id,point=point,resourceId=id})
end
function V:click(screen) if not self:selected() then return false end;self:activate(screen);return true end
function V:blocks(point)
 if not self.gui.Visible then return false end
 local p,s=self.gui.AbsolutePosition,self.gui.AbsoluteSize
 return point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y
end
function V:impact(source)
 local now=workspace:GetServerTimeNow();local at=source:GetAttribute('StartedAt') or 0
 if now-at>.3 then return end
 local kind=source:GetAttribute('Kind');local position=source.Position
 local camera=workspace.CurrentCamera;if not camera or (camera.CFrame.Position-position).Magnitude>120 then return end
 local color=source:GetAttribute('Color') or Color3.fromRGB(160,150,135)
 local cue=({BowlingBallWindup='tool_windup',CrowbarWindup='tool_windup',GreatswordWindup='tool_windup',SledgehammerWindup='tool_windup',JellyGrenadeWindup='tool_windup',MoltenTongsWindup='tool_windup',
  BowlingBallRelease='tool_throw',JellyGrenadeRelease='tool_throw',MoltenTongsRelease='tool_throw',JellyStick='tool_stick'})[kind]
 if cue then self.ctx.audio:play(cue,position);return end
 if kind~='Drop' then
  local grenade=kind=='JellyGrenade';self.ctx.audio:play(grenade and 'impact' or kind=='BowlingBall' and 'breaker_contact' or kind=='Crowbar' and 'tool_pipe' or kind=='Greatsword' and 'tool_slice' or kind=='MoltenTongs' and 'tool_sizzle' or kind=='Sledgehammer' and 'breaker_contact' or kind=='Shatter' and 'rubble' or 'rock_clack',position,{pitch=grenade and .65 or .8,level=1})
  self.ctx.presentation:kick(position,grenade and .14 or .075,now)
 end
 local slab=source:GetAttribute('Slab');local size=source:GetAttribute('RockSize')
 local rockFrame=source:GetAttribute('RockFrame')
 local variant=source:GetAttribute('RockVariant') or ''
 local material=Enum.Material[source:GetAttribute('RockMaterial') or 'Rock'] or Enum.Material.Rock
 local radius=size and math.clamp(math.max(size.X,size.Z)*.5,.8,8) or 1
 local reduced=BeamVFX.reduced()
 if slab and rockFrame and #self.chips<=66 then
  local frame=CFrame.new(position)*rockFrame.Rotation
  local scale=math.clamp(radius,1,6)
  local floor=rockFrame.Position.Y-size.Y*.5
  -- One sweep across the selected cut plane. The detached volume is still
  -- together until the pressure at its center throws the six pieces outward.
  if not reduced then
   local left=(frame*CFrame.new(-slab.X*.62,-slab.Y*.5,.02)).Position
   local right=(frame*CFrame.new(slab.X*.62,-slab.Y*.5,.02)).Position
   RoleVisuals.Beam(left,right,Color3.fromRGB(178,232,255),.14*scale,.16,'Lance')
   RoleVisuals.Pulse(position,Color3.fromRGB(178,232,255),radius*.9,radius*3.1,.46)
  end
  for i=1,6 do
   local x=(i-1)%3-1;local z=i<=3 and -.25 or .25
   local pose=frame*CFrame.new(x*slab.X/3,0,z*slab.Z)
   local dir=(frame.RightVector*x-frame.LookVector*z*3).Unit
   local p=Instance.new('Part');p.Name='SlicedOreBlock';p.Size=Vector3.new(slab.X/3,slab.Y,slab.Z*.5)*.976
   p.Color=color;p.Material=material;p.MaterialVariant=variant;p.CFrame=pose;p.Anchored=true;p.CastShadow=false
   p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=self.ctx.localFX
   self.chips[#self.chips+1]={part=p,at=at,expires=at+1.15,pose=pose,velocity=dir*(4+scale*1.4),
    rise=4+scale*.75,floor=floor+p.Size.Y*.5,spin=Vector3.new(z*2,0,x*.8)}
  end
 end
 if kind=='JellyGrenade' then RoleVisuals.Pulse(position,color,radius*.65,24,.47)
 elseif kind=='BowlingBall' or kind=='Sledgehammer' then RoleVisuals.Pulse(position,Color3.fromRGB(238,203,154),radius*.8,radius*3.2,.37)
 elseif kind=='MoltenTongs' then RoleVisuals.Pulse(position,color,radius*.6,radius*2.25,.58) end
 local count=kind=='JellyGrenade' and 18 or kind=='BowlingBall' and 12 or kind=='Shatter' and 10 or 5
 if reduced then count=math.min(count,3) end
 for i=1,count do
  if #self.chips>=72 then break end
  local angle=i*2.39996;local p=Instance.new('Part');p.Name='ToolRubble'
  local scale=math.clamp(radius*.52,.65,2.5)
  local gel=kind=='JellyGrenade' and i%3==0
  local ember=kind=='MoltenTongs'
  p.Size=Vector3.new(.18+(i%4)*.10,.12+(i%3)*.07,.19+(i%5)*.053)*scale
  p.Color=color;p.Material=ember and Enum.Material.Neon or gel and Enum.Material.Glass or kind=='Shatter' and Enum.Material.Metal or material
  if gel or ember then p.Shape=Enum.PartType.Ball else p.MaterialVariant=variant end
  local outward=Vector3.new(math.cos(angle),0,math.sin(angle))
  local normal=source:GetAttribute('Normal') or Vector3.yAxis
  p.Anchored=false;p.CanCollide=true;p.CanTouch=false;p.CanQuery=false
  p.CFrame=CFrame.new(position+normal*.22+outward*.32*scale);p.Parent=self.ctx.localFX
  p.AssemblyLinearVelocity=outward*((5+i%7)*scale)+Vector3.yAxis*(7+i%9)+normal*(kind=='Crowbar' and 9 or 3)
  p.AssemblyAngularVelocity=Vector3.new(i,5,-i)
  self.chips[#self.chips+1]={part=p,at=now,expires=now+1.5}
 end
end
function V:layout(item,active)
 local size=self.ctx.parent.AbsoluteSize;local touch=self.uis.TouchEnabled and not self.uis.KeyboardEnabled
 local width=math.clamp(size.X-24,120,544);local columns=(size.X<450 and size.Y>=430) and 4 or ToolRules.SLOTS
 local cell=(width-(columns-1)*6)/columns;local height=size.Y<430 and 59 or 72
 local totalHeight=math.ceil(ToolRules.SLOTS/columns)*(height+6)-6
 local bottom=touch and (size.X<550 and 98 or 18) or 12
 self.gui.Size=UDim2.fromOffset(width,totalHeight);self.gui.Position=UDim2.new(.5,0,1,-bottom);self.gui.Visible=not self.ctx.hidden()
 for i,slot in ipairs(self.slots) do
  local entry=self.state.slots[i];slot.button.Size=UDim2.fromOffset(cell,height);slot.button.Position=UDim2.fromOffset(((i-1)%columns)*(cell+6),math.floor((i-1)/columns)*(height+6))
  slot.icon.Size=UDim2.new(1,-8,0,height-35);slot.name.Position=UDim2.fromOffset(3,height-33)
  slot.name.Text=entry and (entry.state=='Held' and ToolRules.ITEMS[entry.kind].short or entry.state=='Recover' and 'Touch ball' or entry.state=='Windup' and 'Winding up' or entry.state=='Deployed' and 'Deployed' or entry.state=='Molten' and 'Melting' or entry.state=='Stuck' and 'Fusing…' or 'Thrown') or '—'
  slot.fill.Size=UDim2.fromScale(entry and entry.hp/entry.maxHP or 0,1)
  slot.fill.BackgroundColor3=entry and entry.hp/entry.maxHP<=.25 and Color3.fromRGB(246,117,83) or Color3.fromRGB(156,231,102)
  slot.button.BackgroundColor3=self.state.selected==i and Color3.fromRGB(74,97,148) or Color3.fromRGB(45,49,63)
  slot.button.BackgroundTransparency=entry and .05 or .4
  slot.button.Selectable=entry and entry.state=='Held' or false
 end
 self.use.Visible=active==true and touch
 self.use.Text='Use';self.use.Position=UDim2.new(.5,-54,1,-bottom-totalHeight-68)
 self.hint.Text=active and (ToolRules.ITEMS[item.kind].name..' · Click a spot on the rock') or ''
end
function V:step(dt,now)
 local item=self:selected();local active=type(item)=='table' and item.state=='Held' and not self.ctx.hidden()
 if now>=(self.hudAt or 0) then self.hudAt=now+.09;self:layout(item,active) end
 for source,r in pairs(self.world) do
  if not source.Parent then r.model:Destroy();self.world[source]=nil
  else
   local state=source:GetAttribute('State');local frame=source.CFrame
   local origin,velocity=source:GetAttribute('Origin'),source:GetAttribute('Velocity')
   if state=='Flying' and origin and velocity then
    local t=math.max(0,now-(source:GetAttribute('StartedAt') or now));local def=ToolRules.ITEMS[r.kind]
    frame=CFrame.new(ToolRules.position(origin,velocity,def.gravity,t))*CFrame.Angles(t*10,0,t*3)
   end
   r.model:PivotTo(frame);r.fill.Size=UDim2.fromScale((source:GetAttribute('HP') or 0)/(source:GetAttribute('MaxHP') or 1),1)
   if state=='Stuck' then local q=math.clamp(1-((source:GetAttribute('FuseAt') or now)-now)/ToolRules.ITEMS.JellyGrenade.fuse,0,1);r.model.PrimaryPart.Color=Color3.fromRGB(144,225,99):Lerp(Color3.fromRGB(255,245,155),math.sin(now*(12+q*18))*.5+.5) end
  end
 end
 for _,p in ipairs(self.players:GetPlayers()) do
  local kind=p:GetAttribute('HeldFieldTool');local hand=p.Character and (p.Character:FindFirstChild('RightHand') or p.Character:FindFirstChild('Right Arm'))
  local r=self.held[p]
  if r and (r.kind~=kind or not hand) then r.model:Destroy();self.held[p]=nil;r=nil end
  if kind and hand and ToolRules.ITEMS[kind] then
   if not r then r={kind=kind,model=ToolArt.create(kind,self.ctx.localFX)};r.fill=ToolArt.bar(r.model.PrimaryPart,p:GetAttribute('HeldFieldToolHP') or 1,ToolRules.ITEMS[kind].uses);self.held[p]=r end
   r.fill.Size=UDim2.fromScale((p:GetAttribute('HeldFieldToolHP') or 0)/ToolRules.ITEMS[kind].uses,1)
   local wind=p:GetAttribute('ToolWindupUntil')
   local release=p:GetAttribute('ToolSwingAt')
   local elapsed=release and now-release or 10
   local q=wind and math.clamp(1-(wind-now)/(ToolRules.ITEMS[kind].windup or .3),0,1) or 0
   local recoil=not wind and elapsed>=0 and elapsed<.26 and math.sin(math.pi*elapsed/.26)^.65 or 0
   r.model:PivotTo(hand.CFrame*CFrame.new(-q*.48,-.5+q*.92,-.4+q*.6-recoil*.85)*CFrame.Angles(q*1.85-recoil*2.1,0,q*.65-(kind=='Crowbar' and .3 or 0)))
  end
 end
 for p,r in pairs(self.held) do if not p.Parent then r.model:Destroy();self.held[p]=nil end end
 for i=#self.chips,1,-1 do
  local c=self.chips[i]
  if now>=c.expires then c.part:Destroy();table.remove(self.chips,i)
  else
   local q=(now-c.at)/(c.expires-c.at)
   if c.pose then
    local t=math.max(0,now-c.at-.075)
    local center=c.pose.Position+c.velocity*((1-math.exp(-3*t))/3)
    local height=math.max(c.floor,center.Y+c.rise*t-19*t*t)
    local rotation=math.min(t,.38)
    c.part.CFrame=CFrame.new(center.X,height,center.Z)*c.pose.Rotation*CFrame.Angles(c.spin.X*rotation,0,c.spin.Z*rotation)
   end
   c.part.Transparency=math.clamp((q-.65)/.35,0,1)
  end
 end
end
function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for _,slot in ipairs(self.slots) do if slot.model then slot.model:Destroy() end end
 for _,r in pairs(self.world) do r.model:Destroy() end
 for _,r in pairs(self.held) do r.model:Destroy() end
 for _,c in ipairs(self.chips) do c.part:Destroy() end
 self.gui:Destroy();self.use:Destroy()
 if self.oldBackpack~=nil then pcall(function() game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,self.oldBackpack) end) end
end
return V
