-- Cosmetics and input only. No client damage, cargo, rewards, or authoritative movement.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local TweenService=game:GetService('TweenService')
local UIS=game:GetService('UserInputService')
local pl=Players.LocalPlayer
local world=workspace:WaitForChild('MiningAwayV2')
local command=RS:WaitForChild('MiningAwayV2'):WaitForChild('Command')
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.Parent=pl:WaitForChild('PlayerGui')
local historicalGUI={ScreenGui=true,IngameGui=true,lowPolyUI=true}
local function isolateGUI(g) if g:IsA('ScreenGui') and historicalGUI[g.Name] then g.Enabled=false end end
for _,g in ipairs(gui.Parent:GetChildren()) do isolateGUI(g) end
gui.Parent.ChildAdded:Connect(isolateGUI)
-- Standard Roblox camera is restored after the historical custom controllers are isolated.
local function camera(ch)
 local h=ch:WaitForChild('Humanoid',10)
 if h then workspace.CurrentCamera.CameraType=Enum.CameraType.Custom;workspace.CurrentCamera.CameraSubject=h end
end
pl.CharacterAdded:Connect(camera);if pl.Character then task.spawn(camera,pl.Character) end
local panel=Instance.new('Frame');panel.Size=UDim2.new(0,350,0,300);panel.Position=UDim2.new(0,16,0,16);panel.BackgroundColor3=Color3.fromRGB(14,21,33);panel.BackgroundTransparency=.1;panel.Parent=gui
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=panel
local function text(y,height,size)
 local t=Instance.new('TextLabel');t.Position=UDim2.fromOffset(14,y);t.Size=UDim2.new(1,-28,0,height);t.BackgroundTransparency=1;t.TextColor3=Color3.fromRGB(224,240,250);t.TextSize=size;t.Font=Enum.Font.Gotham;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextWrapped=true;t.Parent=panel;return t
end
text(10,26,20).Text='MINING AWAY'
local stats=text(40,42,15);local objective=text(86,46,13);local status=text(138,40,13)
local function button(label,x,y,width,fn)
 local b=Instance.new('TextButton');b.Text=label;b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(width,30);b.BackgroundColor3=Color3.fromRGB(41,73,92);b.TextColor3=Color3.new(1,1,1);b.TextSize=12;b.Font=Enum.Font.GothamBold;b.Parent=panel;b.Activated:Connect(fn);return b
end
button('Recall [R]',14,186,100,function() command:FireServer('Recall') end)
button('Sell at home [E]',122,186,210,function() command:FireServer('Sell') end)
local power=button('Power',14,224,155,function() command:FireServer('Upgrade','power') end)
local hull=button('Hull',177,224,155,function() command:FireServer('Upgrade','hull') end)
text(262,28,11).Text='Walk to a patch → click it or press 1 / 2 / 3.\nCo-op: join during the 4-second muster.'
local costs={120,320,800,1800}
UIS.InputBegan:Connect(function(input,processed)
 if processed then return end
 local k=input.KeyCode
 if k==Enum.KeyCode.R then command:FireServer('Recall') elseif k==Enum.KeyCode.E then command:FireServer('Sell')
 elseif k==Enum.KeyCode.One then command:FireServer('Patch',1) elseif k==Enum.KeyCode.Two then command:FireServer('Patch',2) elseif k==Enum.KeyCode.Three then command:FireServer('Patch',3) end
end)
pl:GetMouse().Button1Down:Connect(function()
 local target=pl:GetMouse().Target
 while target and target~=workspace do
  local id=target:GetAttribute('Patch') or target:GetAttribute('Tier')
  if id then command:FireServer('Patch',id);return end
  target=target.Parent
 end
end)
local cosmetic=Instance.new('Folder');cosmetic.Name='MiningAwayLocalFX';cosmetic.Parent=workspace
local tracked,emitters,pending,cracks={},{},{},{}
local displayPoses={}
local budget=0
local function burst(part,color,n)
 if budget>=48 then return end
 for i=1,math.min(n,48-budget) do
  budget=budget+1
  local p=Instance.new('Part');p.Size=Vector3.new(.18,.18,.5);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Material=Enum.Material.Neon;p.Color=color;p.CFrame=part.CFrame;p.Parent=cosmetic
  local v=Vector3.new(math.random(-6,6),math.random(3,9),math.random(-6,6))
  TweenService:Create(p,TweenInfo.new(.45),{Position=p.Position+v,Transparency=1,Size=Vector3.new(.05,.05,.05)}):Play()
  task.delay(.5,function() p:Destroy();budget=budget-1 end)
 end
