-- Deterministic Roblox API double for executing the ACTUAL bundled server.
-- This is not an engine, renderer, network transport, collision solver or asset loader.
local function signal()
 local s={listeners={}}
 function s:Connect(f) local c={f=f,on=true};function c:Disconnect() self.on=false end;table.insert(self.listeners,c);return c end
 function s:Fire(...) for _,c in ipairs(table.clone(self.listeners)) do if c.on then c.f(...) end end end
 return s
end
local VM={}
VM.__index=function(v,k) if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) elseif k=='Unit' then return v/v.Magnitude else return VM[k] end end
VM.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},VM) end
VM.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},VM) end
VM.__unm=function(a) return setmetatable({X=-a.X,Y=-a.Y,Z=-a.Z},VM) end
VM.__mul=function(a,b) if type(a)=='number' then a,b=b,a end;if type(b)=='table' then return setmetatable({X=a.X*b.X,Y=a.Y*b.Y,Z=a.Z*b.Z},VM) end;return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},VM) end
VM.__div=function(a,b) return a*(1/b) end
function VM:Lerp(b,t)
 local value=self+(b-self)*t
 if self.R~=nil then value.R=value.X;value.G=value.Y;value.B=value.Z end
 return value
end
function VM:Cross(b) return setmetatable({X=self.Y*b.Z-self.Z*b.Y,Y=self.Z*b.X-self.X*b.Z,Z=self.X*b.Y-self.Y*b.X},VM) end
function VM:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
local Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},VM) end};Vector3.zero=Vector3.new();Vector3.one=Vector3.new(1,1,1)
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local CF={}
CF.__index=function(c,k) if k=='LookVector' then return Vector3.new(-math.sin(c.yaw),0,-math.cos(c.yaw)) elseif k=='Rotation' then return setmetatable({Position=Vector3.zero,yaw=c.yaw},CF) else return CF[k] end end
local CFrame={}
function CFrame.new(x,y,z) return setmetatable({Position=getmetatable(x)==VM and x or Vector3.new(x,y,z),yaw=0},CF) end
function CFrame.fromMatrix(position,_,_,back) local c=CFrame.new(position);c.yaw=math.atan2(back.X,back.Z);return c end
function CFrame.Angles(_,y,_) return setmetatable({Position=Vector3.zero,yaw=y or 0},CF) end
function CFrame.lookAt(x,y) local d=y-x;local c=CFrame.new(x);c.yaw=math.atan2(-d.X,-d.Z);return c end
function CF:PointToWorldSpace(v) return self.Position+Vector3.new(v.X*math.cos(self.yaw)+v.Z*math.sin(self.yaw),v.Y,-v.X*math.sin(self.yaw)+v.Z*math.cos(self.yaw)) end
function CF:PointToObjectSpace(v) local d=v-self.Position;return Vector3.new(d.X*math.cos(self.yaw)-d.Z*math.sin(self.yaw),d.Y,d.X*math.sin(self.yaw)+d.Z*math.cos(self.yaw)) end
function CF:Inverse() local c=CFrame.Angles(0,-self.yaw,0);c.Position=c:PointToWorldSpace(-self.Position);return c end
CF.__mul=function(a,b) local c=CFrame.new(a:PointToWorldSpace(b.Position));c.yaw=a.yaw+b.yaw;return c end
function CF:Lerp(b,t) local c=CFrame.new(self.Position:Lerp(b.Position,t));c.yaw=self.yaw+(b.yaw-self.yaw)*t;return c end
local Color3={new=function(r,g,b) return setmetatable({X=r,Y=g,Z=b,R=r,G=g,B=b},VM) end}
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local UDim={new=function(scale,offset) return {Scale=scale,Offset=offset} end}
local NumberSequence={new=function(x) return x end};local ColorSequence=NumberSequence
local Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function(_,x) return x end});rawset(t,k,v);return v end})
local IM={};local IT={}
IT.__index=function(i,k)
 if IM[k] then return IM[k] end
 if i._p[k]~=nil then return i._p[k] end
 for _,c in ipairs(i._children) do if c.Name==k then return c end end
 return nil
