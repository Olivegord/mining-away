-- Local, bounded laser-startup visuals. No gameplay, remotes, random seeds, or delayed tasks.
-- The client samples server time, so a late join resumes the current phase without a fresh flash.
local FX={}
local TAU=math.pi*2
local palettes={Stars=Color3.fromRGB(105,224,255),Ignition=Color3.fromRGB(255,179,77),Coil=Color3.fromRGB(182,137,255)}
FX.MaxActive=4 -- Shared with refraction rigs by BeamVFX.
FX.MaxDistance=110
local opacities={}
for i=0,32 do opacities[i]=NumberSequence.new(1-i/32) end
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
 local a=attachment(root)
 local gui=Instance.new('BillboardGui');gui.Name='StartupGlint';gui.Adornee=a
 gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.Brightness=1.5;gui.MaxDistance=FX.MaxDistance;gui.Parent=root
 local function sprite(texture,tint)
  local i=Instance.new('ImageLabel');i.BackgroundTransparency=1;i.Size=UDim2.fromScale(1,1)
  i.Image=texture;i.ImageColor3=tint;i.ImageTransparency=1;i.Parent=gui;return i
 end
 local glow=sprite('rbxasset://textures/particles/flare_main.dds',color)
 local star=sprite('rbxasset://textures/particles/sparkles_main.dds',Color3.new(1,1,1))
 return {a=a,gui=gui,star=star,glow=glow}
end
local function flash(g,pos,size,alpha,rotation)
 g.a.Position=pos;g.gui.Enabled=alpha>.01;g.gui.Size=UDim2.fromScale(size,size)
 g.star.ImageTransparency=1-alpha;g.star.Rotation=rotation
 g.glow.ImageTransparency=1-alpha*.3
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
 return f
end
function FX.destroy(f)
 f.root:Destroy()
end
function FX.update(f,pose,p)
 f.root.CFrame=CFrame.new(pose.Position)
 -- Small enough to preserve the hull silhouette; fade out before the active beam takes over.
 local fade=math.min(1,p/.1,(1-p)/.16)
 local turn=f.phase+p*TAU*1.2
 local collapse=1-.5*math.clamp((p-.72)/.28,0,1)
 local radius=(2.4-.45*p)*collapse
 if f.style=='Stars' then
  -- Two cyan crescents and three individually timed white four-point flashes.
  for i,l in ipairs(f.arcs) do
   local segment=(i-1)%6;local side=math.floor((i-1)/6)*math.pi
   local a=turn+side+segment*.2;local b=a+.22
   local function point(t) return Vector3.new(math.cos(t)*radius,math.sin(t)*.45,math.sin(t)*radius) end
   draw(l,point(a),point(b),.035+.05*segment/5,fade*(.25+.65*segment/5))
  end
  for i,g in ipairs(f.glints) do
   local a=turn*.45+(i-1)*TAU/3
   local pop=pulse(p,.04+(i-1)*.27,.25)
   local pos=Vector3.new(math.cos(a)*radius,i==1 and 1.85 or .15,math.sin(a)*radius)
   flash(g,pos,.3+pop*1.45,pop,0)
  end
 elseif f.style=='Ignition' then
  -- An amber turbine: a level segmented ring tightens as six sparks pull into the emitter.
  for i,l in ipairs(f.arcs) do
   local a=turn+(i-1)*TAU/12;local b=a+.32
   local function point(t) return Vector3.new(math.cos(t)*radius,-.65,math.sin(t)*radius) end
   draw(l,point(a),point(b),.065,fade*(.45+.35*p))
  end
  for i,g in ipairs(f.glints) do
   local pop=pulse(p,.1+(i-1)*.23,.2)
   flash(g,Vector3.new(0,-.2,0),.25+pop*.65,pop*.55,i*30)
  end
 else
  -- A violet double helix, visibly different from the star/turbine styles.
  for i,l in ipairs(f.arcs) do
   local segment=(i-1)%6;local side=math.floor((i-1)/6)*math.pi
   local t=segment/6
   local function point(v)
    local a=turn+side+v*TAU
    return Vector3.new(math.cos(a)*radius*.7,(v-.5)*3,math.sin(a)*radius*.7)
   end
   draw(l,point(t),point(t+1/6),.055,fade*(.45+.35*t))
  end
  for i,g in ipairs(f.glints) do
   local a=turn+(i-1)*TAU/3;local pop=pulse(p,.08+(i-1)*.25,.24)
   flash(g,Vector3.new(math.cos(a)*radius*.7,(i-2)*.9,math.sin(a)*radius*.7),.2+pop*.65,pop*.65,45)
  end
 end
 -- A restrained finishing pulse. Ignition sparks travel inward; the other styles flare outward.
 local finish=pulse(p,.77,.22)
 for i,l in ipairs(f.rays) do
  local a=f.phase+(i-1)*TAU/6
  local inner,outer=.6+finish*.55,1+finish*1.5
  if f.style=='Ignition' then
   local t=(p*2+(i-1)/6)%1;inner=.3+(1-t)*1.7;outer=inner+.4
  end
  local function point(r) return Vector3.new(math.cos(a)*r,math.sin(a*2)*.3,math.sin(a)*r) end
  draw(l,point(inner),point(outer),.055, f.style=='Ignition' and fade*.75 or finish*.8)
 end
end
return FX
