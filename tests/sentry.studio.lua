-- Engine renderer test with controlled authoritative snapshots, not multiplayer.
-- Install build.module_bundle(('Feedback','SentryMotion','Presentation')) followed
-- by `return {Presentation=Presentation,Motion=SentryMotion}` in the temporary
-- ReplicatedStorage.SentryReviewModules ModuleScript, then execute in Client.
local RS=game:GetService('ReplicatedStorage')
local P=require(RS.SentryReviewModules).Presentation
local original=workspace.MiningAway.Fields.Cobalt.Pyramid_1
local fixture=Instance.new('Folder');fixture.Name='SentryRendererTest';fixture.Parent=workspace
local field=original.Parent.Field:Clone();field.CanQuery=false;field.Parent=fixture
local source=original:Clone();source.Parent=fixture
for _,part in ipairs(source:GetDescendants()) do
 if part:IsA('BasePart') then part.CanCollide=false;part.CanQuery=false;part.CanTouch=false end
end
local fx=Instance.new('Folder');fx.Parent=fixture
local presentation=P.new({parent=fx});presentation.maxPulses=64
local results={samples=0,maxSocketDrift=0,maxBaseDrift=0,peakRise=0,passed={}}
local function check(value,name) assert(value,name);table.insert(results.passed,name) end
local function audioCount(name)
 local n=0;for _,o in ipairs(fx:GetDescendants()) do if o:IsA('Sound') and o.Name==name then n+=1 end end;return n
end
local function reset()
 source:SetAttribute('Dead',false);source:SetAttribute('HP',260);source:SetAttribute('MaxHP',260)
 source:SetAttribute('ShotSerial',0);source:SetAttribute('Telegraph',false);source:SetAttribute('Aim',nil)
 source:SetAttribute('Awake',false);source:SetAttribute('WakeAt',0);source:SetAttribute('DeathAt',0)
 source:SetAttribute('WatchPosition',source.eye.Position+Vector3.new(20,3,25))
end
local ok,err=pcall(function()
 for _,fps in ipairs({30,60,144}) do
  reset();local start=workspace:GetServerTimeNow()
  local record=presentation:registerTurret(source,start)
  local base=record.view.basepart.CFrame;local top=record.view.topseg.Position.Y
  local sleeping=record.view.topseg.CFrame
  presentation:renderTurret(record,1/fps,start+.1)
  check(record.view.topseg.CFrame==sleeping and record.eye.Transparency==1,'closed dormant stack stays still at '..fps..' FPS')
  local previous
  for _,name in ipairs({'bottemseg','lowerseg','upperseg','topseg'}) do
   local part=record.view:FindFirstChild(name)
   if previous then assert(part.Position.Y-part.Size.Y*.5<=previous.Position.Y+previous.Size.Y*.5,'gap in dormant stack') end
   previous=part
  end
  local sourceFrame=source.eye.CFrame
  source:SetAttribute('WakeAt',start);source:SetAttribute('ActivateAt',start+2.15);source:SetAttribute('Awake',true)
  local socket=record.eye.CFrame:ToObjectSpace(record.view.eyecase.CFrame)
  local ignitionSounds=audioCount('SentryIgnition')
  for n=1,fps*3 do
   local now=start+n/fps;presentation:renderTurret(record,1/fps,now)
   results.peakRise=math.max(results.peakRise,record.view.topseg.Position.Y-top)
   results.maxSocketDrift=math.max(results.maxSocketDrift,(record.eye.CFrame:ToObjectSpace(record.view.eyecase.CFrame).Position-socket.Position).Magnitude)
   results.maxBaseDrift=math.max(results.maxBaseDrift,(record.view.basepart.Position-base.Position).Magnitude)
   if math.abs(n/fps-2.2)<.5/fps then
    check(record.flare.Enabled and record.flare.Size.X.Scale>20,'large ignition flare at '..fps..' FPS')
   end
   results.samples+=1;if n%120==0 then task.wait() end
  end
  check(source.eye.CFrame==sourceFrame and source:GetAttribute('HP')==260,'renderer preserves authoritative geometry and hull at '..fps..' FPS')
  check(audioCount('SentryIgnition')-ignitionSounds==2,'one wake and one ignition sound at '..fps..' FPS')
  local look=(source:GetAttribute('WatchPosition')-record.eye.Position).Unit
  check(record.eye.CFrame.LookVector:Dot(look)>.99,'eye opening faces player after spin at '..fps..' FPS')
  source:SetAttribute('Aim',source.eye.Position+Vector3.new(12,5,14));source:SetAttribute('Telegraph',true);source:SetAttribute('FireAt',start+3.8)
  presentation:renderTurret(record,1/fps,start+3.6)
  check(record.beam.Enabled and record.core.Enabled,'active threat still readable at '..fps..' FPS')
  source:SetAttribute('Telegraph',false);source:SetAttribute('ShotSerial',1)
  presentation:renderTurret(record,1/fps,start+3.8)
  local effects=#presentation.pulses;presentation:renderTurret(record,1/fps,start+3.82)
  check(#presentation.pulses==effects,'same server shot cannot duplicate effects at '..fps..' FPS')
  source:SetAttribute('HP',220);presentation:renderTurret(record,1/fps,start+3.9)
  check(record.hitAt==start+3.9,'damage triggers weighted flinch at '..fps..' FPS')
  local sounds=audioCount('StoneSlabThud')
  source:SetAttribute('HP',0);source:SetAttribute('DeathAt',start+4);source:SetAttribute('Dead',true)
  for n=0,fps*2 do
   presentation:renderTurret(record,1/fps,start+4+n/fps)
   results.samples+=1;if n%120==0 then task.wait() end
  end
  check(audioCount('StoneSlabThud')-sounds==5,'five independent slab/socket ground impacts at '..fps..' FPS')
  check(not record.beam.Enabled and not record.flare.Enabled and record.light.Brightness==0,'death extinguishes all threat and flare effects at '..fps..' FPS')
  local settled={};for _,item in ipairs(record.pieces) do settled[item.part]=item.part.CFrame end
  presentation:renderTurret(record,1/fps,start+20)
  for part,frame in pairs(settled) do assert(part.CFrame==frame,'wreck moved after impact') end
  check(audioCount('StoneSlabThud')-sounds==5,'wreck stays embedded with no bounce or repeated thuds at '..fps..' FPS')
  reset();presentation:renderTurret(record,1/fps,start+21);presentation:renderTurret(record,1/fps,start+23)
  check(record.eye.Transparency==1 and record.view.topseg.Position.Y<source.topseg.Position.Y-3,'reset reassembles closed sleeping stack at '..fps..' FPS')
  presentation:destroyTurret(record);presentation:update(0,start+30)
 end
 check(results.peakRise>23,'wake expands more than twenty-three studs from closed crown')
 check(results.maxSocketDrift<.00015,'eye and housing remain one rigid assembly')
 check(results.maxBaseDrift==0,'stone plinth stays anchored')
 reset();source:SetAttribute('Dead',true);source:SetAttribute('HP',0);source:SetAttribute('ShotSerial',19);source:SetAttribute('DeathAt',workspace:GetServerTimeNow()-10)
 local record=presentation:registerTurret(source,workspace:GetServerTimeNow())
 check(audioCount('StoneSlabThud')==0 and #presentation.pulses==0,'late join to old ruins does not replay impact or ignition audio')
 check(not record.flare.Enabled,'late join to ruin has no activation flare')
end)
presentation:destroy();fixture:Destroy();assert(ok,err)
return results
