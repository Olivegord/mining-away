--!strict
-- The dig piece being worked, as ONE deformable low-poly mesh (client only,
-- EditableMesh). The rock around it is server CSG and cannot be deformed;
-- the piece the crew is cutting is drawn here over it (DigCubeView proxy),
-- so this is where the rock "does things" while it is mined:
--  * a pulsing ripple from where the beam hits: rings run out across the
--    top, the crest glows toward the attack color (beam roles)
--  * a single shock ring for a slam or a pulse
--  * chunks that pop out: the piece is cut into Voronoi tiles; a hit pries a
--    tile up on one of its edges or lifts it straight out, at snapped angles
--    (multiples of ANGLE_STEP) so the facets read as crisp broken rock.
--    Popped tiles stay out until the piece breaks.
-- Everything is local coordinates about the piece's pivot (the caller poses
-- the part). A failure to make meshes (setting off, memory budget) returns
-- nil and the caller falls back to the old wedge parts.
local AssetService=game:GetService('AssetService')
local M={}
M.failed=false
M.live=0
M.MAX_LIVE=18
M.MAX_TILES=14
M.TILE_AREA=3.6 -- square studs per tile
M.ANGLE_STEP=math.rad(7.5)
local MARGIN=Vector3.new(1.6,2.2,1.6) -- room for pops and ripples inside the fixed bounds
local WHITE=Color3.new(1,1,1)
local TAU=math.pi*2

type Shape={poly:{{number}},y0:number,y1:number,color:Color3,side:number?}

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
local function faceNormal(a: Vector3,b: Vector3,c: Vector3): Vector3
 local n=(b-a):Cross(c-a)
 return n.Magnitude>1e-9 and n.Unit or Vector3.yAxis
end

