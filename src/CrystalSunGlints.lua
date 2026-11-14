-- Cache candidate facets, then let the viewpoint move each reflection
-- across its own surface and change its apparent size.
local Lighting=game:GetService('Lighting')
local G={}
local RANGE,LIMIT,ACTIVE_LIMIT,ROCK_LIMIT,PER_ROCK,INTERVAL=112,64,44,22,5,.055
local STAR='rbxassetid://77624818077620'
local WHITE=Color3.fromRGB(255,251,239)
local LEVELS={.04,.25,.43}
local TRACE_FRACTIONS={1,.5}
local function ramp(t)
 t=math.clamp(t,0,1);return t*t*(3-2*t)
end
local function nearFirst(a,b)
 if a.glintDistance==b.glintDistance then return a.id<b.id end
 return a.glintDistance<b.glintDistance
end
local function brightFirst(a,b)
 if a.score==b.score then return a.index<b.index end
 return a.score>b.score
end
local function drawable(r)
 return r.view.Parent and r.source.Parent and r.source.CanQuery and r.view.Transparency<.65
  and not r.visual.broken and not r.damageScale
  and (r.visibleDarkness or 0)<.96
  and not r.source:GetAttribute('ClusterBlackAt')
end
local function sampleSites(source,params,seed)
 local sites={}
 local frame,size=source.CFrame,source.Size
 params.FilterDescendantsInstances={source}
 for level,y in ipairs(LEVELS) do
  -- Sample from a fixed ring in local space. Stagger the top ring so
  -- different cuts give a spread of points over their faces and ridges.
  for i=1,10 do
   local angle=(i+(level%2)*.5)*math.pi/5
   local direction=Vector3.new(math.cos(angle),level==3 and .23 or 0,math.sin(angle))
   local focus=Vector3.new(0,y,0)
   local origin=frame:PointToWorldSpace((focus+direction)*size)
   local ray=frame:VectorToWorldSpace(-direction*size*1.55)
   local hit=workspace:Raycast(origin,ray,params)
   if hit then
    local point=frame:PointToObjectSpace(hit.Position)/size
    local spaced=true
    for _,other in ipairs(sites) do
     local gap=point-other.point
     if gap:Dot(gap)<.018 then spaced=false;break end
    end
    if spaced then
     local index=#sites+1
     local random=Random.new(seed+index*613)
     local variety=random:NextNumber()
     local span=if variety<.54 then random:NextNumber(1.2,2.6)
      elseif variety<.90 then random:NextNumber(2.9,5.1) else random:NextNumber(5.7,8.1)
     table.insert(sites,{point=point,normal=frame:VectorToObjectSpace(hit.Normal)*size,index=index,
      band=random:NextNumber(-.54,.54),width=random:NextNumber(.065,.18),span=span,
      phase=random:NextNumber(0,256),frequency=random:NextNumber(22,38),
      rotation=random:NextNumber(-28,28)})
    end
   end
  end
 end
 return sites
end
local function response(site,normal,toward,sun)
 local half=toward+sun
 local lit,facing=normal:Dot(sun),normal:Dot(toward)
 if half.Magnitude<.01 or lit<.025 or facing<.065 then return 0 end
 local gloss=ramp((normal:Dot(half.Unit)-.43)/.42)*ramp(lit/.15)*ramp((facing-.065)/.22)
 -- A narrow directional peak models a smaller reflection within a large
 -- collision facet. Distinct peaks make neighboring points trade flashes.
 local tangent=normal:Cross(Vector3.yAxis)
 if tangent.Magnitude<.05 then tangent=normal:Cross(Vector3.xAxis) end
 local mirror=normal*(2*lit)-sun
 local error=math.abs((toward-mirror):Dot(tangent.Unit)-site.band)
 local flash=math.clamp((1-error/site.width)*2.8,0,1)
 return gloss*(.28+.72*flash),flash,gloss
