local Layout=require('../src/MapLayout')
local Config=require('../src/Config')
local plan=Layout.plan(Config.Fields)
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS map '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
check('five clearings span the larger valley before outer hills',function()
 local home={-56,.5,-11}
 local last=0
 for _,f in ipairs(plan.fields) do
  assert(f.top>=last);last=f.top
  assert(math.sqrt((f.x-home[1])^2+(f.z-home[3])^2)<190)
 end
 near(plan.fields[2].top,13);near(plan.fields[5].top,40)
end)
check('expanded world leaves a broad sparse central hub',function()
 assert(Layout.Scale>=1.8)
 assert(Layout.Columns*Layout.Cell*Layout.Scale>=370)
 for x=-100,-12,4 do for z=-51,29,4 do
  if not plan:hubClear(x,z,-8) then near(plan:surface(x,z),.04) end
 end end
 for _,t in ipairs(plan.trees) do assert(plan:hubClear(t.x,t.z,t.h*.3),'tree in open hub') end
 for _,f in ipairs(plan.fields) do assert(math.sqrt((f.x+56)^2+(f.z+11)^2)>80,'field crowds hub') end
end)
check('all walking grades are below 35 degrees and widths admit passing',function()
 for _,r in ipairs(plan.routes) do
  assert(r.width>=9)
  for i=1,#r.samples-1 do
   local a,b=r.samples[i],r.samples[i+1]
   local run=math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)
   assert(run>.01,r.name..' degenerate chord')
   assert(math.abs(b[2]-a[2])/run<math.tan(math.rad(35)),r.name..' steep chord')
  end
 end
end)
check('terrain stays below every mining clearing including its outer edges',function()
 for _,f in ipairs(plan.fields) do
  for x=f.x-f.w/2,f.x+f.w/2,1 do for z=f.z-f.d/2,f.z+f.d/2,1 do
   assert(plan:surface(x,z)<=math.max(0,f.top-2)+.041,'terrain intrudes field '..f.x)
  end end
 end
end)
check('solid terrain leaves floor and body clearance along the full winding route',function()
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1]
  local dx,dz=b[1]-a[1],b[3]-a[3];local length=math.sqrt(dx*dx+dz*dz)
  for n=0,math.ceil(length) do
   local t=n/math.ceil(length)
   for _,side in ipairs({-.3,0,.3}) do
    local x=a[1]+dx*t-dz/length*r.width*side
    local z=a[3]+dz*t+dx/length*r.width*side
    local y=a[2]+(b[2]-a[2])*t
    assert(plan:surface(x,z)<y,r.name..' terrain crosses path')
   end
  end
 end end
end)
check('field entry ramps reach full height before entering a field wall',function()
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1]
  local length=math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)
  for n=0,math.ceil(length*2) do
   local t=n/math.ceil(length*2);local x=a[1]+(b[1]-a[1])*t;local z=a[3]+(b[3]-a[3])*t;local y=a[2]+(b[2]-a[2])*t
   for _,f in ipairs(plan.fields) do
    if math.abs(x-f.x)<f.w/2+2 and math.abs(z-f.z)<f.d/2+2 then
     assert(y>=f.top-.4,r.name..' enters field wall at '..x..','..z)
    end
   end
  end
 end end
end)
check('no upper route foundation blocks a lower route centerline',function()
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1]
  local length=math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)
  for n=0,math.ceil(length) do
   local t=n/math.ceil(length);local x=a[1]+(b[1]-a[1])*t;local z=a[3]+(b[3]-a[3])*t;local y=a[2]+(b[2]-a[2])*t
   for _,other in ipairs(plan.routes) do if other~=r then for j=1,#other.samples-1 do
    local d,h=Layout.distance(x,z,other.samples[j],other.samples[j+1])
    assert(d>other.width/2+1 or h<y+1.2,r.name..' crosses under solid '..other.name)
   end end end
  end
 end end
