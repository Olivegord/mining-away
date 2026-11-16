-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={}
V.__index=V
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
local function showOutline(mark,point,width,color)
 mark.gui.Enabled=point~=nil
 if not point then return end
 if mark.color~=color then
  for _,edge in ipairs(mark.edges) do edge.BackgroundColor3=color;edge.BackgroundTransparency=.22 end
  mark.color=color
 end
 if mark.point~=point then mark.base.Position=point+Vector3.yAxis*.11;mark.point=point end
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
  if bed and (part==bed or leadId) then
   local position=hit.Position
   local top=bed.Position.Y+bed.Size.Y*.5
   if leadId and ray.Direction.Y<-.001 then
    position=ray.Origin+ray.Direction*((top-ray.Origin.Y)/ray.Direction.Y)
   end
   local point=Mining.selectorCenter(position,bed.CFrame,bed.Size)
   local inRange=point and Mining.selectorInRange(hr.Position,point)
   if leadId then
    -- A shallow ray can put the floor projection off the bed, out of range,
    -- or too far from the rock that was actually clicked.
    local rockPosition=rootPart:GetAttribute('FullPosition') or hit.Position
    local profile=o.profile()
    local coversRock=point and profile and Mining.selectorContains(point,Workshop.selectorWidth(profile)*.5,rockPosition)
    if not inRange or not coversRock then
     local rockPoint=Mining.selectorCenter(rockPosition,bed.CFrame,bed.Size)
     if rockPoint and (not point or Mining.selectorInRange(hr.Position,rockPoint)) then
      point=rockPoint;inRange=Mining.selectorInRange(hr.Position,point)
     end
    end
   end
   if point then return point,bed:GetAttribute('FieldId'),leadId,inRange end
   return nil
  end
  if part.CanCollide then return nil end
  table.insert(ignore,part)
 end
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
 local point=Mining.selectorCenter(edge,bed.CFrame,bed.Size)
 return point~=nil and Mining.selectorInRange(root.Position,point)
end
function V:commit(ray)
 local point,id,leadId,inRange=self:aim(ray)
 local profile=self.options.profile()
 if self.pending then return point~=nil end
 if not point or not id or not profile or not profile.run then
  self:cancelPreview()
  return false
 end
 if not inRange then
  if self.options.notify then self.options.notify('Move closer to select that area.') end
  return true
 end
 local width=Workshop.selectorWidth(profile)
 local draft=self.draft
 if not draft or draft.field~=id or draft.runId~=profile.run.id or draft.width~=width
  or not Mining.selectorContains(draft.point,width*.5,point) then
  self.draft={point=point,field=id,width=width,leadId=leadId,runId=profile.run.id,
   character=self.options.player.Character,age=0}
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
function V:step(dt)
 local o=self.options
 local profile=o.profile()
 local visible=profile and not o.hidden()
 local pin=profile and not (o.hidePin or o.hidden)() and o.player:GetAttribute('MA_Selector') or nil
 if not self.activeFloor and profile and o.world.Map:FindFirstChild('CrystalRun') then
  self.flash=fill(o.parent,'SelectorClickFill')
  self.previewEdge=outline(o.parent,'SelectorPreviewOutline')
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
 local color=o.player:GetAttribute('MA_SelectorCleared') and clearColor or activeColor
 local lowFlash=o.player:GetAttribute('ReducedFlashing')==true
 local pinWidth=o.player:GetAttribute('MA_SelectorWidth') or width
 local click,flashStrength=self:flashState()
 showOutline(self.activeEdge,pin,pinWidth,color)
 showFill(self.activeFloor,pin,pinWidth,lowFlash and .13 or .19,color,.04)
 local preview,previewWidth,strength=self:previewState()
 showOutline(self.previewEdge,preview and preview.point,previewWidth,previewColor)
 showFill(self.previewFloor,preview and preview.point,previewWidth,strength*.62,previewColor,.065)
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
  for _,mark in ipairs({self.flash,self.previewEdge,self.previewFloor,self.activeEdge,self.activeFloor}) do mark.base:Destroy() end
 end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V
