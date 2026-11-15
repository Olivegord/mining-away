-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={}
V.__index=V
local previewColor=Color3.fromRGB(234,245,255)
local activeColor=Color3.fromRGB(255,147,61)
local clearColor=Color3.fromRGB(85,243,148)
local white=Color3.new(1,1,1)
local riseTime,wallHeight=.32,10*2/3
local wallHold,wallFadeTime,flashTime=.12,.46,.27
local wallFade=NumberSequence.new({
 NumberSequenceKeypoint.new(0,.62),NumberSequenceKeypoint.new(.36,.51),
 NumberSequenceKeypoint.new(.80,.26),NumberSequenceKeypoint.new(1,0),
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
 local base=part(parent,'SelectorOutline');base.Size=Vector3.one
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
local function fill(parent,name)
 local base=part(parent,name)
 local gui=surface(base,Enum.NormalId.Top,Vector2.new(8,8))
 local face=frame(gui);face.BackgroundColor3=white
 return {base=base,gui=gui,face=face}
end
local function showFill(mark,point,width,opacity)
 mark.gui.Enabled=point~=nil and opacity>0
 if not mark.gui.Enabled then return end
 mark.base.Position=point+Vector3.yAxis*.04
 mark.base.Size=Vector3.new(width,.02,width)
 mark.face.BackgroundTransparency=1-opacity
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
  local edge=part(folder,'WallParticleEdge')
  local sparks=Instance.new('ParticleEmitter');sparks.Name='RisingEdgeSparks'
  sparks.Texture='rbxasset://textures/particles/SquareParticle.png'
  sparks.Enabled=false;sparks.Rate=0;sparks.LockedToPart=false
  sparks.EmissionDirection=Enum.NormalId.Top;sparks.Shape=Enum.ParticleEmitterShape.Box
  sparks.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
  sparks.LightEmission=.78;sparks.LightInfluence=0;sparks.Brightness=1.3
  sparks.Lifetime=NumberRange.new(.68,1.24);sparks.Speed=NumberRange.new(4,10)
  sparks.Drag=2;sparks.Acceleration=Vector3.yAxis*.8;sparks.SpreadAngle=Vector2.new(24,24)
  sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.18,.08),
   NumberSequenceKeypoint.new(.58,.13),NumberSequenceKeypoint.new(1,.035)})
  sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),
   NumberSequenceKeypoint.new(.32,.18),NumberSequenceKeypoint.new(1,1)})
  sparks.Parent=edge
  mark.sides[i]={part=plane,faces=faces,edge=edge,sparks=sparks}
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
local function showWalls(mark,point,width,color,dt,instant,cameraPosition,lowFlash,reduced)
 if not point then
  for _,side in ipairs(mark.sides) do setVisibility(side,0) end
  return
 end
 local moved=point~=mark.point or width~=mark.width
 if moved then mark.age=0;mark.emitted=false end
 local age=mark.age
 local remaining=instant and 0 or 1-math.clamp(age/riseTime,0,1)
 local height=wallHeight*(1-.86*remaining^4)
 local sizeChanged=height~=mark.height or width~=mark.width
 local distance=cameraPosition and (cameraPosition-point).Magnitude or 0
 local far=math.clamp((distance-42)/28,0,1)
 local idle=.33+.20*far
 -- Hit full intensity, hold it, then fade linearly to the visible wall.
 local flash=1-math.clamp((age-wallHold)/wallFadeTime,0,1)
 local opacity=idle+((lowFlash and .60 or .94)-idle)*flash
 opacity=math.round(opacity*128)/128
 local tint=color:Lerp(white,flash*(lowFlash and .12 or .38))
 local emit=not reduced and not mark.emitted and age+dt>=.07
 for i,side in ipairs(mark.sides) do
  local plane=side.part
  if moved or sizeChanged then
   local sideFrame=CFrame.new(point+Vector3.yAxis*(height*.5+.03))*CFrame.Angles(0,(i-1)*math.pi*.5,0)
   plane.Size=Vector3.new(width,height,.02)
   plane.CFrame=sideFrame*CFrame.new(0,0,-width*.5)
  end
  if tint~=mark.tint then for _,f in ipairs(side.faces) do f.BackgroundColor3=tint end end
  setVisibility(side,opacity)
  if emit then
   local edge=side.edge
   edge.Size=Vector3.new(width,.10,.10)
   edge.CFrame=CFrame.new(point+Vector3.yAxis*(wallHeight*.61))*CFrame.Angles(0,(i-1)*math.pi*.5,0)*CFrame.new(0,0,-width*.5)
   side.sparks.Color=ColorSequence.new(white,color)
   side.sparks:Emit(lowFlash and 5 or math.clamp(math.round(width*.37),8,16))
  end
 end
 mark.emitted=mark.emitted or emit
 mark.age=math.min(wallHold+wallFadeTime,age+dt)
 mark.point=point;mark.width=width;mark.height=height;mark.tint=tint
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
 if not point or not id or not profile or not profile.run then return false end
 if not inRange then
  if self.options.notify then self.options.notify('Move closer to select that area.') end
  return true
 end
 local requestId=game:GetService('HttpService'):GenerateGUID(false)
 self.click={point=point,field=id,width=Workshop.selectorWidth(profile),at=os.clock(),requestId=requestId}
 self.options.command:FireServer('PlaceSelector',{fieldId=id,position=point,runId=profile.run.id,leadId=leadId,requestId=requestId})
 return true
