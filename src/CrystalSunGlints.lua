-- Cache fixed points on each crystal's surface. The camera changes which
-- facets catch the light; a sparkle's position never follows the camera.
local Lighting=game:GetService('Lighting')
local G={}
local RANGE,LIMIT,ROCK_LIMIT,PER_ROCK,INTERVAL=112,48,22,5,.13
local STAR='rbxassetid://77624818077620'
local WHITE=Color3.fromRGB(255,251,239)
local LEVELS={.04,.25,.43}
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
  and not r.visual.broken and not r.finalLoad and not r.damageScale
  and not r.source:GetAttribute('ClusterBlackAt')
end
local function sampleSites(source,params)
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
     table.insert(sites,{point=point,normal=frame:VectorToObjectSpace(hit.Normal)*size,index=#sites+1})
    end
   end
  end
 end
 return sites
end
local function makeSprite(carrier)
 local sprite=EnergyDisc.sprite(carrier,'CrystalSunGlint')
 sprite.gui.MaxDistance=RANGE+8;sprite.gui.Brightness=3.4;sprite.image.Image=STAR
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
    local rebuildBudget,visibleBudget=5,LIMIT
    for i=1,math.min(ROCK_LIMIT,#candidates) do
     if visibleBudget<=0 then break end
     local r=candidates[i]
     local sites=self.sites[r]
     if not sites and rebuildBudget>0 then
      sites=sampleSites(r.source,probe);self.sites[r]=sites;rebuildBudget-=1
     end
     if not sites then continue end
     local v=r.view
     local frame,scale=v.CFrame,v.Size
     local ranked=self.ranked;table.clear(ranked)
     for _,site in ipairs(sites) do
      local point=frame:PointToWorldSpace(site.point*scale)
      local normal=frame:VectorToWorldSpace((site.normal/scale).Unit)
      local toward=(position-point).Unit
      local half=toward+sun
      local lit,facing=normal:Dot(sun),normal:Dot(toward)
      if half.Magnitude>.01 and lit>.035 and facing>.08 then
       local gloss=ramp((normal:Dot(half.Unit)-.47)/.47)
       local strength=gloss*ramp(lit/.19)*ramp((facing-.08)/.36)
       if strength>.10 then
        site.score=strength;site.worldPoint=point;site.worldNormal=normal
        table.insert(ranked,site)
       end
      end
     end
     table.sort(ranked,brightFirst)
     local character=player.Character
     shadow.FilterDescendantsInstances=character and {r.source,parent,character} or {r.source,parent}
     local placed=0
     for _,site in ipairs(ranked) do
      if placed>=PER_ROCK or visibleBudget<=0 then break end
      if workspace:Raycast(site.worldPoint+site.worldNormal*.10,sun*96,shadow) then continue end
      local sprite=self.active[site] or table.remove(self.pool)
      if not sprite and self.created<LIMIT then
       self.created+=1;sprite=makeSprite(carrier)
      end
      if sprite then
       if not self.active[site] then sprite.rock=r;sprite.alpha=0;self.active[site]=sprite end
       sprite.targetAlpha=(.34+.66*site.score)*ramp((RANGE-math.sqrt(r.glintDistance))/28)
        *ramp((sun.Y-.015)/.06)
       placed+=1;visibleBudget-=1
      end
     end
    end
   end
  end
  local blend=1-math.exp(-math.min(dt,.1)*10)
  steady=steady or player:GetAttribute('ReducedFlashing')==true
  for site,sprite in pairs(self.active) do
   local r=sprite.rock
   if not drawable(r) then release(site,sprite);continue end
   sprite.alpha+=(sprite.targetAlpha-sprite.alpha)*blend
   if sprite.targetAlpha==0 and sprite.alpha<.012 then release(site,sprite);continue end
   local seed=r.glintSeed+site.index*47
   local period=2.1+seed%7*.23
   local wave=steady and .72 or .5+.5*math.sin((now%period)/period*(2*math.pi)+seed*1.7)
   local size=(2.55+(seed%29)*.109)*(.82+.18*wave)
   local v=r.view
   sprite.gui.Enabled=sprite.alpha>.016
   if sprite.gui.Enabled then
    -- Only the rock's own transform moves the anchor.
    local outward=(site.normal/v.Size).Unit*.12
    sprite.anchor.WorldPosition=v.CFrame:PointToWorldSpace(site.point*v.Size+outward)
    local pixels=24+seed%13
    sprite.gui.Size=UDim2.new(size,pixels,size,pixels)
    sprite.image.ImageColor3=WHITE:Lerp(r.baseColor,.06)
    sprite.image.ImageTransparency=1-sprite.alpha*(.52+.48*wave)*(steady and .74 or 1)
   end
  end
 end
 return self
end
return G
