-- Bundle CrystalCuts and RockFinish before this detached Edit-only component check.
RockFinish.Gems.prepare()
local report={gems={},shells={}}
local cuts={}
for _,name in ipairs(CrystalCuts.variants) do cuts[name]=assert(CrystalCuts.build(name,cuts),'missing '..name) end
local camera=workspace.CurrentCamera
local cameraBefore=camera.CFrame
local root=Instance.new('Folder');root.Name='TemporaryMineralChecks';root.Parent=workspace
local ok,err=xpcall(function()
 camera.CFrame=CFrame.new(0,110,15)
 for i,key in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
  local source=Instance.new('Part');source.Size=Vector3.new(2.16,1.28,1.94);source:SetAttribute('Mineral',key)
  local gem,faceted=RockFinish.Gems.clone(source);source:Destroy()
  assert(faceted,'runtime mesh construction failed for '..key);gem.Parent=root
  gem.CFrame=CFrame.new(i*3,103,0)*CFrame.Angles(.3,.8,-.2)
  local core=gem:FindFirstChild('FixedInclusions')
  if key=='Cobalt' then
   assert(not core and gem.Material==Enum.Material.Metal,'bismuth should be opaque metal')
   assert(#RockFinish.Gems.geometry.describe(key).boxes>=70,'bismuth lost its terraces')
  else
   assert(core,'missing interior grains')
   local center=core:GetAttribute('CenterRatio')
   RockFinish.Gems.update(gem,1)
   assert(core.Transparency==0 and (gem.CFrame:PointToObjectSpace(core.Position)/gem.Size-center).Magnitude<.0001,'grain pose/opacity')
   local before=core.Size
   gem.Size*=.7;gem.CFrame*=CFrame.Angles(0,.4,0);RockFinish.Gems.update(gem,.25)
   assert(math.abs(core.Transparency-.75)<.0001 and (core.Size-before*.7).Magnitude<.0001,'grain fade/scale')
  end
  report.gems[key]={faceted=true,size=tostring(gem.Size),grains=core~=nil}
 end
 for name,part in pairs(cuts) do
  local shell=CrystalCuts.inset(part);cuts[name]=shell
  local paths=game:GetService('HttpService'):JSONDecode(assert(shell:GetAttribute('CoreFissures')))
  assert(#paths==2 and shell:FindFirstChild('CoreGeometry'),'missing shell/core')
  shell.CFrame=CFrame.new(0,103,0);shell.Parent=root
  local record={source=shell,view=shell,baseColor=Color3.fromRGB(60,160,240),visual={broken=false}}
  RockFinish.veins(record,1,false,false)
  local state=assert(record.veinFX)
  assert(#state.rays>=14 and #state.vents==2,'missing beam-ray fans')
  -- The core must be visible THROUGH the shell: cast along the opening and
  -- check that at least one interior sample reaches the smaller core first.
  local world=Instance.new('WorldModel');world.Parent=root
  local skin=shell:Clone();for _,c in ipairs(skin:GetChildren()) do c:Destroy() end
  skin.CanQuery=true;skin.Transparency=1;skin.Parent=world
  local core=state.core:Clone();core.CanQuery=true;core.Parent=world
  task.wait()
  local visible=0
  for _,path in ipairs(paths) do
   for i=2,#path.points-1 do
    local q=path.points[i]
    local p=shell.CFrame:PointToWorldSpace(Vector3.new(q[1],q[2],q[3])*shell.Size)
    local n=shell.CFrame:VectorToWorldSpace(Vector3.new(q[4],q[5],q[6]))
    local h=world:Raycast(p+n*2,-n*6)
    if h and h.Instance==core then
     assert((p-h.Position):Dot(n)>.07,'core is on the skin');visible+=1
    end
   end
  end
  world:Destroy()
  assert(visible>0,'no open view into the core '..name)
  shell.CFrame*=CFrame.Angles(0,.4,0);shell.Size*=.65
  RockFinish.veins(record,2,true,true)
  assert(not state.rays[1].beam.Enabled and not state.vents[1].Enabled,'reduced-effects leakage')
  local expected=shell.CFrame:PointToWorldSpace(shell.Size*state.core:GetAttribute('CenterRatio'))
  assert((state.core.Position-expected).Magnitude<.001,'core did not follow shrinking rock')
  record.visual.broken=true;RockFinish.veins(record,3,false,false)
  assert(not record.veinFX and not state.root.Parent,'broken rock leaked core effects')
  report.shells[name]={openCoreSamples=visible,rays=#state.rays,poseAndCleanup=true}
 end
end,debug.traceback)
camera.CFrame=cameraBefore;root:Destroy()
for _,p in pairs(cuts) do p:Destroy() end
assert(ok,err)
return report
