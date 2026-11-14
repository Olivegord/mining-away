-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={}
V.__index=V
local function tint(r,g,b) return ColorSequence.new(Color3.fromRGB(r,g,b)) end
local preview=tint(228,248,255)
local pending=tint(158,166,176)
local cutting=tint(85,245,173)
local idle=tint(112,207,255)
local caution=tint(255,190,99)
local depleted=tint(177,165,231)
local statusColors={
 BagFull=caution,LooseOre=caution,Claimed=caution,
 Growing=depleted,Refilling=depleted,NoCrystals=depleted,
 Surge=tint(255,219,103),SurgeReady=tint(255,219,103),
 Paused=pending,NoMiners=pending,Recharging=tint(190,147,255),
}
local riseTime=.68
local pillarHeight=19
local railFade=NumberSequence.new(.14)
local pillarFade=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),
 NumberSequenceKeypoint.new(.72,.2),NumberSequenceKeypoint.new(1,1)})

local function beam(anchor,from,to,width,endWidth,transparency)
 local line=Instance.new('Beam')
 line.Attachment0=from;line.Attachment1=to
 line.FaceCamera=true;line.Segments=8;line.LightEmission=.22;line.LightInfluence=0
 line.Width0=width;line.Width1=endWidth;line.Transparency=transparency;line.Enabled=false
 line.Parent=anchor
 return line
end

local function marker(parent,name,isPreview)
 local anchor=Instance.new('Part')
 anchor.Name=name;anchor.Size=Vector3.one;anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false;anchor.Parent=parent
 local mark={anchor=anchor,feet={},tips={},beams={}}
 for i=1,4 do
  local foot=Instance.new('Attachment');foot.Parent=anchor;mark.feet[i]=foot
  if not isPreview then
   local tip=Instance.new('Attachment');tip.Parent=anchor;mark.tips[i]=tip
   table.insert(mark.beams,beam(anchor,foot,tip,1.05,.32,pillarFade))
  end
 end
 local width=isPreview and .85 or .42
 for i,foot in ipairs(mark.feet) do
  table.insert(mark.beams,beam(anchor,foot,mark.feet[i%4+1],width,width,railFade))
 end
 if isPreview then
  local fill=Instance.new('Part')
  fill.Name='AimFootprint';fill.Color=preview.Keypoints[1].Value;fill.Material=Enum.Material.Neon
  fill.Transparency=1;fill.Anchored=true;fill.CanCollide=false;fill.CanTouch=false;fill.CanQuery=false;fill.CastShadow=false
  fill.Parent=anchor;mark.fill=fill
 end
 return mark
end

local function show(mark,point,width,color,dt,instant)
 local visible=point~=nil
 local moved=visible and point~=mark.point
 local resized=visible and width~=mark.width
 if moved then
  mark.anchor.Position=point
  mark.age=if instant then math.huge else 0
 end
 if resized then
  local h=width*.5
  for i,foot in ipairs(mark.feet) do
   foot.Position=Vector3.new((i==1 or i==4) and -h or h,.12,i<=2 and -h or h)
  end
  if mark.fill then mark.fill.Size=Vector3.new(width,.03,width) end
  mark.width=width
 end
 if visible and mark.fill and moved then mark.fill.Position=point+Vector3.yAxis*.045 end
 if visible and #mark.tips>0 and (moved or resized or mark.age<riseTime+.09) then
  if instant then mark.age=math.huge elseif not moved then mark.age+=dt end
  for i,tip in ipairs(mark.tips) do
   local t=math.clamp((mark.age-(i-1)*.03)/riseTime,0,1)
   local rise=1-(1-t)^5
   tip.Position=mark.feet[i].Position+Vector3.yAxis*(.25+(pillarHeight-.25)*rise)
  end
 end
 if visible~=mark.visible or visible and color~=mark.color then
  for _,line in ipairs(mark.beams) do
   line.Enabled=visible
   if visible then line.Color=color end
  end
  if mark.fill then mark.fill.Transparency=visible and .86 or 1 end
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
  self.pinned=marker(o.parent,'MiningSelector',false)
  self.previous=marker(o.parent,'PreviousMiningSelector',false)
  self.preview=marker(o.parent,'SelectorPreview',true)
 end
 if not self.pinned then return end
 local width=profile and Workshop.selectorWidth(profile) or 0
 self.clock+=dt
 if not visible or not ray then self.aimPoint=nil;self.clock=.033
 elseif self.clock>=.033 then self.clock=0;self.aimPoint=self:aim(ray) end
 local point=self.aimPoint
 if point and (point==pin or point==old) then point=nil end
 local transition=o.player:GetAttribute('MA_SelectorTransition')
 local status=o.player:GetAttribute('MA_SelectorStatus')
 local working=o.player:GetAttribute('MA_SelectorWorking')
 local color=transition and pending or statusColors[status] or (working and cutting or idle)
 -- Carry the existing beams over intact when that field becomes the previous one.
 if old and old~=pin and self.pinned.point==old then self.pinned,self.previous=self.previous,self.pinned end
 local instant=o.reducedMotion()
 show(self.pinned,pin,o.player:GetAttribute('MA_SelectorWidth') or width,color,dt,instant)
 show(self.previous,old~=pin and old or nil,o.player:GetAttribute('MA_SelectorPreviousWidth') or width,
  transition=='Finishing' and cutting or idle,dt,instant or self.previous.point~=old)
 show(self.preview,point,width,preview,dt,true)
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
 if self.pinned then self.pinned.anchor:Destroy();self.previous.anchor:Destroy();self.preview.anchor:Destroy() end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V
