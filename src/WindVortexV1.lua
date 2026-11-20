-- Ground vortex from Wind Moveset at 29.997 s. Cues use source-frame time
-- (60000/1001 fps). A pressure front, ink cut, and debris each have their own clock.
local Vortex = {}
Vortex.duration = 4.05
local NAME = "VERSION 1"
local TAU, FRAME = math.pi*2, 1001/60000
local Y, v = Vector3.yAxis, Vector3.new
local ERUPT, FINISH = 55*FRAME, 175*FRAME
Vortex.editPose = 143.65*FRAME
local function color(r,g,b) return ColorSequence.new(Color3.fromRGB(r,g,b)) end
local PAPER = color(255,247,218)
local PEARL = color(226,224,207)
local INK = color(32,30,29)
local ASH = color(102,92,82)
local RED = color(193,24,13)
local EMBER = color(255,100,32)
local groups = {
 {"Pressure",8}, {"Crown",9}, {"Barbs",16}, {"Talons",21}, {"Column",10},
 {"Skirt",14}, {"Filaments",6}, {"Splinters",10},
}
local GRIT_COUNT, PLATE_COUNT = 26,13
local function sat(x) return math.clamp(x,0,1) end
local function ease(x) return 1-(1-sat(x))^3 end
local function smooth(x) x=sat(x); return x*x*(3-2*x) end
local function noise(i,salt) return (math.sin(i*127.1+salt*311.7)*43758.5453)%1 end
local function polar(a,r,h) return v(math.cos(a)*r,h,math.sin(a)*r) end
local function hide(line)
 line.used=false
 if line.b.Enabled then line.b.Enabled=false end
end

-- Solid, translucent strips join edge to edge; brush strokes feather at the tip.
local solid,brush={},{}
for i=0,40 do
 local a=i/40
 solid[i]=NumberSequence.new(1-a)
 brush[i]=NumberSequence.new({
  NumberSequenceKeypoint.new(0,1-.03*a),NumberSequenceKeypoint.new(.17,1-.93*a),
  NumberSequenceKeypoint.new(.47,1-a),NumberSequenceKeypoint.new(.81,1-.60*a),
  NumberSequenceKeypoint.new(1,1-.01*a),
 })
end
local function basis(p,d,up)
 local x=d.Unit
 local z=x:Cross(up)
 if z.Magnitude<.0001 then z=x:Cross(math.abs(x.Y)>.95 and Vector3.zAxis or Y) end
 z=z.Unit
 return CFrame.fromMatrix(p,x,z:Cross(x),z)
end
local function paint(line,c0,c1,d0,d1,w0,w1,up0,up1,alpha,tint,flat)
 if alpha<.02 then return end
 local b=line.b
 line.used=true
 line.a.CFrame=basis(c0,d0,up0); line.z.CFrame=basis(c1,d1,up1)
 b.CurveSize0=d0.Magnitude; b.CurveSize1=d1.Magnitude
 b.Width0=math.max(.018,w0); b.Width1=math.max(.018,w1)
 if line.flat~=flat then b.FaceCamera=not flat; line.flat=flat; line.level=nil end
 local k=math.floor(sat(alpha)*40+.5)
 if line.level~=k then b.Transparency=(flat and solid or brush)[k]; line.level=k end
 if line.tint~=tint then
  b.Color=tint; b.LightEmission=(tint==INK or tint==ASH or tint==RED) and 0 or .4
  b.LightInfluence=0; b.Brightness=tint==PAPER and 1.42 or 1
  line.tint=tint
 end
 b.Enabled=true
end

