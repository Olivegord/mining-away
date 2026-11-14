-- Four cubic quadrants make one expanding circular sheet in the shot plane.
-- The circle expands and fades; its attachments never orbit or face the camera.
local Plane={}
local WHITE=Color3.new(1,1,1)
local DARK=Color3.new(.25,.25,.32)
local opacity={}
local gradientOpacity={}
local edge={0,.16,.36,.16,0}
for i=0,32 do
 local a=i/32
 -- These are internal joins in one closed front, not four separate streaks.
 -- Fade the complete circle over time without exposing its construction seams.
 opacity[i]=NumberSequence.new({NumberSequenceKeypoint.new(0,1-a),NumberSequenceKeypoint.new(1,1-a)})
 gradientOpacity[i]={}
 for arc=1,4 do
  local fade=(1-a)*a
  gradientOpacity[i][arc]=NumberSequence.new(1-a+edge[arc]*fade,1-a+edge[arc+1]*fade)
 end
end
function Plane.create(parent,color)
 local f={rays={},color=color}
 for i=1,4 do
  local a=Instance.new('Attachment');a.Name='PlanarReleaseFrom';a.Parent=parent
  local b=Instance.new('Attachment');b.Name='PlanarReleaseTo';b.Parent=parent
  local beam=Instance.new('Beam');beam.Name='PlanarRelease';beam.Attachment0=a;beam.Attachment1=b
  beam.FaceCamera=false;beam.Segments=12;beam.LightEmission=1;beam.LightInfluence=0
  beam.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.45));beam.Enabled=false;beam.Parent=parent
  f.rays[i]={a=a,b=b,beam=beam}
 end
 return f
end
function Plane.hide(f) for _,r in ipairs(f.rays) do r.beam.Enabled=false end end
function Plane.destroy(f)
 for _,r in ipairs(f.rays) do r.a:Destroy();r.b:Destroy();r.beam:Destroy() end
end
-- Shared circular geometry for shock fronts, contracting telegraphs and wells.
-- Radius is sampled by the owning timeline; the four tangents never rotate.
function Plane.pose(f,normal,reach,strength,width,colorProgress)
 if strength<=.008 or reach<=.001 then Plane.hide(f);return end
 local ref=math.abs(normal.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local right=normal:Cross(ref).Unit;local up=right:Cross(normal).Unit
 local level=math.floor(math.clamp(strength,0,1)*32+.5)
 local change=colorProgress~=f.colorProgress
 if change then f.colorProgress=colorProgress end
 for i,r in ipairs(f.rays) do
  local angle=(i-1)*math.pi/2
  local radial0=right*math.cos(angle)+up*math.sin(angle)
  local radial1=right*math.cos(angle+math.pi/2)+up*math.sin(angle+math.pi/2)
  local tangent0=-right*math.sin(angle)+up*math.cos(angle)
  local tangent1=-right*math.sin(angle+math.pi/2)+up*math.cos(angle+math.pi/2)
  r.a.CFrame=CFrame.fromMatrix(radial0*reach,tangent0,radial0,tangent0:Cross(radial0))
  r.b.CFrame=CFrame.fromMatrix(radial1*reach,tangent1,radial1,tangent1:Cross(radial1))
  r.beam.CurveSize0=reach*.55228475;r.beam.CurveSize1=reach*.55228475
  r.beam.Width0=width;r.beam.Width1=width
  r.beam.Transparency=colorProgress and gradientOpacity[level][i] or opacity[level]
  if change then
   if colorProgress then
    local tint=f.color:Lerp(WHITE,.16)
    local first=tint:Lerp(DARK,edge[i])
    local last=tint:Lerp(DARK,edge[i+1])
    r.beam.Color=ColorSequence.new(WHITE:Lerp(first,colorProgress),WHITE:Lerp(last,colorProgress))
   else
    r.beam.Color=ColorSequence.new(f.color:Lerp(WHITE,.45))
   end
  end
  r.beam.Enabled=strength>.008
 end
end
function Plane.draw(f,normal,t,scale,gradient,reducedFlash)
 if not t or t<0 or t>=1 then Plane.hide(f);return end
 local reach=(.12+1.75*(1-math.exp(-t*40))+.65*t)*scale
 local strength=(1-t)^.8
 local colorProgress
 if gradient then
  strength=(1-t*t)^2
  colorProgress=math.floor(math.min(1,t*3)*12+.5)/12
  if reducedFlash then strength*=.5;colorProgress=math.max(.65,colorProgress) end
 end
 Plane.pose(f,normal,reach,strength,(.08+.22*(1-t))*scale,colorProgress)
end
return Plane
