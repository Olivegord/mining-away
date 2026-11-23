-- Three hand-painted attacks from the owner's references (Nov 22):
--  * Crescent (Gridcutter slot): a moon-shaped slash cuts the rock at an
--    angle. Blue-violet at the trailing tip through lilac and pink to a
--    peach-white leading edge, cloud-shaped bites out of its inner edge and
--    a few full gaps near the tail, a soft rim glow on the bright side and
--    little four-point stars shed off that edge.
--  * Starfall (Starforge slot): a star with a lens flare meanders to the rock
--    on a feathery trail; its impact is a small, blue, toned-down replay of
--    the VERSION 2 Pressure Strike.
--  * Stormcaller (Resonator slot): living lightning. Not a stack of jagged
--    beams: a few long strokes with sharp elbows that keep drifting while it
--    holds, flaring wide at each bend, a torn white core inside a violet rim
--    in a deep blue glow, ending in a white electric crown where it bites.
-- Shapes are painted once per client into EditableImages, shown through
-- SurfaceGui/BillboardGui images (unlit, so they glow). Beams do not render
-- an EditableImage (checked in Studio: a TextureContent beam draws a blank
-- sheet), so beams here use plain colors or built-in textures. Without
-- images the crescent and feathers are skipped and the rest still draws.
local Art={}
local TAU=math.pi*2
local C3=Color3.fromRGB
local WHITE=Color3.new(1,1,1)
local GLOW='rbxasset://textures/ui/AvatarExperience/glowLight.png'
local CIRCLE='rbxasset://textures/ui/VR/circleWhite.png'
local SPARKLE='rbxasset://textures/particles/sparkles_main.dds'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
-- The game's approved lens glint (assets/drone-vfx/striated-four-point-glint.png).
local GLINT='rbxassetid://77624818077620'
local function clamp01(x) return x<0 and 0 or (x>1 and 1 or x) end
local function smooth(a,b,x) local t=clamp01((x-a)/(b-a));return t*t*(3-2*t) end
local function lerp(a,b,t) return a+(b-a)*t end

------------------------------------------------------------------ painting
local images,contents,painting={},{},false
local yieldPaint=true
local function paint(name,w,h,fn)
 local ok,img=pcall(function()
  local assets=game:GetService('AssetService')
  local image=assert(assets:CreateEditableImage({Size=Vector2.new(w,h)}))
  local buf=buffer.create(w*h*4)
  for y=0,h-1 do
   local v=(y+.5)/h
   for x=0,w-1 do
    local r,g,b,a=fn((x+.5)/w,v)
    local o=(y*w+x)*4
    buffer.writeu8(buf,o,math.floor(clamp01(r)*255+.5));buffer.writeu8(buf,o+1,math.floor(clamp01(g)*255+.5))
    buffer.writeu8(buf,o+2,math.floor(clamp01(b)*255+.5));buffer.writeu8(buf,o+3,math.floor(clamp01(a)*255+.5))
   end
   if yieldPaint and y%24==23 and task then task.wait() end
  end
  image:WritePixelsBuffer(Vector2.zero,Vector2.new(w,h),buf)
  return image
 end)
 if ok and img then images[name]=img;contents[name]=Content.fromObject(img)
 else Art.failed=Art.failed or {};Art.failed[name]=tostring(img) end
end
function Art.tex(name) return contents[name] end

