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
 part.Color=Color3.fromRGB(111,120,123):Lerp(color,.18)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('BasePart') then v.Material=Enum.Material.SmoothPlastic;v.Reflectance=0 end
 end
 model.PrimaryPart=part;model.Parent=parent;model:PivotTo(CFrame.new(pos))
 local emitter=model:FindFirstChild('Emmiter',true)
 if not emitter or not emitter:IsA('BasePart') then emitter=W.part(model,'Emmiter',pos,Vector3.new(.24,.24,.24),color,Enum.Material.Neon) end
 emitter.Color=color;emitter.CanQuery=false;emitter.Material=Enum.Material.SmoothPlastic
 model:ScaleTo(model:GetScale()*.58);model:SetAttribute('ModelScale',.58)
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
 local p=solid(block(parent,'Trail',middle,Vector3.new(width or 11,.28,(b-a).Magnitude),P.dust,Enum.Material.SmoothPlastic))
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
 local prompt=Instance.new('ProximityPrompt');prompt.ActionText=title;prompt.ObjectText=name=='PackStation' and 'RUN CARDS' or name=='Printer' and 'DRONE PRINTER' or 'PERMANENT FLEET';prompt.MaxActivationDistance=10;prompt.HoldDuration=0;prompt.RequiresLineOfSight=false;prompt.Enabled=true;prompt.Parent=base
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
  textFace(fascia,'PACK SHOP','',color)
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
 local trunkColor=Color3.fromRGB(85,70,66)
 local function localPart(name,p,size,tint,turn)
  local cf=CFrame.new(x,ground,z)*CFrame.Angles(0,yaw,0)*CFrame.new(p)
  local v=block(m,name,cf.Position,size,tint,Enum.Material.SmoothPlastic);v.CFrame=cf*CFrame.Angles(0,0,turn or 0);return v
 end
 -- Forked trunks and chunky, tiered crowns keep the original parts-built language.
 localPart('Trunk',Vector3.new(0,h*.39,0),Vector3.new(1.35,h*.78,1.5),trunkColor,math.rad(-4))
 localPart('Root',Vector3.new(-.8,.65,0),Vector3.new(3.8,1.3,2.7),trunkColor,math.rad(8))
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
local function surveyGate(parent,at,color)
 local m=Instance.new('Model');m.Name='PlotEntrance';m.Parent=parent
 for _,s in ipairs({-1,1}) do
  stone(m,at+Vector3.new(s*8,3.5,0),Vector3.new(2,7,3),{0,0,s*-5},P.ledge,'ChalkPylon')
  block(m,'GateMarker',at+Vector3.new(s*7.9,5.6,-1.53),Vector3.new(.3,2,.12),color,Enum.Material.Neon)
 end
 block(m,'GateLintel',at+Vector3.new(0,7.5,0),Vector3.new(18,1.15,3),P.ivory,Enum.Material.SmoothPlastic)
end
local function cleanSurface(part,archive)
 part.MaterialVariant='';part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 for _,v in ipairs(part:GetChildren()) do if v:IsA('Texture') or v:IsA('Decal') then v.Parent=archive end end
end
local function nativeFinish(part,material,studs)
 part.Material=material;part.MaterialVariant='';part.Reflectance=0
 part.TopSurface=studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
 part.BottomSurface=Enum.SurfaceType.Smooth
end

-- The authored terraces use the stud pack for nearly every surface, including
-- earth, plants and wood. Map those finishes to actual surface materials at
-- server startup so the original parts, placement and archives stay intact.
local QuarryBiomes=require('./QuarryBiomes')
local quarryVariants={}
local polishedOre=false
function W.applyQuarryVariant(part)
 part.MaterialVariant=quarryVariants[part.Material] or ''
end
function W.applyOreFinish(part)
 W.applyQuarryVariant(part)
 if polishedOre then
  part.MaterialVariant='QuarryOre_Polished'
  part.Reflectance=.11
 end
