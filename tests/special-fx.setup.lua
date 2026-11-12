-- Isolated cosmetic lifecycle API double. The existing game mock remains unchanged.
-- Deterministic Roblox API double for server logic. It is not an engine,
-- network simulator, renderer, DataStore service, or a Studio playtest.
local function signal()
 local s={listeners={}}
 function s:Connect(f)
  local c={f=f,on=true};function c:Disconnect() self.on=false end
  table.insert(self.listeners,c);return c
 end
 function s:Fire(...) for _,c in ipairs(table.clone(self.listeners)) do if c.on then c.f(...) end end end
 return s
end
local realTime=0
local warnings={}
local function warn(...) table.insert(warnings,table.concat({...},' ')) end
local scheduled={}
local task={spawn=function(f,...) return f(...) end,defer=function(f,...) return f(...) end,wait=function() return 0 end}
function task.delay(delay,f,...) table.insert(scheduled,{at=realTime+delay,f=f,args={...}}) end
local function runScheduled()
 for i=#scheduled,1,-1 do local item=scheduled[i];if item.at<=realTime then table.remove(scheduled,i);item.f(table.unpack(item.args)) end end
end
local VM={}
VM.__index=function(v,k)
 if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
 elseif k=='Unit' then return v/v.Magnitude
 else return VM[k] end
end
VM.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},VM) end
VM.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},VM) end
VM.__unm=function(a) return a*-1 end
VM.__mul=function(a,b)
 if type(a)=='number' then a,b=b,a end
 if type(b)=='table' then return setmetatable({X=a.X*b.X,Y=a.Y*b.Y,Z=a.Z*b.Z},VM) end
 return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},VM)
end
VM.__div=function(a,b) return a*(1/b) end
function VM:Lerp(b,t) return self+(b-self)*t end
function VM:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function VM:Cross(b) return setmetatable({X=self.Y*b.Z-self.Z*b.Y,Y=self.Z*b.X-self.X*b.Z,Z=self.X*b.Y-self.Y*b.X},VM) end
local Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},VM) end}
Vector3.zero=Vector3.new();Vector3.one=Vector3.new(1,1,1);Vector3.yAxis=Vector3.new(0,1,0)
Vector3.xAxis=Vector3.new(1,0,0);Vector3.zAxis=Vector3.new(0,0,1)
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local CF={};CF.__index=CF
local CFrame={}
function CFrame.new(x,y,z)
 return setmetatable({Position=type(x)=='table' and x or Vector3.new(x,y,z),LookVector=Vector3.new(0,0,-1),RightVector=Vector3.new(1,0,0),UpVector=Vector3.yAxis},CF)
end
function CFrame.lookAt(x,y) local cf=CFrame.new(x);if (y-x).Magnitude>0 then cf.LookVector=(y-x).Unit end;return cf end
function CFrame.Angles(...) return CFrame.new() end
function CFrame.fromMatrix(position,right,up,back)
 local cf=CFrame.new(position);cf.RightVector=right;cf.UpVector=up;cf.LookVector=-back;return cf
end
CF.__mul=function(a,b)
 if getmetatable(b)==VM then return a.Position+b end
 return CFrame.new(a.Position+b.Position)
end
CF.__sub=function(a,b) return CFrame.new(a.Position-b) end
CF.__add=function(a,b) return CFrame.new(a.Position+b) end
function CF:Lerp(b,t) return CFrame.new(self.Position:Lerp(b.Position,t)) end
function CF:PointToWorldSpace(v) return self.Position+v end
function CF:PointToObjectSpace(v) return v-self.Position end
function CF:VectorToWorldSpace(v) return v end
function CF:ToObjectSpace(cf) return CFrame.new(cf.Position-self.Position) end
function CF:Inverse() return CFrame.new(-self.Position) end
CF.Rotation=CFrame.new()
local Color3={new=function(r,g,b) return setmetatable({X=r,Y=g,Z=b},VM) end}
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end,new=function(...) return {...} end}
local NumberSequence={new=function(x) return x end};local ColorSequence=NumberSequence
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local NumberRange=NumberSequence
local Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function(_,x) return x end});rawset(t,k,v);return v end})
local IM={};local IT={}
local Instance={}
local function descendantSignal(parent,name,child)
 while parent do local s=parent._p[name];if s then s:Fire(child) end;parent=parent._p.Parent end
