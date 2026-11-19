--!strict
-- Client view of the Dig Cube. Every client builds the same cube from the
-- replicated seed (DigCube.build) and renders only cells that air touches:
-- the top layer, pit walls and floors, and flat panels on the outer faces.
-- Cut cells shatter into their own wedge pieces. Drones that are digging draw
-- a beam to their cell, which shakes and heats up as it weakens. Tapping the
-- cube sends the crew there; a launch pad at the base throws you onto the top.
local DigCube=require('./DigCube')
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local V={}
V.__index=V
local GRAVITY=-70
local BEAM_CORE=Color3.fromRGB(255,250,235)
local HOT=Color3.fromRGB(255,196,128)

local function rgb(t: {number}) return Color3.fromRGB(t[1],t[2],t[3]) end

function V.new(ctx: any)
 local self=setmetatable({ctx=ctx,parts={},panels={},base={},debris={},beams={},shaking={},cube=nil,origin=Vector3.zero,
  generation=-1,removedString='',random=Random.new(),connections={},tapAt=0},V)
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
 table.insert(self.connections,holder:GetAttributeChangedSignal('Generation'):Connect(function() self:sync() end))
 table.insert(self.connections,holder:GetAttributeChangedSignal('Removed'):Connect(function() self:sync() end))
 self:sync()
end

function V:clear()
 for _,model in pairs(self.parts) do model:Destroy() end
 for _,list in pairs(self.panels) do for _,p in ipairs(list) do p:Destroy() end end
 self.parts={};self.panels={};self.base={};self.shaking={}
 if self.pad then self.pad:Destroy();self.pad=nil end
end

