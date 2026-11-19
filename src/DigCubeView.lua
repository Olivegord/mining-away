--!strict
-- Client view of the Dig Cube. Every client builds the same cube from the
-- replicated seed (DigCube.build). The block looks seamless: intact stretches
-- render as one block per tile, and only tiles that are cut or targeted break
-- into their small cells. While a drone cuts a chunk, a crack runs around the
-- chunk's outline and then across its split line; it only trembles at the very
-- end. On break the chunk splits into two halves that hold open with a glow
-- (the gamble), then either a gem bursts out or the halves crumble.
local DigCube=require('./DigCube')
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local V={}
V.__index=V
local BEAM_CORE=Color3.fromRGB(255,250,235)
local HOT=Color3.fromRGB(255,196,128)
local CRACK=Color3.fromRGB(34,26,22)
local GLOW=Color3.fromRGB(255,240,205)
local SHAKE_FROM=.82 -- the chunk only trembles in its last moments
local POP=.16 -- split opening time
local TIER_NAMES={'AMBER!','RUBY!','QUARTZ!','VIOLET!','DIAMOND!'}

local function rgb(t: {number}) return Color3.fromRGB(t[1],t[2],t[3]) end
local function fxPart(parent: Instance,name: string,color: Color3): Part
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.TopSurface=Enum.SurfaceType.Smooth
 p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end

function V.new(ctx: any)
 local self=setmetatable({ctx=ctx,parts={},base={},tileParts={},broken={},beams={},cracks={},splits={},banners={},
  shaking={},cube=nil,origin=Vector3.zero,generation=-1,removedString='',breaksString='',serial=0,
  random=Random.new(),connections={},tapAt=0},V)
 local folder=Instance.new('Folder');folder.Name='DigCubeView';folder.Parent=workspace
 self.folder=folder
 local fx=Instance.new('Folder');fx.Name='DigCubeFX';fx.Parent=workspace
 self.fx=fx
 self:watch()
 table.insert(self.connections,ctx.world.ChildAdded:Connect(function(child) if child.Name=='DigCube' then self:watch() end end))
 table.insert(self.connections,UIS.InputBegan:Connect(function(input,processed) self:inputBegan(input,processed) end))
 table.insert(self.connections,UIS.InputEnded:Connect(function(input,processed) self:inputEnded(input,processed) end))
 return self
end

function V:watch()
 local holder=self.ctx.world:FindFirstChild('DigCube')
 if not holder or holder==self.holder then return end
 self.holder=holder
 for _,name in ipairs({'Generation','Removed','Breaks'}) do
  table.insert(self.connections,holder:GetAttributeChangedSignal(name):Connect(function() self:sync() end))
 end
 self:sync()
end

function V:reduced(): boolean
 return self.ctx.reduced~=nil and self.ctx.reduced()==true
end

function V:clear()
 for _,model in pairs(self.parts) do model:Destroy() end
 for _,part in pairs(self.tileParts) do part:Destroy() end
 for id in pairs(self.cracks) do self:dropCrack(id) end
 self.parts={};self.base={};self.tileParts={};self.broken={};self.shaking={}
 if self.pad then self.pad:Destroy();self.pad=nil end
end