end)
check('joint-earth supports stay below swept walking lanes',function()
 for _,route in ipairs(plan.routes) do for i=2,#route.samples-1 do
  local center=route.samples[i];local radius=math.sqrt((route.width/2)^2+.25^2)
  local cap=Layout.jointTop(plan.routes,center,radius)
  for _,other in ipairs(plan.routes) do for j=1,#other.samples-1 do
   local a,b=other.samples[j],other.samples[j+1]
   local length=math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)
   for n=0,math.ceil(length*2) do
    local t=n/math.ceil(length*2);local x=a[1]+(b[1]-a[1])*t;local z=a[3]+(b[3]-a[3])*t
    if (x-center[1])^2+(z-center[3])^2 <= (radius+1.5)^2 then
     local y=a[2]+(b[2]-a[2])*t
     assert(cap<=y-.249,route.name..' joint obstructs '..other.name..' walking lane')
    end
   end
  end end
 end end
end)
check('solid trail-earth footprints avoid pedestrian bands on all routes',function()
 local supports={};local worstGap=0
 for _,route in ipairs(plan.routes) do for i=1,#route.samples-1 do
  local a,b=route.samples[i],route.samples[i+1];local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx*dx+dz*dz)
  local count=math.ceil(len/3);local width=route.width-.3;local length=len/count+.08
  for k=1,count do
   local t=(k-.5)/count;local center={a[1]+dx*t,a[2]+(b[2]-a[2])*t,a[3]+dz*t}
   local low=center[2]-math.abs(b[2]-a[2])/(count*2)
   local top=low-.35
   worstGap=math.max(worstGap,low-.14-top)
   table.insert(supports,{center=center,ux=dx/len,uz=dz/len,width=width,length=length,top=top,route=route.name})
  end
 end end
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1];local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx*dx+dz*dz)
  for n=0,math.ceil(len*2) do for _,offset in ipairs({-2,0,2}) do
   local t=n/math.ceil(len*2);local x=a[1]+dx*t-dz/len*offset;local z=a[3]+dz*t+dx/len*offset;local y=a[2]+(b[2]-a[2])*t
   for _,v in ipairs(supports) do
    local rx,rz=x-v.center[1],z-v.center[3];local along=math.abs(rx*v.ux+rz*v.uz);local side=math.abs(rx*v.uz-rz*v.ux)
    if along<=v.length/2+1 and side<=v.width/2+1 then
     assert(v.top<y+.4,r.name..' raised support exceeds known sampled step allowance: '..tostring(v.top-y))
    end
   end
  end end
 end end
 print('map worst modeled support-to-slab low-edge gap '..tostring(worstGap)..' studs')
