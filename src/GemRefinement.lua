-- Uneven cut planes and optical color, shared by native previews and pickups.
-- Texture samples are deterministic and fixed to the crystal's facets.
local R={}
local rgb=Color3.fromRGB
local V=Vector3.new
local white=rgb(255,255,255)
function R.texture(u,v,key)
 local warp=math.noise(u*3.2,v*3.2,7)*.19
 local cloud=math.noise(u*7+warp,v*5-warp,4)*.5+math.noise(u*19,v*17,9)*.22
 local fine=math.noise(u*113,v*127,3)*.12
 local line=math.abs(math.noise(u*12+warp,v*9,21))
 local fracture=math.clamp((.014-line)*65,0,1)
 local muddy=math.clamp(.5+cloud*1.6,0,1)
 if key=='Amber' then return .97+fine*.1,1 end
 if key=='Quartz' then return math.clamp(.80+cloud*.17+fine*.35+fracture*.17,.57,1),.70+muddy*.3 end
 local veil=math.clamp((cloud-.08)*.70,0,.10)
 return math.clamp(.99-veil+fine*.08+fracture*.035,.88,1),.92+muddy*.08
end
-- Broad straight-sided virtual reflections; no noise, scratches or texture swaps.
function R.spectrum(u,v)
 local x,y=u*3,v*3
 local ix,iy=math.floor(x),math.floor(y)
 local a,b=x-ix,y-iy
 local side=a+b>1 and 1 or 0
 local palette={rgb(29,50,79),rgb(18,231,239),rgb(255,65,151),rgb(255,182,30),rgb(114,85,239),rgb(137,242,161),rgb(185,218,240)}
 local index=(ix*3+iy*5+side*2)%#palette+1
 local c=palette[index]
 local t=math.clamp(a*.60+b*.40,0,1)
 return c:Lerp(t>.58 and rgb(235,252,255) or rgb(14,25,51),t>.58 and (t-.58)*.8 or (.58-t)*.6),index==1 and .18 or .85
end
local function colors(key,p,index)
 if key=='Amber' then
  local t=math.clamp(.48+p.Y*1.18+p.X*.72-p.Z*.32,0,1)
  local c=t<.57 and rgb(241,50,0):Lerp(rgb(255,133,0),t/.57) or rgb(255,133,0):Lerp(rgb(255,222,102),(t-.57)/.43)
  -- Broad pale side facets and a deep orange body, not one yellow stripe.
  return c:Lerp(index%5==0 and rgb(255,227,139) or rgb(255,83,0),index%5==0 and .30 or .08)
 elseif key=='Quartz' then
  local t=math.clamp(.48+p.Y*1.18+p.X*.46-p.Z*.25,0,1)
  local c=t<.42 and rgb(235,196,103):Lerp(rgb(210,228,218),t/.42) or rgb(210,228,218):Lerp(rgb(62,155,216),(t-.42)/.58)
  return c:Lerp(rgb(179,221,237),index%4==0 and .28 or .02)
 end
 -- Neutral facet values preserve the saturated spectrum texture. Unequal
 -- face brightness gives the crystal dark reflective planes at every angle.
 local shade=({.92,.78,.95,.76,.91,.58,.98,.83,.72,.87,.66,.93,.81,.70,.96,.74})[index] or .9
 return Color3.new(shade,shade,shade)