function V:layerColor(layer: number): Color3
 return rgb(DigCube.STRATA[math.min(layer,#DigCube.STRATA)])
end

function V:dress(part: BasePart,layer: number,cellId: number)
 part.Anchored=true;part.CanTouch=false;part.CanQuery=true;part.CanCollide=true
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 part.Color=self:layerColor(layer)
 part.Material=Enum.Material.SmoothPlastic
 part.Reflectance=0
 part.CastShadow=true
 part:SetAttribute('DigCell',cellId)
end

function V:wedgePart(w: any,parent: Instance): WedgePart
 local part=Instance.new('WedgePart')
 part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
 part.CFrame=CFrame.fromMatrix(self.origin+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),
  Vector3.new(w.right[1],w.right[2],w.right[3]),Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
 part.Parent=parent
 return part
end

function V:showCell(id: number)
 if self.parts[id] then return end
 local cell=self.cube.cells[id]
 local model=Instance.new('Model');model.Name='Cell'..id
 for _,w in ipairs(DigCube.wedges(cell)) do
  local part=self:wedgePart(w,model)
  self:dress(part,cell.layer,id)
  self.base[part]=part.CFrame
 end
 model.Parent=self.folder
 self.parts[id]=model
end

function V:hideCell(id: number)
 local model=self.parts[id]
 if model then
  for _,part in ipairs(model:GetChildren()) do self.base[part]=nil end
  self.parts[id]=nil;model:Destroy()
 end
end

function V:showTile(tile: any)
 if self.tileParts[tile.key] or self.broken[tile.key] then return end
 local part=Instance.new('Part');part.Name='Tile'
 part.Size=Vector3.new(tile.x1-tile.x0,tile.y1-tile.y0,tile.z1-tile.z0)
 part.CFrame=CFrame.new(self.origin+Vector3.new((tile.x0+tile.x1)*.5,(tile.y0+tile.y1)*.5,(tile.z0+tile.z1)*.5))
 self:dress(part,tile.layer,0)
 part.Parent=self.folder
 self.tileParts[tile.key]=part
end

-- A cell renders on its own when air touches it and no intact tile stands in for it.
function V:needed(id: number): boolean
 local cube=self.cube
 if cube.removed[id] then return false end
 local cell=cube.cells[id]
 local brokenOver=false
 for _,key in ipairs(self.cellTiles[id]) do if self.broken[key] then brokenOver=true;break end end
 if brokenOver and (cell.layer==1 or cell.boundary) then return true end
 return cell.layer>1 and DigCube.visible(cube,id)
end

function V:refresh(id: number)
 if self:needed(id) then self:showCell(id) else self:hideCell(id) end
end

-- Break every tile over these cells into its cells; adds the cells to refresh.
function V:breakTiles(ids: {number},touched: {[number]:boolean})
 for _,id in ipairs(ids) do
  for _,key in ipairs(self.cellTiles[id]) do
   if not self.broken[key] then
    self.broken[key]=true
    local part=self.tileParts[key];if part then part:Destroy();self.tileParts[key]=nil end
    for _,other in ipairs(self.tiles[key].cells) do touched[other]=true end
   end
  end
 end
end

function V:buildPad()
 local W=self.cube.width
 local at=self.origin+Vector3.new(-5,0,W*.5)
 local pad=Instance.new('Part');pad.Name='DigLaunchPad'
 pad.Shape=Enum.PartType.Cylinder;pad.Size=Vector3.new(.5,7,7)
 pad.CFrame=CFrame.new(at+Vector3.new(0,.25,0))*CFrame.Angles(0,0,math.rad(90))
 pad.Anchored=true;pad.CanCollide=false;pad.CanQuery=false;pad.CanTouch=false
 pad.Material=Enum.Material.Neon;pad.Color=Color3.fromRGB(255,176,72);pad.Transparency=.15
 pad.Parent=self.folder
 local emitter=Instance.new('ParticleEmitter')
 emitter.Texture='rbxasset://textures/particles/sparkles_main.dds'
 emitter.Color=ColorSequence.new(Color3.fromRGB(255,206,120))
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)})
 emitter.Lifetime=NumberRange.new(.8,1.3);emitter.Rate=14;emitter.Speed=NumberRange.new(9,14)
 emitter.EmissionDirection=Enum.NormalId.Right;emitter.SpreadAngle=Vector2.new(8,8);emitter.LightEmission=.6
 emitter.Parent=pad
 self.pad=pad;self.padAt=at
end

local function parseBreaks(s: string)
 local out={}
 for entry in string.gmatch(s,'[^;]+') do
  local serial,tier,key=string.match(entry,'^(%d+):(%d+):(.+)$')
  if serial then table.insert(out,{serial=tonumber(serial) :: number,tier=tonumber(tier) :: number,ids=DigCube.parseKey(key :: string)}) end
 end
 return out
end

