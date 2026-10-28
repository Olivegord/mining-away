-- Runtime map assembly around the original spawn, fields and Converter.
-- The source binary remains untouched. Authored assets are cloned, never rebuilt as boxes.
local W={}
function W.part(parent,name,pos,size,color,material)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.Size=size;p.Position=pos;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Parent=parent
 return p
end
function W.label(part,text,offset)
 -- Reserved for short contextual readouts; field identity uses grounded signs instead.
 local b=Instance.new('BillboardGui');b.Name='Readout';b.Size=UDim2.fromOffset(170,38);b.StudsOffset=offset or Vector3.new(0,4,0);b.AlwaysOnTop=false;b.MaxDistance=65;b.Parent=part
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=.15;t.BackgroundColor3=Color3.fromRGB(20,31,37);t.TextColor3=Color3.fromRGB(229,241,229);t.TextSize=13;t.Font=Enum.Font.GothamMedium;t.TextWrapped=true;t.Text=text;t.Parent=b
 return t
end
local function sanitize(model,query)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=query==true
  elseif v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Trail') then v.Enabled=false end
 end
end
W.sanitize=sanitize
function W.drone(parent,template,pos,color)
 local model=template and template:Clone() or Instance.new('Model');model.Name='Drone';sanitize(model,false)
 local part=model.PrimaryPart or model:FindFirstChild('Mesh') or model:FindFirstChildWhichIsA('BasePart',true)
 if not part or not part:IsA('BasePart') then part=W.part(model,'Hull',pos,Vector3.new(2,2,2),Color3.fromRGB(229,235,230)) end
 part.Color=part.Color:Lerp(color,.25)
 model.PrimaryPart=part;model.Parent=parent;model:PivotTo(CFrame.new(pos))
 local emitter=model:FindFirstChild('Emmiter',true)
 if not emitter or not emitter:IsA('BasePart') then emitter=W.part(model,'Emmiter',pos,Vector3.new(.24,.24,.24),color,Enum.Material.Neon) end
 emitter.Color=color;emitter.CanQuery=false
 model:SetAttribute('OriginalDrone',template~=nil)
 return model,part,emitter
end
local function finishConstruct(model)
 local shell={bottemseg=true,lowerseg=true,upperseg=true,topseg=true}
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('BasePart') then
   v.Reflectance=0;v.MaterialVariant=''
   if shell[v.Name] then v.Material=Enum.Material.SmoothPlastic;v.Color=Color3.fromRGB(218,232,219)
   elseif v.Name=='eyecase' then v.Material=Enum.Material.Metal;v.Color=Color3.fromRGB(47,91,91)
   elseif v.Name=='basepart' then v.Material=Enum.Material.Slate;v.Color=Color3.fromRGB(35,66,70);v.Transparency=0
   elseif v.Name=='eye' or v.Name=='spawnEye' then v.Material=Enum.Material.Neon;v.Color=Color3.fromRGB(102,224,206) end
  end
 end
end
function W.turret(parent,template,pos,color)
 assert(template and template:IsA('Model'),'Original Workspace.construct template is required; refusing a replacement box turret')
 local model=template:Clone();model.Name='PyramidTurret'
 -- AnimSaves is editor keyframe history (3,428 descendants), not the live rig.
 -- Preserve the complete original and ServerStorage template; omit only this redundant
 -- cloned editor copy. Clone the model first so Motor6D references remain correctly remapped.
 local editorHistory=model:FindFirstChild('AnimSaves')
 if editorHistory then editorHistory:Destroy() end
 sanitize(model,false)
 local base=model:FindFirstChild('basepart',true)
 assert(base and base:IsA('BasePart'),'Original construct basepart is missing')
 for _,name in ipairs({'bottemseg','lowerseg','upperseg','topseg','eye','eyecase','spawnEye'}) do
  assert(model:FindFirstChild(name,true),'Original construct missing '..name)
 end
 model.PrimaryPart=base;model.Parent=parent;model:PivotTo(CFrame.new(pos))
 -- Retain every authored mesh/pivot, but give the construct one coherent ceramic shell.
 finishConstruct(model)
 local eye=model:FindFirstChild('eye',true)
 -- One invisible query body admits range/LOS checks without changing the authored silhouette.
 local hit=W.part(model,'DefenseHitbox',base.Position+Vector3.new(0,4.5,0),Vector3.new(8,10,8),color)
 hit.Transparency=1;hit.CanQuery=true
 hit:SetAttribute('TurretHitbox',true);model:SetAttribute('OriginalConstruct',true)
 return model,hit,eye
end
function W.beam(parent,color)
 local rs=game:GetService('ReplicatedStorage')
 local fx=rs:FindFirstChild('MiningFX');local template=fx and fx:FindFirstChild('Beam')
 local a=Instance.new('Attachment');a.Name='RenderedEmitter';a.Position=Vector3.zero;a.Parent=parent
 local endpoint=W.part(parent,'Endpoint',parent.Position,Vector3.new(.05,.05,.05),color);endpoint.Transparency=1
 local b=Instance.new('Attachment');b.Parent=endpoint
 local beams={}
 for i,name in ipairs({'InnerBeam','OuterBeam'}) do
  local original=template and template:FindFirstChild(name,true)
  local beam=original and original:Clone() or Instance.new('Beam')
  beam.Name=name;beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=true;beam.LightEmission=1
  beam.Color=ColorSequence.new(i==1 and Color3.new(1,1,1) or color)
  beam.Width0=0;beam.Width1=0;beam.Enabled=false;beam.Parent=parent
  table.insert(beams,beam)
 end
 return {beams=beams,endpoint=endpoint,attachment=a,targetAttachment=b}
end
function W.setBeam(b,on,pos)
 if pos then b.endpoint.Position=pos end
 for i,v in ipairs(b.beams) do v.Enabled=on;v.Width0=on and (i==1 and .3 or .65) or 0;v.Width1=v.Width0 end
end
local P={
 ground=Color3.fromRGB(84,154,115),dust=Color3.fromRGB(210,216,183),stone=Color3.fromRGB(65,103,106),
 ledge=Color3.fromRGB(186,207,191),metal=Color3.fromRGB(30,65,73),edge=Color3.fromRGB(117,171,162),
 ivory=Color3.fromRGB(245,237,207),ink=Color3.fromRGB(22,49,60),mint=Color3.fromRGB(100,229,201),
 amber=Color3.fromRGB(245,182,96),blue=Color3.fromRGB(118,201,228),coral=Color3.fromRGB(226,129,145),
}
local function solid(p) p.CanCollide=true;p.CanQuery=true;return p end
local function block(parent,name,at,size,color,material,rotation)
 local p=W.part(parent,name,at,size,color,material)
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.CastShadow=true
 if rotation then p.CFrame=CFrame.new(at)*CFrame.Angles(rotation[1] or 0,rotation[2] or 0,rotation[3] or 0) end
 return p
