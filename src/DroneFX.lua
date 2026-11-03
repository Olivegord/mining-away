-- Synced, client-only mining choreography. Damage and payout stay on the server.
-- Each effect owns its geometry; interrupted jobs never leave hidden rocks behind.
local FX = {}
local TAU = math.pi * 2
local MAX_PARTS, MAX_EFFECT_PARTS = 360, 48
local TAIL = 1.15
local supported = {Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local effectAttributes={ResourceId=true,EffectSerial=true,EffectType=true,EffectStartedAt=true,EffectDuration=true,EffectDoneAt=true,EffectPausedAt=true,EffectCancelledSerial=true}
local resourceNames={Crystal=true,Geode=true,Core=true,Shard=true}
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
  local p=part(e,'Fragment',Vector3.one,color or e.color,material or e.material or Enum.Material.SmoothPlastic)
  p.Transparency=1;set[i]=p
 end
 return set
end
local function makeRing(e,n,color,width)
 local ring={parts={},points={},width=width or .065}
 for i=1,n do ring.parts[i]=part(e,'EnergyArc',Vector3.one,color);local angle=(i-1)*TAU/n;ring.points[i]=Vector3.new(math.cos(angle),0,math.sin(angle)) end
 return ring
end
local values=setmetatable({},{__mode='k'})
local function set(p,key,value)
 local cached=values[p]
 if not cached then cached={};values[p]=cached end
 if cached[key]~=value then p[key]=value;cached[key]=value end
end
local function showRing(ring,cf,radius,alpha)
 local n=#ring.parts
 for i,p in ipairs(ring.parts) do
  local from=cf:PointToWorldSpace(ring.points[i]*radius)
  local to=cf:PointToWorldSpace(ring.points[i%n+1]*radius)
  p.Size=Vector3.new(ring.width,ring.width,math.max(.025,(to-from).Magnitude))
  p.CFrame=CFrame.lookAt((from+to)*.5,to);set(p,'Transparency',alpha or 0)
 end
end
local function line(p,a,b,width,alpha)
 if (b-a).Magnitude<.001 then set(p,'Transparency',1);return end
 p.Size=Vector3.new(width,width,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)*.5,b);set(p,'Transparency',alpha or 0)
end
local function hideParts(parts)
 for _,p in ipairs(parts) do set(p,'Transparency',1) end
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
 set(e.rock,'Size',safeSize(e.size*(1-absorb*.77)));set(e.rock,'Transparency',clamp((t-.55)*2))
 for i,p in ipairs(e.bubbles) do
  local a=i*TAU/5+t*4
  local converge=1-smooth(t/.32)
  local offset=i==1 and Vector3.zero or Vector3.new(math.cos(a),math.sin(a*1.7)*.5,math.sin(a))*(r*.55+converge*3)
  p.Position=center+offset+Vector3.new(0,converge*(i+2),0)
  local diameter=i==1 and r*2.65 or r*.8
  set(p,'Size',Vector3.one*math.max(.05,diameter*smooth(t/.17)));set(p,'Transparency',.43)
  local glint=e.glints[i];set(glint,'Size',Vector3.one*math.max(.025,diameter*.075))
  glint.Position=p.Position+Vector3.new(-diameter*.23,diameter*.3,-diameter*.2);set(glint,'Transparency',.12)
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
 set(e.rock,'Transparency',t<.12 and 0 or 1)
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
   set(p,'Size',safeSize(cell*(.94+stretch*.35)*shrink))
   p.CFrame=CFrame.new(p.Position)*e.cf.Rotation*CFrame.Angles(t*grind*30+i*grind,t*grind*20,stretch)
   set(p,'Transparency',clamp((t-.94)*8))
  else set(p,'Transparency',1) end
 end
 showRing(e.ring,CFrame.new(e.center+Vector3.new(0,2,0)),e.radius*1.7,t<.58 and 1 or .45)
end
local function gridPose(e,t)
 local r=e.radius*1.05
 local scan=clamp(t/.7)
 e.rock.CFrame=e.cf;set(e.rock,'Size',e.size);set(e.rock,'Transparency',t<.82 and 0 or 1)
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
  set(p,'Size',safeSize(cell*.91))
  p.CFrame=CFrame.new(e.center+offset+Vector3.new(x*spill*.9,spill*.55,z*spill*.9))*CFrame.Angles(z*spill*.3,x*spill*.3,0)
  set(p,'Transparency',t>=.82 and 0 or 1)
 end
