-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={}
V.__index=V
local previewColor=Color3.fromRGB(234,245,255)
local pendingColor=Color3.fromRGB(155,162,174)
local activeColor=Color3.fromRGB(255,147,61)
local clearColor=Color3.fromRGB(85,243,148)
local riseTime,wallHeight=.68,19
local wallFade=NumberSequence.new({
 NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.30,.84),
 NumberSequenceKeypoint.new(.80,.49),NumberSequenceKeypoint.new(1,0),
})

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

local function outline(parent)
 local base=part(parent,'SelectorPreview');base.Size=Vector3.one
 local gui=surface(base,Enum.NormalId.Top,Vector2.new(512,512))
 local edges={}
 for i=1,4 do
  local edge=frame(gui);edge.BackgroundColor3=previewColor
  edges[i]=edge
 end
 return {base=base,gui=gui,edges=edges}
end
local function showOutline(mark,point,width)
 mark.gui.Enabled=point~=nil
 if not point then return end
 if mark.point~=point then mark.base.Position=point+Vector3.yAxis*.055;mark.point=point end
 if mark.width~=width then
  mark.base.Size=Vector3.new(width,.02,width);mark.width=width
  local t=.55/width
  -- Two full edges and two inset edges meet flush without double-bright corners.
  mark.edges[1].Size=UDim2.fromScale(1,t)
  mark.edges[2].Position=UDim2.fromScale(0,1-t);mark.edges[2].Size=UDim2.fromScale(1,t)
  mark.edges[3].Position=UDim2.fromScale(0,t);mark.edges[3].Size=UDim2.fromScale(t,1-2*t)
  mark.edges[4].Position=UDim2.fromScale(1-t,t);mark.edges[4].Size=UDim2.fromScale(t,1-2*t)
 end
end

local function walls(parent,name)
 local folder=Instance.new('Folder');folder.Name=name;folder.Parent=parent
 local mark={folder=folder,sides={}}
 for i=1,4 do
  local plane=part(folder,'ForcefieldWall')
  local faces={}
  for _,normal in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
   local f=frame(surface(plane,normal,Vector2.new(256,192)))
   local gradient=Instance.new('UIGradient')
   gradient.Rotation=90;gradient.Transparency=wallFade;gradient.Parent=f
   table.insert(faces,f)
  end
  mark.sides[i]={part=plane,faces=faces}
 end
 return mark
end
local function setVisibility(side,opacity)
 if side.opacity==opacity then return end
 side.opacity=opacity
 for _,f in ipairs(side.faces) do
  f.BackgroundTransparency=1-opacity
  f.Parent.Enabled=opacity>0
 end
end
local function showWalls(mark,point,width,color,dt,instant,eye)
 if not point then
  for _,side in ipairs(mark.sides) do setVisibility(side,0) end
  mark.point=nil
  return
 end
 local moved=point~=mark.point
 if moved then mark.age=0 end
 if instant then mark.age=riseTime elseif not moved then mark.age=math.min(riseTime,mark.age+dt) end
 local height=.08+(wallHeight-.08)*(1-(1-mark.age/riseTime)^5)
 local sizeChanged=height~=mark.height or width~=mark.width
 for i,side in ipairs(mark.sides) do
  local plane=side.part
  if moved or sizeChanged then
   local sideFrame=CFrame.new(point+Vector3.yAxis*(height*.5+.03))*CFrame.Angles(0,(i-1)*math.pi*.5,0)
   plane.Size=Vector3.new(width,height,.02)
   plane.CFrame=sideFrame*CFrame.new(0,0,-width*.5)
  end
  if color~=mark.color then for _,f in ipairs(side.faces) do f.BackgroundColor3=color end end
  local opacity=0
  if eye then
   local p=plane.CFrame:PointToObjectSpace(eye)
   local nearest=Vector3.new(math.clamp(p.X,-width*.5,width*.5),math.clamp(p.Y,-height*.5,height*.5),0)
   local proximity=math.clamp((46-(p-nearest).Magnitude)/38,0,1)
   opacity=math.round(.44*proximity^2*64)/64
  end
  setVisibility(side,opacity)
 end
 mark.point=point;mark.width=width;mark.height=height;mark.color=color