end)
check('slope-fitting support caps contact each road while clearing other pedestrian bands',function()
 local caps={}
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1];local dx,dz=b[1]-a[1],b[3]-a[3];local run=math.sqrt(dx*dx+dz*dz)
  local count=math.ceil(run/3)
  for n=1,count do
   local c=Layout.supportCap(a,b,count,n,Layout.supportTrim(r.name,i))
   if c.base>.3 and c.rise>=.05 then
    c.width=r.width-.3;c.route=r.name;table.insert(caps,c)
    for _,offset in ipairs({-.45,0,.45}) do
     local along=offset*c.length;local progress=along/c.length+.5
     if not c.highTowardB then progress=1-progress end
     local capHeight=c.base+c.rise*progress
     local roadHeight=c.center[2]+(b[2]-a[2])/run*along
     local underside=roadHeight-.14*math.sqrt(1+((b[2]-a[2])/run)^2)
     local gap=underside-capHeight
     assert(gap>=-.05 and gap<.3,r.name..' slope cap misses slab: '..tostring(gap))
    end
   end
  end
 end end
 assert(#caps>0 and #caps<500,'unexpected cap population')
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1];local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx*dx+dz*dz)
  for n=0,math.ceil(len*8) do for _,side in ipairs({-r.width*.25,-2,0,2,r.width*.25}) do
   local t=n/math.ceil(len*8);local x=a[1]+dx*t-dz/len*side;local z=a[3]+dz*t+dx/len*side;local y=a[2]+(b[2]-a[2])*t
   for _,c in ipairs(caps) do
    local rx,rz=x-c.center[1],z-c.center[3];local along=rx*c.ux+rz*c.uz;local lateral=math.abs(rx*c.uz-rz*c.ux)
    if math.abs(along)<=c.length/2+1 and lateral<=c.width/2+1 then
     local u=math.clamp(along/c.length+.5,0,1);if not c.highTowardB then u=1-u end
     local height=c.base+c.rise*u
     -- Native floor rays sample within the actual footprint with an unchanged
     -- .8 limit; the body probe begins 1 stud above route center height and
     -- is checked conservatively for a full extra stud around the footprint.
     if math.abs(along)<=c.length/2 and lateral<=c.width/2 then
      assert(height<y+.8,r.name..' cap raises sampled floor')
     end
     assert(height<y+1,r.name..' cap obstructs pedestrian body')
    end
   end
  end end
 end end
end)
check('Ruby overlook native collision location clears its minimally trimmed support cap',function()
 local route;for _,r in ipairs(plan.routes) do if r.name=='Ruby overlook' then route=r;break end end
 assert(route);local a,b=route.samples[6],route.samples[7]
 local len=math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2);local count=math.ceil(len/3)
 assert(count==1 and Layout.supportTrim(route.name,6)==.19)
 local c=Layout.supportCap(a,b,count,1,Layout.supportTrim(route.name,6))
 local x,y,z=-156.7444,19.542339,136.550415
 local rx,rz=x-c.center[1],z-c.center[3];local along=rx*c.ux+rz*c.uz
 local margin=.9*(math.abs(c.ux)+math.abs(c.uz))
 local u=c.highTowardB and math.clamp((along+margin)/c.length+.5,0,1) or 1-math.clamp((along-margin)/c.length+.5,0,1)
 assert(c.base+c.rise*u<y+1,'trimmed cap reaches reported avatar body')
 assert(Layout.supportTrim(route.name,5)==0 and Layout.supportTrim('Grove loop',6)==0)
