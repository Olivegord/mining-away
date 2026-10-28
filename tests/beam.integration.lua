-- Append to the actual Feedback/SentryMotion/Presentation modules and API double.
-- This checks endpoint lifecycle using synthetic geometry, not Roblox rendering.
function CF:VectorToObjectSpace(v) return self:PointToObjectSpace(self.Position+v) end
function CF:VectorToWorldSpace(v) return self:PointToWorldSpace(v)-self.Position end
local passed=0
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
local function check(name,fn)
 local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS beam integration '..name)
end
local localFx=Instance.new('Folder');localFx.Name='LocalFX';localFx.Parent=workspace
local presentation=Presentation.new({parent=localFx})
local target=Instance.new('UnionOperation');target.Name='Target';target.CanCollide=false;target.CanQuery=false;target.Position=Vector3.new(5,3,7);target.Size=Vector3.new(2,4,2);target.Parent=localFx
local source=Instance.new('UnionOperation');source.Parent=workspace
local rayCount=0;local mode='hit'
local function fakeRay(_workspace,origin,direction,params)
 rayCount+=1
 if mode=='throw' then error('synthetic collider failure') end
 if params.FilterType==Enum.RaycastFilterType.Include then
  assert(target.CanQuery==true,'local visual must be queryable only while sampling')
  if mode=='miss' then return nil end
  local contact=target.CFrame:PointToWorldSpace(Vector3.new(.25,target.Size.Y*.5,0))
  return {Instance=target,Position=contact,Normal=Vector3.new(0,1,0)}
 end
 if mode=='blocked' then return {Instance=source,Position=origin+direction*.4} end
 return nil
end
workspace.Raycast=fakeRay
local function anchor()
 return {origin={Parent=true,WorldPosition=Vector3.new(5,20,7)},endpoint={},marker={},
  core={},halo={},secondary={},secondaryPoint={},envelope=Feedback.newBeam(),surface={},secondarySurface={}}
end
local function sample(extra)
 local q={alive=true,active=true,key='resource-1',life=1,since=0,part=target,serverSource=source}
 for k,v in pairs(extra or {}) do q[k]=v end;return q
end
check('rendered emitter anchors to authored shell and strips clipped legacy textures',function()
 local fx=Instance.new('Folder');fx.Name='MiningFX';fx.Parent=rs
 local template=Instance.new('Model');template.Name='Beam';template.Parent=fx
 for _,name in ipairs({'InnerBeam','OuterBeam'}) do
  local b=Instance.new('Beam');b.Name=name;b.Texture='rbxasset://unsafe-legacy-clipped';b.Parent=template
 end
 local view=Instance.new('Model');view.Parent=localFx
 local body=Instance.new('Part');body.Position=Vector3.new(0,10,0);body.Size=Vector3.new(2,2,2);body.Parent=view;view.PrimaryPart=body
 local emitter=Instance.new('Part');emitter.Position=body.Position;emitter.Parent=view
 local beam=presentation:createMiningBeam(view,emitter)
 near(beam.origin.Position.Y,-1);assert(beam.origin.Parent==emitter)
 for _,layer in ipairs({beam.core,beam.halo,beam.secondary}) do
  assert(layer.FaceCamera==true and layer.Texture=='' and layer.Segments==1)
 end
 assert(beam.core.Attachment0==beam.origin and beam.halo.Attachment0==beam.origin)
 assert(beam.core.Attachment1==beam.halo.Attachment1)
 assert(not beam.core.Enabled and not beam.halo.Enabled and not beam.secondary.Enabled)
 presentation:destroyMiningBeam(beam);assert(beam.holder.Parent==nil and beam.origin.Parent==nil)
 view:Destroy();fx:Destroy()
end)
check('real presentation samples visible collision and restores query flag',function()
 local b=anchor();presentation:beginFrame();rayCount=0
 local point,normal=presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,1)
 assert(point and normal);near(point.X,5.25);near(point.Y,5);near(point.Z,7)
 assert(target.CanQuery==false);assert(rayCount==2);assert(presentation.beamRays==2)
end)
check('cached hit tracks translation rotation and shrink every render',function()
 local b=anchor();presentation:beginFrame();rayCount=0
 local p=presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,2);assert(p)
 target.Size=Vector3.new(1,2,1);target.CFrame=CFrame.new(10,4,3)*CFrame.Angles(0,math.pi*.5,0)
 local next=presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,2.01)
 local expected=target.CFrame:PointToWorldSpace(Vector3.new(.125,1,0))
 near(next.X,expected.X);near(next.Y,expected.Y);near(next.Z,expected.Z);assert(rayCount==2)
