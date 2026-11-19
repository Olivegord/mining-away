--!strict
-- Client view of the Dig Cube (3D Voronoi cells). Every client builds the same
-- cube from the replicated seed. Rock color runs on a gradient from sand at the
-- top to slate at the bottom so pit depth reads at a glance. The block looks
-- seamless: the intact top and walls render as one slab per tile, and only
-- faces that touch air are drawn once a tile breaks.
-- While a drone cuts a cell, cracks spread out along the cell's edges from the
-- beam's contact point, the cell darkens with damage, and near the end the
-- split line glows across it; only the last moments tremble. On break the cell
-- splits into two clear halves that jump apart with chips and dust, hold open
-- with a glow (the gamble), then either a gem bursts out or the halves crumble.
local DigCube=require('./DigCube')
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local V={}
V.__index=V
local BEAM_CORE=Color3.fromRGB(255,250,235)
local HOT=Color3.fromRGB(255,170,90)
local CRACK=Color3.fromRGB(28,22,20)
local GLOW=Color3.fromRGB(255,240,205)
local FRESH=Color3.fromRGB(255,246,226)
local SHAKE_FROM=.82 -- the cell only trembles in its last moments
local POP=.2
local GRAVITY=70
local TIER_NAMES={'AMBER!','RUBY!','QUARTZ!','VIOLET!','DIAMOND!'}

local function rgb(t: {number}) return Color3.fromRGB(t[1],t[2],t[3]) end
local function vec(t: {number}) return Vector3.new(t[1],t[2],t[3]) end
local function fxPart(parent: Instance,name: string,color: Color3,class: string?): BasePart
 local p=Instance.new((class or 'Part') :: any) :: BasePart
 p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.TopSurface=Enum.SurfaceType.Smooth
 p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end

