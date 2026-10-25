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
 local eye=model:FindFirstChild('eye',true);eye.Material=Enum.Material.Neon;eye.Color=color
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
 ground=Color3.fromRGB(75,85,80),dust=Color3.fromRGB(111,113,98),stone=Color3.fromRGB(67,78,80),
 ledge=Color3.fromRGB(94,107,105),metal=Color3.fromRGB(38,51,55),edge=Color3.fromRGB(112,134,132),
 ivory=Color3.fromRGB(227,224,199),ink=Color3.fromRGB(24,37,42),mint=Color3.fromRGB(127,206,179),
 amber=Color3.fromRGB(223,169,101),blue=Color3.fromRGB(135,178,209),
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
 local p=solid(block(parent,'Trail',middle,Vector3.new(width or 11,.28,(b-a).Magnitude),P.dust,Enum.Material.Ground))
 p.CFrame=CFrame.lookAt(middle,b);p:SetAttribute('WalkRoute',true)
 -- Inlaid shoulder and short waymarkers give the trail a direction without neon rails.
 local flat=Vector3.new(b.X-a.X,0,b.Z-a.Z);local side=Vector3.new(-flat.Z,0,flat.X).Unit
 for _,sgn in ipairs({-1,1}) do
  local shoulder=block(parent,'TrailShoulder',middle+side*((width or 11)/2+.5)*sgn-Vector3.new(0,.1,0),Vector3.new(.8,.25,(b-a).Magnitude),P.ground,Enum.Material.Slate)
  shoulder.CFrame=CFrame.lookAt(shoulder.Position,b+side*((width or 11)/2+.5)*sgn)
 end
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
local function tree(parent,x,z,h,color,ground,yaw)
 local m=Instance.new('Model');m.Name='QuarryTree';m.Parent=parent
 ground=ground or 0;yaw=yaw or x*.1
 local trunkColor=Color3.fromRGB(70,84,82)
 local function localPart(name,p,size,tint,turn)
  local cf=CFrame.new(x,ground,z)*CFrame.Angles(0,yaw,0)*CFrame.new(p)
  local v=block(m,name,cf.Position,size,tint,Enum.Material.SmoothPlastic);v.CFrame=cf*CFrame.Angles(0,0,turn or 0);return v
 end
 localPart('Trunk',Vector3.new(0,h*.43,0),Vector3.new(.8,h*.86,.85),trunkColor,math.rad(-5))
 localPart('Fork',Vector3.new(1.5,h*.72,0),Vector3.new(.6,h*.46,.65),trunkColor,math.rad(-32))
 localPart('Canopy',Vector3.new(-.6,h,.25),Vector3.new(h*.69,1.45,h*.48),color,math.rad(-6))
 localPart('Canopy',Vector3.new(2.7,h*.94,.1),Vector3.new(h*.5,1.3,h*.39),color:Lerp(P.ledge,.12),math.rad(7))
 localPart('Canopy',Vector3.new(-1.1,h+1.1,.3),Vector3.new(h*.43,1.1,h*.35),color:Lerp(P.ivory,.08),math.rad(-3))
 return m
end
local function stone(parent,at,size,tilt,color,name)
 return solid(block(parent,name or 'WeatheredStone',at,size,color or P.stone,Enum.Material.Slate,{math.rad(tilt[1] or 0),math.rad(tilt[2] or 0),math.rad(tilt[3] or 0)}))
end
local function geology(parent,x,z,w,h,d,yaw)
 local m=Instance.new('Model');m.Name='StratifiedOutcrop';m.Parent=parent
 stone(m,Vector3.new(x,h*.35,z),Vector3.new(w,h*.7,d),{0,yaw,-6},P.stone)
 stone(m,Vector3.new(x-1.2,h*.77,z-.5),Vector3.new(w*.77,h*.31,d*.85),{0,yaw+5,-7},P.ledge)
 block(m,'MineralSeam',Vector3.new(x-.8,h*.64,z),Vector3.new(w*.82,.18,d*.89),P.ground,Enum.Material.SmoothPlastic,{0,math.rad(yaw+3),math.rad(-6)})
 return m
