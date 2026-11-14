-- Invoke after the production PickupView bundle. This is an Edit component check.
assert(not game:GetService('RunService'):IsRunning())
local fx=Instance.new('Folder');fx.Name='TemporaryMineralPreview';fx.Parent=workspace
local sources=Instance.new('Folder');sources.Parent=fx
local camera=workspace.CurrentCamera;local before=camera.CFrame
camera.CFrame=CFrame.new(0,10,8)
local view=PickupView.new(sources,fx,nil,function() return false end)
local report={}
local now=workspace:GetServerTimeNow()
for i,key in ipairs(RockFinish.Gems.geometry.order) do
 local sample=assert(view.byId[-i]);assert(sample.faceted,'sample mesh fallback '..key)
 local source=view.lineup.sources[i]
 local actual=source:Clone();actual:SetAttribute('PickupId',i+100);actual.Parent=sources
 task.wait()
 view:update(1/60,now)
 local drop=assert(view.records[actual]);assert(drop.faceted,'drop mesh fallback '..key)
 assert(drop.view.MeshContent==sample.view.MeshContent and drop.view.Size==sample.view.Size,'different specimen mesh '..key)
 assert(drop.view.Material==sample.view.Material and drop.view.Transparency==sample.view.Transparency,'different specimen material '..key)
 assert(sample.displayRig and drop.displayRig and sample.hoverAlpha==1 and drop.hoverAlpha==1,'missing shared pickup effects '..key)
 actual:Destroy();view:update(1/60,now+1)
 report[key]={sameMesh=true,sameMaterial=true,sameEffects=true}
end
camera.CFrame=before
shared.MineralPreviewCheck={view=view,root=fx,report=report,update=function() view:update(1/60,workspace:GetServerTimeNow()) end,
 close=function() view:destroy();fx:Destroy();shared.MineralPreviewCheck=nil end}
local diamond=view.byId[-5]
assert(diamond.view:FindFirstChild('MineralClouds'))
assert(diamond.displayRig.rays[1].beam.Enabled)
PickupDisplay.draw(diamond.displayRig,diamond,diamond.view.Position-Vector3.yAxis*2,now,1,true,true)
for _,ray in ipairs(diamond.displayRig.rays) do assert(not ray.beam.Enabled) end
PickupDisplay.draw(diamond.displayRig,diamond,diamond.view.Position-Vector3.yAxis*2,now,1,false,false)
for _,ray in ipairs(diamond.displayRig.rays) do assert(ray.beam.Enabled) end
assert(not view.byId[-1].view:FindFirstChild('FixedInclusions'))
assert(view.byId[-1].view.Material==Enum.Material.SmoothPlastic)
assert(view.byId[-3].view.Transparency>view.byId[-1].view.Transparency)
return report