end
function W.applyQuarryTextures(scene)
 if not scene.root:GetAttribute('DronerevolutionMapVersion') then return end
 local terraces=scene.map:FindFirstChild('DronerevolutionTerraces')
 if not terraces then return end
 local material=Enum.Material
 local rgb=Color3.fromRGB
 -- Roblox restricts material definitions to Studio. The native document
 -- carries the 64 px photo tiles; gameplay only selects the named variants.
 for _,variant in ipairs(game:GetService('MaterialService'):GetChildren()) do
  local base=variant:IsA('MaterialVariant') and variant.Name:match('^QuarryPhoto_(%w+)$')
  if base then quarryVariants[material[base]]=variant.Name end
  if variant:IsA('MaterialVariant') and variant.Name=='QuarryOre_Polished' then polishedOre=true end
 end
 local oldFinish={
  DR_MeadowFine={material.Grass,rgb(103,112,77)},
  DR_MeadowMoss={material.LeafyGrass,rgb(87,101,70)},
  DR_MineralDust={material.Pebble,rgb(132,122,109)},
  DR_MineralSeams={material.Rock,rgb(113,105,98)},
  DR_CliffStrata={material.Sandstone,rgb(126,104,82)},
  DR_ExposedRock={material.Slate,rgb(109,98,86)},
  DR_WornPath={material.Pavement,rgb(143,134,116)},
 }
 local function finish(part,base,tint,foliageVariant)
  if part.Transparency>=1 or part.Material==material.Neon then return end
  if part.Material~=base or part.MaterialVariant~='' then
   -- Material changes can otherwise change friction and elasticity on paths.
   if not part.CustomPhysicalProperties then part.CustomPhysicalProperties=part.CurrentPhysicalProperties end
   part.Material=base;part.MaterialVariant=''
  end
  W.applyQuarryVariant(part)
  if foliageVariant then
   part.MaterialVariant=foliageVariant;part.Color=tint
  elseif base==material.Grass or base==material.LeafyGrass then
   -- The aerial tile is olive in its diffuse map. A green tint keeps grass
   -- legible against the orange cliffs under the authored dawn light.
   part.Color=rgb(154,239,197):Lerp(tint,.12)
  elseif base==material.Concrete or base==material.Pavement then
   part.Color=rgb(211,228,251):Lerp(tint,.14)
  else
   part.Color=quarryVariants[base] and rgb(252,249,239):Lerp(tint,.18) or tint
  end
  part.Reflectance=0
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  part.FrontSurface=Enum.SurfaceType.Smooth;part.BackSurface=Enum.SurfaceType.Smooth
  part.LeftSurface=Enum.SurfaceType.Smooth;part.RightSurface=Enum.SurfaceType.Smooth
 end
 for _,group in ipairs(terraces:GetChildren()) do
  for _,part in ipairs(group:GetDescendants()) do
   if not part:IsA('BasePart') then continue end
   local variant=part.MaterialVariant
   local color=part.Color
   local authored=oldFinish[variant]
   if authored then
    finish(part,authored[1],authored[2]:Lerp(color,.17))
   elseif group.Name=='WalkableRoutes' then
    local curb=part.Name:match('Curb$')
    finish(part,curb and material.Concrete or material.Pavement,curb and rgb(105,99,90) or rgb(151,139,114))
   elseif group.Name=='StudPackCliffs' then
    if variant=='Studs' then finish(part,material.Grass,rgb(100,109,72):Lerp(color,.17))
    elseif variant=='Universal' then finish(part,material.Rock,rgb(117,101,84):Lerp(color,.22)) end
   elseif group.Name=='WoodenMarketStalls' then
    if color.R>color.G*1.25 and color.G>color.B*1.2 then
     finish(part,material.WoodPlanks,rgb(123,98,74):Lerp(color,.22))
    else
     finish(part,material.CorrodedMetal,rgb(123,126,124):Lerp(color,.28))
    end
   elseif group.Name=='AssetScenery' or group.Name=='MarketGardens' then
    local prop=part.Parent.Name:lower()
    if prop:find('rock',1,true) then
     finish(part,material.Rock,rgb(109,110,107):Lerp(color,.16))
    elseif prop=='model' and variant=='' then
     finish(part,material.SmoothPlastic,color:Lerp(rgb(227,203,156),.16))
    elseif color.G>color.R and color.G>color.B then
     local tall=prop:find('tree2',1,true)
     local leaves=tall and 'QuarryFoliage_Evergreen' or 'QuarryFoliage_Canopy'
     finish(part,material.LeafyGrass,rgb(194,232,202):Lerp(color,.14),leaves)
    elseif prop:find('tree',1,true) then
     finish(part,material.Wood,rgb(233,225,215):Lerp(color,.13),'QuarryFoliage_Bark')
    end
   elseif part.Name=='ServiceDeck' or part.Parent.Name=='WornRouteSurfaces' then
    finish(part,material.Concrete,rgb(130,123,108))
   end
  end
 end
 for _,item in ipairs(terraces:GetDescendants()) do
  if item:IsA('Texture') and item.Name=='Checker Texture' and item.Texture=='rbxassetid://1372654506' then item:Destroy() end
 end
 for _,field in ipairs(scene.fields) do
  finish(field.part,material.Pebble,rgb(130,121,107):Lerp(field.part.Color,.24))
  local border=field.model:FindFirstChild('Border')
  if border and border:IsA('BasePart') then finish(border,material.Concrete,rgb(111,105,96):Lerp(border.Color,.25)) end
 end
 local depot=scene.map:FindFirstChild('SimpleFlatTestMap')
 if depot then
  for _,part in ipairs(depot:GetDescendants()) do
   if not part:IsA('BasePart') then continue end
   if part.Name:match('Pad$') then
    finish(part,material.Concrete,rgb(131,128,118):Lerp(part.Color,.21))
   elseif part.Name=='Printer' or part.Name=='PackStation' or part.Name=='PrestigeStation' then
    finish(part,material.CorrodedMetal,rgb(109,111,106):Lerp(part.Color,.28))
   end
  end
 end
 for _,part in ipairs(scene.map:GetChildren()) do
  if part:IsA('BasePart') and part.Name:match('Shop$') then
   finish(part,material.CorrodedMetal,rgb(112,115,111):Lerp(part.Color,.3))
  end
 end
 if scene.converter and scene.converter:IsA('BasePart') then
  finish(scene.converter,material.DiamondPlate,rgb(96,101,100))
 end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 if spawn then finish(spawn,material.Concrete,rgb(138,133,118)) end
 local fixtures=Instance.new('Folder');fixtures.Name='QuarryLights';fixtures.Parent=scene.map
 local routes=terraces:FindFirstChild('WalkableRoutes')
 local function fixture(name,frame,size,tint,range,strength)
  local lamp=block(fixtures,name,frame.Position,size,tint,material.Neon)
  lamp.CFrame=frame;lamp.CastShadow=false
  light(lamp,tint,range,strength)
 end
 for _,field in ipairs(scene.fields) do
  local key=field.cfg.Key
  local shop=scene.map:FindFirstChild(key..'Shop')
  local board=shop and shop:FindFirstChild('ShopSign')
  local tint=rgb(unpack(field.cfg.Color)):Lerp(rgb(247,245,233),.43)
  if board and board:IsA('BasePart') then
   local face=board:FindFirstChildWhichIsA('SurfaceGui')
   local front=face and face.Face==Enum.NormalId.Back and 1 or -1
   local frame=board.CFrame*CFrame.new(0,-board.Size.Y*.5-.08,front*(board.Size.Z*.5+.04))
   fixture(key..'ShopGlow',frame,Vector3.new(board.Size.X*.67,.16,.22),tint,17,1.3)
  end
  local ramp=routes and routes:FindFirstChild(key..'Ramp')
  if ramp and ramp:IsA('BasePart') then
   local frame=ramp.CFrame*CFrame.new(ramp.Size.X*.5+.17,ramp.Size.Y*.5+.16,0)
   fixture(key..'RampGlow',frame,Vector3.new(.24,.18,3.6),tint,13,1.25)
  end
 end
 for _,name in ipairs({'Printer','PackStation','PrestigeStation'}) do
  local station=scene.map:FindFirstChild(name,true)
  if station and station:IsA('BasePart') then
   local frame=station.CFrame*CFrame.new(0,station.Size.Y*.5+.07,-station.Size.Z*.32)
   fixture(station.Name..'Glow',frame,Vector3.new(station.Size.X*.62,.14,.24),rgb(164,232,248),15,1.2)
  end
 end
 QuarryBiomes.build(scene,terraces)
