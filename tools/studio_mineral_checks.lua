-- Run after bundling CrystalCuts and RockFinish in Studio Edit. Detached
-- component verification only; no Play session and no gameplay acceptance.
RockFinish.Gems.prepare()
local report={gems={},veins={}}
local cuts={}
for _,name in ipairs(CrystalCuts.variants) do
 cuts[name]=assert(CrystalCuts.build(name,cuts),'missing '..name)
end
local camera=workspace.CurrentCamera
local cameraBefore=camera.CFrame
local root=Instance.new('Folder');root.Name='TemporaryMineralChecks';root.Parent=workspace
local ok,err=xpcall(function()
 camera.CFrame=CFrame.new(0,110,15)
 for i,key in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
  local source=Instance.new('Part');source.Size=Vector3.new(2.16,1.28,1.94);source:SetAttribute('Mineral','Rock:Run'..key..':10')
  local gem,faceted=RockFinish.Gems.clone(source);source:Destroy()
  assert(faceted,'runtime mesh construction failed for '..key)
  gem.Parent=root
  gem.CFrame=CFrame.new(i*3,103,0)*CFrame.Angles(.3,.8,-.2)
  local core=assert(gem:FindFirstChild('FixedInclusions'))
  local center=core:GetAttribute('CenterRatio')
  RockFinish.Gems.update(gem,1)
  assert(core.Transparency==0 and (gem.CFrame:PointToObjectSpace(core.Position)/gem.Size-center).Magnitude<.0001,'grain pose/opacity')
  local before=core.Size
  gem.Size*=.7;gem.CFrame*=CFrame.Angles(0,.4,0);RockFinish.Gems.update(gem,.25)
  assert(math.abs(core.Transparency-.75)<.0001 and (core.Size-before*.7).Magnitude<.0001,'grain fade/scale')
  report.gems[key]={faceted=true,opaqueInterior=true,size=tostring(gem.Size/.7),tint=tostring(RockFinish.Gems.tint(key))}
 end
 for name,part in pairs(cuts) do
  local carved=CrystalCuts.inset(part);cuts[name]=carved
  local encoded=assert(carved:GetAttribute('InsetVeins'),'missing carved channels '..name)
  local paths=game:GetService('HttpService'):JSONDecode(encoded)
  assert(#paths==2,'expected two sides')
  local world=Instance.new('WorldModel');world.Parent=root
  local probe=carved:Clone();probe.CanQuery=true;probe.Transparency=1;probe.Parent=world
  task.wait()
  local point=paths[1].points[4]
  local p=probe.CFrame:PointToWorldSpace(Vector3.new(point[1],point[2],point[3])*probe.Size)
  local n=probe.CFrame:VectorToWorldSpace(Vector3.new(point[4],point[5],point[6]))
  local hit=assert(world:Raycast(p+n*5,-n*10))
  local clearance=(p-hit.Position):Dot(n)
  assert(clearance>.005,'core is buried under the stone surface: '..name..' '..clearance)
  world:Destroy()
  carved.CFrame=CFrame.new(0,103,0);carved.Parent=root
  local color=Color3.fromRGB(60,160,240)
  local _,gradient=RockFinish.apply(carved,color)
  local record={source=carved,view=carved,baseColor=color,stoneGradient=gradient,visual={broken=false}}
  RockFinish.veins(record,1,false,false)
  local state=assert(record.veinFX)
  local expected=0;for _,path in ipairs(paths) do expected+=#path.points-1 end
  assert(#state.segments==expected and #state.vents==2,'incomplete channel renderer')
  local segment=state.segments[1]
  carved.CFrame*=CFrame.Angles(0,.4,0);carved.Size*=.65
  RockFinish.veins(record,2,true,true)
  assert(not state.vents[1].dust.Enabled and not state.vents[1].beam.Enabled,'reduced-effects leakage')
  local midpoint=carved.CFrame:PointToWorldSpace((segment.a+segment.b)*.5*carved.Size)
  assert((segment.part.Position-midpoint).Magnitude<.001,'channel did not follow shrinking rock')
  record.visual.broken=true;RockFinish.veins(record,3,false,false)
  assert(not record.veinFX and not state.root.Parent,'broken rock leaked channel effects')
  report.veins[name]={paths=#paths,recessClearance=clearance,poseAndCleanup=true}
 end
end,debug.traceback)
camera.CFrame=cameraBefore
root:Destroy()
for _,p in pairs(cuts) do p:Destroy() end
assert(ok,err)
return report