end
function R.describe(key,compact)
 if not compact and key~='Amber' and key~='Quartz' and key~='Diamond' then return nil end
 local data={key=key,faces={},grains={},clouds={},rims={},boxes={},texture=key,
  opacity=key=='Amber' and .88 or key=='Quartz' and .31 or .12,
  vertexAlpha=key=='Amber' and .97 or key=='Quartz' and .83 or 1,
  material=key=='Amber' and 'SmoothPlastic' or key=='Diamond' and 'SmoothPlastic' or 'Neon',
  aspect=key=='Amber' and V(1.10,1.42,.73) or key=='Quartz' and V(.96,2.05,.78) or V(1.28,1.48,1.08)}
 if key=='Diamond' then data.texture=nil end
 if compact then data.texture=nil;data.aspect=V(1.25,1.35,1.12) end
 local palettes={Ruby={rgb(62,3,51),rgb(234,17,87),rgb(255,183,138)},Violet={rgb(32,5,85),rgb(137,42,242),rgb(255,176,244)}}
 local function face(a,b,c,index,center)
  if (b-a):Cross(c-a):Dot((a+b+c)/3-center)<0 then b,c=c,b end
  local function shade(p)
   if key=='Diamond' then return rgb(213,234,250) end
   local palette=palettes[key]
   if not palette then return colors(key,p,index) end
   local t=math.clamp(.5+p.Y*.95+p.X*.70-p.Z*.38,0,1)
   return (t<.5 and palette[1]:Lerp(palette[2],t*2) or palette[2]:Lerp(palette[3],t*2-1)):Lerp(rgb(62,21,101),index%3==0 and .25 or 0)
  end
  local f={a,b,c,shade(a),shade(b),shade(c)}
  f.facet=index
  -- One fixed projected coordinate system per plane keeps the texture continuous
  -- across the triangle fan. Adjacent planes refract different parts of it.
  local n=(b-a):Cross(c-a).Unit
  local right=n:Cross(math.abs(n.Y)>.9 and Vector3.zAxis or Vector3.yAxis).Unit
  local up=n:Cross(right)
  for i,p in ipairs({a,b,c}) do f[6+i]=Vector2.new(p:Dot(right)*.71+.43+index*.071,p:Dot(up)*.77+.54+index*.043) end
  data.faces[#data.faces+1]=f
 end
 local function cut(planes,frame,scale)
  -- Intersections of actual cutting planes make broad, unequal planar facets.
  -- Ring jitter would bend faces and still leave the regular barrel silhouette.
  local vertices={}
  local rimEdges={}
  data.solids=data.solids or {};data.solids[#data.solids+1]={planes=planes,frame=frame,scale=scale}
  for a=1,#planes-2 do for b=a+1,#planes-1 do for c=b+1,#planes do
   local A,B,C=planes[a],planes[b],planes[c]
   local denominator=A[1]:Dot(B[1]:Cross(C[1]))
   if math.abs(denominator)>.00001 then
    local p=(B[1]:Cross(C[1])*A[2]+C[1]:Cross(A[1])*B[2]+A[1]:Cross(B[1])*C[2])/denominator
    local valid=true
    for _,plane in ipairs(planes) do if p:Dot(plane[1])>plane[2]+.00005 then valid=false;break end end
    if valid then
     for _,v in ipairs(vertices) do if (p-v).Magnitude<.0001 then valid=false;break end end
     if valid then vertices[#vertices+1]=p end
    end
   end
  end end end
  for index,plane in ipairs(planes) do
   local polygon={};local center=Vector3.zero
   for _,p in ipairs(vertices) do if math.abs(p:Dot(plane[1])-plane[2])<.0001 then polygon[#polygon+1]=p;center+=p end end
   if #polygon>=3 then
    center/=#polygon
    local axis=(polygon[1]-center).Unit;local other=plane[1].Unit:Cross(axis)
    table.sort(polygon,function(a,b) local x,y=a-center,b-center;return math.atan2(x:Dot(other),x:Dot(axis))<math.atan2(y:Dot(other),y:Dot(axis)) end)
    if key=='Diamond' and (index==5 or index==8 or index==9 or index==14) then
     local palette={rgb(107,237,255),rgb(255,153,218),rgb(165,255,153),rgb(255,197,132)}
     local normal=frame:VectorToWorldSpace(plane[1].Unit)*.009
     for i=1,#polygon do
      local a,b=polygon[i],polygon[i%#polygon+1]
      local edgeKey=tostring(a)..'|'..tostring(b)
      local reverseKey=tostring(b)..'|'..tostring(a)
      if rimEdges[edgeKey] or rimEdges[reverseKey] then continue end
      rimEdges[edgeKey]=true
      local mid=(a+b)*.5
      local color=mid.Y>.16 and (mid.X>0 and palette[4] or palette[2]) or mid.Y<-.16 and palette[3] or (mid.X<0 and palette[1] or palette[2])
      local width=index==9 and .006 or .004
      local edge=b-a
      b=a+edge*(.40+(i%3)*.16);a+=edge*.06
      a+=(center-a).Unit*.003;b+=(center-b).Unit*.003
      local ia=a+(center-a).Unit*width;local ib=b+(center-b).Unit*width
      local function point(p) return frame:PointToWorldSpace(p*scale)+normal end
      a,b,ia,ib=point(a),point(b),point(ia),point(ib)
      data.rims[#data.rims+1]={a,b,ia,color,color,color,1,1,1}
      data.rims[#data.rims+1]={b,ib,ia,color,color,color,1,1,1}
     end
    end
    for i=1,#polygon do
     face(frame:PointToWorldSpace(center*scale),frame:PointToWorldSpace(polygon[i]*scale),frame:PointToWorldSpace(polygon[i%#polygon+1]*scale),index,frame.Position)
    end
   end
  end
 end
 local function plane(x,y,z,d) return {V(x,y,z),d} end
 local amber={plane(1,0,0,.48),plane(-1,0,0,.41),plane(.20,1,.12,.52),plane(-.21,-1,.13,.43),plane(0,0,1,.32),plane(0,0,-1,.34),
  plane(1,.61,.14,.51),plane(-1,.34,-.10,.47),plane(.52,-1,.14,.53),plane(-.71,-1,-.08,.62),
  plane(.21,.48,1,.41),plane(.2,-.45,1,.37),plane(-.15,.53,-1,.45),plane(.75,-.2,1,.51),plane(-.84,.08,-1,.49),plane(.80,0,-1,.53),plane(-.64,-.3,1,.51)}
 local quartz={plane(1,-.14,.06,.34),plane(-1,.23,.02,.34),plane(-.12,-1,.12,.49),plane(-.14,1,.08,.24),plane(0,0,1,.28),plane(0,0,-1,.30),
  plane(1,.55,.08,.47),plane(-1,.32,.10,.39),plane(.12,.48,1,.34),plane(.05,.19,-1,.35),
  plane(.8,0,1,.41),plane(-.63,0,-1,.42),plane(-.9,-.12,1,.47),plane(1,-.1,-1,.45),plane(.1,-1,-.3,.53)}
 local diamond={plane(1,0,0,.44),plane(-1,0,0,.40),plane(0,0,1,.29),plane(0,0,-1,.30),
  plane(1,.54,.12,.37),plane(-1,.85,-.06,.49),plane(.16,.59,1,.35),plane(-.09,.73,-1,.44),
  plane(.81,-.78,.08,.45),plane(-1,-.69,.09,.43),plane(.15,-.61,1,.36),plane(-.12,-.69,-1,.42),
  plane(.86,.06,1,.51),plane(-.82,-.08,-1,.48),plane(-.80,.05,1,.47),plane(.95,-.04,-1,.51)}
 local compactPlanes={}
 for _,axis in ipairs({1,2,3}) do for _,a in ipairs({-1,1}) do for _,b in ipairs({-1,1}) do
  compactPlanes[#compactPlanes+1]=axis==1 and plane(a,b,0,.66) or axis==2 and plane(a,0,b,.66) or plane(0,a,b,.66)
 end end end
 if compact then
  cut(compactPlanes,CFrame.Angles(.12,.23,.10),Vector3.one)
 elseif key=='Amber' then
  cut(amber,CFrame.Angles(0,.11,-.24),Vector3.one)
 elseif key=='Quartz' then
  cut(quartz,CFrame.Angles(.03,.1,.08),Vector3.one)
  -- Broken stepped crown, grown from one broad trunk rather than a symmetric
  -- three-pronged star. The tips have different heights, widths and directions.
  cut(diamond,CFrame.new(-.15,.30,.01)*CFrame.Angles(.06,.21,-.14),V(.55,.54,.60))
  cut(diamond,CFrame.new(.22,.19,-.04)*CFrame.Angles(-.11,-.23,-.26),V(.40,.68,.48))
  local random=Random.new(404)
  for i=1,520 do
   if #data.grains>=116 then break end
   local top=#data.grains<76
   local p=top and V(random:NextNumber(-.22,.24),random:NextNumber(.12,.49),random:NextNumber(-.18,.16))
    or V(random:NextNumber(-.22,.22),random:NextNumber(-.47,-.22),random:NextNumber(-.19,.19))
   local inside=false
   for _,solid in ipairs(data.solids) do
    local q=solid.frame:PointToObjectSpace(p)/solid.scale
    local fits=true
    for _,plane in ipairs(solid.planes) do if q:Dot(plane[1])>plane[2]-.015 then fits=false;break end end
    if fits then inside=true;break end
   end
   if inside then data.grains[#data.grains+1]={p,random:NextNumber(top and .0016 or .0015,top and .0045 or .0032),top and rgb(141,205,239) or rgb(240,212,142)} end
  end
 else
  local broad={plane(1,0,0,.48),plane(-1,0,0,.43),plane(0,0,1,.40),plane(0,0,-1,.36),
   plane(.12,1,.06,.46),plane(-.08,-1,.12,.46),plane(1,.75,.8,.73),plane(-1,.83,.7,.69),
   plane(.8,.65,-1,.70),plane(-.8,.72,-1,.69),plane(1,-.8,.7,.72),plane(-.9,-.8,-1,.73)}
  cut(broad,CFrame.Angles(.04,-.08,-.12),Vector3.one)
 end
 if key=='Diamond' then
  -- A complete inset cut carries a displaced optical field. Occlusion and
  -- parallax make this read through the outer faces rather than as confetti.
  for _,f in ipairs(data.faces) do
   local g={}
   for n=1,3 do
    g[n]=f[n]*.94
    g[n+3]=white
    g[n+6]=f[n+6]+Vector2.new(.19,.27)
   end
   data.clouds[#data.clouds+1]=g
  end
 end
 local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,f in ipairs(data.faces) do for i=1,3 do lo=lo:Min(f[i]);hi=hi:Max(f[i]) end end
 data.center=(lo+hi)*.5;data.extents=hi-lo
 if key=='Diamond' then
  data.flares={}
  for _,target in ipairs({V(-.30,.20,-.30),V(.35,-.30,.20),V(.12,.38,.22)}) do
   local best,distance=nil,math.huge
   for _,f in ipairs(data.rims) do for i=1,2 do
    local d=(f[i]-target).Magnitude
    if d<distance then best=f[i];distance=d end
   end end
   data.flares[#data.flares+1]=(best-data.center)/data.extents
  end
 end
 return data
end
return R