end
local function textFace(part,title,subtitle,color,face)
 local g=Instance.new('SurfaceGui');g.Name='SignFace';g.Face=face or Enum.NormalId.Front;g.CanvasSize=Vector2.new(600,180);g.LightInfluence=0;g.Parent=part
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(.92,.48);t.Position=UDim2.fromScale(.04,.09);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextSize=44;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextColor3=color;t.Text=title;t.Parent=g
 local s=Instance.new('TextLabel');s.Size=UDim2.fromScale(.92,.28);s.Position=UDim2.fromScale(.04,.65);s.BackgroundTransparency=1;s.Font=Enum.Font.GothamMedium;s.TextSize=24;s.TextXAlignment=Enum.TextXAlignment.Left;s.TextColor3=P.ivory;s.Text=subtitle;s.Parent=g
 -- Machines and field approaches can be visited from either direction.
 if not face then local back=g:Clone();back.Name='SignReverse';back.Face=Enum.NormalId.Back;back.Parent=part end
 return g
end
local function sign(parent,at,title,subtitle,color,facing)
 local model=Instance.new('Model');model.Name='Wayfinding';model.Parent=parent
 local board=block(model,'FieldSign',at+Vector3.new(0,3.4,0),Vector3.new(9,2.8,.45),P.ink,Enum.Material.Metal)
 if facing then board.CFrame=CFrame.lookAt(board.Position,Vector3.new(facing.X,board.Position.Y,facing.Z)) end
 for _,dx in ipairs({-3.5,3.5}) do
  local p=block(model,'SignFoot',board.CFrame:PointToWorldSpace(Vector3.new(dx,-2,0)),Vector3.new(.3,3,.3),P.edge,Enum.Material.Metal);p.CFrame=CFrame.new(p.Position)*board.CFrame.Rotation
 end
 local stripe=block(model,'FieldCode',board.CFrame:PointToWorldSpace(Vector3.new(-4.3,0,-.25)),Vector3.new(.18,2.2,.08),color,Enum.Material.SmoothPlastic);stripe.CFrame=CFrame.new(stripe.Position)*board.CFrame.Rotation
 textFace(board,title,subtitle,color)
 return board
end
local function light(parent,color,range,brightness)
 local l=Instance.new('PointLight');l.Name='WorkLight';l.Color=color;l.Range=range;l.Brightness=brightness;l.Shadows=false;l.Parent=parent
end
local function path(parent,a,b,width)
 local middle=(a+b)/2
 -- All chords share one flat color. Tiny dark shoulder strips at every bend
 -- produced visible comb teeth in the real baseline Studio screenshot.
 local p=solid(block(parent,'Trail',middle,Vector3.new(width or 11,.28,(b-a).Magnitude+.35),P.dust,Enum.Material.SmoothPlastic))
 p.CFrame=CFrame.lookAt(middle,b);p:SetAttribute('WalkRoute',true)
 return p
end
local function station(parent,name,at,color,title,interaction)
 local model=Instance.new('Model');model.Name=name..'Assembly';model.Parent=parent
 local base=solid(block(model,name,at+Vector3.new(0,1,0),Vector3.new(6,2,5),P.metal,Enum.Material.Metal))
 base:SetAttribute('Interaction',interaction)
 local prompt=Instance.new('ProximityPrompt');prompt.ActionText=title;prompt.ObjectText=name=='PackStation' and 'RUN CARDS' or name=='Printer' and 'DRONE PRINTER' or 'PERMANENT FLEET';prompt.MaxActivationDistance=10;prompt.HoldDuration=0;prompt.RequiresLineOfSight=false;prompt.Enabled=name~='Printer';prompt.Parent=base
 block(model,'MachineFoot',at+Vector3.new(0,.18,0),Vector3.new(7,.36,6),P.ledge,Enum.Material.Concrete)
 for _,x in ipairs({-2.7,2.7}) do block(model,'ChassisEdge',at+Vector3.new(x,1.2,0),Vector3.new(.22,1.7,4.7),P.edge,Enum.Material.Metal) end
 if name=='Printer' then
  -- Free reprints appear inside this open bay, directly above the existing server station.
  for _,x in ipairs({-3.25,3.25}) do
   block(model,'PrintGantry',at+Vector3.new(x,3.7,0),Vector3.new(.55,7.4,4.7),P.metal,Enum.Material.Metal)
   block(model,'PrintRail',at+Vector3.new(x*.93,4.2,-1.8),Vector3.new(.14,4.5,.16),color,Enum.Material.Neon)
  end
  block(model,'PrintHead',at+Vector3.new(0,7.1,0),Vector3.new(7.2,.65,4.7),P.edge,Enum.Material.Metal)
  block(model,'PrintEmitter',at+Vector3.new(0,6.68,0),Vector3.new(3.3,.1,2.8),color,Enum.Material.Neon)
  block(model,'PrintBed',at+Vector3.new(0,2.08,0),Vector3.new(4.7,.16,3.7),P.ink,Enum.Material.Metal)
  local fascia=block(model,'PrinterName',at+Vector3.new(0,6.98,-2.4),Vector3.new(4.7,.8,.12),P.ink)
  textFace(fascia,'PRINT BAY','FREE REPAIRS',color)
 elseif name=='PackStation' then
  local screen=block(model,'CardConsole',at+Vector3.new(0,2.8,.7),Vector3.new(4.9,2,.45),P.ink,Enum.Material.Metal,{math.rad(-16),0,0})
  for i=-1,1 do
   local card=block(model,'CardSlot',screen.CFrame:PointToWorldSpace(Vector3.new(i*1.45,.1,-.28)),Vector3.new(1.05,1.32,.12),i==0 and color or P.edge,Enum.Material.SmoothPlastic)
   card.CFrame=CFrame.new(card.Position)*screen.CFrame.Rotation
   local notch=block(model,'CardNotch',card.CFrame:PointToWorldSpace(Vector3.new(0,-.35,-.08)),Vector3.new(.6,.08,.04),P.ink);notch.CFrame=CFrame.new(notch.Position)*screen.CFrame.Rotation
  end
  local fascia=block(model,'CardName',at+Vector3.new(0,1.1,-2.56),Vector3.new(4.5,1.3,.12),P.ink)
  textFace(fascia,'RUN CARDS','CHOOSE YOUR BUILD',color)
 else
  -- Stepped hardware echoes the original segmented construct without replacing it.
  for i=1,3 do
   block(model,'FleetStack',at+Vector3.new(0,1.7+i*.8,.2),Vector3.new(4.8-i*.8,.48,3.8-i*.55),i==3 and color or P.edge,Enum.Material.Metal)
  end
  for _,x in ipairs({-2.4,2.4}) do block(model,'FleetSocket',at+Vector3.new(x,2.6,.5),Vector3.new(.32,2.1,.32),P.metal,Enum.Material.Metal) end
  local fascia=block(model,'FleetName',at+Vector3.new(0,1.1,-2.56),Vector3.new(4.5,1.3,.12),P.ink)
  textFace(fascia,'FLEET UPLINK','EARN A NEW DRONE',color)
 end
 return base
