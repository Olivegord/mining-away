-- Four cubic quadrants make one expanding circular sheet in the shot plane.
-- The circle expands and fades; its attachments never orbit or face the camera.
local Plane={}
local opacity={}
for i=0,32 do
 local a=i/32
 -- These are internal joins in one closed front, not four separate streaks.
 -- Fade the complete circle over time without exposing its construction seams.
 opacity[i]=NumberSequence.new({NumberSequenceKeypoint.new(0,1-a),NumberSequenceKeypoint.new(1,1-a)})
end
function Plane.create(parent,color)
 local f={rays={}}
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
function Plane.pose(f,normal,reach,strength,width)
 if strength<=.008 or reach<=.001 then Plane.hide(f);return end
 local ref=math.abs(normal.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local right=normal:Cross(ref).Unit;local up=right:Cross(normal).Unit
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
  r.beam.Transparency=opacity[math.floor(math.clamp(strength,0,1)*32+.5)]
  r.beam.Enabled=strength>.008
 end
end
function Plane.draw(f,normal,t,scale)
 if not t or t<0 or t>=1 then Plane.hide(f);return end
 local reach=(.12+1.75*(1-math.exp(-t*40))+.65*t)*scale
 Plane.pose(f,normal,reach,(1-t)^.8,(.08+.22*(1-t))*scale)
end
return Plane
