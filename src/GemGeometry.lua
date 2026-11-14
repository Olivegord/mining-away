-- One geometry description feeds runtime meshes and the durable Edit specimens.
local G={}
local rgb=Color3.fromRGB
G.order={'Quartz','Ruby','Cobalt','Violet','Emerald'}
G.definitions={
 Quartz={kind='cluster',aspect=Vector3.new(1.02,1.85,.85),colors={rgb(21,62,104),rgb(54,176,195),rgb(215,255,239),rgb(143,116,224)}},
 Ruby={kind='ruby',aspect=Vector3.new(.94,1.10,.84),colors={rgb(65,8,62),rgb(218,26,83),rgb(255,167,123),rgb(255,86,164)},opacity=.72,vertexAlpha=.86},
 Cobalt={kind='bismuth',aspect=Vector3.new(1.16,1.68,1.02),colors={rgb(13,21,48),rgb(40,113,232),rgb(248,213,96),rgb(175,57,211)}},
 Violet={kind='needle',aspect=Vector3.new(.46,3.05,.48),colors={rgb(27,4,51),rgb(139,18,209),rgb(255,180,246),rgb(105,49,201)}},
 Emerald={kind='dark',aspect=Vector3.new(.92,1.70,.78),colors={rgb(17,13,23),rgb(27,39,39),rgb(67,240,190),rgb(156,246,145)}},
}
function G.key(value)
 value=type(value)=='string' and value or 'Quartz'
 value=value:match('^Rock:(%a+):') or value:match('^Block:(%a+):') or value
 value=value:gsub('^Run','')
 return G.definitions[value] and value or 'Quartz'