end
local function singularityPose(e,t)
 local center=e.center+Vector3.new(0,e.radius*.4+1,0)
 local grow=smooth(t/.2);local absorb=smooth((t-.12)/.78)
 local diameter=e.radius*.82*grow
 set(e.hole,'Size',Vector3.one*math.max(.05,diameter));e.hole.Position=center
 showRing(e.ring,CFrame.new(center)*CFrame.Angles(.35,0,t*4),math.max(.05,diameter*.9),.05)
 set(e.rock,'Size',safeSize(e.size*(1-absorb*.97)))
 e.rock.CFrame=CFrame.new(e.center:Lerp(center,absorb))*e.cf.Rotation*CFrame.Angles(t*t*5,absorb*12,0)
 set(e.rock,'Transparency',clamp((t-.8)*5))
 for i,p in ipairs(e.fragments) do
  local phase=(t*1.1+i/16)%1
  local radius=e.radius*(.2+(1-phase)*2.2)
  local a=i*2.4+t*15+phase*5
  p.Position=center+Vector3.new(math.cos(a)*radius,math.sin(a*2)*radius*.25,math.sin(a)*radius)
  set(p,'Size',Vector3.one*(.04+(1-phase)*.12));set(p,'Transparency',1-grow*(1-phase))
 end
end
local function starforgePose(e,t)
 local center=e.center+Vector3.new(0,e.radius+3,0)
 local heat=smooth((t-.12)/.75)
 local diameter=e.radius*(.5+.5*smooth(t/.2))
 e.sun.Position=center;set(e.sun,'Size',Vector3.one*diameter)
 e.corona.Position=center;set(e.corona,'Size',e.sun.Size*(1.45+math.sin(t*48)*.04))
 showRing(e.ring,CFrame.new(center)*CFrame.Angles(.45,t*4,.3),diameter*.95,.22)
 set(e.rock,'Color',e.color:Lerp(hot,heat));set(e.rock,'Material',t>.45 and Enum.Material.Neon or e.material)
 set(e.rock,'Size',safeSize(e.size*Vector3.new(1+heat*.22,1-heat*.6,1+heat*.22)))
 e.rock.CFrame=e.cf+Vector3.new(0,-heat*e.size.Y*.24,0)
 for i,p in ipairs(e.fragments) do
  local a=i*2.4;local phase=(t*2+i/18)%1
  p.Position=e.center+Vector3.new(math.cos(a)*e.radius*(.7+phase),-e.radius*.3-phase*phase*2,math.sin(a)*e.radius*(.7+phase))
  set(p,'Size',Vector3.one*(.15+.23*(1-phase)));set(p,'Transparency',t<.35 and 1 or phase*.8)
 end
end
local function frostbitePose(e,t)
 local freeze=smooth(t/.6);local shiver=math.sin(t*150)*smooth((t-.68)/.25)*.035
 e.rock.CFrame=e.cf+Vector3.new(shiver,0,-shiver);set(e.rock,'Color',e.color:Lerp(ice,freeze))
 e.shell.CFrame=e.rock.CFrame;set(e.shell,'Size',e.size*(1.02+freeze*.14));set(e.shell,'Transparency',1-freeze*.55)
 local pulse=((t-.7)*5)%1
 showRing(e.ring,CFrame.new(e.center)*CFrame.Angles(math.pi/2,0,0),e.radius*(1+pulse*1.4),t<.7 and 1 or pulse)
 hideParts(e.fragments)
end
local function resonatorPose(e,t)
 local pulse=(t*5)%1
 local shake=smooth((t-.25)/.7)*.07
 e.rock.CFrame=e.cf*CFrame.Angles(math.sin(t*125)*shake,0,math.cos(t*113)*shake)
 set(e.rock,'Size',safeSize(e.size*Vector3.new(1+math.sin(t*80)*shake,1-math.sin(t*80)*shake,1)))
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
  for _,p in ipairs(e.parts) do set(p,'Transparency',1) end
 end
 local fade=clamp(age/TAIL)
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
  set(p,'Size',safeSize(size*(1-fade*.8)));set(p,'Transparency',fade)
  if e.kind=='Bubbler' then set(p,'Shape',Enum.PartType.Cylinder);set(p,'Size',Vector3.new(.1, .43, .43)*(1-fade*.8));set(p,'Color',gold) end
 end
end