function V:sync()
 local holder=self.holder
 if not holder then return end
 local seed=holder:GetAttribute('Seed');local generation=holder:GetAttribute('Generation') or 0
 local origin=holder:GetAttribute('Origin')
 if type(seed)~='number' or typeof(origin)~='Vector3' then return end
 if generation~=self.generation then
  self:clear()
  self.generation=generation;self.origin=origin
  self.cube=DigCube.build(seed)
  self.tiles,self.cellTiles=DigCube.tiles(self.cube)
  for _,tile in pairs(self.tiles) do self:showTile(tile) end
  self.removedString='';self.breaksString=''
  -- Breaks from before this client saw the cube are not replayed.
  local serial=0
  for _,b in ipairs(parseBreaks(holder:GetAttribute('Breaks') or '')) do serial=math.max(serial,b.serial) end
  self.serial=serial
  self:buildPad()
 end
 local cube=self.cube
 local now=os.clock()
 local touched={}
 local fresh={}
 -- Breaks first, so a chunk splits open in the same frame its cells disappear.
 local breaks=holder:GetAttribute('Breaks')
 if type(breaks)=='string' and breaks~=self.breaksString then
  self.breaksString=breaks
  for _,b in ipairs(parseBreaks(breaks)) do
   if b.serial>self.serial then
    self.serial=b.serial
    local valid=#b.ids>0
    for _,id in ipairs(b.ids) do if not cube.cells[id] then valid=false end end
    if valid then
     self:split(b.ids,b.tier,now)
     for _,id in ipairs(b.ids) do
      if not cube.removed[id] then cube.removed[id]=true;cube.removedCount+=1;table.insert(fresh,id) end
     end
    end
   end
  end
 end
 local s=holder:GetAttribute('Removed')
 if type(s)=='string' and s~=self.removedString then
  self.removedString=s
  for id in pairs(DigCube.decode(cube,s)) do
   if not cube.removed[id] then cube.removed[id]=true;cube.removedCount+=1;table.insert(fresh,id) end
  end
 end
 if #fresh==0 then return end
 self:breakTiles(fresh,touched)
 for _,id in ipairs(fresh) do
  touched[id]=true
  for _,other in ipairs(DigCube.affected(cube,id)) do touched[other]=true end
 end
 for id in pairs(touched) do self:refresh(id) end
end

-- Two halves along the chunk's split line, held open while the gem rolls.
function V:split(ids: {number},tier: number,now: number)
 local cube=self.cube
 local sp=DigCube.split(cube,ids)
 local color=self:layerColor(sp.layer)
 local thick=sp.y1-sp.y0
 local n=Vector3.new(sp.nx,0,sp.nz)
 local hinge=CFrame.fromMatrix(self.origin+Vector3.new(sp.cx,sp.y0,sp.cz),n,Vector3.yAxis)
 local entry={at=now,tier=tier,hinge=hinge,halves={},thick=thick,color=color,
  center=self.origin+Vector3.new(sp.cx,(sp.y0+sp.y1)*.5,sp.cz),top=self.origin+Vector3.new(sp.cx,sp.y1,sp.cz),revealed=false}
 for index,polys in ipairs({sp.a,sp.b}) do
  local model=Instance.new('Model');model.Name='DigHalf'
  local list={}
  for _,poly in ipairs(polys) do
   for _,w in ipairs(DigCube.polyWedges(poly,sp.y0,sp.y1)) do
    local part=self:wedgePart(w,model)
    part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
    part.Material=Enum.Material.SmoothPlastic;part.Color=color;part.CastShadow=true
    table.insert(list,{part=part,rel=hinge:ToObjectSpace(part.CFrame)})
   end
  end
  model.Parent=self.fx
  entry.halves[index]={model=model,parts=list,side=index==1 and -1 or 1}
 end
 -- The seam: a glowing plate along the split line, inside the opening.
 local span=0
 local t=Vector3.new(-sp.nz,0,sp.nx)
 for _,c in ipairs(sp.chords) do
  for _,v in ipairs({{c.ax,c.az},{c.bx,c.bz}}) do span=math.max(span,math.abs((v[1]-sp.cx)*t.X+(v[2]-sp.cz)*t.Z)) end
 end
 local seam=fxPart(self.fx,'DigSeam',GLOW)
 seam.Material=Enum.Material.Neon;seam.Size=Vector3.new(.12,thick*.85,math.max(1,span*2*.9))
 seam.CFrame=hinge*CFrame.new(0,thick*.5,0);seam.Transparency=1
 local light=Instance.new('PointLight');light.Color=GLOW;light.Range=math.clamp(span*2.5,8,18);light.Brightness=0;light.Shadows=false
 light.Parent=seam
 entry.seam=seam;entry.light=light
 table.insert(self.splits,entry)
 local ctx=self.ctx
 local size=math.sqrt((DigCube.chunkArea(cube,ids)))
 if ctx.audio then ctx.audio:play('crystal_split',entry.center,{rockSize=size}) end
 if not self:reduced() then
  if ctx.presentation and ctx.presentation.work then
   ctx.presentation.work:burst(entry.top,Vector3.yAxis,color,math.clamp(math.floor(size*2.4),10,26),workspace:GetServerTimeNow())
  end
  if ctx.beat then ctx.beat('Split',entry.center,workspace:GetServerTimeNow(),math.clamp(size/8,.5,1.2)) end
 end
