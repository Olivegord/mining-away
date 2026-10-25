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
local function solid(p) p.CanCollide=true;p.CanQuery=true;return p end
local function path(parent,a,b,width)
 local middle=(a+b)/2
 local p=solid(W.part(parent,'Trail',middle,Vector3.new(width or 9,.35,(b-a).Magnitude),Color3.fromRGB(73,96,90),Enum.Material.Slate))
 p.CFrame=CFrame.lookAt(middle,b);return p
end
local function sign(parent,at,title,subtitle,color,facing)
 W.part(parent,'SignPost',at+Vector3.new(0,1.6,0),Vector3.new(.3,3.2,.3),Color3.fromRGB(65,79,75),Enum.Material.Metal)
 local board=W.part(parent,'FieldSign',at+Vector3.new(0,3.4,0),Vector3.new(9,2.8,.35),Color3.fromRGB(23,39,42));board.CanQuery=true
 if facing then board.CFrame=CFrame.lookAt(board.Position,Vector3.new(facing.X,board.Position.Y,facing.Z)) end
 local g=Instance.new('SurfaceGui');g.Name='SignFace';g.Face=Enum.NormalId.Front;g.CanvasSize=Vector2.new(500,160);g.LightInfluence=.1;g.Parent=board
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,.48);t.Position=UDim2.fromScale(0,.08);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextSize=27;t.TextColor3=color;t.Text=title;t.Parent=g
 local s=Instance.new('TextLabel');s.Size=UDim2.fromScale(.92,.35);s.Position=UDim2.fromScale(.04,.57);s.BackgroundTransparency=1;s.Font=Enum.Font.Gotham;s.TextSize=19;s.TextWrapped=true;s.TextColor3=Color3.fromRGB(223,235,225);s.Text=subtitle;s.Parent=g
 return board
end
local function station(parent,name,at,color,title,interaction)
 local base=solid(W.part(parent,name,at+Vector3.new(0,1,0),Vector3.new(5,2,4),Color3.fromRGB(35,50,54),Enum.Material.Metal))
 W.part(parent,name..'Accent',at+Vector3.new(0,2.1,0),Vector3.new(4,.25,3),color,Enum.Material.Neon)
 W.part(parent,name..'Screen',at+Vector3.new(0,3,0),Vector3.new(3.8,1.5,.35),color,Enum.Material.Glass)
 base:SetAttribute('Interaction',interaction)
 local prompt=Instance.new('ProximityPrompt');prompt.ActionText=title;prompt.ObjectText=name=='PackStation' and 'RUN CARDS' or 'PERMANENT FLEET';prompt.MaxActivationDistance=11;prompt.HoldDuration=0;prompt.RequiresLineOfSight=false;prompt.Parent=base
 return base
end
local function tree(parent,x,z,h,color)
 local m=Instance.new('Model');m.Name='AlienTree';m.Parent=parent
 local trunk=solid(W.part(m,'Trunk',Vector3.new(x,h/2,z),Vector3.new(1.1,h,1.1),Color3.fromRGB(73,93,84),Enum.Material.Wood))
 trunk.CFrame=CFrame.new(trunk.Position)*CFrame.Angles(0,0,math.rad((x%7)-3))
 for i=1,3 do
  local crown=W.part(m,'Crown',Vector3.new(x+(i-2)*1.2,h+(i-1)*1.2,z),Vector3.new(6-i*.8,1.6,5-i*.5),color)
  crown.CFrame=CFrame.new(crown.Position)*CFrame.Angles(0,math.rad(i*32+x%30),0)
 end
 return m
