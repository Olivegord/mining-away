-- Execute in Studio Edit, with the staged payloads served from localhost:8767.
assert(not game:GetService('RunService'):IsRunning(),'Install only in Edit')
assert(game.PlaceId==124078027733625 or game.PlaceId==0,'Wrong game: expected DRONEREVOLUTION or the canonical local file')
assert(game.PlaceId==0 or game.GameId==10774898335,'Wrong DRONEREVOLUTION universe')
assert(workspace:FindFirstChild('MiningAway'),'Expected the existing game')
local http=game:GetService('HttpService')
local enabled=http.HttpEnabled
local fetched,prior,nextPayload=pcall(function()
 http.HttpEnabled=true
 return http:JSONDecode(http:GetAsync('http://127.0.0.1:8767/refinement-before-payload.json')),
  http:JSONDecode(http:GetAsync('http://127.0.0.1:8767/refinement-source-payload.json'))
end)
http.HttpEnabled=enabled
assert(fetched,prior)
assert(nextPayload.place_id==124078027733625 and nextPayload.universe_id==10774898335,'Wrong destination payload')
local targets,before,untouched={},{},{}
for path,entry in pairs(nextPayload.sources) do
 local node=game
 for name in path:gmatch('[^.]+') do node=assert(node:FindFirstChild(name),path) end
 assert(node.ClassName==entry.class,'Wrong class: '..path)
 local previous=assert(prior.sources[path],'Missing baseline: '..path)
 assert(node.Source==previous.source or node.Source==entry.source,'Unreviewed source: '..path)
 targets[node]={path=path,entry=entry};before[node]=node.Source
end
for _,node in ipairs(game:GetDescendants()) do
 if node:IsA('LuaSourceContainer') and not targets[node] then untouched[node]=node.Source end
end
local editor=game:GetService('ScriptEditorService')
local changes={}
local ok,err=pcall(function()
 for node,value in pairs(targets) do
  if node.Source~=value.entry.source then
   editor:UpdateSourceAsync(node,function(current)
    assert(current==before[node],'Source changed during install: '..value.path)
    return value.entry.source
   end)
   table.insert(changes,node)
  end
 end
 for node,value in pairs(targets) do assert(node.Source==value.entry.source,'Result mismatch: '..value.path) end
 for node,source in pairs(untouched) do assert(node.Parent and node.Source==source,'Unrelated source changed: '..node.Name) end
end)
if not ok then
 for i=#changes,1,-1 do
  local node=changes[i]
  editor:UpdateSourceAsync(node,function(current)
   assert(current==targets[node].entry.source,'Cannot safely roll back concurrent edit')
   return before[node]
  end)
 end
 error(err)
end
local report={sources={},changed=#changes,httpRestored=http.HttpEnabled==enabled,untouchedScripts=0,validation='Exact native Edit Source equality, not runtime acceptance'}
for _ in pairs(untouched) do report.untouchedScripts+=1 end
for node,value in pairs(targets) do table.insert(report.sources,{path=value.path,bytes=#node.Source,sha256=value.entry.sha256,matches=true}) end
return report
