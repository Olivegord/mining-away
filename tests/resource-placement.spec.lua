local P=require('../src/ResourcePlacement')
local Mining=require('../src/Mining')
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS resource placement '..name) end
local function rng(seed)
 return function(low,high) seed=(seed*16807)%2147483647;return low+(high-low)*(seed/2147483647) end
end
check('rotated and tilted corners stay inside the reserved footprint',function()
 for _,size in ipairs({{2,4,3},{10.4,10.4,10.4},{1,9,2}}) do
  local radius=P.radius(size[1],size[2],size[3])
  for i=1,200 do
   local a,b,c=i*.17,i*.31,i*.23
   for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
    local x,y,z=sx*size[1]*.5,sy*size[2]*.5,sz*size[3]*.5
    x,y=x*math.cos(c)-y*math.sin(c),x*math.sin(c)+y*math.cos(c)
    x,z=x*math.cos(b)+z*math.sin(b),-x*math.sin(b)+z*math.cos(b)
    y,z=y*math.cos(a)-z*math.sin(a),y*math.sin(a)+z*math.cos(a)
    assert(math.sqrt(x*x+z*z)<=radius+1e-8)
   end end end
  end
 end
end)
check('spacing adds both radii and remains symmetric for large neighbors',function()
 local small=P.radius(3,3,3);local large=P.radius(10.4,10.4,10.4)
 assert(not P.fits(10,0,60,60,small,{{x=0,z=0,radius=large}}))
 assert(not P.fits(10,0,60,60,large,{{x=0,z=0,radius=small}}))
 local gap=small+large+P.GAP+.001
 assert(P.fits(gap,0,60,60,small,{{x=0,z=0,radius=large}}))
end)
check('large rocks and shell reveals fit completely inside field boundaries',function()
 local radius=P.radius(10.4,10.4,10.4)
 local limit=21-radius-P.EDGE_MARGIN
 assert(P.fits(limit,0,42,42,radius,{}))
 assert(not P.fits(limit+.01,0,42,42,radius,{}))
 local shell=P.radius(4,4,4,'Geode')
 local shard=Mining.resource(70,'Shard',1)
 assert(shell>=4+P.radius(shard.size,shard.size,shard.size))
end)
check('blocked fields consume at most eighteen expensive clearance queries',function()
 local calls=0
 local result,attempts=P.sample(42,42,2,{},rng(42),function()calls+=1;return false end)
 assert(not result and attempts==P.MAX_ATTEMPTS and calls==P.MAX_ATTEMPTS)
 local impossible,count=P.sample(5,5,4,{},function()error('must not draw impossible coordinates')end)
 assert(not impossible and count==0)
end)
check('occupied points reject before querying world geometry',function()
 local calls=0
 local result,attempts=P.sample(42,42,2,{{x=0,z=0,radius=10}},function()return 0 end,function()calls+=1;return true end)
 assert(not result and attempts==18 and calls==0)
end)
check('grower plans revalidate without rerolling position or material footprint',function()
 local preferred={x=5,z=-3}
 local noRandom=function()error('committed plan rerolled')end
 local result,attempts=P.sample(42,42,3,{},noRandom,nil,preferred)
 assert(result and result.x==5 and result.z==-3 and attempts==1)
 local blocked,count=P.sample(42,42,3,{{x=5,z=-3,radius=1}},noRandom,nil,preferred)
 assert(not blocked and count==1)
 local malformed=P.sample(42,42,3,{},noRandom,nil,{x=5})
 assert(not malformed)
end)
check('seeded field populations preserve random positions without overlap',function()
 for seed=1,60 do
  local random=rng(seed);local occupied={};local successes=0
  for _=1,48 do
   local boulder=#occupied==0 or random(0,1)<Mining.BOULDER_CHANCE
   local roll=math.floor(random(50,101));local size=Mining.resource(roll,'Crystal',1).size
   if boulder then size*=Mining.BOULDER_SIZE end
   local radius=P.radius(size,size,size)
   local sample=P.sample(42,42,radius,occupied,random)
   if sample then
    assert(P.fits(sample.x,sample.z,42,42,radius,occupied))
    table.insert(occupied,sample);successes+=1
   end
   if successes>=16 then break end
  end
  assert(successes>=16,'starter-sized field cannot populate after bounded retries: '..seed)
 end
end)
check('invalid dimensions and coordinates cannot produce an invalid spawn',function()
 assert(not P.radius(0,2,2) and not P.radius(0/0,2,2) and not P.radius(2,math.huge,2))
 assert(not P.fits(0/0,0,42,42,2,{}) and not P.fits(0,0,42,42,-1,{}))
end)
print(checks..' pure resource placement checks; native obstruction coverage and population pacing require Studio')
