local F=require('../src/Feel')
local passed=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS feel '..name) end
local function near(a,b,e) assert(math.abs(a-b)<(e or 1e-9),tostring(a)..' ~= '..tostring(b)) end
check('60Hz trajectory is the original .03 capped equation',function()
 for _,cap in ipairs({.2,.35,.5}) do
  local original,actual=-25,-25
  for _=1,600 do
   local delta=80-original;original+=math.min(delta*.03,cap)
   actual=F.approachScalar(actual,80,cap,1/60);near(actual,original,1e-10)
  end
 end
end)
check('30 60 120 144Hz paths preserve cap/easing transition scale',function()
 local reference={}
 for _,rate in ipairs({30,60,120,144}) do
  local p=0
  for _=1,rate*4 do p=F.approachScalar(p,45,.35,1/rate) end
  reference[rate]=p
 end
 for _,rate in ipairs({30,120,144}) do near(reference[rate],reference[60],.12) end
end)
check('uncapped paths match elapsed time at all render frequencies',function()
 for _,rate in ipairs({30,60,120,144}) do
  local p=0
  for _=1,rate*2 do p=F.approachScalar(p,1,1,1/rate) end
  near(p,1-.97^120,1e-10)
 end
end)
check('60Hz yaw blend equals original .1 and other rates match',function()
 near(F.turnAlpha(1/60),.1)
 for _,rate in ipairs({30,60,144}) do
  local a=0
  for _=1,rate do a=F.approachYaw(a,1,1/rate) end
  near(a,1-.9^60,1e-10)
 end
end)
check('zero dt and reached goals never drift or NaN',function() near(F.approachScalar(1,10,.3,0),1);near(F.approachScalar(1,1,.3,1),1);near(F.turnAlpha(0),0) end)
check('first six fleet sizes form stable radius10 ring',function()
 for count=1,6 do for slot=1,count do local x,z=F.formationXZ(slot,count);near(math.sqrt(x*x+z*z),10);near(F.hover(0,.35),math.sin(70)/3) end end
end)
check('hover amplitude and six second period preserve original',function()
 for i=0,1000 do assert(math.abs(F.hover(i/100,.3))<=1/3) end
 near(F.hover(.4,.3),F.hover(.4+2*math.pi,.3))
end)
check('exact quarter thresholds and every crossed stage',function()
 assert(F.stage(76,100)==0 and F.stage(75,100)==1 and F.stage(50,100)==2 and F.stage(25,100)==3)
 local crossed=F.stagesCrossed(0,20,100);assert(#crossed==3 and crossed[1]==1 and crossed[2]==2 and crossed[3]==3)
 assert(#F.stagesCrossed(3,0,100)==0)
 near(F.stageScale(0),1);near(F.stageScale(1),.75);near(F.stageScale(2),.5);near(F.stageScale(3),.25)
end)
check('growth is original 2 second Quad.Out and latejoin reconstructs',function()
 near(F.growth(10,10),0);near(F.growth(11,10),.75);near(F.growth(12,10),1);near(F.growth(20,10),1)
 assert(not F.ready(11.999,10));assert(F.ready(12,10));near(F.growth(11,10),F.growth(101,100))
end)
check('one stud server arrival gate blocks approach and growing rocks',function()
 assert(F.canMine(1,true,true,true));assert(not F.canMine(1.001,true,true,true));assert(not F.canMine(.2,false,true,true));assert(not F.canMine(.2,true,false,true));assert(not F.canMine(.2,true,true,false))
end)
check('station is directly overhead and geode slots stay over footprint',function()
 for slot=1,6 do
  local x,y,z=F.stationOffset(slot,false);near(x,0);near(y,10);near(z,0)
  local gx,gy,gz=F.stationOffset(slot,true);near(gy,10);near(math.sqrt(gx*gx+gz*gz),1.15)
  local fx,fy,fz=F.followOffset(slot,6,.5,.35);near(math.sqrt(fx*fx+fz*fz),10);near(fy,7+math.sin(.5+70)/3)
 end
end)
check('coalesced three quarters and break remain visible in order',function()
 local p=F.newStagePresentation(0,false,0)
 assert(F.updateStagePresentation(p,3,true,1)=='stage');assert(p.stage==1 and not p.broken)
 assert(F.updateStagePresentation(p,3,true,1.08)==nil)
 assert(F.updateStagePresentation(p,3,true,1.091)=='stage');assert(p.stage==2 and not p.broken)
 assert(F.updateStagePresentation(p,3,true,1.182)=='stage');assert(p.stage==3 and not p.broken)
 assert(F.updateStagePresentation(p,3,true,1.273)=='break');assert(p.broken)
end)
check('each ordinary quarter retains a minimum display dwell',function()
 local p=F.newStagePresentation(0,false,0)
 F.updateStagePresentation(p,1,false,1);assert(p.stage==1)
 assert(F.updateStagePresentation(p,2,false,1.02)==nil and p.stage==1)
 F.updateStagePresentation(p,2,false,1.091);assert(p.stage==2)
 F.updateStagePresentation(p,3,true,1.182);assert(p.stage==3 and not p.broken)
 assert(F.updateStagePresentation(p,3,true,1.22)==nil)
 assert(F.updateStagePresentation(p,3,true,1.273)==nil and not p.broken)
 F.updateStagePresentation(p,3,true,1.303);assert(p.broken)
end)
check('late join initializes current stage and break without replay',function()
 local p=F.newStagePresentation(3,true,5)
 assert(p.stage==3 and p.broken)
 for n=1,10 do assert(F.updateStagePresentation(p,3,true,5+n)==nil) end
 local live=F.newStagePresentation(2,false,5)
 assert(F.updateStagePresentation(live,2,false,6)==nil and live.stage==2)
end)
check('duplicate snapshots cannot duplicate cracks or break',function()
 local p=F.newStagePresentation(0,false,0);local cracks,breaks=0,0
 for n=0,100 do
  local event=F.updateStagePresentation(p,3,true,n*.02)
  if event=='stage' then cracks=cracks+1 elseif event=='break' then breaks=breaks+1 end
 end
 assert(cracks==3 and breaks==1 and #p.queue==0)
end)
check('break arriving before stage attribute still presents every quarter',function()
 local p=F.newStagePresentation(0,false,0)
 F.updateStagePresentation(p,0,true,1);assert(p.stage==1 and not p.broken)
 F.updateStagePresentation(p,3,true,1.1);assert(p.stage==2 and not p.broken)
 F.updateStagePresentation(p,3,true,1.2);assert(p.stage==3 and not p.broken)
 F.updateStagePresentation(p,3,true,1.3);assert(p.broken)
end)
check('presentation stall does not consume unreadable quarter stages',function()
 local p=F.newStagePresentation(0,false,0)
 F.updateStagePresentation(p,3,true,1)
 F.updateStagePresentation(p,3,true,100);assert(p.stage==2 and not p.broken)
 assert(F.updateStagePresentation(p,3,true,100.02)==nil)
 F.updateStagePresentation(p,3,true,100.1);assert(p.stage==3 and not p.broken)
 F.updateStagePresentation(p,3,true,100.2);assert(p.broken)
end)
check('stale lower stages do not rewind presentation',function()
 local p=F.newStagePresentation(2,false,0)
 assert(F.updateStagePresentation(p,0,false,1)==nil and p.stage==2)
 F.updateStagePresentation(p,3,false,2);assert(p.stage==3)
end)
check('a final hit retains the already-third-stage mesh for only its short finish',function()
 local p=F.newStagePresentation(3,false,0)
 assert(F.updateStagePresentation(p,3,true,10)==nil and not p.broken)
 assert(F.updateStagePresentation(p,0,true,10.119)==nil and not p.broken)
 assert(F.updateStagePresentation(p,3,true,10.121)=='break' and p.broken)
 assert(F.updateStagePresentation(p,3,true,10.3)==nil,'duplicate break replay')
end)
check('final-hit finish does not add a second delay after multi-quarter presentation',function()
 local p=F.newStagePresentation(0,false,0)
 assert(F.updateStagePresentation(p,0,true,10)=='stage')
 assert(F.updateStagePresentation(p,3,true,10.091)=='stage')
 assert(F.updateStagePresentation(p,1,true,10.182)=='stage')
 assert(F.updateStagePresentation(p,3,true,10.273)=='break')
end)
print(passed..' original-equation feel tests passed; not Studio visual parity')