-- Crescent: an outer circle minus an offset inner one; s runs along the arc
-- from the trailing tip (0) to the leading tip (1), t across it from the
-- inner edge (0) to the outer edge (1).
local STOPS={{0,C3(112,116,226)},{.3,C3(152,126,238)},{.55,C3(214,144,228)},{.78,C3(250,186,206)},{1,C3(255,243,226)}}
local CREAM=C3(255,236,214)
local function gradient(s)
 s=clamp01(s)
 for i=2,#STOPS do
  local a,b=STOPS[i-1],STOPS[i]
  if s<=b[1] then return a[2]:Lerp(b[2],(s-a[1])/(b[1]-a[1])) end
 end
 return STOPS[#STOPS][2]
end
-- bites out of the inner edge {s, half-width, depth (>1 = a full gap)}
local NOTCH={{.09,.04,1.4},{.17,.03,.66},{.28,.055,.6},{.4,.045,.72},{.53,.05,.5},{.67,.032,.48},{.8,.03,.4},{.9,.022,.34}}
-- holes floating inside the arc {s, t, half-width in s, half-width in t}
local HOLES={{.24,.58,.03,.14},{.47,.6,.026,.12},{.62,.7,.02,.09}}
-- k: crescent thickness, H: how far the leading tip has swept, T: how far
-- the trailing end has dissolved, g: how much the gaps have widened.
Art.SLASH_FRAMES={
 {k=.42,H=.42,T=0,g=1,a=1,at=0},{k=.78,H=.74,T=0,g=1,a=1,at=.035},{k=1,H=1.06,T=0,g=1,a=1,at=.07},
 {k=1,H=1.06,T=.16,g=1.35,a=.95,at=.13},{k=.78,H=1.06,T=.42,g=1.8,a=.8,at=.2},{k=.55,H=1.06,T=.7,g=2.4,a=.58,at=.27},
}
Art.SLASH_LIFE=.34
local function slashPixel(f,u,v)
 local x,y=u-.5,v-.5
 local rO=.41
 local ox,oy=-.105*f.k,.095*f.k
 local rI=.41-.018*f.k
 local dO=math.sqrt(x*x+y*y)
 local dI=math.sqrt((x-ox)^2+(y-oy)^2)
 local phiT=math.atan2(-oy,-ox)
 local rel=(math.atan2(y,x)-phiT+math.pi)%TAU-math.pi
 local s=(rel+1.85)/3.7
 local px=1/192
 local inO,outI=rO-dO,dI-rI
 local t=outI/math.max(1e-4,outI+math.max(inO,0))
 local a=clamp01(inO/px+.5)*clamp01(outI/px+.5)
 -- sweep: the leading tip grows in; the tail dissolves in clumps
 local reveal=clamp01((f.H-s)/.05)
 local n=math.noise(u*13,v*13,f.T*4+.3)*.22
 local tail=f.T>0 and clamp01((s-f.T+n)/.07) or 1
 a*=reveal*tail
 for _,b in ipairs(NOTCH) do
  local w=b[2]*f.g
  local q=(s-b[1])/w
  if q>-1 and q<1 then
   local depth=b[3]*math.sqrt(1-q*q)*(.85+.3*f.g/2.4)
   a*=clamp01((t-depth)*28+.5)
  end
 end
 for _,h in ipairs(HOLES) do
  local qs,qt=(s-h[1])/(h[3]*f.g),(t-h[2])/(h[4]*(.7+.3*f.g))
  local d=qs*qs+qt*qt
  if d<1.3 then a*=clamp01((d-1)*6+.5) end
 end
 local col=gradient(s)
 -- the outer rim on the bright side runs to cream; the inner edge stays deeper
 col=col:Lerp(CREAM,.7*smooth(.6,1,t)*smooth(.3,.75,s))
 col=col:Lerp(col:Lerp(C3(70,56,140),.4),(1-smooth(0,.3,t))*.5)
 -- soft glow just outside the bright edge
 if dO>rO then
  local glow=.62*math.exp(-(dO-rO)/.022)*smooth(.28,.8,s)*reveal*tail
  if glow>a then return CREAM.R,CREAM.G*.94,CREAM.B*.92,glow*f.a end
 end
 return col.R,col.G,col.B,a*f.a
end

-- The bolt's end: white blades fanning up out of a small hot orb, with a
-- magenta glow. Three variants flicker.
local CROWNS={
 {{.3,.08,.11},{.74,.3,.085},{.6,.6,.06}},
 {{.38,.06,.1},{.18,.42,.07},{.8,.22,.09}},
 {{.5,.05,.1},{.26,.26,.075},{.78,.46,.07},{.36,.58,.05}},
}
local function crownPixel(blades)
 return function(u,v)
  local bx,by=.5,.84
  local white,glowD=0,1
  for _,b in ipairs(blades) do
   local tx,ty=b[1]-bx,b[2]-by
   local len=math.sqrt(tx*tx+ty*ty)
   local ax,ay=tx/len,ty/len
   local px,py=u-bx,v-by
   local along=clamp01((px*ax+py*ay)/len)
   local perp=math.abs(-px*ay+py*ax)
   local width=b[3]*(1-along)^1.25*(1+.25*math.sin(along*14+b[1]*9))
   local d=perp-width
   white=math.max(white,clamp01(-d*120+.5)*(along<.999 and 1 or 0))
   glowD=math.min(glowD,math.max(d,0)+math.max(0,(px*ax+py*ay)-len))
  end
  local orb=math.exp(-((u-bx)^2+(v-by)^2)/.004)
  local glow=.7*math.exp(-glowD/.045)
  local a=clamp01(math.max(white,orb,glow))
  local col=C3(255,70,210):Lerp(WHITE,clamp01(white+orb*.8))
  if orb>.5 then col=col:Lerp(C3(255,214,176),.5) end
  return col.R,col.G,col.B,a
 end
end

-- Paints everything once, a little per frame, the shapes needed first.
-- sync: paint everything now, without yielding (Edit previews).
function Art.prepare(sync)
 if painting then return end
 painting=true
 if sync then yieldPaint=false end
 local function run()
  for i,f in ipairs(Art.SLASH_FRAMES) do paint('slash'..i,192,192,function(u,v) return slashPixel(f,u,v) end) end
  for i,c in ipairs(CROWNS) do paint('crown'..i,112,112,crownPixel(c)) end
 end
 if task and not sync then task.spawn(run) else run() end
end

------------------------------------------------------------------ helpers
local function holder(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.CastShadow=false;p.Transparency=1;p.Size=Vector3.one*.05;p.Locked=true;p.Parent=parent
 return p
end
local function attach(part,name)
 local a=Instance.new('Attachment');a.Name=name or 'At';a.Parent=part;return a
end
local function beam(part,a0,a1,color,z,face)
 local b=Instance.new('Beam');b.Attachment0=a0;b.Attachment1=a1;b.FaceCamera=face~=false;b.Segments=face==false and 1 or 6
 b.Color=ColorSequence.new(color);b.LightEmission=1;b.LightInfluence=0;b.Brightness=1.4;b.ZOffset=z or 0
 b.TextureSpeed=0;b.TextureLength=1;b.TextureMode=Enum.TextureMode.Stretch;b.Enabled=false;b.Parent=part
 return b
end
local function emitter(parent,texture,colors,size,life,speed,light)
 local e=Instance.new('ParticleEmitter');e.Texture=texture;e.Rate=0;e.Enabled=true
 e.Color=ColorSequence.new(colors[1],colors[2] or colors[1]);e.LightEmission=light or 1;e.LightInfluence=0;e.Brightness=1.5
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size[1]),NumberSequenceKeypoint.new(.3,size[2]),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.7,.2),NumberSequenceKeypoint.new(1,1)})
 e.Lifetime=NumberRange.new(life[1],life[2]);e.Speed=NumberRange.new(speed[1],speed[2]);e.SpreadAngle=Vector2.new(180,180)
 e.Drag=2;e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-90,90)
 -- Designed particles: the global circle swap and randomizer leave them alone.
 e:SetAttribute('Randomized',true);e:SetAttribute('RoleParticle',true)
 e.Parent=parent
 return e
