-- Native Edit check after SelectorView with Workshop.selectorWidth returning 30.
local root=Instance.new('Folder');root.Name='TemporarySelectorDistance';root.Parent=workspace
local map=Instance.new('Folder');map.Parent=root
local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=map
local player=Instance.new('Folder');player:SetAttribute('MA_Selector',Vector3.new(0,100,0))
local view=SelectorView.new({parent=root,world={Map=map},player=player,profile=function() return {} end,hidden=function() return false end,reducedMotion=function() return false end})
view.aim=function() return nil end
local camera=workspace.CurrentCamera;local before=camera.CFrame
local report={}
local ok,err=xpcall(function()
 for _,distance in ipairs({15,42,56,70,100,15}) do
  camera.CFrame=CFrame.new(0,100,distance)
  view:showAim(.1,{})
  local opacity=view.pinned.sides[1].opacity
  if distance<=42 then assert(opacity==0,'near camera saw boundary reveal') else assert(opacity>0,'far camera lost boundary') end
  report[tostring(distance)]=opacity
 end
 player:SetAttribute('MA_SelectorPrevious',Vector3.new(1,100,0))
 view:showAim(.1,{})
 assert(view.previous.sides[1].opacity==0,'near camera saw transfer boundary')
end,debug.traceback)
camera.CFrame=before;view:destroy();root:Destroy();player:Destroy();assert(ok,err)
return report