end
function W.ensureImpactField(root,fields)
 if root:GetAttribute('DronerevolutionMapVersion') and fields:FindFirstChild('ImpactTest') then return end
 local quartz=fields:FindFirstChild('Quartz');local source=quartz and quartz:FindFirstChild('Field')
 if not source then return end
 local cfg=Config.Fields[6]
 local model=fields:FindFirstChild(cfg.Key)
 if not model then
  model=Instance.new('Model');model.Name=cfg.Key;model.Parent=fields
  local bed=W.part(model,'Field',source.Position,Vector3.new(56,source.Size.Y,64),source.Color,Enum.Material.Slate)
  bed.Anchored=true;bed.CanCollide=true;bed.CanQuery=true
 end
 local bed=model:FindFirstChild('Field')
 local destination=source.Position+Vector3.new(source.Size.X/2+8+bed.Size.X/2,0,0)
 model:PivotTo(CFrame.new(destination-bed.Position)*model:GetPivot())
 model:SetAttribute('AlwaysUnlocked',true);model:SetAttribute('Mineral','Quartz');model:SetAttribute('DisplayName',cfg.Name)
 bed:SetAttribute('Mineral','Quartz')
 if not model:FindFirstChild('ImpactTestSign') then
  for _,side in ipairs({-1,1}) do
   local foot=W.part(model,'TestSignFoot',bed.Position+Vector3.new(side*5,1.5,-bed.Size.Z/2+1),Vector3.new(.3,3,.3),Color3.fromRGB(67,73,72),Enum.Material.Metal)
   foot.CanCollide=false
  end
  local board=W.part(model,'ImpactTestSign',bed.Position+Vector3.new(0,3,-bed.Size.Z/2+1),Vector3.new(13,3,.3),Color3.fromRGB(43,48,49),Enum.Material.Metal)
  textFace(board,'IMPACT TEST','10x ROCK HEALTH  /  ALWAYS OPEN',Color3.fromRGB(225,202,143))
 end
end
function W.layoutFields(root,fields,home)
 W.ensureImpactField(root,fields)
 -- Preserve the captured parts, machines and field identities. The former
 -- straight-line order placed Cobalt in front of spawn and Quartz at the end.
 -- Reuse the existing plot footprints, ordered by distance, then stagger the
 -- two right-hand plots so every later tier is farther from both depot and sell.
 if root:GetAttribute('PlotOrderVersion')~=1 and not root:GetAttribute('DronerevolutionMapVersion') then
  local slots={};local plots={}
  for id,cfg in ipairs(Config.Fields) do
   if cfg.TestField then continue end
   local model=fields:FindFirstChild(cfg.Key);local part=model and model:FindFirstChild('Field')
   assert(model and part and part:IsA('BasePart'),'Editable map is missing field '..cfg.Key)
   plots[id]={model=model,part=part};table.insert(slots,part.CFrame)
  end
  table.sort(slots,function(a,b)
   local ad=(a.Position-home).Magnitude;local bd=(b.Position-home).Magnitude
   if math.abs(ad-bd)<.01 then return a.Position.X<b.Position.X end
   return ad<bd
  end)
  for id,plot in ipairs(plots) do
   local target=slots[id]+Vector3.new(0,0,id==3 and 20 or id==5 and 40 or 0)
   local transform=target*plot.part.CFrame:Inverse()
   plot.model:PivotTo(transform*plot.model:GetPivot())
   plot.model:SetAttribute('Tier',id)
  end
  root:SetAttribute('PlotOrderVersion',1)
 end
 for id,cfg in ipairs(Config.Fields) do
  local model=fields:FindFirstChild(cfg.Key);local part=model:FindFirstChild('Field')
  model:SetAttribute('Tier',id);model:SetAttribute('FieldId',id);part:SetAttribute('FieldId',id)
  model:SetAttribute('AlwaysUnlocked',cfg.AlwaysUnlocked==true);model:SetAttribute('Mineral',cfg.Material or cfg.Key);part:SetAttribute('Mineral',cfg.Material or cfg.Key)
 end
end
local function finishEditableMap(root,map,fields,home)
 W.layoutFields(root,fields,home)
 if root:GetAttribute('DronerevolutionMapVersion') then return end
 -- Native Roblox surfaces provide readable material changes without global
 -- gloss: studded plastic trim, rough ore beds, paved lanes and metal machines.
 for _,part in ipairs(map:GetDescendants()) do if part:IsA('BasePart') then
  if part.Name=='HubPad' then nativeFinish(part,Enum.Material.Concrete);part.Color=Color3.fromRGB(179,175,139)
  elseif part.Name=='MainTestLane' or part.Name=='FieldTestLane' then nativeFinish(part,Enum.Material.Sandstone);part.Color=Color3.fromRGB(210,185,128)
  elseif part.Name:match('Pad$') then nativeFinish(part,Enum.Material.DiamondPlate)
  elseif part.Name=='Printer' or part.Name=='PackStation' or part.Name=='PrestigeStation' then nativeFinish(part,Enum.Material.Metal)
  else part.Reflectance=0 end
 end end
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then nativeFinish(baseplate,Enum.Material.Grass);baseplate.Color=Color3.fromRGB(86,142,74) end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 if spawn then nativeFinish(spawn,Enum.Material.Plastic,true) end
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then
  nativeFinish(converter,Enum.Material.DiamondPlate)
  for _,prompt in ipairs(converter:GetDescendants()) do if prompt:IsA('ProximityPrompt') then prompt.ActionText='Sell ore' end end
 end
 local converterName=map:FindFirstChild('ConverterName',true)
 if converterName then for _,text in ipairs(converterName:GetDescendants()) do if text:IsA('TextLabel') and (text.Text=='SELL YOUR CARGO' or text.Text=='DEPOSIT FOR LAUNCH') then text.Text='SELL ORE' end end end
 local lane=map:FindFirstChild('FieldTestLane',true)
 local finishes={Enum.Material.Sandstone,Enum.Material.Ground,Enum.Material.Slate,Enum.Material.Rock,Enum.Material.Grass}
 local beds={Color3.fromRGB(192,170,113),Color3.fromRGB(173,111,86),Color3.fromRGB(100,143,165),Color3.fromRGB(146,117,167),Color3.fromRGB(104,154,101)}
 for id,cfg in ipairs(Config.Fields) do
  local model=fields:FindFirstChild(cfg.Key);local part=model:FindFirstChild('Field')
  nativeFinish(part,finishes[id] or Enum.Material.Slate);part.Color=beds[id] or beds[1]
  local border=model:FindFirstChild('Border')
  if border and border:IsA('BasePart') then nativeFinish(border,Enum.Material.Plastic,true);border.Color=(beds[id] or beds[1]):Lerp(Color3.fromRGB(50,70,53),.5) end
  if lane and lane:IsA('BasePart') and not model:FindFirstChild('DepotApproach') then
   local nearEdge=part.Position.Z-part.Size.Z/2
   local laneEdge=lane.Position.Z+lane.Size.Z/2
   if nearEdge>laneEdge then
    local length=nearEdge-laneEdge+1
    local link=W.part(model,'DepotApproach',Vector3.new(part.Position.X,lane.Position.Y,laneEdge+length/2),Vector3.new(12,lane.Size.Y,length),lane.Color,Enum.Material.Pavement)
    link:SetAttribute('GeneratedDepotApproach',true);nativeFinish(link,Enum.Material.Pavement);solid(link)
   end
  end
 end