end
IT.__index=function(i,k) return IM[k] or i._p[k] end
IT.__newindex=function(i,k,v)
 if k=='Parent' then
  local old=i._p.Parent
  if old==v then return end
  if old then
   descendantSignal(old,'DescendantRemoving',i)
   for n,c in ipairs(old._children) do if c==i then table.remove(old._children,n);break end end
   old.ChildRemoved:Fire(i)
  end
  i._p.Parent=v
  if v then table.insert(v._children,i);v.ChildAdded:Fire(i);descendantSignal(v,'DescendantAdded',i) end
 elseif k=='CFrame' then
  i._p.CFrame=v;i._p.Position=v.Position
 elseif k=='Position' then
  i._p.Position=v;i._p.CFrame=CFrame.new(v)
 else i._p[k]=v end
 local s=i._propertySignals[k];if s then s:Fire() end
end
function Instance.new(class)
 local i=setmetatable({_p={ClassName=class,Name=class,Position=Vector3.zero,CFrame=CFrame.new(),Size=Vector3.one,Color=Color3.new(1,1,1),Transparency=0,LocalTransparencyModifier=0,ChildAdded=signal(),ChildRemoved=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),AttributeChanged=signal(),Destroying=signal()},_children={},_attrs={},_attributeSignals={},_propertySignals={}},IT)
 if class=='Beam' then i._p.Width0=1;i._p.Width1=1 end
 if class=='RemoteEvent' then i.OnServerEvent=signal();i.OnClientEvent=signal() end
 if class=='ProximityPrompt' then i.Triggered=signal() end
 if class=='Sound' then i.Ended=signal() end
 return i
end
function IM:Play() self.Playing=true end
function IM:Stop() self.Playing=false end
function IM:Emit() end
function IM:IsA(c)
 return c==self.ClassName or (c=='BasePart' and (self.ClassName=='Part' or self.ClassName=='MeshPart' or self.ClassName=='UnionOperation' or self.ClassName=='SpawnLocation')) or (c=='LuaSourceContainer' and (self.ClassName=='Script' or self.ClassName=='LocalScript' or self.ClassName=='ModuleScript'))
end
function IM:GetChildren() return table.clone(self._children) end
function IM:GetDescendants()
 local a={};for _,c in ipairs(self._children) do table.insert(a,c);for _,d in ipairs(c:GetDescendants()) do table.insert(a,d) end end;return a
end
function IM:FindFirstChild(name,deep) for _,c in ipairs(deep and self:GetDescendants() or self:GetChildren()) do if c.Name==name then return c end end;return nil end
function IM:FindFirstChildWhichIsA(class,deep) for _,c in ipairs(deep and self:GetDescendants() or self:GetChildren()) do if c:IsA(class) then return c end end;return nil end
function IM:FindFirstChildOfClass(c) return self:FindFirstChildWhichIsA(c) end
function IM:WaitForChild(n) return self:FindFirstChild(n) end
function IM:SetAttribute(k,v)
 if self._attrs[k]==v then return end
 self._attrs[k]=v;self.AttributeChanged:Fire(k)
 if self._attributeSignals[k] then self._attributeSignals[k]:Fire() end