end

function V:reveal(entry: any)
 entry.revealed=true
 local ctx=self.ctx
 if entry.tier>0 then
  local ore=DigCube.ORES[entry.tier]
  local color=rgb(ore.color)
  entry.seam.Color=color:Lerp(Color3.new(1,1,1),.25);entry.light.Color=color
  if ctx.audio then ctx.audio:play('gem_reveal',entry.top,{pitch=1+entry.tier*.08,level=1}) end
  if not self:reduced() then
   if ctx.presentation and ctx.presentation.work then
    ctx.presentation.work:burst(entry.top,Vector3.yAxis,color,22+entry.tier*4,workspace:GetServerTimeNow())
   end
   if ctx.beat then ctx.beat(entry.tier>=3 and 'HeavySplit' or 'Split',entry.center,workspace:GetServerTimeNow(),math.min(1.4,.7+entry.tier*.15)) end
  end
  self:banner(entry.top,TIER_NAMES[entry.tier] or 'GEM!',color)
 else
  if ctx.audio then ctx.audio:play('crystal_fall_tink',entry.center,{pitch=.8,level=.7}) end
  if not self:reduced() and ctx.presentation and ctx.presentation.work then
   ctx.presentation.work:burst(entry.top,Vector3.yAxis,entry.color,8,workspace:GetServerTimeNow())
  end
 end
end

function V:banner(at: Vector3,text: string,color: Color3)
 local anchor=fxPart(self.fx,'DigReveal',color);anchor.Transparency=1;anchor.Size=Vector3.one*.1;anchor.Position=at+Vector3.yAxis*2
 local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromOffset(220,64);gui.AlwaysOnTop=true;gui.LightInfluence=0
 gui.MaxDistance=140;gui.Adornee=anchor;gui.Parent=anchor
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
 label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.Text=text;label.TextColor3=color
 label.TextStrokeTransparency=0;label.TextStrokeColor3=Color3.fromRGB(20,16,30);label.Parent=gui
 local scale=Instance.new('UIScale');scale.Scale=.2;scale.Parent=gui
 table.insert(self.banners,{anchor=anchor,label=label,scale=scale,at=os.clock(),from=anchor.Position})
end