end
-- Dress the actual editable map, after the starter plot has reached its final
-- position. The old landscape planner belongs to the historical capture and
-- must not be used to cover this native map with a second world.
function W.landscapeEditable(scene)
 if scene.root:GetAttribute('DronerevolutionMapVersion') then return end
 if not scene.root:GetAttribute('EditableMap') then return end
 local previous=scene.map:FindFirstChild('QuarryLandscape')
 if previous and previous:GetAttribute('LandscapeVersion')==1 then return end
 if previous then previous:Destroy() end
 local landscape=Instance.new('Folder');landscape.Name='QuarryLandscape';landscape:SetAttribute('LandscapeVersion',1)
 local base=workspace:FindFirstChild('Baseplate')
 local floor=base and base.Position.Y+base.Size.Y/2 or 0
 local grass=Color3.fromRGB(102,155,77)
 local earth=Color3.fromRGB(120,99,70)
 local chalk=Color3.fromRGB(184,170,131)
 local foliage={Color3.fromRGB(84,143,67),Color3.fromRGB(159,124,63),Color3.fromRGB(71,133,126),Color3.fromRGB(113,115,160),Color3.fromRGB(62,133,89)}
 local keepClear={}
 for _,field in ipairs(scene.fields) do table.insert(keepClear,{part=field.part,padding=5}) end
 -- Treat every existing floor, building and lane as occupied. Decorations
 -- never cover a shop, mining footprint, display station or authored route.
 for _,part in ipairs(scene.map:GetDescendants()) do
  if part:IsA('BasePart') and part.Transparency<1 then table.insert(keepClear,{part=part,padding=3}) end
 end
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then table.insert(keepClear,{part=converter,padding=6}) end
 local function clear(x,z,w,d)
  -- The home effects previews are client-only and appear after this server
  -- pass. Reserve their two-column apron before any trees are planted.
  if math.abs(x-(scene.home.X+61))<w/2+25 and math.abs(z-(scene.home.Z-2))<d/2+35 then return false end
  if base and (math.abs(x-base.Position.X)+w/2>base.Size.X/2-5 or math.abs(z-base.Position.Z)+d/2>base.Size.Z/2-5) then return false end
  for _,entry in ipairs(keepClear) do
   local part=entry.part;local localPoint=part.CFrame:PointToObjectSpace(Vector3.new(x,part.Position.Y,z))
   -- Project the candidate's two diagonal corners into the original part's
   -- frame. This also conservatively clears any rotated authored footprint.
   local a=part.CFrame:PointToObjectSpace(Vector3.new(x+w/2,part.Position.Y,z+d/2))-localPoint
   local b=part.CFrame:PointToObjectSpace(Vector3.new(x-w/2,part.Position.Y,z+d/2))-localPoint
   local ex,ez=math.max(math.abs(a.X),math.abs(b.X)),math.max(math.abs(a.Z),math.abs(b.Z))
   if math.abs(localPoint.X)<part.Size.X/2+ex+entry.padding and math.abs(localPoint.Z)<part.Size.Z/2+ez+entry.padding then return false end
  end
  return true
 end
 local function piece(parent,name,x,z,w,h,d,tint,material,top,collide)
  local p=W.part(parent,name,Vector3.new(x,top-h/2,z),Vector3.new(w,h,d),tint,material)
  p.CanCollide=collide==true;p.CanQuery=collide==true;p.CastShadow=h>.4
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  return p
 end
 local function terrace(parent,x,z,w,d,h,tint)
  if not clear(x,z,w,d) then return false end
  piece(parent,'EarthBank',x,z,w,h,d,earth,Enum.Material.Ground,floor+h,true)
  piece(parent,'GrassShelf',x,z,w+.08,.22,d+.08,tint,Enum.Material.Grass,floor+h+.12,true)
  piece(parent,'ExposedStratum',x,z-d/2-.06,w-.8,.65,.16,chalk,Enum.Material.Sandstone,floor+h*.56,false)
  return true
 end
 for index,field in ipairs(scene.fields) do
  if field.cfg.TestField then continue end
  local p=field.part;local biome=Instance.new('Folder');biome.Name=field.cfg.Key..'Landscape'
  local x,z=p.Position.X,p.Position.Z;local halfX,halfZ=p.Size.X/2,p.Size.Z/2
  local tint=foliage[index] or grass
  -- Stacked rectangular cuts show local geology instead of an empty grey
  -- plane. Their fronts remain outside the rock and player travel footprint.
  local ridgeX,ridgeZ=x,z+halfZ+29
  local width,depth=p.Size.X+7,22
  if index==1 then ridgeX=x-halfX-27;ridgeZ=z;width=20;depth=p.Size.Z-16 end
  if terrace(biome,ridgeX,ridgeZ,width,depth,3.4,tint:Lerp(grass,.55)) then
   local upperX=ridgeX+(index==1 and -3 or 3);local upperZ=ridgeZ+3
   terrace(biome,upperX,upperZ,width-7,depth-7,7+index*.65,tint:Lerp(grass,.4))
   tree(biome,upperX-width*.2,upperZ,14+index,tint,floor+7+index*.65,.3*index)
   tree(biome,upperX+width*.23,upperZ+2,11+index,tint:Lerp(grass,.25),floor+7+index*.65,1.2+index)
  end
  -- A low grassy shoulder and two hand-placed trees form a compact grove.
  -- A failed clearance candidate is simply omitted, never pushed into a lane.
  for side=-1,1,2 do
   local tx,tz=x+side*(halfX+19),z+halfZ-8
   if clear(tx,tz,15,15) then
    piece(biome,'GroveSoil',tx,tz,15,.3,15,grass:Lerp(tint,.18),Enum.Material.Grass,floor+.24,false)
    tree(biome,tx,tz,12+index*.7,tint,floor,.5+index*side)
    for bush=1,3 do
     piece(biome,'LowBrush',tx+side*(3+bush),tz-5+bush*.7,3.2,1.2+bush*.25,2.7,tint:Lerp(grass,.25),Enum.Material.SmoothPlastic,floor+1.2+bush*.25,false)
    end
   end
  end
  -- Cobalt gets a shallow settling pond on its far outside shoulder; it is
  -- cosmetic, with a grounded stone lip and no deep-water movement trap.
  if field.cfg.Key=='Cobalt' then
   local px,pz=x+halfX+23,z+halfZ+9
   if clear(px,pz,20,16) then
    piece(biome,'SettlingPondBank',px,pz,20,.6,16,chalk,Enum.Material.Slate,floor+.55,true)
    piece(biome,'SettlingPondWater',px,pz,17,.12,13,Color3.fromRGB(59,157,176),Enum.Material.SmoothPlastic,floor+.62,false)
    for n=1,3 do piece(biome,'PondReed',px+6+n*.5,pz-4, .3,1+n*.4,.3,foliage[5],Enum.Material.SmoothPlastic,floor+1+n*.4,false) end
   end
  end
  biome.Parent=landscape
 end
 -- Backdrop behind the depot, leaving its machines and forward sightline open.
 for _,side in ipairs({-1,1}) do
  local x,z=scene.home.X+side*70,scene.home.Z-25
  if terrace(landscape,x,z,24,28,2.2,grass) then
   tree(landscape,x-side*4,z,17,foliage[1],floor+2.2,side*.6)
   tree(landscape,x+side*6,z+5,12,foliage[1]:Lerp(chalk,.12),floor+2.2,side*1.1)
  end
 end
 landscape.Parent=scene.map
 scene.root:SetAttribute('LandscapeDirection','Sunlit parts-built mineral quarry')
 scene.root:SetAttribute('LandscapePartCount',#landscape:GetDescendants())
end
local function restoreMiningFX()
 local rs=game:GetService('ReplicatedStorage')
 if rs:FindFirstChild('MiningFX') then return end
 -- The flat-map capture archived the original particles and contact glows.
 -- Replicate a disposable visual template; leave every preserved backup intact.
 for _,archive in ipairs(game:GetService('ServerStorage'):GetChildren()) do
  local original=archive:FindFirstChild('MiningFX')
  if original then
   local copy=original:Clone()
   for _,object in ipairs(copy:GetDescendants()) do
    if object:IsA('LuaSourceContainer') then object:Destroy()
    elseif object:IsA('ParticleEmitter') or object:IsA('Beam') then object.Enabled=false
    elseif object:IsA('BasePart') then object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false end
   end
   copy.Parent=rs;return
  end
 end
end
-- Keep the first field on the depot's center approach and respawn beside it.
-- Run before resources/turrets spawn; move the original model as one assembly.
function W.placeStart(scene)
 if scene.root:GetAttribute('DronerevolutionMapVersion') then
  local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
  scene.spawnPosition=spawn and spawn.Position or scene.home
  scene.root:SetAttribute('StarterField','Quartz')
  scene.root:SetAttribute('StarterSpawn',scene.spawnPosition)
  return
 end
 local home=scene.home;local pad=scene.map:FindFirstChild('HubPad',true)
 scene.root:SetAttribute('DepotHome',home)
 local quartz
 for _,field in ipairs(scene.fields) do if field.cfg.Key=='Quartz' then quartz=field;break end end
 if not quartz then return end
 local half=pad and pad.Size.Z/2 or 32
 local center=Vector3.new(home.X,quartz.part.Position.Y,home.Z+half+6+quartz.part.Size.Z/2)
 local target=CFrame.new(center)*quartz.part.CFrame.Rotation
 quartz.model:PivotTo(target*quartz.part.CFrame:Inverse()*quartz.model:GetPivot());quartz.center=quartz.part.Position
 local approach=quartz.model:FindFirstChild('DepotApproach')
 if approach and approach:GetAttribute('GeneratedDepotApproach') then approach:Destroy() end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local surface=pad and pad.Position.Y+pad.Size.Y/2 or home.Y
 local nearEdge=quartz.center.Z-quartz.part.Size.Z/2
 if pad then
  local edge=pad.Position.Z+pad.Size.Z/2
  if nearEdge>edge then
   local bridge=scene.map:FindFirstChild('QuartzApproach') or W.part(scene.map,'QuartzApproach',Vector3.zero,Vector3.one,pad.Color,Enum.Material.Pavement)
   bridge.Size=Vector3.new(12,pad.Size.Y,nearEdge-edge+1);bridge.CFrame=CFrame.new(home.X,pad.Position.Y,(nearEdge+edge)/2)
   bridge.CanCollide=true;bridge.CanQuery=true
  end
 end
 scene.spawnPosition=Vector3.new(home.X,surface+(spawn and spawn.Size.Y/2 or .5),nearEdge-10)
 if spawn then spawn.CFrame=CFrame.lookAt(scene.spawnPosition,Vector3.new(quartz.center.X,scene.spawnPosition.Y,quartz.center.Z)) end
 W.ensureImpactField(scene.root,scene.root:FindFirstChild('Fields'))
 for _,field in ipairs(scene.fields) do if field.cfg.TestField then field.center=field.part.Position end end
 scene.root:SetAttribute('StarterField','Quartz');scene.root:SetAttribute('StarterSpawn',scene.spawnPosition)
 W.landscapeEditable(scene)
end
function W.initialize(): any
 restoreMiningFX()
 Daylight.apply()
 -- The reference layout can clone its old dawn setter during startup.
 -- Reapply its fallback after those scripts run; the authored quarry is native.
 task.defer(Daylight.apply)
 local existing=workspace:FindFirstChild('MiningAway')
 if existing and existing:GetAttribute('EditableMap') then
  local map=existing:FindFirstChild('Map')
  local fields=existing:FindFirstChild('Fields')
  local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
  local hub=map and map:FindFirstChild('HubPad',true)
  local home=existing:GetAttribute('DepotHome') or (hub and hub.Position) or (spawn and spawn.Position) or Vector3.new(-56,.5,-11)
  assert(map and fields,'Editable map is missing required folders')
  finishEditableMap(existing,map,fields,home)
  local fieldMetadata={}
  for id,cfg in ipairs(Config.Fields) do
   local model=fields:FindFirstChild(cfg.Key)
   local part=model and model:FindFirstChild('Field')
   assert(model and part and part:IsA('BasePart'),'Editable map is missing field '..cfg.Key)
   table.insert(fieldMetadata,{id=id,cfg=cfg,center=part.Position,part=part,model=model})
  end
  return {
   root=existing,map=map,home=home,
   printer=map:FindFirstChild('Printer',true),
   packStation=map:FindFirstChild('PackStation',true),
   prestigeStation=map:FindFirstChild('PrestigeStation',true),
   converter=workspace:FindFirstChild('Converter'),
   fields=fieldMetadata,
   turretTemplate=game:GetService('ServerStorage'):FindFirstChild('OriginalConstructTemplate'),
   droneTemplate=workspace:FindFirstChild('Drone'),
   crystalTemplate=workspace:FindFirstChild('Crystal')
  }
 end
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
 construct.PrimaryPart=construct:FindFirstChild('basepart');construct:PivotTo(CFrame.new(constructX,plan:surface(constructX,constructZ)+.5,constructZ))
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then cleanSurface(baseplate,archive);baseplate.Color=P.ground;baseplate.Material=Enum.Material.SmoothPlastic end
 if spawn then cleanSurface(spawn,archive);spawn.Color=P.ledge;spawn.Material=Enum.Material.Metal end
 -- Retain the author's simple parts-built trees, now under the same restrained palette.
 for _,model in ipairs(workspace:GetChildren()) do
  if model:IsA('Model') and model.Name=='Model' then
   -- Original trees were perched on the old abandoned test stairs. Keep the
   -- same two-part geometry, scale and ground it as a distant southern grove.
   local parts={};local low,high=math.huge,-math.huge;local anchor=nil
   for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then
    table.insert(parts,v);anchor=anchor or v.Position
    low=math.min(low,v.Position.Y-v.Size.Y/2);high=math.max(high,v.Position.Y+v.Size.Y/2)
   end end
   local scale=math.min(1,18/math.max(1,high-low))
   if anchor then for _,v in ipairs(parts) do
    local p=v.Position;v.Size=v.Size*scale
    v.CFrame=CFrame.new(anchor.X+(p.X-anchor.X)*scale,(p.Y-low)*scale,anchor.Z+(p.Z-anchor.Z)*scale)*v.CFrame.Rotation
   end end
   for _,v in ipairs(model:GetDescendants()) do
    if v:IsA('BasePart') then cleanSurface(v,archive);v.Material=Enum.Material.SmoothPlastic;v.Color=v.Size.Y>v.Size.X*1.7 and Color3.fromRGB(50,88,91) or Color3.fromRGB(107,182,159) end
   end
  end
 end
 HarborLighting.apply()
 Daylight.apply()
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
 local header=block(map,'DepotHeader',Vector3.new(home.X,10.7,home.Z-13.65),Vector3.new(12,1.9,.18),P.ink)
 textFace(header,'MINING AWAY','EXTRACTION DEPOT  /  01',P.ivory)
 local printer=station(map,'Printer',home+Vector3.new(12,-.5,-2),P.mint,'Free reprint','Printer')
 local packs=station(map,'PackStation',home+Vector3.new(-12,-.5,-2),P.blue,'Open pack','Pack')
 local prestige=station(map,'PrestigeStation',home+Vector3.new(0,-.5,-12),P.amber,'Review prestige','Prestige')
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then
  cleanSurface(converter,archive);converter.Color=P.metal;converter.Material=Enum.Material.Metal;converter:SetAttribute('Interaction','Sell')
  for _,v in ipairs(converter:GetChildren()) do if v:IsA('ProximityPrompt') then v:Destroy() end end
  local prompt=Instance.new('ProximityPrompt');prompt.ActionText='Sell ore';prompt.ObjectText='CONVERTER';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=converter
  local p=converter.Position;local half=converter.Size/2
  block(map,'ConverterCollar',Vector3.new(p.X,p.Y+half.Y-.3,p.Z),Vector3.new(converter.Size.X+1,.6,converter.Size.Z+1),P.edge,Enum.Material.Metal)
  for _,dx in ipairs({-.34,.34}) do
   block(map,'ConverterRib',Vector3.new(p.X+converter.Size.X*dx,p.Y,p.Z-half.Z-.15),Vector3.new(.45,converter.Size.Y*.85,.35),P.edge,Enum.Material.Metal)
  end
  block(map,'ConverterIntake',Vector3.new(p.X,p.Y,p.Z-half.Z-.3),Vector3.new(converter.Size.X*.5,converter.Size.Y*.42,.28),P.ink)
  block(map,'ConverterLight',Vector3.new(p.X,p.Y+half.Y*.42,p.Z-half.Z-.48),Vector3.new(converter.Size.X*.4,.18,.08),P.mint,Enum.Material.Neon)
  local name=block(map,'ConverterName',Vector3.new(p.X,p.Y+half.Y+1,p.Z-half.Z-.2),Vector3.new(7,1.6,.22),P.ink);textFace(name,'CONVERTER','SELL ORE',P.mint)
  block(map,'OreChute',Vector3.new(p.X,p.Y-half.Y+.6,p.Z-half.Z-2),Vector3.new(converter.Size.X*.7,1.2,3.5),P.ledge,Enum.Material.Metal)
 end
 local fields={};local originals=workspace:FindFirstChild('Patches')
 for id,field in ipairs(cfg.Fields) do
  local model=Instance.new('Model');model.Name=field.Key;model:SetAttribute('AlwaysUnlocked',field.AlwaysUnlocked==true);model:SetAttribute('Mineral',field.Material or field.Key);model:SetAttribute('FieldId',id);model:SetAttribute('Tier',id);model:SetAttribute('DisplayName',field.Name);model.Parent=root.Fields
  local part=originals and field.Original and originals:FindFirstChild(field.Original)
  if part and part:IsA('BasePart') then part.Parent=model
  else local o=field.Offset;part=block(model,'Field',home+Vector3.new(o[1],o[2],o[3]),Vector3.new(unpack(field.Size)),P.ground,Enum.Material.Ground) end
  -- Reposition the original patch objects with the rest of the compact valley.
  part.CFrame=CFrame.new(home+Vector3.new(unpack(field.Offset)));part.Size=Vector3.new(unpack(field.Size))
  cleanSurface(part,archive)
  local accent=Color3.fromRGB(unpack(field.Color))
  local beds={Color3.fromRGB(130,190,139),Color3.fromRGB(159,102,91),Color3.fromRGB(88,146,179),Color3.fromRGB(142,117,178),Color3.fromRGB(63,156,114)}
  part.Name='Field';part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.Color=beds[id] or beds[1];part.Material=Enum.Material.SmoothPlastic;part:SetAttribute('FieldId',id);part:SetAttribute('Patch',id)
  local top=part.Position.Y+part.Size.Y/2;local bottom=part.Position.Y-part.Size.Y/2
  -- The original raised Ruby patch is now visibly supported by a low layered mesa.
  if bottom>.4 then
   solid(block(model,'FieldBedrock',Vector3.new(part.Position.X,bottom/2,part.Position.Z),Vector3.new(part.Size.X+4,bottom,part.Size.Z+4),P.stone,Enum.Material.SmoothPlastic))
   solid(block(model,'FieldSkirt',Vector3.new(part.Position.X,bottom*.23,part.Position.Z),Vector3.new(part.Size.X+10,math.max(.4,bottom*.46),part.Size.Z+8),P.ledge,Enum.Material.SmoothPlastic))
   block(model,'ChalkCrown',Vector3.new(part.Position.X,bottom-.45,part.Position.Z),Vector3.new(part.Size.X+5,.65,part.Size.Z+5),P.ivory,Enum.Material.SmoothPlastic)
  end
  -- Signs stand on each actual field top, beside its incoming route.
  local shoulders={{-20,-11},{-20,-8},{-20,10},{-21,-8},{21,-8}}
  local shoulder=shoulders[id] or {0,-20};local edge=Vector3.new(part.Position.X+shoulder[1]*MapLayout.FieldScale,top,part.Position.Z+shoulder[2]*MapLayout.FieldScale)
  local subtitle=id==1 and 'SAFE  /  START HERE' or field.Turrets>0 and (id==3 and 'GUARDED  /  COMBAT CARDS' or 'GUARDED  /  '..field.RecommendedFleet..'+ DRONES') or 'SAFE  /  RICHER ORE'
  local facing=id>3 and fields[id-1].center or home
  solid(block(model,'SignTerrace',edge-Vector3.new(0,top/2,0),Vector3.new(9,math.max(.2,top),5),P.stone))
  sign(model,edge,string.format('%02d  %s',id,field.Name:upper()),subtitle,accent,facing)
  -- Short corner caps read as a footprint and leave every field side walkable.
  for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local corner=part.Position+Vector3.new(x*(part.Size.X/2+.3),top-part.Position.Y+.15,z*(part.Size.Z/2+.3))
   block(model,'FieldCorner',corner-Vector3.new(x*2.2,0,0),Vector3.new(4.4,.25,.42),P.ivory,Enum.Material.SmoothPlastic)
   block(model,'FieldCorner',corner-Vector3.new(0,0,z*2.2),Vector3.new(.42,.25,4.4),P.ivory,Enum.Material.SmoothPlastic)
   local beacon=block(model,'SurveyPin',corner+Vector3.new(0,.75,0),Vector3.new(.3,1.5,.3),P.metal,Enum.Material.Metal)
   block(model,'PinLight',beacon.Position+Vector3.new(0,.76,0),Vector3.new(.32,.16,.32),accent,Enum.Material.Neon)
  end end
  table.insert(fields,{id=id,cfg=field,center=part.Position,part=part,model=model})
 end
 -- The valley is one continuous stepped landform. Route and field cuts are
 -- calculated in the pure plan before geometry is emitted, leaving real corridors.
 local foliage={Color3.fromRGB(81,174,104),Color3.fromRGB(173,57,49),Color3.fromRGB(64,150,185),Color3.fromRGB(157,103,192),Color3.fromRGB(36,157,110)}
 local soils={Color3.fromRGB(112,171,112),Color3.fromRGB(158,104,83),Color3.fromRGB(103,165,174),Color3.fromRGB(148,129,173),Color3.fromRGB(64,147,107)}
 local terrain=Instance.new('Model');terrain.Name='ConnectedCliffs';terrain.Parent=map
 local batch=Instance.new('Model');batch.Name='SlopePatch';local facetCells=0
 for _,cell in ipairs(plan.terrain) do
  for _,face in ipairs(cell.faces) do
   local a,b,c=Vector3.new(face[1][1],face[1][2],face[1][3]),Vector3.new(face[2][1],face[2][2],face[2][3]),Vector3.new(face[3][1],face[3][2],face[3][3])
   local normal=(b-a):Cross(c-a).Unit
   local steep=math.abs(normal.Y)<.72
   local color=steep and (cell.biome==2 and Color3.fromRGB(111,76,70) or P.stone) or (soils[cell.biome] or soils[1])
   Facets.triangle(batch,a,b,c,color)
  end
  facetCells+=1
  if facetCells%40==0 then batch.Parent=terrain;task.wait();batch=Instance.new('Model');batch.Name='SlopePatch' end
 end
 batch.Parent=terrain
 for _,r in ipairs(plan.rocks) do
  local m=Instance.new('Model');m.Name='FracturedCliff';m.Parent=terrain
  local tint=r.biome==2 and Color3.fromRGB(112,76,70) or P.stone
  stone(m,Vector3.new(r.x,r.y+r.h*.32,r.z),Vector3.new(r.w,r.h*.8,r.d),{-5,r.yaw,4},tint,'CliffButtress')
  stone(m,Vector3.new(r.x-2,r.y+r.h*.75,r.z+1),Vector3.new(r.w*.72,r.h*.35,r.d*.8),{4,r.yaw+17,-8},tint:Lerp(P.ledge,.18),'BrokenCrown')
 end
 -- Built-in terrain decoration owns grass rendering and wind. No per-blade
 -- replication, client cloning, octrees or per-frame foliage work remains.
 NativeMeadow.build(plan,root)
 root:SetAttribute('TerrainStyle','Irregular slopes and fractured cliffs')
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
    local top=at.Y-math.abs(b.Y-a.Y)/(count*2)-.18
    if top>.3 then
     local fill=solid(block(lane,'TrailEarth',Vector3.new(at.X,top/2,at.Z),Vector3.new(r.width-.3,top,flat.Magnitude/count+.08),P.stone))
     fill.CFrame=CFrame.lookAt(fill.Position,fill.Position+flat)
    end
   end
  end

 end
 local forest=Instance.new('Model');forest.Name='BiomeGroves';forest.Parent=map
 for _,t in ipairs(plan.trees) do
  local m=tree(forest,t.x,t.z,t.h,foliage[t.biome],t.ground,t.yaw)
  m.Name=t.biome==2 and 'AuburnTree' or 'MineralTree';m:SetAttribute('Biome',t.biome)
 end
 -- Small parts-built landmarks and dense undergrowth reward the bends. All
 -- dressing is outside the resource clearings; it never substitutes for an ore node.
 local props=Instance.new('Model');props.Name='ValleyDetails';props.Parent=map
 local siteX,siteZ,targetX,targetZ
 local function site(x,z,biome)
  siteX,siteZ=x,z
  if biome then targetX,targetZ=plan:biomePoint(biome,x,z) else targetX,targetZ=plan:point(x,z) end
 end
 local function at(x,y,z) return Vector3.new(targetX+x-siteX,y+plan.dy,targetZ+z-siteZ) end
 local function groundAt(x,z) local p=at(x,0,z);return plan:surface(p.X,p.Z) end
 local function prop(name,x,y,z,sx,sy,sz,color,turn,collide)
  local p=block(props,name,at(x,y,z),Vector3.new(sx,sy,sz),color,Enum.Material.SmoothPlastic,turn and {0,math.rad(turn),0})
  if collide then solid(p) end
  return p
 end
 -- Ruby mine: actual walk-in recess at the foot of a rising cliff. The
 -- playable crystal field remains in front, with no roof over its drone stations.
 site(-88,66,2)
 for _,x in ipairs({-99,-77}) do
  prop('RubyPortalRock',x,22,66,7,18,9,Color3.fromRGB(112,70,66),x==-99 and -8 or 8,true)
  prop('MineTimber',x==-99 and -95 or -81,19,62.5,1.1,12,1.3,Color3.fromRGB(92,65,52),0,true)
 end
 prop('RubyLintel',-88,30,67,27,6,11,Color3.fromRGB(158,98,85),0,true)
 prop('MineCrossbeam',-88,25,62.5,15,1.4,1.5,Color3.fromRGB(111,75,51),0,true)
 prop('MineShadow',-88,20.5,70.8,14,14.5,.2,Color3.fromRGB(34,35,43))
 prop('MineFloor',-88,12.7,66,15,.6,11,P.stone,0,true)
 for _,x in ipairs({-92.5,-83.5}) do
  local lamp=prop('AmberMineLamp',x,22.5,61.6,.8,1,.7,P.amber);light(lamp,P.amber,13,.6)
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
 for _,z in ipairs({72,82}) do
  prop('LookoutRail',-65,36,z,13,.35,.35,P.metal)
  for _,x in ipairs({-71,-65,-59}) do prop('LookoutPost',x,35,z,.35,2.5,.35,P.metal) end
 end
 sign(props,at(-65,34,81),'RUBY LOOKOUT','GROVE BELOW',P.coral,at(-87,13,46))
 -- A narrow aqueduct/waterfall gives the upper pass an unmistakable silhouette.
 site(-12,-101)
 local aqueductY=math.max(groundAt(-20,-101),groundAt(-4,-101))+12
 for _,x in ipairs({-20,-4}) do prop('AqueductPier',x,aqueductY-6,-101,3.5,12,5,P.ledge,0,true) end
 prop('AqueductLintel',-12,aqueductY,-101,21,2.5,6,P.ivory,0,true)
 prop('WaterChannel',-12,aqueductY+1.3,-101,19,.2,2.5,Color3.fromRGB(82,193,216))
 prop('WaterSpout',-21,aqueductY+.8,-97.5,2,1,10,P.ledge)
 prop('SpoutWater',-21,aqueductY+1.35,-97.5,1.2,.15,10,Color3.fromRGB(82,193,216))
 local poolGround=groundAt(-21,-94)
 local fallTop=aqueductY+1.3;local fallHeight=fallTop-poolGround
 local fall=prop('MineralWaterfall',-21,poolGround+fallHeight/2,-94,1.1,fallHeight,3.2,Color3.fromRGB(81,190,208));fall.Transparency=.25
 prop('PoolBank',-21,poolGround+.11,-94,11,.2,12,P.ledge)
 prop('PoolWater',-21,poolGround+.24,-94,9,.12,10,Color3.fromRGB(54,154,181))
 -- Emerald's preserved segmented construct crowns the ridge as a dormant landmark.
 site(62,9)
 local constructGround=groundAt(62,9)
 prop('ConstructPlinth',62,constructGround-.5,9,13,1,13,P.ledge,0,true)
 prop('ConstructBedrock',62,constructGround/2,9,13,constructGround,13,P.stone,0,true)
 -- Leaf/flower clusters, fungi, fallen trunks and survey equipment occupy the
 -- negative space around trees. Deterministic placement keeps repeat builds equal.
 for i,t in ipairs(plan.trees) do
  for n=1,4 do
   local angle=i*2.1+n*1.7;local x=t.x+math.cos(angle)*(3+n);local z=t.z+math.sin(angle)*(3+n)
   if plan:routeClear(x,z,1.8) and plan:fieldClear(x,z,2) then
    local ground=plan:surface(x,z);local color=foliage[t.biome]
    block(props,'Undergrowth',Vector3.new(x,ground+.65,z),Vector3.new(2.2,1.3,1.8),color:Lerp(P.ground,.4),Enum.Material.SmoothPlastic,{0,angle,.15})
    local stem=block(props,'FlowerStem',Vector3.new(x+.8,ground+1.3,z+.3),Vector3.new(.18,1.5,.18),P.metal)
    local blossom=block(props,n%2==0 and 'MineralBloom' or 'ShelfFungus',stem.Position+Vector3.new(0,.8,0),Vector3.new(n%2==0 and .8 or 1.8,.3,n%2==0 and .8 or 1.8),n%2==0 and P.ivory or color:Lerp(P.amber,.35))
    if n%2==1 then blossom.CFrame=blossom.CFrame*CFrame.Angles(0,angle,0) end
   end
  end
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
  local x,z,h=m[1],m[2],m[3];site(x,z);local y=groundAt(x,z)
  prop('FungusStalk',x,y+h/2,z,1,h,1,P.ledge)
  prop('FungusCap',x,y+h,z,h*.9,1.3,h*.75,P.amber,-8)
  prop('FungusCrown',x-.5,y+h+.9,z,h*.55,.6,h*.5,P.ivory,4)
 end
 site(-24,-50)
 surveyGate(map,at(-24,10,-50),P.blue)
 root:SetAttribute('TreeCount',#plan.trees);root:SetAttribute('RouteCount',#plan.routes);root:SetAttribute('MapScale',MapLayout.Scale);root:SetAttribute('OpenHubRadius',46)
 root:SetAttribute('SourceSceneIntegrated',true);root:SetAttribute('FieldCount',#fields);root:SetAttribute('ArtDirection','Alabaster Valley / Open Meadows / Outer Groves')
 return {root=root,map=map,home=home,printer=printer,packStation=packs,prestigeStation=prestige,converter=converter,fields=fields,turretTemplate=turretTemplate,droneTemplate=rs:FindFirstChild('Drone'),crystalTemplate=rs:FindFirstChild('Crystal')}
end
return W

