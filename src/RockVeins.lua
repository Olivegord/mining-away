-- A bounded set of nearby channel lights. Geometry comes from actual inset
-- channels on the replicated rock; local effects track its exact rendered pose.
local V={}
local active=0
local LIMIT,RANGE=20,76
local function release(record)
 if record.veinFX then record.veinFX.root:Destroy();record.veinFX=nil end
end
local function make(record)
 local encoded=record.view:GetAttribute('InsetVeins')
 if not encoded then return nil end
 local ok,paths=pcall(function() return game:GetService('HttpService'):JSONDecode(encoded) end)
 if not ok then return nil end
 local root=Instance.new('Folder');root.Name='InsetMineralLight'
 local state={root=root,segments={},vents={},seed=record.source:GetAttribute('StageSeed') or 1}
 local color=record.baseColor
 local white=Color3.fromRGB(231,255,249)
 for _,path in ipairs(paths) do
  local points={}
  for _,p in ipairs(path.points) do points[#points+1]=Vector3.new(p[1],p[2],p[3]) end
  for i=1,#points-1 do
   local part=Instance.new('Part');part.Name='RecessedVeinCore';part.Anchored=true
   part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part.Material=Enum.Material.Neon;part.Color=color:Lerp(white,i%3==0 and .38 or .12)
   part.Parent=root
   state.segments[#state.segments+1]={part=part,a=points[i],b=points[i+1],width=path.width*((i==1 or i==#points-1) and .16 or .29)}
  end
  local index=math.ceil(#points*.58);local p=path.points[index]
  local anchor=Instance.new('Attachment');anchor.Name='VeinVent';anchor.Parent=record.view
  local endPoint=Instance.new('Attachment');endPoint.Name='VeinRayEnd';endPoint.Parent=record.view
  local beam=Instance.new('Beam');beam.Name='SoftEscapingLight';beam.FaceCamera=true
  beam.Attachment0=anchor;beam.Attachment1=endPoint;beam.Segments=3;beam.LightEmission=1;beam.LightInfluence=0
  beam.Color=ColorSequence.new(white:Lerp(color,.30),color)
  beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.76),NumberSequenceKeypoint.new(.30,.91),NumberSequenceKeypoint.new(1,1)})
  beam.Parent=anchor
  local dust=Instance.new('ParticleEmitter');dust.Name='SlowVeinMotes'
  dust.Texture='rbxasset://textures/ui/VR/circleWhite.png';dust.LightEmission=1;dust.LightInfluence=0;dust.Brightness=1.4
  dust.Color=ColorSequence.new(white:Lerp(color,.32),color)
  dust.Rate=1.7;dust.Lifetime=NumberRange.new(1.5,2.4);dust.Speed=NumberRange.new(.22,.52)
  dust.Drag=.5;dust.Acceleration=Vector3.new(0,.24,0);dust.SpreadAngle=Vector2.new(22,22)
  dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.065),NumberSequenceKeypoint.new(.25,.10),NumberSequenceKeypoint.new(1,0)})
  dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.28),NumberSequenceKeypoint.new(.6,.40),NumberSequenceKeypoint.new(1,1)})
  dust.EmissionDirection=Enum.NormalId.Top;dust.Enabled=false;dust.Parent=anchor
  state.vents[#state.vents+1]={a=anchor,b=endPoint,beam=beam,dust=dust,point=points[index],normal=Vector3.new(p[4],p[5],p[6])}
 end
 active+=1
 root.Destroying:Once(function()
  active-=1
  for _,vent in ipairs(state.vents) do vent.a:Destroy();vent.b:Destroy() end
 end)
 root.Parent=record.view
 return state
end
function V.update(record,now,reducedEffects,reducedMotion)
 local view=record.view
 if record.visual.broken or view.Transparency>=1 or (view.LocalTransparencyModifier or 0)>=1 then release(record);return end
 local state=record.veinFX
 if now>=(record.veinCheckAt or 0) then
  record.veinCheckAt=now+.24
  local camera=workspace.CurrentCamera
  record.veinNear=camera and (camera.CFrame.Position-view.Position).Magnitude<RANGE
  if not record.veinNear then release(record);return end
  if not state and active<LIMIT then
   state=make(record);record.veinFX=state
  end
 end
 if not state then return end
 local size,frame=view.Size,view.CFrame
 if state.size~=size or state.frame~=frame then
  state.size=size;state.frame=frame
  local scale=math.min(size.X,size.Z)
  for _,line in ipairs(state.segments) do
   local a,b=frame:PointToWorldSpace(line.a*size),frame:PointToWorldSpace(line.b*size)
   line.part.Size=Vector3.new(scale*line.width,scale*line.width*.68,(b-a).Magnitude+.012)
   line.part.CFrame=CFrame.lookAt((a+b)*.5,b)
  end
  for _,vent in ipairs(state.vents) do
   local point=vent.point*size
   local normal=vent.normal
   local across=normal:Cross(Vector3.yAxis)
   if across.Magnitude<.01 then across=Vector3.xAxis end
   across=across.Unit
   vent.a.CFrame=CFrame.fromMatrix(point,across,normal,across:Cross(normal))
   vent.b.Position=point+normal*math.clamp(scale*.26,.45,1.15)+Vector3.yAxis*.16
   vent.beam.Width0=scale*.035;vent.beam.Width1=scale*.18
  end
 end
 if now<(state.nextAt or 0) then return end
 state.nextAt=now+.10
 local breath=reducedMotion and 1 or .86+.14*math.sin(now*.85+state.seed)
 for _,line in ipairs(state.segments) do line.part.Transparency=1-(1-view.Transparency)*breath end
 for _,vent in ipairs(state.vents) do
  vent.beam.Enabled=not reducedEffects
  vent.beam.Brightness=breath*.85
  vent.dust.Enabled=not reducedEffects and not reducedMotion
 end
end
return V