end
local function tree(parent,x,z,h,color,ground,yaw,foundationBottom)
 local m=Instance.new('Model');m.Name='QuarryTree';m.Parent=parent
 ground=ground or 0;yaw=yaw or x*.1
 local trunkColor=Color3.fromRGB(85,70,66)
 -- A deliberate squared planter is filled down to every neighboring step.
 -- Both the trunk and root begin at its actual flat top, including on slopes.
 local bottom=foundationBottom or ground
 local depth=math.max(.2,ground-bottom+.2)
 local footing=solid(block(m,'TreeFooting',Vector3.new(x,ground-depth/2,z),Vector3.new(6.4,depth,6.4),P.ledge))
 footing:SetAttribute('GroundedBase',true);footing:SetAttribute('FootTop',ground)
 local function localPart(name,p,size,tint,turn)
  local cf=CFrame.new(x,ground,z)*CFrame.Angles(0,yaw,0)*CFrame.new(p)
  local v=block(m,name,cf.Position,size,tint,Enum.Material.SmoothPlastic);v.CFrame=cf*CFrame.Angles(0,0,turn or 0)
  if name=='Canopy' or name=='Crown' then v.TopSurface=Enum.SurfaceType.Studs end
  return v
 end
 -- Forked trunks and chunky, tiered crowns keep the original parts-built language.
 localPart('Trunk',Vector3.new(0,h*.39,0),Vector3.new(1.35,h*.78,1.5),trunkColor)
 localPart('Root',Vector3.new(-.55,.65,0),Vector3.new(3.6,1.3,2.7),trunkColor)
 localPart('Fork',Vector3.new(2,h*.68,0),Vector3.new(.85,h*.44,.9),trunkColor,math.rad(-29))
 localPart('Fork',Vector3.new(-2.2,h*.65,.3),Vector3.new(.8,h*.34,.85),trunkColor,math.rad(32))
 localPart('Canopy',Vector3.new(-2.5,h*.84,.3),Vector3.new(h*.52,3.4,h*.46),color,math.rad(-9))
 localPart('Canopy',Vector3.new(3.5,h*.88,-.3),Vector3.new(h*.43,3.1,h*.39),color:Lerp(P.amber,.12),math.rad(8))
 localPart('Canopy',Vector3.new(0,h,0),Vector3.new(h*.48,3.5,h*.42),color:Lerp(P.ivory,.14),math.rad(-3))
 localPart('Crown',Vector3.new(-1,h+2.1,.3),Vector3.new(h*.29,1.5,h*.3),color:Lerp(P.ivory,.27),math.rad(-5))
 return m
end
local function stone(parent,at,size,tilt,color,name)
 return solid(block(parent,name or 'WeatheredStone',at,size,color or P.stone,Enum.Material.SmoothPlastic,{math.rad(tilt[1] or 0),math.rad(tilt[2] or 0),math.rad(tilt[3] or 0)}))
end
local function surveyGate(parent,at,color,plan)
 local m=Instance.new('Model');m.Name='ExpeditionGate';m.Parent=parent
 local surfaces={}
 local gateY=at.Y
 for _,s in ipairs({-1,1}) do
  local top,bottom=plan:foundation(at.X+s*8,at.Z,1.8);surfaces[s]={top,bottom};gateY=math.max(gateY,top)
 end
 for _,s in ipairs({-1,1}) do
  local bottom=surfaces[s][2];local depth=math.max(.2,gateY-bottom+.2)
  solid(block(m,'GateFooting',Vector3.new(at.X+s*8,gateY-depth/2,at.Z),Vector3.new(3.6,depth,3.6),P.ledge))
  stone(m,Vector3.new(at.X+s*8,gateY+3.5,at.Z),Vector3.new(2,7,3),{0,0,0},P.ledge,'ChalkPylon')
  block(m,'GateMarker',Vector3.new(at.X+s*7.9,gateY+5.6,at.Z-1.53),Vector3.new(.3,2,.12),color,Enum.Material.Neon)
 end
 block(m,'GateLintel',Vector3.new(at.X,gateY+7.5,at.Z),Vector3.new(18,1.15,3),P.ivory,Enum.Material.SmoothPlastic)
end
local function cleanSurface(part,archive)
 part.MaterialVariant='';part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 for _,v in ipairs(part:GetChildren()) do if v:IsA('Texture') or v:IsA('Decal') then v.Parent=archive end end