end)
check('occluded missing and throwing target clear verified contact safely',function()
 local b=anchor();target.CFrame=CFrame.new(5,3,7);target.Size=Vector3.new(2,4,2)
 presentation:beginFrame();mode='hit';assert(presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,3))
 mode='blocked';assert(presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,3.2)==nil);assert(b.surface.anchor==nil)
 mode='miss';assert(presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,3.4)==nil)
 mode='throw';assert(presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,3.6)==nil);assert(target.CanQuery==false);mode='hit'
end)
check('query budget counts both target and occlusion rays, no cache means no beam',function()
 presentation:beginFrame();rayCount=0
 for _=1,6 do local b=anchor();assert(presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,4)) end
 assert(presentation.beamRays==12);assert(rayCount==12)
 local b=anchor();assert(presentation:_surface(b,b.surface,b.origin.WorldPosition,target,source,4)==nil)
 assert(presentation.beamRays==12);assert(rayCount==12)
end)
check('actual presentation follows current contact and clears target on reprint',function()
 local b=anchor();local q=sample();presentation:beginFrame()
 q.since=0;presentation:renderMiningBeam(b,q,2)
 assert(b.core.Enabled and b.halo.Enabled);near(b.endpoint.Position.Y,5)
 near(b.marker.Position.Y,5.07)
 target.Size=Vector3.new(1,2,1);target.Position=Vector3.new(8,4,9)
 presentation:renderMiningBeam(b,q,2.01);near(b.endpoint.Position.X,8.125);near(b.endpoint.Position.Y,5)
 q.alive=false;q.life=2;presentation:renderMiningBeam(b,q,2.02)
 assert(not b.core.Enabled and not b.halo.Enabled);near(b.marker.Transparency,1);assert(b.surface.anchor==nil)
 target.Size=Vector3.new(2,4,2);target.Position=Vector3.new(5,3,7)
end)
check('an unavailable target or wall never displays a stale beam',function()
 local b=anchor();local q=sample();presentation:beginFrame();presentation:renderMiningBeam(b,q,2)
 assert(b.core.Enabled);mode='blocked';presentation:renderMiningBeam(b,q,2.2)
 assert(not b.core.Enabled and not b.halo.Enabled and not b.secondary.Enabled);near(b.marker.Transparency,1);mode='hit'
 q.part=nil;presentation:renderMiningBeam(b,q,2.3);assert(not b.core.Enabled)
end)
-- Load tests execute the actual frame queue and ray scheduler against a
-- deterministic collision double. This is not Roblox rendering evidence.
local blockedAll=false
workspace.Raycast=function(_,origin,direction,params)
 rayCount+=1
 if params.FilterType==Enum.RaycastFilterType.Include then
  local part=params.FilterDescendantsInstances[1]
  return {Instance=part,Position=part.Position+Vector3.new(0,part.Size.Y*.5,0),Normal=Vector3.new(0,1,0)}
 end
 if blockedAll then return {Instance=source,Position=origin+direction*.4} end
 return nil
end
local function population(n,branches)
 local rows={}
 for i=1,n do
  local part=Instance.new('Part');part.Position=Vector3.new(i,0,0);part.Size=Vector3.new(2,2,2);part.Parent=localFx
  local b=anchor();b.origin.WorldPosition=Vector3.new(i,10,0)
  local q={alive=true,active=true,key='rock-'..i,life=1,since=0,part=part}
  if branches then q.secondaryPart=part;q.secondaryKey='branch-'..i end
  rows[i]={b=b,q=q}
 end
 return rows
end
local function frame(p,rows,now,reverse)
 p:beginFrame();rayCount=0
 if reverse then for i=#rows,1,-1 do local r=rows[i];p:queueMiningBeam(r.b,r.q,now) end
 else for _,r in ipairs(rows) do p:queueMiningBeam(r.b,r.q,now) end end
 p:flushMiningBeams();assert(p.beamRays<=12 and rayCount<=12,'frame exceeded ray budget')
end
for _,fps in ipairs({30,60,144}) do
 for _,branches in ipairs({false,true}) do
  check(('fair %d fps with 48 primary beams, branches %s'):format(fps,tostring(branches)),function()
   local p=Presentation.new({parent=localFx});local rows=population(48,branches);local seen={}
   for i=1,fps*3 do
    frame(p,rows,i/fps,i%2==0)
    for n,r in ipairs(rows) do if r.b.core.Enabled then seen[n]=true end end
    if i>fps then for _,r in ipairs(rows) do assert(r.b.core.Enabled,'verified primary starved or flickered') end end
   end
   for n=1,48 do assert(seen[n],'primary never received service') end
  end)
 end
