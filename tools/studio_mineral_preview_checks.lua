-- Invoke after the production PickupView bundle. This is an Edit component check.
assert(not game:GetService('RunService'):IsRunning())
local fx=Instance.new('Folder');fx.Name='TemporaryMineralPreview';fx.Parent=workspace
local sources=Instance.new('Folder');sources.Parent=fx
local camera=workspace.CurrentCamera;local before=camera.CFrame
camera.CFrame=CFrame.new(16,10,0)
local view=PickupView.new(sources,fx,nil,function() return false end)
local report={}
local now=workspace:GetServerTimeNow()
for row=1,2 do
for index,key in ipairs(RockFinish.Gems.geometry.order) do
 now+=2
 local i=index+(row-1)*5
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
 report[key..(row==2 and "Compact" or "")]={sameMesh=true,sameMaterial=true,sameEffects=true}
end
end
camera.CFrame=before
shared.MineralPreviewCheck={view=view,root=fx,report=report,update=function() view:update(1/60,workspace:GetServerTimeNow()) end,
 close=function() view:destroy();fx:Destroy();shared.MineralPreviewCheck=nil end}
local diamond=view.byId[-5]
assert(#view.lineup.sources==10 and #view.lineup.records==10)
assert(diamond.view.Material==Enum.Material.Neon)
assert(diamond.view:GetAttribute('RefractionPatterns')==0)
assert(diamond.view.MineralClouds.Material==Enum.Material.Neon)
assert(math.abs(diamond.view.MineralClouds.Transparency-.44)<.001)
assert(not diamond.view.MineralClouds.DoubleSided)
local geometry=RockFinish.Gems.geometry
local compact=geometry.describe('Ruby',true)
for _,key in ipairs(geometry.order) do
 local data=geometry.describe(key,true)
 local original=geometry.describe(key,false)
 assert(data.material==original.material and data.opacity==original.opacity and data.vertexAlpha==original.vertexAlpha,'finish mismatch '..key)
 assert(data.texture==original.texture and #data.grains==#original.grains,'texture/inclusion mismatch '..key)
 for _,f in ipairs(data.faces) do for j=1,3 do
  local p=(f[j]-data.center)/data.extents*original.extents+original.center
  assert((Vector3.new(f[j+3].R,f[j+3].G,f[j+3].B)-Vector3.new(original.colorAt(p,f.facet).R,original.colorAt(p,f.facet).G,original.colorAt(p,f.facet).B)).Magnitude<.0001,'palette mismatch '..key)
 end end
 assert(#data.faces==#compact.faces)
 for i,f in ipairs(data.faces) do for j=1,3 do assert((f[j]-compact.faces[i][j]).Magnitude<.00001) end end
 local faces={};for _,f in ipairs(data.faces) do faces[f.facet]=true end
 local count=0;for _ in pairs(faces) do count+=1 end
 assert(count==12,'compact cut should have 12 broad faces')
end
local gem=diamond.view;local pose=gem.CFrame
for step=1,120 do
 gem.CFrame=pose*CFrame.Angles(step*.05,step*.12,0)
 RockFinish.Gems.update(gem,1)
 local inner=gem.MineralClouds
 assert((inner.CFrame.Position-(gem.CFrame*CFrame.new(gem.Size*inner:GetAttribute('CenterRatio'))).Position).Magnitude<.001)
 assert(gem:GetAttribute('RefractionPattern')==nil,'no discrete texture swapping')
end
gem.CFrame=pose;RockFinish.Gems.update(gem,1)
assert(not diamond.view:FindFirstChild('PrismaticEdges'),'detached rim ribbons removed')
assert(not diamond.view.DoubleSided)
assert(not diamond.displayRig.outline.Enabled,'Diamond does not stack a white outline over its rims')
assert(diamond.displayRig.light and diamond.displayRig.light.Enabled)
assert(not view.byId[-1].displayRig.light)
for i=1,3 do assert(typeof(diamond.view:GetAttribute('GemFlare'..i))=='Vector3') end
assert(diamond.view.MineralClouds.TextureContent~=Content.none)
assert(view.byId[-3].view:GetAttribute('OpticalTexture'))
assert(diamond.displayRig.rays[1].beam.Enabled)
PickupDisplay.draw(diamond.displayRig,diamond,diamond.view.Position-Vector3.yAxis*2,now,1,true,true)
for _,ray in ipairs(diamond.displayRig.rays) do assert(not ray.beam.Enabled and not ray.flare.Enabled) end
PickupDisplay.draw(diamond.displayRig,diamond,diamond.view.Position-Vector3.yAxis*2,now,1,false,false)
for _,ray in ipairs(diamond.displayRig.rays) do assert(ray.beam.Enabled and ray.flare.Enabled) end
assert(not view.byId[-1].view:FindFirstChild('FixedInclusions'))
assert(view.byId[-1].view.Material==Enum.Material.SmoothPlastic)
assert(view.byId[-3].view.Transparency>view.byId[-1].view.Transparency)
return report