end
local function lighting()
 local l=game:GetService('Lighting')
 l.ClockTime=16.4;l.GeographicLatitude=28;l.Brightness=2.35;l.ExposureCompensation=.12
 l.Ambient=Color3.fromRGB(94,102,120);l.OutdoorAmbient=Color3.fromRGB(132,140,148)
 l.ColorShift_Top=Color3.fromRGB(255,226,194);l.ColorShift_Bottom=Color3.fromRGB(74,92,112)
 l.EnvironmentDiffuseScale=.72;l.EnvironmentSpecularScale=.22;l.GlobalShadows=true;l.ShadowSoftness=.3
 l.FogColor=Color3.fromRGB(167,172,183);l.FogStart=200;l.FogEnd=700
 local a=l:FindFirstChildOfClass('Atmosphere') or Instance.new('Atmosphere');a.Name='QuarryAtmosphere';a.Density=.255;a.Offset=.12;a.Color=Color3.fromRGB(192,198,209);a.Decay=Color3.fromRGB(121,137,150);a.Glare=.12;a.Haze=1.2;a.Parent=l
 local grade=l:FindFirstChildOfClass('ColorCorrectionEffect') or Instance.new('ColorCorrectionEffect');grade.Name='QuarryGrade';grade.Enabled=true;grade.Brightness=.015;grade.Contrast=.08;grade.Saturation=-.12;grade.TintColor=Color3.fromRGB(255,245,232);grade.Parent=l
 local bloom=l:FindFirstChildOfClass('BloomEffect') or Instance.new('BloomEffect');bloom.Name='QuarryBloom';bloom.Enabled=true;bloom.Intensity=.11;bloom.Size=20;bloom.Threshold=1.6;bloom.Parent=l
 local rays=l:FindFirstChildOfClass('SunRaysEffect') or Instance.new('SunRaysEffect');rays.Name='QuarrySun';rays.Intensity=.035;rays.Spread=.65;rays.Parent=l
 for _,v in ipairs(l:GetChildren()) do if v:IsA('DepthOfFieldEffect') then v.Enabled=false end end
 local sky=l:FindFirstChildOfClass('Sky');if sky then sky.SunAngularSize=8;sky.MoonAngularSize=4;sky.StarCount=450 end
end
local function cleanSurface(part,archive)
 part.MaterialVariant='';part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 for _,v in ipairs(part:GetChildren()) do if v:IsA('Texture') or v:IsA('Decal') then v.Parent=archive end end