end
function IM:GetAttribute(k) return self._attrs[k] end
function IM:GetAttributes() return table.clone(self._attrs) end
function IM:GetAttributeChangedSignal(k) if not self._attributeSignals[k] then self._attributeSignals[k]=signal() end;return self._attributeSignals[k] end
function IM:GetPropertyChangedSignal(k) if not self._propertySignals[k] then self._propertySignals[k]=signal() end;return self._propertySignals[k] end
function IM:IsDescendantOf(root) local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
function IM:Destroy() self.Destroying:Fire();for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;self._destroyed=true end
function IM:GetPivot() return CFrame.new(self.PrimaryPart and self.PrimaryPart.Position or self.Position) end
function IM:PivotTo(cf)
 local delta=cf.Position-self:GetPivot().Position
 for _,p in ipairs(self:GetDescendants()) do if p:IsA('BasePart') then p.Position=p.Position+delta end end
 self.Position=cf.Position
end
function IM:Clone()
 local mapping={}
 local function copy(source)
  local target=Instance.new(source.ClassName);mapping[source]=target
  for k,v in pairs(source._p) do if k~='Parent' and k~='PrimaryPart' and type(v)~='function' and not (type(v)=='table' and v.listeners) then target[k]=v end end
  target._attrs=table.clone(source._attrs)
  for _,child in ipairs(source:GetChildren()) do copy(child).Parent=target end
  return target
 end
 local out=copy(self)
 for source,target in pairs(mapping) do if source.PrimaryPart then target.PrimaryPart=mapping[source.PrimaryPart] end end
 return out
end
function IM:FireClient(...) self.lastClientArgs={...} end
function IM:FireAllClients(...) self.lastAllClientArgs={...} end
function IM:Kick(message) self.kicked=message;self.Parent=nil end
local workspace=Instance.new('Workspace');workspace.Name='Workspace'
function workspace:GetServerTimeNow() return realTime end
function workspace:Raycast(...) return nil end
local heartbeat=signal()
local originalFire=heartbeat.Fire
function heartbeat:Fire(dt) runScheduled();originalFire(self,dt);runScheduled() end
local runService={Heartbeat=heartbeat,studio=true}
function runService:IsStudio() return self.studio end
local players={PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
function players:GetPlayers() return self.list end
local rs=Instance.new('ReplicatedStorage')
local soundService=Instance.new('SoundService')
local guidCount=0
local httpService={}
function httpService:GenerateGUID() guidCount=guidCount+1;return 'test-guid-'..guidCount end
local stores={}
local dataStoreService={}
function dataStoreService:GetDataStore(name)
 if not stores[name] then
  local store={data={},updates=0,fail=false}
  function store:UpdateAsync(key,callback)
   self.updates=self.updates+1;if self.fail then error('injected datastore outage') end
   local value=callback(self.data[key]);if value~=nil then self.data[key]=value end;return self.data[key]
  end
  stores[name]=store
 end
 return stores[name]
end
local game={JobId='test-server',PlaceId=123,closeCallbacks={}}
function game:BindToClose(callback) table.insert(self.closeCallbacks,callback) end
function game:GetService(n)
 if n=='SoundService' then return soundService elseif n=='Players' then return players elseif n=='ReplicatedStorage' then return rs elseif n=='RunService' then return runService elseif n=='DataStoreService' then return dataStoreService elseif n=='HttpService' then return httpService elseif n=='Debris' then return {AddItem=function(_,item,delay) task.delay(delay,function() item:Destroy() end) end} end
 error('Unmocked Roblox service '..n)
end
local RaycastParams={new=function() return {} end}
local Random={}
function Random.new() return {NextNumber=function(_,a,b) return (a or 0)+math.random()*((b or 1)-(a or 0)) end,NextInteger=function(_,a,b) return math.random(a,b) end} end
local function player(id)
 local p=Instance.new('Player');p.UserId=id;p.DisplayName='Tester'..id;p.CharacterAdded=signal();p.Parent=workspace
 local ch=Instance.new('Model');local hr=Instance.new('Part');hr.Name='HumanoidRootPart';hr.Parent=ch;ch.PrimaryPart=hr
 local h=Instance.new('Humanoid');h.Health=100;h.Parent=ch;p.Character=ch;ch.Parent=workspace
 return p
end
