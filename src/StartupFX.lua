-- The supplied clip's inward streams, compact charge glint and flat release.
-- This shares the same force-sampled paths as the regular laser's charge.
local FX={MaxActive=4,MaxDistance=110}
local palettes={Stars=Color3.fromRGB(105,224,255),Ignition=Color3.fromRGB(255,179,77),Coil=Color3.fromRGB(182,137,255)}
local fades={}
for i=0,32 do fades[i]=NumberSequence.new(1-i/32) end
local function line(root,color)
 local a=Instance.new('Attachment');a.Parent=root
 local b=Instance.new('Attachment');b.Parent=root
 local beam=Instance.new('Beam');beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Segments=8;beam.LightEmission=1;beam.LightInfluence=0
 beam.Color=ColorSequence.new(color);beam.Enabled=false;beam.Parent=root
 return {a=a,b=b,beam=beam}
end
local function pose(a,p,tangent)
 local ref=math.abs(tangent.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=tangent:Cross(ref).Unit
 a.CFrame=CFrame.fromMatrix(p,tangent,back:Cross(tangent).Unit,back)
end
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function FX.create(parent,style,seed)
 local color=palettes[style] or palettes.Coil
 local root=Instance.new('Part');root.Name='LaserStartup_'..style
 root.Anchored=true;root.Transparency=1;root.Size=Vector3.one*.025
 root.CanCollide=false;root.CanTouch=false;root.CanQuery=false;root.CastShadow=false;root.Parent=parent
 local f={root=root,style=style,arcs={},rays={},glints={{rays={}}},plane=PlaneBurst.create(root,color)}
 for i=1,8 do f.arcs[i]=line(root,color);f.rays[i]=line(root,Color3.new(1,1,1));f.rays[i].beam.Segments=1 end
 for i=1,4 do f.glints[1].rays[i]=line(root,Color3.new(1,1,1));f.glints[1].rays[i].beam.Segments=1 end
 return f
end
function FX.hide(f)
 f.root.Transparency=1;PlaneBurst.hide(f.plane)
 for _,l in ipairs(f.arcs) do l.beam.Enabled=false end
 for _,l in ipairs(f.rays) do l.beam.Enabled=false end
 for _,g in ipairs(f.glints) do for _,l in ipairs(g.rays) do l.beam.Enabled=false end end
end
function FX.destroy(f) f.root:Destroy() end
function FX.update(f,origin,q)
 f.root.CFrame=CFrame.new(origin.Position)
 for i,l in ipairs(f.arcs) do
  local a,va,captured=PullMotion.sample(i,q)
  local b,vb=PullMotion.sample(i,math.max(0,q-.13))
  local alpha=smooth(q/.035)*(1-smooth((q-captured+.035)/.035))
  local span=(b-a).Magnitude
  l.beam.Enabled=alpha>.01 and span>.002 and va.Magnitude>.01 and vb.Magnitude>.01
  local head=f.rays[i];head.beam.Enabled=l.beam.Enabled
  if l.beam.Enabled then
   pose(l.a,a*.62,-va.Unit);pose(l.b,b*.62,-vb.Unit)
   l.beam.CurveSize0=span*.62/3;l.beam.CurveSize1=span*.62/3
   l.beam.Width0=.065*alpha;l.beam.Width1=0;l.beam.Transparency=fades[math.floor(alpha*32+.5)]
   head.a.Position=a*.62;head.b.Position=(a-va.Unit*.075)*.62
   head.beam.Width0=.09*alpha;head.beam.Width1=0;head.beam.Transparency=fades[math.floor(alpha*32+.5)]
  end
 end
 -- One central glint, increasing as the inward streams are consumed.
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 local light=smooth((q-.38)/.48)*(1-smooth((q-.9)/.1))
 for i,l in ipairs(f.glints[1].rays) do
  local axis=i==1 and right or i==2 and up or i==3 and -right or -up
  l.a.Position=Vector3.zero;l.b.Position=axis*(.12+.24*light)
  l.beam.Width0=.055*light;l.beam.Width1=0;l.beam.Enabled=light>.01
  l.beam.Transparency=fades[math.floor(light*32+.5)]
 end
 PlaneBurst.draw(f.plane,-Vector3.yAxis,(q-.86)/.14,.8)
end
return FX
