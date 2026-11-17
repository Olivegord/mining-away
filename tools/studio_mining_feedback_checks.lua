-- Prepend production FieldInteractionView, DroneStatus and GeodeView modules.
-- This isolated Edit component fixture creates and removes its own objects.
assert(not game:GetService('RunService'):IsRunning())
local folder=Instance.new('Folder');folder.Name='MiningFeedbackCheck';folder.Parent=workspace
local gui=Instance.new('ScreenGui');gui.Name='MiningFeedbackCheck';gui.Parent=game:GetService('CoreGui')
local interaction,openings
local ok,result=pcall(function()
 local camera=workspace.CurrentCamera
 local model=Instance.new('Model');model.Parent=folder
 local hull=Instance.new('Part');hull.Size=Vector3.new(2,1,2);hull.Anchored=true
 hull.CFrame=camera.CFrame*CFrame.new(0,0,-12);hull.Parent=model;model.PrimaryPart=hull
 local drone={view=model,pos=hull.Position}
 hull:SetAttribute('BatteryPowered',true);hull:SetAttribute('Battery',75);hull:SetAttribute('MaxBattery',100)
 hull:SetAttribute('InMiningPlot',true)
 local now=workspace:GetServerTimeNow()
 DroneStatus.draw(drone,hull,'Travel','Striker',true,now,false,false)
 assert(drone.workStatus.track.Visible and not drone.workStatus.spinner.Visible,'travel inside plot must show battery only')
 hull:SetAttribute('ThinkUntil',now+1)
 DroneStatus.draw(drone,hull,'Thinking','Striker',true,now,false,false)
 assert(drone.workStatus.track.Visible and drone.workStatus.spinner.Visible,'thinking inside plot lost battery')
 hull:SetAttribute('InMiningPlot',false)
 for _,state in ipairs({'Travel','Waiting','Return','Collect','Unload'}) do
  DroneStatus.draw(drone,hull,state,'Striker',true,now,false,false)
  assert(not drone.workStatus.gui.Enabled,'non-thinking state invented spinner: '..state)
 end
 local original=assert(game.ServerStorage:FindFirstChild('MiningAwayCrystal'))
 local view=original:Clone();view.Size=Vector3.new(1.8,1.8,1.8);view.Anchored=true;view.Transparency=0
 view.CFrame=camera.CFrame*CFrame.new(0,-2,-12);view.Parent=folder
 local source=view:Clone();source.Transparency=1;source.Parent=folder
 source:SetAttribute('Kind','Geode');source:SetAttribute('SealedDrop',true);source:SetAttribute('OpenReady',true)
 source:SetAttribute('ReadyAt',now-1);source:SetAttribute('BreakSerial',0)
 local record={source=source,view=view,restPose=view.CFrame,baseColor=view.Color}
 local audio={stopLoop=function() end,setLoop=function() end,play=function() end}
 openings=GeodeView.new(folder,audio,{},function() error('sealed discovery must not build hinged halves') end,function() end)
 openings:update(record,now)
 assert(openings.rigs[record].root:IsA('Attachment') and not record.shellModel)
 assert(not folder:FindFirstChild('ReadyGlow',true) and view.Transparency==0)
 source:SetAttribute('OpeningAt',now+.85);openings:update(record,now+.4)
 assert(view.CFrame~=record.restPose,'opening anticipation missing')
 interaction=FieldInteractionView.new(gui,folder,function() end)
 interaction:show('Open geode',view,view.Position,view.Size.Y,'E')
 assert(interaction.gui.Size==UDim2.fromOffset(132,34) and interaction.highlight.Adornee==view)
 interaction:select();assert(folder:FindFirstChild('InteractionSelection'))
 interaction:show(nil);assert(not interaction.gui.Enabled and not interaction.highlight.Enabled)
 return {batteryInPlot=true,spinnerOnlyThinking=true,sealedOriginalGeometry=true,noHingeOrHalo=true,prompt='132x34',whiteSelectionParticles=true}
end)
if interaction then interaction:destroy() end
if openings then openings:destroy() end
gui:Destroy();folder:Destroy()
assert(ok,result)
return result
