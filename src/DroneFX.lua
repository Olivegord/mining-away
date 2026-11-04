-- Client-only, server-clocked specialist work. Each cycle removes a chunk;
-- the remaining authored crystal stays grounded and readable throughout.
local FX = {}
local TAU=math.pi*2
local MAX_PARTS,MAX_EFFECT_PARTS=360,48
local TAIL=1.15
local supported={Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local effectAttributes={ResourceId=true,EffectSerial=true,EffectType=true,EffectStartedAt=true,EffectDuration=true,EffectImpact=true,EffectDoneAt=true,EffectDepleted=true,EffectPausedAt=true,EffectCancelledSerial=true}
local resourceNames={Crystal=true,Geode=true,Core=true,Shard=true}
local cyan=Color3.fromRGB(130,239,255)
local gold=Color3.fromRGB(255,211,83)
local purple=Color3.fromRGB(179,105,255)
local ice=Color3.fromRGB(169,229,255)
local hot=Color3.fromRGB(255,140,48)
local function clamp(x) return math.clamp(x,0,1) end
local function smooth(x) x=clamp(x);return x*x*(3-2*x) end
local function safeSize(v) return Vector3.new(math.max(.025,v.X),math.max(.025,v.Y),math.max(.025,v.Z)) end
local function part(e,name,size,color,material,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Size=safeSize(size);p.Color=color;p.Material=material or Enum.Material.Neon;p.CFrame=e.cf;p.Transparency=1
 if shape then p.Shape=shape end
 p.Parent=e.folder;e.parts[#e.parts+1]=p;e.owner.count+=1;return p
end
local function fragments(e,n,color,material,shape)
 local result={}
 for i=1,n do result[i]=part(e,'ExtractedChip',Vector3.one,color or e.color,material or e.material,shape) end
 return result
end
local function ring(e,n,color,width)
 local result={parts={},width=width or .045}
 for i=1,n do result.parts[i]=part(e,'WaveSegment',Vector3.one,color) end
 return result
end
local function line(p,a,b,width,alpha)
 if (b-a).Magnitude<.001 then p.Transparency=1;return end
 p.Size=Vector3.new(width,width,math.max(.025,(b-a).Magnitude));p.CFrame=CFrame.lookAt((a+b)*.5,b);p.Transparency=clamp(alpha)
end
local function energyLine(e,p,a,b,width,alpha,style)
 line(p,a,b,width,alpha)
 e.beams=e.beams or {}
 local r=e.beams[p]
 if alpha>=.98 or (b-a).Magnitude<.015 then BeamVFX.hide(r,true);return end
 if not r then r=BeamVFX.new(e.folder,style,p.Color,p.Name=='ScanHead');e.beams[p]=r end
 if r then
  p.Transparency=1
  BeamVFX.draw(r,a,b,e.visualNow,1-math.clamp(alpha,0,1),nil,e.contactAge,width/r.profile.body)
 end
end
local function showRing(value,cf,radius,alpha)
 for i,p in ipairs(value.parts) do
  local a,b=(i-1)*TAU/#value.parts,i*TAU/#value.parts
  line(p,cf:PointToWorldSpace(Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)),cf:PointToWorldSpace(Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius)),value.width,alpha)
 end
end
local function hideParts(values) for _,p in ipairs(values) do p.Transparency=1 end end
local function proxy(e)
 local p=e.view:Clone()
 for _,v in ipairs(p:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Highlight') or v:IsA('Sound') or v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Trail') then v:Destroy() end
 end
 p.Name='GroundedCrystal';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.LocalTransparencyModifier=0;p.Transparency=0;p.Parent=e.folder;e.parts[#e.parts+1]=p;e.owner.count+=1;return p
end
local function build(e)
 e.rock=proxy(e)
 if e.kind=='Bubbler' then
  e.bubbles={};e.glints={}
  for i=1,3 do
   local p=part(e,'PressureBubble',Vector3.one,cyan,Enum.Material.Glass,Enum.PartType.Ball);p.Reflectance=.18;e.bubbles[i]=p
   e.glints[i]=part(e,'GlassGlint',Vector3.one,Color3.new(1,1,1),Enum.Material.Neon,Enum.PartType.Ball)
  end
  e.fragments=fragments(e,8,e.color,e.material)
 elseif e.kind=='Halver' then
  e.jaws={part(e,'CuttingJaw',Vector3.one,purple,Enum.Material.Metal),part(e,'CuttingJaw',Vector3.one,purple,Enum.Material.Metal)}
  e.cut=part(e,'ShearEdge',Vector3.one,cyan);e.fragments=fragments(e,8)
 elseif e.kind=='Gridcutter' then
  e.grid={};for i=1,6 do e.grid[i]=part(e,'CutLine',Vector3.one,Color3.fromRGB(255,92,109)) end
  e.scanner=part(e,'ScanHead',Vector3.one,Color3.new(1,1,1));e.fragments=fragments(e,9)
 elseif e.kind=='Singularity' then
  e.hole=part(e,'EventHorizon',Vector3.one,Color3.fromRGB(5,3,12),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
  e.ring=ring(e,12,purple,.07);e.fragments=fragments(e,10)
 elseif e.kind=='Starforge' then
  e.sun=part(e,'ContainedSun',Vector3.one,gold,Enum.Material.Neon,Enum.PartType.Ball)
  e.corona=part(e,'HeatEnvelope',Vector3.one,hot,Enum.Material.Neon,Enum.PartType.Ball)
  e.rays={};for i=1,3 do e.rays[i]=part(e,'HeatRay',Vector3.one,hot) end
  e.fragments=fragments(e,10,hot,Enum.Material.Neon,Enum.PartType.Ball)
 elseif e.kind=='Frostbite' then
  e.shell=proxy(e);e.shell.Name='GrowingIce';e.shell.Color=ice;e.shell.Material=Enum.Material.Glass;e.shell.Transparency=1;e.shell.Reflectance=.16
  e.ring=ring(e,10,ice,.045);e.fragments=fragments(e,12,ice,Enum.Material.Glass)
 elseif e.kind=='Resonator' then
  e.rings={ring(e,10,cyan,.045),ring(e,10,purple,.045),ring(e,10,cyan,.045)}
  e.fragments=fragments(e,8)
 end
end
local function facePoint(e,i)
 local a=i*2.399963
 return e.center+Vector3.new(math.cos(a)*e.radius*.38,e.size.Y*.36,math.sin(a)*e.radius*.38)
end
local function fade(e,age) return age and smooth(age/e.tail) or 0 end
local function recovery(age) return age and smooth(age/.65) or 0 end
local function ballistic(e,age,style)
 hideParts(e.fragments)
 if not age then return end
 local alpha=fade(e,age)
 for i,p in ipairs(e.fragments) do
  local a=i*2.399963;local r=e.radius
  local origin=facePoint(e,i)
  local force=style=='slab' and 1.6 or style=='dust' and 1.1 or 2
  local velocity=Vector3.new(math.cos(a)*force,1.6+(i%3)*.4,math.sin(a)*force)
  p.CFrame=CFrame.new(origin+velocity*age+Vector3.new(0,-5*age*age,0))*e.cf.Rotation*CFrame.Angles(age*(i%3-1),age*.7,i*.2)
  local size=style=='slab' and Vector3.new(r*.4,r*.11,r*.3) or style=='ice' and Vector3.new(r*.09,r*.35,r*.13) or Vector3.one*r*(style=='dust' and .075 or .16)
  p.Size=safeSize(size*(1-alpha*.7));p.Transparency=alpha
 end
end
local function bubblePose(e,t,age)
 local r=e.radius;local fill=smooth(t/(e.impact*.73));local release=smooth((t-e.impact*.78)/(e.impact*.22))
 local cap=e.center+Vector3.new(0,e.size.Y*.42,0)
 local lift=age and math.min(age,.5) or 0
 local floating=cap+Vector3.new(lift*.45,math.sin(lift*math.pi)*r*.85,0)
 local pop=age and smooth((age-.44)/.18) or 0
 for i,p in ipairs(e.bubbles) do
  local side=i-2
  local position=cap+Vector3.new(side*r*.65*(1-fill),r*.4*(1-fill),side*r*.2*(1-fill))
  position=position:Lerp(floating,release)
  local diameter=r*(i==2 and .82 or .27)*fill*(1+pop*.5)
  p.Position=position;p.Size=Vector3.one*math.max(.025,diameter);p.Transparency=.55+pop*.45
  local glint=e.glints[i];glint.Position=position+Vector3.new(-diameter*.23,diameter*.27,-diameter*.12)
  glint.Size=Vector3.one*math.max(.025,diameter*.05);glint.Transparency=.18+pop*.82
 end
 hideParts(e.fragments)
 if age then
  for i,p in ipairs(e.fragments) do
   local a=i*2.399963;local spread=math.max(0,age-.5)
   local origin=floating+Vector3.new(math.cos(a),0,math.sin(a))*r*.1
   p.CFrame=CFrame.new(origin+Vector3.new(math.cos(a)*spread*1.6,spread*1.4-5*spread*spread,math.sin(a)*spread*1.6))*e.cf.Rotation
   p.Size=safeSize(Vector3.one*r*.14*(1-fade(e,age)*.6));p.Transparency=fade(e,age)
  end
 end
end
local function halverPose(e,t,age)
 local charge=smooth(t/(e.impact*.7));local cut=smooth((t-e.impact*.8)/(e.impact*.2));local reset=recovery(age)
 local gap=e.radius*(1.1+.15*charge-.76*cut+.9*reset)
 local top=e.center+Vector3.new(0,e.size.Y*.4,0)
 for i,p in ipairs(e.jaws) do
  local side=i==1 and -1 or 1
  p.CFrame=CFrame.new(top+Vector3.new(side*gap,.15*charge,0))*e.cf.Rotation*CFrame.Angles(0,0,side*(.18*charge-.24*cut)*(1-reset))
  p.Size=Vector3.new(.09,e.radius*.28,e.radius*1.35);p.Transparency=.15+reset*.85
 end
 energyLine(e,e.cut,top+Vector3.new(0,0,-e.radius*.65),top+Vector3.new(0,0,e.radius*.65),.07,.9-cut*.8+reset*.9,'Lance')
 ballistic(e,age,'slab')
end
local function gridPose(e,t,age)
 local r=e.radius*.73;local top=e.center+Vector3.new(0,e.size.Y*.46,0)
 local scan=smooth(t/(e.impact*.83));local out=fade(e,age)
 for i,p in ipairs(e.grid) do
  local axis=i>3;local coordinate=((i-1)%3-1)*r*.56
  local a=axis and Vector3.new(-r,0,coordinate) or Vector3.new(coordinate,0,-r)
  local b=axis and Vector3.new(r,0,coordinate) or Vector3.new(coordinate,0,r)
  local visible=smooth((scan-(i-1)/7)*7)
  energyLine(e,p,top+a,top+a:Lerp(b,visible),.055,1-visible*(1-out)*.8,'Gridcutter')
 end
 local x=-r+scan*r*2
 energyLine(e,e.scanner,top+Vector3.new(x,.04,-r),top+Vector3.new(x,.04,r),.10,.18+out*.82,'Gridcutter')
 hideParts(e.fragments)
 if age then
  for i,p in ipairs(e.fragments) do
   local x1=(i-1)%3-1;local z1=math.floor((i-1)/3)-1
   local origin=top+Vector3.new(x1*r*.56,0,z1*r*.56)
   p.Size=safeSize(Vector3.new(r*.48,r*.18,r*.48)*(1-out*.65))
   p.CFrame=CFrame.new(origin+Vector3.new(x1*age*.85,age*1.8-age*age*5,z1*age*.85))*e.cf.Rotation*CFrame.Angles(z1*age*.5,0,x1*age*.5);p.Transparency=out
  end
 end
end
local function singularityPose(e,t,age)
 local r=e.radius;local grow=smooth(t/(e.impact*.75));local close=recovery(age)
 local center=e.center+Vector3.new(0,e.size.Y*.5+r*.55,0)
 local diameter=r*.46*grow*(1-close*.85)
 e.hole.Position=center;e.hole.Size=Vector3.one*math.max(.025,diameter);e.hole.Transparency=math.max(close,fade(e,age))
 showRing(e.ring,CFrame.new(center)*CFrame.Angles(.42,t*.7,.25),math.max(.025,diameter*.9),.15+math.max(close,fade(e,age))*.85)
 -- Keep the authored gravity well and chips. A pair of tightening hooks and
 -- two sharp cuts give this small well a different vocabulary from heat rays.
 -- This is a resource gravity well, not a laser emitter: no charge lens here.
 e.gravityVFX=e.gravityVFX or BeamVFX.new(e.folder,'Singularity',purple,nil,false)
 if e.gravityVFX then
  BeamVFX.draw(e.gravityVFX,center,center-Vector3.yAxis,e.visualNow,0,math.min(1,t/e.impact),age,math.min(1.4,r*.7))
  local strength=1-fade(e,age)
  for _,v in ipairs(e.gravityVFX.all) do v.Width0*=strength;v.Width1*=strength end
  if e.gravityVFX.orb then e.gravityVFX.orb.Transparency=1 end -- existing EventHorizon owns the dark center
 end
 hideParts(e.fragments)
 if age then
  for i,p in ipairs(e.fragments) do
   -- Each chip has one continuous inward spiral, with no modulo wrap.
   local u=smooth((age-(i-1)*.018)/.7);local a=i*2.399963+u*TAU*.9
   local radius=r*.55*(1-u)
   local origin=facePoint(e,i)
   local target=center+Vector3.new(math.cos(a)*radius,-r*.4*(1-u),math.sin(a)*radius)
   p.Position=origin:Lerp(target,smooth(u*3));p.Size=Vector3.one*math.max(.025,r*.17*(1-u));p.Transparency=math.max(u,fade(e,age))
  end
 end
end
local function starforgePose(e,t,age)
 local heat=smooth(t/(e.impact*.9));local cool=recovery(age);local r=e.radius
 local center=e.center+Vector3.new(0,e.size.Y*.5+r*.8,0)
 local diameter=r*(.2+.35*heat)*(1-cool*.8)
 e.sun.Position=center;e.sun.Size=Vector3.one*math.max(.025,diameter);e.sun.Transparency=cool
 e.corona.Position=center;e.corona.Size=e.sun.Size*1.35;e.corona.Transparency=.82+cool*.18
 for i,p in ipairs(e.rays) do energyLine(e,p,center,facePoint(e,i*2),.065,.95-heat*.65+cool*.75,'Starforge') end
 e.rock.Color=e.color:Lerp(hot,heat*.25*(1-cool))
 hideParts(e.fragments)
 if age then
  for i,p in ipairs(e.fragments) do
   local drip=math.max(0,age-(i-1)*.035);local a=i*2.399963
   p.Position=facePoint(e,i)+Vector3.new(math.cos(a)*drip*.35,-2.8*drip*drip,math.sin(a)*drip*.35)
   p.Size=safeSize(Vector3.new(r*.10,r*(.12+drip*.13),r*.10)*(1-fade(e,age)*.65));p.Transparency=fade(e,age)
  end
 end
end
local function frostbitePose(e,t,age)
 local freeze=smooth(t/(e.impact*.8));local shatter=age and smooth(age/.16) or 0
 e.shell.CFrame=e.cf;e.shell.Size=safeSize(e.size*(1.006+.022*freeze))
 e.shell.Color=ice;e.shell.Transparency=1-freeze*.45*(1-shatter)
 local wave=age and smooth(age/.45) or 0
 showRing(e.ring,CFrame.new(e.center+Vector3.new(0,e.size.Y*.15,0)),e.radius*(.8+wave*.7),age and (1-math.sin(math.pi*wave)*.65) or 1)
 ballistic(e,age,'ice')
end
local function resonatorPose(e,t,age)
 for i,value in ipairs(e.rings) do
  local from=e.impact*(.08+(i-1)*.19)
  local phase=clamp((t-from)/(e.impact*.55))
  local strength=math.sin(math.pi*phase)^2
  local center=e.center+Vector3.new(0,(i-2)*e.radius*.22,0)
  showRing(value,CFrame.new(center)*CFrame.Angles(i==2 and math.pi/2 or .13,0,(i-2)*.16),e.radius*(.7+.75*smooth(phase)),1-strength*.65)
 end
 -- One low-amplitude recoil at contact replaces whole-rock high-frequency jitter.
 if age then
  local recoil=math.sin(math.pi*clamp(age/.26))*math.exp(-age*8)*.018
  e.rock.CFrame=e.cf*CFrame.Angles(0,recoil,0)
 end
 ballistic(e,age,'dust')
end
local poses={Bubbler=bubblePose,Halver=halverPose,Gridcutter=gridPose,Singularity=singularityPose,Starforge=starforgePose,Frostbite=frostbitePose,Resonator=resonatorPose}

function FX.new(world,options)
 options=options or {}
 local self={world=world,tracked={},dirty={},retry={},active={},completed={},count=0,connections={},destroyed=false,poseUpdates=0}
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
 -- A final hit is irreversible. Recall/death may cancel its cosmetic tail,
 -- but cannot reveal the old crystal while ordinary fracture stages drain.
 local function concealDepleted(e)
  if not e.retired then freeGeometry(e) end
  e.retired=true;e.tombstone=true;e.view.LocalTransparencyModifier=1
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
  self.dirty[v]=nil;self.retry[v]=nil;self.completed[v]=nil
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
    if e and e.serial==serial and cancelled and v:GetAttribute('EffectDepleted')==true then concealDepleted(e)
    elseif e and (e.serial~=serial or e.kind~=kind or cancelled or type(start)~='number' or type(duration)~='number' or duration<=0) then remove(v);e=nil end
    if e and not e.tombstone then e.start=start;e.duration=duration;e.tail=math.min(TAIL,duration*(1-e.impact)*.98) end -- Save-pause clock shifts preserve geometry and phase.
    if not e and self.completed[v]~=serial and serial>0 and not cancelled and supported[kind] and type(start)=='number' and type(duration)=='number' and duration>0 then
     local done=v:GetAttribute('EffectDoneAt') or 0
     if done>0 and done>=start and now-done>TAIL then
      self.completed[v]=serial -- A late joiner never replays an old contact.
     elseif not nearby(v) then self.retry[v]=now+.2
     elseif self.count+MAX_EFFECT_PARTS<=MAX_PARTS then
      local view=options.resolve and options.resolve(v) or (not options.resolve and v or nil)
      if view and view.Parent and view.Transparency<.99 then
       local full=v:GetAttribute('FullSize') or v.Size
       if type(full)=='number' then full=Vector3.one*full end
       local size=view.Size.Magnitude>.05 and view.Size or full
       local effectFolder=Instance.new('Folder');effectFolder.Name=kind..'_'..serial;effectFolder.Parent=self.folder
       e={owner=self,resource=v,view=view,kind=kind,serial=serial,start=start,duration=duration,impact=math.clamp(v:GetAttribute('EffectImpact') or .68,.1,.95),folder=effectFolder,parts={},center=view.Position,cf=view.CFrame,size=size,color=view.Color,material=view.Material,radius=math.max(size.X,size.Y,size.Z)*.5,originalTransparency=view.LocalTransparencyModifier}
       e.tail=math.min(TAIL,duration*(1-e.impact)*.98)
       build(e);self.active[v]=e;view.LocalTransparencyModifier=1
      elseif done<=0 then self.retry[v]=now+.1 end
     else self.retry[v]=now+.1 end
    end
   end
  end
  for v,e in pairs(self.active) do
   if not v.Parent or not e.view.Parent or not v:GetAttribute('ResourceId') then remove(v)
   elseif e.tombstone then e.view.LocalTransparencyModifier=1
   elseif (v:GetAttribute('EffectCancelledSerial') or 0)>=e.serial then
    if v:GetAttribute('EffectDepleted')==true then concealDepleted(e) else remove(v) end
   elseif not nearby(v) then
    if v:GetAttribute('EffectDepleted')==true then concealDepleted(e) else remove(v);self.retry[v]=now+.2 end
   else
    local pausedAt=v:GetAttribute('EffectPausedAt') or 0
    local visualNow=pausedAt>0 and math.min(now,pausedAt) or now
    local done=v:GetAttribute('EffectDoneAt') or 0
    local impacted=done>0 and done>=e.start
    local depleted=impacted and v:GetAttribute('EffectDepleted')==true
    local age=impacted and math.max(0,visualNow-done) or nil
    e.visualNow=visualNow;e.contactAge=age
    -- The ordinary fracture queue owns surviving crystal size/pose immediately
    -- after the accepted hit. Keep only local chips/tool recovery over that view.
    e.view.LocalTransparencyModifier=(not impacted or depleted) and 1 or e.originalTransparency
    if age and age>=e.tail then
     if depleted then
      if not e.retired then freeGeometry(e);e.retired=true end
     else self.completed[v]=e.serial;remove(v) end
    elseif not e.retired then
     local t=impacted and math.min(1,e.impact+age/e.duration) or math.min(e.impact,clamp((visualNow-e.start)/e.duration))
     if t~=e.lastPhase or age~=e.lastAge then
      e.lastPhase=t;e.lastAge=age;self.poseUpdates+=1
      e.rock.CFrame=e.cf;e.rock.Size=e.size;e.rock.Color=e.color;e.rock.Transparency=impacted and 1 or 0
      poses[e.kind](e,t,age)
     end
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
  table.clear(self.dirty);table.clear(self.retry);table.clear(self.tracked);table.clear(self.completed)
  self.folder:Destroy()
 end
 return self
end
return FX