-- A strip wraps around the axis. Its two end widths and orientation come
-- from the actual lower and upper lips of the sheet, independent of camera.
local function skin(lines,first,count,spin,arc,edge,alpha,tint)
 if alpha<.02 then return end
 local function section(u)
  local a=spin+arc*u
  local rb,yb,rt,yt,shear=edge(u)
  local lo=polar(a,rb,yb)
  local hi=polar(a+shear,rt,yt)
  return (lo+hi)*.5,hi-lo
 end
 local c0,w0=section(0)
 for j=1,count do
  local u=j/count
  local c1,w1=section(u)
  local mid=section(u-.5/count)
  -- Match the endpoints and midpoint of the curved band with a quadratic,
  -- represented as a cubic Bezier. Keep X perpendicular to the lip span.
  local ctrl=mid*2-(c0+c1)*.5
  local function handle(d,w)
   local n=w.Unit
   local h=d-n*d:Dot(n)
   return h.Magnitude>.0001 and h or d
  end
  paint(lines[first+j-1],c0,c1,handle((ctrl-c0)*2/3,w0),handle((c1-ctrl)*2/3,w1),
   w0.Magnitude,w1.Magnitude,w0,w1,alpha,tint,true)
  c0,w0=c1,w1
 end
end
local function stroke(line,a,b,h0,h1,w0,w1,alpha,tint)
 paint(line,a,b,h0,h1,w0,w1,Y,Y,alpha,tint,false)
end
function Vortex.bind(root)
 local origin=assert(root:FindFirstChild("VortexOrigin"))
 local rig={origin=origin,grit={},plates={},all={},yaw=.34,turn=1,salt=12,calm=false}
 for _,g in ipairs(groups) do
  local lines={}
  for i=1,g[2] do
   local b=assert(origin:FindFirstChild(g[1]..i))
   local line={b=b,a=b.Attachment0,z=b.Attachment1}
   lines[i]=line; table.insert(rig.all,line)
  end
  rig[g[1]]=lines
 end
 for i=1,GRIT_COUNT do rig.grit[i]=assert(root.Debris:FindFirstChild("Chip"..i)) end
 for i=1,PLATE_COUNT do rig.plates[i]=assert(root.Debris:FindFirstChild("Plate"..i)) end
 return rig
end

-- Original repeating brush masks. Across a sheet the pigment breaks into
-- swept slits; along a pressure lip it falls off into a soft inner shoulder.
-- The authored geometry also supplies the silhouette on lower-memory clients.
local function makeMask(assets,pressure)
 local size=96
 local img=assets:CreateEditableImage({Size=Vector2.new(size,size)})
 if not img then return nil end
 local pixels=buffer.create(size*size*4)
 for y=0,size-1 do
  local h=(y+.5)/size
  for x=0,size-1 do
   local u=(x+.5)/size
   local bend=u+.21*h*h+.032*math.sin(h*6+u*TAU)
   local wave=.5+.5*math.sin(TAU*(bend*3+.05*math.sin(TAU*bend)))
   local tooth=.05+.77*wave^5+.105*math.sin(TAU*(bend*7+.11))^8
   local tip=smooth((h-tooth+.07)/.11)
   local notch=.5+.5*math.sin(TAU*(bend*9+.08*math.sin(bend*TAU*3)))
   local score=smooth((notch-.88)/.115)*smooth((h-.19)/.22)*(1-smooth((h-.63)/.33))
   local alpha=tip*(1-.88*score)*smooth((1-h)/.055)
   local tone=1-.36*score-.16*(1-tip)
   if pressure then
    local lip=math.exp(-((h-.76)/.125)^2)
    alpha=(.24*smooth(h/.60)+.76*lip)*smooth((1-h)/.10)
    tone=.96
   end
   local gray=math.floor(tone*255+.5)
   buffer.writeu32(pixels,(y*size+x)*4,gray*65793+math.floor(sat(alpha)*255+.5)*16777216)
  end
 end
 img:WritePixelsBuffer(Vector2.zero,Vector2.new(size,size),pixels)
 return img
