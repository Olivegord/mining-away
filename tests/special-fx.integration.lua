-- Appended to the current DroneFX source with an isolated API double; not rendering QA.
local Color3={new=function(r,g,b) return setmetatable({X=r,Y=g,Z=b},VM) end}
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end,new=function(...) return {...} end}
local NumberSequence={new=function(x) return x end};local ColorSequence=NumberSequence
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

local DroneFX=(function()
-- Synced, client-only mining choreography. Damage and payout stay on the server.
-- Each effect owns its geometry; interrupted jobs never leave hidden rocks behind.
local FX = {}
local TAU = math.pi * 2
local MAX_PARTS, MAX_EFFECT_PARTS = 360, 48
local TAIL = 1.15
local supported = {Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local cyan = Color3.fromRGB(130,239,255)
local gold = Color3.fromRGB(255,211,83)
local purple = Color3.fromRGB(179,105,255)
local ice = Color3.fromRGB(169,229,255)
local hot = Color3.fromRGB(255,140,48)
local function clamp(x) return math.clamp(x,0,1) end
local function smooth(x) x=clamp(x);return x*x*(3-2*x) end
local function safeSize(v)
 return Vector3.new(math.max(.025,v.X),math.max(.025,v.Y),math.max(.025,v.Z))
end

local function part(e,name,size,color,material,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Size=safeSize(size);p.Color=color;p.Material=material or Enum.Material.Neon
 if shape then p.Shape=shape end
 p.Parent=e.folder;e.parts[#e.parts+1]=p;e.owner.count=e.owner.count+1
 return p
end
local function fragmentSet(e,n,color,material)
 local set={}
 for i=1,n do
  local p=part(e,'Fragment',Vector3.one,color or e.color,material or Enum.Material.SmoothPlastic)
  p.Transparency=1;set[i]=p
 end
 return set
end
local function makeRing(e,n,color,width)
 local ring={parts={},width=width or .065}
 for i=1,n do ring.parts[i]=part(e,'EnergyArc',Vector3.one,color) end
 return ring
end
local function showRing(ring,cf,radius,alpha)
 local n=#ring.parts
 for i,p in ipairs(ring.parts) do
  local a,b=(i-1)*TAU/n,i*TAU/n
  local from=cf:PointToWorldSpace(Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius))
  local to=cf:PointToWorldSpace(Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius))
  p.Size=Vector3.new(ring.width,ring.width,math.max(.025,(to-from).Magnitude))
  p.CFrame=CFrame.lookAt((from+to)*.5,to);p.Transparency=alpha or 0
 end
end
local function line(p,a,b,width,alpha)
 if (b-a).Magnitude<.001 then p.Transparency=1;return end
 p.Size=Vector3.new(width,width,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)*.5,b);p.Transparency=alpha or 0
end
local function hideParts(parts)
 for _,p in ipairs(parts) do p.Transparency=1 end
end
local function proxy(e)
 -- The authoritative collider remains hidden by Client.lua. Clone the current
 -- local rock so authored silhouette, grounded pose and prior fractures agree.
 local p=e.view:Clone()
 for _,v in ipairs(p:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Highlight') or v:IsA('Sound') or v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Trail') then v:Destroy() end
 end
 p.Name='VisualRock';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.LocalTransparencyModifier=0;p.Transparency=0;p.Parent=e.folder
 e.parts[#e.parts+1]=p;e.owner.count=e.owner.count+1
 return p
end

local function build(e)
 e.rock=proxy(e)
 if e.kind=='Bubbler' then
  e.bubbles={}
  e.glints={}
  for i=1,5 do
   local p=part(e,'GlassBubble',Vector3.one,cyan,Enum.Material.Glass,Enum.PartType.Ball)
   p.Transparency=.43;p.Reflectance=.24;e.bubbles[i]=p
   e.glints[i]=part(e,'BubbleGlint',Vector3.one,Color3.new(1,1,1),Enum.Material.Neon,Enum.PartType.Ball)
  end
  e.bubbleRim=makeRing(e,12,cyan,.045)
  e.fragments=fragmentSet(e,16,gold,Enum.Material.Neon)
 elseif e.kind=='Halver' then
  e.fragments=fragmentSet(e,32)
  e.ring=makeRing(e,12,cyan,.045)
 elseif e.kind=='Gridcutter' then
  e.fragments=fragmentSet(e,27)
  e.grid={}
  for i=1,8 do e.grid[i]=part(e,'CutLine',Vector3.one,Color3.fromRGB(255,92,109)) end
  e.scanner=part(e,'ScanningLaser',Vector3.one,Color3.new(1,1,1))
 elseif e.kind=='Singularity' then
  e.hole=part(e,'EventHorizon',Vector3.one,Color3.fromRGB(5,3,12),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
  e.ring=makeRing(e,14,purple,.13)
  e.fragments=fragmentSet(e,16,purple,Enum.Material.Neon)
 elseif e.kind=='Starforge' then
  e.sun=part(e,'MiniatureSun',Vector3.one,gold,Enum.Material.Neon,Enum.PartType.Ball)
  e.corona=part(e,'Corona',Vector3.one,hot,Enum.Material.Neon,Enum.PartType.Ball);e.corona.Transparency=.76
  e.ring=makeRing(e,12,hot,.07)
  e.fragments=fragmentSet(e,18,hot,Enum.Material.Neon)
 elseif e.kind=='Frostbite' then
  e.shell=part(e,'IceCasing',e.size*1.12,ice,Enum.Material.Glass);e.shell.Transparency=.65;e.shell.Reflectance=.2
  e.ring=makeRing(e,12,ice,.08)
  e.fragments=fragmentSet(e,24,ice,Enum.Material.Glass)
 elseif e.kind=='Resonator' then
  e.rings={makeRing(e,12,cyan,.065),makeRing(e,12,purple,.065),makeRing(e,12,cyan,.065)}
  e.fragments=fragmentSet(e,10)
 end
end

local function bubblePose(e,t)
 local r=e.radius
 local lift=smooth((t-.28)/.34)*7
 local fall=smooth((t-.7)/.3)*9
 local center=e.center+Vector3.new(0,lift-fall,0)
 local absorb=smooth((t-.18)/.2)
 e.rock.CFrame=e.cf+Vector3.new(0,lift-fall,0)
 e.rock.Size=safeSize(e.size*(1-absorb*.77));e.rock.Transparency=clamp((t-.55)*2)
 for i,p in ipairs(e.bubbles) do
  local a=i*TAU/5+t*4
  local converge=1-smooth(t/.32)
  local offset=i==1 and Vector3.zero or Vector3.new(math.cos(a),math.sin(a*1.7)*.5,math.sin(a))*(r*.55+converge*3)
  p.Position=center+offset+Vector3.new(0,converge*(i+2),0)
  local diameter=i==1 and r*2.65 or r*.8
  p.Size=Vector3.one*math.max(.05,diameter*smooth(t/.17));p.Transparency=.43
  local glint=e.glints[i];glint.Size=Vector3.one*math.max(.025,diameter*.075)
  glint.Position=p.Position+Vector3.new(-diameter*.23,diameter*.3,-diameter*.2);glint.Transparency=.12
 end
 local view=workspace.CurrentCamera
 local rimCF=CFrame.new(center)
 if view and (view.CFrame.Position-center).Magnitude>.001 then rimCF=CFrame.lookAt(center,view.CFrame.Position)*CFrame.Angles(math.pi/2,0,0) end
 showRing(e.bubbleRim,rimCF,math.max(.025,r*1.325*smooth(t/.17)),.25)
end
local function halverPose(e,t)
 local split=clamp((t-.12)/.5)
 local levels=math.min(5,math.floor(split*5)+1)
 local n=2^levels
 local stretch=math.sin((split*5)%1*math.pi)*.35
 local grind=smooth((t-.6)/.28)
 e.rock.Transparency=t<.12 and 0 or 1
 for i,p in ipairs(e.fragments) do
  if i<=n and t>=.12 then
   local angle=(i-1)*TAU/n+t*t*48
   -- Alternate X/Y/Z cuts: 2 halves, 4 quarters, 8 eighths, then 16/32 chips.
   local cell=e.size;local offset=Vector3.zero
   for level=1,levels do
    local sign=math.floor((i-1)/2^(level-1))%2==0 and -1 or 1
    local axis=(level-1)%3
    if axis==0 then cell=Vector3.new(cell.X*.5,cell.Y,cell.Z);offset=offset+Vector3.new(sign*cell.X*.5,0,0)
    elseif axis==1 then cell=Vector3.new(cell.X,cell.Y*.5,cell.Z);offset=offset+Vector3.new(0,sign*cell.Y*.5,0)
    else cell=Vector3.new(cell.X,cell.Y,cell.Z*.5);offset=offset+Vector3.new(0,0,sign*cell.Z*.5) end
   end
   local splitPos=e.center+e.cf:VectorToWorldSpace(offset)*(1.08+stretch)+Vector3.new(0,1.2+stretch*2,0)
   local ringPos=e.center+Vector3.new(math.cos(angle)*e.radius*1.6,2+math.sin(angle*3)*.2,math.sin(angle)*e.radius*1.6)
   p.Position=splitPos:Lerp(ringPos,grind)
   local shrink=1-smooth((t-.84)/.16)*.87
   p.Size=safeSize(cell*(.94+stretch*.35)*shrink)
   p.CFrame=CFrame.new(p.Position)*e.cf.Rotation*CFrame.Angles(t*grind*30+i*grind,t*grind*20,stretch)
   p.Transparency=clamp((t-.94)*8)
  else p.Transparency=1 end
 end
 showRing(e.ring,CFrame.new(e.center+Vector3.new(0,2,0)),e.radius*1.7,t<.58 and 1 or .45)
end
local function gridPose(e,t)
 local r=e.radius*1.05
 local scan=clamp(t/.7)
 e.rock.CFrame=e.cf;e.rock.Size=e.size;e.rock.Transparency=t<.82 and 0 or 1
 for i,p in ipairs(e.grid) do
  local axis=i>4;local index=(i-1)%4
  local coordinate=(index/3-.5)*r*1.5
  local from=axis and Vector3.new(-r,r,coordinate) or Vector3.new(coordinate,r,-r)
  local to=axis and Vector3.new(r,r,coordinate) or Vector3.new(coordinate,r,r)
  local visible=scan>=i/9
  line(p,e.center+from,e.center+to,.045,visible and .12 or 1)
 end
 local scanPos=e.center+Vector3.new(-r+scan*r*2,r+.08,0)
 line(e.scanner,scanPos+Vector3.new(0,0,-r),scanPos+Vector3.new(0,0,r),.1,t<.75 and .05 or 1)
 -- The final short impulse exposes a real 3 × 3 × 3 cube lattice.
 for i,p in ipairs(e.fragments) do
  local q=i-1;local x=q%3-1;local y=math.floor(q/3)%3-1;local z=math.floor(q/9)-1
  local cell=e.size/3
  local offset=Vector3.new(x*cell.X,y*cell.Y,z*cell.Z)
  local spill=clamp((t-.82)/.18)
  p.Size=safeSize(cell*.91)
  p.CFrame=CFrame.new(e.center+offset+Vector3.new(x*spill*.9,spill*.55,z*spill*.9))*CFrame.Angles(z*spill*.3,x*spill*.3,0)
  p.Transparency=t>=.82 and 0 or 1
 end
end
local function singularityPose(e,t)
 local center=e.center+Vector3.new(0,e.radius*.4+1,0)
 local grow=smooth(t/.2);local absorb=smooth((t-.12)/.78)
 local diameter=e.radius*.82*grow
 e.hole.Size=Vector3.one*math.max(.05,diameter);e.hole.Position=center
 showRing(e.ring,CFrame.new(center)*CFrame.Angles(.35,0,t*4),math.max(.05,diameter*.9),.05)
 e.rock.Size=safeSize(e.size*(1-absorb*.97))
 e.rock.CFrame=CFrame.new(e.center:Lerp(center,absorb))*e.cf.Rotation*CFrame.Angles(t*t*5,absorb*12,0)
 e.rock.Transparency=clamp((t-.8)*5)
 for i,p in ipairs(e.fragments) do
  local phase=(t*1.1+i/16)%1
  local radius=e.radius*(.2+(1-phase)*2.2)
  local a=i*2.4+t*15+phase*5
  p.Position=center+Vector3.new(math.cos(a)*radius,math.sin(a*2)*radius*.25,math.sin(a)*radius)
  p.Size=Vector3.one*(.04+(1-phase)*.12);p.Transparency=1-grow*(1-phase)
 end
end
local function starforgePose(e,t)
 local center=e.center+Vector3.new(0,e.radius+3,0)
 local heat=smooth((t-.12)/.75)
 local diameter=e.radius*(.5+.5*smooth(t/.2))
 e.sun.Position=center;e.sun.Size=Vector3.one*diameter
 e.corona.Position=center;e.corona.Size=e.sun.Size*(1.45+math.sin(t*48)*.04)
 showRing(e.ring,CFrame.new(center)*CFrame.Angles(.45,t*4,.3),diameter*.95,.22)
 e.rock.Color=e.color:Lerp(hot,heat);e.rock.Material=t>.45 and Enum.Material.Neon or e.material
 e.rock.Size=safeSize(e.size*Vector3.new(1+heat*.22,1-heat*.6,1+heat*.22))
 e.rock.CFrame=e.cf+Vector3.new(0,-heat*e.size.Y*.24,0)
 for i,p in ipairs(e.fragments) do
  local a=i*2.4;local phase=(t*2+i/18)%1
  p.Position=e.center+Vector3.new(math.cos(a)*e.radius*(.7+phase),-e.radius*.3-phase*phase*2,math.sin(a)*e.radius*(.7+phase))
  p.Size=Vector3.one*(.15+.23*(1-phase));p.Transparency=t<.35 and 1 or phase*.8
 end
end
local function frostbitePose(e,t)
 local freeze=smooth(t/.6);local shiver=math.sin(t*150)*smooth((t-.68)/.25)*.035
 e.rock.CFrame=e.cf+Vector3.new(shiver,0,-shiver);e.rock.Color=e.color:Lerp(ice,freeze)
 e.shell.CFrame=e.rock.CFrame;e.shell.Size=e.size*(1.02+freeze*.14);e.shell.Transparency=1-freeze*.55
 local pulse=((t-.7)*5)%1
 showRing(e.ring,CFrame.new(e.center)*CFrame.Angles(math.pi/2,0,0),e.radius*(1+pulse*1.4),t<.7 and 1 or pulse)
 hideParts(e.fragments)
end
local function resonatorPose(e,t)
 local pulse=(t*5)%1
 local shake=smooth((t-.25)/.7)*.07
 e.rock.CFrame=e.cf*CFrame.Angles(math.sin(t*125)*shake,0,math.cos(t*113)*shake)
 e.rock.Size=safeSize(e.size*Vector3.new(1+math.sin(t*80)*shake,1-math.sin(t*80)*shake,1))
 for i,ring in ipairs(e.rings) do
  local phase=(pulse+(i-1)/3)%1
  local cf=CFrame.new(e.center+Vector3.new(0,(i-2)*e.radius*.5,0))*CFrame.Angles(i==2 and math.pi/2 or .15,0,t*(i-2)*2)
  showRing(ring,cf,e.radius*(1.15+phase*.65),.15+phase*.7)
 end
 hideParts(e.fragments)
end
local poses={Bubbler=bubblePose,Halver=halverPose,Gridcutter=gridPose,Singularity=singularityPose,Starforge=starforgePose,Frostbite=frostbitePose,Resonator=resonatorPose}

local function finishPose(e,age)
 if not e.finished then
  e.finished=true;e.burstOrigin=e.kind=='Bubbler' and e.center+Vector3.new(0,-2,0) or e.center
 end
 local fade=clamp(age/TAIL)
 for _,p in ipairs(e.parts) do p.Transparency=1 end
 local fragments=e.fragments or {}
 for i,p in ipairs(fragments) do
  local a=i*2.399963
  local force=e.kind=='Gridcutter' and 3.2 or e.kind=='Singularity' and 1.3 or 4.4
  local velocity=Vector3.new(math.cos(a)*force,2+(i%4),math.sin(a)*force)
  local start=e.burstOrigin
  if e.kind=='Gridcutter' then
   local q=i-1;local x=q%3-1;local y=math.floor(q/3)%3-1;local z=math.floor(q/9)-1
   start=e.center+Vector3.new(x*(e.size.X/3+.9),y*e.size.Y/3+.55,z*(e.size.Z/3+.9))
  end
  p.CFrame=CFrame.new(start+velocity*age+Vector3.new(0,-6*age*age,0))*CFrame.Angles(i+age*4,age*6,i*.5)
  local size=e.kind=='Gridcutter' and e.size/3*.85 or Vector3.one*(e.kind=='Bubbler' and .34 or .23)
  p.Size=safeSize(size*(1-fade*.8));p.Transparency=fade
  if e.kind=='Bubbler' then p.Shape=Enum.PartType.Cylinder;p.Size=Vector3.new(.1, .43, .43)*(1-fade*.8);p.Color=gold end
 end
end

function FX.new(world,options)
 options=options or {}
 local self={world=world,tracked={},dirty={},active={},count=0,connections={},destroyed=false}
 local folder=Instance.new('Folder');folder.Name='MiningAwayDroneFX';folder.Parent=workspace;self.folder=folder
 local function freeGeometry(e)
  self.count=math.max(0,self.count-#e.parts);e.parts={}
  if e.folder then e.folder:Destroy();e.folder=nil end
 end
 local function remove(v)
  local e=self.active[v]
  if e then
   if e.view.Parent then e.view.LocalTransparencyModifier=e.originalTransparency end
   freeGeometry(e);self.active[v]=nil
  end
 end
 local function observe(v)
  if not v:IsA('BasePart') or self.tracked[v] then return end
  self.tracked[v]=v.AttributeChanged:Connect(function() self.dirty[v]=true end)
  self.dirty[v]=true
 end
 self.connections[#self.connections+1]=world.DescendantAdded:Connect(observe)
 self.connections[#self.connections+1]=world.DescendantRemoving:Connect(function(v)
  remove(v)
  if self.tracked[v] then self.tracked[v]:Disconnect();self.tracked[v]=nil end
  self.dirty[v]=nil
 end)
 for _,v in ipairs(world:GetDescendants()) do observe(v) end
 function self:isActive(source) return self.active[source]~=nil end
 function self:step(now,_dt)
  if self.destroyed then return end
  for v in pairs(self.dirty) do
   self.dirty[v]=nil
   if v.Parent and v:GetAttribute('ResourceId') then
    local serial=v:GetAttribute('EffectSerial') or 0
    local kind=v:GetAttribute('EffectType')
    local start=v:GetAttribute('EffectStartedAt')
    local duration=v:GetAttribute('EffectDuration')
    local cancelled=(v:GetAttribute('EffectCancelledSerial') or 0)>=serial
    local e=self.active[v]
    if e and (e.serial~=serial or e.start~=start or e.kind~=kind or cancelled) then remove(v);e=nil end
    if not e and serial>0 and not cancelled and supported[kind] and type(start)=='number' and type(duration)=='number' and duration>0 then
     local done=v:GetAttribute('EffectDoneAt') or 0
     if done>0 and done>=start and now-done>TAIL then
      -- A late joiner does not replay old payouts.
     elseif self.count+MAX_EFFECT_PARTS<=MAX_PARTS then
      local view=options.resolve and options.resolve(v) or (not options.resolve and v or nil)
      if view and view.Parent and view.Transparency<.99 then
       local full=v:GetAttribute('FullSize') or v.Size
       if type(full)=='number' then full=Vector3.one*full end
       local size=view.Size.Magnitude>.05 and view.Size or full
       local effectFolder=Instance.new('Folder');effectFolder.Name=kind..'_'..serial;effectFolder.Parent=self.folder
       e={owner=self,resource=v,view=view,kind=kind,serial=serial,start=start,duration=duration,folder=effectFolder,parts={},center=view.Position,cf=view.CFrame,size=size,color=view.Color,material=view.Material,radius=math.max(size.X,size.Y,size.Z)*.5,originalTransparency=view.LocalTransparencyModifier}
       build(e);self.active[v]=e;view.LocalTransparencyModifier=1
      elseif done<=0 then self.dirty[v]=true end
     else self.dirty[v]=true end
    end
   end
  end
  for v,e in pairs(self.active) do
   if not v.Parent or not e.view.Parent or not v:GetAttribute('ResourceId') or (v:GetAttribute('EffectCancelledSerial') or 0)>=e.serial then remove(v)
   else
    -- Run after the ordinary growth/fracture renderer. Hide its view without
    -- changing the hidden server collider or suppressing existing crystal audio.
    e.view.LocalTransparencyModifier=1
    local done=v:GetAttribute('EffectDoneAt') or 0
    if done>0 and done>=e.start then
     local age=math.max(0,now-done)
     if age>TAIL then
      -- The ordinary renderer can still be draining a long fracture queue.
      -- Free every effect Part now, but conceal that retired rock until its
      -- authoritative source disappears, rather than flashing it back in.
      if not e.retired then freeGeometry(e);e.retired=true end
     elseif not e.retired then finishPose(e,age) end
    else
     local pausedAt=v:GetAttribute('EffectPausedAt') or 0
     local visualNow=pausedAt>0 and math.min(now,pausedAt) or now
     local t=math.min(.985,clamp((visualNow-e.start)/e.duration))
     poses[e.kind](e,t)
     -- If the server cancels without retiring a resource, the next attribute pass cleans it.
     -- A small timeout also bounds stale effects after streaming/network interruptions.
     if visualNow-e.start>e.duration+3 then remove(v) end
    end
   end
  end
 end
 function self:destroy()
  if self.destroyed then return end;self.destroyed=true
  for v in pairs(self.active) do remove(v) end
  for _,connection in pairs(self.tracked) do connection:Disconnect() end
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  self.folder:Destroy()
 end
 return self
end
return FX

end)()

CF.Rotation=CFrame.new()
local world=Instance.new('Folder');world.Parent=workspace
local visibleRoot=Instance.new('Folder');visibleRoot.Parent=workspace
local views={};local ctrl=DroneFX.new(world,{resolve=function(source) return views[source] end})
local durations={Bubbler=4.2,Halver=8,Gridcutter=5,Singularity=2.4,Starforge=5,Frostbite=5.5,Resonator=4.8}
local checks=0
local function resource(kind,start,noView)
 local p=Instance.new('Part');p.Size=Vector3.new(4,5,3);p.Position=Vector3.new(0,4,0);p.Material=Enum.Material.Slate;p.LocalTransparencyModifier=1;p.Parent=world
 p:SetAttribute('ResourceId','test');p:SetAttribute('FullSize',p.Size);p:SetAttribute('EffectType',kind);p:SetAttribute('EffectStartedAt',start);p:SetAttribute('EffectDuration',durations[kind]);p:SetAttribute('EffectSerial',1)
 if not noView then local view=p:Clone();view.Position=Vector3.new(10,4,0);view.LocalTransparencyModifier=.2;view.Parent=visibleRoot;views[p]=view end
 return p
end
local now=20
for kind,duration in pairs(durations) do
 local p=resource(kind,now);local view=views[p]
 for j=0,100 do
  ctrl:step(now+duration*j/100,.02)
  assert(ctrl.count>0 and ctrl.count<=48,kind..' bounded geometry')
  assert(view.LocalTransparencyModifier==1 and p.LocalTransparencyModifier==1,kind..' hides view, preserves source')
  for _,fx in ipairs(ctrl.folder:GetDescendants()) do
   if fx:IsA('BasePart') then assert(fx.Size.X>0 and fx.Size.Y>0 and fx.Size.Z>0 and fx.Position.Magnitude==fx.Position.Magnitude,kind..' finite geometry') end
  end
 end
 p:SetAttribute('EffectDoneAt',now+duration)
 ctrl:step(now+duration+.1,.1);assert(ctrl.count>0,kind..' completion tail')
 ctrl:step(now+duration+1.2,.1);assert(ctrl.count==0 and view.LocalTransparencyModifier==1 and ctrl:isActive(p),kind..' retirement hold prevents fracture flash')
 p:Destroy();assert(view.LocalTransparencyModifier==.2 and not ctrl:isActive(p),kind..' source retirement cleanup');view:Destroy();checks=checks+1
 now=now+20
 local cancelled=resource(kind,now);local cancelledView=views[cancelled]
 ctrl:step(now+.1,.1);cancelled:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+.2,.1)
 assert(ctrl.count==0 and cancelledView.LocalTransparencyModifier==.2,kind..' cancellation restore');assert(cancelled.LocalTransparencyModifier==1,'must preserve authoritative collider')
 cancelled:Destroy();cancelledView:Destroy();checks=checks+1
end
local waiting=resource('Bubbler',now,true);ctrl:step(now+.1,.1);assert(ctrl.count==0,'awaits local resource view');checks=checks+1
local waitedView=waiting:Clone();waitedView.LocalTransparencyModifier=.3;waitedView.Parent=visibleRoot;views[waiting]=waitedView
ctrl:step(now+.2,.1);assert(ctrl.count>0 and waitedView.LocalTransparencyModifier==1,'view arrival without source attr update');checks=checks+1
waiting:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+.3,.1);assert(waitedView.LocalTransparencyModifier==.3,'view wait original transparency retained');waiting:Destroy();waitedView:Destroy();checks=checks+1
local paused=resource('Halver',now);ctrl:step(now+2.4,.1);paused:SetAttribute('EffectPausedAt',now+2.4)
local before=ctrl.active[paused].fragments[1].Position
ctrl:step(now+100,.1);assert(ctrl.count>0,'pause does not expire');assert((ctrl.active[paused].fragments[1].Position-before).Magnitude<.0001,'pause pose frozen');checks=checks+1
paused:SetAttribute('EffectStartedAt',now+97.6);paused:SetAttribute('EffectPausedAt',0);ctrl:step(now+100,.1)
assert((ctrl.active[paused].fragments[1].Position-before).Magnitude<.0001,'resume start shift preserves pose');checks=checks+1
paused:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+100.1,.1);paused:Destroy();views[paused]:Destroy()
local old=resource('Bubbler',0);old:SetAttribute('EffectDoneAt',4.2);ctrl:step(now,.1);assert(ctrl.count==0,'late join skips old payout');old:Destroy();views[old]:Destroy();checks=checks+1
local invisible=resource('Bubbler',now);views[invisible].Transparency=1;ctrl:step(now+.1,.1);assert(ctrl.count==0,'hidden progression rock stays hidden');invisible:Destroy();views[invisible]:Destroy();checks=checks+1
local crowded={}
for i=1,20 do crowded[i]=resource('Resonator',now) end
ctrl:step(now+.1,.1);assert(ctrl.count<=360,'shared budget');checks=checks+1
for _,p in ipairs(crowded) do p:SetAttribute('EffectCancelledSerial',1) end
ctrl:step(now+.2,.1);assert(ctrl.count==0,'all crowded effects cancel');checks=checks+1
for _,p in ipairs(crowded) do p:Destroy();views[p]:Destroy() end
local streamed=resource('Gridcutter',now);ctrl:step(now+.1,.1);streamed:Destroy();assert(ctrl.count==0,'stream out cleanup');views[streamed]:Destroy();checks=checks+1
local final=resource('Frostbite',now);ctrl:step(now+.1,.1);ctrl:destroy();assert(ctrl.destroyed and views[final].LocalTransparencyModifier==.2 and final.LocalTransparencyModifier==1,'destroy restores visible view only');checks=checks+1
print(checks..' latest-client FX lifecycle API-double checks passed (not Roblox rendering validation)')
