-- Event and lifetime boundaries for production state/visual code; not a renderer.
CF.__add=function(a,b) local c=CFrame.new(a.Position+b);c.yaw=a.yaw;return c end
local originalNew=Instance.new
Instance.new=function(class)
 local node=originalNew(class)
 node.ChildAdded=signal();node.ChildRemoved=signal();node.Destroying=node.Destroying or signal()
 return node
end
workspace.ChildAdded=signal();workspace.ChildRemoved=signal()
local originalIndex=IT.__newindex
IT.__newindex=function(node,key,value)
 local old=key=='Parent' and node.Parent or nil
 originalIndex(node,key,value)
 if key=='Parent' then
  if old and old.ChildRemoved then old.ChildRemoved:Fire(node) end
  if value and value.ChildAdded then value.ChildAdded:Fire(node) end
 end
end
local originalDestroy=IM.Destroy
function IM:Destroy() if self.Destroying then self.Destroying:Fire() end;originalDestroy(self) end