end
function V:reply(state)
 if not self.click or self.click.requestId~=state.requestId then return false end
 if state.status=='rejected' then self.click=nil end
 return true
end
function V:flashState()
 local click=self.click
 if not click or self.options.hidden() then return nil,0 end
 local age=os.clock()-click.at
 if age>=flashTime then return nil,0 end
 local peak=self.options.player:GetAttribute('ReducedFlashing')==true and .34 or .78
 return click,peak*(1-math.clamp((age-.045)/(flashTime-.045),0,1))
end
function V:showAim(dt,ray)
 local o=self.options
 local profile=o.profile()
 local visible=profile and not o.hidden()
 local pin=profile and not (o.hidePin or o.hidden)() and o.player:GetAttribute('MA_Selector') or nil
 if not self.pinned and profile and o.world.Map:FindFirstChild('CrystalRun') then
  self.pinned=walls(o.parent,'MiningSelector')
  self.flash=fill(o.parent,'SelectorClickFill')
  self.aimEdge=outline(o.parent)
  self.activeEdge=outline(o.parent)
 end
 if not self.pinned then return end
 if not o.player:GetAttribute('MA_Selector') then self.pinned.point=nil end
 local width=profile and Workshop.selectorWidth(profile) or 0
 self.clock+=dt
 if not visible or not ray then self.aimPoint=nil;self.clock=.033
 elseif self.clock>=.033 then
  self.clock=0
  local point,_,_,inRange=self:aim(ray)
  self.aimPoint=inRange and point or nil
 end
 local color=o.player:GetAttribute('MA_SelectorCleared') and clearColor or activeColor
 local camera=workspace.CurrentCamera
 local instant=o.reducedMotion()
 local lowFlash=o.player:GetAttribute('ReducedFlashing')==true
 local pinWidth=o.player:GetAttribute('MA_SelectorWidth') or width
 showWalls(self.pinned,pin,pinWidth,color,dt,instant,camera and camera.CFrame.Position,lowFlash,instant or BeamVFX.reduced())
 showOutline(self.activeEdge,pin,pinWidth,color)
 showOutline(self.aimEdge,self.aimPoint~=pin and self.aimPoint or nil,width,previewColor)
 local flash,strength=self:flashState()
 showFill(self.flash,flash and flash.point or nil,flash and flash.width or width,strength)
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
 if self.pinned then
  self.pinned.folder:Destroy()
  for _,mark in ipairs({self.flash,self.aimEdge,self.activeEdge}) do mark.base:Destroy() end
 end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V
