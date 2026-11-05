-- Local, bounded laser-startup visuals. No gameplay, remotes, random seeds, or delayed tasks.
-- The client samples server time, so a late join resumes the current phase without a fresh flash.
local FX={}
local TAU=math.pi*2
local palettes={Stars=Color3.fromRGB(105,224,255),Ignition=Color3.fromRGB(255,179,77),Coil=Color3.fromRGB(182,137,255)}
FX.MaxActive=4 -- Shared with refraction rigs by BeamVFX.
FX.MaxDistance=110
local opacities={}
local arcOpacities={}
for i=0,32 do
 opacities[i]=NumberSequence.new(1-i/32)
 local alpha=i/32
 arcOpacities[i]=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,1-alpha),NumberSequenceKeypoint.new(.75,1-alpha*.8),NumberSequenceKeypoint.new(1,1)})
end
local function attachment(root)
 local a=Instance.new('Attachment');a.Parent=root;return a
end
local function line(root,color)
 local a,b=attachment(root),attachment(root)
 local beam=Instance.new('Beam');beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Segments=1;beam.LightEmission=1;beam.LightInfluence=0
 beam.Color=ColorSequence.new(color);beam.Transparency=NumberSequence.new(1)
 beam.Enabled=false;beam.Parent=root
 return {a=a,b=b,beam=beam}
end
local function draw(l,a,b,width,alpha)
 local enabled=alpha>.01
 if l.beam.Enabled~=enabled then l.beam.Enabled=enabled end
 if not l.beam.Enabled then return end
 l.a.Position=a;l.b.Position=b;l.beam.Width0=width;l.beam.Width1=width*.4
 local opacity=math.floor(math.clamp(alpha,0,1)*32+.5)
 if l.opacity~=opacity then l.opacity=opacity;l.beam.Transparency=opacities[opacity] end
end
local function glint(root,color)
 local g={rays={}}
 for i=1,4 do
  local l=line(root,Color3.new(1,1,1));l.beam.Name='ChargeStar'
  g.rays[i]=l
 end
 return g
end
local function flash(g,pos,size,alpha,rotation)
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 local a=math.rad(rotation);local x=right*math.cos(a)+up*math.sin(a)
 local y=up*math.cos(a)-right*math.sin(a)
 for i,l in ipairs(g.rays) do
  local axis=i==1 and x or i==2 and y or i==3 and -x or -y
  draw(l,pos,pos+axis*size*(i%2==1 and 1 or .8),size*.46,alpha)
  l.beam.Width1=0
 end