end
local observe
observe=function(v)
 if not v.Parent then return end
 if v:IsA('BasePart') and v.Name=='Endpoint' then
  local m=v.Parent
  while m and m~=world do
   if displayPoses[m] then table.insert(displayPoses[m].endpoints,v);break end
   m=m.Parent
  end
 end
 if v:IsA('BasePart') and not v:GetAttribute('Resource') and not pending[v] then
  pending[v]=v:GetAttributeChangedSignal('Resource'):Connect(function()
   if v:GetAttribute('Resource') then pending[v]:Disconnect();pending[v]=nil;observe(v) end
  end)
 elseif v:IsA('Beam') and not v.Attachment1 and not pending[v] then
  pending[v]=v:GetPropertyChangedSignal('Attachment1'):Connect(function()
   if v.Attachment1 then pending[v]:Disconnect();pending[v]=nil;observe(v) end
  end)
 end
 if v:IsA('BasePart') and v:GetAttribute('Resource') and not tracked[v] then
  local baseColor=v.Color
  local highlight=Instance.new('Highlight');highlight.FillTransparency=1;highlight.OutlineTransparency=1;highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Parent=v
  local last=-1
  cracks[v]={}
  local lastBreak=v:GetAttribute('BreakSerial') or 0
  local function changed()
   local fracture=v:GetAttribute('Fracture') or 0
   if fracture~=last then
    local previous=last;last=fracture
    for _,c in ipairs(cracks[v]) do c:Destroy() end;cracks[v]={}
    if v.Name=='GeodeShell' then
     for i=1,fracture do
      local c=Instance.new('Part');c.Name='Fracture';c.Anchored=true;c.CanCollide=false;c.CanQuery=false;c.CanTouch=false;c.Size=Vector3.new(.07,3.8,.07);c.Material=Enum.Material.Neon;c.Color=Color3.fromRGB(190,155,255)
      c.CFrame=v.CFrame*CFrame.new((i-2)*1.15,0,-v.Size.Z*.45)*CFrame.Angles(0,0,(i-2)*.45);c.Parent=cosmetic;table.insert(cracks[v],c)
     end
    end
    v.Color=baseColor:Lerp(Color3.new(1,1,1),fracture*.12);highlight.OutlineColor=Color3.new(1,1,1);highlight.OutlineTransparency=1-fracture*.22
    if previous>=0 then burst(v,baseColor,2) end
   end
   local b=v:GetAttribute('BreakSerial') or 0
   if b>lastBreak then
    lastBreak=b;burst(v,baseColor,8)
    for _,c in ipairs(cracks[v]) do c:Destroy() end;cracks[v]={}
    if budget<40 then local sound=Instance.new('Sound');sound.SoundId='rbxasset://sounds/electronicpingshort.wav';sound.Volume=.12;sound.PlaybackSpeed=v.Name=='GeodeShell' and .75 or 1.3;sound.Parent=v;sound:Play();game:GetService('Debris'):AddItem(sound,1) end
   end
  end
  tracked[v]={v.AttributeChanged:Connect(changed)};changed()
 elseif v:IsA('Beam') and v.Parent.Name=='MiningEmitter' then
  -- One emitter for both beam layers, no extra lights or impact parts.
  local attachment=v.Attachment1
  if attachment and not emitters[attachment] then
   local e=Instance.new('ParticleEmitter');e.Texture='rbxasset://textures/particles/sparkles_main.dds';e.Rate=0;e.Lifetime=NumberRange.new(.12,.25);e.Speed=NumberRange.new(2,5);e.SpreadAngle=Vector2.new(80,80);e.LightEmission=1;e.Size=NumberSequence.new(.15);e.Color=ColorSequence.new(Color3.fromRGB(110,235,255));e.Parent=attachment
   emitters[attachment]={particle=e,beam=v}
  end
 end