end
local function perpendiculars(dir)
 local ref=math.abs(dir.Y)<.9 and Vector3.yAxis or Vector3.xAxis
 local e1=dir:Cross(ref).Unit
 return e1,dir:Cross(e1).Unit
end

------------------------------------------------------------------ crescent
-- One slash: the crescent turns in a tilted plane through the hit, its lower
-- half inside the rock, a bright seam where it crosses the surface.
function Art.newSlash(parent)
 local sheet=holder(parent,'CrescentSlash')
 local rig={host=sheet,at=-10,idle=true,images={}}
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
  local gui=Instance.new('SurfaceGui');gui.Face=face;gui.LightInfluence=0;gui.Brightness=1.5;gui.AlwaysOnTop=false
  gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=Vector2.new(256,256);gui.ClipsDescendants=false;gui.Enabled=false
  gui.ResetOnSpawn=false;gui.Adornee=sheet
  local img=Instance.new('ImageLabel');img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.Parent=gui
  gui.Parent=sheet
  table.insert(rig.images,{gui=gui,img=img})
 end
 local seam=Instance.new('Part');seam.Name='CrescentSeam';seam.Anchored=true;seam.CanCollide=false;seam.CanTouch=false;seam.CanQuery=false
 seam.CastShadow=false;seam.Material=Enum.Material.Neon;seam.Transparency=1;seam.Size=Vector3.one*.05;seam.Parent=sheet
 rig.seam=seam
 rig.sparkAt=attach(sheet,'Sparks')
 rig.sparks=emitter(rig.sparkAt,SPARKLE,{C3(255,236,190),C3(255,170,214)},{.12,.34},{.45,.95},{.4,1.6})
 rig.sparks.Acceleration=Vector3.new(0,1.2,0)
 return rig
end
-- dir: horizontal cut direction; tilt: radians the plane leans from upright
-- (sign picks the side); size: studs across.
function Art.fireSlash(rig,hit,dir,tilt,size,now,owned)
 dir=Vector3.new(dir.X,0,dir.Z)
 dir=dir.Magnitude>1e-3 and dir.Unit or Vector3.xAxis
 local side=dir:Cross(Vector3.yAxis).Unit
 local up=(Vector3.yAxis*math.cos(tilt)+side*math.sin(tilt)).Unit
 rig.dir,rig.up,rig.normal,rig.size=dir,up,dir:Cross(up).Unit,size
 rig.center=hit+up*(size*.24)
 rig.hit=hit;rig.at=now;rig.idle=false;rig.frame=0;rig.sparked=0;rig.owned=owned
 rig.spin=(math.random()<.5 and -1 or 1)
 Art.stepSlash(rig,now)
