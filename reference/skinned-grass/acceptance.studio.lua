-- Run on a real Studio client in Play. Exercises the imported module and real rig.
local assets=game.ReplicatedStorage:WaitForChild('SkinnedGrass')
local module=require(assets.SkinnedGrass)
local folder=Instance.new('Folder');folder.Name='GrassAcceptance';folder.Parent=workspace
local storage=Instance.new('Folder');storage.Name='GrassAcceptanceStorage';storage.Parent=game.ReplicatedStorage
local model=assets.Studio.Models.Model:Clone();model.Parent=folder
local sim=module.new({RenderInAnimation=false,RenderOutAnimation=false,WindEnabled=false,MeshStorage=storage,RenderDistance=50})
assert(sim.Settings.WindEnabled==false and sim.Settings.RenderInAnimation==false,'false settings overwritten')
sim:AddMeshes({model})
assert(model.Parent==storage,'new mesh was not stored')
local mesh=model.Mesh;local bone=mesh.SkinnedGrass_Origin:FindFirstChildWhichIsA('Bone')
local pos=bone.WorldCFrame.Position
sim:Step(1/60,{},pos)
assert(model.Parent==folder,'nearby grass did not render')
-- An exactly coincident collider formerly produced a NaN direction.
sim:Step(1/60,{pos},pos)
for _,v in {bone.Transform:GetComponents()} do assert(v==v and math.abs(v)<1e9,'nonfinite collision transform') end
local angle=select(2,bone.Transform:ToAxisAngle())
assert(angle>.5,'grass did not bend around the collider')
sim:Step(1/60,{},pos+Vector3.new(500,0,0))
assert(model.Parent==storage,'distant grass did not cull')
sim:Step(1/60,{},pos)
assert(model.Parent==folder,'returning grass failed to render')
folder:Destroy();storage:Destroy()
return {kind='real Studio client / imported rig and module',falseSettings=true,coincidentCollisionFinite=true,bendDegrees=math.deg(angle),renderAndCull=true}