end
local function traceReflection(site,source,view,camera,params)
 local frame,size=view.CFrame,view.Size
 local localNormal=(site.normal/size).Unit
 local worldPoint=frame:PointToWorldSpace(site.point*size)
 local toward=frame:VectorToObjectSpace((camera-worldPoint).Unit)
 local tangent=toward-localNormal*toward:Dot(localNormal)
 -- Move within the facet as the eye moves. Reproject onto the native
 -- surface so the highlight cannot slide off a tip or across a void.
 local drift=tangent*.24
 local sourceFrame,sourceSize=source.CFrame,source.Size
 local normal=(site.normal/sourceSize).Unit
 local reach=sourceSize.Magnitude*.17
 local axis=sourceFrame:VectorToWorldSpace(normal)
 params.FilterDescendantsInstances={source}
 for _,fraction in ipairs(TRACE_FRACTIONS) do
  local center=sourceFrame:PointToWorldSpace((site.point+drift*fraction)*sourceSize)
  local hit=workspace:Raycast(center+axis*reach,-axis*reach*2,params)
  if hit and hit.Normal:Dot(axis)>.94 and math.abs((hit.Position-center):Dot(axis))<reach*.22 then
   return sourceFrame:PointToObjectSpace(hit.Position)/sourceSize
  end
 end
 return site.point
end
local function makeSprite(carrier)
 local sprite=EnergyDisc.sprite(carrier,'CrystalSunGlint')
 sprite.gui.MaxDistance=RANGE+8;sprite.gui.Brightness=4.5;sprite.image.Image=STAR
 return sprite
