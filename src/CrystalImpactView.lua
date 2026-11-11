-- Local-only feedback. Rest poses and reward objects belong to other systems.
local V={}
local function part(parent,class,name,color)
 local p=Instance.new(class);p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false
 p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Parent=parent
 return p
end
function V.new(parent,audio)
 local self={pieces={},parent=parent,audio=audio,seamBudget=1}
 function self:chips(at,point,normal,tint,count,large,scale,ground)
  if not BeamVFX.near(point,large and 92 or 60) then return end
  if BeamVFX.reduced() then count=math.min(count,large and 2 or 1) end
  local sideways=normal:Cross(Vector3.yAxis)
  sideways=sideways.Magnitude>.01 and sideways.Unit or Vector3.xAxis
  local up=normal:Cross(sideways).Unit
  for i=1,count do
   if #self.pieces>=48 then break end
   local angle=i*2.399+at%3;local spread=sideways*math.cos(angle)+up*math.sin(angle)
   local direction=normal*.7+spread*(large and 1.25 or .66)
   local size=large and scale*(.42+i*.1) or .10+i*.036
   local p=part(parent,'WedgePart',large and 'CrystalBreakPiece' or 'CrystalChip',tint)
   p.Size=Vector3.new(size*.72,size*1.45,size)
   p.CFrame=CFrame.new(point)
   local origin=point+normal*(size*.85+.025)
   p.Position=origin
   self.pieces[#self.pieces+1]={p=p,at=at,from=origin,v=direction*(large and 8 or 9)+Vector3.yAxis*(large and 4 or 2),
    duration=large and .5 or .24,ground=ground or point.Y-4}
  end
 end
 function self:step(now)
  for i=#self.pieces,1,-1 do
   local e=self.pieces[i];local t=now-e.at
   if t>=e.duration then e.p:Destroy();table.remove(self.pieces,i)
   else
    local pos=e.from+e.v*t-Vector3.yAxis*(23*t*t)
    e.p.CFrame=CFrame.new(pos.X,math.max(e.ground+e.p.Size.Y*.45,pos.Y),pos.Z)*CFrame.Angles(t*9+i,t*7,t*4)
    e.p.Transparency=math.clamp((t/e.duration-.62)/.38,0,1)
   end
  end
 end
 function self:clearMarks(r)
  if r.seams then r.seams:Destroy();r.seams=nil end
 end
 function self:marks(r,stage,count)
  self:clearMarks(r)
  local view,source=r.view,r.source
  if stage==0 or not source.CanQuery or not BeamVFX.near(view.Position,125) then return false end
  local folder=Instance.new('Folder');folder.Name='CrystalSeams';folder.Parent=parent;r.seams=folder
  local depth=stage/math.max(1,count)
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={source}
  -- Trace seams onto the current collision surface. Every point is projected;
  -- narrow discontinuities in the faceted mesh are left as gaps.
  local function trace(out,across,points,tint,width)
   local previous=nil
   for _,xy in ipairs(points) do
    local base=source.CFrame:PointToWorldSpace((across*xy[1]+Vector3.yAxis*xy[2])*source.Size)
    local ray=source.CFrame:VectorToWorldSpace(out)*source.Size.Magnitude
    local hit=workspace:Raycast(base+ray,-ray*1.25,params)
    local point=hit and hit.Position+hit.Normal*.028
    if point and previous then
     local span=(point-previous).Magnitude
     if span>.015 and span<source.Size.Magnitude*.25 then
      local line=part(folder,'Part','Seam',tint)
      line.Size=Vector3.new(width,width,span+.02);line.CFrame=CFrame.lookAt((point+previous)*.5,point)
     end
    end
    previous=point
   end
  end
  local dark=r.baseColor:Lerp(Color3.fromRGB(25,17,30),.82)
  local interior=r.baseColor:Lerp(Color3.fromRGB(255,238,210),.62)
  local main={{-.19,-.35},{-.10,-.21},{-.16,-.11},{-.03,.02},{-.06,.13}}
  if depth>=.60 then table.insert(main,{.07,.27});table.insert(main,{.05,.37}) end
  for _,out in ipairs({Vector3.xAxis,-Vector3.xAxis,Vector3.zAxis,-Vector3.zAxis}) do
   local across=Vector3.yAxis:Cross(out)
   trace(out,across,main,dark,.055+depth*.052)
   if depth>=.55 then trace(out,across,{{-.16,-.11},{-.035,-.12},{.10,-.024},{.22,-.052}},interior,.064+depth*.045) end
  end
  return true
 end
 function self:react(r,now)
  local s,v=r.source,r.view
  local impact=s:GetAttribute('CutContactAt') or 0
  local broken=(s:GetAttribute('BreakSerial') or 0)>0
  local breakAt=s:GetAttribute('CrystalBreakAt') or 0
  if impact>r.lastContactAt then
   r.lastContactAt=impact
   local at=now-impact
   if at>=0 and at<.21 and BeamVFX.near(v.Position,95) and now>=(r.flashGate or 0) then
    r.flashAt=now;r.flashGate=now+.105
    local point=s:GetAttribute('CutContactPoint') or v.Position
    local normal=s:GetAttribute('CutContactNormal') or Vector3.yAxis
    r.kick=Vector3.new(-normal.Z,0,normal.X)*.021
    self:chips(now,point,normal,r.baseColor,3,false,nil,s:GetAttribute('GroundY'))
    if s:GetAttribute('CutIsShot') and not broken then
     local health=(s:GetAttribute('HP') or 1)/math.max(1,s:GetAttribute('MaxHP') or 1)
     audio:play('crystal_snap',point,{pitch=1.20-.23*health})
     audio:play('crystal_electric',point,{pitch=.95+.12*(1-health)})
     r.chipTail={at=now+.042,point=point,pitch=1.04+.22*(1-health)}
    end
   end
  end
  if r.chipTail and now>=r.chipTail.at then
   local cue=r.chipTail;r.chipTail=nil
   if not broken and now-cue.at<.10 then audio:play('crystal_chip',cue.point,{pitch=cue.pitch}) end
  end
  if broken and breakAt>0 and breakAt>(r.lastBreakAt or 0) then
   if breakAt>now then return end
   if not r.splitDue and now-breakAt<.24 and r.restPose and BeamVFX.near(v.Position,92) then
    r.splitDue=now+.05;r.flashAt=now
   end
   if r.splitDue and now<r.splitDue then
    v.Transparency=0
   else
    r.lastBreakAt=breakAt
    if r.splitDue then
     local frame=r.restPose
     local ground=s:GetAttribute('GroundY') or frame.Position.Y-1
     local point=Vector3.new(frame.Position.X,ground+math.max(.65,v.Size.Y*.42),frame.Position.Z)
     for _,side in ipairs({-1,1}) do
      local normal=frame.RightVector*side
      self:chips(now,point+normal*v.Size.X*.22,normal,r.baseColor,2,true,math.clamp(v.Size.Y*.36,.65,1.6),ground)
     end
     audio:play('crystal_split',point)
    end
    r.splitDue=nil;v.Transparency=1;self:clearMarks(r)
   end
  end
  if r.restPose and (r.flashAt or r.vibrating or (r.cutUntil or 0)>now) then
   local t=r.flashAt and now-r.flashAt or math.huge
   if t<.06 then v.Color=r.restColor:Lerp(Color3.new(1,1,1),.95*(1-.35*t/.06))
   else v.Color=r.restColor end
   local amount=t<.14 and math.sin(math.pi*t/.14)*(1-t/.14) or 0
   if t>=.14 then r.flashAt=nil;r.kick=nil end
   r.vibrating=not broken and not BeamVFX.reduced() and (r.cutUntil or 0)>now
   local vibration=r.vibrating and math.sin(now*77)*.004 or 0
   local kick=not BeamVFX.reduced() and r.kick or Vector3.zero
   local foot=r.restPose.Position-Vector3.yAxis*(v.Size.Y*.5)
   v.CFrame=CFrame.new(foot)*CFrame.Angles(kick.X*amount+vibration,0,kick.Z*amount-vibration)*CFrame.new(-foot)*r.restPose
  end
 end
 function self:destroy()
  for _,e in ipairs(self.pieces) do e.p:Destroy() end;table.clear(self.pieces)
 end
 return self
end
return V
