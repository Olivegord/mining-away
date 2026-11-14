-- Real production renderers with synthetic engine APIs, never native footage.
function CF:VectorToObjectSpace(v) return self:PointToObjectSpace(self.Position+v) end
function CF:VectorToWorldSpace(v) return self:PointToWorldSpace(v)-self.Position end
local checks=0
local function check(name,fn) LaunchAftermath.clear();fn();LaunchAftermath.clear();checks+=1;print('PASS beam VFX '..name) end
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
check('Inkbeam anchors its tapered color ray and leases only four nearby ink silhouettes',function()
 local rigs={}
 for i=1,5 do rigs[i]=InkbeamView.draw(nil,root,from,to,1,.3,true) end
 local r=rigs[1];local ray=r.layers[2]
 assert(ray.beam.Enabled and ray.beam.Width0>8*ray.beam.Width1)
 near((r.root.Position+ray.b.Position-to).Magnitude,0)
 assert(r.ink[1][1].beam.CurveSize0>0 and r.ink[2][1].beam.CurveSize0==nil)
 assert(r.ink[1][1].beam.LightEmission==0 and r.ink[5][1].beam.LightEmission>0)
 assert(rigs[4].detailed and not rigs[5].detailed)
 local before=r.ink[1][1].a.Position
 InkbeamView.draw(r,root,from,to,1,.31,true)
 local advance=(before-r.ink[1][1].a.Position).Magnitude
 assert(advance>0 and advance<.03)
 InkbeamView.draw(r,root,from,to,.25,.8,false)
 assert(not r.detailed and #r.ink==0 and ray.beam.Enabled and ray.beam.Transparency>.65)
 InkbeamView.draw(rigs[5],root,from,to,1,.8,true)
 assert(rigs[5].detailed,'distant/reduced effect failed to free its detail lease')
 for _,rig in ipairs(rigs) do InkbeamView.destroy(rig) end
 assert(not r.root.Parent)
end)
check('charge gathers compresses and changes silhouette before release',function()
 local full=BeamVFX.charge(.76);local compressed=BeamVFX.charge(.9)
 assert(full>.99 and compressed<.4)
 local _,glint=BeamVFX.charge(1);near(glint,1)
 local r=BeamVFX.new(root,'Orbital',color)
 BeamVFX.draw(r,from,to,9.7,0,.58,nil)
 assert(r.rich and r.rich.core.Transparency<.85 and r.rich.collars[1].beam.Enabled and not r.core.Enabled)
 BeamVFX.draw(r,from,to,10,0,.965,nil)
 assert(not r.paths[1].beam.Enabled,'decorative orbit returned')
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
  near(r.body.Width0,.15*BeamVFX.WidthScale);assert(r.body.Width1<r.body.Width0)
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
  assert(r.rich==h and r.body.Enabled and h.glass.Transparency<1,'missing ignition overlap')
  BeamVFX.draw(r,from,to,70+i+.19,1,nil,.09)
  assert(r.rich==nil and h.root.Parent==nil and not h.sparks.Enabled and not h.vapor.Enabled)
  local _,_,active,cached=BeamVFX.counts();assert(active==0 and cached<=6)
 end
 BeamVFX.destroy(r)
 local _,_,active,cached=BeamVFX.counts();assert(active==0 and cached==0,'last rig removal retained cache')
end)
check('mixed startup styles and overlapping lenses stay warm across preview cycles',function()
 local rigs={}
 for i=1,6 do
  rigs[i]=BeamVFX.new(root,'Cutter',color)
  BeamVFX.startup(rigs[i],({[2]='Stars',[3]='Coil',[5]='Ignition'})[i])
 end
 local seen={}
 local function charge(i,cycle)
  local r=rigs[i];BeamVFX.draw(r,from,to,cycle,0,.4,nil)
  local h=assert(r.rich)
  if cycle>2 then assert(seen[h],'mixed-style cache evicted a reusable rig') end
  seen[h]=true
 end
 for cycle=1,100 do
  -- The first and last lens overlap; the other styles use intervening slots.
  charge(1,cycle);charge(6,cycle)
  BeamVFX.hide(rigs[1],false);BeamVFX.hide(rigs[6],false)
  for _,i in ipairs({2,3,4,5}) do charge(i,cycle);BeamVFX.hide(rigs[i],false) end
  local _,_,active,cached=BeamVFX.counts();assert(active==0 and cached<=6)
 end
 for _,r in ipairs(rigs) do BeamVFX.destroy(r) end
 local a,b,c,d=BeamVFX.counts();assert(a==0 and b==0 and c==0 and d==0)
end)
check('charge lens follows emitter and overlaps ignition for only 80 milliseconds',function()
 local r=BeamVFX.new(root,'Cutter',color)
 local moving=Vector3.new(9,8,3)
 BeamVFX.draw(r,from,to,60,0,.3,nil)
 local h=assert(r.rich);assert(h.glass.Transparency==1, 'lens appeared during early inflow')
 BeamVFX.draw(r,moving,to,60.1,0,.965,nil)
 near((h.glass.CFrame.Position-moving).Magnitude,0)
 assert(h.glass.Material==Enum.Material.Neon and not h.glass.CanQuery and h.glass.Transparency>=0 and h.glass.Transparency<1)
 local expanded=h.glass.Size.X
 BeamVFX.draw(r,moving,to,60.15,0,.985,nil);assert(h.glass.Size.X<expanded)
 BeamVFX.draw(r,moving,to,60.2,0,.9999,nil)
 assert(h.glass.Transparency<1,'pop finished before ignition')
 BeamVFX.draw(r,moving,to,60.3,1,nil,0)
 assert(r.rich==h and h.glass.Transparency<1 and r.body.Enabled,'pop and laser did not overlap')
 for _,path in ipairs(h.paths) do assert(not path.beam.Enabled,'inflow survived ignition') end
 BeamVFX.draw(r,moving,to,60.39,1,nil,.09)
 assert(r.rich==nil and h.root.Parent==nil,'lens outlived its short ignition overlap')
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
  assert(not r.rich and r.body.Enabled);near(r.body.Width0,.405*BeamVFX.WidthScale)
  BeamVFX.destroy(r)
 end
 local a,b,c=BeamVFX.counts();assert(a==0 and b==0 and c==0)
end)
check('original flash shape and duration with hard colors and overlapping ignition',function()
 local r=BeamVFX.new(root,'Cutter',color)
 near(BeamVFX.lensEnvelope(.64),0);near(BeamVFX.lensEnvelope(.79),1);near(BeamVFX.lensEnvelope(1),0)
 for _,sample in ipairs({{.75,1,1,0},{.80,1,1,0},{.82,0,1,1},{.88,0,1,1},{.90,1,0,1},{.96,1,0,1},{.98,1,1,0}}) do
  BeamVFX.draw(r,from,to,99,0,.999,nil,1,.8)
  if sample[1]<.9 then BeamVFX.draw(r,from,to,99,0,sample[1]+.1,nil,1,.8)
  else BeamVFX.draw(r,from,to,99,1,nil,(sample[1]-.9)*.8,1) end
  local c=r.rich.glass.Color
  near(c.R,sample[2]);near(c.G,sample[3]);near(c.B,sample[4])
 end
 for _,duration in ipairs({.8,1.6,3.2}) do
  for _,remaining in ipairs({.3,.25,.168,.1,.02,.001}) do
   local q=1-remaining/duration
   local oldQ=.9-remaining/.8
   near(BeamVFX.flashProgress(q,duration),oldQ)
   BeamVFX.draw(r,from,to,100+q,0,q,nil,1,duration)
   local lens=BeamVFX.lensEnvelope(oldQ)
   assert(r.rich.glass.Size.X<=1.15 and r.rich.glass.Size.X>=.02)
   assert((lens==0)==(r.rich.glass.Transparency==1) and r.rich.glass.Transparency>=0)
  end
 end
 local aftermath=assert(r.aftermath)
 BeamVFX.draw(r,from,to,101,1,nil,.04,1)
 assert(r.rich and r.rich.glass.Transparency<1 and r.body.Enabled and r.body.Width0<.17)
 for _,ray in ipairs(aftermath.plane.rays) do
  assert(ray.beam.Enabled and not ray.beam.FaceCamera)
  near(ray.a.Position.Y,0);near(ray.b.Position.Y,0)
  near(ray.a.Position.Magnitude,ray.b.Position.Magnitude)
  assert(ray.a.Position.Magnitude>1.4 and ray.a.Position.Magnitude<2.02,'ring must snap out but remain compact')
  assert(ray.beam.CurveSize0>0,'ring became flat triangular rays')
 end
 LaunchAftermath.step(101.7)
 local radius=aftermath.plane.rays[1].a.Position.Magnitude
 assert(aftermath.plane.rays[1].beam.Enabled,'ring disappeared instead of lingering')
 LaunchAftermath.step(101.95)
 assert(aftermath.plane.rays[1].a.Position.Magnitude>radius+.1,'ring tail stopped moving')
 LaunchAftermath.step(102.2)
 for _,ray in ipairs(aftermath.plane.rays) do assert(not ray.beam.Enabled) end
 BeamVFX.destroy(r)
end)
check('launch keeps smoke and electrical fragments alive after lens and drone rig removal',function()
 local r=BeamVFX.new(root,'Cutter',color)
 BeamVFX.draw(r,from,to,110,0,.7,nil,1)
 local f=assert(r.aftermath);local smoke=f.smoke[1].e;assert(smoke.Emitted>0)
 smoke.Cleared=false
 BeamVFX.draw(r,from,to,110.3,1,nil,0,1)
 assert(r.rich and r.rich.glass.Transparency<1 and not r.aftermath and not smoke.Cleared)
 assert(smoke.Acceleration.Magnitude>10,'existing smoke got no pressure impulse')
 local emitted=smoke.Emitted
 BeamVFX.destroy(r)
 LaunchAftermath.step(110.65)
 assert(f.root.Parent==workspace and not smoke.Cleared,'short attack cut off its launched aftermath')
 assert(f.chips[1].Transparency<1 and f.chips[1].Position.Y<from.Y)
 assert(smoke.Emitted==emitted,'release repeatedly emitted a burst')
 local before=f.chips[1].Position
 LaunchAftermath.step(111.4);assert(f.chips[1].Transparency<1 and (f.chips[1].Position-before).Magnitude>.2,'fragments failed to linger and keep moving')
 LaunchAftermath.step(112.2)
 assert(not f.root.Parent and smoke.Cleared)
 for _,p in ipairs(f.chips) do assert(p.Transparency==1) end
end)
check('electrical spray keeps drifting without gravity and carries chromatic pulse hues',function()
 for i=1,18 do
  local early=PullMotion.discharge(i,.05);local late=PullMotion.discharge(i,.5);local endp=PullMotion.discharge(i,1.2)
  assert(early.Magnitude>.75,'launch is too slow')
  assert(math.sqrt(early.X^2+early.Z^2)>math.abs(early.Y)*1.45,'spray collapsed to a downward column')
  assert(math.abs(endp.Y-late.Y)<.4,'dust accelerated into a gravitational fall')
  assert((endp-late).Magnitude>.3,'dust tail stopped moving')
  assert(endp.Magnitude<4,'dust spread escaped compact budget')
 end
 local owner={color=color};LaunchAftermath.charge(owner,from,-Vector3.yAxis,125,.5,1)
 local f=assert(owner.aftermath)
 for i,p in ipairs(f.chips) do
  local expected=LaunchAftermath.palette(color,i)
  near(p.Color.R,expected.R);near(p.Color.G,expected.G);near(p.Color.B,expected.B)
 end
 assert(f.smoke[1].e.Color==color)
 local r=BeamVFX.new(root,'Cutter',color);local cues={}
 BeamVFX.onCue=function(kind,_,_,pulse) cues[#cues+1]=kind..pulse end
 local chargeUpdates,chargeEnds=0,0
 BeamVFX.onCharge=function() chargeUpdates+=1 end;BeamVFX.onChargeEnd=function() chargeEnds+=1 end
 for _,q in ipairs({.5,.64,.765,.86,.94}) do
  BeamVFX.draw(r,from,to,126+q,0,q,nil)
  BeamVFX.draw(r,from,to,126+q+.001,0,q+.001,nil)
 end
 BeamVFX.draw(r,from,to,127,1,nil,0);BeamVFX.draw(r,from,to,127.01,1,nil,.01)
 assert(#cues==1 and cues[1]=='launch1','release audio repeated per frame')
 assert(chargeUpdates==10 and chargeEnds==1,'charge tone failed to track visual lifecycle')
 BeamVFX.onCue=nil;BeamVFX.onCharge=nil;BeamVFX.onChargeEnd=nil;BeamVFX.destroy(r)
end)
check('aftermath budget cancellation late receipts and reduced-effects cleanup',function()
 local owners={}
 for i=1,8 do owners[i]={};LaunchAftermath.charge(owners[i],from,-Vector3.yAxis,120,.7,1) end
 local active=LaunchAftermath.counts();assert(active==4)
 for _,owner in ipairs(owners) do LaunchAftermath.fire(owner,from,-Vector3.yAxis,120,.8) end
 active=LaunchAftermath.counts();assert(active==0,'late observer replayed the launch')
 LaunchAftermath.charge(owners[1],from,-Vector3.yAxis,121,.7,1)
 LaunchAftermath.fire(owners[1],from,-Vector3.yAxis,121,0)
 local p=Instance.new('Player');players.LocalPlayer=p;p:SetAttribute('ReducedEffects',true)
 LaunchAftermath.step(121.1);active=LaunchAftermath.counts();assert(active==0)
 players.LocalPlayer=nil;p:Destroy()
 for _,fps in ipairs({30,60,144}) do
  local at
  for frame=0,fps do at=PullMotion.discharge(3,frame/fps) end
  near((at-PullMotion.discharge(3,1)).Magnitude,0)
 end
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
 BeamVFX.hide(r,false);assert(not r.rich and r.detail,'hidden charge kept a lease or lost retained detail')
 BeamVFX.draw(r,from,to,61.1,0,.35,nil)
 assert(r.rich==h,'hidden charge failed to reuse pooled rig')
 BeamVFX.draw(r,from,to,61.2,0,.4,nil)
 assert((h.sparks.Emitted or 0)>0,'reused charge failed to emit particles')
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
 local mark=assert(group:FindFirstChild('ConvergingLock'))
 local height=mark.Position.Y
 assert(height>1 and height<12,'orbital charge cue is detached from its target')
 view:step(201.6);assert(mark.Position.Y<height,'orbital markers did not converge')
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
 assert(not b.reference and b.vfx and b.vfx.rich and not b.vfx.body.Enabled,'ordinary miner charge lost its startup or showed a premature beam')
 p:beginFrame();p:renderMiningBeam(b,s,300)
 local inner,outer=unpack(b.reference)
 assert(b.flare and b.flare.Enabled and not b.flare.AlwaysOnTop)
 assert(#b.flare:GetChildren()==1 and b.flareStar.Image=='rbxassetid://77624818077620',
  'active mining optic must render the four-point star as its only flare texture')
 assert(b.flareLight.Shadows,'mining flare glow must respect shadows')
 assert(outer.Enabled and not inner.Enabled and outer.Attachment0==b.origin and outer.Attachment1.Parent==b.endpoint)
 near(outer.Width0,.5)
 assert(not b.vfx.body.Enabled,'charge rig drew a second beam on top of the original')
 assert(not b.envelope.active,'cosmetic bridge modified authoritative envelope')
 s.paused=true;p:beginFrame();p:renderMiningBeam(b,s,300.02)
 assert(not outer.Enabled,'paused prediction survived')
 s.paused=false;s.droneRole='Bubbler';p:beginFrame();p:renderMiningBeam(b,s,300.03)
 assert(not outer.Enabled and (not b.vfx or not b.vfx.body.Enabled),'specialist predicted a continuous beam')
 s.droneRole='Striker';p:beginFrame();p:renderMiningBeam(b,s,300.16)
 assert(not outer.Enabled,'prediction extended past its bounded receipt window')
 s.active=true;s.charging=false
 p:beginFrame();p:renderMiningBeam(b,s,301)
 near(inner.Width0,.225);near(outer.Width0,.5);near(b.endpoint.Position.Y,1)
 assert(p.beamRays<=12 and not b.vfx)
 s.active=false
 p:beginFrame();p:renderMiningBeam(b,s,301.01)
 p:beginFrame();p:renderMiningBeam(b,s,301.22)
 assert(not inner.Enabled and not outer.Enabled,'original fade exceeded .2 seconds')
 s.active=true;s.key='next';s.life=2;s.since=302
 blocked=true;p:beginFrame();p:renderMiningBeam(b,s,302.1)
 assert(not outer.Enabled,'new life reused a stale contact')
 p:destroyMiningBeam(b);p:destroy();target:Destroy();view:Destroy()
end)
check('crystal beam follows a turned and shrunk contact between ray checks',function()
 local p=Presentation.new({parent=root})
 local target=Instance.new('UnionOperation');target.Size=Vector3.new(3.135000228881836,6.566902160644531,4.4872307777404785)
 target.CFrame=CFrame.new(0,1,0);target.Parent=root;target:SetAttribute('CubicRock',false)
 local view=Instance.new('Model');view.Parent=root
 local emitter=Instance.new('Part');emitter.Position=from;emitter.Parent=view;view.PrimaryPart=emitter
 local b=p:createMiningBeam(view,emitter);b.origin.WorldPosition=from
 local previousRaycast=workspace.Raycast
 local blocked=false;local anchor
 workspace.Raycast=function(_,origin,delta,params)
  if params.FilterType==Enum.RaycastFilterType.Include then
   local at=target.CFrame:PointToObjectSpace(origin)
   anchor=Vector3.new(at.X/target.Size.X,.4,at.Z/target.Size.Z)
   return {Instance=target,Position=target.CFrame:PointToWorldSpace(anchor*target.Size),Normal=Vector3.yAxis}
  end
  if blocked then return {Instance=target,Position=origin+delta*.5} end
  return nil
 end
 local s={alive=true,isMining=true,active=true,contact=true,key='crystal',life=1,part=target,serverSource=target,since=299,style='Cutter',droneRole='Striker'}
 local function frame(now) p:beginFrame();p:queueMiningBeam(b,s,now);p:flushMiningBeams() end
 frame(300)
 assert(p.beamRays==2 and b.reference[1].Enabled)
 near(anchor.X*target.Size.X,-.5675010681152344);near(anchor.Z*target.Size.Z,-.24361419677734375)
 local before=b.endpoint.Position
 target.Size*=.75;target.CFrame=CFrame.new(0,.5,0)*CFrame.Angles(0,math.pi/2,0)
 frame(300.01)
 assert(p.beamRays==0 and b.reference[1].Enabled,'a crystal turn interrupted the beam')
 local tip=b.endpoint.Position
 assert((tip-target.CFrame:PointToWorldSpace(anchor*target.Size)).Magnitude<1e-6)
 assert(math.abs(tip.X-before.X)>.2 and math.abs(tip.Z-before.Z)>.2)
 s.breakContactAt=300.02;s.breakContactUntil=300.32;target:SetAttribute('HP',0)
 for _,at in ipairs({300.02,300.06,300.12,300.20,300.229}) do
  frame(at)
  assert(b.reference[1].Enabled and b.reference[2].Enabled,'confirmed cut went dark during the held fracture')
 end
 target.Transparency=1;frame(300.23)
 assert(not b.reference[1].Enabled and not b.reference[2].Enabled,'the beam outlived the visible fracture')
 target.Transparency=0;target:SetAttribute('HP',50);s.breakContactAt=nil;s.breakContactUntil=nil
 blocked=true;frame(300.34);assert(p.beamRays==2 and not b.reference[1].Enabled,'occluded contact stayed visible')
 workspace.Raycast=previousRaycast
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
check('heavy beam texture loops advance independently and impact strokes outlive the shot',function()
 realTime=550
 RoleVisuals.setTime(realTime)
 RoleVisuals.Beam(from,to,color,1.52,.25,'Prism')
 local raycast=workspace.Raycast
 workspace.Raycast=function(_,origin)
  return {Position=Vector3.new(origin.X,-2,origin.Z)}
 end
 RoleVisuals.PrismImpact(to,Vector3.yAxis,Vector3.new(0,-5,0))
 workspace.Raycast=raycast
 RoleVisuals.setTime(nil);RoleVisuals.step(550.03)
 local effects=workspace.DroneRoleClientEffects
 local rig=assert(effects:FindFirstChild('BeamVFX'))
 local flame=assert(rig:FindFirstChild('StreamingFlame',true))
 local fold=assert(rig:FindFirstChild('StreamingHotFolds',true))
 assert(flame.Enabled and fold.Enabled and flame.Texture~=fold.Texture)
 assert(flame.Attachment1.WorldPosition==to and fold.Attachment1.WorldPosition==to)
 local flameOffset,foldOffset=flame.TextureOffset,fold.TextureOffset
 local impact=assert(effects:FindFirstChild('RamielImpactArtwork'))
 local ray=assert(impact:FindFirstChild('ImpactFlashRay'))
 local stroke=assert(impact:FindFirstChild('GroundingImpactTendril'))
 local smoke=assert(impact:FindFirstChild('RollingSmoke'))
 assert(ray.Enabled and stroke.Enabled and stroke.CurveSize0>0 and smoke.Emitted==8)
 local tip=stroke.Attachment1.WorldCFrame.Position
 RoleVisuals.step(550.09)
 assert(math.abs((flameOffset-flame.TextureOffset)%1-(foldOffset-fold.TextureOffset)%1)>.01)
 assert((stroke.Attachment1.WorldCFrame.Position-tip).Magnitude>.2)
 RoleVisuals.step(550.30)
 assert(not rig.Parent and impact.Parent and stroke.Enabled and not ray.Enabled)
 local crest=stroke.Attachment1.WorldCFrame.Position
 assert(crest.Y>8,'tendril did not rise far above the impact')
 RoleVisuals.step(550.57)
 local landing=stroke.Attachment1.WorldCFrame.Position
 near(landing.Y,-1.87)
 assert(landing.Magnitude>17 and stroke.Enabled,'tendril did not reach the ground at full length')
 near((stroke.Attachment0.WorldCFrame.Position-impact.Position).Magnitude,0)
 RoleVisuals.step(550.92);assert(not stroke.Enabled)
 RoleVisuals.step(552)
 assert(not impact.Parent)
 local player=Instance.new('Player');players.LocalPlayer=player
 player:SetAttribute('ReducedFlashing',true)
 realTime=553;RoleVisuals.PrismImpact(to,Vector3.yAxis);RoleVisuals.step(realTime)
 impact=assert(effects:FindFirstChild('RamielImpactArtwork'))
 assert(not impact:FindFirstChild('ImpactFlashRay') and impact:FindFirstChild('RollingSmoke').Emitted==8)
 player:SetAttribute('ReducedEffects',true);RoleVisuals.step(realTime+.02)
 assert(not impact.Parent)
 players.LocalPlayer=nil;player:Destroy();RoleVisuals.destroy()
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
check('physical courier cargo settles above the table and waits for its receipt',function()
 local original=Instance.new('Model');original.Name='Crystal';original.Parent=workspace
 local template=Instance.new('UnionOperation');template.Name='Mesh';template.Parent=original
 local oldLabel=Instance.new('BillboardGui');oldLabel.Parent=template
 local source=Instance.new('Folder');source:SetAttribute('Role','Courier');source:SetAttribute('State','Unload')
 source:SetAttribute('DeliveryUnits',6);source:SetAttribute('DeliverySlots',6);source:SetAttribute('SnapshotAt',700)
 source:SetAttribute('DeliveryMaterials','Rock:Quartz:10;Block:RunRuby:80;Rock:RunRuby:40;Rock:RunRuby:44;Rock:RunCobalt:160;Rock:RunViolet:640')
 source:SetAttribute('CourierUnloadAt',700);source:SetAttribute('CourierUnloadHold',.65)
 local counter=Vector3.new(0,7,2.2);source:SetAttribute('SellPosition',counter)
 local model=Instance.new('Model');model.Parent=root
 local emitter=Instance.new('Part');emitter.Position=Vector3.new(0,9,-5);emitter.Parent=model;model.PrimaryPart=emitter
 local drone={source=source,view=model,emitter=emitter,pos=emitter.Position}
 local record={events={dead=false}};local work=WorkEffects.new(root)
 work:courier(drone,record,700.25)
 local mounts=record.courier.mounts
 assert(mounts[1].cargo:IsA('UnionOperation') and not mounts[1].cargo:FindFirstChildWhichIsA('BillboardGui'))
 assert(mounts[2].cargo:IsA('Part') and mounts[2].cargo.Material==Enum.Material.Metal)
 assert(#mounts[1].fingers==4 and mounts[1].cargo.Size.X==Workshop.ROCK_SIZE[1])
 assert(mounts[1].cargo.Position.Z>mounts[5].cargo.Position.Z,'the shipment unloaded all at once')
 work:courier(drone,record,700.65)
 for i,slot in ipairs(mounts) do
  near(slot.cargo.Position.Y-slot.cargo.Size.Y*.5,7.015)
  assert(slot.cargo.Position.Z>1 and slot.cargo.Transparency==0)
 end
 source:SetAttribute('WorkPaused',true);source:SetAttribute('CourierUnloadAt',701)
 work:courier(drone,record,701.1)
 assert(mounts[1].cargo.Transparency==0 and #work.bursts==0,'unconfirmed sale consumed cargo')
 source:SetAttribute('WorkPaused',false);source:SetAttribute('State','Collect');source:SetAttribute('DeliveryUnits',0)
 source:SetAttribute('CourierSaleSerial',1);source:SetAttribute('CourierSaleAt',701.2)
 work:courier(drone,record,701.2);work:courier(drone,record,701.25)
 assert(mounts[1].cargo.Transparency>0 and mounts[1].cargo.Transparency<1 and #work.bursts==1,'confirmed sale did not start its fade exactly once')
 work:courier(drone,record,701.42)
 assert(mounts[1].cargo.Transparency==1)
 near(work.bursts[1].part.Position.Y,7.18)
 work:destroyDrone(record);work:destroy();model:Destroy();source:Destroy();original:Destroy()
end)
check('courier claws close at ground contact without a tether and snap once',function()
 local source=Instance.new('Folder');source:SetAttribute('Role','Courier');source:SetAttribute('State','Pickup')
 source:SetAttribute('DeliverySlots',4);source:SetAttribute('CourierDock',Vector3.new(0,5,0))
 source:SetAttribute('CourierPickupAt',720);source:SetAttribute('SnapshotAt',720);source.Parent=root
 local model=Instance.new('Model');model.Parent=root
 local emitter=Instance.new('Part');emitter.Position=Vector3.new(0,5,0);emitter.Parent=model;model.PrimaryPart=emitter
 local drone={source=source,view=model,emitter=emitter,pos=emitter.Position}
 local record={events={dead=false}};local work=WorkEffects.new(root)
 assert(not work:courier(drone,record,720.10))
 local slot=record.courier.mounts[1]
 local open=slot.fingers[1][2].Position
 assert(not slot.cargo and slot.fingers[1][2].Transparency==0 and not record.courier.tetherVFX)
 assert(not work:courier(drone,record,720.48))
 assert((open-slot.fingers[1][2].Position).Magnitude>.02 and not slot.cargo)
 source:SetAttribute('DeliveryUnits',1);source:SetAttribute('DeliveryMaterials','Rock:Quartz:10')
 source:SetAttribute('CourierLoadedOre',19);source:SetAttribute('CourierLoadedMaterial','Rock:Quartz:10')
 source:SetAttribute('CourierLoadedAt',720.56)
 drone.pickupAge=Workshop.COURIER_CONTACT-.04
 assert(not work:courier(drone,record,720.57))
 assert(slot.cargo.Transparency==1 and not drone.cargoMount,'early cargo receipt jumped ahead of the animated fingers')
 drone.pickupAge=Workshop.COURIER_CONTACT+.01
 assert(work:courier(drone,record,720.57))
 assert(slot.cargo.Transparency==0 and drone.cargoMount.id==19)
 assert(not work:courier(drone,record,720.58))
 work:destroyDrone(record);work:destroy();model:Destroy();source:Destroy()
end)
root:Destroy()
print(checks..' production VFX behavior checks; API doubles, Studio visuals UNVERIFIED')
