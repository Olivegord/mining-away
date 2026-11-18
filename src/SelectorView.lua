-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={Interaction=require('./FieldInteractionView')}
V.__index=V
local aimColor=Color3.fromRGB(139,160,178)
local previewColor=Color3.fromRGB(234,245,255)
local activeColor=Color3.fromRGB(255,147,61)
local clearColor=Color3.fromRGB(85,243,148)
local white=Color3.new(1,1,1)
local previewTime,flashTime=.26,.38

local function part(parent,name)
 local p=Instance.new('Part')
 p.Name=name;p.Anchored=true;p.Transparency=1;p.CastShadow=false
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=parent
 return p
end
local function surface(part,face,canvas)
 local gui=Instance.new('SurfaceGui')
 gui.Face=face;gui.CanvasSize=canvas;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
 gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.Enabled=false;gui.Parent=part
 return gui
end
local function frame(parent)
 local f=Instance.new('Frame')
 f.BorderSizePixel=0;f.Size=UDim2.fromScale(1,1);f.Parent=parent
 return f
end

local function outline(parent,name)
 local base=part(parent,name);base.Size=Vector3.one
 local gui=surface(base,Enum.NormalId.Top,Vector2.new(512,512))
 local edges={}
 for i=1,4 do
  local edge=frame(gui);edge.BackgroundColor3=previewColor
  edges[i]=edge
 end
 return {base=base,gui=gui,edges=edges}
end
local function showOutline(mark,point,width,color,lift)
 mark.gui.Enabled=point~=nil
 if not point then return end
 if mark.color~=color then
  for _,edge in ipairs(mark.edges) do edge.BackgroundColor3=color;edge.BackgroundTransparency=.22 end
  mark.color=color
 end
 if mark.point~=point then mark.base.Position=point+Vector3.yAxis*(lift or .11);mark.point=point end
 if mark.width~=width then
  mark.base.Size=Vector3.new(width,.02,width);mark.width=width
  local t=math.min(.24,.46/width)
  -- Two full edges and two inset edges meet flush without double-bright corners.
  mark.edges[1].Size=UDim2.fromScale(1,t)
  mark.edges[2].Position=UDim2.fromScale(0,1-t);mark.edges[2].Size=UDim2.fromScale(1,t)
  mark.edges[3].Position=UDim2.fromScale(0,t);mark.edges[3].Size=UDim2.fromScale(t,1-2*t)
  mark.edges[4].Position=UDim2.fromScale(1-t,t);mark.edges[4].Size=UDim2.fromScale(t,1-2*t)
 end
end
local function fill(parent,name)
 local base=part(parent,name)
 local gui=surface(base,Enum.NormalId.Top,Vector2.new(8,8))
 local face=frame(gui);face.BackgroundColor3=white
 return {base=base,gui=gui,face=face}
end
local function showFill(mark,point,width,opacity,color,lift)
 mark.gui.Enabled=point~=nil and opacity>0
 if not mark.gui.Enabled then return end
 if mark.point~=point then mark.base.Position=point+Vector3.yAxis*lift;mark.point=point end
 if mark.width~=width then mark.base.Size=Vector3.new(width,.02,width);mark.width=width end
 if mark.color~=color then mark.face.BackgroundColor3=color;mark.color=color end
 if mark.opacity~=opacity then mark.face.BackgroundTransparency=1-opacity;mark.opacity=opacity end
end
function V.new(options)
 return setmetatable({options=options,cues={}},V)
end
function V:aim(ray)
 local o=self.options
 local run=o.world.Map:FindFirstChild('CrystalRun')
 if not run or o.hidden() then return nil end
 local character=o.player.Character
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 if not hr then return nil end
 local filter=RaycastParams.new();filter.FilterType=Enum.RaycastFilterType.Exclude
 local ignore={character,o.parent}
 local drones=o.world:FindFirstChild('Drones')
 if drones then table.insert(ignore,drones) end
 local direction=ray.Direction*500
 local function bedFor(node)
  while node and node~=run do
   local zone=node.Parent
   if zone and zone.Parent==run then return zone:FindFirstChild('Field'),node end
   node=zone
  end
 end
 for _=1,12 do
  filter.FilterDescendantsInstances=ignore
  local hit=workspace:Raycast(ray.Origin,direction,filter)
  if not hit then return nil end
  local part=hit.Instance
  local bed,rootPart=bedFor(part)
  local leadId=bed and rootPart:GetAttribute('ResourceId')
  if leadId and (rootPart:GetAttribute('SealedDrop') or (rootPart:GetAttribute('BreakSerial') or 0)>0) then
   table.insert(ignore,rootPart)
   continue
  end
  if bed and (part==bed or leadId) then
   local position=leadId and (rootPart:GetAttribute('FullPosition') or rootPart.Position) or hit.Position
   local point,fieldWidth=Mining.fieldSelection(position,bed)
   if point then
    return point,bed:GetAttribute('FieldId'),leadId,Mining.selectorInRange(hr.Position,point),leadId and rootPart,fieldWidth
   end
   return nil
  end
  if part.CanCollide then return nil end
  table.insert(ignore,part)
 end