end
function Art.stepSlash(rig,now)
 if rig.idle then return false end
 local t=now-rig.at
 if t>=Art.SLASH_LIFE then
  rig.idle=true;rig.seam.Transparency=1
  for _,v in ipairs(rig.images) do v.gui.Enabled=false end
  return false
 end
 local index=1
 for i,f in ipairs(Art.SLASH_FRAMES) do if t>=f.at then index=i end end
 local tex=Art.tex('slash'..index)
 if index~=rig.frame then
  rig.frame=index
  for _,v in ipairs(rig.images) do
   v.gui.Enabled=tex~=nil
   if tex then v.img.ImageContent=tex end
  end
 end
 -- the sheet keeps turning a little through the cut
 local turn=rig.spin*math.rad(-14+30*smooth(0,Art.SLASH_LIFE,t))
 local L=rig.size
 local frame=CFrame.fromMatrix(rig.center,rig.dir,rig.up)*CFrame.Angles(0,0,turn)
 rig.host.Size=Vector3.new(L,L,.05)
 rig.host.CFrame=frame
 -- the seam on the surface: grows with the sweep, then cools
 local grow=smooth(0,.09,t)
 local cool=smooth(.1,Art.SLASH_LIFE,t)
 rig.seam.Transparency=.1+.9*cool
 rig.seam.Color=C3(214,160,255):Lerp(CREAM,.6*(1-cool))
 rig.seam.Size=Vector3.new(math.max(.05,L*.72*grow),.05,.11*(1-.6*cool))
 rig.seam.CFrame=CFrame.fromMatrix(rig.hit+Vector3.yAxis*.05,rig.dir,Vector3.yAxis)
 -- little stars shed off the bright edge while the slash is full
 if t>.06 and t<.24 and rig.sparked<9 then
  local want=math.floor((t-.06)/.18*9)
  while rig.sparked<want do
   rig.sparked+=1
   local s=.45+.55*math.random()
   local a=math.atan2(-.095,.105)+(s*3.7-1.85)
   local r=L*(.41+.03*math.random())
   -- image x runs along the sheet's X, image y down its Y
   rig.sparkAt.WorldPosition=frame:PointToWorldSpace(Vector3.new(math.cos(a)*r,-math.sin(a)*r,0))
   rig.sparks:Emit(1)
  end
 end
 return true
end

------------------------------------------------------------------ lightning
local BOLT={JOINTS=5,LIFE=.5,GROW=.07,HOLD=.36,WIDTH=.5,
 CORE=WHITE,RIM=C3(158,52,255),GLOW=C3(46,40,255),FORK=C3(196,120,255)}