function V:stepSplits(now: number)
 local pause=DigCube.PAUSE
 local reduced=self:reduced()
 for i=#self.splits,1,-1 do
  local e=self.splits[i]
  local age=now-e.at
  if age>=pause and not e.revealed then self:reveal(e) end
  if age>=pause+.7 then
   for _,h in ipairs(e.halves) do h.model:Destroy() end
   e.seam:Destroy()
   table.remove(self.splits,i)
  else
   local fade,tremble=0,0
   local pop=reduced and 1 or 1-(1-math.clamp(age/POP,0,1))^3
   local open,gap,lift=.11*pop,.22*pop,math.min(.35,e.thick*.08)*pop
   if age<pause then
    -- The hold: still, with the glow in the crack building toward the reveal.
    local hold=math.clamp((age-POP)/(pause-POP),0,1)
    tremble=reduced and 0 or .025*hold
    e.seam.Transparency=1-(.25+.6*hold)
    e.light.Brightness=.4+2.6*hold
   else
    local q=math.clamp((age-pause)/.6,0,1)
    if e.tier>0 then
     local fly=1-(1-q)^2
     open+=.8*fly;gap+=1.8*fly;lift+=.6*fly
     e.seam.Transparency=q;e.light.Brightness=4*(1-q)
    else
     lift-=e.thick*.7*q*q
     e.seam.Transparency=.6+.4*q;e.light.Brightness=1.5*(1-q)
    end
    fade=math.clamp((q-.35)/.65,0,1)
   end
   for _,h in ipairs(e.halves) do
    local jx=tremble>0 and math.sin(now*57+h.side)*tremble or 0
    local jz=tremble>0 and math.cos(now*49+h.side)*tremble or 0
    local frame=e.hinge*CFrame.new(h.side*gap+jx,lift,jz)*CFrame.Angles(0,0,-h.side*open)
    for _,item in ipairs(h.parts) do
     item.part.CFrame=frame*item.rel
     item.part.Transparency=fade
    end
   end
  end
 end
 for i=#self.banners,1,-1 do
  local b=self.banners[i];local t=now-b.at
  if t>=1.6 then b.anchor:Destroy();table.remove(self.banners,i)
  else
   b.scale.Scale=t<.18 and .2+1.1*(t/.18) or 1.3-.3*math.clamp((t-.18)/.15,0,1)
   b.anchor.Position=b.from+Vector3.yAxis*(t*1.4)
   local fade=math.clamp((t-1.1)/.5,0,1)
   b.label.TextTransparency=fade;b.label.TextStrokeTransparency=fade
  end
 end
end

-- Crack overlay for one drone's chunk: thin lines along the outline that run
-- around it as the cut progresses, then the split line across it.
function V:buildCrack(droneId: string,key: string)
 local cube=self.cube
 local ids=DigCube.parseKey(key)
 if #ids==0 then return nil end
 for _,id in ipairs(ids) do if not cube.cells[id] or cube.removed[id] then return nil end end
 local edges,cx,cz=DigCube.outline(cube,ids)
 for _,e in ipairs(edges) do
  local a1=math.atan2(e.az-cz,e.ax-cx);local a2=math.atan2(e.bz-cz,e.bx-cx)
  local d=(a2-a1+math.pi)%(2*math.pi)-math.pi
  if d<0 then e.ax,e.az,e.bx,e.bz=e.bx,e.bz,e.ax,e.az end
 end
 local total=0
 for _,e in ipairs(edges) do e.start=total;total+=e.len end
 local sp=DigCube.split(cube,ids)
 local crack={key=key,ids=ids,edges=edges,total=total,chords=sp.chords,y=cube.cells[ids[1]].y1,parts={},seams={},progress=0,seen=0}
 local touched={}
 self:breakTiles(ids,touched)
 for id in pairs(touched) do self:refresh(id) end
 self.cracks[droneId]=crack
 return crack
end

function V:dropCrack(droneId: string)
 local crack=self.cracks[droneId]
 if not crack then return end
 for _,p in pairs(crack.parts) do p:Destroy() end
 for _,p in pairs(crack.seams) do p:Destroy() end
 self.cracks[droneId]=nil
end

function V:line(list: {[number]:Part},index: number,ax: number,az: number,bx: number,bz: number,y: number,width: number,color: Color3,neon: boolean)
 local part=list[index]
 local length=math.sqrt((bx-ax)^2+(bz-az)^2)
 if length<.03 then if part then part.Transparency=1 end;return end
 if not part then part=fxPart(self.fx,'DigCrack',color);list[index]=part end
 local a=self.origin+Vector3.new(ax,y,az);local b=self.origin+Vector3.new(bx,y,bz)
 part.Size=Vector3.new(width,.06,length+width*.6)
 part.CFrame=CFrame.lookAt((a+b)*.5,b)
 part.Color=color;part.Material=neon and Enum.Material.Neon or Enum.Material.SmoothPlastic;part.Transparency=0