end
world.DescendantAdded:Connect(function(v) task.defer(observe,v) end)
for _,v in ipairs(world:GetDescendants()) do observe(v) end
world.DescendantRemoving:Connect(function(v)
 if pending[v] then pending[v]:Disconnect();pending[v]=nil end
 if cracks[v] then for _,c in ipairs(cracks[v]) do c:Destroy() end;cracks[v]=nil end
 if tracked[v] then for _,c in ipairs(tracked[v]) do c:Disconnect() end;tracked[v]=nil end
 if emitters[v] then emitters[v].particle:Destroy();emitters[v]=nil end
end)
-- Interpolation is cosmetic: poses originate on the server; server targeting never reads these local transforms.
RunService.RenderStepped:Connect(function(dt)
 for model,data in pairs(displayPoses) do
  local target=model:GetAttribute('Pose')
  if model.Parent and target then
   local state=model:GetAttribute('State')
   data.pose=(state=='Destroyed' or state=='Reprinting') and target or data.pose:Lerp(target,1-math.exp(-18*dt))
   local endpoints={}
   for _,v in ipairs(data.endpoints) do if v.Parent then endpoints[v]=v.Position end end
   model:PivotTo(data.pose)
   -- Beam targets stay in world space while the emitter follows the interpolated drone.
   for v,pos in pairs(endpoints) do v.Position=pos end
  else displayPoses[model]=nil end
 end
end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
 local ore=pl:GetAttribute('MA_Ore') or 0;local credits=pl:GetAttribute('MA_Credits') or 0
 stats.Text=string.format('%d / 2000 ORE    •    %d CREDITS',ore,credits)
 objective.Text=pl:GetAttribute('MA_Objective') or 'Preparing fleet...'
 local a=pl:GetAttribute('MA_Power') or 0;local b=pl:GetAttribute('MA_Hull') or 0
 power.Text=string.format('Power %d → %s',a,costs[a+1] and tostring(costs[a+1])..' cr' or 'MAX')
 hull.Text=string.format('Hull %d → %s',b,costs[b+1] and tostring(costs[b+1])..' cr' or 'MAX')
 local lines={};local now=workspace:GetServerTimeNow()
 for _,m in ipairs(world:GetChildren()) do
  if m:IsA('Model') and m:GetAttribute('Owner') and not displayPoses[m] then
   local endpoints={}
   for _,v in ipairs(m:GetDescendants()) do if v:IsA('BasePart') and v.Name=='Endpoint' then table.insert(endpoints,v) end end
   displayPoses[m]={pose=m:GetAttribute('Pose') or m:GetPivot(),endpoints=endpoints}
  end
  if m:IsA('Model') and m:GetAttribute('Owner')==pl.UserId then
   local at=m:GetAttribute('ReprintAt') or 0
   if at>now then table.insert(lines,string.format('Drone %s: free reprint %ds',tostring(m:GetAttribute('DroneId')),math.ceil(at-now))) end
  end
 end
 local nearest,dist=nil,math.huge
 local hr=pl.Character and pl.Character:FindFirstChild('HumanoidRootPart')
 for _,m in ipairs(world:GetChildren()) do
  if m:IsA('Model') and m:GetAttribute('Tier') then
   local floor=m:FindFirstChild('PatchFloor')
   local n=hr and floor and (hr.Position-floor.Position).Magnitude or math.huge
   if n<dist then nearest=m;dist=n end
  end
 end
 local hint='Fleet ready. Retreat spends its slot for this assault.'
 if nearest and dist<58 then
  local phase=nearest:GetAttribute('Phase');local remain=math.max(0,math.ceil((nearest:GetAttribute('PhaseEndsAt') or now)-now))
  hint=string.format('Patch %d • %s%s',nearest:GetAttribute('Tier'),phase or 'Loading', (phase=='Gathering' or phase=='Resetting' or phase=='Cleared') and ' • '..remain..'s' or '')
 end
 status.Text=#lines>0 and table.concat(lines,'\n') or hint
 local count=0
 for at,e in pairs(emitters) do
  if at.Parent and e.beam.Parent and e.beam.Enabled and count<32 then e.particle:Emit(1);count=count+1 end
 end
end)