function FX.new(world,options)
 options=options or {}
 local self={world=world,tracked={},dirty={},retry={},active={},count=0,connections={},destroyed=false,poseUpdates=0}
 local interval=options.interval or 0 -- continuous render-frame motion by default
 local maxDistance=options.maxDistance or 160
 local focusPosition
 local function nearby(v)
  if focusPosition then local delta=focusPosition-v.Position;if delta:Dot(delta)<=maxDistance*maxDistance then return true end end
  local camera=workspace.CurrentCamera
  if not camera then return true end
  local offset=camera.CFrame.Position-v.Position
  return offset:Dot(offset)<=maxDistance*maxDistance
 end
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
  -- Ignore scenery, drone hardware, currency and their constantly changing
  -- attributes. Name/parent cover resources streamed before their attributes.
  local parent=v.Parent
  if not v:GetAttribute('ResourceId') and not resourceNames[v.Name]
   and not (parent and (parent.Name=='Resources' or parent:GetAttribute('FieldId'))) then return end
  self.tracked[v]=v.AttributeChanged:Connect(function(name)
   if effectAttributes[name] then self.dirty[v]=true;self.retry[v]=nil end
  end)
  self.dirty[v]=true
 end
 self.connections[#self.connections+1]=world.DescendantAdded:Connect(observe)
 self.connections[#self.connections+1]=world.DescendantRemoving:Connect(function(v)
  remove(v)
  if self.tracked[v] then self.tracked[v]:Disconnect();self.tracked[v]=nil end
  self.dirty[v]=nil;self.retry[v]=nil
 end)
 for _,v in ipairs(world:GetDescendants()) do observe(v) end
 function self:isActive(source) return self.active[source]~=nil end
 function self:step(now,_dt)
  if self.destroyed then return end
  focusPosition=options.focus and options.focus() or nil
  for v,at in pairs(self.retry) do if now>=at then self.retry[v]=nil;self.dirty[v]=true end end
  for v in pairs(self.dirty) do
   self.dirty[v]=nil
   if v.Parent and v:GetAttribute('ResourceId') then
    local serial=v:GetAttribute('EffectSerial') or 0
    local kind=v:GetAttribute('EffectType')
    local start=v:GetAttribute('EffectStartedAt')
    local duration=v:GetAttribute('EffectDuration')
    local cancelled=(v:GetAttribute('EffectCancelledSerial') or 0)>=serial
    local e=self.active[v]
    if e and (e.serial~=serial or e.kind~=kind or cancelled or type(start)~='number' or type(duration)~='number' or duration<=0) then remove(v);e=nil end
    if e then e.start=start end -- Save-pause clock shifts do not rebuild geometry.
    if not e and serial>0 and not cancelled and supported[kind] and type(start)=='number' and type(duration)=='number' and duration>0 then
     local done=v:GetAttribute('EffectDoneAt') or 0
     if done>0 and done>=start and now-done>TAIL then
      -- A late joiner does not replay old payouts.
     elseif not nearby(v) then self.retry[v]=now+.2
     elseif self.count+MAX_EFFECT_PARTS<=MAX_PARTS then
      local view=options.resolve and options.resolve(v) or (not options.resolve and v or nil)
      if view and view.Parent and view.Transparency<.99 then
       local full=v:GetAttribute('FullSize') or v.Size
       if type(full)=='number' then full=Vector3.one*full end
       local size=view.Size.Magnitude>.05 and view.Size or full
       local effectFolder=Instance.new('Folder');effectFolder.Name=kind..'_'..serial;effectFolder.Parent=self.folder
       e={owner=self,resource=v,view=view,kind=kind,serial=serial,start=start,duration=duration,folder=effectFolder,parts={},center=view.Position,cf=view.CFrame,size=size,color=view.Color,material=view.Material,radius=math.max(size.X,size.Y,size.Z)*.5,originalTransparency=view.LocalTransparencyModifier}
       build(e);self.active[v]=e;view.LocalTransparencyModifier=1
      elseif done<=0 then self.retry[v]=now+.1 end
     else self.retry[v]=now+.1 end
    end
   end
  end
  for v,e in pairs(self.active) do
   if not v.Parent or not e.view.Parent or not v:GetAttribute('ResourceId') or (v:GetAttribute('EffectCancelledSerial') or 0)>=e.serial then remove(v)
   elseif not nearby(v) then
    remove(v);self.retry[v]=now+.2
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
     elseif not e.retired and now>=(e.nextPose or 0) then
      e.nextPose=now+interval;self.poseUpdates+=1;finishPose(e,age)
     end
    else
     local pausedAt=v:GetAttribute('EffectPausedAt') or 0
     local visualNow=pausedAt>0 and math.min(now,pausedAt) or now
     local t=math.min(.985,clamp((visualNow-e.start)/e.duration))
     if now>=(e.nextPose or 0) and (not e.lastPhase or t~=e.lastPhase) then
      e.nextPose=now+interval;e.lastPhase=t;self.poseUpdates+=1;poses[e.kind](e,t)
     end
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
  table.clear(self.dirty);table.clear(self.retry);table.clear(self.tracked)
  self.folder:Destroy()
 end
 return self
end
return FX