end

function V:drawCrack(crack: any)
 local p=crack.progress
 local heat=math.clamp((p-SHAKE_FROM+.06)/(1-SHAKE_FROM+.06),0,1)
 local color=CRACK:Lerp(HOT,heat)
 local width=.11+.09*p
 local y=crack.y+.03
 -- The outline runs around the chunk over most of the cut.
 local reach=math.clamp((p-.03)/.67,0,1)*crack.total
 for i,e in ipairs(crack.edges) do
  local r=math.clamp((reach-e.start)/e.len,0,1)
  if r<=0 then
   if crack.parts[i] then crack.parts[i].Transparency=1 end
  else
   self:line(crack.parts,i,e.ax,e.az,e.ax+(e.bx-e.ax)*r,e.az+(e.bz-e.az)*r,y,width,color,heat>0)
  end
 end
 -- Then the split line opens across it from the middle outward.
 local g=math.clamp((p-.68)/.24,0,1)
 for i,c in ipairs(crack.chords) do
  if g<=0 then
   if crack.seams[i] then crack.seams[i].Transparency=1 end
  else
   local mx,mz=(c.ax+c.bx)*.5,(c.az+c.bz)*.5
   self:line(crack.seams,i,mx+(c.ax-mx)*g,mz+(c.az-mz)*g,mx+(c.bx-mx)*g,mz+(c.bz-mz)*g,y+.005,width*1.1,CRACK:Lerp(GLOW,.25+.75*heat),heat>0)
  end
 end
end