end
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function pose(a,position,tangent)
 local ref=math.abs(tangent.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=tangent:Cross(ref).Unit
 a.CFrame=CFrame.fromMatrix(position,tangent,back:Cross(tangent).Unit,back)
end
local function arc(l,a,b,ta,tb,bend,width,alpha)
 draw(l,a,b,width,alpha)
 if not l.beam.Enabled then return end
 l.beam.Segments=12
 pose(l.a,a,ta);pose(l.b,b,tb)
 l.beam.CurveSize0=bend;l.beam.CurveSize1=bend;l.beam.Width1=0
 local opacity=math.floor(math.clamp(alpha,0,1)*32+.5)
 if l.arcOpacity~=opacity then l.arcOpacity=opacity;l.beam.Transparency=arcOpacities[opacity] end
end
local function pulse(p,start,duration)
 local t=(p-start)/duration
 if t<=0 or t>=1 then return 0 end
 return math.sin(t*math.pi)^2
end
function FX.create(parent,style,seed)
 style=palettes[style] and style or 'Stars'
 local root=Instance.new('Part');root.Name='LaserStartup_'..style
 root.Anchored=true;root.Transparency=1;root.Size=Vector3.new(.05,.05,.05)
 root.CanCollide=false;root.CanTouch=false;root.CanQuery=false;root.CastShadow=false;root.Parent=parent
 local f={root=root,style=style,phase=seed*2.399963,arcs={},rays={},glints={}}
 for i=1,12 do f.arcs[i]=line(root,palettes[style]) end
 for i=1,6 do f.rays[i]=line(root,palettes[style]) end
 for i=1,3 do f.glints[i]=glint(root,palettes[style]) end
 -- Reuse the same bounded curves as broad dark lobes plus luminous rims.
 if style~='Ignition' then
  for i=1,6 do f.arcs[i].beam.Color=ColorSequence.new(Color3.fromRGB(8,12,28));f.arcs[i].beam.LightEmission=0 end
 end
 return f
end
function FX.hide(f)
 f.root.Transparency=1
 for _,l in ipairs(f.arcs) do l.beam.Enabled=false end
 for _,l in ipairs(f.rays) do l.beam.Enabled=false end
 for _,g in ipairs(f.glints) do for _,l in ipairs(g.rays) do l.beam.Enabled=false end end
end
function FX.destroy(f)
 f.root:Destroy()
end
function FX.update(f,pose,p)
 f.root.CFrame=CFrame.new(pose.Position)
 f.root.Transparency=1
 -- First supplied animation: four separated central flashes, then a decisive
 -- expanding sweep. The exact same star silhouette returns at larger scale.
 -- Absolute phase sampling also lets late observers enter without replaying it.
 local fade=math.min(1,p/.1,(1-p)/.16)
 local turn=f.phase+smooth(p)*2.4
 local collapse=1-.5*math.clamp((p-.72)/.28,0,1)
 local radius=(2.4-.45*p)*collapse
 if f.style=='Stars' then
  local burst=smooth((p-.72)/.065)
  local settle=smooth((p-.81)/.19)
  local ring=(1.1+3.6*burst)*(1-.22*settle)
  for i,l in ipairs(f.arcs) do
   local lane=(i-1)%6;local angle=2.4*smooth(p)+lane*TAU/3
   local r=ring*(lane<3 and 1 or .72);local height=lane<3 and -.35 or .6
   local function pt(t) return Vector3.new(math.cos(t)*r,height+math.sin(t*2)*.35,math.sin(t)*r) end
   local function tangent(t) return Vector3.new(-math.sin(t),0,math.cos(t)) end
   arc(l,pt(angle),pt(angle+2.1),tangent(angle),tangent(angle+2.1),r*.85,
    (i<=6 and .65 or .22)*burst*(1-smooth((p-.91)/.09)),burst*(1-smooth((p-.91)/.09))*(i<=6 and .6 or 1))
  end
  local pop=0
  for i=0,3 do pop=math.max(pop,pulse(p,.025+i*.175,.11)*(1+i*.12)) end
  flash(f.glints[1],Vector3.zero,.35+1.6*pop,math.min(1,pop),-12+60*smooth(p))
  local reuse=smooth((p-.79)/.055)*(1-smooth((p-.93)/.07))
  flash(f.glints[2],Vector3.new(0,ring*.85,0),1.65*reuse,reuse,0)
  local angle=2.4*smooth(p)+.7
  flash(f.glints[3],Vector3.new(math.cos(angle)*ring,-.35,math.sin(angle)*ring),1.45*reuse,reuse,0)
 elseif f.style=='Ignition' then
  -- Three tapered curved sweeps with continuous eased travel, no polygon cage.
  for i,l in ipairs(f.arcs) do
   local lane=(i-1)%3
   local a=turn+lane*TAU/3;local b=a+1.55
   local r=radius*(i<=6 and 1 or .72)
   local function point(t) return Vector3.new(math.cos(t)*r,-.65,math.sin(t)*r) end
   local function tangent(t) return Vector3.new(-math.sin(t),0,math.cos(t)) end
   arc(l,point(a),point(b),tangent(a),tangent(b),r*.55,
    i<=3 and .18 or .055,fade*(i<=3 and .8 or .25))
  end
  for i,g in ipairs(f.glints) do
   local pop=pulse(p,.1+(i-1)*.23,.2)
   flash(g,Vector3.new(0,-.2,0),.25+pop*.65,pop*.55,i*30)
  end
 else
  -- Three smooth tightening spirals with dark bodies and bright edges, instead
  -- of a six-segment wire helix. Radius surges once before snapping inward.
  local surge=smooth((p-.64)/.12);local snap=smooth((p-.91)/.09)
  local r=(3.8-1.3*p+1.8*surge)*(1-.8*snap)
  local power=smooth(p/.12)*(1-snap)
  f.root.Shape=Enum.PartType.Ball;f.root.Material=Enum.Material.SmoothPlastic
  f.root.Color=Color3.fromRGB(17,8,35);f.root.Size=Vector3.one*(.2+(1.5+surge*1.4)*(1-snap))
  f.root.Transparency=1-power
  for i,l in ipairs(f.arcs) do
   local lane=(i-1)%6;local angle=3.6*smooth(p)+lane*TAU/3
   local rr=r*(lane<3 and 1 or .65);local y=lane<3 and -1.1 or 1.5
   local a=Vector3.new(math.cos(angle)*rr,y,math.sin(angle)*rr)
   local b=Vector3.new(math.cos(angle+2.6)*rr*.3,y*.2,math.sin(angle+2.6)*rr*.3)
   local ta=Vector3.new(-math.sin(angle),.15,math.cos(angle)).Unit
   local tb=Vector3.new(-math.sin(angle+2.6),-.2,math.cos(angle+2.6)).Unit
   arc(l,a,b,ta,tb,rr*1.25,(i<=6 and 1.3 or .26)*power,power)
  end
  for i,g in ipairs(f.glints) do
   local angle=3.6*smooth(p)+(i-1)*TAU/3
   flash(g,Vector3.new(math.cos(angle)*r,-.5,math.sin(angle)*r),.45+.55*surge,power*.8,0)
  end
 end
 -- A restrained finishing pulse. Ignition sparks travel inward; the other styles flare outward.
 local finish=pulse(p,.72,.28)
 for i,l in ipairs(f.rays) do
  local a=f.phase+(i-1)*TAU/6
  local t=math.clamp((p-.72)/.28,0,1)
  local inner,outer=1+t*5,1.6+t*5
  if f.style=='Ignition' then
   local t=smooth(math.clamp((p-(i-1)*.045)/.75,0,1));inner=.08+(1-t)*2.3;outer=inner+.4*(1-t)
  end
  local function point(r) return Vector3.new(math.cos(a)*r,math.sin(a*2)*.3,math.sin(a)*r) end
  draw(l,point(inner),point(outer),.12, f.style=='Ignition' and fade*.75 or finish*.8)
 end
end
return FX
