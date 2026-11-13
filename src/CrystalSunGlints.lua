-- Camera-local reflections. Probe the crystal's native collision facets, then
-- transfer the hit from the replicated rock to its smoothly rendered copy.
local Lighting=game:GetService('Lighting')
local G={}
local RANGE,LIMIT,PROBE_LIMIT,INTERVAL=110,20,28,.14
local STAR='rbxassetid://77624818077620'
local WHITE=Color3.fromRGB(255,251,239)
local PROBES={Vector2.new(0,.17),Vector2.new(-.26,.31),Vector2.new(.26,.31),
 Vector2.new(-.34,-.02),Vector2.new(.34,-.02),Vector2.new(0,.51)}
local function ramp(t)
 t=math.clamp(t,0,1);return t*t*(3-2*t)
end
local function rank(a,b)
 if a.glintDistance==b.glintDistance then return a.id<b.id end
 return a.glintDistance<b.glintDistance
end
local function drawable(r)
 return r.view.Parent and r.source.Parent and r.source.CanQuery and r.view.Transparency<.65
  and not r.visual.broken and not r.finalLoad and not r.damageScale
  and not r.source:GetAttribute('ClusterBlackAt')
end
local function makeSprite(parent)
 local sprite=EnergyDisc.sprite(parent,'CrystalSunGlint')
 sprite.gui.MaxDistance=RANGE+8;sprite.gui.Brightness=2.8;sprite.image.Image=STAR
 return sprite
end
local function reflect(r,camera,sun,params,shadow,fx,character)
 local v,s=r.view,r.source
 local toward=(camera-v.Position).Unit
 local mid=toward+sun
 if mid.Magnitude<.01 then return end
 mid=mid.Unit
 local probeDirection=(toward+mid).Unit
 local side=probeDirection:Cross(Vector3.yAxis)
 if side.Magnitude<.01 then side=Vector3.xAxis else side=side.Unit end
 local up=side:Cross(probeDirection)
 local frame,scale=v.CFrame,v.Size
 local sourceFrame,sourceSize=s.CFrame,s.Size
 local extent=scale.Magnitude
 local function toSource(point)
  return sourceFrame:PointToWorldSpace(frame:PointToObjectSpace(point)/scale*sourceSize)
 end
 params.FilterDescendantsInstances={s}
 local function probe(point)
  local origin=toSource(point+probeDirection*extent)
  local hit=workspace:Raycast(origin,toSource(point-probeDirection*extent)-origin,params)
  if not hit then return end
  local n=(sourceFrame:VectorToObjectSpace(hit.Normal)*sourceSize/scale).Unit
  local w=frame:VectorToWorldSpace(n)
  local lit,visible=w:Dot(sun),w:Dot(toward)
  -- Broad test lobe: a sunlit shoulder can glint well before
  -- the camera reaches the strongest mirror angle.
  local strength=ramp((w:Dot(mid)-.48)/.46)*ramp(lit/.13)*ramp(visible/.17)
  return sourceFrame:PointToObjectSpace(hit.Position)/sourceSize,n,strength
 end
 local function width(axis)
  local d=frame:VectorToObjectSpace(axis)
  return math.abs(d.X)*scale.X+math.abs(d.Y)*scale.Y+math.abs(d.Z)*scale.Z
 end
 local w,h=width(side),width(up)
 local best,normal,strength,origin,offset=nil,nil,.025,nil,nil
 for _,p in ipairs(PROBES) do
  local point=v.Position+side*(p.X*w)+up*(p.Y*h)
  local hit,n,score=probe(point)
  if hit and score>strength+.009 then
   best,normal,strength,origin,offset=hit,n,score,point,p
  end
 end
 if not origin then return end
 -- Walk toward a ridge on the selected facet, staying on the lit side
 -- of the change in surface normal. The probe basis rotates with the viewer.
 local outward=(side*(offset.X*1.8)+up*.52).Unit
 local lo,hi=0,math.min(w,h)*.46
 local hit,n=probe(origin+outward*hi)
 if not hit or n:Dot(normal)<.984 then
  for _=1,4 do
   local distance=(lo+hi)*.5
   hit,n=probe(origin+outward*distance)
   if hit and n:Dot(normal)>.984 then lo=distance;best=hit else hi=distance end
  end
 else
  best=hit
 end
 local point=frame:PointToWorldSpace(best*scale)
 local worldNormal=frame:VectorToWorldSpace(normal)
 shadow.FilterDescendantsInstances=character and {s,fx,character} or {s,fx}
 if workspace:Raycast(point+worldNormal*.07,sun*150,shadow) then return end
 -- Pull the star just off the surface toward the viewer to keep the
 -- center readable at grazing angles. World geometry still occludes it.
 return best+(normal*.045+frame:VectorToObjectSpace(toward)*.13)/scale,strength
