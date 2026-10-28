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
print(passed..' production Presentation endpoint checks passed with synthetic API double; not a Studio visual test')