end
function W.initialize()
 local cfg=Config
 local rs=game:GetService('ReplicatedStorage');local storage=game:GetService('ServerStorage')
 local root=Instance.new('Folder');root.Name='MiningAway';root.Parent=workspace
 local map=Instance.new('Folder');map.Name='Map';map.Parent=root
 for _,name in ipairs({'Fields','Drones','Resources','Turrets'}) do local f=Instance.new('Folder');f.Name=name;f.Parent=root end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local home=spawn and spawn.Position or Vector3.new(-56,.5,-11)
 local archive=Instance.new('Folder');archive.Name='MiningAwayOriginalReference';archive.Parent=storage
 for _,name in ipairs({'FaceTest','Test','sphere','Mesh','Crystals','MiningEffect','Beam','Cat','potato'}) do
  local original=workspace:FindFirstChild(name);if original then original.Parent=archive end
 end
 local construct=workspace:FindFirstChild('construct')
 assert(construct and construct:IsA('Model'),'The supplied source must retain Workspace.construct')
 local turretTemplate=construct:Clone();turretTemplate.Name='OriginalConstructTemplate';turretTemplate.Parent=storage
 construct:SetAttribute('DormantLandmark',true)
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then cleanSurface(baseplate,archive);baseplate.Color=P.ground;baseplate.Material=Enum.Material.Ground end
 if spawn then cleanSurface(spawn,archive);spawn.Color=P.ledge;spawn.Material=Enum.Material.Metal end
 -- Retain the author's simple parts-built trees, now under the same restrained palette.
 for _,model in ipairs(workspace:GetChildren()) do
  if model:IsA('Model') and model.Name=='Model' then
   for _,v in ipairs(model:GetDescendants()) do
    if v:IsA('BasePart') then cleanSurface(v,archive);v.Material=Enum.Material.SmoothPlastic;v.Color=v.Size.Y>v.Size.X*1.7 and Color3.fromRGB(70,84,82) or Color3.fromRGB(94,126,119) end
   end
  end
 end
 lighting()
 local depot=solid(block(map,'DepotApron',Vector3.new(home.X,.1,home.Z),Vector3.new(40,.2,34),P.ledge,Enum.Material.Concrete));depot:SetAttribute('SafeDepot',true)
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
  cleanSurface(part,archive)
  local accent=Color3.fromRGB(unpack(field.Color))
  part.Name='Field';part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.Color=P.ground:Lerp(accent,.13);part.Material=Enum.Material.Ground;part:SetAttribute('FieldId',id);part:SetAttribute('Patch',id)
  local top=part.Position.Y+part.Size.Y/2;local bottom=part.Position.Y-part.Size.Y/2
  -- The original raised Ruby patch is now visibly supported by a low layered mesa.
  if bottom>.4 then
   solid(block(model,'FieldBedrock',Vector3.new(part.Position.X,bottom/2,part.Position.Z),Vector3.new(part.Size.X+4,bottom,part.Size.Z+4),P.stone,Enum.Material.Slate))
   solid(block(model,'FieldSkirt',Vector3.new(part.Position.X,bottom*.23,part.Position.Z),Vector3.new(part.Size.X+10,math.max(.4,bottom*.46),part.Size.Z+8),P.ledge,Enum.Material.Slate))
  end
  -- Authored shoulder locations follow each incoming trail. Ground-level feet
  -- avoid the former floating Ruby sign and keep boards off the walking centerline.
  local shoulders={{-3,-23},{6,-33},{-12,24},{-30,9},{-32,-5}}
  local shoulder=shoulders[id];local edge=Vector3.new(part.Position.X+shoulder[1],0,part.Position.Z+shoulder[2])
  local subtitle=id==1 and 'SAFE  /  START HERE' or field.Turrets>0 and 'GUARDED  /  '..field.RecommendedFleet..'+ DRONES' or 'SAFE  /  RICHER ORE'
  local facing=id>3 and fields[id-1].center or home
  sign(model,edge,string.format('%02d  %s',id,field.Name:upper()),subtitle,accent,facing)
  -- Short corner caps read as a footprint and leave every field side walkable.
  for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local corner=part.Position+Vector3.new(x*(part.Size.X/2+.3),top-part.Position.Y+.15,z*(part.Size.Z/2+.3))
   block(model,'FieldCorner',corner-Vector3.new(x*2.2,0,0),Vector3.new(4.4,.25,.42),accent:Lerp(P.ledge,.45),Enum.Material.SmoothPlastic)
   block(model,'FieldCorner',corner-Vector3.new(0,0,z*2.2),Vector3.new(.42,.25,4.4),accent:Lerp(P.ledge,.45),Enum.Material.SmoothPlastic)
  end end
  table.insert(fields,{id=id,cfg=field,center=part.Position,part=part,model=model})
 end
 -- Every route starts at the existing depot and stays at the source landscape's elevation.
 path(map,home+Vector3.new(-11,-.2,-8),Vector3.new(-82,.4,-33),10)
 path(map,home+Vector3.new(12,-.2,9),fields[1].center+Vector3.new(-10,1.14,-10),12)
 path(map,home+Vector3.new(-9,-.2,14),Vector3.new(-76,6,32),12)
 path(map,Vector3.new(-76,6,32),fields[2].center+Vector3.new(0,1.14,-14),12)
 path(map,home+Vector3.new(0,-.2,-16),fields[3].center+Vector3.new(0,1.14,17),12)
 path(map,fields[3].center+Vector3.new(15,1.14,3),fields[4].center+Vector3.new(-18,1.14,3),11)
 path(map,fields[4].center+Vector3.new(18,1.14,7),fields[5].center+Vector3.new(-19,1.14,-5),11)
 -- Sparse field-specific silhouettes frame the playable clearings instead of filling them.
 local trees={
  {-111,30,12,2},{-115,62,15,2},{-101,82,11,2},{-72,79,12,2},{-47,54,9,1},{-6,49,12,1},{0,16,10,1},
  {-81,-108,10,3},{-68,-113,13,3},{-21,-113,9,3},{3,-107,11,4},{56,-93,14,4},{61,-45,11,4},
  {74,7,12,5},{115,-6,16,5},{118,-43,13,5},{-113,-12,10,1},{-106,-55,12,1},
 }
 local foliage={Color3.fromRGB(96,132,119),Color3.fromRGB(151,106,120),Color3.fromRGB(105,129,151),Color3.fromRGB(128,118,149),Color3.fromRGB(76,135,119)}
 for i,t in ipairs(trees) do tree(map,t[1],t[2],t[3],foliage[t[4]],0,i*.73) end
 local rocks={
  {-112,45,15,8,10,-12},{-99,74,13,6,10,25},{-76,73,11,7,9,-20},
  {-80,-94,17,8,13,15},{-64,-113,16,11,12,-8},{-15,-105,21,9,12,8},
  {19,-98,24,12,15,-16},{53,-90,17,9,12,22},{65,-44,12,7,10,20},
  {79,-58,19,12,11,-8},{114,-45,17,14,12,14},{119,-12,14,10,12,-18},
  {-9,66,18,7,12,-12},{-123,-15,19,12,16,17},
 }
 for _,r in ipairs(rocks) do geology(map,unpack(r)) end
 -- One readable distant ridgeline closes the empty baseplate horizon. All stone is grounded.
 for _,r in ipairs({{-151,-78,38,28,30,15},{-130,-128,43,34,26,-12},{-65,-153,48,24,28,5},{9,-148,50,32,30,-9},{81,-132,42,41,31,12},{139,-98,34,35,30,-18},{153,-35,31,30,28,10},{148,39,46,25,28,-7},{52,87,42,22,27,15},{-37,108,48,27,28,-10},{-119,109,43,32,28,8}}) do geology(map,unpack(r)) end
 -- Survey pylons repeat the segmented original landmark's proportions at the last ridge.
 for i=1,3 do
  local p=Vector3.new(133+i*7,0,-79+i*5)
  stone(map,p+Vector3.new(0,6+i*3,0),Vector3.new(3,12+i*6,3),{0,0,(i-2)*6},P.ledge,'SurveyMonolith')
 end
 root:SetAttribute('SourceSceneIntegrated',true);root:SetAttribute('FieldCount',#fields);root:SetAttribute('ArtDirection','Weathered Quarry / Warm Sun / Cool Mineral')
 return {root=root,map=map,home=home,printer=printer,packStation=packs,prestigeStation=prestige,converter=converter,fields=fields,turretTemplate=turretTemplate,droneTemplate=rs:FindFirstChild('Drone'),crystalTemplate=rs:FindFirstChild('Crystal')}
end
return W