end)
check('reported Grove and Fern failures cannot be raised by nearby joint supports',function()
 for _,case in ipairs({{name='Grove loop',x=-63.275322,z=114.320717,segment=22},
                       {name='Fern stair',x=53.873516,z=101.772247,segment=15}}) do
  local route;for _,r in ipairs(plan.routes) do if r.name==case.name then route=r end end
  assert(route);local _,floor=Layout.distance(case.x,case.z,route.samples[case.segment],route.samples[case.segment+1])
  local found=0
  for _,other in ipairs(plan.routes) do for i=2,#other.samples-1 do
   local center=other.samples[i];local radius=other.width/2
   if (case.x-center[1])^2+(case.z-center[3])^2<=(radius+1.5)^2 then
    found+=1;assert(Layout.jointTop(plan.routes,center,radius)<=floor-.249,case.name..' collision cap above route')
   end
  end end
  assert(found>0,'fixture must exercise a nearby joint')
 end
end)
check('pitched short seams remain within step height of overlapping pedestrian lanes',function()
 for _,r in ipairs(plan.routes) do for i=2,#r.samples-1 do
  local a,b=Layout.jointSeam(r.samples,i)
  local dx,dz=b[1]-a[1],b[3]-a[3];local length=math.sqrt(dx*dx+dz*dz)
  assert(length>0 and length<1,'seam should bridge only the local joint')
  for _,side in ipairs({-3,-2,-1,0,1,2,3}) do for _,t in ipairs({0,.5,1}) do
   local x=a[1]+dx*t-dz/length*side;local z=a[3]+dz*t+dx/length*side
   local y=a[2]+(b[2]-a[2])*t
   for _,other in ipairs(plan.routes) do for j=1,#other.samples-1 do
    local c,d=other.samples[j],other.samples[j+1];local vx,vz=d[1]-c[1],d[3]-c[3]
    local len2=vx*vx+vz*vz;local u=((x-c[1])*vx+(z-c[3])*vz)/len2
    local across=math.abs((x-c[1])*vz-(z-c[3])*vx)/math.sqrt(len2)
    if u>=0 and u<=1 and across<=other.width/2 then
     assert(y-(c[2]+(d[2]-c[2])*u)<.5,r.name..' raised seam over '..other.name)
    end
   end end
  end end
 end end
end)
check('curved road strips do not fold back above a walking lane',function()
 for _,r in ipairs(plan.routes) do for i=1,#r.samples-1 do
  local a,b=r.samples[i],r.samples[i+1];local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx*dx+dz*dz)
  local steps=math.ceil(len/2)
  for n=0,steps do for _,side in ipairs({-.25,0,.25}) do
   local t=n/steps;local x=a[1]+dx*t-dz/len*r.width*side;local z=a[3]+dz*t+dx/len*r.width*side;local y=a[2]+(b[2]-a[2])*t
   for j=1,#r.samples-1 do
    local c,d=r.samples[j],r.samples[j+1];local vx,vz=d[1]-c[1],d[3]-c[3];local length2=vx*vx+vz*vz
    local u=((x-c[1])*vx+(z-c[3])*vz)/length2
    if u>=0 and u<=1 then
     local across=math.abs((x-c[1])*vz-(z-c[3])*vx)/math.sqrt(length2)
     assert(across>r.width/2 or c[2]+(d[2]-c[2])*u<y+.65,r.name..' folded road edge')
    end
   end
  end end
 end end