function V:cellColor(cell: any): Color3
 if cell.ore>0 then return rgb(DigCube.ORES[cell.ore].color) end
 local c=rgb(DigCube.STRATA[math.min(cell.layer,#DigCube.STRATA)])
 if cell.shade>0 then return c:Lerp(Color3.new(1,1,1),cell.shade) end
 return c:Lerp(Color3.new(0,0,0),-cell.shade)
end

function V:dressPart(part: BasePart,cell: any)
 part.Anchored=true;part.CanTouch=false;part.CanQuery=true;part.CanCollide=true
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 part.Color=self:cellColor(cell)
 part.Material=Enum.Material.SmoothPlastic
 part.Reflectance=cell.ore>0 and .22 or 0
 part.CastShadow=true
 part:SetAttribute('DigCell',cell.id)
end

function V:showCell(id: number)
 if self.parts[id] then return end
 self:hidePanels(id)
 local cell=self.cube.cells[id]
 local model=Instance.new('Model');model.Name='Cell'..id
 for _,w in ipairs(DigCube.wedges(cell)) do
  local part=Instance.new('WedgePart')
  part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
  local cf=CFrame.fromMatrix(self.origin+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),
   Vector3.new(w.right[1],w.right[2],w.right[3]),Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
  part.CFrame=cf;self.base[part]=cf
  self:dressPart(part,cell)
  part.Parent=model
 end
 model.Parent=self.folder
 self.parts[id]=model
end

function V:showPanels(id: number)
 if self.panels[id] or self.parts[id] then return end
 local cell=self.cube.cells[id]
 local list={}
 local thick=cell.y1-cell.y0
 for _,pn in ipairs(DigCube.panels(cell)) do
  local nx,nz=DigCube.sideNormal(pn.side)
  local part=Instance.new('Part')
  part.Size=Vector3.new(pn.length,thick,.2)
  local center=self.origin+Vector3.new(pn.mx-nx*.1,(cell.y0+cell.y1)*.5,pn.mz-nz*.1)
  part.CFrame=CFrame.fromMatrix(center,Vector3.new(pn.dx,0,pn.dz),Vector3.yAxis)
  self:dressPart(part,cell)
  part.Parent=self.folder
  table.insert(list,part)
 end
 self.panels[id]=list
end

function V:hidePanels(id: number)
 local list=self.panels[id]
 if list then for _,p in ipairs(list) do p:Destroy() end;self.panels[id]=nil end
end

-- Bring one cell to the state the removed set implies.
function V:refresh(id: number)
 local cube=self.cube
 if cube.removed[id] then
  self:hidePanels(id)
  local model=self.parts[id];if model then self.parts[id]=nil;model:Destroy() end
 elseif DigCube.visible(cube,id) then self:showCell(id)
 elseif cube.cells[id].boundary then self:showPanels(id) end
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

function V:sync()
 local holder=self.holder
 if not holder then return end
 local seed=holder:GetAttribute('Seed');local generation=holder:GetAttribute('Generation') or 0
 local origin=holder:GetAttribute('Origin')
 if type(seed)~='number' or typeof(origin)~='Vector3' then return end
 local animate=true
 if generation~=self.generation then
  self:clear()
  self.generation=generation;self.origin=origin
  self.cube=DigCube.build(seed)
  self.removedString=''
  for _,cell in ipairs(self.cube.cells) do self:refresh(cell.id) end
  self:buildPad()
  animate=false
 end
 local s=holder:GetAttribute('Removed')
 if type(s)~='string' or s==self.removedString then return end
 self.removedString=s
 local cube=self.cube
 local now=os.clock()
 local touched={}
 local fresh={}
 for id in pairs(DigCube.decode(cube,s)) do
  if not cube.removed[id] then
   cube.removed[id]=true;cube.removedCount+=1
   table.insert(fresh,id)
  end
 end
 -- A big first sync (joining mid-dig) applies silently.
 if #fresh>12 then animate=false end
 for _,id in ipairs(fresh) do
  if animate then self:shatter(id,now) end
  touched[id]=true
  for _,other in ipairs(DigCube.affected(cube,id)) do touched[other]=true end
 end
 for id in pairs(touched) do self:refresh(id) end
end

function V:shatter(id: number,now: number)
 local model=self.parts[id]
 local cell=self.cube.cells[id]
 local center=self.origin+Vector3.new(cell.cx,(cell.y0+cell.y1)*.5,cell.cz)
 local color=self:cellColor(cell)
 if model then
  self.parts[id]=nil
  model.Parent=self.fx
  for _,part in ipairs(model:GetChildren()) do
   if part:IsA('BasePart') then
    part.CanCollide=false;part.CanQuery=false
    local out=part.Position-center;out=Vector3.new(out.X,0,out.Z)
    out=out.Magnitude>.05 and out.Unit or Vector3.new(self.random:NextNumber(-1,1),0,self.random:NextNumber(-1,1)).Unit
    local velocity=out*self.random:NextNumber(5,12)+Vector3.new(0,self.random:NextNumber(16,27),0)
    local axis=Vector3.new(self.random:NextNumber(-1,1),self.random:NextNumber(-1,1),self.random:NextNumber(-1,1))
    if axis.Magnitude<.05 then axis=Vector3.xAxis end
    table.insert(self.debris,{part=part,model=model,start=now,from=part.CFrame,size=part.Size,velocity=velocity,
     axis=axis.Unit,spin=self.random:NextNumber(4,10),life=self.random:NextNumber(.75,1.15)})
   end
  end
 end
 local ctx=self.ctx
 local top=self.origin+Vector3.new(cell.cx,cell.y1,cell.cz)
 local size=math.sqrt(cell.area)
 if not (ctx.reduced and ctx.reduced()) then
  if ctx.presentation and ctx.presentation.work then
   ctx.presentation.work:burst(top,Vector3.yAxis,color,cell.ore>0 and 22 or 14,workspace:GetServerTimeNow())
  end
  if ctx.beat then ctx.beat(cell.ore>0 and 'HeavySplit' or 'Split',center,workspace:GetServerTimeNow(),math.clamp(size/7,.6,1.4)) end
 end
 if ctx.audio then ctx.audio:play('crystal_split',center,{rockSize=size}) end
end

function V:stepDebris(now: number)
 for i=#self.debris,1,-1 do
  local d=self.debris[i]
  local t=now-d.start
  if t>=d.life or not d.part.Parent then
   d.part:Destroy()
   if #d.model:GetChildren()==0 then d.model:Destroy() end
   table.remove(self.debris,i)
  else
   local offset=d.velocity*t+Vector3.new(0,.5*GRAVITY*t*t,0)
   local fade=math.clamp((t/d.life-.45)/.55,0,1)
   d.part.CFrame=(d.from+offset)*CFrame.fromAxisAngle(d.axis,d.spin*t)
   d.part.Size=d.size*(1-.55*fade)
   d.part.Transparency=fade
  end
 end
end

-- One beam per digging drone, from its rendered emitter to its cell.
function V:droneBeam(source: Instance,from: Vector3,now: number,color: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' then return end
 local cellId=source:GetAttribute('DigCell')
 local active=source:GetAttribute('DigMining')==true and type(cellId)=='number' and cellId>0 and self.cube~=nil
  and self.parts[cellId]~=nil and source:GetAttribute('WorkPaused')~=true
 local beam=self.beams[id]
 if not active then
  if beam then beam.core.Transparency=1;beam.glow.Transparency=1;beam.spot.Transparency=1 end
  return
 end
 if not beam then
  local function rod(name: string,c: Color3)
   local p=Instance.new('Part');p.Name=name;p.Shape=Enum.PartType.Cylinder;p.Anchored=true
   p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=c
   p.Parent=self.fx;return p
  end
  beam={core=rod('DigBeamCore',BEAM_CORE),glow=rod('DigBeamGlow',color or HOT),spot=rod('DigBeamSpot',color or HOT)}
  beam.spot.Shape=Enum.PartType.Ball
  self.beams[id]=beam
 end
 local point=source:GetAttribute('DigPoint')
 if typeof(point)~='Vector3' then return end
 local progress=source:GetAttribute('DigProgress') or 0
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
 local r=1+.9*progress+.2*pulse
 beam.spot.Size=Vector3.new(r,r,r);beam.spot.CFrame=CFrame.new(to);beam.spot.Transparency=.25
 self.shaking[cellId]=math.max(self.shaking[cellId] or 0,progress)
 if self.ctx.presentation and self.ctx.presentation.work and now>=(beam.sparkAt or 0) then
  beam.sparkAt=now+.18
  self.ctx.presentation.work:burst(to,Vector3.yAxis,color or HOT,6,workspace:GetServerTimeNow())
 end
end

function V:stepShake(now: number)
 for id,model in pairs(self.parts) do
  local progress=self.shaking[id]
  local was=model:GetAttribute('Shaking')
  if progress then
   local cell=self.cube.cells[id]
   local base=self:cellColor(cell)
   local amp=.04+.12*progress
   local offset=Vector3.new(math.sin(now*61+id)*amp,0,math.cos(now*53+id*2)*amp)
   for _,part in ipairs(model:GetChildren()) do
    local cf=self.base[part]
    if cf and part:IsA('BasePart') then part.CFrame=cf+offset;part.Color=base:Lerp(HOT,.55*progress) end
   end
   model:SetAttribute('Shaking',true)
  elseif was then
   local cell=self.cube.cells[id];local base=self:cellColor(cell)
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
 if not hit or not hit.Instance:GetAttribute('DigCell') then return end
 self.tapAt=os.clock()
 self.ctx.command:FireServer('DigFocus',{point=hit.Position})
 if self.ctx.presentation and self.ctx.presentation.work then
  self.ctx.presentation.work:burst(hit.Position,hit.Normal,Color3.fromRGB(255,232,170),10,workspace:GetServerTimeNow())
 end
end

function V:update()
 local now=os.clock()
 self:stepDebris(now)
 self:stepShake(now)
 self:stepPad(now)
end

function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 self:clear()
 self.folder:Destroy();self.fx:Destroy()
end
return V