function V.new(ctx: any)
 local self=setmetatable({ctx=ctx,models={},sig={},base={},tileParts={},broken={},beams={},cracks={},splits={},debris={},
  banners={},damage={},cube=nil,origin=Vector3.zero,generation=-1,removedString='',breaksString='',serial=0,
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
 for _,model in pairs(self.models) do model:Destroy() end
 for _,part in pairs(self.tileParts) do part:Destroy() end
 for id in pairs(self.cracks) do self:dropCrack(id) end
 self.models={};self.sig={};self.base={};self.tileParts={};self.broken={};self.damage={}
 if self.pad then self.pad:Destroy();self.pad=nil end
end

function V:colorAt(y: number): Color3
 return rgb(DigCube.gradient(y,self.cube.height))
end

function V:dress(part: BasePart,color: Color3,cellId: number)
 part.Anchored=true;part.CanTouch=false;part.CanQuery=true;part.CanCollide=true
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 part.Color=color;part.Material=Enum.Material.SmoothPlastic;part.Reflectance=0;part.CastShadow=true
 part:SetAttribute('DigCell',cellId)
end

function V:wedge(w: any,parent: Instance,offset: Vector3?): WedgePart
 local part=Instance.new('WedgePart')
 part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
 part.CFrame=CFrame.fromMatrix((offset or self.origin)+vec(w.pos),vec(w.right),vec(w.up),vec(w.back))
 part.Parent=parent
 return part
end

-- Faces of a cell that touch air and are not covered by an intact tile.
function V:openFaces(id: number): {number}
 local cube=self.cube
 local out={}
 if cube.removed[id] then return out end
 local perFace=self.faceTiles[id]
 for fi,f in ipairs(cube.cells[id].faces) do
  if f.label>0 then
   if cube.removed[f.label] then table.insert(out,fi) end
  elseif f.label<-1 then
   for _,key in ipairs(perFace[fi] or {}) do if self.broken[key] then table.insert(out,fi);break end end
  end
 end
 return out
end

function V:refresh(id: number)
 local faces=self:openFaces(id)
 local sig=table.concat(faces,',')
 if sig==(self.sig[id] or '') then return end
 local old=self.models[id]
 if old then for _,p in ipairs(old:GetChildren()) do self.base[p]=nil end;old:Destroy();self.models[id]=nil end
 self.sig[id]=sig
 if #faces==0 then return end
 local model=Instance.new('Model');model.Name='Cell'..id
 local cell=self.cube.cells[id]
 for _,fi in ipairs(faces) do
  for _,w in ipairs(DigCube.faceWedges(cell.faces[fi],.5)) do
   local part=self:wedge(w,model)
   self:dress(part,self:colorAt(w.y),id)
   self.base[part]=part.CFrame
  end
 end
 model.Parent=self.folder
 self.models[id]=model
end

function V:showTile(tile: any)
 if self.tileParts[tile.key] or self.broken[tile.key] then return end
 local W,H=self.cube.width,self.cube.height
 local du,dv=tile.u1-tile.u0,tile.v1-tile.v0
 local um,vm=(tile.u0+tile.u1)*.5,(tile.v0+tile.v1)*.5
 local size,center
 if tile.side==-2 then size,center=Vector3.new(du,.6,dv),Vector3.new(um,H-.3,vm)
 elseif tile.side==-3 then size,center=Vector3.new(.6,dv,du),Vector3.new(.3,vm,um)
 elseif tile.side==-4 then size,center=Vector3.new(.6,dv,du),Vector3.new(W-.3,vm,um)
 elseif tile.side==-5 then size,center=Vector3.new(du,dv,.6),Vector3.new(um,vm,.3)
 else size,center=Vector3.new(du,dv,.6),Vector3.new(um,vm,W-.3) end
 local part=Instance.new('Part');part.Name='Tile';part.Size=size
 part.CFrame=CFrame.new(self.origin+center)
 self:dress(part,self:colorAt(center.Y),0)
 part.Parent=self.folder
 self.tileParts[tile.key]=part
end

-- Break every tile over these cells; adds the cells to refresh.
function V:breakTiles(ids: {number},touched: {[number]:boolean})
 for _,id in ipairs(ids) do
  for _,list in pairs(self.faceTiles[id] or {}) do
   for _,key in ipairs(list) do
    if not self.broken[key] then
     self.broken[key]=true
     local part=self.tileParts[key];if part then part:Destroy();self.tileParts[key]=nil end
     for _,ref in ipairs(self.tiles[key].faces) do touched[ref[1]]=true end
    end
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
  self.tiles,self.faceTiles=DigCube.tiles(self.cube)
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
 local fresh={}
 -- Breaks first, so a cell splits open in the same frame it disappears.
 local breaks=holder:GetAttribute('Breaks')
 if type(breaks)=='string' and breaks~=self.breaksString then
  self.breaksString=breaks
  for _,b in ipairs(parseBreaks(breaks)) do
   if b.serial>self.serial then
    self.serial=b.serial
    local valid=#b.ids>0
    for _,id in ipairs(b.ids) do if not cube.cells[id] or cube.removed[id] then valid=false end end
    if valid then
     self:split(b.ids,b.tier,now)
     for _,id in ipairs(b.ids) do cube.removed[id]=true;cube.removedCount+=1;table.insert(fresh,id) end
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
 local touched={}
 self:breakTiles(fresh,touched)
 for _,id in ipairs(fresh) do
  touched[id]=true
  for _,other in ipairs(cube.cells[id].neighbors) do touched[other]=true end
 end
 for id in pairs(touched) do self:refresh(id) end
end

-- A closed piece (list of faces) as wedges in a model, with each part's
-- offset from `frame` so the whole piece can move as one.
function V:piece(faces: {any},frame: CFrame,cutColor: Color3?)
 local model=Instance.new('Model');model.Name='DigPiece'
 local list={}
 for _,f in ipairs(faces) do
  for _,w in ipairs(DigCube.faceWedges(f,.35)) do
   local part=self:wedge(w,model)
   part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
   part.Material=Enum.Material.SmoothPlastic;part.CastShadow=true
   part.Color=f.label==0 and cutColor or self:colorAt(w.y)
   table.insert(list,{part=part,rel=frame:ToObjectSpace(part.CFrame)})
  end
 end
 model.Parent=self.fx
 return model,list
end

-- Small rock chips that fly, tumble, land, bounce once and fade.
function V:chips(at: Vector3,color: Color3,count: number,speed: number,floor: number,now: number)
 if self:reduced() then return end
 for i=1,count do
  if #self.debris>=90 then break end
  local s=self.random:NextNumber(.35,.8)
  local chip=fxPart(self.fx,'DigChip',color:Lerp(Color3.new(1,1,1),self.random:NextNumber(0,.15)),'WedgePart')
  chip.Size=Vector3.new(s*.7,s,s*1.2);chip.CastShadow=true
  local a=i*2.399963+self.random:NextNumber(0,.6)
  local v=Vector3.new(math.cos(a),0,math.sin(a))*speed*self.random:NextNumber(.5,1)+Vector3.yAxis*self.random:NextNumber(12,20)
  local axis=Vector3.new(self.random:NextNumber(-1,1),self.random:NextNumber(-1,1),self.random:NextNumber(-1,1))
  table.insert(self.debris,{part=chip,at=now,from=at,v=v,axis=axis.Magnitude>.05 and axis.Unit or Vector3.xAxis,
   spin=self.random:NextNumber(6,12),floor=floor+s*.5,life=self.random:NextNumber(1,1.4),size=chip.Size})
 end
end

function V:stepDebris(now: number)
 for i=#self.debris,1,-1 do
  local d=self.debris[i];local t=now-d.at
  if t>=d.life then d.part:Destroy();table.remove(self.debris,i)
  else
   local pos=d.from+d.v*t-Vector3.yAxis*(GRAVITY*.5*t*t)
   if pos.Y<=d.floor then
    if not d.landed then
     d.landed=t;d.landAt=Vector3.new(pos.X,d.floor,pos.Z);d.bounce=math.min(8,math.abs(d.v.Y-GRAVITY*t)*.25)
    end
    local age=t-d.landed
    pos=d.landAt+Vector3.new(d.v.X*.08*age,math.max(0,d.bounce*age-GRAVITY*.5*age*age),d.v.Z*.08*age)
   end
   local spin=d.spin*(d.landed or t)
   local fade=math.clamp((t/d.life-.6)/.4,0,1)
   d.part.Size=d.size*(1-.6*fade)
   d.part.CFrame=CFrame.new(pos)*CFrame.fromAxisAngle(d.axis,spin)
   d.part.Transparency=fade
  end
 end
end

-- The break: the cell splits into two halves that jump apart, hold open while
-- the gem rolls, then burst (gem) or crumble (nothing). Cells blasted out with
-- it by a bigger cut fly off whole.
function V:split(ids: {number},tier: number,now: number)
 local cube=self.cube
 local id=ids[1]
 local cell=cube.cells[id]
 local sp=DigCube.split(cube,id)
 local center=self.origin+vec(sp.center)
 local n=vec(sp.normal)
 local up=(Vector3.yAxis-n*n.Y)
 up=up.Magnitude>.05 and up.Unit or Vector3.zAxis
 local frame=CFrame.fromMatrix(center,n,up)
 local color=self:colorAt(cell.cy)
 local cut=color:Lerp(FRESH,.45)
 local entry={at=now,tier=tier,frame=frame,halves={},pieces={},color=color,center=center,
  floor=self.origin.Y+cell.minY,size=cell.volume^(1/3),revealed=false}
 for index,faces in ipairs({sp.a,sp.b}) do
  local model,list=self:piece(faces,frame,cut)
  entry.halves[index]={model=model,parts=list,side=index==1 and -1 or 1}
 end
 for i=2,math.min(#ids,7) do
  local other=cube.cells[ids[i]]
  local at=self.origin+Vector3.new(other.cx,other.cy,other.cz)
  local model,list=self:piece(other.faces,CFrame.new(at))
  local out=(at-center);out=out.Magnitude>.1 and out.Unit or Vector3.yAxis
  table.insert(entry.pieces,{model=model,parts=list,from=CFrame.new(at),v=out*self.random:NextNumber(10,16)+Vector3.yAxis*self.random:NextNumber(14,22),
   axis=Vector3.new(self.random:NextNumber(-1,1),1,self.random:NextNumber(-1,1)).Unit,spin=self.random:NextNumber(3,6)})
 end
 -- The seam: a glowing plate in the opening between the halves.
 local seam=fxPart(self.fx,'DigSeam',GLOW)
 seam.Material=Enum.Material.Neon;seam.Size=Vector3.new(.15,entry.size*.8,entry.size*.8)
 seam.CFrame=frame;seam.Transparency=1
 local light=Instance.new('PointLight');light.Color=GLOW;light.Range=math.clamp(entry.size*2.6,10,20);light.Brightness=0;light.Shadows=false
 light.Parent=seam
 entry.seam=seam;entry.light=light
 table.insert(self.splits,entry)
 local ctx=self.ctx
 if ctx.audio then ctx.audio:play('crystal_split',center,{rockSize=entry.size}) end
 self:chips(center+Vector3.yAxis*entry.size*.3,color,10+math.min(10,(#ids-1)*3),8,entry.floor,now)
 if not self:reduced() then
  if ctx.presentation and ctx.presentation.work then
   ctx.presentation.work:burst(center,Vector3.yAxis,color,math.clamp(math.floor(entry.size*3),14,30),workspace:GetServerTimeNow())
  end
  if ctx.beat then ctx.beat(#ids>1 and 'HeavySplit' or 'Split',center,workspace:GetServerTimeNow(),math.clamp(entry.size/8+(#ids-1)*.1,.6,1.4)) end
 end
end

function V:reveal(e: any,now: number)
 e.revealed=true
 local ctx=self.ctx
 if e.tier>0 then
  local color=rgb(DigCube.ORES[e.tier].color)
  e.seam.Color=color:Lerp(Color3.new(1,1,1),.25);e.light.Color=color
  if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1+e.tier*.08,level=1}) end
  self:chips(e.center,color,12+e.tier*2,12,e.floor,now)
  if not self:reduced() then
   if ctx.presentation and ctx.presentation.work then
    ctx.presentation.work:burst(e.center,Vector3.yAxis,color,24+e.tier*4,workspace:GetServerTimeNow())
   end
   if ctx.beat then ctx.beat(e.tier>=3 and 'HeavySplit' or 'Split',e.center,workspace:GetServerTimeNow(),math.min(1.4,.7+e.tier*.15)) end
  end
  self:banner(e.center+Vector3.yAxis*e.size*.5,TIER_NAMES[e.tier] or 'GEM!',color)
 else
  if ctx.audio then ctx.audio:play('crystal_fall_tink',e.center,{pitch=.8,level=.7}) end
  self:chips(e.center,e.color,8,5,e.floor,now)
  if not self:reduced() and ctx.presentation and ctx.presentation.work then
   ctx.presentation.work:burst(e.center,Vector3.yAxis,e.color,10,workspace:GetServerTimeNow())
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
  if age>=pause and not e.revealed then self:reveal(e,now) end
  if age>=pause+.75 then
   for _,h in ipairs(e.halves) do h.model:Destroy() end
   for _,p in ipairs(e.pieces) do p.model:Destroy() end
   e.seam:Destroy()
   table.remove(self.splits,i)
  else
   -- Pop: the halves jump apart and up so the split is easy to see.
   local pop=reduced and 1 or 1-(1-math.clamp(age/POP,0,1))^3
   local over=reduced and 0 or math.sin(math.clamp(age/POP,0,1)*math.pi)*.25
   local gap=(.9+over)*pop;local lift=(.9+over)*pop;local open=.24*pop
   local fade,tremble,shrink=0,0,1
   if age<pause then
    local hold=math.clamp((age-POP)/(pause-POP),0,1)
    tremble=reduced and 0 or .04*hold
    e.seam.Transparency=1-(.3+.6*hold)
    e.light.Brightness=.5+2.5*hold
    lift+=reduced and 0 or .25*math.sin(hold*math.pi*.5)
   else
    local q=math.clamp((age-pause)/.65,0,1)
    if e.tier>0 then
     local fly=1-(1-q)^2
     gap+=3.5*fly;lift+=2.2*fly-4*q*q;open+=1.1*fly
     e.seam.Transparency=q;e.light.Brightness=4*(1-q)
    else
     lift-=e.size*.9*q*q;gap+=.4*q;open+=.25*q
     shrink=1-.35*q
     e.seam.Transparency=.6+.4*q;e.light.Brightness=1.5*(1-q)
    end
    fade=math.clamp((q-.4)/.6,0,1)
   end
   for _,h in ipairs(e.halves) do
    local jx=tremble>0 and math.sin(now*57+h.side)*tremble or 0
    local jz=tremble>0 and math.cos(now*49+h.side)*tremble or 0
    local f=e.frame*CFrame.new(h.side*gap+jx,lift,jz)*CFrame.Angles(0,0,-h.side*open)
    for _,item in ipairs(h.parts) do
     local rel=item.rel
     if shrink<1 then rel=CFrame.new(rel.Position*shrink)*rel.Rotation end
     item.part.CFrame=f*rel;item.part.Transparency=fade
    end
   end
   for _,p in ipairs(e.pieces) do
    local t=age
    local pos=p.v*t-Vector3.yAxis*(GRAVITY*.5*t*t)
    local f=p.from*CFrame.new(pos)*CFrame.fromAxisAngle(p.axis,p.spin*t)
    local pf=math.clamp((t-.45)/.5,0,1)
    for _,item in ipairs(p.parts) do item.part.CFrame=f*item.rel;item.part.Transparency=pf end
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

-- Crack overlay for one drone's cell: cracks spread from the beam's contact
-- point along the cell's edges, then the split line glows across it.
function V:buildCrack(droneId: string,key: string)
 local cube=self.cube
 local ids=DigCube.parseKey(key)
 if #ids==0 then return nil end
 for _,id in ipairs(ids) do if not cube.cells[id] or cube.removed[id] then return nil end end
 local touched={}
 self:breakTiles(ids,touched)
 for id in pairs(touched) do self:refresh(id) end
 local data=DigCube.cracks(cube,ids[1])
 local crack={key=key,ids=ids,edges=data.edges,reach=math.max(.5,data.reach),seams=data.seams,parts={},seamParts={},progress=0,seen=0,dustAt=0}
 self.cracks[droneId]=crack
 return crack
end

function V:dropCrack(droneId: string)
 local crack=self.cracks[droneId]
 if not crack then return end
 for _,p in pairs(crack.parts) do p:Destroy() end
 for _,p in pairs(crack.seamParts) do p:Destroy() end
 for _,id in ipairs(crack.ids) do self.damage[id]=nil end
 self.cracks[droneId]=nil
end

function V:line(list: {[number]:BasePart},index: number,a: Vector3,b: Vector3,normal: Vector3,width: number,color: Color3,neon: boolean)
 local part=list[index]
 local length=(b-a).Magnitude
 if length<.03 then if part then part.Transparency=1 end;return end
 if not part then part=fxPart(self.fx,'DigCrack',color);list[index]=part end
 local lift=normal*.06
 part.Size=Vector3.new(width,.08,length+width*.5)
 part.CFrame=CFrame.lookAt((a+b)*.5+lift,b+lift,normal)
 part.Color=color;part.Material=neon and Enum.Material.Neon or Enum.Material.SmoothPlastic;part.Transparency=0
end

function V:drawCrack(crack: any,now: number)
 local p=crack.progress
 local heat=math.clamp((p-.74)/.26,0,1)
 local color=CRACK:Lerp(HOT,heat)
 local width=.14+.12*p
 local front=math.clamp((p-.02)/.68,0,1)*crack.reach
 local o=self.origin
 local tipAt
 for i,e in ipairs(crack.edges) do
  local r=math.clamp((front-e.start)/e.len,0,1)
  if r<=0 then
   if crack.parts[i] then crack.parts[i].Transparency=1 end
  else
   local a=o+vec(e.a);local b=o+vec(e.b)
   local tip=a:Lerp(b,r)
   self:line(crack.parts,i,a,tip,vec(e.normal),width,color,heat>0)
   if r<1 then tipAt=tip end
  end
 end
 -- Dust puffs where the cracks are still running.
 if tipAt and now>=crack.dustAt and not self:reduced() and self.ctx.presentation and self.ctx.presentation.work then
  crack.dustAt=now+.16
  self.ctx.presentation.work:burst(tipAt,Vector3.yAxis,self:colorAt(tipAt.Y-o.Y):Lerp(Color3.new(1,1,1),.3),3,workspace:GetServerTimeNow())
 end
 -- Then the split line opens across it from the middle outward, glowing.
 local g=math.clamp((p-.68)/.24,0,1)
 for i,s in ipairs(crack.seams) do
  if g<=0 then
   if crack.seamParts[i] then crack.seamParts[i].Transparency=1 end
  else
   local a=o+vec(s.a);local b=o+vec(s.b);local m=(a+b)*.5
   self:line(crack.seamParts,i,m:Lerp(a,g),m:Lerp(b,g),vec(s.normal),width*1.2,CRACK:Lerp(GLOW,.35+.65*heat),true)
  end
 end
 for _,id in ipairs(crack.ids) do self.damage[id]=p end
end

-- One beam per digging drone, from its rendered emitter to its cell.
function V:droneBeam(source: Instance,from: Vector3,now: number,color: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' or not self.cube then return end
 local key=source:GetAttribute('DigChunk')
 if type(key)~='string' then key='' end
 local crack=self.cracks[id]
 if crack and crack.key~=key then self:dropCrack(id);crack=nil end
 if not crack and key~='' then crack=self:buildCrack(id,key) end
 local progress=source:GetAttribute('DigProgress') or 0
 if crack then crack.progress=math.max(crack.progress,progress);crack.seen=now end
 local active=crack~=nil and source:GetAttribute('DigMining')==true and source:GetAttribute('WorkPaused')~=true
 local beam=self.beams[id]
 if not active then
  if beam then beam.core.Transparency=1;beam.glow.Transparency=1;beam.spot.Transparency=1 end
  return
 end
 if not beam then
  local function rod(name: string,c: Color3)
   local p=fxPart(self.fx,name,c);(p :: Part).Shape=Enum.PartType.Cylinder;p.Material=Enum.Material.Neon
   return p
  end
  beam={core=rod('DigBeamCore',BEAM_CORE),glow=rod('DigBeamGlow',color or HOT),spot=rod('DigBeamSpot',color or HOT)};
  (beam.spot :: Part).Shape=Enum.PartType.Ball
  self.beams[id]=beam
 end
 local point=source:GetAttribute('DigPoint')
 if typeof(point)~='Vector3' then return end
 local to=point
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
  if now-crack.seen>.3 then self:dropCrack(id) else self:drawCrack(crack,now) end
 end
end

-- The cell darkens as damage builds; only its last moments tremble and heat up.
function V:stepDamage(now: number)
 local reduced=self:reduced()
 for id,model in pairs(self.models) do
  local p=self.damage[id]
  local was=model:GetAttribute('Damaged')
  if p then
   local q=math.clamp((p-SHAKE_FROM)/(1-SHAKE_FROM),0,1)
   local amp=(reduced or q<=0) and 0 or .03+.12*q
   local offset=Vector3.new(math.sin(now*61+id)*amp,0,math.cos(now*53+id*2)*amp)
   for _,part in ipairs(model:GetChildren()) do
    local cf=self.base[part]
    if cf and part:IsA('BasePart') then
     part.CFrame=cf+offset
     local base=self:colorAt(cf.Position.Y-self.origin.Y)
     part.Color=base:Lerp(CRACK,.22*math.min(1,p/.8)):Lerp(HOT,.35*q)
    end
   end
   model:SetAttribute('Damaged',true)
  elseif was then
   for _,part in ipairs(model:GetChildren()) do
    local cf=self.base[part]
    if cf and part:IsA('BasePart') then part.CFrame=cf;part.Color=self:colorAt(cf.Position.Y-self.origin.Y) end
   end
   model:SetAttribute('Damaged',nil)
  end
 end
end

function V:stepPad(now: number)
 local pad=self.pad;if not pad or not self.cube then return end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
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
 self:stepDamage(now)
 self:stepSplits(now)
 self:stepDebris(now)
 self:stepPad(now)
end

function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 self:clear()
 self.folder:Destroy();self.fx:Destroy()
end
return V
