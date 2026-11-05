-- Real production renderers with synthetic engine APIs, never native footage.
function CF:VectorToObjectSpace(v) return self:PointToObjectSpace(self.Position+v) end
function CF:VectorToWorldSpace(v) return self:PointToWorldSpace(v)-self.Position end
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS beam VFX '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
local root=Instance.new('Folder');root.Parent=workspace
local camera=Instance.new('Camera');camera.CFrame=CFrame.new(0,5,14);workspace.CurrentCamera=camera
local color=Color3.fromRGB(130,210,255)
local from,to=Vector3.new(0,8,0),Vector3.zero
check('every line family has a bounded and distinct vocabulary',function()
 for _,name in ipairs({'Cutter','Percussion','Resonance','Combat','Branch','Repair','Courier','Sentry','Lance','Orbital','Gridcutter','Starforge','Singularity'}) do
  local p=assert(BeamVFX.styles[name],name);assert(p.body>0 and p.body<=1.8 and p.taper>0 and p.taper<1 and p.tail<=1.1)
 end
 assert(BeamVFX.styles.Orbital.orbit>BeamVFX.styles.Cutter.orbit*5)
 assert(BeamVFX.styles.Repair.spin<BeamVFX.styles.Combat.spin)
end)
check('charge gathers compresses and changes silhouette before release',function()
 local full=BeamVFX.charge(.76);local compressed=BeamVFX.charge(.9)
 assert(full>.99 and compressed<.4)
 local _,glint=BeamVFX.charge(1);near(glint,1)
 local r=BeamVFX.new(root,'Orbital',color)
 BeamVFX.draw(r,from,to,10,0,.93,nil)
 assert(r.rich and r.rich.core.Transparency==0 and not r.core.Enabled)
 assert(r.paths[1].beam.CurveSize0>0 and r.paths[1].a.CFrame~=r.paths[1].b.CFrame)
 local size=r.rich.glass.Size.X;BeamVFX.draw(r,from,to,10.1,0,.985,nil);assert(r.rich.glass.Size.X<size)
 BeamVFX.draw(r,from,to,10.2,1,nil,0)
 assert(r.orb.Transparency==1 and r.stars[1].beam.Enabled and r.stars[1].beam.Width1==0)
 assert(#r.stars==4 and r.paths[4].beam.LightEmission==0,'dark seam must use normal blending')
 BeamVFX.destroy(r)
end)
check('display-rate-independent paths and widths at matching timestamps',function()
 local expected
 for _,fps in ipairs({30,60,144}) do
  local r=BeamVFX.new(root,'Cutter',color)
  for frame=0,fps do BeamVFX.draw(r,from,to,20+frame/fps,.5,nil,frame/fps) end
  if expected then near(r.paths[1].a.Position.X,expected) else expected=r.paths[1].a.Position.X end
  near(r.body.Width0,.15);assert(r.body.Width1<r.body.Width0)
  near((r.root.Position+r.b.Position-to).Magnitude,0)
  assert(not r.stars[1].beam.Enabled,'late observer replayed ignition')
  BeamVFX.destroy(r)
 end
end)
check('main body trace star and flecks end on independent clocks',function()
 local r=BeamVFX.new(root,'Lance',color)
 BeamVFX.draw(r,from,to,30,1,nil,0)
 BeamVFX.after(r,from,to,30.25,.05)
 assert(not r.body.Enabled and r.paths[3].beam.Enabled and r.stars[1].beam.Enabled)
 BeamVFX.after(r,from,to,30.5,.3)
 assert(not r.paths[3].beam.Enabled and r.stars[1].beam.Enabled and r.paths[1].beam.Enabled)
 BeamVFX.after(r,from,to,31,1)
 for _,v in ipairs(r.all) do assert(not v.Enabled) end
 BeamVFX.destroy(r)
end)
check('reduced effects keeps contact and drops curved detail and flashes',function()
 local p=Instance.new('Player');players.LocalPlayer=p
 local r=BeamVFX.new(root,'Orbital',color);BeamVFX.draw(r,from,to,40,1,nil,0)
 assert(r.detail)
 p:SetAttribute('ReducedEffects',true);BeamVFX.draw(r,from,to,40.01,1,nil,.01)
 assert(not r.detail and r.body.Enabled and r.core.Enabled)
 p:SetAttribute('ReducedEffects',false);p:SetAttribute('ReducedMotion',true)
 BeamVFX.draw(r,from,to,40.02,1,nil,.02);assert(not r.detail)
 players.LocalPlayer=nil;p:Destroy();BeamVFX.destroy(r)
end)
check('shared caps culling parent removal and repeated activation release leases',function()
 local rigs={}
 for i=1,100 do
  local r=BeamVFX.new(root,'Combat',color)
  if r then rigs[#rigs+1]=r;BeamVFX.draw(r,from,to,50,1,nil,0) end
 end
 for i=1,4 do
  local r=assert(BeamVFX.new(root,'Orbital',color),'ordinary work consumed the priority reserve')
  rigs[#rigs+1]=r;BeamVFX.draw(r,from,to,50,1,nil,0)
 end
 local live,detail=BeamVFX.counts();assert(live==64 and detail==12)
 camera.CFrame=CFrame.new(1000,0,0)
 for _,r in ipairs(rigs) do BeamVFX.draw(r,from,to,50.1,1,nil,.1) end
 local _,after=BeamVFX.counts();assert(after==0)
 for _,r in ipairs(rigs) do BeamVFX.destroy(r) end
 camera.CFrame=CFrame.new(0,5,14)
 for i=1,100 do
  local parent=Instance.new('Folder');parent.Parent=root
  local r=assert(BeamVFX.new(parent,'Repair',color));BeamVFX.draw(r,from,to,51,1,nil,0)
  parent:Destroy()
  BeamVFX.hide(r,true);BeamVFX.after(r,from,to,51.2,.2);BeamVFX.destroy(r)
 end
 local a,b=BeamVFX.counts();assert(a==0 and b==0)
end)
check('visible charge paths are continuous across former reset boundaries',function()
 local r=BeamVFX.new(root,'Cutter',color)
 for frame=1,998 do
  local q=frame/1000
  BeamVFX.draw(r,from,to,60+q,0,q,nil)
  local h=r.rich;local before={}
  for i,path in ipairs(h.paths) do before[i]={a=path.a.Position,b=path.b.Position,on=path.beam.Enabled} end
  BeamVFX.draw(r,from,to,60+q+.00001,0,q+.00001,nil)
  for i,path in ipairs(h.paths) do
   if before[i].on and path.beam.Enabled then
    assert((path.a.Position-before[i].a).Magnitude<.01,'visible path head teleported')
    assert((path.b.Position-before[i].b).Magnitude<.01,'visible path tail teleported')
   end
  end
 end
 BeamVFX.draw(r,from,to,61,1,nil,0)
 local opacity=r.body.Transparency
 for i=1,60 do BeamVFX.draw(r,from,to,61+i/60,1,nil,i/60);assert(r.body.Transparency==opacity,'stepped body opacity') end
 BeamVFX.destroy(r)
end)
check('repeated charges reuse detached rigs without keeping active leases or particles',function()
 local r=BeamVFX.new(root,'Cutter',color)
 local previous
 for i=1,200 do
  BeamVFX.draw(r,from,to,70+i,0,.4,nil)
  local h=r.rich
  if previous then assert(h==previous,'charge rebuilt instead of reusing') end
  previous=h
  BeamVFX.draw(r,from,to,70+i+.1,1,nil,0)
  assert(r.rich==nil and h.root.Parent==nil and not h.sparks.Enabled and not h.vapor.Enabled)
  local _,_,active,cached=BeamVFX.counts();assert(active==0 and cached<=4)
 end
 BeamVFX.destroy(r)
 local _,_,active,cached=BeamVFX.counts();assert(active==0 and cached==0,'last rig removal retained cache')
end)
check('charge lens stays at the moving emitter briefly and never survives release',function()
 local r=BeamVFX.new(root,'Cutter',color)
 local moving=Vector3.new(9,8,3)
 BeamVFX.draw(r,from,to,60,0,.3,nil)
 local h=assert(r.rich);assert(h.glass.Transparency==1 and not h.mask.Enabled,'lens appeared during early inflow')
 BeamVFX.draw(r,moving,to,60.1,0,.93,nil)
 near((h.glass.Position-moving).Magnitude,0);assert(h.mask.Parent==h.glass)
 assert(h.glass.Material==Enum.Material.Glass and not h.glass.CanQuery and h.glass.Transparency>1 and h.mask.Enabled)
 assert(h.mask.FillTransparency>1, 'color lens failed to appear')
 local expanded=h.glass.Size.X
 BeamVFX.draw(r,moving,to,60.15,0,.985,nil);assert(h.glass.Size.X<expanded)
 BeamVFX.draw(r,moving,to,60.2,0,.9999,nil)
 assert(h.glass.Transparency==1 and not h.mask.Enabled,'lens survived pre-release collapse')
 BeamVFX.draw(r,moving,to,60.3,1,nil,0)
 assert(r.rich==nil and h.root.Parent==nil,'charge decoration survived beam release')
 BeamVFX.after(r,moving,to,60.4,.1);assert(r.rich==nil,'afterglow recreated the bubble')
 BeamVFX.destroy(r)
end)
check('cloud startup variants share the lens budget and hand off directly to firing',function()
 assert(BeamVFX.startupStyles.Bubbler=='Stars' and BeamVFX.startupStyles.Halver=='Ignition' and BeamVFX.startupStyles.Singularity=='Coil')
 assert(not BeamVFX.startupStyles.Blue and not BeamVFX.startupStyles.Striker,'basic miner lost the reference lens')
 local rigs={}
 for i,style in ipairs({'Stars','Ignition','Coil','Stars','Ignition','Coil'}) do
  local r=assert(BeamVFX.new(root,'Cutter',color));rigs[i]=r;BeamVFX.startup(r,style)
  BeamVFX.draw(r,from,to,60,0,.5,nil)
  if i<=4 then
   assert(r.rich.startup.style==style and not r.rich.glass)
   near((r.rich.startup.root.Position-from).Magnitude,0)
  else assert(not r.rich,'startup bypassed shared cap') end
 end
 local _,_,count=BeamVFX.counts();assert(count==4)
 for _,r in ipairs(rigs) do
  BeamVFX.draw(r,from,to,60.1,1,nil,0)
  assert(not r.rich and r.body.Enabled);near(r.body.Width0,.405)
  BeamVFX.destroy(r)
 end
 local a,b,c=BeamVFX.counts();assert(a==0 and b==0 and c==0)
end)
check('lens contracts to a point and its large flash continues into the beam',function()
 local r=BeamVFX.new(root,'Cutter',color)
 local last=math.huge
 for _,q in ipairs({.79,.84,.9,.95,.98,.999}) do
  BeamVFX.draw(r,from,to,100+q,0,q,nil,1.6)
  assert(r.rich.glass.Size.X<last,'lens was cut off instead of shrinking')
  last=r.rich.glass.Size.X
 end
 assert(last<.03 and r.orb.Material==Enum.Material.Neon and r.orb.Size.X>3)
 local before=r.orb.Size.X
 BeamVFX.draw(r,from,to,101,1,nil,0,1.6)
 assert(not r.rich and r.body.Enabled and r.orb.Transparency==0)
 assert(math.abs(r.orb.Size.X-before)<.01,'release cut off the flash')
 BeamVFX.draw(r,from,to,101.2,1,nil,.2,1.6)
 assert(r.orb.Transparency==1 and not r.stars[1].beam.Enabled)
 BeamVFX.destroy(r)
end)
check('resource gravity wells cannot acquire the emitter-only charge lens',function()
 local r=BeamVFX.new(root,'Singularity',color,nil,false)
 BeamVFX.draw(r,from,to,60,0,.93,nil)
 assert(r.detail and not r.rich,'resource well gained a laser-origin bubble')
 BeamVFX.destroy(r)
end)
check('charge lens leases and emissions remain bounded across repeated hide and draw',function()
 local rigs={}
 for i=1,6 do
  local r=assert(BeamVFX.new(root,'Orbital',color));rigs[i]=r
  BeamVFX.draw(r,from,to,61,0,.3,nil)
 end
 local _,_,count=BeamVFX.counts();assert(count==4,'lens rig cap exceeded')
 local r=rigs[1];local h=assert(r.rich)
 BeamVFX.hide(r);BeamVFX.draw(r,from,to,61.1,0,.35,nil)
 assert((h.sparks.Emitted or 0)>0,'per-frame hide prevented charge particles')
 local emitted=h.sparks.Emitted or 0
 BeamVFX.draw(r,from,to,161,0,.4,nil)
 assert((h.sparks.Emitted or 0)-emitted<=2,'late sample dumped skipped particles')
 BeamVFX.hide(r,true);assert(r.rich==nil and h.root.Parent==nil)
 BeamVFX.draw(r,from,to,162,0,.93,nil);assert(r.rich)
 for _,v in ipairs(rigs) do BeamVFX.destroy(v) end
 local a,b,c=BeamVFX.counts();assert(a==0 and b==0 and c==0,'lens lease leaked')
end)
check('short receipt late join reconstructs aftermath without replaying main beam',function()
 realTime=100
 DroneRoleEffects.Beam(from,to,color,.24,.2)
 realTime=100.45;local view=RoleEffectView.new();view:step(realTime)
 local effect=assert(workspace:FindFirstChild('DroneRoleClientEffects'))
 local rig=assert(effect:FindFirstChild('BeamVFX'))
 assert(not rig:FindFirstChild('TaperedBody').Enabled,'expired beam restarted')
 local star=assert(rig:FindFirstChild('FourPointStar'));assert(star.Enabled)
 view:step(102);assert(rig.Parent==nil)
 view:destroy();workspace.DroneRoleState:Destroy()
end)
check('partial charge waits then uses its server duration and cancels cleanly',function()
 realTime=200
 local view=RoleEffectView.new()
 local state=Instance.new('Folder');state.Name='DroneRoleState';state.Parent=workspace
 local node=Instance.new('Folder');node:SetAttribute('Kind','AbilityCharge');node:SetAttribute('StartedAt',200)
 node:SetAttribute('ExpiresAt',202.6);node.Parent=state
 view:step(200);assert(not workspace:FindFirstChild('DroneRoleClientEffects'))
 node:SetAttribute('Position',Vector3.zero);node:SetAttribute('Ability','Orbital');node:SetAttribute('Duration',1.4)
 view:step(200.7)
 local effect=assert(workspace:FindFirstChild('DroneRoleClientEffects'))
 local group=assert(effect:FindFirstChild('OrbitalTargetSight'))
 local rig=group:FindFirstChild('BeamVFX');assert(rig and rig.Position.Y>=260,'orbital charge was placed at its impact instead of sky source')
 view:step(201.6);assert(not group:FindFirstChild('ClearGlassDistortion',true),'expired charge kept its lens')
 node:Destroy();view:step(201.61);assert(group.Parent==nil)
 view:destroy();state:Destroy();local a,b=BeamVFX.counts();assert(a==0 and b==0)
end)
check('actual mining envelope surface contact target life and paused work remain safe',function()
 local p=Presentation.new({parent=root})
 local target=Instance.new('Part');target.Position=Vector3.new(0,0,0);target.Size=Vector3.new(2,2,2);target.Parent=root
 local view=Instance.new('Model');view.Parent=root
 local emitter=Instance.new('Part');emitter.Position=from;emitter.Parent=view;view.PrimaryPart=emitter
 local b=p:createMiningBeam(view,emitter);b.origin.WorldPosition=from
 local blocked=false
 workspace.Raycast=function(_,origin,delta,params)
  if params.FilterType==Enum.RaycastFilterType.Include then return {Instance=target,Position=Vector3.new(origin.X,1,origin.Z),Normal=Vector3.yAxis} end
  if blocked then return {Instance=target,Position=origin+delta*.5} end
  return nil
 end
 local s={alive=true,isMining=true,active=true,contact=true,key='ore',life=1,part=target,serverSource=target,since=300,style='Cutter',droneRole='Striker',warmupStart=299,warmupDuration=1}
 s.active=false;s.charging=true
 p:beginFrame();p:renderMiningBeam(b,s,299.93)
 assert(b.vfx.rich and b.vfx.rich.mask.Enabled and not b.vfx.body.Enabled)
 p:beginFrame();p:renderMiningBeam(b,s,300)
 near(b.vfx.body.Width0,.972);assert(b.vfx.body.Enabled and not b.vfx.rich)
 assert(not b.envelope.active,'cosmetic bridge modified authoritative envelope')
 s.paused=true;p:beginFrame();p:renderMiningBeam(b,s,300.02)
 assert(not b.vfx or not b.vfx.body.Enabled,'paused prediction survived')
 s.paused=false;s.droneRole='Bubbler';p:beginFrame();p:renderMiningBeam(b,s,300.03)
 assert(not b.vfx or not b.vfx.body.Enabled,'specialist predicted a continuous beam')
 s.droneRole='Striker';p:beginFrame();p:renderMiningBeam(b,s,300.16)
 assert(not b.vfx or not b.vfx.body.Enabled,'prediction extended past its bounded receipt window')
 s.active=true;s.charging=false
 p:beginFrame();p:renderMiningBeam(b,s,300.17)
 near(b.vfx.body.Width0,.72);assert(p.beamRays<=12)
 assert(not b.vfx.rich,'release kept the charge rig')
 near((b.vfx.root.Position+b.vfx.b.Position).Y,1)
 s.paused=true;s.active=false;s.charging=false
 p:beginFrame();p:renderMiningBeam(b,s,301.01)
 p:beginFrame();p:renderMiningBeam(b,s,301.22)
 assert(not b.vfx or not b.vfx.body.Enabled)
 s.paused=false;s.active=true;s.key='next';s.life=2;s.since=302
 blocked=true;p:beginFrame();p:renderMiningBeam(b,s,302.1)
 assert(not b.vfx or not b.vfx.body.Enabled,'new life reused a stale contact')
 p:destroyMiningBeam(b);p:destroy();target:Destroy();view:Destroy()
end)
check('future receipts wait and stale orbital contacts stop light and new emission',function()
 realTime=400
 local view=RoleEffectView.new()
 DroneRoleEffects.Beam(from,to,color,.24,.2)
 local state=workspace:FindFirstChild('DroneRoleState');state:GetChildren()[1]:SetAttribute('StartedAt',401)
 view:step(400);assert(not workspace:FindFirstChild('DroneRoleClientEffects'))
 state:GetChildren()[1]:SetAttribute('ExpiresAt',402)
 realTime=401.1;view:step(realTime);assert(workspace:FindFirstChild('DroneRoleClientEffects'))
 view:destroy();state:Destroy()
 realTime=500;DroneRoleEffects.Ability(88,{kind='orbital',target={x=0,y=1,z=0}})
 view=RoleEffectView.new();view:step(realTime)
 local effect=workspace:FindFirstChild('DroneRoleClientEffects');local group=effect:FindFirstChild('OrbitalMelt')
 realTime=500.5;view:step(realTime)
 assert(group:GetAttribute('Suspended')==true and group.MeltCore.Transparency==1)
 for _,v in ipairs(group:GetDescendants()) do if v:IsA('ParticleEmitter') then assert(not v.Enabled) end end
 DroneRoleEffects.Ability(88,{kind='orbital',target={x=0,y=1,z=0}});view:step(realTime)
 assert(group:GetAttribute('Suspended')==false and group.MeltCore.Transparency<1)
 view:destroy();workspace.DroneRoleState:Destroy()
end)
check('courier transfer ticks follow rendered mounts and release on pause and repeat',function()
 local owner=player(991);owner.Character.HumanoidRootPart.CFrame=CFrame.new(0,4,2)
 local oldLookup=players.GetPlayerByUserId
 players.GetPlayerByUserId=function(_,id) return id==991 and owner or nil end
 local source=Instance.new('Folder');source:SetAttribute('Role','Courier');source:SetAttribute('Owner',991)
 source:SetAttribute('State','Pickup');source:SetAttribute('SnapshotAt',600);source:SetAttribute('CourierPickupAt',600)
 source:SetAttribute('CourierPickupHold',.55);source.Parent=root
 local model=Instance.new('Model');model.Parent=root
 local emitter=Instance.new('Part');emitter.Position=Vector3.new(0,5,0);emitter.Parent=model;model.PrimaryPart=emitter
 local d={source=source,view=model,emitter=emitter,pos=emitter.Position}
 local r={events={dead=false}};local work=WorkEffects.new(root)
 work:courier(d,r,600.2)
 local rig=assert(r.courier.tetherVFX);assert(rig.body.Enabled and r.courier.tether.Transparency==1)
 assert(rig.paths[1].beam.CurveSize0==0,'transfer ticks became a generic orbit')
 source:SetAttribute('MotionPaused',true);work:courier(d,r,600.25);assert(rig.root.Parent==nil)
 source:SetAttribute('MotionPaused',false);work:courier(d,r,600.3);assert(r.courier.tetherVFX~=rig)
 work:destroyDrone(r);work:destroy();model:Destroy();source:Destroy();owner.Character:Destroy();owner:Destroy()
 players.GetPlayerByUserId=oldLookup;local a,b=BeamVFX.counts();assert(a==0 and b==0)
end)
root:Destroy()
print(checks..' production VFX behavior checks; API doubles, Studio visuals UNVERIFIED')