end
function G.new(parent,player)
 local probe=RaycastParams.new();probe.FilterType=Enum.RaycastFilterType.Include
 local shadow=RaycastParams.new();shadow.FilterType=Enum.RaycastFilterType.Exclude;shadow.IgnoreWater=true
 local carrier=Instance.new('Part');carrier.Name='CrystalGlintAnchors'
 carrier.Size=Vector3.one*.1;carrier.Anchored=true;carrier.Transparency=1
 carrier.CanCollide=false;carrier.CanTouch=false;carrier.CanQuery=false;carrier.CastShadow=false
 carrier.Parent=parent
 local self={nextAt=0,created=0,active={},pool={},candidates={},ranked={},sites=setmetatable({},{__mode='k'})}
 local function release(site,sprite)
  sprite.gui.Enabled=false;table.insert(self.pool,sprite);self.active[site]=nil
 end
 function self:update(resources,now,dt,reduced,steady)
  local camera=workspace.CurrentCamera
  if not camera or reduced then
   for site,sprite in pairs(self.active) do release(site,sprite) end
   self.nextAt=0;return
  end
  if now>=self.nextAt then
   self.nextAt=now+INTERVAL
   local sun=Lighting:GetSunDirection()
   local position=camera.CFrame.Position
   local candidates=self.candidates;table.clear(candidates)
   for _,sprite in pairs(self.active) do sprite.targetAlpha=0 end
   if sun.Y>.015 and Lighting.Brightness>.05 then
    for _,r in pairs(resources) do
     if r.cutFeedback and drawable(r) then
      local delta=r.view.Position-position
      local distance=delta:Dot(delta)
      if distance<RANGE^2 and distance>1 then
       local _,visible=camera:WorldToViewportPoint(r.view.Position)
       if visible then
        r.glintDistance=distance;table.insert(candidates,r)
       end
      end
     end
    end
    table.sort(candidates,nearFirst)
    local rebuildBudget,visibleBudget=2,ACTIVE_LIMIT
    for i=1,math.min(ROCK_LIMIT,#candidates) do
     if visibleBudget<=0 then break end
     local r=candidates[i]
     local sites=self.sites[r]
     if not sites and rebuildBudget>0 then
      sites=sampleSites(r.source,probe,r.glintSeed);self.sites[r]=sites;rebuildBudget-=1
     end
     if not sites then continue end
     local v=r.view
     local frame,scale=v.CFrame,v.Size
     local ranked=self.ranked;table.clear(ranked)
     for _,site in ipairs(sites) do
      local point=frame:PointToWorldSpace(site.point*scale)
      local normal=frame:VectorToWorldSpace((site.normal/scale).Unit)
      local strength=response(site,normal,(position-point).Unit,sun)
      if strength>.065 then
       site.score=strength;site.worldPoint=point;site.worldNormal=normal
       table.insert(ranked,site)
      end
     end
     table.sort(ranked,brightFirst)
     local character=player.Character
     shadow.FilterDescendantsInstances=character and {r.source,parent,character} or {r.source,parent}
     local placed=0
     for _,site in ipairs(ranked) do
      if placed>=PER_ROCK or visibleBudget<=0 then break end
      if not site.shadowUntil or now>=site.shadowUntil or (site.shadowSun-sun).Magnitude>.02 then
       site.shadowed=workspace:Raycast(site.worldPoint+site.worldNormal*.10,sun*96,shadow)~=nil
       site.shadowUntil=now+.40;site.shadowSun=sun
      end
      if site.shadowed then continue end
      local sprite=self.active[site] or table.remove(self.pool)
      if not sprite and self.created<LIMIT then
       self.created+=1;sprite=makeSprite(carrier)
      end
      if sprite then
       if not site.traceEye or (site.traceEye-position).Magnitude>.06
        or site.traceFrame~=frame or site.traceSize~=scale then
        site.tracePoint=traceReflection(site,r.source,v,position,probe)
        site.traceEye=position;site.traceFrame=frame;site.traceSize=scale
       end
       sprite.targetPoint=site.tracePoint
       if not self.active[site] then
        sprite.rock=r;sprite.alpha=0;sprite.point=sprite.targetPoint;self.active[site]=sprite
       end
       sprite.targetAlpha=ramp((RANGE-math.sqrt(r.glintDistance))/28)*ramp((sun.Y-.015)/.06)
       placed+=1;visibleBudget-=1
      end
     end
    end
   end
  end
  local sun=Lighting:GetSunDirection()
  local position=camera.CFrame.Position
  steady=steady or player:GetAttribute('ReducedFlashing')==true
  for site,sprite in pairs(self.active) do
   local r=sprite.rock
   if not drawable(r) then release(site,sprite);continue end
   local v=r.view
   local normal=(site.normal/v.Size).Unit
   local blend=1-math.exp(-math.min(dt,.1)*26)
   sprite.point=sprite.point:Lerp(sprite.targetPoint,blend)
   local point=v.CFrame:PointToWorldSpace(sprite.point*v.Size+normal*.12)
   local strength,flash,gloss=response(site,v.CFrame:VectorToWorldSpace(normal),(position-point).Unit,sun)
   -- A quick, irregular shimmer rides on the reflection. Viewing angle
   -- supplies the larger changes in brightness and apparent size.
   local shimmer=steady and 1 or .91+.09*math.clamp(math.noise(now*site.frequency%2048,site.phase)*2,-1,1)
   local target=sprite.targetAlpha*math.min(1,strength*1.42)*(1-(r.visibleDarkness or 0))
   if steady then target*=.72 end
   sprite.alpha+=(target-sprite.alpha)*(steady and 1-math.exp(-math.min(dt,.1)*8) or blend)
   if sprite.targetAlpha==0 and sprite.alpha<.012 then release(site,sprite);continue end
   sprite.gui.Enabled=sprite.alpha>.035
   if sprite.gui.Enabled then
    sprite.anchor.WorldPosition=point
    local spread=.52+.30*(gloss or 0)+.30*(flash or 0)
    local size=site.span*spread
    local pixels=math.floor((14+site.span*5.8)*spread+.5)
    sprite.gui.Size=UDim2.new(size,pixels,size,pixels)
    sprite.image.Rotation=site.rotation
    sprite.image.ImageColor3=WHITE:Lerp(r.baseColor,.06)
    sprite.image.ImageTransparency=1-sprite.alpha*shimmer
   end
  end
 end
 return self
end
return G
