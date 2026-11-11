-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={}
V.__index=V
local idle=ColorSequence.new(Color3.fromRGB(167,212,218))
local active=ColorSequence.new(Color3.fromRGB(255,215,123))
local preview=ColorSequence.new(Color3.fromRGB(211,230,229))
local heights={.06,.27,.54}
local widths={.075,.11,.15}
local fades={.28,.68,.87}

local function marker(parent,isPreview)
 local anchor=Instance.new('Part')
 anchor.Name=isPreview and 'SelectorPreview' or 'MiningSelector'
 anchor.Size=Vector3.one;anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Parent=parent
 local layers={}
 for i,height in ipairs(heights) do
  if isPreview and i>1 then break end
  local layer={height=height,corners={},beams={}}
  for n=1,4 do
   local corner=Instance.new('Attachment');corner.Parent=anchor;layer.corners[n]=corner
  end
  for n=1,4 do
   local beam=Instance.new('Beam')
   beam.Attachment0=layer.corners[n];beam.Attachment1=layer.corners[n%4+1]
   beam.FaceCamera=true;beam.Segments=1;beam.LightEmission=.25;beam.LightInfluence=.25
   beam.Width0=widths[i];beam.Width1=widths[i];beam.Enabled=false
   beam.Transparency=NumberSequence.new(isPreview and .73 or fades[i])
   beam.Parent=anchor;layer.beams[n]=beam
  end
  layers[i]=layer
 end
 return {anchor=anchor,layers=layers}
end

local function show(mark,point,width,color)
 local visible=point~=nil
 if visible and mark.point~=point then mark.anchor.Position=point end
 if visible and mark.width~=width then
  local h=width*.5
  for _,layer in ipairs(mark.layers) do
   local y=layer.height
   for i,corner in ipairs(layer.corners) do
    corner.Position=Vector3.new((i==1 or i==4) and -h or h,y,i<=2 and -h or h)
   end
  end
  mark.width=width
 end
 if visible~=mark.visible or visible and color~=mark.color then
  for _,layer in ipairs(mark.layers) do for _,beam in ipairs(layer.beams) do
   beam.Enabled=visible
   if visible then beam.Color=color end
  end end
 end
 mark.visible=visible;mark.point=point;mark.color=color
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
 for _,plot in quartz:GetChildren() do
  if not plot:IsA('BasePart') or not plot:GetAttribute('CrystalCluster') then continue end
  local localPosition=plot.CFrame:PointToObjectSpace(root.Position)
  local edge=plot.CFrame:PointToWorldSpace(Vector3.new(
   math.clamp(localPosition.X,-plot.Size.X*.5,plot.Size.X*.5),0,
   math.clamp(localPosition.Z,-plot.Size.Z*.5,plot.Size.Z*.5)))
  local point=Mining.selectorCenter(edge,bed.CFrame,bed.Size)
  if point and Mining.selectorInRange(root.Position,point) then return true end
 end
 return false
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
 local pin=not o.hidden() and o.player:GetAttribute('MA_Selector') or nil
 if not self.pinned and profile and o.world.Map:FindFirstChild('CrystalRun') then
  self.pinned=marker(o.parent,false);self.preview=marker(o.parent,true)
 end
 if not self.pinned or not profile then return end
 local width=Workshop.selectorWidth(profile)
 self.clock+=dt
 if not ray then self.aimPoint=nil
 elseif self.clock>=.033 then self.clock=0;self.aimPoint=self:aim(ray) end
 local point=self.aimPoint
 if point and pin and (point-pin).Magnitude<.8 then point=nil end
 show(self.pinned,pin,width,o.player:GetAttribute('MA_SelectorWorking') and active or idle)
 show(self.preview,point,width,preview)
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
 if self.pinned then self.pinned.anchor:Destroy();self.preview.anchor:Destroy() end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V
