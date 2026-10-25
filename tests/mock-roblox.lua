-- Minimal deterministic Roblox API double; not an engine or renderer.
local function signal()
 local s={listeners={}}
 function s:Connect(f) local c={f=f,on=true};function c:Disconnect() self.on=false end;table.insert(self.listeners,c);return c end
 function s:Fire(...) for _,c in ipairs(self.listeners) do if c.on then c.f(...) end end end
 return s
end
local VM={}
VM.__index=function(v,k) if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) elseif k=='Unit' then return v/v.Magnitude else return VM[k] end end
VM.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},VM) end
VM.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},VM) end
VM.__mul=function(a,b) if type(a)=='number' then a,b=b,a end;return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},VM) end
VM.__div=function(a,b) return a*(1/b) end
function VM:Lerp(b,t) return self+(b-self)*t end
local Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},VM) end};Vector3.zero=Vector3.new()
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local CF={};CF.__index=CF
local CFrame={}
function CFrame.new(x,y,z) return setmetatable({Position=type(x)=='table' and x or Vector3.new(x,y,z)},CF) end
function CFrame.lookAt(x,y) return CFrame.new(x) end
function CF:Lerp(b,t) return CFrame.new(self.Position:Lerp(b.Position,t)) end
local Color3={new=function(r,g,b) return setmetatable({X=r,Y=g,Z=b},VM) end}
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local NumberSequence={new=function(x) return x end};local ColorSequence=NumberSequence
local Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function(_,x) return x end});rawset(t,k,v);return v end})
local IM={};local IT={}
IT.__index=function(i,k) return IM[k] or i._p[k] end
IT.__newindex=function(i,k,v)
 if k=='Parent' then
  local old=i._p.Parent;if old then for n,c in ipairs(old._children) do if c==i then table.remove(old._children,n);break end end end
  i._p.Parent=v;if v then table.insert(v._children,i) end
 else i._p[k]=v end
end
local Instance={}
function Instance.new(class)
 local i=setmetatable({_p={ClassName=class,Name=class,Position=Vector3.zero,CFrame=CFrame.new(),Size=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Transparency=0},_children={},_attrs={}},IT)
 return i
end
function IM:Play() self.Playing=true end
function IM:IsA(c)
 return c==self.ClassName or (c=='BasePart' and (self.ClassName=='Part' or self.ClassName=='SpawnLocation')) or (c=='LuaSourceContainer' and (self.ClassName=='Script' or self.ClassName=='LocalScript' or self.ClassName=='ModuleScript'))
end
function IM:GetChildren() return table.clone(self._children) end
function IM:GetDescendants() local a={};for _,c in ipairs(self._children) do table.insert(a,c);for _,d in ipairs(c:GetDescendants()) do table.insert(a,d) end end;return a end
function IM:FindFirstChild(name,deep) for _,c in ipairs(deep and self:GetDescendants() or self:GetChildren()) do if c.Name==name then return c end end;return nil end
function IM:FindFirstChildWhichIsA(class,deep) for _,c in ipairs(deep and self:GetDescendants() or self:GetChildren()) do if c:IsA(class) then return c end end;return nil end
function IM:FindFirstChildOfClass(c) return self:FindFirstChildWhichIsA(c) end
function IM:WaitForChild(n) return self:FindFirstChild(n) end
function IM:SetAttribute(k,v) self._attrs[k]=v end
function IM:GetAttribute(k) return self._attrs[k] end
function IM:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;self._destroyed=true end
function IM:GetPivot() return CFrame.new(self.PrimaryPart and self.PrimaryPart.Position or self.Position) end
function IM:PivotTo(cf)
 local delta=cf.Position-self:GetPivot().Position
 for _,p in ipairs(self:GetDescendants()) do if p:IsA('BasePart') then p.Position=p.Position+delta;p.CFrame=CFrame.new(p.Position) end end
 self.Position=cf.Position;self.CFrame=cf
end
local workspace=Instance.new('Workspace');workspace.Name='Workspace'
local realTime=0
function workspace:GetServerTimeNow() return realTime end
function workspace:Raycast(...) return nil end
local heartbeat=signal();local players={PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
function players:GetPlayers() return self.list end
local rs=Instance.new('ReplicatedStorage')
local soundService=Instance.new('SoundService')
local game={}
function game:GetService(n) if n=='SoundService' then return soundService elseif n=='Players' then return players elseif n=='ReplicatedStorage' then return rs elseif n=='RunService' then return {Heartbeat=heartbeat} end;error(n) end
local RaycastParams={new=function() return {} end}
local task={spawn=function(f,...) f(...) end}
local function player(id)
 local p=Instance.new('Player');p.UserId=id;p.DisplayName='Tester'..id;p.CharacterAdded=signal();p.Parent=workspace
 local ch=Instance.new('Model');local hr=Instance.new('Part');hr.Name='HumanoidRootPart';hr.Parent=ch;ch.PrimaryPart=hr
 local h=Instance.new('Humanoid');h.Health=100;h.Parent=ch;p.Character=ch;ch.Parent=workspace
 return p
end
-- Attach RemoteEvent signal automatically.
local originalNew=Instance.new
function Instance.new(c) local i=originalNew(c);if c=='RemoteEvent' then i.OnServerEvent=signal() end;return i end