end
-- A cut-paper surface for the two impacts. The air has actual holes through it:
-- three broad brush marks wrap the cup, with smaller tongues and raked-out slits.
local function impactMesh(assets)
 local mesh=assets:CreateEditableMesh()
 if not mesh then return nil end
 local ok,part=pcall(function()
  local white=mesh:AddColor(Color3.fromRGB(255,252,236),1)
  local pearl=mesh:AddColor(Color3.fromRGB(234,224,200),1)
  local grey=mesh:AddColor(Color3.fromRGB(158,149,131),1)
  local ink=mesh:AddColor(Color3.fromRGB(55,49,42),1)
  local nx,ny=168,24
  local vertices,colors={},{}
  local function tip(a,center,width)
   local delta=math.atan2(math.sin(a-center),math.cos(a-center))
   return math.max(0,1-math.abs(delta)/width)^1.65
  end
  local function profile(a)
   return .14+.12*(.5+.5*math.sin(6*a-.8))+.60*tip(a,.4,.60)+.34*tip(a,.98,.21)
    +.64*tip(a,2.78,.45)+.53*tip(a,3.44,.23)+.69*tip(a,4.91,.62)+.33*tip(a,5.83,.31)
  end
  for x=0,nx do
   local a=TAU*x/nx
   local crest=profile(a)
   vertices[x],colors[x]={},{}
   for y=0,ny do
    local t=y/ny
    local h=t*crest
    local theta=a+.83*t^1.65+crest*.30*t
    local r=.32+.73*h^.72+.11*t+.027*math.sin(a*3.0+t*2)
    local point=polar(theta,r,h)
    vertices[x][y]=mesh:AddVertex(point)
    local rake=math.sin(a*18+2.4*t+.55*math.sin(a*5))*.5+.5
    colors[x][y]=t<.25 and rake>.66 and ink or t<.34 and rake>.44 and grey or rake>.83 and pearl or white
   end
  end
  for x=0,nx-1 do
   local a=TAU*(x+.5)/nx
   for y=0,ny-1 do
    local t=(y+.5)/ny
    local stroke=(.5+.5*math.sin(a*13+.7*math.sin(a*4)+2.3*t))
    local torn=t<.18+.68*stroke^13 and stroke>.87
    local notch=t>.72+.18*math.sin(a*9) and math.sin(a*17+.9*t)>.82
    if not torn and not notch then
     local p,q=vertices[x],vertices[x+1]
     local c,d=colors[x],colors[x+1]
     local f=mesh:AddTriangle(p[y],p[y+1],q[y])
     mesh:SetFaceColors(f,{c[y],c[y+1],d[y]})
     local g=mesh:AddTriangle(q[y],p[y+1],q[y+1])
     mesh:SetFaceColors(g,{d[y],c[y+1],d[y+1]})
    end
   end
  end
  local result=assets:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
  result.Name="TornWindSurface"; result.Anchored=true; result.CanCollide=false
  result.CanTouch=false; result.CanQuery=false; result.CastShadow=false; result.DoubleSided=true
  result.Material=Enum.Material.Neon; result.Color=Color3.new(1,1,1); result.Transparency=1
  return result
 end)
 if not ok then mesh:Destroy(); return nil end
 return {mesh=mesh,part=part,size=part.Size}
end

function Vortex.ink(rig)
 if rig.retired then return end
 local assets=game:GetService("AssetService")
 rig.masks={}
 for _,layer in ipairs({{"Talons","Column","Skirt","Barbs"},{"Crown","Pressure","Filaments","Splinters"}}) do
  local ok,img=pcall(makeMask,assets,layer[1]=="Crown")
  if ok and img then
   table.insert(rig.masks,img)
   local content=Content.fromObject(img)
   for _,group in ipairs(layer) do
    for i,line in ipairs(rig[group]) do
     local b=line.b
     b.TextureContent=content; b.TextureMode=Enum.TextureMode.Stretch; b.TextureLength=1; b.TextureSpeed=0
     b:SetTextureOffset(noise(i,14))
    end
   end
  end
 end
 local ok,shell=pcall(impactMesh,assets)
 if ok and shell then
  if rig.retired then shell.part:Destroy(); shell.mesh:Destroy(); return end
  rig.shell=shell
  shell.part.Parent=rig.origin
 end
end

