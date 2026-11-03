-- Execute after mock-roblox, energy-effects.setup and production modules
-- Mining/Feedback/SentryMotion/WorkEffects/Presentation.
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS energy effects '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local root=Instance.new('Folder');root.Parent=workspace
local camera=Instance.new('Camera');camera.CFrame=CFrame.new(0,20,0);workspace.CurrentCamera=camera
check('moving monochrome transparency stays ordered and bounded at every frame rate',function()
 for _,fps in ipairs({30,60,144}) do for frame=0,fps*2 do
  local sequence=WorkEffects.orbitalTransparency(frame/fps)
  assert(#sequence>=13 and #sequence<=15 and sequence[1].Time==0 and sequence[#sequence].Time==1)
  for i,key in ipairs(sequence) do
   assert(key.Value>=0 and key.Value<=1)
   if i>1 then assert(key.Time>sequence[i-1].Time,'duplicate or unordered ramp key') end
  end
 end end
 local first=WorkEffects.orbitalTransparency(0);local moved=WorkEffects.orbitalTransparency(.025)
 assert(math.abs(first[2].Time-moved[2].Time)>.001,'ramp did not move')
end)
check('break energy uses round glowing discs and bounded burst cleanup',function()
 local work=WorkEffects.new(root)
 for n=1,30 do work:burst(Vector3.zero,Vector3.yAxis,Color3.new(1,1,0),38,100) end
 assert(#work.bursts==work.maxBursts)
 local emitter=work.bursts[1].part:FindFirstChildWhichIsA('ParticleEmitter')
 assert(emitter.Texture=='rbxasset://textures/particles/flare_main.dds' and emitter.LightEmission==1)
 assert(emitter.Emitted==38 and emitter.Rate==0 and emitter.Lifetime.Max==.85)
 local bloom=game:GetService('Lighting'):FindFirstChild('MiningEnergyBloom');assert(bloom and bloom.Intensity>1)
 work:update(101.1);assert(#work.bursts==0);work:destroy();assert(bloom.Parent==nil)
end)
check('orbital extends above high camera and collapses on authoritative end',function()
 local source=Instance.new('Folder');source.Name='DroneRoleServerEffects';source.Parent=workspace
 local group=Instance.new('Folder');group:SetAttribute('OrbitalBurn',true);group:SetAttribute('Position',Vector3.zero);group.Parent=source
 local core=Instance.new('Part');core.Name='MeltCore';core.LocalTransparencyModifier=.2;core.Parent=group
 local work=WorkEffects.new(root);camera.CFrame=CFrame.new(0,400,0);work:update(10)
 local fx=assert(work.orbitals[group]);assert(fx.top.Position.Y>=580)
 assert(core.LocalTransparencyModifier==1,'solid source washed out the clear ramp gaps')
 camera.CFrame=CFrame.new(0,400,0);work:update(10.1);assert(fx.top.Position.Y>=580)
 assert(fx.ramp.Color.R==1 and fx.ramp.Color.G==1 and fx.ramp.Color.B==1)
 group:SetAttribute('ContactAt',9);work:update(10.1);assert(not fx.ramp.Enabled,'stale strike kept drilling')
 core.LocalTransparencyModifier=0
 group:SetAttribute('ContactAt',10.1);work:update(10.1);assert(fx.ramp.Enabled,'fresh contact failed to resume')
 assert(core.LocalTransparencyModifier==1,'resume restored a solid column over the clear gaps')
 group:SetAttribute('EndedAt',10.1);work:update(10.34);assert(fx.ramp.Width0<.5)
 work:update(10.7);assert(work.orbitals[group]==nil and fx.holder.Parent==nil)
 assert(core.LocalTransparencyModifier==.2,'source visibility was not restored after collapse')
 work:destroy();source:Destroy();camera.CFrame=CFrame.new(0,20,0)
end)
check('nearby character feels the impact at far camera zoom and reduced motion opts out',function()
 local renderer=Presentation.new({parent=root});local oldPlayer=players.LocalPlayer
 local player=Instance.new('Player');local character=Instance.new('Model')
 local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=Vector3.new(0,3,0);body.Parent=character;player.Character=character
 players.LocalPlayer=player;camera.CFrame=CFrame.new(0,400,0)
 renderer:kick(Vector3.zero,.09,100);assert(renderer.shakeStrength>.07,'camera zoom swallowed nearby impact')
 local before=renderer.shakeStrength;player:SetAttribute('ReducedMotion',true)
 renderer:kick(Vector3.zero,.14,100.01);assert(renderer.shakeStrength==before)
 renderer:destroy();players.LocalPlayer=oldPlayer;character:Destroy();player:Destroy();camera.CFrame=CFrame.new(0,20,0)
end)
check('real fracture creates authored mesh chunks and honors pool limit',function()
 local source=Instance.new('UnionOperation');source:SetAttribute('FullSize',Vector3.one*4);source.Parent=workspace
 local view=source:Clone();view.Size=Vector3.one;view.Position=Vector3.new(0,2,0);view.Parent=root
 local renderer=Presentation.new({parent=root});renderer._floor=function() return 0 end
 local resource={source=source,view=view,baseColor=Color3.new(.5,.7,1)}
 renderer:resourceImpact(resource,'stage',100);assert(#renderer.fragments==3)
 renderer:resourceImpact(resource,'break',100.5);assert(#renderer.fragments==12)
 for _,fragment in ipairs(renderer.fragments) do
  assert(fragment.part:IsA('UnionOperation'),'lost original rock geometry')
  assert(fragment.velocity.Y>0 and fragment.duration>=.75 and not fragment.part.CanQuery)
 end
 for n=1,10 do renderer:resourceImpact(resource,'break',101+n*.1) end
 assert(#renderer.fragments==renderer.maxFragments)
 renderer:update(1,110);assert(#renderer.fragments==0);renderer:destroy();source:Destroy()
end)
root:Destroy();camera:Destroy()
print(checks..' production energy/fragment behavior checks with API doubles; Studio appearance remains separate')
