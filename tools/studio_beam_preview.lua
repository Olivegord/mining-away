-- Bundle after production BeamVFX. Temporary Edit-only component preview.
-- Run only in the existing canonical editable document; never save this folder.
assert(not game:GetService('RunService'):IsRunning(),'This preview requires stopped Studio Edit mode')
assert(game.PlaceId==136098934779395 or game.PlaceId==0,'Wrong game')
assert(workspace:FindFirstChild('MiningAway'),'Open the existing editable workspace')
local camera=assert(workspace.CurrentCamera,'No native camera')
local previous=workspace:FindFirstChild('MiningAwayBeamReview');if previous then previous:Destroy() end
local root=Instance.new('Folder');root.Name='MiningAwayBeamReview';root.Parent=workspace
local palette={Color3.fromRGB(255,208,69),Color3.fromRGB(245,105,85),Color3.fromRGB(104,224,146),
 Color3.fromRGB(45,224,255),Color3.fromRGB(104,224,146),Color3.fromRGB(141,209,151),Color3.fromRGB(244,193,89),
 Color3.fromRGB(255,179,102),Color3.fromRGB(255,137,210),Color3.fromRGB(171,111,255),
 Color3.fromRGB(255,92,109),Color3.fromRGB(255,140,48),Color3.fromRGB(179,105,255)}
local styles={'Cutter','Percussion','Resonance','Combat','Branch','Repair','Courier','Sentry','Lance','Orbital','Gridcutter','Starforge','Singularity'}
local origin=camera.CFrame.Position+camera.CFrame.LookVector*24
local right=camera.CFrame.RightVector
local rigs={}
for i,style in ipairs(styles) do
 local position=origin+right*((i-1)%7-3)*3.5+Vector3.yAxis*(math.floor((i-1)/7)*8-4)
 local group=Instance.new('Folder');group.Name=style;group.Parent=root
 local rig=BeamVFX.new(group,style,palette[i]);rigs[i]={rig=rig,from=position+Vector3.yAxis*5,to=position}
end
-- This uses production phase functions and native Beam rendering. It cannot
-- establish mining contact, network behavior, frame rate, or full-game quality.
task.spawn(function()
 local started=os.clock()
 while root.Parent and os.clock()-started<24 do
  local elapsed=os.clock()-started;local t=elapsed%4
  for i,r in ipairs(rigs) do
   local scale=styles[i]=='Orbital' and .65 or 1
   if t<1.4 then BeamVFX.draw(r.rig,r.from,r.to,elapsed,0,t/1.4,nil,scale)
   elseif t<2.4 then BeamVFX.draw(r.rig,r.from,r.to,elapsed,math.min(1,(t-1.4)/.06),nil,t-1.4,scale)
   else BeamVFX.after(r.rig,r.from,r.to,elapsed,t-2.4,scale) end
  end
  task.wait(1/60)
 end
 root:Destroy()
end)
return {mode='Temporary native Edit component preview; NOT gameplay or visual approval',duration=24,
 cleanup="workspace:FindFirstChild('MiningAwayBeamReview'):Destroy()",save=false}