-- shapes: pivot-local prisms. split(poly,n,random) cuts a convex polygon into
-- about n convex tiles (DigCube.voronoiSplit). Yields (CreateMeshPartAsync).
function M.build(shapes: {Shape},split: any,random: () -> number): any?
 if M.failed or M.live>=M.MAX_LIVE or #shapes==0 then return nil end
 -- Tiles: each shape cut by area, the whole piece capped at MAX_TILES.
 local total=0
 for _,s in ipairs(shapes) do total+=area(s.poly) end
 local scale=math.min(1,M.MAX_TILES/math.max(1,total/M.TILE_AREA))
 local tiles={}
 for _,s in ipairs(shapes) do
  local a=area(s.poly)
  if a>.02 then
   local n=math.clamp(math.floor(a/M.TILE_AREA*scale+.5),1,6)
   local parts=n>1 and split(s.poly,n,random) or {s.poly}
   for _,q in ipairs(parts) do
    if #q>=3 and area(q)>.01 then table.insert(tiles,{poly=q,y0=s.y0,y1=s.y1,color=s.color,side=s.side}) end
   end
  end
 end
 if #tiles==0 then return nil end
 local mesh
 local ok,made=pcall(function()
  mesh=AssetService:CreateEditableMesh()
  assert(mesh,'no mesh budget')
  local rec={verts={},faces={},tiles={},topColors={},rings={},bounds=Vector3.zero,radius=.5}
  local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
  local function vertex(tile: any,p: Vector3,top: boolean): number
   local id=mesh:AddVertex(p)
   local v={id=id,base=p,pos=p,top=top,tile=tile}
   table.insert(rec.verts,v);table.insert(tile.verts,v)
   lo=lo:Min(p);hi=hi:Max(p)
   if top then rec.radius=math.max(rec.radius,math.sqrt(p.X*p.X+p.Z*p.Z)) end
   return #rec.verts
  end
  local function face(tile: any,a: number,b: number,c: number,out: Vector3,colors: {number})
   local va,vb,vc=rec.verts[a],rec.verts[b],rec.verts[c]
   if faceNormal(va.base,vb.base,vc.base):Dot(out)<0 then vb,vc=vc,vb;colors={colors[1],colors[3],colors[2]} end
   local id=mesh:AddTriangle(va.id,vb.id,vc.id)
   local nid=mesh:AddNormal(faceNormal(va.base,vb.base,vc.base))
   mesh:SetFaceNormals(id,{nid,nid,nid})
   mesh:SetFaceColors(id,colors)
   local f={id=id,n=nid,a=va,b=vb,c=vc,tile=tile,side=out.Y<.5}
   table.insert(rec.faces,f);table.insert(tile.faces,f)
  end
  for _,t in ipairs(tiles) do
   local poly=t.poly
   local cx,cz=centroid(poly)
   local tile={verts={},faces={},poly=poly,cx=cx,cz=cz,y0=t.y0,y1=t.y1,side=t.side,stone=t.color,
    -- the tile's own pose: lift along +Y and a hinge turn (pry), animated
    lift=0,angle=0,hinge=nil,anim=nil,popped=false}
   tile.sideColor=mesh:AddColor(t.color:Lerp(Color3.new(0,0,0),.28),1)
   -- Top: centre, an inner ring and the outer ring (corners and edge
   -- midpoints), so ripples have vertices to move. Sides down to y0.
   local ring={}
   for k=1,#poly do
    local a,b=poly[k],poly[k%#poly+1]
    table.insert(ring,{a[1],a[2]})
    table.insert(ring,{(a[1]+b[1])*.5,(a[2]+b[2])*.5})
   end
   local function topColor(): number
    local c=mesh:AddColor(t.color,1)
    table.insert(rec.topColors,{id=c,tile=tile})
    return c
   end
   local center=vertex(tile,Vector3.new(cx,t.y1,cz),true)
   local cc=topColor();rec.verts[center].color=cc
   local inner,outer,bottom,ic,oc={},{},{},{},{}
   for j,r in ipairs(ring) do
    inner[j]=vertex(tile,Vector3.new(cx+(r[1]-cx)*.5,t.y1,cz+(r[2]-cz)*.5),true)
    ic[j]=topColor();rec.verts[inner[j]].color=ic[j]
    outer[j]=vertex(tile,Vector3.new(r[1],t.y1,r[2]),true)
    oc[j]=topColor();rec.verts[outer[j]].color=oc[j]
    bottom[j]=vertex(tile,Vector3.new(r[1],t.y0,r[2]),false)
   end
   local n=#ring
   for j=1,n do
    local k=j%n+1
    face(tile,center,inner[j],inner[k],Vector3.yAxis,{cc,ic[j],ic[k]})
    face(tile,inner[j],outer[j],outer[k],Vector3.yAxis,{ic[j],oc[j],oc[k]})
    face(tile,inner[j],outer[k],inner[k],Vector3.yAxis,{ic[j],oc[k],ic[k]})
    local out=Vector3.new((ring[j][1]+ring[k][1])*.5-cx,0,(ring[j][2]+ring[k][2])*.5-cz)
    out=out.Magnitude>1e-6 and out.Unit or Vector3.xAxis
    local sc=tile.sideColor
    face(tile,outer[j],bottom[j],bottom[k],out,{sc,sc,sc})
    face(tile,outer[j],bottom[k],outer[k],out,{sc,sc,sc})
   end
   table.insert(rec.tiles,tile)
  end
  -- Two specks at fixed opposite corners pin the bounds symmetric about the
  -- pivot, so the part's centre is the pivot however the tiles move.
  local extent=Vector3.new(math.max(math.abs(lo.X),math.abs(hi.X)),math.max(math.abs(lo.Y),math.abs(hi.Y)),math.max(math.abs(lo.Z),math.abs(hi.Z)))+MARGIN
  local clear=mesh:AddColor(WHITE,0)
  for _,s in ipairs({-1,1}) do
   local p=extent*s
   local a=mesh:AddVertex(p);local b=mesh:AddVertex(p-Vector3.new(.002*s,0,0));local c=mesh:AddVertex(p-Vector3.new(0,0,.002*s))
   local f=mesh:AddTriangle(a,b,c);mesh:SetFaceColors(f,{clear,clear,clear})
  end
  rec.bounds=extent
  local part=AssetService:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
  part.Name='DigRockMesh';part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
  part.CastShadow=true;part.Material=Enum.Material.SmoothPlastic;part.Color=WHITE;part.DoubleSided=true
  rec.part=part;rec.mesh=mesh
  return rec
 end)
 if not ok or not made then
  if mesh then pcall(function() mesh:Destroy() end) end
  -- A missing API or setting fails every time: wedges from now on. A busy
  -- memory budget may pass later, so only count it.
  local message=tostring(made)
  if not string.find(message,'budget') and not string.find(message,'memory') then M.failed=true end
  M.lastError=message
  return nil
 end
 M.live+=1
 made.dirty=true
 return made
end

function M.destroy(rec: any)
 if not rec or rec.dead then return end
 rec.dead=true
 M.live=math.max(0,M.live-1)
 if rec.part then rec.part:Destroy() end
 if rec.mesh then pcall(function() rec.mesh:Destroy() end) end
end

-- Tile colors: the stone toward `tone` by `shade` (darker under the beam).
function M.shade(rec: any,tone: Color3,shade: number)
 for _,tile in ipairs(rec.tiles) do tile.color=tile.stone:Lerp(tone,shade) end
 rec.colorDirty=true
end

-- The hinge on edge k of a tile, turning so the tile's middle rises.
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

-- Chunks pop out: `count` tiles (unpopped first, nearest `near` if given)
-- pry up on one of their edges or lift straight out. `strength` ~ .5-1.6.
function M.pop(rec: any,count: number,strength: number,now: number,random: Random,mode: string?,near: Vector3?)
 if not rec or rec.dead then return end
 local pool={}
 for _,tile in ipairs(rec.tiles) do if not tile.popped then table.insert(pool,tile) end end
 if #pool==0 then pool=table.clone(rec.tiles) end
 if near then
  table.sort(pool,function(a,b)
   return (a.cx-near.X)^2+(a.cz-near.Z)^2<(b.cx-near.X)^2+(b.cz-near.Z)^2
  end)
 end
 for i=1,math.min(count,#pool) do
  local tile=near and pool[i] or table.remove(pool,random:NextInteger(1,#pool))
  local kind=mode or (random:NextNumber()<.6 and 'pry' or 'lift')
  local was=tile.popped
  tile.popped=true
  local anim={at=now,dur=.16,fromLift=tile.lift,fromAngle=tile.angle,kind=kind}
  if kind=='pry' then
   -- Hinge on the outer edge farthest from the piece's middle: the inner
   -- side of the chunk comes up, like rock levered out of its bed.
   local poly=tile.poly
   local best,score=1,-math.huge
   for k=1,#poly do
    local a,b=poly[k],poly[k%#poly+1]
    local s=((a[1]+b[1])*.5)^2+((a[2]+b[2])*.5)^2+random:NextNumber()*.5
    if s>score then best,score=k,s end
   end
   if not tile.hinge or not was then tile.hinge=hingeFor(tile,best) end
   anim.toAngle=snap(math.rad(9+9*random:NextNumber())*strength)+(was and tile.angle or 0)
   anim.toAngle=math.min(anim.toAngle,math.rad(38))
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

-- A ring that runs out once from `center` (local x,z): a slam, a pulse.
function M.ring(rec: any,now: number,center: Vector3,amp: number,speed: number,width: number,glow: number?)
 if not rec or rec.dead then return end
 table.insert(rec.rings,{at=now,center=center,amp=amp,speed=speed,width=width,glow=glow or 0})
 if #rec.rings>4 then table.remove(rec.rings,1) end
 rec.dirty=true
end

-- One frame. `s` (all optional):
--  ripple={amp,len,speed,center=Vector3,square=bool,glow=0..1} continuous waves
--  bulge=studs at the middle; glowColor=Color3; slide=Vector3 per side (Halver);
--  scale=number (toward the pivot); tremble=studs of per-tile shiver
function M.step(rec: any,now: number,s: any)
 if not rec or rec.dead then return end
 local ripple=s.ripple
 local rings=rec.rings
 for i=#rings,1,-1 do
  local r=rings[i]
  if (now-r.at)*math.abs(r.speed)>rec.radius+r.width*3 then table.remove(rings,i) end
 end
 local animating=false
 for _,tile in ipairs(rec.tiles) do
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
 local active=ripple~=nil or #rings>0 or (s.bulge or 0)>0 or tremble>0
 local scale=s.scale or 1
 local slide=s.slide
 if not (active or animating or rec.dirty or rec.colorDirty or scale~=(rec.lastScale or 1) or slide~=rec.lastSlide or rec.wasActive) then return end
 local moved=active or animating or rec.dirty or scale~=(rec.lastScale or 1) or slide~=rec.lastSlide or rec.wasActive
 rec.wasActive=active;rec.lastScale=scale;rec.lastSlide=slide
 local mesh=rec.mesh
 local radius=rec.radius
 local glowColor=s.glowColor or WHITE
 local glows={} -- top vertex color id -> glow amount
 if moved then
  -- Per tile: hinge turn, lift, Halver slide and shiver.
  local frames,changed={},{}
  for i,tile in ipairs(rec.tiles) do
   local f=CFrame.identity
   if tile.angle~=0 and tile.hinge then
    local h=tile.hinge
    f=CFrame.new(h.a)*CFrame.fromAxisAngle(h.dir,tile.angle*h.sign)*CFrame.new(-h.a)
   end
   local offset=Vector3.yAxis*tile.lift
   if slide and tile.side then offset+=slide*tile.side end
   if tremble>0 then
    local q=math.floor(now*36)*.71+i*3.1
    offset+=Vector3.new(math.noise(q,i,.3),math.noise(i,q,.9)*.4,math.noise(.5,i,q))*tremble
   end
   local frame=CFrame.new(offset)*f
   frames[tile]=frame
   if frame~=tile.frame or rec.dirty or scale~=1 then changed[tile]=true;tile.frame=frame end
  end
  local waves=ripple~=nil or #rings>0 or (s.bulge or 0)>0
  for _,v in ipairs(rec.verts) do
   local p=frames[v.tile]*v.base
   if v.top then
    local dy,glow=0,0
    local x,z=v.base.X,v.base.Z
    if ripple then
     local c=ripple.center or Vector3.zero
     local dx,dz=x-c.X,z-c.Z
     local r=ripple.square and math.max(math.abs(dx),math.abs(dz)) or math.sqrt(dx*dx+dz*dz)
     local env=math.clamp(1-r/(radius+.3),0,1)^.6
     local w=math.sin(TAU*(r/ripple.len-now*ripple.speed/ripple.len))
     dy+=ripple.amp*w*env
     glow=math.max(glow,(ripple.glow or 0)*math.max(0,w)*env)
    end
    for _,ring in ipairs(rings) do
     local c=ring.center
     local dx,dz=x-c.X,z-c.Z
     local r=math.sqrt(dx*dx+dz*dz)
     local t=now-ring.at
     local front=ring.speed>0 and ring.speed*t or radius+ring.speed*t
     local d=(r-front)/ring.width
     local k=math.exp(-d*d)*math.clamp(1-t*.9,0,1)*math.clamp(1-r/(radius+.6),0,1)^.4
     dy+=ring.amp*k
     glow=math.max(glow,ring.glow*k)
    end
    if (s.bulge or 0)>0 then dy+=s.bulge*math.clamp(1-(x*x+z*z)/(radius*radius),0,1) end
    -- a popped chunk rides its own pose, the waves mostly pass it by
    if v.tile.popped then dy*=.35 end
    p+=Vector3.yAxis*dy
    if v.color then glows[v.color]=glow end
   end
   if scale~=1 then p=Vector3.new(p.X*scale,p.Y,p.Z*scale) end
   if p~=v.pos then v.pos=p;mesh:SetPosition(v.id,p) end
  end
  -- Top faces follow the waves; a side only turns with its tile.
  for _,f in ipairs(rec.faces) do
   if changed[f.tile] or (waves and not f.side) or rec.settle then mesh:SetNormal(f.n,faceNormal(f.a.pos,f.b.pos,f.c.pos)) end
  end
  rec.settle=waves
 end
 -- Colors: tile shade, and the ripple crest glowing toward the attack color.
 for _,entry in ipairs(rec.topColors) do
  local tile=entry.tile
  local base=tile.color or tile.stone
  local g=glows[entry.id] or 0
  local color=g>0 and base:Lerp(glowColor,math.min(.75,g)) or base
  if entry.last~=color then entry.last=color;mesh:SetColor(entry.id,color) end
 end
 if rec.colorDirty then
  for _,tile in ipairs(rec.tiles) do mesh:SetColor(tile.sideColor,(tile.color or tile.stone):Lerp(Color3.new(0,0,0),.28)) end
 end
 rec.dirty=false;rec.colorDirty=false
end
return M