end
check('inactive retained targets consume no rays after recall fade',function()
 local p=Presentation.new({parent=localFx});local rows=population(48,false)
 for i=1,18 do rows[i].q.active=false end
 for i=1,90 do frame(p,rows,i/30);if i>15 then for n=19,48 do assert(rows[n].b.core.Enabled) end end end
 for i=1,18 do assert(rows[i].b.surface.lastSample==nil,'inactive beam consumed a ray') end
end)
check('all due primary contacts precede optional secondary branches',function()
 local p=Presentation.new({parent=localFx});local rows=population(6,true)
 frame(p,rows,1);assert(p.beamRays==12)
 for _,r in ipairs(rows) do assert(r.b.surface.verifiedAt==1 and r.b.secondarySurface.verifiedAt==nil) end
 frame(p,rows,1.01);assert(p.beamRays==12)
 for _,r in ipairs(rows) do assert(r.b.secondarySurface.verifiedAt==1.01) end
end)
check('prewarmed contact is invalidated after new wall under contention',function()
 local p=Presentation.new({parent=localFx});local rows=population(48,false)
 for i=1,45 do frame(p,rows,i/30) end
 assert(rows[48].b.core.Enabled);blockedAll=true
 for i=46,90 do frame(p,rows,i/30) end
 for _,r in ipairs(rows) do assert(not r.b.core.Enabled,'occluded cached contact remained visible') end
 blockedAll=false
end)
check('population growth removal and severe overload remain fair with bounded expiry',function()
 local p=Presentation.new({parent=localFx});local rows=population(240,true);local seen={};local expired=false
 for i=1,180 do
  frame(p,rows,i/30,i%2==0)
  for n,r in ipairs(rows) do if r.b.core.Enabled then seen[n]=true elseif i>45 and r.b.surface.lastSample then expired=true end end
 end
 for n=1,240 do assert(seen[n],'overloaded beam never served') end
 assert(expired,'overloaded verified anchors must expire instead of remaining stale')
 for i=240,49,-1 do table.remove(rows,i) end
 for i=181,240 do frame(p,rows,i/30) end
 for _,r in ipairs(rows) do assert(r.b.core.Enabled,'remaining population did not recover') end
end)
check('recall preserves original 0.2 second fade without idle queries',function()
 local p=Presentation.new({parent=localFx});local rows=population(1,false);local b=rows[1].b
 frame(p,rows,1);frame(p,rows,3);near(b.core.Width0,.3)
 rows[1].q.active=false;frame(p,rows,3.01);near(b.core.Width0,.3)
 frame(p,rows,3.11);near(b.core.Width0,.075)
 frame(p,rows,3.21);near(b.core.Width0,0)
 frame(p,rows,3.5);assert(p.beamRays==0 and not b.core.Enabled)
end)
check('an almost-expired verified contact completes recall fade but cannot survive death',function()
 local p=Presentation.new({parent=localFx});local rows=population(1,false);local b=rows[1].b
 frame(p,rows,1);frame(p,rows,3);near(b.core.Width0,.3)
 -- Artificially withhold subsequent queries while the last successful hit ages.
 b.surface.nextSample=4;rows[1].q.active=false;frame(p,rows,3.74);near(b.core.Width0,.3)
 frame(p,rows,3.84);near(b.core.Width0,.075)
 rows[1].q.alive=false;frame(p,rows,3.85);assert(not b.core.Enabled and not b.surface.anchor)
end)
check('continuous arrivals do not starve older due contacts',function()
 local p=Presentation.new({parent=localFx});local rows=population(48,false)
 for i=1,60 do frame(p,rows,i/30) end
 local persistent={};for i=1,12 do persistent[i]=rows[i] end
 for frameNo=61,150 do
  for _=1,3 do table.remove(rows,13) end
  for _,r in ipairs(population(3,false)) do table.insert(rows,r) end
  frame(p,rows,frameNo/30,frameNo%2==0)
  for _,r in ipairs(persistent) do
   assert(r.b.core.Enabled,'continuous new arrivals starved existing contact')
   assert(frameNo/30-r.b.surface.verifiedAt<.75,'existing contact was not reverified')
  end
 end
end)
print(passed..' production Presentation endpoint and bounded scheduling checks with synthetic API double; not a Studio visual test')