end
function G.describe(key)
 key=G.key(key)
 local spec=G.definitions[key]
 local ruby=spec.kind=='ruby' -- The Ruby cut and finish from 3b1f622.
 local data={faces={},grains={},boxes={},aspect=spec.aspect,key=key,tint=spec.colors[2],
  opacity=spec.opacity or (key=='Emerald' and .96 or key=='Cobalt' and 1 or .76),
  vertexAlpha=spec.vertexAlpha or .88}
 if key=='Emerald' then data.tint=spec.colors[3] end
 local function gradient(p,sector)
  local t=math.clamp(p.Y+.5,0,1)
  if spec.kind=='dark' then
   -- Most of the body remains near-black; concentrated green/gold light rises
   -- only a short distance from the bottom point.
   local glow=math.clamp((.30-t)/.30,0,1)^1.5
   local dark=spec.colors[1]:Lerp(spec.colors[2],sector%3*.18)
   return dark:Lerp(sector%2==0 and spec.colors[3] or spec.colors[4],glow)
  end
  local midpoint=ruby and .52 or .56
  local c=t<midpoint and spec.colors[1]:Lerp(spec.colors[2],t/midpoint)
   or spec.colors[2]:Lerp(spec.colors[3],(t-midpoint)/(ruby and .48 or .44))
  return c:Lerp(spec.colors[4],sector%3==0 and (ruby and .45 or .28) or (ruby and .08 or .04))
 end
 local function face(a,b,c,sector,center,fixed)
  local n=(b-a):Cross(c-a)
  if n.Magnitude<.000001 then return end
  if n:Dot((a+b+c)/3-(center or Vector3.zero))<0 then b,c=c,b end
  local shade=sector%2==0 and .12 or (ruby and .38 or .28)
  local function color(p) return (fixed or gradient(p,sector)):Lerp(Color3.new(0,0,0),shade) end
  data.faces[#data.faces+1]={a,b,c,color(a),color(b),color(c)}
 end
 local function prism(sides,rings,lean,frame,scale,grainCount,seed)
  local rows={}
  local function transform(p) return frame:PointToWorldSpace(p*scale) end
  for k,ring in ipairs(rings) do
   rows[k]={}
   for i=1,sides do
    local angle=(i-1)*2*math.pi/sides+.19
    local radius=ring[1]*(i%3==0 and (ruby and .88 or .90) or 1)
    rows[k][i]=transform(Vector3.new(math.cos(angle)*radius+ring[2]*lean,ring[2],math.sin(angle)*radius))
   end
  end
  local top=transform(Vector3.new(lean*.5,.5,0))
  local bottom=transform(Vector3.new(-lean*(ruby and .45 or .5),-.5,0))
  local center=frame.Position
  for i=1,sides do
   local j=i%sides+1
   face(top,rows[1][i],rows[1][j],i,center)
   for k=1,#rows-1 do
    face(rows[k][i],rows[k+1][i],rows[k+1][j],i,center)
    face(rows[k][i],rows[k+1][j],rows[k][j],ruby and i+1 or i,center)
   end
   face(rows[#rows][i],bottom,rows[#rows][j],i,center)
  end
  local random=Random.new(seed)
  for i=1,grainCount do
   local y=random:NextNumber(ruby and -.30 or -.29,ruby and .32 or .28)
   local r=((ruby and .28 or .23)-math.abs(y)*(ruby and .38 or .32))*math.sqrt(random:NextNumber())
   local a=random:NextNumber(0,math.pi*2)
   local size=random:NextNumber(.008,ruby and .015 or .014)*(ruby and (i%9==0 and 1.35 or 1) or math.min(scale.X,scale.Y,scale.Z))
   data.grains[#data.grains+1]={transform(Vector3.new(math.cos(a)*r+y*lean,y,math.sin(a)*r)),size}
  end
 end
 local long={{.025,.5},{.34,.28},{.36,-.29},{.035,-.5}}
 if spec.kind=='cluster' then
  prism(6,long,.04,CFrame.new(.01,.02,0),Vector3.new(.65,.96,.66),18,593)
  prism(5,long,-.12,CFrame.new(-.32,-.18,.04)*CFrame.Angles(0,.4,.33),Vector3.new(.40,.67,.43),9,614)
  prism(6,long,.06,CFrame.new(.30,-.24,.10)*CFrame.Angles(-.19,0,-.38),Vector3.new(.37,.58,.39),8,631)
 elseif spec.kind=='needle' then
  prism(5,{{.015,.5},{.34,.29},{.46,-.13},{.025,-.5}},-.22,CFrame.new(),Vector3.one,26,702)
 elseif spec.kind=='dark' then
  prism(5,{{.025,.5},{.43,.15},{.45,-.28},{.035,-.5}},.17,CFrame.new(),Vector3.one,14,721)
 elseif spec.kind=='ruby' then
  prism(7,{{.28,.46},{.48,.19},{.44,-.22},{.25,-.44}},-.12,CFrame.new(),Vector3.one,30,593+7*17)
 else
  -- Hollow square terraces with open centers, plus two offset satellite steps.
  -- These are geometric hopper crystals, not a prism with a rainbow texture.
  local function box(frame,size,color,sector)
   data.boxes[#data.boxes+1]={frame=frame,size=size,color=color}
   local v={}
   for _,s in ipairs({{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}}) do
    v[#v+1]=frame:PointToWorldSpace(Vector3.new(s[1],s[2],s[3])*size*.5)
   end
   for _,f in ipairs({{1,3,2},{1,4,3},{5,6,7},{5,7,8},{1,2,6},{1,6,5},{4,8,7},{4,7,3},{1,5,8},{1,8,4},{2,3,7},{2,7,6}}) do face(v[f[1]],v[f[2]],v[f[3]],sector,frame.Position,color) end
  end
  local palette={rgb(246,207,103),rgb(221,119,104),rgb(168,63,196),rgb(54,92,215),rgb(44,185,199),rgb(218,200,104)}
  local function hopper(frame,scale,count)
   for i=1,count do
    local edge=(.92-(i-1)*.103)*scale
    local rail=.045*scale
    local y=(-.37+(i-1)*.105)*scale
    local c=palette[(i-1)%#palette+1]
    box(frame*CFrame.new(0,y,-edge*.5),Vector3.new(edge+rail,.055*scale,rail),c,i)
    box(frame*CFrame.new(0,y,edge*.5),Vector3.new(edge+rail,.055*scale,rail),c,i+1)
    box(frame*CFrame.new(-edge*.5,y,0),Vector3.new(rail,.055*scale,edge),c,i)
    box(frame*CFrame.new(edge*.5,y,0),Vector3.new(rail,.055*scale,edge),c,i+1)
    -- A short vertical riser connects successive terraces while keeping the
    -- center visibly hollow and the silhouette stepped.
    if i<count then
     box(frame*CFrame.new(-edge*.5+.035*scale,y+.05*scale,-edge*.5+.035*scale),Vector3.new(.055*scale,.105*scale,.055*scale),c,i)
    end
   end
  end
  hopper(CFrame.Angles(.33,.22,-.16),.86,7)
  hopper(CFrame.new(.37,-.29,.14)*CFrame.Angles(.45,.6,.28),.48,5)
  hopper(CFrame.new(-.32,.12,-.09)*CFrame.Angles(-.22,-.3,-.42),.44,5)
 end
 local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,f in ipairs(data.faces) do for i=1,3 do lo=lo:Min(f[i]);hi=hi:Max(f[i]) end end
 data.center=(lo+hi)*.5;data.extents=hi-lo
 return data
end
return G