end

function V:inAcceptedPlot(id,rock,width)
 local player=self.options.player
 local pin=player:GetAttribute('MA_Selector')
 return rock and pin and player:GetAttribute('MA_SelectorField')==id
  and Mining.selectorContains(pin,(player:GetAttribute('MA_SelectorWidth') or width)*.5,
   rock:GetAttribute('FullPosition') or rock.Position)
end

function V:canReachStarterPlot()
 local o=self.options
 local run=o.world.Map:FindFirstChild('CrystalRun')
 local quartz=run and run:FindFirstChild('Quartz')
 local bed=quartz and quartz:FindFirstChild('Field')
 local character=o.player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if not bed or not root then return false end
 local localPosition=bed.CFrame:PointToObjectSpace(root.Position)
 local edge=bed.CFrame:PointToWorldSpace(Vector3.new(
  math.clamp(localPosition.X,-bed.Size.X*.5,bed.Size.X*.5),0,
  math.clamp(localPosition.Z,-bed.Size.Z*.5,bed.Size.Z*.5)))
 local point=Mining.fieldSelection(edge,bed)
 return point~=nil and Mining.selectorInRange(root.Position,point)
end
-- Aim at an object, rather than selecting whichever happens to be nearest.
function V:interactionScore(view,current)
 local camera=workspace.CurrentCamera;if not camera or not view or not view.Parent then return nil end
 local input=game:GetService('UserInputService')
 local point=input:GetMouseLocation()-game:GetService('GuiService'):GetGuiInset()
 if input:GetLastInputType()==Enum.UserInputType.Touch or input:GetLastInputType().Name:match('^Gamepad') then point=camera.ViewportSize*.5 end
 local screen,visible=camera:WorldToViewportPoint(view.Position)
 if not visible then return nil end
 local dx,dy=screen.X-point.X,screen.Y-point.Y
 local radius=32
 local score=(dx*dx+dy*dy)/(radius*radius)
 if current then
  -- Keep the target while moving the pointer from its body onto its button.
  local top=camera:WorldToViewportPoint(view.Position+Vector3.yAxis*(view.Size.Y*.5+.7))
  if math.abs(point.X-top.X)<=68 and point.Y>=top.Y-20 and point.Y<=screen.Y+16 then return -.1 end
 end
 return score<=1 and score or nil
end
function V:readyRock(resources)
 local previous=self.ready;self.ready=nil
 local root=self.options.player.Character and self.options.player.Character:FindFirstChild('HumanoidRootPart')
 if not root then return nil end
 local best=math.huge;local now=workspace:GetServerTimeNow()
 for _,r in pairs(resources) do
  local s=r.source
  if s:GetAttribute('OpenReady') and now>=(s:GetAttribute('ReadyAt') or 0)
   and s:GetAttribute('OpenOwner')==self.options.player.UserId and not s:GetAttribute('OpeningAt')
   and (s.Position-root.Position).Magnitude<=Mining.OPEN_REACH then
   local score=self:interactionScore(r.view,r==previous)
   if score and (score<best or score==best and (not self.ready or r.id<self.ready.id)) then
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={self.options.player.Character,self.options.parent}
    local hit=workspace:Raycast(root.Position,s.Position-root.Position,params)
    if not hit or hit.Instance==s then self.ready=r;best=score end
   end
  end
 end
 return self.ready
end
function V:readyPickup(records)
 local previous=self.pickupId;self.pickupId=nil;local best=math.huge
 for source,r in pairs(records) do
  if source.Parent and source:GetAttribute('Owner')==self.options.player.UserId
   and source:GetAttribute('ManualPickupReady') and not r.collectAt then
   local id=source:GetAttribute('PickupId')
   local score=self:interactionScore(r.view,id==previous)
   if score and (score<best or score==best and (not self.pickupId or id<self.pickupId)) then self.pickupId=id;best=score end
  end
 end
 return self.pickupId