end
IT.__newindex=function(i,k,v)
 if k=='Parent' then
  local old=i._p.Parent;if old then for n,c in ipairs(old._children) do if c==i then table.remove(old._children,n);break end end end
  i._p.Parent=v;if v then table.insert(v._children,i) end
 elseif k=='Position' then i._p.Position=v;local cf=CFrame.new(v);cf.yaw=i._p.CFrame.yaw;i._p.CFrame=cf
 elseif k=='CFrame' then i._p.CFrame=v;i._p.Position=v.Position
 else i._p[k]=v end
end
local Instance={}
function Instance.new(class)
 local i=setmetatable({_p={ClassName=class,Name=class,Position=Vector3.zero,CFrame=CFrame.new(),Size=Vector3.one,Color=Color3.new(1,1,1),Transparency=0,CanQuery=true,CanCollide=true,Enabled=true},_children={},_attrs={},_signals={}},IT)
 if class=='RemoteEvent' then i.OnServerEvent=signal() end
 return i
end
function IM:Play() self.Playing=true end
function IM:IsA(c)
 return c==self.ClassName or (c=='BasePart' and (self.ClassName=='Part' or self.ClassName=='SpawnLocation' or self.ClassName=='MeshPart' or self.ClassName=='UnionOperation' or self.ClassName=='WedgePart')) or (c=='LuaSourceContainer' and (self.ClassName=='Script' or self.ClassName=='LocalScript' or self.ClassName=='ModuleScript'))
end
function IM:GetChildren() return table.clone(self._children) end
function IM:GetDescendants() local a={};for _,c in ipairs(self._children) do table.insert(a,c);for _,d in ipairs(c:GetDescendants()) do table.insert(a,d) end end;return a end
function IM:FindFirstChild(name,deep) for _,c in ipairs(deep and self:GetDescendants() or self:GetChildren()) do if c.Name==name then return c end end;return nil end
function IM:FindFirstChildWhichIsA(class,deep) for _,c in ipairs(deep and self:GetDescendants() or self:GetChildren()) do if c:IsA(class) then return c end end;return nil end
function IM:FindFirstChildOfClass(c) return self:FindFirstChildWhichIsA(c) end
function IM:WaitForChild(n) return self:FindFirstChild(n) end
function IM:SetAttribute(k,v) self._attrs[k]=v;if self._signals[k] then self._signals[k]:Fire() end end
function IM:GetAttributes() return table.clone(self._attrs) end
function IM:GetAttribute(k) return self._attrs[k] end
function IM:GetAttributeChangedSignal(k) self._signals[k]=self._signals[k] or signal();return self._signals[k] end
function IM:IsDescendantOf(other) local p=self.Parent;while p do if p==other then return true end;p=p.Parent end;return false end
function IM:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;self._destroyed=true end
function IM:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self.CFrame end
function IM:PivotTo(cf)
 local delta=cf*self:GetPivot():Inverse()
 for _,p in ipairs(self:GetDescendants()) do if p:IsA('BasePart') then p.CFrame=delta*p.CFrame end end
 self.CFrame=cf
end
function IM:Clone()
 local mapping={}
 local function create(old) local n=Instance.new(old.ClassName);mapping[old]=n;for _,c in ipairs(old:GetChildren()) do local nc=create(c);nc.Parent=n end;return n end
 local result=create(self)
 local function value(v) if mapping[v] then return mapping[v] end;if type(v)=='table' and not getmetatable(v) then local t={};for k,x in pairs(v) do t[k]=value(x) end;return t end;return v end
 for old,n in pairs(mapping) do
  for k,v in pairs(old._p) do if k~='Parent' then n._p[k]=value(v) end end
  for k,v in pairs(old._attrs) do n._attrs[k]=value(v) end
 end
 return result
