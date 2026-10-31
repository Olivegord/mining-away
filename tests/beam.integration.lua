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
check('mining types retain original inner ramp but show distinct outer geometry',function()
 local tipWidths={}
 for _,style in ipairs({'Cutter','Percussion','Resonance'}) do
  local p=Presentation.new({parent=localFx});local b=anchor()
  local q=sample({style=style,contact=true,pulseSerial=1,pulseAt=2,pulseKey='resource-1'})
  p:beginFrame();p:renderMiningBeam(b,q,0);near(b.core.Width0,0)
  p:beginFrame();p:renderMiningBeam(b,q,1);near(b.core.Width0,.225)
  p:beginFrame();p:renderMiningBeam(b,q,2);near(b.core.Width0,.3)
  tipWidths[style]=b.halo.Width1
  q.active=false;p:beginFrame();p:renderMiningBeam(b,q,2.01)
  p:beginFrame();p:renderMiningBeam(b,q,2.21);near(b.core.Width0,0);assert(not b.core.Enabled)
 end
 assert(tipWidths.Percussion>tipWidths.Cutter and tipWidths.Cutter>tipWidths.Resonance)
end)
check('live Dart and Striker retain distinct colors with the same cutter behavior',function()
 local tints={}
 for _,kind in ipairs({'Dart','Striker'}) do
  local p=Presentation.new({parent=localFx});local b=anchor()
  p:beginFrame();p:renderMiningBeam(b,sample({style='Cutter',droneType=kind}),2)
  near(b.core.Width0,.3);near(b.halo.Width1,.42);tints[kind]=b.halo.Color
 end
 assert(tints.Dart.B>tints.Dart.R and tints.Striker.R>tints.Striker.B)
end)
check('percussion accents require a real matching hit and never replay on late join',function()
 local p=Presentation.new({parent=localFx});local b=anchor();local sounds=0
 p._sound=function(_,_,kind) assert(kind=='mining');sounds+=1 end
 local q=sample({style='Percussion',contact=true,pulseSerial=7,pulseAt=2,pulseKey='resource-1'})
 p:beginFrame();p:renderMiningBeam(b,q,2);near(b.halo.Width1,.79);near(b.marker.Size.X,.34);assert(sounds==0)
 q.pulseSerial=8;q.pulseAt=2.8;p:beginFrame();p:renderMiningBeam(b,q,2.8);assert(sounds==1)
 p:renderMiningBeam(b,q,2.81);assert(sounds==1)
 q.pulseKey='old-resource';q.pulseSerial=9;q.pulseAt=3.6;p:beginFrame();p:renderMiningBeam(b,q,3.6)
 near(b.halo.Width1,.34);near(b.marker.Size.X,.14);assert(sounds==1)
 q.pulseKey=q.key;q.paused=true;q.pulseSerial=10;q.pulseAt=4.4;p:beginFrame();p:renderMiningBeam(b,q,4.4)
 near(b.halo.Width1,.34);assert(sounds==1)
 q.paused=false;q.pulseSerial=11;q.pulseAt=5.2;mode='blocked';p:beginFrame();p:renderMiningBeam(b,q,5.2)
 assert(not b.core.Enabled and sounds==1);mode='hit'
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
  local q={alive=true,active=true,key='rock-'..i,life=1,since=0,part=part,style=({'Cutter','Percussion','Resonance'})[(i-1)%3+1]}
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
check('final-hit branch uses still-visible breaking meshes and original beam age',function()
 local p=Presentation.new({parent=localFx});local rows=population(1,true);local r=rows[1]
 local primarySource=Instance.new('Part');primarySource.Parent=workspace;primarySource:SetAttribute('HP',0)
 local secondarySource=Instance.new('Part');secondarySource.Parent=workspace;secondarySource:SetAttribute('HP',0)
 r.q.serverSource=primarySource;r.q.secondarySource=secondarySource;r.q.style='Resonance'
 -- HP can retire the ordinary endpoint before its final contact arrives.
 frame(p,rows,1.9);r.q.part=nil;r.q.active=false;frame(p,rows,2)
 assert(not r.b.core.Enabled)
 r.q.part=r.q.secondaryPart;r.q.active=true;r.q.breakContactAt=2;r.q.breakContactUntil=2.3
 frame(p,rows,2.05)
 near(r.b.core.Width0,.3);assert(r.b.secondary.Enabled and r.b.branchHold==nil)
 frame(p,rows,2.31);assert(not r.b.core.Enabled and not r.b.secondary.Enabled)
 assert(rayCount==0,'expired final contact consumed surface queries')
end)
check('final contact expires without an ordinary branch hold or late-join audio replay',function()
 local p=Presentation.new({parent=localFx});local rows=population(1,true);local r=rows[1];local sounds=0
 p._sound=function() sounds+=1 end
 r.q.style='Percussion';r.q.breakContactAt=2;r.q.breakContactUntil=20
 r.q.pulseSerial=12;r.q.pulseAt=2;r.q.pulseKey=r.q.key
 frame(p,rows,2.01);assert(r.b.core.Enabled and r.b.secondary.Enabled and sounds==0)
 frame(p,rows,2.3);assert(not r.b.core.Enabled and not r.b.secondary.Enabled and r.b.branchHold==nil)
 assert(sounds==0,'a late contact replayed impact audio')
end)
check('final contact obeys pause death and disappearing fracture geometry',function()
 for _,cause in ipairs({'paused','dead','hidden','removed'}) do
  local p=Presentation.new({parent=localFx});local rows=population(1,true);local r=rows[1]
  r.q.breakContactAt=2;r.q.breakContactUntil=2.3;frame(p,rows,2.01);assert(r.b.secondary.Enabled)
  if cause=='paused' then r.q.paused=true elseif cause=='dead' then r.q.alive=false
  elseif cause=='hidden' then r.q.part.Transparency=1 else r.q.part:Destroy() end
  frame(p,rows,2.02);assert(not r.b.core.Enabled and not r.b.secondary.Enabled and rayCount==0,cause)
 end
end)
check('final-hit contacts share the existing ray budget and cannot persist under overload',function()
 local p=Presentation.new({parent=localFx});local rows=population(48,true)
 for _,r in ipairs(rows) do r.q.breakContactAt=2;r.q.breakContactUntil=2.3 end
 for n=1,12 do frame(p,rows,2+n/30) end
 for _,r in ipairs(rows) do assert(not r.b.core.Enabled and not r.b.secondary.Enabled and r.b.branchHold==nil) end
end)
check('simultaneous percussion audio is globally throttled and pool bounded',function()
 local p=Presentation.new({parent=localFx});local rows=population(48,false)
 for _,r in ipairs(rows) do r.q.style='Percussion';r.q.pulseSerial=1;r.q.pulseAt=1;r.q.pulseKey=r.q.key end
 for i=1,30 do frame(p,rows,i/30) end
 assert(#p.pulses==0,'late discovery sounded old impacts')
 for _,r in ipairs(rows) do r.q.pulseSerial=2;r.q.pulseAt=1.8 end
 frame(p,rows,1.8);assert(#p.pulses==1,'simultaneous fleet hits produced audio spam')
 frame(p,rows,1.81);assert(#p.pulses==1,'same hit replayed audio')
 for n=3,25 do
  for _,r in ipairs(rows) do r.q.pulseSerial=n;r.q.pulseAt=n*.8 end
  frame(p,rows,n*.8);assert(#p.pulses<=p.maxPulses,'audio exceeded existing effect pool')
 end
end)
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
check('primary has four slots, branches reserve two, unused capacity returns',function()
 local p=Presentation.new({parent=localFx});local rows=population(6,true)
 frame(p,rows,1);assert(p.beamRays==12)
 local main,branch=0,0
 for _,r in ipairs(rows) do if r.b.surface.verifiedAt then main+=1 end;if r.b.secondarySurface.verifiedAt then branch+=1 end end
 assert(main==4 and branch==2,'contested frame must reserve primary majority and branch service')
 local only=Presentation.new({parent=localFx});local plain=population(6,false);frame(only,plain,1)
 for _,r in ipairs(plain) do assert(r.b.surface.verifiedAt==1,'unused branch capacity lost') end
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
for _,case in ipairs({{30,18},{60,30},{30,48},{60,48},{144,48}}) do
 check(('branches get bounded sustained service %dfps %d beams'):format(case[1],case[2]),function()
  local fps,n=case[1],case[2];local p=Presentation.new({parent=localFx});local rows=population(n,true)
  local seenPrimary,seenBranch={},{};local lastBranch={};local maxGap=0
  for i=1,fps*10 do
   frame(p,rows,i/fps,i%2==0)
   for j,r in ipairs(rows) do
    if r.b.core.Enabled then seenPrimary[j]=true end
    if r.b.secondary.Enabled then seenBranch[j]=true end
    if i>fps and n==48 then assert(r.b.core.Enabled and r.b.secondary.Enabled,'48-contact normal load flickered') end
    local t=r.b.secondarySurface.lastSample
    if t and t~=lastBranch[j] then
     if lastBranch[j] and i>fps*2 then maxGap=math.max(maxGap,t-lastBranch[j]) end
     lastBranch[j]=t
    end
   end
  end
  for j=1,n do assert(seenPrimary[j] and seenBranch[j],'contact never appeared '..j);assert(lastBranch[j] and 10-lastBranch[j]<1.3,'branch starvation '..j) end
  assert(maxGap<1.3,'branch service gap '..maxGap)
 end)
end
for _,case in ipairs({{80,43},{43,43}}) do
 check(('asymmetric feasible load preserves freshness %d primaries %d branches'):format(case[1],case[2]),function()
  local p=Presentation.new({parent=localFx});local rows=population(case[1],true)
  for i=case[2]+1,#rows do rows[i].q.secondaryPart=nil;rows[i].q.secondaryKey=nil end
  for i=1,180 do
   frame(p,rows,i/30,i%2==0)
   if i>90 then for n,r in ipairs(rows) do
    assert(r.b.core.Enabled,'primary flickered in feasible asymmetric load '..n)
    if n<=case[2] then assert(r.b.secondary.Enabled,'branch flickered in feasible asymmetric load '..n) end
   end end
  end
 end)
end
check('branch churn and target key changes invalidate stale secondary contact',function()
 local p=Presentation.new({parent=localFx});local rows=population(18,true)
 for i=1,60 do frame(p,rows,i/30) end
 for i=1,9 do rows[i].q.secondaryKey=nil;rows[i].q.secondaryPart=nil end
 for i=61,100 do frame(p,rows,i/30) end
 for i=1,9 do assert(not rows[i].b.secondary.Enabled and not rows[i].b.secondarySurface.anchor) end
 for i=1,9 do rows[i].q.secondaryKey='new-'..i;rows[i].q.secondaryPart=rows[i].q.part end
 for i=101,150 do frame(p,rows,i/30) end
 for i=1,18 do assert(rows[i].b.secondary.Enabled,'branch did not recover after changing load') end
 local r=rows[1];r.q.secondaryKey='different';blockedAll=true;frame(p,rows,151/30);blockedAll=false
 assert(not r.b.secondary.Enabled and not r.b.secondarySurface.anchor,'changed branch key reused old surface')
end)
for _,case in ipairs({{30,18},{30,48},{60,30},{60,48},{144,48}}) do
 local fps,n=case[1],case[2]
 check(('short authoritative proc burst gets bounded cosmetic service at %dfps for %d beams'):format(fps,n),function()
  local p=Presentation.new({parent=localFx});local rows=population(n,true);local seen={}
  for i=1,fps*2 do
   if i/fps>.18 then for _,r in ipairs(rows) do r.q.secondaryKey=nil;r.q.secondaryPart=nil end end
   frame(p,rows,i/fps)
   for j,r in ipairs(rows) do if r.b.secondary.Enabled then seen[j]=true end end
  end
  for j,r in ipairs(rows) do assert(seen[j],'short proc branch never displayed '..j);assert(not r.b.secondary.Enabled and not r.b.branchHold,'cosmetic extension failed to expire') end
 end)
end
check('extreme burst expires bounded unserved cosmetic backlog',function()
 local p=Presentation.new({parent=localFx});local rows=population(240,true);local seen={}
 for i=1,75 do
  local now=i/30;if now>.18 then for _,r in ipairs(rows) do r.q.secondaryPart=nil;r.q.secondaryKey=nil end end
  frame(p,rows,now)
  for n,r in ipairs(rows) do if r.b.secondary.Enabled then seen[n]=true end end
 end
 local total=0;for n,r in ipairs(rows) do if seen[n] then total+=1 end;assert(not r.b.branchHold and not r.b.secondary.Enabled,'expired event leaked') end
 assert(total>0 and total<240,'extreme finite-budget limitation not exercised')
end)
check('held proc clears on death, target loss, life and primary changes',function()
 for _,cause in ipairs({'dead','gone','life','primary','inactive','occluded'}) do
  local p=Presentation.new({parent=localFx});local rows=population(18,true);local r=rows[18]
  local secondarySource=Instance.new('Part');secondarySource.Parent=workspace;secondarySource:SetAttribute('HP',100);r.q.secondarySource=secondarySource
  frame(p,rows,1);r.q.secondaryPart=nil;r.q.secondaryKey=nil
  if cause=='dead' then secondarySource:SetAttribute('HP',0)
  elseif cause=='gone' then secondarySource:Destroy()
  elseif cause=='life' then r.q.life=2
  elseif cause=='primary' then r.q.key='another-primary'
  elseif cause=='inactive' then r.q.active=false
  else blockedAll=true end
  for i=1,50 do frame(p,rows,1+i/30);assert(not r.b.secondary.Enabled,'invalid held branch visible: '..cause) end
  if cause~='occluded' then assert(not r.b.branchHold,'invalid hold survived: '..cause) end
  blockedAll=false
 end
end)
check('delayed proc extension expires after first verified contact without refresh',function()
 local p=Presentation.new({parent=localFx});local rows=population(18,true);local r=rows[18]
 frame(p,rows,1);r.q.secondaryPart=nil;r.q.secondaryKey=nil
 local first
 for i=1,36 do
  local now=1+i/30;frame(p,rows,now)
  if r.b.branchHold and r.b.branchHold.firstVerifiedAt then first=first or r.b.branchHold.firstVerifiedAt end
  if first and now>first+.12 then assert(not r.b.secondary.Enabled and not r.b.branchHold,'verified extension refreshed beyond .12s') end
 end
 assert(first,'late proc was never verified')
end)
print(passed..' production Presentation endpoint and bounded scheduling checks with synthetic API double; not a Studio visual test')