Art.BOLT=BOLT
function Art.newBolt(parent)
 local host=holder(parent,'LivingBolt')
 local rig={host=host,joints={},mids={},layers={},at=-10,idle=true}
 for i=1,BOLT.JOINTS do rig.joints[i]=attach(host,'J'..i) end
 for i=1,BOLT.JOINTS-1 do rig.mids[i]=attach(host,'M'..i) end
 -- each segment is two halves (joint to middle, middle to joint) so it can
 -- flare wide at the elbows and pinch between them
 local function layer(color,z,texture)
  local list={}
  for i=1,BOLT.JOINTS-1 do
   local a=beam(host,rig.joints[i],rig.mids[i],color,z);local b=beam(host,rig.mids[i],rig.joints[i+1],color,z)
   if texture then a.Texture=texture;b.Texture=texture end
   list[#list+1]=a;list[#list+1]=b
  end
  return list
 end
 rig.glow=layer(BOLT.GLOW,0,GLOW)
 rig.rim=layer(BOLT.RIM,.01)
 rig.core=layer(BOLT.CORE,.02)
 for _,b in ipairs(rig.glow) do b.LightEmission=1;b.Brightness=1.2 end
 for _,b in ipairs(rig.rim) do b.LightEmission=.7;b.Brightness=1.6 end
 for _,b in ipairs(rig.core) do b.LightEmission=.4;b.Brightness=2 end
 -- round caps at the bends so the strokes join cleanly
 rig.caps={}
 for i=2,BOLT.JOINTS-1 do
  local function disc(color,size,z)
   local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromScale(size,size);gui.LightInfluence=0;gui.Brightness=1.6;gui.Enabled=false
   gui.Adornee=rig.joints[i];gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
   local img=Instance.new('ImageLabel');img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.Image=CIRCLE;img.ImageColor3=color;img.ZIndex=z;img.Parent=gui
   gui.Parent=rig.joints[i]
   return gui,img
  end
  local rimGui,rimImg=disc(BOLT.RIM,1,1)
  local coreGui,coreImg=disc(BOLT.CORE,1,2)
  rig.caps[i]={rim=rimGui,rimImg=rimImg,core=coreGui,coreImg=coreImg}
 end
 rig.forkA,rig.forkM,rig.forkB=attach(host,'FA'),attach(host,'FM'),attach(host,'FB')
 rig.fork={beam(host,rig.forkA,rig.forkM,BOLT.FORK,.01),beam(host,rig.forkM,rig.forkB,BOLT.FORK,.01)}
 -- the crown where it bites
 local crownAt=attach(host,'Crown')
 local gui=Instance.new('BillboardGui');gui.Name='Crown';gui.Size=UDim2.fromScale(3,3);gui.LightInfluence=0;gui.Brightness=2.2
 gui.AlwaysOnTop=false;gui.Enabled=false;gui.Adornee=crownAt;gui.ResetOnSpawn=false
 local img=Instance.new('ImageLabel');img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.Image=GLOW;img.ImageColor3=C3(255,120,230);img.Parent=gui
 gui.Parent=crownAt
 rig.crownAt,rig.crown,rig.crownImg=crownAt,gui,img
 rig.sparkAt=attach(host,'Sparks')
 rig.sparks=emitter(rig.sparkAt,CIRCLE,{C3(255,240,255),C3(170,70,255)},{.12,.2},{.15,.4},{10,22})
 rig.sparks.Drag=4;rig.sparks.Acceleration=Vector3.new(0,-20,0)
 local light=Instance.new('PointLight');light.Color=C3(170,110,255);light.Range=12;light.Brightness=0;light.Shadows=false;light.Parent=rig.sparkAt
 rig.light=light
 return rig
end
-- from: where it leaves the drone; to: where it bites.
function Art.fireBolt(rig,from,to,now,owned,scale)
 local travel=to-from
 local len=travel.Magnitude
 if len<.5 then return end
 local dir=travel/len
 local e1,e2=perpendiculars(dir)
 -- the bends swing across the view, not toward the camera, so they read
 local camera=workspace.CurrentCamera
 if camera then
  local across=dir:Cross(camera.CFrame.LookVector)
  if across.Magnitude>.2 then e1=across.Unit;e2=dir:Cross(e1).Unit end
 end
 rig.from,rig.to,rig.dir,rig.len,rig.e1,rig.e2=from,to,dir,len,e1,e2
 rig.at=now;rig.idle=false;rig.owned=owned;rig.scale=scale or 1;rig.seed=math.random()*100;rig.sparked=false
 -- the bends: long strokes with strong elbows, alternating sides, the last
 -- one hooking into the hit
 rig.base={}
 local sideSign=math.random()<.5 and -1 or 1
 -- few, long strokes: three elbows that swing well out to alternate sides
 local fractions={0,.26,.52,.78,1}
 for i=1,BOLT.JOINTS do
  local f=fractions[i]
  local amp=(i==1 or i==BOLT.JOINTS) and 0 or len*(.17+.1*math.random())*(1-.3*f)
  sideSign=-sideSign
  local twist=(math.random()-.5)*.35
  rig.base[i]={f=f+(i>1 and i<BOLT.JOINTS and (math.random()-.5)*.06 or 0),x=amp*sideSign,y=amp*twist}
 end
 local fs=math.random(2,3)
 rig.forkFrom=fs;rig.forkDir=(e1*(rig.base[fs].x>0 and 1 or -1)+e2*(math.random()-.5)+dir*.5).Unit
 rig.variant=math.random(1,3)
 Art.stepBolt(rig,now)
end
function Art.stepBolt(rig,now)
 if rig.idle then return false end
 local t=now-rig.at
 if t>=BOLT.LIFE then
  rig.idle=true
  for _,list in ipairs({rig.glow,rig.rim,rig.core,rig.fork}) do for _,b in ipairs(list) do b.Enabled=false end end
  rig.crown.Enabled=false;rig.light.Brightness=0
  for _,cap in pairs(rig.caps) do cap.rim.Enabled=false;cap.core.Enabled=false end
  return false
 end
 -- alive: the elbows drift smoothly, sampled at 24 fps so it stays crisp
 local q=math.floor(t*24)/24
 local live=1-smooth(BOLT.HOLD,BOLT.LIFE,t)
 local reach=smooth(0,BOLT.GROW,t)
 local pts={}
 for i,b in ipairs(rig.base) do
  local w=(i==1 or i==#rig.base) and 0 or 1
  local nx=math.noise(q*2.2+rig.seed,i*1.7)*rig.len*.12*w
  local ny=math.noise(i*2.3,q*2.4+rig.seed)*rig.len*.12*w
  -- the strokes keep sliding along a little, like a living thing
  local slide=math.noise(q*2+i,rig.seed)*.025*w
  pts[i]=rig.from+rig.dir*(rig.len*(b.f+slide))+rig.e1*(b.x+nx)+rig.e2*(b.y+ny)
 end
 -- grow down from the drone
 local total=0
 local segs={}
 for i=1,#pts-1 do segs[i]=(pts[i+1]-pts[i]).Magnitude;total+=segs[i] end
 local budget=total*reach
 local shown=#pts
 for i=1,#pts-1 do
  if budget<segs[i] then pts[i+1]=pts[i]:Lerp(pts[i+1],budget/math.max(segs[i],1e-3));shown=i+1;break end
  budget-=segs[i]
 end
 local S=rig.scale
 local thin=lerp(.25,1,live)
 local wobble=1+.12*math.sin(t*61)
 local function bend(i)
  if i<=1 or i>=#pts then return .35 end
  local a=(pts[i]-pts[i-1]);local b=(pts[i+1]-pts[i])
  if a.Magnitude<1e-3 or b.Magnitude<1e-3 then return .5 end
  return clamp01(1-a.Unit:Dot(b.Unit))
 end
 local host=rig.host
 host.CFrame=CFrame.new()
 for i=1,BOLT.JOINTS do rig.joints[i].WorldPosition=pts[math.min(i,shown)] end
 for i=1,BOLT.JOINTS-1 do
  local a,b=pts[math.min(i,shown)],pts[math.min(i+1,shown)]
  local mid=a:Lerp(b,.5)
  rig.mids[i].WorldPosition=mid
  local visible=i<shown
  -- one steady stroke width, tapering a little toward the bite; the bends
  -- get round caps (below) instead of flared plates
  local function width(j) return BOLT.WIDTH*S*(1-.3*(j-1)/(BOLT.JOINTS-1))*thin*wobble end
  local wa,wb=width(i),width(i+1)
  local wm=(wa+wb)/2
  for k,list in ipairs({rig.glow,rig.rim,rig.core}) do
   local mul=k==1 and 3.6 or (k==2 and 1.25 or .55)
   local h1,h2=list[i*2-1],list[i*2]
   h1.Width0=wa*mul;h1.Width1=wm*mul;h2.Width0=wm*mul;h2.Width1=wb*mul
   local fade=k==1 and .45+.4*(1-live) or (1-live)*.85
   if h1.Enabled~=visible then h1.Enabled=visible;h2.Enabled=visible end
   if visible then
    local tr=NumberSequence.new(fade)
    h1.Transparency=tr;h2.Transparency=tr
   end
   -- straight strokes meet at the bends; the drift keeps them alive
   h1.CurveSize0=0;h2.CurveSize1=0
  end
 end
 for i,cap in pairs(rig.caps) do
  local on=i<shown
  cap.rim.Enabled=on;cap.core.Enabled=on
  if on then
   local w=BOLT.WIDTH*S*(1-.3*(i-1)/(BOLT.JOINTS-1))*thin*wobble
   cap.rim.Size=UDim2.fromScale(w*1.25,w*1.25);cap.core.Size=UDim2.fromScale(w*.55,w*.55)
   cap.rimImg.ImageTransparency=(1-live)*.85;cap.coreImg.ImageTransparency=(1-live)*.85
  end
 end
 -- a short fork off one elbow, only while fully alive
 local fi=rig.forkFrom
 local forkOn=t>BOLT.GROW and t<BOLT.HOLD and fi<shown
 rig.fork[1].Enabled=forkOn;rig.fork[2].Enabled=forkOn
 if forkOn then
  local p=pts[fi]
  local flen=rig.len*.22*smooth(BOLT.GROW,BOLT.GROW+.05,t)
  local d=(rig.forkDir+rig.e2*math.noise(q*6,rig.seed)*.4).Unit
  rig.forkA.WorldPosition=p;rig.forkM.WorldPosition=p+d*flen*.55+rig.e1*flen*.12;rig.forkB.WorldPosition=p+d*flen
  local w=BOLT.WIDTH*S*.45*thin
  rig.fork[1].Width0=w;rig.fork[1].Width1=w*.7;rig.fork[2].Width0=w*.7;rig.fork[2].Width1=.02
 end
 -- the crown, the sparks and the light where it bites
 local bit=shown>=#pts and t>=BOLT.GROW
 if bit and not rig.sparked then
  rig.sparked=true
  rig.sparkAt.WorldPosition=rig.to+Vector3.yAxis*.2
  rig.sparks:Emit(rig.owned and 16 or 7)
 end
 rig.crown.Enabled=bit and t<BOLT.HOLD+.06
 if rig.crown.Enabled then
  local pop=smooth(BOLT.GROW,BOLT.GROW+.05,t)*(1-.25*smooth(BOLT.GROW+.05,BOLT.GROW+.12,t))
  local fade=smooth(BOLT.HOLD-.08,BOLT.HOLD+.06,t)
  local size=3.4*S*(.4+.8*pop)
  rig.crown.Size=UDim2.fromScale(size,size)
  rig.crownAt.WorldPosition=rig.to+Vector3.yAxis*size*.32
  local crownKey='crown'..(1+(rig.variant+math.floor(t*14))%3)
  local crown=Art.tex(crownKey)
  if crown and rig.crownKey~=crownKey then
   rig.crownKey=crownKey;rig.crownImg.ImageContent=crown;rig.crownImg.ImageColor3=WHITE
  end
  rig.crownImg.ImageTransparency=fade
 end
 rig.light.Brightness=bit and (rig.owned and 2.4 or 1.2)*(1-smooth(BOLT.GROW,BOLT.HOLD+.1,t))*(1+.3*math.sin(t*90)) or 0
 return true
end

------------------------------------------------------------------ star
-- A star that meanders to the rock: a hot white point with a lens flare in
-- a blue glow, a feathery trail and a scatter of blue sparks behind it.
-- The feather: a sawtooth width along the trail (barbs), tapering to the tail.
local function featherWidth(n,taper)
 local keys={NumberSequenceKeypoint.new(0,.25)}
 for i=1,n do
  local u=i/(n+1)
  local w=(1-u)^taper
  keys[#keys+1]=NumberSequenceKeypoint.new(u-.5/(n+1),w*(.95+.05*math.sin(i*2.7)))
  keys[#keys+1]=NumberSequenceKeypoint.new(u,w*.32)
 end
 keys[#keys+1]=NumberSequenceKeypoint.new(1,0)
 return NumberSequence.new(keys)
end
function Art.newStar(parent)
 local part=holder(parent,'Starfall')
 local a0,a1=attach(part,'TrailA'),attach(part,'TrailB')
 a0.Position=Vector3.new(0,.42,0);a1.Position=Vector3.new(0,-.42,0)
 -- the feathery trail (owner: "a trail with a feathered width curve"):
 -- a wide blue trail whose width saw-tooths into barbs, with a thin white
 -- quill down its middle
 local trail=Instance.new('Trail');trail.Attachment0=a0;trail.Attachment1=a1;trail.FaceCamera=true
 trail.Lifetime=.5;trail.MinLength=.02;trail.LightEmission=.9;trail.LightInfluence=0;trail.Brightness=1.5
 trail.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C3(206,226,255)),ColorSequenceKeypoint.new(.4,C3(110,150,255)),ColorSequenceKeypoint.new(1,C3(60,80,230))})
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.5,.35),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=featherWidth(9,1.2);trail.Enabled=false;trail.Parent=part
 local q0,q1=attach(part,'QuillA'),attach(part,'QuillB')
 q0.Position=Vector3.new(0,.07,0);q1.Position=Vector3.new(0,-.07,0)
 local quill=Instance.new('Trail');quill.Attachment0=q0;quill.Attachment1=q1;quill.FaceCamera=true
 quill.Lifetime=.32;quill.MinLength=.02;quill.LightEmission=1;quill.LightInfluence=0;quill.Brightness=2
 quill.Color=ColorSequence.new(WHITE,C3(170,200,255))
 quill.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
 quill.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)});quill.Enabled=false;quill.Parent=part
 local function board(size,image,color,transparency)
  local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromScale(size,size);gui.LightInfluence=0;gui.Brightness=2;gui.Enabled=false;gui.Adornee=part
  local img=Instance.new('ImageLabel');img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.Image=image;img.ImageColor3=color
  img.ImageTransparency=transparency;img.Parent=gui
  gui.Parent=part
  return gui,img
 end
 local halo,haloImg=board(5,GLOW,C3(70,110,255),.35)
 local flare,flareImg=board(3.4,GLINT,WHITE,0)
 local rig={part=part,trail=trail,quill=quill,halo=halo,haloImg=haloImg,flare=flare,flareImg=flareImg,on=false}
 rig.dots=emitter(part,CIRCLE,{C3(220,236,255),C3(70,110,255)},{.09,.16},{.3,.6},{.3,1.4})
 rig.dots.Rate=0;rig.dots.Drag=3
 rig.twinkle=emitter(part,SPARKLE,{WHITE,C3(120,170,255)},{.15,.3},{.25,.5},{.2,.8})
 local light=Instance.new('PointLight');light.Color=C3(110,150,255);light.Range=7;light.Brightness=0;light.Shadows=false;light.Parent=part
 rig.light=light
 return rig