end

function V.new(options)
 return setmetatable({options=options,cues={},clock=0},V)
end
function V:aim(ray)
 local o=self.options
 local run=o.world.Map:FindFirstChild('CrystalRun')
 if not run or o.hidden() then return nil end
 local character=o.player.Character
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 if not hr then return nil end
 local filter=RaycastParams.new();filter.FilterType=Enum.RaycastFilterType.Exclude
 filter.FilterDescendantsInstances={character,o.parent}
 local direction=ray.Direction*500
 local hit=workspace:Raycast(ray.Origin,direction,filter)
 if not hit then return nil end
 local part=hit.Instance
 local zone=part.Parent
 local bed=zone and zone.Parent==run and zone:FindFirstChild('Field')
 local leadId=bed and part:GetAttribute('ResourceId')
 if not bed or (part~=bed and not leadId) then
  if part.CanCollide then return nil end
  filter.RespectCanCollide=true
  hit=workspace:Raycast(ray.Origin,direction,filter)
  part=hit and hit.Instance
  zone=part and part.Parent
  bed=zone and zone.Parent==run and zone:FindFirstChild('Field')
  if not bed or part~=bed then return nil end
  leadId=nil
 end
 local position=leadId and part:GetAttribute('FullPosition') or hit.Position
 local point=Mining.selectorCenter(position,bed.CFrame,bed.Size)
 if not point then return nil end
 local field=bed:GetAttribute('FieldId')
 if not Mining.selectorInRange(hr.Position,point) then return nil end
 return point,field,leadId
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
 local point,id,leadId=self:aim(ray)
 local profile=self.options.profile()
 if not point or not id or not profile then return false end
 self.options.command:FireServer('PlaceSelector',{fieldId=id,position=point,runId=profile.run.id,leadId=leadId})
 return true
end
function V:showAim(dt,ray)
 local o=self.options
 local profile=o.profile()
 local visible=profile and not o.hidden()
 local pin=visible and o.player:GetAttribute('MA_Selector') or nil
 local old=pin and o.player:GetAttribute('MA_SelectorPrevious') or nil
 if not self.pinned and profile and o.world.Map:FindFirstChild('CrystalRun') then
  self.pinned=walls(o.parent,'MiningSelector')
  self.previous=walls(o.parent,'PreviousMiningSelector')
  self.preview=outline(o.parent)
 end
 if not self.pinned then return end
 local width=profile and Workshop.selectorWidth(profile) or 0
 self.clock+=dt
 if not visible or not ray then self.aimPoint=nil;self.clock=.033
 elseif self.clock>=.033 then self.clock=0;self.aimPoint=self:aim(ray) end
 local point=self.aimPoint
 if point and (point==pin or point==old) then point=nil end
 local transfer=old and o.player:GetAttribute('MA_SelectorTransition')
 local color=transfer and pendingColor or (o.player:GetAttribute('MA_SelectorCleared') and clearColor or activeColor)
 -- Keep the already extended walls when the current pin becomes the old one.
 if old and old~=pin and self.pinned.point==old then self.pinned,self.previous=self.previous,self.pinned end
 local instant=o.reducedMotion()
 local camera=workspace.CurrentCamera
 local eye=camera and camera.CFrame.Position
 showWalls(self.pinned,pin,o.player:GetAttribute('MA_SelectorWidth') or width,color,dt,instant,eye)
 showWalls(self.previous,old~=pin and old or nil,o.player:GetAttribute('MA_SelectorPreviousWidth') or width,
  o.player:GetAttribute('MA_SelectorPreviousCleared') and clearColor or activeColor,dt,instant or self.previous.point~=old,eye)
 showOutline(self.preview,point,width)
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
 if self.pinned then self.pinned.folder:Destroy();self.previous.folder:Destroy();self.preview.base:Destroy() end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V