-- In the close shot the charge swaps a broad shallow cuff for tall red
-- negatives. The attack goes completely quiet for seven frames before release.
local chargeFrames={
 {0,4,9,3.3}, {6,3,10,5.2}, {10,3,8,.95}, {13,2,5.0,4,RED},
 {16,2,9,3.5}, {18,2,4.1,6,RED}, {20,1.4,8,3}, {22,2.6,5.4,8,RED},
 {27,1.8,6.0,5,RED}, {29,1.8,9.4,3.6}, {32,1.8,3.1,14,RED},
 {34,2,8,3.4}, {37,1.6,4.5,8,RED}, {39,1.5,9.2,4.2}, {41,2,3,12.6,RED},
 {45,2.5,6.5,6.3,RED},
}
local function charge(rig,f)
 for i=#chargeFrames,1,-1 do
  local row=chargeFrames[i]
  if f>=row[1] then
   local u=(f-row[1])/row[2]
   if u>=1 then return end
   local hot=row[5]~=nil
   local alpha=rig.calm and .48 or 1
   local tint=hot and (rig.calm and ASH or RED) or PAPER
   local r,h=row[3]*(1+.16*ease(u)),row[4]
   local lift=(hot and 0 or 1.5)+ease(u)*1.35
   local function wall(lo,hi,offset)
    return function()
     return r*(.67+.33*lo)+offset,lift+h*lo,r*(.67+.33*hi)+offset,lift+h*hi,.01
    end
   end
   skin(rig.Crown,1,9,rig.yaw,TAU,wall(.14,1,0),alpha*(hot and .96 or .55)*(1-.45*u),tint)
   skin(rig.Pressure,1,8,rig.yaw,TAU,wall(.67,.98,.03),alpha*(hot and .80 or .65)*(1-u),hot and INK or PAPER)
   for j=1,(hot and 10 or 6) do
    local a=j*2.39996+rig.yaw+i*.15
    local top=h*(.32+.63*noise(j,i))
    stroke(rig.Talons[j],polar(a,r*.67,lift),polar(a+.18,r*.89,lift+top),
     polar(a+.5,.4,top*.21),polar(a+1,.36,top*.32),
     hot and 1.8 or .48,.035,alpha*(hot and .9 or .4),hot and (j%3==0 and EMBER or INK) or PEARL)
   end
   return
  end
 end
end
-- Different marks occupy different frames; only the two accented impacts use
-- a full brush-cut bowl. Columns, floating collars and side cuts can overlap.
local marks={
 -- source frame, duration (frames), silhouette, radius, height, azimuth
 {55,3,"disc",23,4,.1}, {57,2.4,"negative",21,17,.3}, {59,2.3,"burst",27,33,.45},
 {61,5.2,"needle",4,32,.0}, {70,3,"collar",21,16,.8}, {76,3,"needle",3,21,.9},
 {81,2.2,"collar",12,13,1.9}, {83,7.4,"needle",5,33,1.4},
 {94,2.1,"scythe",22,20,1.1}, {96,4.2,"needle",2.8,22,.6},
 {106,2.4,"groundcut",17,2.1,1.7}, {109,3.4,"needle",3.8,26,1.6},
 {118,2.5,"scythe",26,22,3.2}, {120,3.1,"needle",2.5,29,3.8},
 {130,2.9,"collar",20,15,2.2}, {133,4.1,"needle",4.4,24,2.6},
 {142,1.2,"negative",18,15,1.5}, {143,1.9,"burst",22,25,1.75}, {145,4.5,"needle",4.8,27,1.7},
 {154,2.4,"collar",19,14,2.35}, {156,3.7,"groundcut",19,3,3.8},
 {166,2.3,"scythe",25,21,4.7}, {171.7,3.6,"needle",4.4,33,4.9},
 {177.8,2.2,"collar",14,13,4.8},
}
local function drawCollar(rig,r,h,spin,turn,power,u,side)
 local rise=ease(u); local y=h*(.79+.27*rise)
 local sweep=side and 3.86 or TAU-.30
 local width=side and 3.8 or 1.5
 local function lip(q)
  local a=q*sweep
  local taper=.10+.90*math.sin(math.pi*q)^.52
  local tilt=(side and 4.2 or 1.35)*math.sin(a+.6)
  local base=y+tilt+q*(side and 6 or 1.5)
  return r-.4,base,r+.62,base+width*taper,.022*turn
 end
 skin(rig.Crown,1,9,spin,turn*sweep,lip,power,PAPER)
 -- The thin underside trails behind the detached, much brighter cutting edge.
 skin(rig.Talons,12,10,spin,turn*sweep,function(q)
  local _,bottom,_,top=lip(q)
  local rag=.5+.5*math.sin(q*19+.8)
  return r*(.57+.26*q),bottom-(1+6.0*rag),r*.99,top,.12*turn
 end,power*.22,ASH)
 for i=1,8 do
  local q=(i-.43)/8; local a=spin+turn*sweep*q
  local _,b,_,top=lip(q)
  local sharp=(i%3==0 and -1 or 1)*(1.8+5.6*noise(i,rig.salt))
  stroke(rig.Barbs[i],polar(a-turn*.12,r-.28,b),polar(a+turn*.08,r+.65,top+sharp),
   polar(a+turn*1.57,r*.075,.1),polar(a+turn*1.57,.35,sharp*.36),
   .75+noise(i,2),.035,power,PAPER)
 end