end
-- The flight path: a swooping cubic from the muzzle to the hit with a
-- slowing wobble across it, fixed per shot by its seed.
function Art.starPath(from,to,seed,u)
 local travel=to-from
 local len=math.max(travel.Magnitude,1)
 local dir=travel/len
 local e1,e2=perpendiculars(dir)
 local a=seed*7.31
 local side=e1*math.cos(a)+e2*math.sin(a)
 local c1=from+travel*.25+side*len*.55+Vector3.yAxis*len*.25
 local c2=from+travel*.8-side*len*.3+Vector3.yAxis*len*.1
 local v=1-u
 local p=from*v*v*v+c1*3*v*v*u+c2*3*v*u*u+to*u*u*u
 local wob=(e1*math.cos(a+1.9)+e2*math.sin(a+1.9))*math.sin(u*TAU*1.5+seed)*len*.06*math.sin(math.pi*u)
 return p+wob
end
function Art.stepStar(rig,from,to,age,windup,flight,seed,now)
 local part=rig.part
 local charging=age<windup
 local u=charging and 0 or clamp01((age-windup)/math.max(flight,1e-3))
 local pos=charging and from or Art.starPath(from,to,seed,u)
 part.CFrame=CFrame.new(pos)
 if not rig.on then
  rig.on=true;rig.halo.Enabled=true;rig.flare.Enabled=true
 end
 local grow=charging and smooth(0,math.max(windup,.05),age) or 1
 local twinkle=1+.12*math.sin(now*37+seed)
 local flareSize=(1.6+3.4*grow)*twinkle
 rig.flare.Size=UDim2.fromScale(flareSize,flareSize)
 rig.halo.Size=UDim2.fromScale(flareSize*1.6,flareSize*1.6)
 rig.flareImg.Rotation=(now*40+seed*90)%360*(charging and 1 or .3)
 rig.trail.Enabled=not charging;rig.quill.Enabled=not charging
 rig.dots.Rate=charging and 6 or 55
 rig.twinkle.Rate=charging and 2 or 9
 rig.light.Brightness=(charging and .4*grow or .8)*twinkle
 return pos