end
function G.new(parent,player)
 local probes=RaycastParams.new();probes.FilterType=Enum.RaycastFilterType.Include
 local shadow=RaycastParams.new();shadow.FilterType=Enum.RaycastFilterType.Exclude;shadow.IgnoreWater=true
 -- A real world part gives every billboard attachment a spatial parent.
 local carrier=Instance.new('Part');carrier.Name='CrystalGlintAnchors'
 carrier.Size=Vector3.one*.1;carrier.Anchored=true;carrier.Transparency=1
 carrier.CanCollide=false;carrier.CanTouch=false;carrier.CanQuery=false;carrier.CastShadow=false
 carrier.Parent=parent
 local self={nextAt=0,created=0,active={},pool={},candidates={}}
 function self:update(resources,now,dt,reduced,steady)
  local camera=workspace.CurrentCamera
  if not camera or reduced then
   for r,sprite in pairs(self.active) do
    sprite.gui.Enabled=false;table.insert(self.pool,sprite);self.active[r]=nil
   end
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
    table.sort(candidates,rank)
    for i=1,math.min(PROBE_LIMIT,#candidates) do
     local r=candidates[i]
     local point,strength=reflect(r,position,sun,probes,shadow,parent,player.Character)
     if point then
      local sprite=self.active[r] or table.remove(self.pool)
      if not sprite and self.created<LIMIT then
       self.created+=1;sprite=makeSprite(carrier)
      end
      if sprite then
       if not self.active[r] then sprite.point=point;sprite.alpha=0;self.active[r]=sprite end
       sprite.target=point
       sprite.targetAlpha=(.36+.64*strength)*ramp((RANGE-math.sqrt(r.glintDistance))/26)
        *ramp((sun.Y-.015)/.06)
      end
     end
    end
   end
  end
  local blend=1-math.exp(-math.min(dt,.1)*15)
  steady=steady or player:GetAttribute('ReducedFlashing')==true
  for r,sprite in pairs(self.active) do
   if not drawable(r) then sprite.targetAlpha=0;sprite.alpha=0 end
   local gap=sprite.target-sprite.point
   local switching=gap:Dot(gap)>.075
   local target=switching and sprite.alpha>.035 and 0 or sprite.targetAlpha
   sprite.alpha+=(target-sprite.alpha)*blend
   if target==0 and sprite.targetAlpha==0 and sprite.alpha<.012 then
    sprite.gui.Enabled=false;self.active[r]=nil;table.insert(self.pool,sprite)
   elseif r.view.Parent then
    if switching and sprite.alpha<=.035 then sprite.point=sprite.target
    elseif not switching then sprite.point=sprite.point:Lerp(sprite.target,blend) end
    local seed=r.glintSeed
    local period=1.85+seed%7*.22
    local wave=steady and .65 or .5+.5*math.sin((now%period)/period*(2*math.pi)+seed*1.7)
    local size=(1.35+(seed%29)*.083)*(.75+.25*wave)*(.72+.28*sprite.alpha)
    local v=r.view
    sprite.gui.Enabled=sprite.alpha>.016
    if sprite.gui.Enabled then
     sprite.anchor.WorldPosition=v.CFrame:PointToWorldSpace(sprite.point*v.Size)
     sprite.gui.Size=UDim2.new(size,10,size,10)
     sprite.image.ImageColor3=WHITE:Lerp(r.baseColor,.09)
     sprite.image.ImageTransparency=1-sprite.alpha*(.60+.40*wave)*(steady and .68 or 1)
    end
   end
  end
 end
 return self
end
return G
