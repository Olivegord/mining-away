-- The drone yard adds intent controls to the existing HUD; gameplay remains server-owned.
local View={}
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local function units(bag)
 local total=0;for _,value in pairs(type(bag)=='table' and bag or {}) do if type(value)=='number' then total=total+value end end;return total
end
local function compact(value)
 value=tonumber(value) or 0
 if value>=1e6 then return string.format('%.1fM',value/1e6) elseif value>=10000 then return string.format('%.1fk',value/1000) end
 return tostring(math.floor(value))
end
function View.start(ctx)
 local self: any={selected=nil,tab='Drones',loadCarrier=nil,draft={},open=false,connections={},visuals={},scanAt=0,message='',messageUntil=0}
 local U=ctx.interface;local C=U.palette;local root=ctx.parent;local player=Players.LocalPlayer
 local function profile() return ctx.profile() or {} end
 local function owned() return profile().logistics or {} end
 local function run() local p=profile();return p.run and p.run.logistics or {} end
 local function send(action,value)
  local p=profile();if not p.run or p.pendingTransaction then self.message='Wait for your current save to finish.';self.messageUntil=os.clock()+5;if ctx.notify then ctx.notify(self.message) end;return end
  ctx.command:FireServer(action,value)
 end
 local function say(message) self.message=message;self.messageUntil=os.clock()+5;if ctx.notify then ctx.notify(message) end end
 local function carrier(id)
  for _,record in ipairs(owned().carriers or {}) do if record.id==id then return record end end;return nil
 end
 local function state(id)
  local folder=player:FindFirstChild('MA_Logistics');local record=folder and folder:FindFirstChild(id)
  if record then return record:GetAttribute('State') or 'Home' end
  local published=profile().logisticsStates or {}
  local value=published[id]
  if type(value)=='table' then return value.state or value.State or 'Home' elseif type(value)=='string' then return value end
  return 'Home'
 end
 local function setOpen(value)
  self.open=value==true
  if self.layer then self.layer.Visible=self.open end
  if self.open and ctx.onOpen then ctx.onOpen() end
  if ctx.onVisibility then ctx.onVisibility() end
 end
 local trigger=U.button(root,UDim2.fromOffset(0,96),UDim2.fromOffset(100,36),'Drones [O]',function()
  if units(run().storage)>=(profile().storageCapacity or 120) then self.tab='Storage' end
  setOpen(not self.open)
 end,C.accent)
 trigger.Name='OpenDroneYard';trigger.TextSize=15
 local targetCycle=U.button(root,UDim2.fromOffset(0,138),UDim2.fromOffset(100,36),'Fleet',function() self:cycle() end,C.accent)
 targetCycle.Name='CarrierTargetCycle';targetCycle.TextSize=15;targetCycle.Visible=false
 local carrierReturn=U.button(root,UDim2.fromOffset(0,180),UDim2.fromOffset(100,36),'Return carrier',function() self:recall() end,C.mineral)
 carrierReturn.Name='RecallSelectedCarrier';carrierReturn.TextSize=14;carrierReturn.Visible=false
 local bar=U.panel(root,UDim2.fromOffset(12,0),UDim2.fromOffset(360,42),C.panel,10);bar.Name='CarrierToolbar';bar.Visible=false
 local strip=Instance.new('ScrollingFrame');strip.BackgroundTransparency=1;strip.BorderSizePixel=0;strip.Position=UDim2.fromOffset(5,4);strip.Size=UDim2.new(1,-10,1,-8);strip.ScrollBarThickness=2;strip.ScrollingDirection=Enum.ScrollingDirection.X;strip.CanvasSize=UDim2.fromOffset(0,0);strip.Active=true;strip.ZIndex=bar.ZIndex+2;strip.Parent=bar
 local layer=U.frame(root,UDim2.fromScale(0,0),UDim2.fromScale(1,1),C.ink);layer.Name='DroneYardLayer';layer.BackgroundTransparency=1;layer.Visible=false;layer.Active=true;layer.ZIndex=70
 self.layer=layer
 local backdrop=Instance.new('TextButton');backdrop.Size=UDim2.fromScale(1,1);backdrop.BackgroundColor3=C.ink;backdrop.BackgroundTransparency=.3;backdrop.Text='';backdrop.AutoButtonColor=false;backdrop.ZIndex=71;backdrop.Parent=layer
 table.insert(self.connections,backdrop.Activated:Connect(function() setOpen(false) end))
 local sheet=U.panel(layer,UDim2.fromOffset(12,12),UDim2.fromOffset(480,540),C.panel,18);sheet.Name='DroneYard';sheet.ZIndex=72
 local title=U.text(sheet,UDim2.fromOffset(18,12),UDim2.new(1,-88,0,32),'DRONE YARD',25,C.text,true)
 U.icon(sheet,'drone',UDim2.fromOffset(18,49),UDim2.fromOffset(24,24),C.accent)
 local balance=U.text(sheet,UDim2.fromOffset(50,48),UDim2.new(1,-68,0,24),'',14,C.muted,true)
 U.button(sheet,UDim2.new(1,-56,0,12),UDim2.fromOffset(40,40),'X',function() setOpen(false) end,C.danger)
 local tabs={};local body=Instance.new('ScrollingFrame');body.Name='YardContents';body.BackgroundTransparency=1;body.BorderSizePixel=0;body.Active=true;body.ScrollBarThickness=3;body.ScrollBarImageColor3=C.muted;body.ZIndex=sheet.ZIndex+2;body.Parent=sheet
 local foot=U.text(sheet,UDim2.fromOffset(18,0),UDim2.new(1,-36,0,37),'Buy and load at the depot. Your permanent fleet stays with you.',13,C.muted)
 local width,height,contentWidth=480,540,444
 local signature='';local barSignature='';local purchases={};local launch,auto,storageSummary=nil,nil,nil
 local render
 local function chooseCarrier(id)
  self.loadCarrier=id;self.draft={}
  local record=carrier(id);for _,droneId in ipairs(record and record.droneIds or {}) do self.draft[droneId]=true end
 end
 local function row(y,h)
  return U.panel(body,UDim2.fromOffset(0,y),UDim2.fromOffset(contentWidth,h),C.paper,12)
 end
 local function text(parent,x,y,w,h,value,size,color)
  return U.text(parent,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),value,size or 15,color or C.text,true)
 end
 local function purchase(action,key)
  if action=='BuyCarrier' and #(owned().carriers or {})>=3 then say('Your yard already has three carriers.');return end
  send(action,key)
 end
 local function shopCard(y,name,description,price,color,duration,action,key,alreadyOwned)
  local cardHeight=contentWidth<340 and 178 or 154
  local card=row(y,cardHeight)
  local preview=action=='BuyDrone' and player:GetAttribute('MA_DevToolsEnabled')==true
  U.icon(card,'drone',UDim2.fromOffset(12,12),UDim2.fromOffset(32,32),color)
  text(card,54,10,contentWidth-(preview and 152 or 68),28,name,19)
  if preview then U.button(card,UDim2.fromOffset(contentWidth-86,8),UDim2.fromOffset(72,36),'Preview',function() send('DevAddDrone',{role=key});say(name..' added to the temporary test crew.');setOpen(false) end,C.paper).TextSize=14 end
  U.text(card,UDim2.fromOffset(14,46),UDim2.fromOffset(contentWidth-28,cardHeight-96),description,15,C.muted)
  text(card,14,cardHeight-39,contentWidth-150,28,duration and string.format('%.1fs • whole rock',duration) or 'Permanent equipment',13,color)
  local b=U.button(card,UDim2.fromOffset(contentWidth-136,cardHeight-44),UDim2.fromOffset(122,36),alreadyOwned and 'Owned' or compact(price)..' Quartz',function() purchase(action,key) end,color)
  b.TextSize=15;table.insert(purchases,{button=b,price=price,owned=alreadyOwned})
  return cardHeight
 end
 for index,name in ipairs({'Drones','Transport','Storage'}) do
  tabs[name]=U.button(sheet,UDim2.fromOffset(0,82),UDim2.fromOffset(130,36),name,function() self.tab=name;signature='' end,name=='Drones' and C.accent or C.paper)
  tabs[name].LayoutOrder=index
 end
 render=function()
  for _,child in ipairs(body:GetChildren()) do child:Destroy() end
  purchases={};launch=nil;auto=nil;storageSummary=nil
  for name,b in pairs(tabs) do U.skin(b,name==self.tab and C.accent or C.paper,11,.92) end
  if self.tab=='Drones' then
   local y=0
   for _,key in ipairs(DroneCatalog.Order) do
    local entry=DroneCatalog.Types[key]
    if key~='Laser' then
     y=y+shopCard(y,entry.Name,entry.Description,entry.Price,Color3.fromRGB(unpack(entry.Color)),entry.Duration,'BuyDrone',key,false)+8
    end
   end
   body.CanvasSize=UDim2.fromOffset(0,y)
  elseif self.tab=='Storage' then
   local card=row(0,160)
   text(card,14,10,contentWidth-28,28,'ORBITAL STORAGE',19,C.accent)
   storageSummary=U.text(card,UDim2.fromOffset(14,42),UDim2.fromOffset(contentWidth-28,62),'',16,C.text,true)
   launch=U.button(card,UDim2.fromOffset(14,112),UDim2.fromOffset(contentWidth-28,38),'Launch full storage [L]',function() send('LaunchStorage') end,C.mineral)
   U.button(body,UDim2.fromOffset(0,170),UDim2.fromOffset(contentWidth,40),'Deposit backpack [U]',function() send('Deposit') end,C.accent)
   auto=U.button(body,UDim2.fromOffset(0,220),UDim2.fromOffset(contentWidth,40),'Auto-launch: OFF',function()
    if (owned().launches or 0)==0 then say('Launch your first full capsule at the depot to unlock automatic launches.');return end
    send('AutoLaunch',not owned().autoLaunch)
   end,C.paper)
   local helpHeight=contentWidth<340 and 180 or 128
   U.text(body,UDim2.fromOffset(4,272),UDim2.fromOffset(contentWidth-8,helpHeight),'Ore keeps its mineral type. Deposit it into storage, then launch a full capsule to receive those currencies after liftoff. Carriers send ore to storage; the flying backpack fetches your full bag. Opt into auto-launch after your first launch for an unattended outpost.',15,C.muted)
   body.CanvasSize=UDim2.fromOffset(0,282+helpHeight)
  else
   local first=shopCard(0,'Carrier • four bays','Choose four permanent miners, send the carrier to a cleared field, and leave them working.',1500,C.accent,nil,'BuyCarrier',nil,false)
   local second=shopCard(first+8,'Flying Backpack','A flying backpack companion picks up your full bag and carries it to storage.',750,C.mineral,nil,'BuyBackpack',nil,owned().backpack==true)
   local y=first+second+16
   local records=owned().carriers or {}
   if not carrier(self.loadCarrier) then chooseCarrier(self.selected or (records[1] and records[1].id)) end
   text(body,4,y,contentWidth-8,28,'CARRIER LOADOUT • FOUR MINERS',16,C.accent);y=y+34
   if #records==0 then
    U.text(body,UDim2.fromOffset(4,y),UDim2.fromOffset(contentWidth-8,58),'Buy a carrier above to choose its miners. Carrier missions work in safe or cleared fields.',15,C.muted);y=y+64
   else
    for index,record in ipairs(records) do
     U.button(body,UDim2.fromOffset(0,y),UDim2.fromOffset(contentWidth,38),'Carrier '..index..' • '..state(record.id)..(record.id==self.loadCarrier and ' ✓' or ''),function() self.selected=record.id;chooseCarrier(record.id);signature='';barSignature='' end,record.id==self.loadCarrier and C.accent or C.paper);y=y+45
    end
    local count=0;for _ in pairs(self.draft) do count=count+1 end
    text(body,4,y,contentWidth-8,26,string.format('%d / 4 bays selected • edit at the depot',count),14,C.muted);y=y+32
    for _,drone in ipairs(profile().fleet or {}) do
     local role=drone.role or drone.type
     if role=='Striker' or role=='Charger' or DroneCatalog.Types[role] then
      local id=drone.id;local elsewhere=false
      for _,record in ipairs(records) do if record.id~=self.loadCarrier and table.find(record.droneIds or {},id) then elsewhere=true end end
      local entry=DroneCatalog.Types[role];local tint=entry and Color3.fromRGB(unpack(entry.Color)) or C.mineral
      U.button(body,UDim2.fromOffset(0,y),UDim2.fromOffset(contentWidth,40),(self.draft[id] and '✓ ' or '+ ')..drone.name..(elsewhere and ' • other carrier' or ''),function()
       if elsewhere then say('Unload this miner from its other carrier first.');return end
       if self.draft[id] then self.draft[id]=nil
       else local n=0;for _ in pairs(self.draft) do n=n+1 end;if n>=4 then say('A carrier has four bays. Remove a miner first.');return end;self.draft[id]=true end
       signature=''
      end,self.draft[id] and tint or C.paper);y=y+47
     end
    end
    U.button(body,UDim2.fromOffset(0,y+4),UDim2.fromOffset(contentWidth,40),'Save carrier loadout',function()
     if state(self.loadCarrier)~='Home' then say('Recall this carrier and wait for it to reach the depot before changing its miners.');return end
     local ids={};for id in pairs(self.draft) do table.insert(ids,id) end;table.sort(ids)
     send('LoadCarrier',{carrierId=self.loadCarrier,droneIds=ids})
    end,C.mineral);y=y+52
   end
   body.CanvasSize=UDim2.fromOffset(0,y)
  end
 end
 function self:isOpen() return self.open end
 function self:toggle() setOpen(not self.open) end
 function self:close() setOpen(false) end
 function self:cycle()
  local records=owned().carriers or {};local index=1
  for i,record in ipairs(records) do if record.id==self.selected then index=i+1 end end
  self.selected=records[index] and records[index].id or nil;barSignature=''
 end
 function self:dispatchField(fieldId)
  if not self.selected then return false end
  local record=carrier(self.selected)
  if not record or #(record.droneIds or {})==0 then say('Load miners in Drone yard → Transport before deploying this carrier.');return true end
  send('CarrierPatch',{carrierId=self.selected,patch=fieldId});return true
 end
 function self:recall()
  if not self.selected then return false end;send('RecallCarrier',self.selected);return true
 end
 function self:update(view,fighting)
  if ctx.hidden() and self.open then setOpen(false) end
  layer.Visible=self.open;trigger.Visible=not ctx.hidden();bar.Visible=not ctx.hidden() and not self.open and #(owned().carriers or {})>0
  local touch=UIS.TouchEnabled;local short=view.Y<400
  trigger.Position=UDim2.fromOffset(view.X-112,96);trigger.Size=UDim2.fromOffset(100,36)
  local stored=units(run().storage);local capacity=profile().storageCapacity or 120
  trigger.Text=stored>=capacity and 'Storage full' or touch and 'Drone yard' or 'Drones [O]'
  trigger.Visible=trigger.Visible and not (short and fighting)
  local w=math.min(490,view.X-24);local h=math.min(568,view.Y-24)
  if w~=width or h~=height then
   width=w;height=h;contentWidth=w-36;signature=''
   sheet.Size=UDim2.fromOffset(w,h);sheet.Position=UDim2.fromOffset((view.X-w)/2,(view.Y-h)/2)
   title.Size=UDim2.new(1,-88,0,32);balance.Size=UDim2.new(1,-68,0,24)
   for i,name in ipairs({'Drones','Transport','Storage'}) do tabs[name].Position=UDim2.fromOffset(14+(i-1)*(w-28)/3,82);tabs[name].Size=UDim2.fromOffset((w-28)/3-6,36) end
   local footerHeight=contentWidth<340 and 52 or 37
   body.Position=UDim2.fromOffset(14,128);body.Size=UDim2.fromOffset(w-28,math.max(32,h-128-footerHeight-20))
   foot.Position=UDim2.fromOffset(18,h-footerHeight-11);foot.Size=UDim2.new(1,-36,0,footerHeight)
  end
  local p=profile();local wallet=p.run and p.run.wallet or {};balance.Text=compact(wallet.Quartz or 0)..' Quartz • purchases at the depot'
  local key={self.tab,tostring(w),tostring(h),tostring(owned().backpack),tostring(#(p.fleet or {})),tostring(self.loadCarrier),tostring(p.run and p.run.id),tostring(player:GetAttribute('MA_DevToolsEnabled'))}
  for _,record in ipairs(owned().carriers or {}) do table.insert(key,record.id..':'..state(record.id)..':'..table.concat(record.droneIds or {},',')) end
  for id in pairs(self.draft) do table.insert(key,id) end;table.sort(key)
  local current=table.concat(key,'|')
  if self.open and signature~=current then local scroll=body.CanvasPosition;signature=current;render();body.CanvasPosition=scroll end
  for _,item in ipairs(purchases) do U.setEnabled(item.button,not item.owned and not p.pendingTransaction and (wallet.Quartz or 0)>=item.price) end
  if storageSummary then
   local cargo=units(run().launchCargo);local hauler=units(run().backpackCargo)
   storageSummary.Text=compact(stored)..' / '..compact(capacity)..' ore stored'..(cargo>0 and string.format('\n%s in orbit • %.1fs',compact(cargo),run().launchRemaining or 0) or hauler>0 and '\nFlying backpack: '..compact(hauler)..' ore' or '\nFull capsules become mineral currency.')
   launch.Text=cargo>0 and 'Capsule in flight…' or stored>=capacity and 'Launch ready [L]' or 'Fill storage to launch'
   U.setEnabled(launch,stored>=capacity and cargo==0 and not p.pendingTransaction)
   auto.Text='Auto-launch: '..(owned().autoLaunch and 'ON' or 'OFF')
  end
  if self.selected and not carrier(self.selected) then self.selected=nil end
  local keys={tostring(self.selected)}
  for _,record in ipairs(owned().carriers or {}) do table.insert(keys,record.id..':'..state(record.id)..':'..#(record.droneIds or {})) end
  local nextBar=table.concat(keys,'|')
  if nextBar~=barSignature then
   barSignature=nextBar;for _,child in ipairs(strip:GetChildren()) do child:Destroy() end
   U.button(strip,UDim2.fromOffset(0,0),UDim2.fromOffset(80,34),'Fleet',function() self.selected=nil;barSignature='' end,not self.selected and C.mineral or C.paper)
   local x=87
   for i,record in ipairs(owned().carriers or {}) do
    U.button(strip,UDim2.fromOffset(x,0),UDim2.fromOffset(126,34),string.format('Carrier %d • %d/4',i,#(record.droneIds or {})),function() self.selected=record.id;chooseCarrier(record.id);barSignature='' end,self.selected==record.id and C.accent or C.paper);x=x+133
   end
   strip.CanvasSize=UDim2.fromOffset(x,0)
  end
  local anchor=view.Y-(touch and 108 or 12)
  if ctx.dock and ctx.dock.Visible then anchor=math.min(anchor,ctx.dock.Position.Y.Offset) end
  if ctx.context and ctx.context.Visible then anchor=math.min(anchor,ctx.context.Position.Y.Offset) end
  bar.Size=UDim2.fromOffset(math.min(500,view.X-24),42);bar.Position=UDim2.fromOffset((view.X-bar.Size.X.Offset)/2,anchor-50)
  local compactTarget=anchor-50<138
  if compactTarget then bar.Visible=false end
  targetCycle.Visible=compactTarget and not ctx.hidden() and not self.open and #(owned().carriers or {})>0
  targetCycle.Position=UDim2.fromOffset(view.X-112,138)
  targetCycle.Text='Fleet'
  for index,record in ipairs(owned().carriers or {}) do if record.id==self.selected then targetCycle.Text='Carrier '..index;break end end
  carrierReturn.Visible=self.selected~=nil and not ctx.hidden() and not self.open
  carrierReturn.Position=UDim2.fromOffset(view.X-112,targetCycle.Visible and 180 or 138)
  sheet.Position=UDim2.fromOffset((view.X-w)/2,(view.Y-h)/2)
  foot.Text=os.clock()<self.messageUntil and self.message or self.selected and 'Carrier selected • click a field to deploy • [R] returns it • [C] changes target' or 'Buy and load at the depot. Your permanent fleet stays with you.'
 end
 -- All players render the same authoritative logistics poses through local clones.
 function self:step(now,dt)
  if self.selected and not self.open and not ctx.hidden() and now>=(self.hoverAt or 0) then
   self.hoverAt=now+.06
   local fieldId=nil
   local published=profile().logisticsStates or {};local selected=published[self.selected]
   if type(selected)=='table' then fieldId=selected.field end
   if UIS.MouseEnabled and not UIS:GetFocusedTextBox() then
    local pointer=UIS:GetMouseLocation();local camera=workspace.CurrentCamera
    if camera and (not ctx.blocks or not ctx.blocks(pointer)) then
     local ray=camera:ScreenPointToRay(pointer.X,pointer.Y);local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={ctx.localFX,player.Character}
     local hit=workspace:Raycast(ray.Origin,ray.Direction*300,params);local node=hit and hit.Instance
     while node and node~=workspace do fieldId=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier') or fieldId;node=node.Parent end
    end
   end
   local floor=nil;local fields=ctx.world:FindFirstChild('Fields')
   if fields then for _,field in ipairs(fields:GetChildren()) do if (field:GetAttribute('FieldId') or field:GetAttribute('Tier'))==fieldId then floor=field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor');break end end end
   if not self.fieldMark then self.fieldMark=Instance.new('Highlight');self.fieldMark.Name='CarrierFieldOrder';self.fieldMark.DepthMode=Enum.HighlightDepthMode.Occluded;self.fieldMark.FillColor=C.accent;self.fieldMark.OutlineColor=C.accent;self.fieldMark.FillTransparency=.92;self.fieldMark.OutlineTransparency=.08;self.fieldMark.Parent=ctx.localFX end
   self.fieldMark.Adornee=floor;self.fieldMark.Enabled=floor~=nil
  elseif (not self.selected or self.open or ctx.hidden()) and self.fieldMark then self.fieldMark.Enabled=false end
  if now>=self.scanAt then
   self.scanAt=now+.2
   for _,source in ipairs(ctx.world:GetChildren()) do
    local class=source:GetAttribute('Class')
    local previous=self.visuals[source]
    if previous and previous.geometryDirty then
     for _,connection in ipairs(previous.connections) do connection:Disconnect() end
     previous.view:Destroy();for node,value in pairs(previous.hidden) do if node.Parent then node.LocalTransparencyModifier=value end end;self.visuals[source]=nil
    end
    if source:IsA('Model') and (class=='Carrier' or class=='Backpack' or class=='Capsule') and not self.visuals[source] and source:GetAttribute('Pose') then
     local clone=source:Clone();clone.Name='View_'..source.Name
     for _,node in ipairs(clone:GetDescendants()) do
      if node:IsA('LuaSourceContainer') or node:IsA('ProximityPrompt') or node:IsA('BillboardGui') then node:Destroy()
      elseif node:IsA('BasePart') then node.Anchored=true;node.CanCollide=false;node.CanTouch=false;node.CanQuery=false;node.LocalTransparencyModifier=0 end
     end
     clone.Parent=ctx.localFX;local hidden={}
     for _,node in ipairs(source:GetDescendants()) do if node:IsA('BasePart') then hidden[node]=node.LocalTransparencyModifier;node.LocalTransparencyModifier=1 end end
     local record={samples={},view=clone,pose=source:GetAttribute('Pose'),hidden=hidden,connections={},exhaust=clone:FindFirstChild('Exhaust',true),sourceExhaust=source:FindFirstChild('Exhaust',true)}
     local function changed() record.geometryDirty=true end
     table.insert(record.connections,source.DescendantAdded:Connect(changed));table.insert(record.connections,source.DescendantRemoving:Connect(changed))
     self.visuals[source]=record
    end
   end
  end
  for source,record in pairs(self.visuals) do
   if not source.Parent then
    for _,connection in ipairs(record.connections) do connection:Disconnect() end
    record.view:Destroy();self.visuals[source]=nil
   else
    local target=source:GetAttribute('Pose')
    if target then
     local reset=source:GetAttribute('Class')=='Capsule' and (source:GetAttribute('Manifest') or 0)==0
     MotionBuffer.push(record.samples,source:GetAttribute('PoseAt'),target,reset)
     record.pose=MotionBuffer.pose(record.samples,now) or target
     if record.drawnPose~=record.pose then record.view:PivotTo(record.pose);record.drawnPose=record.pose end
     local exhaust,original=record.exhaust,record.sourceExhaust
     if exhaust and original and exhaust:IsA('BasePart') then exhaust.Transparency=original.Transparency end
    end
   end
  end
 end
 function self:destroy()
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  for source,record in pairs(self.visuals) do
   for _,connection in ipairs(record.connections) do connection:Disconnect() end
   record.view:Destroy();if source.Parent then for node,value in pairs(record.hidden) do if node.Parent then node.LocalTransparencyModifier=value end end end
  end
  trigger:Destroy();targetCycle:Destroy();carrierReturn:Destroy();bar:Destroy();layer:Destroy()
  if self.fieldMark then self.fieldMark:Destroy() end
 end
 return self
end
return View