end
function W.initialize(): any
 local cfg=Config
 local rs=game:GetService('ReplicatedStorage');local storage=game:GetService('ServerStorage')
 local root=Instance.new('Folder');root.Name='MiningAway';root.Parent=workspace
 local map=Instance.new('Folder');map.Name='Map';map.Parent=root
 for _,name in ipairs({'Fields','Drones','Resources','Turrets'}) do local f=Instance.new('Folder');f.Name=name;f.Parent=root end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local home=spawn and spawn.Position or Vector3.new(-56,.5,-11)
 local plan=MapLayout.plan(cfg.Fields,{home.X,home.Y,home.Z})
 local archive=Instance.new('Folder');archive.Name='MiningAwayOriginalReference';archive.Parent=storage
 for _,name in ipairs({'FaceTest','Test','sphere','Mesh','Crystals','MiningEffect','Beam','Cat','potato'}) do
  local original=workspace:FindFirstChild(name);if original then original.Parent=archive end
 end
 -- These unlabelled top-level blocks are the old off-route construction experiment.
 -- Preserve their exact objects beside other reference props rather than leaving
 -- grey stairs and a giant beige slab in the composed landscape.
 for _,v in ipairs(workspace:GetChildren()) do
  if v:IsA('BasePart') and v.Name=='Part' then v.Parent=archive end
 end
 local construct=workspace:FindFirstChild('construct')
 assert(construct and construct:IsA('Model'),'The supplied source must retain Workspace.construct')
 local turretTemplate=construct:Clone();turretTemplate.Name='OriginalConstructTemplate';turretTemplate.Parent=storage
 finishConstruct(construct);construct:SetAttribute('DormantLandmark',true)
 local constructX,constructZ=plan:point(62,9)
 local constructGround,constructLow=plan:foundation(constructX,constructZ,7)
 construct.PrimaryPart=construct:FindFirstChild('basepart');construct:PivotTo(CFrame.new(constructX,constructGround+.5,constructZ))
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then cleanSurface(baseplate,archive);baseplate.Color=Color3.fromRGB(36,63,58);baseplate.Material=Enum.Material.SmoothPlastic end
 if spawn then cleanSurface(spawn,archive);spawn.Color=P.ledge;spawn.Material=Enum.Material.Metal end
 -- Retain the author's simple parts-built trees, now under the same restrained palette.
 for _,model in ipairs(workspace:GetChildren()) do
  if model:IsA('Model') and model.Name=='Model' then
   -- Original trees were perched on the old abandoned test stairs. Keep the
   -- same two-part geometry, scale and ground it as a distant southern grove.
   local parts={};local low,high=math.huge,-math.huge;local anchor=nil
   local trunk,slenderness=nil,-math.huge
   for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then
    table.insert(parts,v);anchor=anchor or v.Position
    local score=v.Size.Y/math.max(.01,v.Size.X,v.Size.Z)
    if score>slenderness then trunk=v;slenderness=score end
    -- Original source parts can be rotated. Measure their actual eight world
    -- corners before scaling instead of assuming axis-aligned local heights.
    for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
     local corner=v.CFrame:PointToWorldSpace(Vector3.new(v.Size.X*sx/2,v.Size.Y*sy/2,v.Size.Z*sz/2))
     low=math.min(low,corner.Y);high=math.max(high,corner.Y)
    end end end
   end end
   -- Parent original trees around their actual vertical trunk, not an
   -- arbitrary first child that might instead be a remote canopy part.
   if trunk then anchor=trunk.Position end
   local scale=math.min(1,18/math.max(1,high-low))
   local originalGround,footBottom=0,0
   if anchor then originalGround,footBottom=plan:foundation(anchor.X,anchor.Z,3.2) end
   if anchor then for _,v in ipairs(parts) do
    local p=v.Position;v.Size=v.Size*scale
    v.CFrame=CFrame.new(anchor.X+(p.X-anchor.X)*scale,originalGround+(p.Y-low)*scale,anchor.Z+(p.Z-anchor.Z)*scale)*v.CFrame.Rotation
   end end
   if anchor then
    local depth=math.max(.2,originalGround-footBottom+.2)
    local footing=solid(block(model,'OriginalTreeFooting',Vector3.new(anchor.X,originalGround-depth/2,anchor.Z),Vector3.new(6.4,depth,6.4),P.ledge))
    footing:SetAttribute('GroundedBase',true);footing:SetAttribute('FootTop',originalGround)
   end
   for _,v in ipairs(model:GetDescendants()) do
    if v:IsA('BasePart') then cleanSurface(v,archive);v.Material=Enum.Material.SmoothPlastic;v.Color=v.Size.Y>v.Size.X*1.7 and Color3.fromRGB(50,88,91) or Color3.fromRGB(107,182,159) end
   end
  end
 end
 HarborLighting.apply()
 local depot=solid(block(map,'DepotApron',Vector3.new(home.X,.1,home.Z),Vector3.new(40,.2,34),P.ivory:Lerp(P.ledge,.2),Enum.Material.SmoothPlastic));depot:SetAttribute('SafeDepot',true)
 -- Flush panel joints and painted corner brackets make one deliberate working yard.
 for _,x in ipairs({-10,0,10}) do block(map,'ApronJoint',Vector3.new(home.X+x,.215,home.Z),Vector3.new(.1,.02,32),P.stone) end
 for _,z in ipairs({-8,0,8}) do block(map,'ApronJoint',Vector3.new(home.X,.216,home.Z+z),Vector3.new(38,.02,.1),P.stone) end
 for _,dx in ipairs({-19,19}) do
  for _,dz in ipairs({-16,16}) do
   block(map,'YardPaint',Vector3.new(home.X+dx,.235,home.Z+dz*.86),Vector3.new(.18,.025,4),P.ivory)
   block(map,'YardPaint',Vector3.new(home.X+dx*.9,.235,home.Z+dz),Vector3.new(4,.025,.18),P.ivory)
  end
 end
 -- Rear service frame leaves the original follow ring and the route ahead open.
 for _,dx in ipairs({-17,17}) do
  block(map,'DepotPillar',Vector3.new(home.X+dx,5.8,home.Z-13),Vector3.new(.8,11.6,.8),P.metal,Enum.Material.Metal)
  local lamp=block(map,'DepotLamp',Vector3.new(home.X+dx,10.8,home.Z-12.5),Vector3.new(1.4,.4,.4),P.ivory,Enum.Material.Neon);light(lamp,P.ivory,22,.7)
 end
 block(map,'DepotLintel',Vector3.new(home.X,11.3,home.Z-13),Vector3.new(35,.8,1.2),P.edge,Enum.Material.Metal)
 block(map,'DepotCanopy',Vector3.new(home.X,12,home.Z-8),Vector3.new(38,.65,13),P.ivory,Enum.Material.SmoothPlastic)
 block(map,'CanopyInset',Vector3.new(home.X,11.64,home.Z-8),Vector3.new(34,.1,10),P.metal,Enum.Material.Metal)
 block(map,'DepotSunstripe',Vector3.new(home.X,12.36,home.Z-4),Vector3.new(31,.06,1.6),P.amber,Enum.Material.SmoothPlastic)
 -- The retrieval beacon is a single memorable skyline silhouette and a
 -- navigation landmark from every field. Its two legs connect to the depot,
 -- rather than floating a glowing sign above the scene.
 local tower=Instance.new('Model');tower.Name='RetrievalBeacon';tower.Parent=map
 for _,x in ipairs({-2,2}) do
  local column=block(tower,'BeaconLeg',Vector3.new(home.X+17+x,24,home.Z-13),Vector3.new(.8,24,.8),P.metal,Enum.Material.Metal)
  column.TopSurface=Enum.SurfaceType.Studs
 end
 for _,y in ipairs({15,21,27,33}) do
  block(tower,'BeaconRung',Vector3.new(home.X+17,y,home.Z-13),Vector3.new(4.8,.5,.8),P.edge,Enum.Material.Metal)
 end
 block(tower,'BeaconCrossbar',Vector3.new(home.X+17,36.5,home.Z-13),Vector3.new(12,1.2,2),P.ivory)
 block(tower,'BeaconCounterweight',Vector3.new(home.X+13,35.3,home.Z-13),Vector3.new(2.2,1.4,2.2),P.amber)
 local beacon=block(tower,'BeaconLens',Vector3.new(home.X+21,35.3,home.Z-13),Vector3.new(2.2,1.4,2.2),P.mint,Enum.Material.Neon)
 light(beacon,P.mint,10,.35)
 local header=block(map,'DepotHeader',Vector3.new(home.X,10.7,home.Z-13.65),Vector3.new(12,1.9,.18),P.ink)
 textFace(header,'MINING AWAY','EXTRACTION DEPOT  /  01',P.ivory)
 local printer=station(map,'Printer',home+Vector3.new(12,-.5,-2),P.mint,'Free reprint','Printer')
 local packs=station(map,'PackStation',home+Vector3.new(-12,-.5,-2),P.blue,'Open pack','Pack')
 local prestige=station(map,'PrestigeStation',home+Vector3.new(0,-.5,-12),P.amber,'Review prestige','Prestige')
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then
  cleanSurface(converter,archive);converter.Color=P.metal;converter.Material=Enum.Material.Metal;converter:SetAttribute('Interaction','Sell')
  for _,v in ipairs(converter:GetChildren()) do if v:IsA('ProximityPrompt') then v:Destroy() end end
  local prompt=Instance.new('ProximityPrompt');prompt.ActionText='Sell cargo';prompt.ObjectText='CONVERTER';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=converter
  local p=converter.Position;local half=converter.Size/2
  block(map,'ConverterCollar',Vector3.new(p.X,p.Y+half.Y-.3,p.Z),Vector3.new(converter.Size.X+1,.6,converter.Size.Z+1),P.edge,Enum.Material.Metal)
  for _,dx in ipairs({-.34,.34}) do
   block(map,'ConverterRib',Vector3.new(p.X+converter.Size.X*dx,p.Y,p.Z-half.Z-.15),Vector3.new(.45,converter.Size.Y*.85,.35),P.edge,Enum.Material.Metal)
  end
  block(map,'ConverterIntake',Vector3.new(p.X,p.Y,p.Z-half.Z-.3),Vector3.new(converter.Size.X*.5,converter.Size.Y*.42,.28),P.ink)
  block(map,'ConverterLight',Vector3.new(p.X,p.Y+half.Y*.42,p.Z-half.Z-.48),Vector3.new(converter.Size.X*.4,.18,.08),P.mint,Enum.Material.Neon)
  local name=block(map,'ConverterName',Vector3.new(p.X,p.Y+half.Y+1,p.Z-half.Z-.2),Vector3.new(7,1.6,.22),P.ink);textFace(name,'CONVERTER','SELL YOUR CARGO',P.mint)
  block(map,'OreChute',Vector3.new(p.X,p.Y-half.Y+.6,p.Z-half.Z-2),Vector3.new(converter.Size.X*.7,1.2,3.5),P.ledge,Enum.Material.Metal)
 end
 local fields={};local originals=workspace:FindFirstChild('Patches')
 for id,field in ipairs(cfg.Fields) do
  local model=Instance.new('Model');model.Name=field.Key;model:SetAttribute('FieldId',id);model:SetAttribute('Tier',id);model:SetAttribute('DisplayName',field.Name);model.Parent=root.Fields
  local part=originals and field.Original and originals:FindFirstChild(field.Original)
  if part and part:IsA('BasePart') then part.Parent=model
  else local o=field.Offset;part=block(model,'Field',home+Vector3.new(o[1],o[2],o[3]),Vector3.new(unpack(field.Size)),P.ground,Enum.Material.Ground) end
  -- Reposition the original patch objects with the rest of the compact valley.
  part.CFrame=CFrame.new(home+Vector3.new(unpack(field.Offset)));part.Size=Vector3.new(unpack(field.Size))
  cleanSurface(part,archive)
  local accent=Color3.fromRGB(unpack(field.Color))
  local beds={Color3.fromRGB(130,190,139),Color3.fromRGB(159,102,91),Color3.fromRGB(88,146,179),Color3.fromRGB(142,117,178),Color3.fromRGB(63,156,114)}
  part.Name='Field';part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.Color=beds[id];part.Material=Enum.Material.SmoothPlastic;part:SetAttribute('FieldId',id);part:SetAttribute('Patch',id)
  part.TopSurface=Enum.SurfaceType.Studs
  local top=part.Position.Y+part.Size.Y/2;local bottom=part.Position.Y-part.Size.Y/2
  -- The original raised Ruby patch is now visibly supported by a low layered mesa.
  if bottom>.4 then
   solid(block(model,'FieldBedrock',Vector3.new(part.Position.X,bottom/2,part.Position.Z),Vector3.new(part.Size.X+4,bottom,part.Size.Z+4),P.stone,Enum.Material.SmoothPlastic))
   solid(block(model,'FieldSkirt',Vector3.new(part.Position.X,bottom*.23,part.Position.Z),Vector3.new(part.Size.X+10,math.max(.4,bottom*.46),part.Size.Z+8),P.ledge,Enum.Material.SmoothPlastic))
   block(model,'ChalkCrown',Vector3.new(part.Position.X,bottom-.45,part.Position.Z),Vector3.new(part.Size.X+5,.65,part.Size.Z+5),P.ivory,Enum.Material.SmoothPlastic)
  end
  -- Signs stand on each actual field top, beside its incoming route.
  local shoulders={{-20,-11},{-20,-8},{-20,10},{-21,-8},{21,-8}}
  local shoulder=shoulders[id];local edge=Vector3.new(part.Position.X+shoulder[1]*MapLayout.FieldScale,top,part.Position.Z+shoulder[2]*MapLayout.FieldScale)
  local subtitle=id==1 and 'SAFE  /  START HERE' or field.Turrets>0 and (id==3 and 'GUARDED  /  COMBAT CARDS' or 'GUARDED  /  '..field.RecommendedFleet..'+ DRONES') or 'SAFE  /  RICHER ORE'
  local facing=id>3 and fields[id-1].center or home
  solid(block(model,'SignTerrace',edge-Vector3.new(0,top/2,0),Vector3.new(9,math.max(.2,top),5),P.stone))
  sign(model,edge,string.format('%02d  %s',id,field.Name:upper()),subtitle,accent,facing)
  -- Flat, nonblocking perimeter rails make each complete working field easy
  -- to recognize from player height without fence collisions at entrances.
  local rim=accent:Lerp(P.ivory,.45)
  for _,sgn in ipairs({-1,1}) do
   block(model,'FieldRim',Vector3.new(part.Position.X,top+.06,part.Position.Z+sgn*(part.Size.Z/2-.32)),Vector3.new(part.Size.X-.35,.12,.55),rim)
   block(model,'FieldRim',Vector3.new(part.Position.X+sgn*(part.Size.X/2-.32),top+.06,part.Position.Z),Vector3.new(.55,.12,part.Size.Z-.35),rim)
  end
  -- Short corner caps read as a footprint and leave every field side walkable.
  for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local corner=part.Position+Vector3.new(x*(part.Size.X/2+.3),top-part.Position.Y+.15,z*(part.Size.Z/2+.3))
   block(model,'FieldCorner',corner-Vector3.new(x*2.2,0,0),Vector3.new(4.4,.25,.42),P.ivory,Enum.Material.SmoothPlastic)
   block(model,'FieldCorner',corner-Vector3.new(0,0,z*2.2),Vector3.new(.42,.25,4.4),P.ivory,Enum.Material.SmoothPlastic)
   local pin=block(model,'SurveyPin',corner+Vector3.new(0,.75,0),Vector3.new(.3,1.5,.3),P.metal,Enum.Material.Metal)
   block(model,'PinLight',pin.Position+Vector3.new(0,.76,0),Vector3.new(.32,.16,.32),accent,Enum.Material.Neon)
  end end
  table.insert(fields,{id=id,cfg=field,center=part.Position,part=part,model=model})
 end
 -- Retro landscape: square solid parts with studded top surfaces. The old
 -- faceted slopes and native terrain meadow remain in source as reference but
 -- are intentionally not created in this authored parts-built scene.
 local foliage={Color3.fromRGB(81,174,104),Color3.fromRGB(173,57,49),Color3.fromRGB(64,150,185),Color3.fromRGB(157,103,192),Color3.fromRGB(36,157,110)}
 local terrain=Instance.new('Model');terrain.Name='ConnectedCliffs';terrain.Parent=map
 local batch=Instance.new('Model');batch.Name='PartTerrace';local terrainCells=0
 for _,cell in ipairs(plan.cells) do
  local x=(cell.a[1]+cell.c[1])/2;local z=(cell.a[3]+cell.c[3])/2
  local width=cell.b[1]-cell.a[1];local depth=cell.d[3]-cell.a[3]
  if cell.h>.05 then
   local earth=solid(block(batch,'TerraceBody',Vector3.new(x,cell.h/2,z),Vector3.new(width,cell.h,depth),P.stone))
   earth:SetAttribute('LandscapeSurface',true)
  end
  local green=Color3.fromRGB(112,162,113):Lerp(Color3.fromRGB(59,108,82),math.min(cell.h/120,.20))
  local cap=solid(block(batch,'StuddedGround',Vector3.new(x,cell.h,z),Vector3.new(width,.08,depth),green))
  cap.TopSurface=Enum.SurfaceType.Studs;cap:SetAttribute('LandscapeSurface',true)
  terrainCells+=1
  if terrainCells%40==0 then batch.Parent=terrain;task.wait();batch=Instance.new('Model');batch.Name='PartTerrace' end
 end
 batch.Parent=terrain
 for _,r in ipairs(plan.rocks) do
  local radius=math.sqrt(r.w*r.w+r.d*r.d)/2+1
  local ground,bottom=plan:foundation(r.x,r.z,radius)
  -- Restrained buttresses only where an actual short supporting footing fits.
  -- Avoid hiding a floating rock with a giant improvised pedestal.
  if ground-bottom<=5 then
   local m=Instance.new('Model');m.Name='TerracedButtress';m.Parent=terrain
   local tint=r.biome==2 and Color3.fromRGB(112,76,70) or P.stone
   local depth=math.max(.2,ground-bottom+.2)
   solid(block(m,'ButtressFooting',Vector3.new(r.x,ground-depth/2,r.z),Vector3.new(r.w+2,depth,r.d+2),tint,Enum.Material.SmoothPlastic,{0,math.rad(r.yaw),0}))
   stone(m,Vector3.new(r.x,ground+r.h*.4,r.z),Vector3.new(r.w,r.h*.8,r.d),{0,r.yaw,0},tint,'CliffButtress')
   stone(m,Vector3.new(r.x-2,ground+r.h*.75,r.z+1),Vector3.new(r.w*.72,r.h*.35,r.d*.8),{0,r.yaw+17,0},tint:Lerp(P.ledge,.18),'BrokenCrown')
  end
 end
 root:SetAttribute('TerrainStyle','Studded part terraces')
 root:SetAttribute('GrassRenderer','None - parts-built retro landscape')
 local function v(a) return Vector3.new(unpack(a)) end
 local routes=Instance.new('Model');routes.Name='WindingRoutes';routes.Parent=map
 for _,r in ipairs(plan.routes) do
  local lane=Instance.new('Model');lane.Name=r.name;lane.Parent=routes
  for i=1,#r.samples-1 do
   local a,b=v(r.samples[i]),v(r.samples[i+1]);local trail=path(lane,a,b,r.width)
   trail:SetAttribute('RouteSegment',i);trail:SetAttribute('RouteName',r.name);trail:SetAttribute('RouteStart',a);trail:SetAttribute('RouteEnd',b);trail:SetAttribute('RouteWidth',r.width)
   -- Close the underside with contiguous earth supports, never a floating ramp.
   local flat=Vector3.new(b.X-a.X,0,b.Z-a.Z);local count=math.ceil(flat.Magnitude/3)
   for n=1,count do
    local t=(n-.5)/count;local at=a:Lerp(b,t)
    local top=at.Y-math.abs(b.Y-a.Y)/(count*2)-.35
    if top>.3 then
     local fill=solid(block(lane,'TrailEarth',Vector3.new(at.X,top/2,at.Z),Vector3.new(r.width-.3,top,flat.Magnitude/count+.08),P.stone))
     fill.CFrame=CFrame.lookAt(fill.Position,fill.Position+flat)
     fill:SetAttribute('RouteSegment',i)
    end
   end
  end
  -- A short pitched seam follows its neighboring chords. Broad horizontal
  -- discs formerly crossed descending slopes as several-stud-high walls.
  for i=2,#r.samples-1 do
   local at=v(r.samples[i])
   local from,to=MapLayout.jointSeam(r.samples,i);local a,b=v(from),v(to)
   local joint=path(lane,a,b,r.width);joint.Name='RouteJoint'
   joint:SetAttribute('WalkRoute',true);joint:SetAttribute('JointIndex',i)
   local supportTop=MapLayout.jointTop(plan.routes,r.samples[i],math.sqrt((r.width/2)^2+.25^2))
   joint:SetAttribute('SupportTop',supportTop)
   if supportTop>.2 then
    local support=solid(block(lane,'JointEarth',Vector3.new(at.X,supportTop/2,at.Z),Vector3.new(r.width-.3,supportTop,.5),P.stone))
    local flat=Vector3.new(b.X-a.X,0,b.Z-a.Z);support.CFrame=CFrame.lookAt(support.Position,support.Position+flat)
    support:SetAttribute('JointIndex',i)
   end
  end
 end
 -- Each starter route meets the depot apron. The earlier plan began outside
 -- its edge, leaving the open hub visually disconnected from its paths.
 for _,r in ipairs(plan.routes) do
  local from,to=MapLayout.depotLink(r,{home.X,home.Y,home.Z})
  if from then
   local a,b=v(from),v(to)
   local lane=Instance.new('Model');lane.Name='Depot link - '..r.name;lane.Parent=routes
   local trail=path(lane,a,b,r.width);trail:SetAttribute('RouteSegment',1);trail:SetAttribute('RouteName',lane.Name)
   trail:SetAttribute('RouteStart',a);trail:SetAttribute('RouteEnd',b);trail:SetAttribute('RouteWidth',r.width)
  end
 end
 -- The old mint baseplate extended unbounded past the authored landscape.
 -- Segmented low retaining walls give it a constructed edge without an
 -- enormous opaque backdrop; every wall panel starts at its actual ground.
 local edge=Instance.new('Model');edge.Name='ValleyRetainingEdge';edge.Parent=map
 local x0,z0=plan:point(MapLayout.Origin[1],MapLayout.Origin[2])
 local x1,z1=plan:point(MapLayout.Origin[1]+MapLayout.Columns*MapLayout.Cell,MapLayout.Origin[2]+MapLayout.Rows*MapLayout.Cell)
 local function boundary(a,b)
  local delta=b-a;local n=math.ceil(delta.Magnitude/32)
  for i=1,n do
   local start=a+delta*((i-1)/n);local finish=a+delta*(i/n);local mid=(start+finish)/2
   local ground=plan:surface(mid.X,mid.Z)
   local panel=solid(block(edge,'RetainingPanel',Vector3.new(mid.X,ground+3,mid.Z),Vector3.new(2,6,(finish-start).Magnitude),P.edge))
   panel.CFrame=CFrame.lookAt(panel.Position,Vector3.new(finish.X,panel.Position.Y,finish.Z))
   panel.TopSurface=Enum.SurfaceType.Studs;panel:SetAttribute('GroundedBase',true);panel:SetAttribute('FootTop',ground)
  end
 end
 boundary(Vector3.new(x0,0,z0),Vector3.new(x1,0,z0));boundary(Vector3.new(x1,0,z0),Vector3.new(x1,0,z1))
 boundary(Vector3.new(x1,0,z1),Vector3.new(x0,0,z1));boundary(Vector3.new(x0,0,z1),Vector3.new(x0,0,z0))
 local forest=Instance.new('Model');forest.Name='BiomeGroves';forest.Parent=map
 for _,t in ipairs(plan.trees) do
  local m=tree(forest,t.x,t.z,t.h,foliage[t.biome],t.ground,t.yaw,t.foundationBottom)
  m.Name=t.biome==2 and 'AuburnTree' or 'MineralTree';m:SetAttribute('Biome',t.biome)
 end
 -- Small parts-built landmarks and dense undergrowth reward the bends. All
 -- dressing is outside the resource clearings; it never substitutes for an ore node.
 local props=Instance.new('Model');props.Name='ValleyDetails';props.Parent=map
 local siteX,siteZ,targetX,targetZ,siteY
 local function site(x,z,biome,yOffset)
  siteX,siteZ=x,z
  siteY=yOffset or 0
  if biome then targetX,targetZ=plan:biomePoint(biome,x,z) else targetX,targetZ=plan:point(x,z) end
 end
 local function at(x,y,z) return Vector3.new(targetX+x-siteX,y+plan.dy+siteY,targetZ+z-siteZ) end
 local function groundAt(x,z) local p=at(x,0,z);return plan:surface(p.X,p.Z) end
 local function prop(name,x,y,z,sx,sy,sz,color,turn,collide)
  local p=block(props,name,at(x,y,z),Vector3.new(sx,sy,sz),color,Enum.Material.SmoothPlastic,turn and {0,math.rad(turn),0})
  if collide then solid(p) end
  return p
 end
 -- Ruby mine: actual walk-in recess at the foot of a rising cliff. The
 -- playable crystal field remains in front, with no roof over its drone stations.
 site(-88,66,2)
 local _,mineBottom=plan:foundation(targetX,targetZ,16)
 local mineTop=12.41+plan.dy;local mineDepth=math.max(.2,mineTop-mineBottom+.2)
 prop('MineFoundation',-88,12.41-mineDepth/2,66,30,mineDepth,14,P.stone,0,true)
 for _,x in ipairs({-99,-77}) do
  local portalDepth=math.max(.2,13+plan.dy-mineBottom+.2)
  prop('PortalFooting',x,13-portalDepth/2,66,7,portalDepth,9,P.stone,0,true)
  prop('RubyPortalRock',x,22,66,7,18,9,Color3.fromRGB(112,70,66),x==-99 and -8 or 8,true)
  prop('MineTimber',x==-99 and -95 or -81,19,62.5,1.1,12,1.3,Color3.fromRGB(92,65,52),0,true)
 end
 prop('RubyLintel',-88,30,67,27,6,11,Color3.fromRGB(158,98,85),0,true)
 prop('MineCrossbeam',-88,25,62.5,15,1.4,1.5,Color3.fromRGB(111,75,51),0,true)
 prop('MineShadow',-88,20.25,70.8,14,14.5,.2,Color3.fromRGB(34,35,43))
 prop('MineFloor',-88,12.7,66,15,.6,11,P.stone,0,true)
 for _,x in ipairs({-92.5,-83.5}) do
  local lamp=prop('AmberMineLamp',x,22.5,61.6,.8,1,.7,P.amber);light(lamp,P.amber,13,.6)
  prop('MineLampCable',x,23.65,61.9,.12,1.3,.12,P.metal)
 end
 for i=1,6 do prop('MineSleeper',-88,13.08,62+i*1.15,8,.18,.5,Color3.fromRGB(98,70,51)) end
 for _,x in ipairs({-90.8,-85.2}) do prop('OreRail',x,13.22,66.2,.16,.16,9,P.metal) end
 -- A little ore trolley and abandoned hand tools, built from the same simple parts.
 site(-63,35,2)
 local cartX,cartZ=-63,35;local cartGround=groundAt(cartX,cartZ)
 prop('OreCart',cartX,cartGround+2,cartZ,4,2.5,3,P.metal,14)
 prop('CartOre',cartX,cartGround+3.3,cartZ,3.5,.5,2.5,P.coral,14)
 for _,x in ipairs({cartX-1.6,cartX+1.6}) do for _,z in ipairs({cartZ-1,cartZ+1}) do
  local wheel=prop('CartWheel',x,cartGround+.6,z,.5,1.2,1.2,P.ink);wheel.Shape=Enum.PartType.Cylinder
 end end
 -- Walkable overlook sits above the grove; one short sign replaces floating text.
 site(-65,77)
 prop('OverlookDeck',-65,33.8,77,13,.6,12,P.ledge,0,true)
 for _,x in ipairs({-70,-60}) do for _,z in ipairs({73,81}) do
  local ground=groundAt(x,z);local top=33.5+plan.dy;local height=math.max(.2,top-ground)
  prop('OverlookSupport',x,(top+ground)/2-plan.dy,z,.9,height,.9,P.metal,0,true)
 end end
 for _,z in ipairs({72,82}) do
  prop('LookoutRail',-65,36,z,13,.35,.35,P.metal)
  for _,x in ipairs({-71,-65,-59}) do prop('LookoutPost',x,35,z,.35,2.5,.35,P.metal) end
 end
 sign(props,at(-65,34,81),'RUBY LOOKOUT','GROVE BELOW',P.coral,at(-87,13,46))
 -- A narrow aqueduct/waterfall gives the upper pass an unmistakable silhouette.
 site(-12,-101)
 local aqueductY=math.max(groundAt(-20,-101),groundAt(-4,-101))+12
 for _,x in ipairs({-20,-4}) do
  local ground=groundAt(x,-101);local height=aqueductY-ground
  prop('AqueductPier',x,(aqueductY+ground)/2-plan.dy,-101,3.5,height,5,P.ledge,0,true)
 end
 prop('AqueductLintel',-12,aqueductY,-101,21,2.5,6,P.ivory,0,true)
 prop('WaterChannel',-12,aqueductY+1.3,-101,19,.2,2.5,Color3.fromRGB(82,193,216))
 prop('WaterSpout',-21,aqueductY+.8,-97.5,2,1,10,P.ledge)
 prop('SpoutWater',-21,aqueductY+1.35,-97.5,1.2,.15,10,Color3.fromRGB(82,193,216))
 local poolGround=groundAt(-21,-94)
 local poolPosition=at(-21,0,-94);local poolTop,poolBottom=plan:foundation(poolPosition.X,poolPosition.Z,6)
 poolGround=poolTop
 local poolDepth=math.max(.2,poolTop-poolBottom+.2)
 prop('PoolFoundation',-21,poolTop-poolDepth/2-plan.dy,-94,11,poolDepth,12,P.stone,0,true)
 local fallTop=aqueductY+1.3;local fallHeight=fallTop-poolGround
 local fall=prop('MineralWaterfall',-21,poolGround+fallHeight/2,-94,1.1,fallHeight,3.2,Color3.fromRGB(81,190,208));fall.Transparency=.25
 prop('PoolBank',-21,poolGround+.11,-94,11,.2,12,P.ledge)
 prop('PoolWater',-21,poolGround+.24,-94,9,.12,10,Color3.fromRGB(54,154,181))
 -- Emerald's preserved segmented construct crowns the ridge as a dormant landmark.
 site(62,9)
 prop('ConstructPlinth',62,constructGround-.5-plan.dy,9,13,1,13,P.ledge,0,true)
 local constructDepth=math.max(.2,constructGround-1-constructLow+.2)
 prop('ConstructBedrock',62,constructGround-1-constructDepth/2-plan.dy,9,13,constructDepth,13,P.stone,0,true)
 -- Leaf/flower clusters, fungi, fallen trunks and survey equipment occupy the
 -- negative space around trees. Deterministic placement keeps repeat builds equal.
 for i,t in ipairs(plan.trees) do
  -- A few composed clusters, not one repeated decorative carpet per tree.
  if i%3==0 then for n=1,1 do
   local angle=i*2.1+n*1.7;local x=t.x+math.cos(angle)*(3+n);local z=t.z+math.sin(angle)*(3+n)
   if plan:routeClear(x,z,1.8) and plan:fieldClear(x,z,2) then
    local ground,bottom=plan:foundation(x,z,1.4);local color=foliage[t.biome]
    if ground-bottom<=1.5 then
     local depth=math.max(.2,ground-bottom+.2)
     solid(block(props,'GrowthFooting',Vector3.new(x,ground-depth/2,z),Vector3.new(2.8,depth,2.8),P.stone))
     block(props,'Undergrowth',Vector3.new(x,ground+.65,z),Vector3.new(2.2,1.3,1.8),color:Lerp(P.ground,.4),Enum.Material.SmoothPlastic,{0,angle,0})
     local stem=block(props,'FlowerStem',Vector3.new(x+.8,ground+1.3,z+.3),Vector3.new(.18,1.5,.18),P.metal)
     local blossom=block(props,'ShelfFungus',stem.Position+Vector3.new(0,.8,0),Vector3.new(1.8,.3,1.8),color:Lerp(P.amber,.35))
     blossom.CFrame=blossom.CFrame*CFrame.Angles(0,angle,0)
    end
   end
  end end
 end
 -- Deliberate little discoveries along the lower loop, never new interaction UI.
 site(-102,-9)
 for i=1,4 do
  local x,z=-108+i*3,-12+i*1.5;local y=groundAt(x,z)
  prop('SurveyCrate',x,y+1.2,z,2.4,2.4,2.4,i%2==0 and P.amber or P.edge,i*13)
  prop('CrateBand',x,y+1.2,z,2.45,.32,2.45,P.ivory,i*13)
 end
 -- Giant flat-capped alien fungi mark the first route, without copying the reference's assets.
 for _,m in ipairs({{-8,3,6},{-3,43,8},{-50,54,5}}) do
  local x,z,h=m[1],m[2],m[3];site(x,z);local world=at(x,0,z);local y,bottom=plan:foundation(world.X,world.Z,.8)
  local depth=math.max(.2,y-bottom+.2)
  prop('FungusFooting',x,y-depth/2-plan.dy,z,1.6,depth,1.6,P.stone,0,true)
  prop('FungusStalk',x,y+h/2-plan.dy,z,1,h,1,P.ledge)
  prop('FungusCap',x,y+h-plan.dy,z,h*.9,1.3,h*.75,P.amber,-8)
  prop('FungusCrown',x-.5,y+h+.9-plan.dy,z,h*.55,.6,h*.5,P.ivory,4)
 end
 site(-24,-50)
 surveyGate(map,at(-24,groundAt(-24,-50)-plan.dy,-50),P.blue,plan)
 root:SetAttribute('TreeCount',#plan.trees);root:SetAttribute('RouteCount',#plan.routes);root:SetAttribute('MapScale',MapLayout.Scale);root:SetAttribute('OpenHubRadius',46)
 root:SetAttribute('SourceSceneIntegrated',true);root:SetAttribute('FieldCount',#fields);root:SetAttribute('ArtDirection','Mining Away / Studded Terraces / Retrieval Beacon')
 return {root=root,map=map,home=home,printer=printer,packStation=packs,prestigeStation=prestige,converter=converter,fields=fields,turretTemplate=turretTemplate,droneTemplate=rs:FindFirstChild('Drone'),crystalTemplate=rs:FindFirstChild('Crystal')}
end
return W