end
local function drawBowl(rig,r,h,spin,turn,power,negative)
 -- Three torn shells, each with a heavy shoulder, notches and one long end.
 -- The displaced upper lip twists into the lower one instead of forming straight spokes.
 if rig.shell then
  local shell=rig.shell
  local scale=v(r,h,r)
  local cf=rig.origin.CFrame*CFrame.Angles(0,-spin,0)
  shell.part.Size=shell.size*scale
  shell.part.CFrame=cf
  shell.part.Color=negative and Color3.fromRGB(39,34,32) or Color3.fromRGB(227,218,193)
  shell.part.Transparency=1-power
  rig.showShell=true
 end
 for island=0,(rig.shell and -1 or 2) do
  local span=({2.3,1.68,1.91})[island+1]
  local start=spin+turn*({0,2.35,4.15})[island+1]
  local heights=({{.05,.44,1,.28,.52,.17,.45,.03},{.03,.25,.42,.23,.83,.46,.18,.04},{.05,.26,.65,.18,.39,.83,.30,.05}})[island+1]
  local function edge(q)
   local k=math.min(7,math.floor(q*7)+1)
   local fraction=q*7-(k-1)
   local peak=heights[k]+(heights[k+1]-heights[k])*fraction
   local low=h*(.035+.09*math.sin(q*4+island)^2)
   return r*(.31+.13*q),low,r*(.56+.45*peak),low+h*peak,turn*(.14+.38*peak)
  end
  skin(rig.Talons,island*7+1,7,start,turn*span,edge,power,
   negative and INK or (island==1 and PEARL or PAPER))
 end
 -- A torn waist bridges the three large shapes. A few dark slits survive the white cel.
 skin(rig.Crown,1,9,spin,turn*(TAU-.18),function(q)
  local crest=.20+.10*math.sin(TAU*q*3+.6)+.08*math.cos(TAU*q*4)
  return r*.33,.22,r*(.58+crest*.37),h*crest,turn*.12
 end,power*(negative and .60 or .97),negative and ASH or PAPER)
 for i=1,6 do
  local a=spin+turn*(i*1.05+.27)
  local j=noise(i,7)
  stroke(rig.Column[i],polar(a,r*(.34+.13*j),.5+h*.04),
   polar(a+turn*.26,r*(.59+.16*j),h*(.24+.29*j)),
   polar(a+turn*.6,r*.14,h*.1),polar(a+turn*.8,r*.08,h*.21),
   .22+.47*j,.02,power*.76,negative and PAPER or INK)
 end
 for i=1,12 do
  local a=spin+TAU*i/12
  local j=noise(i,rig.salt)
  stroke(rig.Barbs[i],polar(a,r*(.32+.07*j),.3),polar(a+turn*(.16+.28*j),r*(.60+.37*j),h*(.22+.7*j)),
   polar(a+turn*.6,r*.18,h*.08),polar(a+turn*1.1,r*.14,h*.39),
   r*(rig.shell and (.012+.024*j) or (.04+.12*j)),.04,power*(negative and .91 or .95),
   negative and (i%4==0 and PAPER or ASH) or (i%3==0 and INK or PAPER))
 end
