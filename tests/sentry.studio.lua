-- Run in Studio Client with a ModuleScript named SentryReviewModules containing
-- the build.py module_bundle(('Feedback','SentryMotion','Presentation')) followed
-- by `return {Presentation=Presentation}`. Uses real Instances/CFrames/render code;
-- controlled timestamps/attributes are a renderer test, not a multiplayer test.
local RS=game:GetService('ReplicatedStorage')
local P=require(RS:FindFirstChild('SentryReviewModules')).Presentation
local original=workspace.MiningAway.Fields.Cobalt.Pyramid_1
local fixture=Instance.new('Folder');fixture.Name='SentryRendererTest';fixture.Parent=workspace
local source=original:Clone();source.Parent=fixture
source:PivotTo(source:GetPivot()+Vector3.new(0,0,500))
for _,part in ipairs(source:GetDescendants()) do
 if part:IsA('BasePart') then part.CanCollide=false;part.CanQuery=false;part.CanTouch=false end
end
local fx=Instance.new('Folder');fx.Parent=fixture
local presentation=P.new({parent=fx})
local results={samples=0,maxSocketDrift=0,maxBaseDrift=0,passed={}}
local function check(value,name) assert(value,name);table.insert(results.passed,name) end
local function reset()
 source:SetAttribute('Dead',false);source:SetAttribute('HP',260);source:SetAttribute('MaxHP',260)
 source:SetAttribute('ShotSerial',0);source:SetAttribute('Telegraph',false);source:SetAttribute('Aim',nil)
end
local ok,err=pcall(function()
 for _,fps in ipairs({30,60,144}) do
  reset()
  local start=workspace:GetServerTimeNow()
  local record=presentation:registerTurret(source,start)
  local base=record.view.basepart.CFrame
  local socket=record.eye.CFrame:ToObjectSpace(record.view.eyecase.CFrame)
  local sourceFrame=source.eye.CFrame
  local sourceHP=source:GetAttribute('HP')
  for n=1,fps*2 do
   local now=start+n/fps
   presentation:renderTurret(record,1/fps,now)
   local current=record.eye.CFrame:ToObjectSpace(record.view.eyecase.CFrame)
   results.maxSocketDrift=math.max(results.maxSocketDrift,(current.Position-socket.Position).Magnitude)
   results.maxBaseDrift=math.max(results.maxBaseDrift,(record.view.basepart.Position-base.Position).Magnitude)
   for _,item in ipairs(record.pieces) do
    local position=item.part.Position
    assert(position.X==position.X and position.Y==position.Y and position.Z==position.Z,'nonfinite pose')
    assert(item.part.Size.Y>0,'invalid aperture size')
   end
   results.samples+=1
   if n%120==0 then task.wait() end
  end
  check(source.eye.CFrame==sourceFrame and source:GetAttribute('HP')==sourceHP,'renderer leaves authoritative source unchanged at '..fps..' FPS')
  source:SetAttribute('Aim',source.eye.Position+Vector3.new(12,5,14))
  source:SetAttribute('Telegraph',true);source:SetAttribute('FireAt',start+2.8)
  presentation:renderTurret(record,.016,start+2.6)
  check(record.beam.Enabled and record.core.Enabled and record.light.Brightness>.4,'charge and both beam layers at '..fps..' FPS')
  source:SetAttribute('Telegraph',false);source:SetAttribute('ShotSerial',1)
  presentation:renderTurret(record,.016,start+2.8)
  local effects=#presentation.pulses
  presentation:renderTurret(record,.016,start+2.816)
  check(#presentation.pulses==effects,'duplicate shot snapshot does not replay effects at '..fps..' FPS')
  source:SetAttribute('HP',240)
  presentation:renderTurret(record,.016,start+2.9)
  check(record.hitAt==start+2.9,'damage reaction at '..fps..' FPS')
  source:SetAttribute('HP',0);source:SetAttribute('Dead',true)
  presentation:renderTurret(record,.016,start+3)
  local deathAt=record.deathAt
  presentation:renderTurret(record,.016,start+4.5)
  check(not record.beam.Enabled and not record.core.Enabled and record.light.Brightness==0,'dead sentry has no threat effects at '..fps..' FPS')
  check(record.deathAt==deathAt and record.eye.Transparency>.8,'collapse completes once at '..fps..' FPS')
  reset();presentation:renderTurret(record,.016,start+4.6)
  presentation:renderTurret(record,.016,start+6)
  check(record.eye.Transparency<.1 and record.restoreAt==start+4.6,'reassembly restores eye at '..fps..' FPS')
  presentation:destroyTurret(record);presentation:update(0,start+10)
 end
 check(results.maxSocketDrift<.0001,'eye and housing remain one rigid assembly')
 check(results.maxBaseDrift==0,'anchored plinth never moves')
 reset();source:SetAttribute('Dead',true);source:SetAttribute('HP',0);source:SetAttribute('ShotSerial',19)
 local record=presentation:registerTurret(source,workspace:GetServerTimeNow())
 check(#presentation.pulses==0 and record.eye.Transparency>.8,'late joining a ruin does not replay death or old shots')
end)
presentation:destroy();fixture:Destroy()
assert(ok,err)
return results
