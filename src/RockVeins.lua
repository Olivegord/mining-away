-- Thin shell openings reveal one luminous mineral core. Short textured native
-- Beams soften light escaping the crack; no emissive line geometry on the skin.
local V={}
local active=0
local LIMIT,RANGE=14,80
local function release(record)
 if record.veinFX then record.veinFX.root:Destroy();record.veinFX=nil end
end
local function make(record)
 local view=record.view
 local encoded=view:GetAttribute('CoreFissures')
 local template=view:FindFirstChild('CoreGeometry')
 if not encoded or not template then return nil end
 local ok,paths=pcall(function() return game:GetService('HttpService'):JSONDecode(encoded) end)
 if not ok then return nil end
 local root=Instance.new('Folder');root.Name='CrackedCoreLight'
 local state={root=root,rays={},vents={},seed=record.source:GetAttribute('StageSeed') or 1}
 local color=record.baseColor
 local white=Color3.fromRGB(244,255,248)
 local core=template:Clone();core.Name='LuminousCore';core.Color=color:Lerp(white,.12);core.Transparency=0;core.Parent=root;state.core=core
 -- One short, soft shaft per opening. Repeated thin rays alias into a fence.
 for _,path in ipairs(paths) do
  local i=math.max(1,math.floor(#path.points/2))
  local a,b=path.points[i],path.points[i+1]
  local normal=Vector3.new(a[4],a[5],a[6])
  local point=Vector3.new(a[1],a[2],a[3]):Lerp(Vector3.new(b[1],b[2],b[3]),.5)
  local anchor=Instance.new('Attachment');anchor.Name='CrackRayOrigin';anchor.Parent=view
  local tip=Instance.new('Attachment');tip.Name='CrackRayEnd';tip.Parent=view
  local beam=Instance.new('Beam');beam.Name='CoreLightWash';beam.FaceCamera=true
  beam.Attachment0=anchor;beam.Attachment1=tip;beam.Segments=1
  beam.Texture='rbxasset://textures/ui/AvatarExperience/glowLight.png'
  beam.TextureMode=Enum.TextureMode.Stretch;beam.TextureSpeed=0
  beam.LightEmission=1;beam.LightInfluence=0;beam.Brightness=.8
  beam.Color=ColorSequence.new(color:Lerp(white,.18),color)
  beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.65),NumberSequenceKeypoint.new(.35,.82),NumberSequenceKeypoint.new(1,1)})
  beam.Parent=anchor
  state.rays[#state.rays+1]={a=anchor,b=tip,beam=beam,point=point,normal=normal,fan=normal+Vector3.new(.08,.18,0),length=.26,width=.055,wash=true}
  local dust=Instance.new('ParticleEmitter');dust.Name='EscapingCoreMotes'
  dust.Texture='rbxasset://textures/ui/VR/circleWhite.png';dust.LightEmission=1;dust.LightInfluence=0;dust.Brightness=1
  dust.Color=ColorSequence.new(white,color);dust.Rate=.8
  dust.Lifetime=NumberRange.new(1.3,2);dust.Speed=NumberRange.new(.12,.25);dust.Drag=.8
  dust.Acceleration=Vector3.new(0,.16,0);dust.SpreadAngle=Vector2.new(18,18)
  dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.035),NumberSequenceKeypoint.new(.2,.055),NumberSequenceKeypoint.new(1,0)})
  dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.2,.2),NumberSequenceKeypoint.new(1,1)})
  dust.Enabled=false;dust.Parent=anchor;state.vents[#state.vents+1]=dust
 end
 active+=1
 root.Destroying:Once(function()
  active-=1
  for _,ray in ipairs(state.rays) do ray.a:Destroy();ray.b:Destroy() end
 end)
 root.Parent=view
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
  if not state and active<LIMIT then state=make(record);record.veinFX=state end
 end
 if not state then return end
 local size,frame=view.Size,view.CFrame
 if state.size~=size or state.frame~=frame then
  state.size=size;state.frame=frame
  local core=state.core
  core.Size=size*core:GetAttribute('SizeRatio')
  core.CFrame=frame*CFrame.new(size*core:GetAttribute('CenterRatio'))*core:GetAttribute('RelativeRotation')
  local scale=math.min(size.X,size.Z)
  for _,ray in ipairs(state.rays) do
   local point=ray.point*size+ray.normal*.012
   local across=ray.normal:Cross(Vector3.yAxis).Unit
   ray.a.CFrame=CFrame.fromMatrix(point,across,ray.normal,across:Cross(ray.normal))
   ray.b.Position=point+ray.fan*math.clamp(scale*ray.length,.25,.85)
   ray.beam.Width0=scale*ray.width
   ray.beam.Width1=scale*ray.width*(ray.wash and 3.4 or 1.9)
  end
 end
 if now<(state.nextAt or 0) then return end
 state.nextAt=now+.10
 local breath=reducedMotion and 1 or .91+.09*math.sin(now*.65+state.seed)
 state.core.Transparency=view.Transparency
 for _,ray in ipairs(state.rays) do ray.beam.Enabled=not reducedEffects;ray.beam.Brightness=breath*(ray.wash and .85 or 1.35) end
 for _,dust in ipairs(state.vents) do dust.Enabled=not reducedEffects and not reducedMotion end
end
return V