end
function W.initialize()
 local cfg=Config
 local rs=game:GetService('ReplicatedStorage');local storage=game:GetService('ServerStorage')
 local root=Instance.new('Folder');root.Name='MiningAway';root.Parent=workspace
 local map=Instance.new('Folder');map.Name='Map';map.Parent=root
 for _,name in ipairs({'Fields','Drones','Resources','Turrets'}) do local f=Instance.new('Folder');f.Name=name;f.Parent=root end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local home=spawn and spawn.Position or Vector3.new(-56,.5,-11)
 -- Keep source objects and pose exactly; only known experimental display props are archived at runtime.
 local archive=Instance.new('Folder');archive.Name='MiningAwayOriginalReference';archive.Parent=storage
 for _,name in ipairs({'FaceTest','Test','sphere','Mesh','Crystals','MiningEffect','Beam'}) do
  local original=workspace:FindFirstChild(name)
  if original then original.Parent=archive end
 end
 local construct=workspace:FindFirstChild('construct')
 assert(construct and construct:IsA('Model'),'The supplied source must retain Workspace.construct')
 local turretTemplate=construct:Clone();turretTemplate.Name='OriginalConstructTemplate';turretTemplate.Parent=storage
 -- The original construct remains in its authored location as a silent alien landmark.
 construct:SetAttribute('DormantLandmark',true)
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then baseplate.Color=Color3.fromRGB(39,65,61);baseplate.Material=Enum.Material.Grass end
 local depot=solid(W.part(map,'DepotApron',Vector3.new(home.X,0,home.Z),Vector3.new(38,.3,32),Color3.fromRGB(57,77,75),Enum.Material.Slate))
 depot:SetAttribute('SafeDepot',true)
 -- Low open-sided depot framework keeps the drone ring and sky unobstructed.
 for _,dx in ipairs({-15,15}) do
  W.part(map,'DepotPillar',Vector3.new(home.X+dx,4.5,home.Z-10),Vector3.new(1.2,9,1.2),Color3.fromRGB(100,130,117),Enum.Material.Metal)
 end
 W.part(map,'DepotLintel',Vector3.new(home.X,9.2,home.Z-10),Vector3.new(32,1.3,2),Color3.fromRGB(112,149,135),Enum.Material.Metal)
 sign(map,Vector3.new(home.X+15,0,home.Z+10),'MINING AWAY','Quartz → Ruby → Cobalt',Color3.fromRGB(160,227,198))
 local printer=station(map,'Printer',home+Vector3.new(12,-.5,-3),Color3.fromRGB(91,215,188),'Free reprint','Printer')
 local packs=station(map,'PackStation',home+Vector3.new(-12,-.5,-3),Color3.fromRGB(112,181,237),'Open pack','Pack')
 local prestige=station(map,'PrestigeStation',home+Vector3.new(0,-.5,-12),Color3.fromRGB(221,186,106),'Review prestige','Prestige')
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then
  converter:SetAttribute('Interaction','Sell')
  local prompt=Instance.new('ProximityPrompt');prompt.ActionText='Sell cargo';prompt.ObjectText='CONVERTER';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=converter
  sign(map,converter.Position+Vector3.new(0,-4,4),'CONVERTER','Sell cargo for run credits',Color3.fromRGB(150,223,201))
 end
 local fields={};local originals=workspace:FindFirstChild('Patches')
 for id,field in ipairs(cfg.Fields) do
  local model=Instance.new('Model');model.Name=field.Key;model:SetAttribute('FieldId',id);model:SetAttribute('Tier',id);model.Parent=root.Fields
  local part=originals and field.Original and originals:FindFirstChild(field.Original)
  if part and part:IsA('BasePart') then part.Parent=model
  else
   local o=field.Offset;part=W.part(model,'Field',home+Vector3.new(o[1],o[2],o[3]),Vector3.new(unpack(field.Size)),Color3.fromRGB(unpack(field.Color)),Enum.Material.Grass)
  end
  part.Name='Field';part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.Color=Color3.fromRGB(unpack(field.Color)):Lerp(Color3.fromRGB(40,64,59),.64);part.Material=Enum.Material.Grass;part:SetAttribute('FieldId',id);part:SetAttribute('Patch',id)
  local toHome=Vector3.new(home.X-part.Position.X,0,home.Z-part.Position.Z)
  local entrance=toHome.Magnitude>.01 and toHome.Unit or Vector3.new(0,0,-1)
  local edge=part.Position+entrance*(math.max(part.Size.X,part.Size.Z)/2+3)+Vector3.new(0,part.Size.Y/2,0)
  sign(model,edge,field.Name:upper(),field.Turrets>0 and 'GUARDED • join an expedition' or 'SAFE • assign your drone',Color3.fromRGB(unpack(field.Color)),home)
  -- Low edge stones identify field footprint without trapping the player.
  for _,side in ipairs({-1,1}) do W.part(model,'Boundary',part.Position+Vector3.new(side*(part.Size.X/2+.4),1,0),Vector3.new(.6,1.3,part.Size.Z),Color3.fromRGB(unpack(field.Color)):Lerp(Color3.fromRGB(56,72,68),.45),Enum.Material.Slate) end
  table.insert(fields,{id=id,cfg=field,center=part.Position,part=part,model=model})
 end
 -- Ground-level routes are sunk into the existing world, not floating test platforms.
 path(map,home+Vector3.new(-7,.2,-7),Vector3.new(-82,.7,-33),9)
 path(map,home+Vector3.new(13,.2,8),fields[1].center+Vector3.new(-10,1,-10),11)
 path(map,home+Vector3.new(-8,.2,14),Vector3.new(-76,6,32),10)
 path(map,Vector3.new(-76,6,32),fields[2].center+Vector3.new(0,1,-12),10)
 path(map,home+Vector3.new(0,.2,-16),fields[3].center+Vector3.new(0,1,17),11)
 path(map,fields[3].center+Vector3.new(15,1,3),fields[4].center+Vector3.new(-18,1,3),10)
 path(map,fields[4].center+Vector3.new(18,1,7),fields[5].center+Vector3.new(-19,1,-5),10)
 local trees={{-109,-16,9},{-102,19,12},{-119,51,10},{-95,79,13},{-65,76,8},{-45,54,11},{-3,50,10},{2,14,13},{-8,-20,10},{-82,-69,12},{-72,-108,10},{-20,-111,14},{4,-96,9},{32,-95,12},{59,-78,14},{67,-22,12},{106,-60,13},{116,5,11},{73,18,14}}
 for i,t in ipairs(trees) do tree(map,t[1],t[2],t[3],i%2==0 and Color3.fromRGB(72,133,117) or Color3.fromRGB(88,118,139)) end
 -- A sparse landmark cluster frames the progression vista beyond the live fields.
 for i=1,3 do
  local monolith=solid(W.part(map,'FarMonolith',Vector3.new(132+i*7,5+i*3,-84+i*5),Vector3.new(3,10+i*6,3),Color3.fromRGB(90,113,111),Enum.Material.Slate))
  monolith.CFrame=CFrame.new(monolith.Position)*CFrame.Angles(0,0,math.rad((i-2)*8))
 end
 root:SetAttribute('SourceSceneIntegrated',true);root:SetAttribute('FieldCount',#fields)
 return {root=root,map=map,home=home,printer=printer,packStation=packs,prestigeStation=prestige,converter=converter,fields=fields,turretTemplate=turretTemplate,droneTemplate=rs:FindFirstChild('Drone'),crystalTemplate=rs:FindFirstChild('Crystal')}
end
return W
