--!strict
-- The dig piece being worked as animated rock chunks (client only, plain
-- parts moved by CFrame every frame; owner, Nov 22: "they should NOT be
-- editable meshes, just animations"). The piece is cut into Voronoi chunks,
-- each a few wedge parts that move together:
--  * a pulsing ripple from where the beam hits: chunks bob up in rings that
--    run outward (inward for a negative speed), the crest glowing toward the
--    attack color (beam roles)
--  * a shock ring for a slam, a pulse or a crack
--  * the crack pop (M.burst): a ring plus chunks pried up on an edge or lifted
--    out, at snapped angles (multiples of ANGLE_STEP) so the facets read as
--    crisp broken rock. Popped chunks stay out until the piece breaks.
-- Coordinates are local about the piece's pivot; M.setPose places it.
local M={}
M.live=0
M.MAX_TILES=14
M.TILE_AREA=3.6 -- square studs per chunk
M.ANGLE_STEP=math.rad(7.5)
-- Owner, Nov 22: "too smooth, animate them at like 8fps". Chunk motion is
-- stepped on an 8 fps grid (a new hit still shows on its own frame).
M.FPS=8
-- Owner, Nov 22: "too colorful". Only the few chunks nearest the hit take
-- the attack color, and only partly; the rest stay rock.
M.TINT_RANKS={1,.6,.3} -- the nearest chunks to the hit, in order; the rest none
M.TINT_MAX=.35
M.TONE_RANKS={1,.85,.65,.45,.25} -- a colored shade (role tone) reaches a few more
M.wedges=nil :: any -- DigCube.polyWedges, installed by the caller
M.material=nil :: any -- the rock material, installed by the caller
M.variant=nil :: any -- and its MaterialVariant name
local TAU=math.pi*2
local BLACK=Color3.new(0,0,0)

local function centroid(poly: {{number}}): (number,number)
 local x,z=0,0
 for _,v in ipairs(poly) do x+=v[1];z+=v[2] end
 return x/#poly,z/#poly
end
local function area(poly: {{number}}): number
 local s=0
 for k=1,#poly do local a,b=poly[k],poly[k%#poly+1];s+=a[1]*b[2]-b[1]*a[2] end
 return math.abs(s)*.5
end

-- shapes: {{poly,y0,y1,color,side?}} pivot-local prisms; split(poly,n,random)
-- cuts a convex polygon into about n convex chunks (DigCube.voronoiSplit).
function M.build(shapes: {any},split: any,random: () -> number): any?
 local wedges=M.wedges
 if not wedges or #shapes==0 then return nil end
 local total=0
 for _,s in ipairs(shapes) do total+=area(s.poly) end
 local scale=math.min(1,M.MAX_TILES/math.max(1,total/M.TILE_AREA))
 local model=Instance.new('Model');model.Name='DigRockChunks'
 local rec={model=model,tiles={},rings={},parts={},pose=CFrame.new(),radius=.5,dirty=true}
 for _,s in ipairs(shapes) do
  local a=area(s.poly)
  if a>.02 then
   local n=math.clamp(math.floor(a/M.TILE_AREA*scale+.5),1,6)
   for _,q in ipairs(n>1 and split(s.poly,n,random) or {s.poly}) do
    if #q>=3 and area(q)>.01 then
     local cx,cz=centroid(q)
     local tile={poly=q,cx=cx,cz=cz,y1=s.y1,side=s.side,stone=s.color,color=s.color,parts={},
      lift=0,angle=0,hinge=nil,anim=nil,popped=false,frame=CFrame.new(),r=math.sqrt(cx*cx+cz*cz)}
     for _,w in ipairs(wedges(q,s.y0,s.y1)) do
      local p=Instance.new('WedgePart');p.Name='DigChunk';p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
      p.CastShadow=true;p.Material=M.material or Enum.Material.SmoothPlastic;p.MaterialVariant=M.variant or '';p.Color=s.color
      p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
      p.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
      local base=CFrame.fromMatrix(Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
       Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
      p.CFrame=base;p.Parent=model
      table.insert(tile.parts,{part=p,base=base})
      table.insert(rec.parts,p)
      for _,v in ipairs(q) do rec.radius=math.max(rec.radius,math.sqrt(v[1]*v[1]+v[2]*v[2])) end
     end
     if #tile.parts>0 then table.insert(rec.tiles,tile) end
    end
   end
  end
 end
 if #rec.tiles==0 then model:Destroy();return nil end
 M.live+=1
 return rec
end

function M.destroy(rec: any)
 if not rec or rec.dead then return end
 rec.dead=true
 M.live=math.max(0,M.live-1)
 rec.model:Destroy()
end

-- Back to whole rock: every chunk down, no rings (the showcase loops).
function M.reset(rec: any)
 if not rec or rec.dead then return end
 for _,tile in ipairs(rec.tiles) do tile.lift=0;tile.angle=0;tile.hinge=nil;tile.anim=nil;tile.popped=false end
 table.clear(rec.rings)
 rec.dirty=true
end
-- Each chunk's rank by distance from the hit (0 = nearest).
local function ranks(rec: any,center: Vector3)
 if rec.rankCenter and (rec.rankCenter-center).Magnitude<.25 then return end
 rec.rankCenter=center
 local order=table.clone(rec.tiles)
 table.sort(order,function(a,b) return (a.cx-center.X)^2+(a.cz-center.Z)^2<(b.cx-center.X)^2+(b.cz-center.Z)^2 end)
 for i,tile in ipairs(order) do tile.rank=i end
 rec.colorDirty=true
end
local function weight(list: {number},rank: number?): number return list[rank or math.huge] or 0 end
-- Chunk colors: the stone toward `tone` by `shade`. Darkening (a gray or
-- black tone) covers the piece; a colored tone only the chunks nearest the
-- hit (owner: "too colorful").
function M.shade(rec: any,tone: Color3,shade: number,center: Vector3?)
 ranks(rec,center or rec.rankCenter or Vector3.zero)
 local _,sat=tone:ToHSV()
 for _,tile in ipairs(rec.tiles) do
  local k=sat>.25 and weight(M.TONE_RANKS,tile.rank) or 1
  tile.color=tile.stone:Lerp(tone,shade*k)
 end
 rec.colorDirty=true
end
function M.setMaterial(rec: any,material: Enum.Material)
 for _,p in ipairs(rec.parts) do p.Material=material end
end

-- Where every part goes: pose * chunk frame * its wedge.
local function place(rec: any)
 local parts,frames={},{}
 local pose=rec.pose
 for _,tile in ipairs(rec.tiles) do
  local f=pose*tile.frame
  for _,e in ipairs(tile.parts) do table.insert(parts,e.part);table.insert(frames,f*e.base) end
 end
 local ok=pcall(function() workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end)
 if not ok then for i,p in ipairs(parts) do p.CFrame=frames[i] end end
end
function M.setPose(rec: any,pose: CFrame)
 if not rec or rec.dead then return end
 if pose==rec.pose and not rec.moved then return end
 rec.pose=pose;rec.moved=false
 place(rec)
end

-- The hinge on edge k of a chunk, turning so the chunk's middle rises.
local function hingeFor(tile: any,k: number): any
 local poly=tile.poly
 local a,b=poly[k],poly[k%#poly+1]
 local h={a=Vector3.new(a[1],tile.y1,a[2]),dir=Vector3.new(b[1]-a[1],0,b[2]-a[2])}
 h.dir=h.dir.Magnitude>1e-6 and h.dir.Unit or Vector3.xAxis
 local up=h.dir:Cross(Vector3.new(tile.cx,tile.y1,tile.cz)-h.a)
 h.sign=up.Y>=0 and 1 or -1
 return h
end
local function snap(angle: number): number
 local step=M.ANGLE_STEP
 return math.max(step,math.floor(angle/step+.5)*step)
end
local function backOut(u: number): number
 local s=1.9
 u-=1
 return u*u*((s+1)*u+s)+1
end

-- Chunks pop out: `count` chunks (unpopped first, nearest `near` if given)
-- pry up on their outer edge or lift straight out. `strength` ~ .5-1.6.
function M.pop(rec: any,count: number,strength: number,now: number,random: Random,mode: string?,near: Vector3?)
 if not rec or rec.dead then return end
 local pool={}
 for _,tile in ipairs(rec.tiles) do if not tile.popped then table.insert(pool,tile) end end
 if #pool==0 then pool=table.clone(rec.tiles) end
 if near then
  table.sort(pool,function(a,b) return (a.cx-near.X)^2+(a.cz-near.Z)^2<(b.cx-near.X)^2+(b.cz-near.Z)^2 end)
 end
 for i=1,math.min(count,#pool) do
  local tile=near and pool[i] or table.remove(pool,random:NextInteger(1,#pool))
  local kind=mode or (random:NextNumber()<.6 and 'pry' or 'lift')
  local was=tile.popped
  tile.popped=true
  -- Stop-motion: the hit frame already shows the chunk punched out past
  -- its rest (the ease's overshoot), the next 8 fps frame settles it.
  local anim={at=now-.1,dur=.18,fromLift=tile.lift,fromAngle=tile.angle}
  if kind=='pry' then
   -- Hinge on the outer edge farthest from the piece's middle: the inner
   -- side comes up, like rock levered out of its bed.
   local poly=tile.poly
   local best,score=1,-math.huge
   for k=1,#poly do
    local a,b=poly[k],poly[k%#poly+1]
    local s=((a[1]+b[1])*.5)^2+((a[2]+b[2])*.5)^2+random:NextNumber()*.5
    if s>score then best,score=k,s end
   end
   if not tile.hinge or not was then tile.hinge=hingeFor(tile,best) end
   anim.toAngle=math.min(snap(math.rad(9+9*random:NextNumber())*strength)+(was and tile.angle or 0),math.rad(38))
   anim.toLift=tile.lift+.04*strength
  else
   anim.toAngle=tile.angle+(random:NextNumber()<.5 and snap(math.rad(4+6*random:NextNumber())) or 0)
   if anim.toAngle>0 and not tile.hinge then tile.hinge=hingeFor(tile,random:NextInteger(1,#tile.poly)) end
   anim.toLift=math.min(tile.lift+(.14+.16*random:NextNumber())*strength,.85)
  end
  tile.anim=anim
 end
 rec.dirty=true
end

-- Every chunk jumps and twists a little, then lands back where it was
-- (owner: visual feedback at each stage). Three 8 fps frames.
function M.hop(rec: any,now: number,random: Random,strength: number?)
 if not rec or rec.dead then return end
 local k=strength or 1
 for _,tile in ipairs(rec.tiles) do
  local sign=random:NextNumber()<.5 and -1 or 1
  tile.hop={at=now-.05,dur=.4,h=(.14+.12*random:NextNumber())*k,twist=sign*snap(math.rad(5+5*random:NextNumber())*k)}
 end
 rec.dirty=true
end
-- A ring that runs out once from `center` (local x,z); speed < 0 runs in.
function M.ring(rec: any,now: number,center: Vector3,amp: number,speed: number,width: number,glow: number?)
 if not rec or rec.dead then return end
 table.insert(rec.rings,{at=now,center=center,amp=amp,speed=speed,width=width,glow=glow or 0})
 if #rec.rings>4 then table.remove(rec.rings,1) end
 rec.dirty=true
end
-- The crack pop (owner: "phenomenal, reuse it everywhere"): a shock ring and
-- chunks prying or lifting out. `b` varies it: {count,strength,mode,ring,
-- speed,width,glow}; `scale` scales count and strength.
function M.burst(rec: any,now: number,center: Vector3,b: any,random: Random,scale: number?,near: Vector3?)
 if not rec or rec.dead then return end
 local k=scale or 1
 M.ring(rec,now,center,(b.ring or .2)*math.min(1.4,k),b.speed or 11,b.width or .9,b.glow or .6)
 M.pop(rec,math.max(1,math.floor((b.count or 2)*k+.5)),(b.strength or 1.1)*math.min(1.3,.75+.25*k),now,random,b.mode or 'pry',near)
end

-- One animation step. `s` (all optional):
--  ripple={amp,len,speed,center=Vector3,square=bool,glow=0..1}; bulge=studs at
--  the middle; glowColor=Color3; slide=Vector3 per side (Halver); scale
--  (toward the pivot); tremble=studs of per-chunk shiver.
function M.step(rec: any,now: number,s: any)
 if not rec or rec.dead then return end
 -- Stop-motion: one pose per 1/FPS. A hit (dirty) draws at once.
 local frame=math.floor(now*M.FPS)
 if frame==rec.frameIndex and not rec.dirty then return end
 rec.frameIndex=frame
 if not rec.dirty then now=frame/M.FPS end
 local ripple=s.ripple
 local rings=rec.rings
 for i=#rings,1,-1 do
  local r=rings[i]
  if (now-r.at)*math.abs(r.speed)>rec.radius+r.width*3 then table.remove(rings,i) end
 end
 local animating=false
 for _,tile in ipairs(rec.tiles) do
  if tile.hop then if now-tile.hop.at>=tile.hop.dur then tile.hop=nil;rec.dirty=true else animating=true end end
  local a=tile.anim
  if a then
   local u=math.clamp((now-a.at)/a.dur,0,1)
   local e=backOut(u)
   tile.lift=a.fromLift+(a.toLift-a.fromLift)*e
   tile.angle=a.fromAngle+(a.toAngle-a.fromAngle)*e
   if u>=1 then tile.anim=nil else animating=true end
  end
 end
 local tremble=s.tremble or 0
 local scale=s.scale or 1
 local slide=s.slide
 local active=ripple~=nil or #rings>0 or (s.bulge or 0)>0 or tremble>0
 if not (active or animating or rec.dirty or rec.colorDirty or rec.wasActive or scale~=(rec.lastScale or 1) or slide~=rec.lastSlide) then return end
 rec.wasActive=active;rec.lastScale=scale;rec.lastSlide=slide
 local glowColor=s.glowColor or Color3.new(1,1,1)
 local radius=rec.radius
 ranks(rec,(ripple and ripple.center) or (rings[#rings] and rings[#rings].center) or rec.rankCenter or Vector3.zero)
 for i,tile in ipairs(rec.tiles) do
  local dy,glow=0,0
  local x,z=tile.cx,tile.cz
  if ripple then
   local c=ripple.center or Vector3.zero
   local dx,dz=x-c.X,z-c.Z
   local r=ripple.square and math.max(math.abs(dx),math.abs(dz)) or math.sqrt(dx*dx+dz*dz)
   local env=math.clamp(1-r/(radius+.6),0,1)^.6
   local w=math.max(0,math.sin(TAU*(r/ripple.len-now*ripple.speed/ripple.len)))
   -- Chunks rise on the crest; nothing sinks into the solid rock below.
   dy+=ripple.amp*w*env
   glow=math.max(glow,(ripple.glow or 0)*w*weight(M.TINT_RANKS,tile.rank))
  end
  for _,ring in ipairs(rings) do
   local dx,dz=x-ring.center.X,z-ring.center.Z
   local r=math.sqrt(dx*dx+dz*dz)
   local t=now-ring.at
   local front=ring.speed>0 and ring.speed*t or radius+ring.speed*t
   local d=(r-front)/ring.width
   local k=math.exp(-d*d)*math.clamp(1-t*.9,0,1)
   dy+=ring.amp*k
   glow=math.max(glow,ring.glow*k*weight(M.TINT_RANKS,tile.rank))
  end
  if (s.bulge or 0)>0 then dy+=s.bulge*math.clamp(1-(x*x+z*z)/(radius*radius),0,1) end
  if tile.popped then dy*=.35 end
  local offset=Vector3.new(0,tile.lift+dy,0)
  if slide and tile.side then offset+=slide*tile.side end
  if scale~=1 then offset+=Vector3.new(x*(scale-1),0,z*(scale-1)) end
  if tremble>0 then
   local q=math.floor(now*36)*.71+i*3.1
   offset+=Vector3.new(math.noise(q,i,.3),math.noise(i,q,.9)*.4,math.noise(.5,i,q))*tremble
  end
  local f=CFrame.new(offset)
  local hop=tile.hop
  if hop then
   local e=math.sin(math.pi*math.clamp((now-hop.at)/hop.dur,0,1))
   local c=Vector3.new(tile.cx,tile.y1,tile.cz)
   f=CFrame.new(0,hop.h*e,0)*f*CFrame.new(c)*CFrame.Angles(0,hop.twist*e,0)*CFrame.new(-c)
  end
  if tile.angle~=0 and tile.hinge then
   local h=tile.hinge
   f=f*CFrame.new(h.a)*CFrame.fromAxisAngle(h.dir,tile.angle*h.sign)*CFrame.new(-h.a)
  end
  tile.frame=f
  local color=glow>0 and tile.color:Lerp(glowColor,math.min(M.TINT_MAX,glow)) or tile.color
  if color~=tile.shown then
   tile.shown=color
   for _,e in ipairs(tile.parts) do e.part.Color=color end
  end
 end
 rec.dirty=false;rec.colorDirty=false
 place(rec)
end
M.BLACK=BLACK
return M