end
function Art.hideStar(rig)
 if not rig.on then return end
 rig.on=false;rig.halo.Enabled=false;rig.flare.Enabled=false;rig.trail.Enabled=false;rig.quill.Enabled=false
 rig.dots.Rate=0;rig.twinkle.Rate=0;rig.light.Brightness=0
end

-- The impact: the VERSION 2 Pressure Strike, small, blue, quick and quiet.
-- Two pooled rigs, moved to each hit (the strike is ~400 instances).
local Strike=require('./PressureStrikeStar')
local IMPACT={SCALE=.15,FROM=.84,TO=1.72,SPEED=1.55,LIGHT=.3}
Art.IMPACT=IMPACT
local impacts={}
function Art.starImpact(parent,at,now,scale)
 if not Strike then return end
 local rig
 for _,r in ipairs(impacts) do if not r.busy then rig=r;break end end
 if not rig then
  if #impacts>=2 then
   rig=impacts[1]
   for _,r in ipairs(impacts) do if r.at<rig.at then rig=r end end
  else
   local ok,made=pcall(Strike.new,parent,CFrame.new(at),IMPACT.SCALE)
   if not ok then return end
   rig={strike=made,at=now,busy=false};table.insert(impacts,rig)
  end
 end
 rig.strike.host.CFrame=CFrame.new(at)
 rig.strike.last=-1
 rig.at=now;rig.busy=true;rig.k=scale or 1
 Art.stepImpacts(now)
end
function Art.stepImpacts(now)
 for _,rig in ipairs(impacts) do
  if rig.busy then
   local t=IMPACT.FROM+(now-rig.at)*IMPACT.SPEED
   if t>=IMPACT.TO then rig.busy=false;rig.strike:Seek(-1)
   else
    rig.strike:Step(t)
    rig.strike.light.Brightness*=IMPACT.LIGHT
   end
  end
 end
end

return Art