-- One beam per digging drone, from its rendered emitter to its chunk.
function V:droneBeam(source: Instance,from: Vector3,now: number,color: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' or not self.cube then return end
 local key=source:GetAttribute('DigChunk')
 if type(key)~='string' then key='' end
 local crack=self.cracks[id]
 if crack and crack.key~=key then self:dropCrack(id);crack=nil end
 if not crack and key~='' then crack=self:buildCrack(id,key) end
 local progress=source:GetAttribute('DigProgress') or 0
 if crack then
  crack.progress=math.max(crack.progress,progress);crack.seen=now
  if crack.progress>=SHAKE_FROM then
   for _,cell in ipairs(crack.ids) do self.shaking[cell]=crack.progress end
  end
 end
 local active=crack~=nil and source:GetAttribute('DigMining')==true and source:GetAttribute('WorkPaused')~=true
 local beam=self.beams[id]
 if not active then
  if beam then beam.core.Transparency=1;beam.glow.Transparency=1;beam.spot.Transparency=1 end
  return
 end
 if not beam then
  local function rod(name: string,c: Color3)
   local p=fxPart(self.fx,name,c);p.Shape=Enum.PartType.Cylinder;p.Material=Enum.Material.Neon
   return p
  end
  beam={core=rod('DigBeamCore',BEAM_CORE),glow=rod('DigBeamGlow',color or HOT),spot=rod('DigBeamSpot',color or HOT)}
  beam.spot.Shape=Enum.PartType.Ball
  self.beams[id]=beam
 end
 local point=source:GetAttribute('DigPoint')
 if typeof(point)~='Vector3' then return end
 local to=point+Vector3.new(0,.15,0)
 local length=(to-from).Magnitude
 if length<.1 then return end
 local mid=(from+to)*.5
 local frame=CFrame.lookAt(mid,to)*CFrame.Angles(0,math.rad(90),0)
 local pulse=.5+.5*math.sin(now*38)
 beam.core.Size=Vector3.new(length,.16+.04*pulse,.16+.04*pulse);beam.core.CFrame=frame;beam.core.Transparency=0
 beam.glow.Color=color or HOT
 beam.glow.Size=Vector3.new(length,.5+.12*pulse,.5+.12*pulse);beam.glow.CFrame=frame;beam.glow.Transparency=.55
 beam.spot.Color=(color or HOT):Lerp(BEAM_CORE,.4)
 local r=.9+.6*progress+.2*pulse
 beam.spot.Size=Vector3.new(r,r,r);beam.spot.CFrame=CFrame.new(to);beam.spot.Transparency=.25
 if self.ctx.presentation and self.ctx.presentation.work and now>=(beam.sparkAt or 0) then
  beam.sparkAt=now+.18
  self.ctx.presentation.work:burst(to,Vector3.yAxis,color or HOT,6,workspace:GetServerTimeNow())
 end
end

function V:stepCracks(now: number)
 for id,crack in pairs(self.cracks) do
  if now-crack.seen>.3 then self:dropCrack(id) else self:drawCrack(crack) end
 end
end

-- Only the last moments of a cut tremble, and the chunk heats up as it goes.
function V:stepShake(now: number)
 local reduced=self:reduced()
 for id,model in pairs(self.parts) do
  local progress=self.shaking[id]
  local was=model:GetAttribute('Shaking')
  if progress then
   local cell=self.cube.cells[id]
   local base=self:layerColor(cell.layer)
   local q=math.clamp((progress-SHAKE_FROM)/(1-SHAKE_FROM),0,1)
   local amp=reduced and 0 or .03+.11*q
   local offset=Vector3.new(math.sin(now*61+id)*amp,0,math.cos(now*53+id*2)*amp)
   for _,part in ipairs(model:GetChildren()) do
    local cf=self.base[part]
    if cf and part:IsA('BasePart') then part.CFrame=cf+offset;part.Color=base:Lerp(HOT,.3*q) end
   end
   model:SetAttribute('Shaking',true)
  elseif was then
   local cell=self.cube.cells[id];local base=self:layerColor(cell.layer)
   for _,part in ipairs(model:GetChildren()) do
    local cf=self.base[part]
    if cf and part:IsA('BasePart') then part.CFrame=cf;part.Color=base end
   end
   model:SetAttribute('Shaking',nil)
  end
 end
 self.shaking={}
end

function V:stepPad(now: number)
 local pad=self.pad;if not pad or not self.cube then return end
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 pad.Transparency=.15+.12*math.sin(now*4)
 if not root or not root:IsA('BasePart') or now<(self.launchedAt or 0)+1.2 then return end
 local offset=root.Position-self.padAt
 if Vector3.new(offset.X,0,offset.Z).Magnitude<3.6 and offset.Y<6 then
  self.launchedAt=now
  local rise=self.cube.height+8
  local up=math.sqrt(2*workspace.Gravity*rise)
  root.AssemblyLinearVelocity=Vector3.new(16,up,0)
  if self.ctx.audio then self.ctx.audio:play('crystal_split',root.Position,{rockSize=3}) end
 end
end

function V:inputBegan(input: InputObject,processed: boolean)
 if processed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  self.pressAt=os.clock();self.pressPosition=Vector2.new(input.Position.X,input.Position.Y)
 end
end

function V:inputEnded(input: InputObject,processed: boolean)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 local at,position=self.pressAt,self.pressPosition
 self.pressAt=nil
 if processed or not at or not position or os.clock()-at>.45 then return end
 if (Vector2.new(input.Position.X,input.Position.Y)-position).Magnitude>14 then return end
 if os.clock()<self.tapAt+.3 then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local ray=camera:ViewportPointToRay(position.X,position.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={self.folder}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*400,params)
 if not hit or hit.Instance:GetAttribute('DigCell')==nil then return end
 self.tapAt=os.clock()
 self.ctx.command:FireServer('DigFocus',{point=hit.Position})
 if self.ctx.presentation and self.ctx.presentation.work then
  self.ctx.presentation.work:burst(hit.Position,hit.Normal,Color3.fromRGB(255,232,170),10,workspace:GetServerTimeNow())
 end
end

function V:update()
 local now=os.clock()
 self:stepCracks(now)
 self:stepShake(now)
 self:stepSplits(now)
 self:stepPad(now)
end

function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 self:clear()
 self.folder:Destroy();self.fx:Destroy()
end
return V