end
local function drawNeedle(rig,r,h,spin,turn,power,u)
 -- The head travels up while the lower end catches up. The brightest stroke
 -- leaves the floor, cutting a narrow vertical slot through the previous wide hit.
 local tip=ease(u); local lo=h*smooth((u-.24)/.90)
 for i=1,7 do
  local a=spin+i*2.39996
  local j=noise(i,8)
  local base=polar(a,r*(.13+.16*j),lo)
  local top=polar(a+turn*(.27+.64*j),r*(.45+.9*j),h*(.67+.33*j)*(.78+.34*tip)+lo*.25)
  stroke(rig.Column[i],base,top,polar(a+turn*.6,r*.13,h*.28),polar(a+turn*1.0,r*.55,h*.36),
   r*(.63+.56*j)*(1-.74*u),.06,power*(1-.52*u),i==6 and INK or PAPER)
 end
end
local function drawMark(rig,row,f)
 local u=sat((f-row[1])/row[2]); local k=row[3]
 local calm=rig.calm
 local a=calm and .47 or (1-.35*smooth((u-.67)/.33))
 local turn=rig.turn
 local spin=rig.yaw+turn*(row[6]+(.12+.48*ease(u))*(k=="scythe" and 3.1 or 1))
 local r=row[4]*(.85+.24*ease(u))
 local h=row[5]
 if k=="burst" or k=="negative" then
  -- An ink drawing and its paper successor hold briefly, then disappear in one cut.
  drawBowl(rig,r,h*(.91+.16*ease(u)),spin,turn,a,k=="negative")
 elseif k=="needle" then
  drawNeedle(rig,r,h,spin,turn,a,u)
 elseif k=="collar" or k=="scythe" then
  drawCollar(rig,r,h,spin,turn,a,u,k=="scythe")
  if k=="scythe" then
   for i=1,4 do
    local side=spin+turn*(1.0+i*.31)
    stroke(rig.Talons[i],polar(side,r*.20,1+i*.24),polar(side+turn*.40,r,h*(.62+.11*i)),
     polar(side+turn*.78,r*.36,-.15),polar(side+turn*1.08,r*.17,h*.51),
     1.1+i*.72,.06,a*(.62+.08*i),PAPER)
   end
  end
 elseif k=="disc" or k=="groundcut" then
  local rail=k=="disc" and rig.Crown or rig.Talons
  skin(rail,1,9,spin,turn*(k=="disc" and TAU or 4.5),function(q)
   local y=h+math.sin(q*TAU)*.35
   return r*.86,y-1.6,r*1.11,y+.35,.02*turn
  end,a*(k=="disc" and .85 or .55),PAPER)
 end
end
-- A specimen frame can be shorter than a render interval. If a heavy cel was
-- completely crossed since the last draw, show it once at its authored peak.
local function accentFrame(f,previous)
 if previous and f-previous<=4.2 then
  for _,peak in ipairs({59,143}) do
   if previous<peak and f>=peak+1.9 then return peak+.7 end
  end
 end
 return f
end
local function shock(rig,t,born,life,first,last,power)
 local u=(t-born)/life
 if u<0 or u>=1 then return end
 local travel=1-(1-u)^2.6
 local r=first+(last-first)*travel
 local width=(1-u)^1.6*(born==FINISH and 7 or 3.4)+.14
 local alpha=power*(1-smooth(u))
 -- Three concentric lips make a feathered pressure sheet; the leading edge is sharp.
 for i,bank in ipairs({rig.Pressure,rig.Splinters,rig.Filaments}) do
  local lo=({0,.46,.82})[i]; local hi=({.53,.89,1})[i]
  skin(bank,1,#bank,rig.yaw,TAU,function()
   return r-width*(1-lo),.12+lo*.9,r-width*(1-hi),.15+hi*1.15,0
  end,alpha*({.17,.36,.79})[i],PEARL)
 end