end
function V:aimPreview(ray)
 local point,id,leadId,inRange,rock,fieldWidth=self:aim(ray)
 local profile=self.options.profile()
 if self.pending then return point~=nil end
 if not point or not id or not profile or not profile.run then
  self:cancelPreview()
  return false
 end
 if fieldWidth then
  self:cancelPreview()
  if not inRange then
   if self.options.notify then self.options.notify('Move closer to select that field.') end
   return true
  end
  local requestId=game:GetService('HttpService'):GenerateGUID(false)
  self.pending={draft={point=point,field=id,width=fieldWidth},at=os.clock(),requestId=requestId}
  self.options.command:FireServer('PlaceSelector',{fieldId=id,position=point,runId=profile.run.id,requestId=requestId})
  return true
 end
 local width=Workshop.selectorWidth(profile)
 if leadId and self:inAcceptedPlot(id,rock,width) then
  self:cancelPreview()
  self.options.command:FireServer('FocusResource',{resourceId=leadId,runId=profile.run.id,
   requestId=game:GetService('HttpService'):GenerateGUID(false)})
  return true
 end
 if not inRange then
  if self.options.notify then self.options.notify('Move closer to select that area.') end
  return true
 end
 local draft=self.draft
 if not draft or draft.field~=id or draft.point~=point or draft.leadId~=leadId
  or draft.runId~=profile.run.id or draft.width~=width then
  self.draft={point=point,field=id,width=width,leadId=leadId,runId=profile.run.id,
   character=self.options.player.Character,age=0}
 end
 return true
end
function V:confirm()
 local draft=self.draft
 if not draft then return false end
 if self.pending then return true end
 local profile=self.options.profile()
 if self.options.hidden() or not profile or not profile.run or profile.run.id~=draft.runId
  or Workshop.selectorWidth(profile)~=draft.width then
  self:cancelPreview()
  return true
 end
 local character=self.options.player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if character~=draft.character or not root or not Mining.selectorInRange(root.Position,draft.point) then
  self:cancelPreview()
  if self.options.notify then self.options.notify('Move closer to select that area.') end
  return true
 end
 local requestId=game:GetService('HttpService'):GenerateGUID(false)
 self.pending={draft=draft,at=os.clock(),requestId=requestId}
 self.options.command:FireServer('PlaceSelector',{fieldId=draft.field,position=draft.point,runId=draft.runId,
  leadId=draft.leadId,requestId=requestId})
 return true
end
function V:cancelPreview()
 local hadDraft=self.draft~=nil
 self.draft=nil
 if self.pending then self.pending.dismissed=true end
 return hadDraft
end
function V:reply(state)
 local pending=self.pending
 if not pending or pending.requestId~=state.requestId then return false end
 self.pending=nil
 if state.status=='accepted' and not pending.dismissed then
  self.draft=nil
  self.click=pending.draft;self.click.at=os.clock()
 end
 return true
end
function V:previewState()
 local draft=self.draft
 if not draft or self.options.hidden() then return nil,0,0 end
 local t=self.options.reducedMotion() and 1 or math.clamp(draft.age/previewTime,0,1)
 local expansion=1-(1-t)^3
 local lowFlash=self.options.player:GetAttribute('ReducedFlashing')==true
 return draft,math.max(1,draft.width*expansion),(lowFlash and .18 or .31)*expansion
end
function V:flashState()
 local click=self.click
 if not click or self.options.hidden() then return nil,0 end
 local age=os.clock()-click.at
 if age>=flashTime then return nil,0 end
 local peak=self.options.player:GetAttribute('ReducedFlashing')==true and .29 or .68
 return click,peak*(1-math.clamp((age-.045)/(flashTime-.045),0,1))