end)
check('main flight corridors clear terrain without replacing original direct eased travel',function()
 local stations={{x=-56,y=10.5,z=-11}}
 for _,f in ipairs(plan.fields) do table.insert(stations,{x=f.x,y=f.top+12,z=f.z}) end
 for _,a in ipairs(stations) do for _,b in ipairs(stations) do
  for n=0,100 do
   local t=n/100;local x=a.x+(b.x-a.x)*t;local y=a.y+(b.y-a.y)*t;local z=a.z+(b.z-a.z)*t
   assert(plan:surface(x,z)<y-1.5,'terrain blocks direct flight '..a.x..','..a.z..' to '..b.x..','..b.z)
  end
 end end
end)
check('Ruby forest is tall, dense and clear of the mining footprint',function()
 local ruby=0
 assert(#plan.trees>=30)
 for _,t in ipairs(plan.trees) do
  assert(plan:fieldClear(t.x,t.z,t.h*.27));assert(plan:routeClear(t.x,t.z,3))
  if t.biome==2 then ruby+=1;assert(t.h>=19) end
 end
 assert(ruby>=8)
end)
check('depot and original Converter are not buried by the raised world',function()
 for x=-76,-36,2 do for z=-28,6,2 do near(plan:surface(x,z),.04) end end
 near(plan:surface(-86,-37.5),.04)
end)
check('field and route metadata follow the source spawn',function()
 local shifted=Layout.plan(Config.Fields,{-44,3.5,-18})
 for i,f in ipairs(plan.fields) do near(shifted.fields[i].x,f.x+12);near(shifted.fields[i].y,f.y+3);near(shifted.fields[i].z,f.z-7) end
 for i,r in ipairs(plan.routes) do for j,a in ipairs(r.samples) do
  local b=shifted.routes[i].samples[j];near(b[1],a[1]+12);near(b[2],a[2]+3);near(b[3],a[3]-7)
 end end
end)
check('all four starter walks join the depot and clear its three machines',function()
 local home={-56,.5,-11};local count=0
 local machines={{-68,-13},{-44,-13},{-56,-23}}
 for _,route in ipairs(plan.routes) do
  local a,b=Layout.depotLink(route,home)
  if a then
   count+=1;near(math.sqrt((a[1]-home[1])^2+(a[3]-home[3])^2),20)
   near(a[2],b[2]);near(a[2],.34)
   for _,machine in ipairs(machines) do
    local distance=Layout.distance(machine[1],machine[2],a,b)
    assert(distance>route.width/2+3.1,route.name..' clips a depot machine')
   end
   for n=0,50 do local t=n/50;local x=a[1]+(b[1]-a[1])*t;local z=a[3]+(b[3]-a[3])*t
    assert(plan:surface(x,z)<a[2],'depot link has no floor clearance')
   end
  end
 end
 assert(count==4)
end)
check('part-built terraces match their actual square cap and never use native meadow blades',function()
 assert(#plan.cells==Layout.Columns*Layout.Rows);assert(#plan.grass==0)
 for _,cell in ipairs(plan.cells) do
  local x=(cell.a[1]+cell.c[1])/2;local z=(cell.a[3]+cell.c[3])/2
  near(plan:surface(x,z),cell.h+.04)
  assert(cell.h<=math.min(cell.a[2],cell.b[2],cell.c[2],cell.d[2])+.001,'part clips higher than the original clearance vertices')
  assert(cell.faces==nil,'faceted geometry returned')
 end
end)
check('every generated tree has a grounded level root pad across cell borders',function()
 for _,t in ipairs(plan.trees) do
  local top,bottom=plan:foundation(t.x,t.z,3.2)
  near(t.ground,top);near(t.foundationBottom,bottom)
  assert(top-bottom<=4.5,'tree footing spans an abrupt cliff')
  for ix=-2,2 do for iz=-2,2 do
   local height=plan:surface(t.x+3.2*ix/2,t.z+3.2*iz/2)
   assert(height<=top+1e-6 and height>=bottom-1e-6,'unsupported tree footing')
  end end
 end
end)
check('depot miters follow their link and first road chord',function()
 local home={-56,.5,-11};local count=0
 for _,r in ipairs(plan.routes) do
  local a,b=Layout.depotSeam(r,home)
  if a then
   count+=1;local linkA,linkB=Layout.depotLink(r,home)
   local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx*dx+dz*dz)
   assert(len>.1 and len<6.5,'depot seam must stay short')
   local ix,iz=linkB[1]-linkA[1],linkB[3]-linkA[3];local ox,oz=r.samples[2][1]-linkB[1],r.samples[2][3]-linkB[3]
   local il=math.sqrt(ix*ix+iz*iz);local ol=math.sqrt(ox*ox+oz*oz);local cosine=math.clamp((ix*ox+iz*oz)/(il*ol),-.95,1)
   local need=r.width/2*math.sqrt((1-cosine)/(1+cosine))
   local approach=math.sqrt((a[1]-linkB[1])^2+(a[3]-linkB[3])^2)
   assert(approach+.175>=need,'miter too short for outside turn')
   for _,t in ipairs({0,.25,.5,.75,1}) do for _,side in ipairs({-.45,0,.45}) do
    local x=a[1]+dx*t-dz/len*r.width*side;local z=a[3]+dz*t+dx/len*r.width*side
    local y=a[2]+(b[2]-a[2])*t
    local d1,h1=Layout.distance(x,z,linkA,linkB);local d2,h2=Layout.distance(x,z,r.samples[1],r.samples[2])
    if d1<=r.width/2 then assert(y-h1<.5,'miter above depot approach') end
    if d2<=r.width/2 then assert(y-h2<.5,'miter above road approach') end
   end end
  end
 end
 assert(count==4,'all starter junctions need a miter')
end)
print(checks..' deterministic map geometry checks passed; not engine walking or multiplayer evidence')