end
local function wake(rig,t)
 local age=t-ERUPT
 if age<0 or t>3.62 then return end
 local alive=ease(age/.105)*(1-smooth((t-2.94)/.50))
 local turn=rig.turn; local spin=rig.yaw+turn*(.24+1.55*age)
 -- Dark, lifted ground edge runs independently through the empty hit frames.
 for i=1,9 do
  local a=spin+i*2.39996; local j=noise(i,rig.salt)
  local s=(age*1.9+j)%1
  stroke(rig.Skirt[i],polar(a,4.5+1.4*j,.12),polar(a+turn*.83,8.7+4.1*j,1+s*4.2),
   polar(a+turn*1.0,3.7,.06),polar(a+turn*1.5,2.7,2.9),2.0+j*2,.045,
   alive*.36*math.sin(math.pi*s)^.70,ASH)
 end
 for i=8,10 do
  local u=(age*(1.13+.09*i)+noise(i,4))%1; local a=spin+turn*i*2.39996
  stroke(rig.Column[i],polar(a,2.1,2+5*u),polar(a+turn*1.1,3.8+2*u,11.8+7*u),
   polar(a+turn*1.3,1.4,3),polar(a+turn*1.6,2.2,5),
   .39,.06,alive*.24*math.sin(math.pi*u),PEARL)
 end
 local tail=smooth((t-2.83)/.13)*(1-smooth((t-3.12)/.49))
 if tail>0 then
  for i=1,3 do
   local a=spin+i*2.0; local r=5+i*1.5
   local h=4.1+i*2+(t-2.82)*9
   stroke(rig.Skirt[9+i],polar(a,r,.65+(t-2.82)*2),polar(a+turn*2.95,r*.47,h),
    polar(a+turn*math.pi/2,r*1.65,1.4),polar(a+turn*(2.95+math.pi/2),r*1.14,h*.38),
    .37,.04,tail*.58,PEARL)
  end
 end
end
local function rubble(rig,t)
 local base=rig.origin.CFrame
 for i,p in ipairs(rig.grit) do
  local j=noise(i,rig.salt)
  local birth=ERUPT+.048+.22*j+(i%5==0 and .55 or 0)
  local age=t-birth
  local dropAt=2.54+.48*noise(i,6)
  local endAt=dropAt+.42+.49*j
  if age<0 or t>endAt then p.Transparency=1 continue end
  local lift=ease(age/(.29+.54*noise(i,3)))
  local drop=sat((t-dropAt)/(endAt-dropAt))
  local theta=rig.yaw+rig.turn*(i*2.39996+lift*.88+age*(.23+.42*j))
  local height=.24+(4.6+16.3*j)*lift*(1-drop^2)
  local radius=1.4+5.6*noise(i,4)+lift*(2.0+4.7*noise(i,5))+drop*3.6
  p.CFrame=base*CFrame.new(polar(theta,radius,height))*CFrame.Angles(i+lift*2+age,i*.71+age*1.5,i+age*2.1)
  p.Transparency=1-ease(age/.035)*(1-smooth((drop-.7)/.3))
 end
 for i,p in ipairs(rig.plates) do
  local j=noise(i,rig.salt)
  local age=t-ERUPT-.044*j
  if age<0 or t>=Vortex.duration then p.Transparency=1 continue end
  local a=rig.yaw+TAU*i/#rig.plates+.41*j
  local lift=ease(age/.092)
  local settle=smooth((t-FINISH)/.43)
  local r=5.1+3.8*noise(i,5)+lift*(1.1+j*1.3)
  local h=-.24+lift*(.4+.75*j)*(1-settle*.84)
  p.CFrame=base*CFrame.new(polar(a,r,h))*CFrame.Angles(0,-a,0)*CFrame.Angles(.12,.50*(j-.5),lift*(.37+noise(i,4)*.54)*(1-.7*settle))
  p.Transparency=1-ease(age/.067)*(1-smooth((t-3.43-j*.10)/.51))
 end