end
local workspace=Instance.new('Workspace');workspace.Name='Workspace'
local realTime=1000
local os={time=function() return math.floor(realTime) end,clock=function() return realTime end}
function workspace:GetServerTimeNow() return realTime end
function workspace:Raycast(...) return nil end
local heartbeat=signal();local players={PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
function players:GetPlayers() return self.list end
local rs=Instance.new('ReplicatedStorage');local serverStorage=Instance.new('ServerStorage');local soundService=Instance.new('SoundService');local lighting=Instance.new('Lighting')
local guidCounter=0;local jsonValues={};local http={}
local function json(value)
 if value==nil then return 'null' end
 if type(value)=='boolean' or type(value)=='number' then return tostring(value) end
 if type(value)=='string' then return string.format('%q',value) end
 local values={};local array=#value>0
 if array then for _,v in ipairs(value) do table.insert(values,json(v)) end;return '['..table.concat(values,',')..']' end
 local keys={};for k in pairs(value) do table.insert(keys,k) end;table.sort(keys)
 for _,k in ipairs(keys) do table.insert(values,json(tostring(k))..':'..json(value[k])) end
 return '{'..table.concat(values,',')..'}'
end
local function deep(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=deep(x) end;return o end
function http:GenerateGUID(_) guidCounter=guidCounter+1;return 'mock-guid-'..guidCounter end
function http:JSONEncode(v) local encoded=json(v);jsonValues[encoded]=deep(v);return encoded end
function http:JSONDecode(s) return deep(assert(jsonValues[s],'unknown mock JSON')) end
local runtimeStore={values={},failBefore=0,failAfter=0,hook=nil}
function runtimeStore:UpdateAsync(k,fn)
 if self.failBefore>0 then self.failBefore=self.failBefore-1;error('mock datastore failure before commit') end
 if self.hook then local hook=self.hook;self.hook=nil;hook() end
 local value=fn(deep(self.values[k]));if value~=nil then self.values[k]=deep(value) end
 if self.failAfter>0 then self.failAfter=self.failAfter-1;error('mock datastore response lost after commit') end
 return deep(value)
end
local runService={Heartbeat=heartbeat}
-- Test the production adapter while still avoiding live APIs; preview selection is tested separately.
function runService:IsStudio() return false end
local shutdown
local game={JobId='api-double-job',GameId=100}
function game:BindToClose(fn) shutdown=fn end
function game:GetService(n)
 if n=='Lighting' then return lighting elseif n=='SoundService' then return soundService elseif n=='Players' then return players elseif n=='ReplicatedStorage' then return rs elseif n=='ServerStorage' then return serverStorage elseif n=='RunService' then return runService elseif n=='HttpService' then return http
 elseif n=='DataStoreService' then return {GetDataStore=function() return runtimeStore end}
 elseif n=='Debris' then return {AddItem=function() end} end
 error('Missing mock service '..n)
end
local RaycastParams={new=function() return {} end}
local Random={}
function Random.new(initial)
 local r={state=initial or 4721}
 function r:NextNumber(a,b) self.state=(self.state*16807)%2147483647;local x=self.state/2147483647;if a==nil then return x end;return a+x*((b or 1)-a) end
 function r:NextInteger(a,b) return math.floor(self:NextNumber(a,b+1)) end
 return r
end
local task={spawn=function(f,...) return f(...) end,defer=function(f,...) return f(...) end,wait=function(dt) realTime=realTime+(dt or .03);return dt or .03 end}
local function player(id)
 local p=Instance.new('Player');p.UserId=id;p.DisplayName='Tester'..id;p.Name='Tester'..id;p.CharacterAdded=signal();p.Parent=workspace
 local ch=Instance.new('Model');local hr=Instance.new('Part');hr.Name='HumanoidRootPart';hr.Parent=ch;ch.PrimaryPart=hr
 local h=Instance.new('Humanoid');h.Health=100;h.Parent=ch;p.Character=ch;ch.Parent=workspace
 return p
end
-- Synthetic fixture asserts asset-binding paths, NOT the real source meshes' rendered appearance.
local function fixturePart(parent,name,pos,size,class)
 local p=Instance.new(class or 'Part');p.Name=name;p.Position=pos;p.Size=size or Vector3.one;p.Parent=parent;return p
end
fixturePart(workspace,'SpawnLocation',Vector3.new(-56,.5,-11),Vector3.new(6,1,6),'SpawnLocation')
fixturePart(workspace,'Baseplate',Vector3.new(0,-1,0),Vector3.new(512,2,512))
fixturePart(workspace,'Converter',Vector3.new(-50,1,-6),Vector3.new(6,2,6))
local harborTemplate=Instance.new('Folder');harborTemplate.Name='AlabasterHarborLighting';harborTemplate.Parent=serverStorage
for _,v in ipairs({{'Sky','Sunless Blue Sky'},{'Atmosphere','Atmosphere'},{'BloomEffect','Bloom'},{'ColorCorrectionEffect','ColorCorrection'},{'DepthOfFieldEffect','DepthOfField'},{'SunRaysEffect','SunRays'},{'BlurEffect','Blur'}}) do local n=Instance.new(v[1]);n.Name=v[2];n.Parent=harborTemplate end
local nativeTerrain=Instance.new('Terrain');nativeTerrain.Parent=workspace
local Region3={new=function(low,high) return {low=low,high=high} end}
function nativeTerrain:ReadVoxels(region,resolution)
 local m,o={},{}
 local size=(region.high-region.low)/resolution
 for x=1,size.X do m[x]={};o[x]={};for y=1,size.Y do m[x][y]={};o[x][y]={};for z=1,size.Z do m[x][y][z]=Enum.Material.Air;o[x][y][z]=0 end end end
 return m,o
end
function nativeTerrain:WriteVoxels(_,_,_,_) end
function nativeTerrain:FillBlock(_,_,_) end
function nativeTerrain:SetMaterialColor(_,_) end
local originalPatches=Instance.new('Folder');originalPatches.Name='Patches';originalPatches.Parent=workspace
fixturePart(originalPatches,'rubyPatch',Vector3.new(-89,12,55),Vector3.new(30,2,30))
fixturePart(originalPatches,'cobaltPatch',Vector3.new(-49,.5,-85),Vector3.new(34,2,34))
local construct=Instance.new('Model');construct.Name='construct';construct.Parent=workspace
local base=fixturePart(construct,'basepart',Vector3.new(0,0,0),Vector3.new(8,1,8));construct.PrimaryPart=base
local segmentIds={bottemseg='14477420875',lowerseg='14477422793',upperseg='14477425917',topseg='14477427275',eye='14477430698',eyecase='14477428635',spawnEye='14477430698'}
local segmentY=0
for _,name in ipairs({'bottemseg','lowerseg','upperseg','topseg','eye','eyecase','spawnEye'}) do segmentY=segmentY+1;local mesh=fixturePart(construct,name,Vector3.new(0,segmentY,0),Vector3.one,'MeshPart');mesh.MeshId='rbxassetid://'..segmentIds[name] end
local anim=Instance.new('AnimationController');anim.Parent=construct;local saves=Instance.new('Model');saves.Name='AnimSaves';saves.Parent=construct
local originalDrone=Instance.new('Model');originalDrone.Name='Drone';originalDrone.Parent=rs
local originalHull=fixturePart(originalDrone,'Mesh',Vector3.zero,Vector3.new(2,2,2),'UnionOperation');originalDrone.PrimaryPart=originalHull
fixturePart(originalDrone,'Emmiter',Vector3.new(0,-1,0),Vector3.new(.2,.2,.2))
local originalCrystal=Instance.new('Model');originalCrystal.Name='Crystal';originalCrystal.Parent=rs
fixturePart(originalCrystal,'Mesh',Vector3.zero,Vector3.one,'UnionOperation')
