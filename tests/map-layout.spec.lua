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
  if not plan:hubClear(x,z,-8) then near(plan:surface(x,z),0) end
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
   assert(plan:surface(x,z)<=math.max(0,f.top-2),'terrain intrudes field '..f.x)
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
 for x=-76,-36,2 do for z=-28,6,2 do near(plan:surface(x,z),0) end end
 near(plan:surface(-86,-37.5),0)
end)
check('field and route metadata follow the source spawn',function()
 local shifted=Layout.plan(Config.Fields,{-44,3.5,-18})
 for i,f in ipairs(plan.fields) do near(shifted.fields[i].x,f.x+12);near(shifted.fields[i].y,f.y+3);near(shifted.fields[i].z,f.z-7) end
 for i,r in ipairs(plan.routes) do for j,a in ipairs(r.samples) do
  local b=shifted.routes[i].samples[j];near(b[1],a[1]+12);near(b[2],a[2]+3);near(b[3],a[3]-7)
 end end
end)
check('native meadow covers broad connected land and keeps gameplay footprints clear',function()
 assert(#plan.grass*16>30000,'meadow regressed to isolated little patches')
 local dry,wet=0,0
 for _,cell in ipairs(plan.grass) do
  assert(plan:routeClear(cell.x,cell.z,3),'native grass intrudes on a route')
  assert(plan:fieldClear(cell.x,cell.z,4),'native grass intrudes on an ore clearing')
  assert(math.abs(cell.x+56)>=24 or math.abs(cell.z+11)>=21,'native grass covers the depot')
  assert(cell.blades==nil,'per-blade replication returned')
  if cell.dry then dry+=1 else wet+=1 end
 end
 assert(dry>#plan.grass*.05 and wet>#plan.grass*.7,'missing green/dry-ground variation')
end)
print(checks..' deterministic map geometry checks passed; not engine walking or multiplayer evidence')