end
function Vortex.pose(rig,t,previous)
 local f=t/FRAME
 rig.showShell=false
 for _,line in ipairs(rig.all) do line.used=false end
 if f<49 then charge(rig,f) end
 local sampled=accentFrame(f,previous and previous/FRAME)
 for _,row in ipairs(marks) do
  if sampled>=row[1] and sampled<row[1]+row[2] then drawMark(rig,row,sampled) end
 end
 wake(rig,t)
 local gain=rig.calm and .43 or 1
 shock(rig,t,ERUPT+.055,.255,5,31,.84*gain)
 shock(rig,t,2.382,.214,5,23,.65*gain)
 shock(rig,t,FINISH,.48,4.8,55,1.0*gain)
 for _,line in ipairs(rig.all) do if not line.used then hide(line) end end
 if rig.shell and not rig.showShell then rig.shell.part.Transparency=1 end
 rubble(rig,t)
end
local function clear(rig)
 if rig.shell then rig.shell.part.Transparency=1 end
 for _,line in ipairs(rig.all) do hide(line) end
 for _,part in ipairs(rig.grit) do part.Transparency=1 end
 for _,part in ipairs(rig.plates) do part.Transparency=1 end
end
local dustBeats={{.970,13,22},{1.575,3,10},{2.379,8,16},{2.928,10,12}}
function Vortex.begin(rig,clock,calm)
 local seed=math.floor(clock*1000)%997
 rig.salt=seed
 rig.yaw=noise(seed,24)*TAU
 rig.turn=noise(seed,14)<.5 and -1 or 1
 rig.calm=calm==true
end
function Vortex.step(rig,t,previous)
 Vortex.pose(rig,t,previous)
 for _,cue in ipairs(dustBeats) do
  if previous<cue[1] and t>=cue[1] and t-cue[1]<.12 then
   rig.origin.DustShelf:Emit(cue[2]); rig.origin.StoneGrit:Emit(cue[3])
  end
 end
end

function Vortex.mount(scriptOwner)
 local run = game:GetService("RunService")
 local model, rig, clockChanged, frame
 local function detach()
  if frame then frame:Disconnect(); frame=nil end
  if clockChanged then clockChanged:Disconnect(); clockChanged=nil end
  if rig then rig.retired=true end
  if rig and rig.shell then rig.shell.part:Destroy(); rig.shell.mesh:Destroy() end
  if rig and rig.masks then
   for _,img in ipairs(rig.masks) do img:Destroy() end
  end
  model,rig=nil,nil
 end
 local function attach(root)
  if root.Name ~= NAME or not root:IsA("Model") or root:GetAttribute("WindVortexVersion") ~= 1 then return end
  detach()
  model,rig=root,Vortex.bind(root)
  task.defer(Vortex.ink,rig)
  local function start()
   if frame then frame:Disconnect(); frame=nil end
   clear(rig)
   local clock=root:GetAttribute("CastAt")
   if type(clock)~="number" or workspace:GetServerTimeNow()-clock>=Vortex.duration then return end
   local player=game:GetService("Players").LocalPlayer
   local quiet=game:GetService("GuiService").ReducedMotionEnabled or (player and (
    player:GetAttribute("ReducedFlashing") or player:GetAttribute("ReducedMotion") or player:GetAttribute("MA_ReducedMotion")))
   Vortex.begin(rig,clock,quiet)
   local previous=-1
   local function draw()
    local t=workspace:GetServerTimeNow()-clock
    if t<0 then return end
    if t>=Vortex.duration then
     clear(rig)
     if frame then frame:Disconnect(); frame=nil end
     return
    end
    Vortex.step(rig,t,previous)
    previous=t
   end
   frame=run.RenderStepped:Connect(draw)
   draw()
  end
  clockChanged=root:GetAttributeChangedSignal("CastAt"):Connect(start)
  start()
 end
 local added=workspace.ChildAdded:Connect(attach)
 local removed=workspace.ChildRemoved:Connect(function(child) if child==model then detach() end end)
 local root=workspace:FindFirstChild(NAME)
 if root then attach(root) end
 scriptOwner.Destroying:Once(function() added:Disconnect(); removed:Disconnect(); detach() end)
end
-- One static set of layers lives in Workspace and can be inspected in Edit.
Vortex.groups, Vortex.gritCount, Vortex.plateCount = groups, GRIT_COUNT, PLATE_COUNT
return Vortex
