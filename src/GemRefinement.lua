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
 local veil=math.clamp((cloud-.035)*4.8,0,.62)
 return math.clamp(.96-veil+fine*.35+fracture*.18,.32,1),.82+muddy*.18
end
local function colors(key,p,index)
 if key=='Amber' then
  local t=math.clamp(.49+p.Y*.8+p.X*.48-p.Z*.21,0,1)
  local c=t<.57 and rgb(241,50,0):Lerp(rgb(255,133,0),t/.57) or rgb(255,133,0):Lerp(rgb(255,222,102),(t-.57)/.43)
  -- Broad pale side facets and a deep orange body, not one yellow stripe.
  return c:Lerp(index%5==0 and rgb(255,227,139) or rgb(255,83,0),index%5==0 and .30 or .08)
 elseif key=='Quartz' then
  local t=math.clamp((p.Y+.49)/.96,0,1)
  local c=t<.42 and rgb(235,196,103):Lerp(rgb(210,228,218),t/.42) or rgb(210,228,218):Lerp(rgb(62,155,216),(t-.42)/.58)
  return c:Lerp(rgb(179,221,237),index%4==0 and .28 or .02)
 end
 local palette={rgb(246,174,219),rgb(141,221,239),rgb(183,226,180),rgb(249,199,153),rgb(183,173,193),rgb(192,221,241),rgb(244,194,222)}
 local faces={2,1,4,3,1,2,4,2,3,5,2,1,4,1,3,2}
 local base=palette[faces[index] or 2]
 local alternate=palette[(index+2)%#palette+1]
 local t=math.clamp(.48+p.Y*.54+p.X*.37-p.Z*.48,0,1)
 return base:Lerp(alternate,t*.44):Lerp(white,.19)
end
function R.describe(key)
 if key~='Amber' and key~='Quartz' and key~='Diamond' then return nil end
 local data={key=key,faces={},grains={},clouds={},boxes={},texture=key,
  opacity=key=='Amber' and .88 or key=='Quartz' and .31 or .80,
  vertexAlpha=key=='Amber' and .97 or key=='Quartz' and .83 or .88,
  material=key=='Amber' and 'SmoothPlastic' or 'Neon',
  aspect=key=='Amber' and V(1.10,1.42,.73) or key=='Quartz' and V(.96,2.05,.78) or V(.99,2.22,.69)}
 local function face(a,b,c,index,center)
  if (b-a):Cross(c-a):Dot((a+b+c)/3-center)<0 then b,c=c,b end
  local f={a,b,c,colors(key,a,index),colors(key,b,index),colors(key,c,index)}
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
 if key=='Amber' then
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
  cut(diamond,CFrame.Angles(.04,-.08,-.12),Vector3.one)
  -- Close inset fracture surfaces carry the same cloudy optical texture.
  -- They span the volume rather than floating as five colored islands.
  for i,f in ipairs(data.faces) do
   if i%3==1 then
    local g={}
    for n=1,3 do g[n]=f[n]*.82+V(.015,-.012,.008);g[n+3]=f[n+3]:Lerp(white,.26);g[n+6]=f[n+6] end
    data.clouds[#data.clouds+1]=g
   end
  end
 end
 local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,f in ipairs(data.faces) do for i=1,3 do lo=lo:Min(f[i]);hi=hi:Max(f[i]) end end
 data.center=(lo+hi)*.5;data.extents=hi-lo
 return data
end
return R