end
function V:step(dt,aimRay)
 local o=self.options
 local profile=o.profile()
 local visible=profile and not o.hidden()
 local pin=profile and not (o.hidePin or o.hidden)() and o.player:GetAttribute('MA_Selector') or nil
 if not self.activeFloor and profile and o.world.Map:FindFirstChild('CrystalRun') then
  self.flash=fill(o.parent,'SelectorClickFill')
  self.previewEdge=outline(o.parent,'SelectorPreviewOutline')
  self.aimEdge=outline(o.parent,'SelectorAimOutline')
  self.previewFloor=fill(o.parent,'SelectorPreviewFill')
  self.activeEdge=outline(o.parent,'SelectorOutline')
  self.activeFloor=fill(o.parent,'SelectorFootprint')
 end
 if not self.activeFloor then return end
 local width=profile and Workshop.selectorWidth(profile) or 0
 if self.pending and os.clock()-self.pending.at>3 then self.pending=nil end
 local draft=self.draft
 if draft then
  local character=o.player.Character
  local root=character and character:FindFirstChild('HumanoidRootPart')
  if not visible or not profile.run or profile.run.id~=draft.runId or width~=draft.width
   or character~=draft.character or not root or not Mining.selectorInRange(root.Position,draft.point) then
   self:cancelPreview()
  else draft.age=math.min(previewTime,draft.age+dt) end
 end
 if not visible or not aimRay then
  self.hoverPoint=nil;self.hoverId=nil;self.aimAt=nil
 elseif os.clock()>=(self.aimAt or 0) then
  self.aimAt=os.clock()+.05
  local point,id,leadId,inRange,rock,fieldWidth=self:aim(aimRay)
  self.hoverWidth=fieldWidth or width
  local focus=not fieldWidth and leadId and self:inAcceptedPlot(id,rock,width)
  self.hoverId=not fieldWidth and (focus or inRange) and leadId or nil
  self.hoverPoint=inRange and not focus and point or nil
 end
 local color=o.player:GetAttribute('MA_SelectorCleared') and clearColor or activeColor
 local lowFlash=o.player:GetAttribute('ReducedFlashing')==true
 local pinWidth=o.player:GetAttribute('MA_SelectorWidth') or width
 local click,flashStrength=self:flashState()
 showOutline(self.activeEdge,pin,pinWidth,color)
 showFill(self.activeFloor,pin,pinWidth,lowFlash and .13 or .19,white,.04)
 local preview,previewWidth,strength=self:previewState()
 showOutline(self.previewEdge,preview and preview.point,previewWidth,previewColor,.13)
 showOutline(self.aimEdge,not preview and self.hoverPoint~=pin and self.hoverPoint or nil,self.hoverWidth or width,aimColor,.095)
 showFill(self.previewFloor,preview and preview.point,previewWidth,strength*.62,white,.065)
 showFill(self.flash,click and click.point,click and click.width or width,flashStrength*.86,white,.09)
end

function V:heal(view,now)
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-view.Position).Magnitude>64 then return end
 for i=1,2 do
  local available
  for _,cue in ipairs(self.cues) do if not cue.at then available=cue;break end end
  if not available then
   if #self.cues>=16 then return end
   local gui=Instance.new('BillboardGui')
   gui.Name='CrystalHealing';gui.Size=UDim2.fromOffset(22,22);gui.LightInfluence=0;gui.MaxDistance=68
   gui.Parent=self.options.parent
   local plus=Instance.new('TextLabel')
   plus.Size=UDim2.fromScale(1,1);plus.BackgroundTransparency=1;plus.Font=Enum.Font.GothamBold
   plus.Text='+';plus.TextColor3=Color3.fromRGB(138,255,151);plus.TextSize=22;plus.Parent=gui
   available={gui=gui,text=plus};table.insert(self.cues,available)
  end
  available.at=now;available.side=i==1 and -1 or 1
  available.gui.Adornee=view;available.gui.Enabled=true
 end
end
function V:updateHealing(now)
 for _,cue in ipairs(self.cues) do
  if cue.at then
   local age=now-cue.at
   local view=cue.gui.Adornee
   if age>=.65 or not view or not view.Parent then
    cue.at=nil;cue.gui.Enabled=false;cue.gui.Adornee=nil
   else
    cue.gui.StudsOffsetWorldSpace=Vector3.new(cue.side*(.45+age*.55),view.Size.Y*.5+.4+age*2.5,cue.side*.3)
    cue.text.TextTransparency=math.clamp((age-.24)/.41,0,1)
   end
  end
 end
end
function V:destroy()
 if self.activeFloor then
  for _,mark in ipairs({self.flash,self.previewEdge,self.aimEdge,self.previewFloor,self.activeEdge,self.activeFloor}) do mark.base:Destroy() end
 end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V
