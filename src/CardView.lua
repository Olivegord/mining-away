-- Presentation only. Two text elements per card: effect and target/terms.
-- The complete saved server choice remains the selection contract.
local CardView={HEIGHT=320,MIN_HEIGHT=212}

local function percent(value) return string.format('%g%%',math.floor(value*100+.5)) end
local function amount(value,label) return '+'..percent(value)..' '..label end
local function reach(choice,key,fallback)
 for _,row in ipairs(choice.preview or {}) do if type(row)=='table' and row.label==key and type(row.after)=='number' then return row.after end end
 return fallback
end

function CardView.summary(choice)
 local e=choice.effects or {};local lines={}
 local function add(key,text) if type(e[key])=='number' and e[key]>0 then table.insert(lines,text) end end
 add('doubleBeam','Two lasers.\n2× damage to one crystal.')
 add('twinThrusters','Two thrusters.\n2× top flight speed.')
 add('oreDuplicator','Gold ore chamber.\n2× ore from this miner.')
 add('compactor','Presses 3 loose ore into 1 of the next tier.')
 add('batchPress','Your Compactor now needs 2 ore per press.')
 add('liveWire',amount(e.liveWire or 0,'laser damage above half battery'))
 add('shiftRelay','Emptier sales boost pin damage by 50% for '..(e.shiftRelay or 0)..'s.')
 add('orbitalLaser','Call an orbital strike on the biggest rock')
 add('scrapSwarm','Deploy tiny miners for 10 seconds')
 add('plotAuto','Drones choose stones for you')
 add('fullAuto',amount(e.fullAuto or 0,'courier speed'))
 add('mining',amount(e.mining or 0,'mining power'))
 add('combat',amount(e.combat or 0,'attack damage'))
 add('rate',amount(e.rate or 0,'attack speed'))
 add('health',amount(e.health or 0,'drone health'))
 add('reduction','Block '..percent(e.reduction or 0)..' damage')
 add('capacity',amount(e.capacity or 0,'backpack space'))
 add('speed',amount(e.speed or 0,'drone speed'))
 add('startup',amount(e.startup or 0,'laser startup speed'))
 add('yield',amount(e.yield or 0,'ore per crystal'))
 add('range',amount(e.range or 0,'attack range'))
 add('crit',percent(e.crit or 0)..' chance to hit twice')
 add('fork','Hit a nearby crystal for '..percent(e.fork or 0)..' damage')
 add('deepCut',amount(e.deepCut or 0,'damage in Ruby through Emerald'))
 add('aftershock','Each laser crack or break sends a shock into one nearby crystal.')
 add('reclaim','Recover '..(e.reclaim or 0)..' battery when you break a crystal')
 add('earlyDrop','Cracks drop more ore that flies farther to you')
 add('fieldCharge','Depleted drones recharge at your pin')
 add('magnetRange','Pull ore from '..(e.magnetRange or 0)..' studs farther away')
 add('battery','+'..(e.battery or 0)..' battery capacity')
 add('splash','Hit a nearby sentry for '..percent(e.splash or 0)..' damage')
 add('shield','Start fights with '..percent(e.shield or 0)..' shield')
 add('finisher',amount(e.finisher or 0,'damage to weak sentries'))
 add('geode',amount(e.geode or 0,'geode damage'))
 add('salvage','Kills repair '..percent(e.salvage or 0)..' health')
 return #lines>0 and table.concat(lines,'\n') or (choice.description or choice.title or 'Run upgrade')
end

function CardView.terms(choice,_targetOverride,hasBadge)
 local e=choice.effects or {};local target
 local work=(e.mining or 0)>0 or (e.startup or 0)>0 or (e.yield or 0)>0 or (e.fork or 0)>0 or (e.geode or 0)>0 or (e.plotAuto or 0)>0
 local allRoles=(e.speed or 0)>0 or (e.health or 0)>0 or (e.reduction or 0)>0 or (e.shield or 0)>0
 if (e.orbitalLaser or 0)>0 then target='Your orbital laser'
 elseif (e.scrapSwarm or 0)>0 then target='Your scrap bots'
 elseif e.fullAuto and e.fullAuto>0 and choice.scope=='Player' then target='Your couriers'
 elseif choice.scope=='Individual' then target=choice.targetName or 'One drone'
 elseif choice.scope=='Color' then target=(choice.type or '')..(work and not allRoles and ' mining drones' or ' drones')
 elseif (e.fieldCharge or 0)>0 then target='Your mining pin'
 elseif e.compactor then target='New drone at your pin'
 elseif e.batchPress then target='Your Compactor'
 elseif e.shiftRelay then target='Your mining pin'
 elseif choice.scope=='Player' then target='Your backpack'
 elseif (e.aftershock or 0)>0 or (e.deepCut or 0)>0 or (e.fork or 0)>0 or e.liveWire then target='Laser miners'
 elseif e.capacity and e.capacity>0 then target='Drones + backpack'
 elseif work and not allRoles or (e.reclaim or 0)>0 or (e.earlyDrop or 0)>0 then target='Mining drones'
 else target='All drones' end
 if choice.workshop then
  if e.doubleBeam or e.twinThrusters or e.oreDuplicator then
   return (choice.targetName or 'Fit to one miner')..' · This run'
  end
  local before=choice.stackBefore
  local count=before and (before>0 and (before..'× → '..(before+choice.level)..'×') or ('NEW · '..choice.level..'×')) or (choice.level..'×')
  return target..' · This run\n'..count..(hasBadge and '' or ' · '..(choice.rarity or 'Common'))
 end
 local details={target..' · This run'}
 local losses={}
 for _,entry in ipairs({{'speed','drone speed'},{'mining','mining speed'},{'combat','attack damage'},{'health','drone health'},{'startup','startup speed'},{'yield','ore yield'},{'capacity','backpack space'}}) do
  local n=e[entry[1]];if type(n)=='number' and n<0 then table.insert(losses,'−'..percent(-n)..' '..entry[2]) end
 end
 if #losses>0 then table.insert(details,table.concat(losses,', ')) end
 if (e.finisher or 0)>0 then table.insert(details,'Weak = below 35% health') end
 if (e.fork or 0)>0 then table.insert(details,string.format('One crystal within %g studs',reach(choice,'Split reach',6+math.clamp(e.forkRange or 0,0,6)))) end
 if (e.splash or 0)>0 then table.insert(details,string.format('One sentry within %g studs',reach(choice,'Arc reach',6+math.clamp(e.chain or 0,0,16)))) end
 return table.concat(details,'\n')
end

-- ViewportFrame cannot render nested GuiObjects. The supported hierarchy is a
-- real camera-local card > SurfaceGui face > small ViewportFrame illustration.
-- Screen-space hitboxes retain ordinary touch, keyboard and controller input.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local GuiService=game:GetService('GuiService')
local UserInputService=game:GetService('UserInputService')
local serial=0
local bindPrefix='UpgradeCards'..game:GetService('HttpService'):GenerateGUID(false)
local FACE_PIXELS=3 -- Supersample the curved physical face; screen text stays native.
local function rarityColor(tier) return Color3.fromRGB(table.unpack(Packs.Palette[tier] or Packs.Palette[1])) end
local function reducedMotion()
 local reduced=false
 pcall(function() reduced=GuiService.ReducedMotionEnabled end)
 local player=Players.LocalPlayer
 return reduced or player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true
end

local function visualPart(parent,size,position,color,shape)
 local part=Instance.new('Part');part.Size=size;part.CFrame=CFrame.new(position);part.Color=color
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Material=Enum.Material.Plastic;part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 if shape then part.Shape=shape end
 part.Parent=parent;return part
end
-- Identity follows the mechanic, never a rainbow rarity assignment.
function CardView.identity(choice)
 local e=choice.effects or {}
 local function has(k) return type(e[k])=='number' and e[k]>0 end
 if has('doubleBeam') then return 'double',Color3.fromRGB(20,82,163),Color3.fromRGB(113,236,255) end
 if has('twinThrusters') then return 'boost',Color3.fromRGB(159,55,23),Color3.fromRGB(255,168,69) end
 if has('oreDuplicator') then return 'duplicate',Color3.fromRGB(130,81,12),Color3.fromRGB(255,224,104) end
 if has('compactor') or has('batchPress') then return 'press',Color3.fromRGB(135,71,19),Color3.fromRGB(255,208,116) end
 if has('liveWire') then return 'thrust',Color3.fromRGB(29,111,71),Color3.fromRGB(178,255,116) end
 if has('shiftRelay') then return 'cargo',Color3.fromRGB(158,94,21),Color3.fromRGB(255,221,123) end
 if has('orbitalLaser') then return 'orbital',Color3.fromRGB(219,58,35),Color3.fromRGB(255,223,82) end
 if has('scrapSwarm') then return 'swarm',Color3.fromRGB(103,49,209),Color3.fromRGB(191,255,98) end
 if has('plotAuto') then return 'scanner',Color3.fromRGB(0,119,114),Color3.fromRGB(142,255,153) end
 if has('aftershock') then return 'aftershock',Color3.fromRGB(42,75,203),Color3.fromRGB(88,244,255) end
 if has('fork') then return 'prism',Color3.fromRGB(42,75,203),Color3.fromRGB(88,244,255) end
 if has('capacity') or has('fullAuto') or has('magnetRange') then return 'cargo',Color3.fromRGB(200,93,10),Color3.fromRGB(255,224,101) end
 if has('health') or has('reduction') or has('salvage') or has('shield') then return 'repair',Color3.fromRGB(12,125,65),Color3.fromRGB(164,255,180) end
 if has('combat') or has('rate') or has('crit') or has('splash') or has('finisher') or has('range') then return 'combat',Color3.fromRGB(178,30,80),Color3.fromRGB(255,161,198) end
 if has('speed') or has('startup') or has('reclaim') or has('fieldCharge') then return 'thrust',Color3.fromRGB(0,104,179),Color3.fromRGB(121,237,255) end
 return 'mineral',Color3.fromRGB(104,49,170),Color3.fromRGB(245,177,255)
end

-- One textured surface and one rounded border, shared by cards and packs.
-- Use Roblox's shipped stud atlas; no uploaded art or per-stud GUI objects.
function CardView.housing(U,root,color,_accent)
 local pixels=root.Parent:IsA('SurfaceGui') and FACE_PIXELS or 1
 root.BackgroundColor3=color
 local finish=Instance.new('UIGradient');finish.Name='GlossColor';finish.Rotation=90
 finish.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.42,Color3.fromRGB(220,228,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(85,87,130))});finish.Parent=root
 local corner=root:FindFirstChildOfClass('UICorner') or U.corner(root,20*pixels)
 corner.CornerRadius=UDim.new(0,20*pixels)
 local edge=U.stroke(root,Color3.fromRGB(16,28,55),3*pixels)
 edge.BorderStrokePosition=Enum.BorderStrokePosition.Inner;edge.ZIndex=root.ZIndex+5
 local texture=Instance.new('CanvasGroup');texture.Name='StudTexture';texture.BackgroundTransparency=1
 texture.Size=UDim2.fromScale(1,1);texture.ZIndex=root.ZIndex+1;texture.Parent=root;U.corner(texture,20*pixels)
 -- The shipped image is an atlas. Tile its first 512-pixel stud region in
 -- short bands; cropped ImageRects do not honor TileSize in the native UI.
 local band=96*pixels
 local bands=math.max(1,math.ceil(math.max(root.Size.Y.Offset,band)/band))
 for i=0,bands-1 do
  local tile=Instance.new('ImageLabel');tile.Name='StudBand';tile.BackgroundTransparency=1
  tile.Position=UDim2.fromOffset(0,i*band);tile.Size=UDim2.new(1,0,0,band)
  tile.Image='rbxasset://textures/studs.dds';tile.ScaleType=Enum.ScaleType.Tile
  tile.TileSize=UDim2.fromOffset(24*pixels,384*pixels)
  tile.ImageColor3=color:Lerp(Color3.new(1,1,1),.2);tile.ImageTransparency=.83
  tile.ZIndex=texture.ZIndex+1;tile.Parent=texture
 end
 return edge
end

local function mechanicVisual(parent,choice,compact)
 local viewport=Instance.new('ViewportFrame');viewport.Name='MechanicPreview';viewport.BackgroundTransparency=1;viewport.ZIndex=parent.ZIndex+4
 viewport.Position=UDim2.fromScale(.045,.022);viewport.Size=UDim2.fromScale(.91,compact and .32 or .46)
 viewport.Ambient=Color3.fromRGB(205,210,225);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-3);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Name='Mechanic';world.Parent=viewport
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(Vector3.new(4,3,7),Vector3.new(0,-.1,0));camera.Parent=viewport;viewport.CurrentCamera=camera
 local identity,body,accent=CardView.identity(choice)
 local storage=game:GetService('ReplicatedStorage')
 local config=storage:FindFirstChild('Shared');config=config and config:FindFirstChild('DroneConfig')
 local roles=config and require(config)
 local function safe(model)
  for _,c in ipairs(model:GetDescendants()) do
   if c:IsA('LuaSourceContainer') or c:IsA('Sound') or c:IsA('BillboardGui') or c:IsA('SurfaceGui') then c:Destroy()
   elseif c:IsA('BasePart') then c.Anchored=true;c.CanCollide=false;c.CanTouch=false;c.CanQuery=false;c.CastShadow=false;c.Reflectance=0
   elseif c:IsA('Trail') or c:IsA('Beam') or c:IsA('ParticleEmitter') then c.Enabled=false end
  end
 end
 local function drone(role,size,position,rotation)
  local template=storage:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
  if not template or not template:IsA('Model') then return end
  local model=template:Clone();safe(model)
  if roles then
   roles.decorate(model,role)
  else
   local shell=model:FindFirstChild('Mesh')
   if shell and shell:IsA('BasePart') then shell.Color=Color3.fromRGB(66,87,111):Lerp(body,.25) end
  end
  safe(model)
  local _,bounds=model:GetBoundingBox();model:ScaleTo(model:GetScale()*size/math.max(bounds.X,bounds.Y,bounds.Z,.01))
  local box=model:GetBoundingBox();model:PivotTo(CFrame.new(position)*(rotation or CFrame.new())*box:Inverse()*model:GetPivot())
  model.Parent=world;return model
 end
 local function crystal(size,position,color,rotation)
  local original=storage:FindFirstChild('Crystal') or workspace:FindFirstChild('Crystal')
  local template=original and original:FindFirstChild('Mesh',true)
  if not template or not template:IsA('BasePart') then return end
  local part=template:Clone();safe(part)
  part.Size=template.Size*(size/math.max(template.Size.Y,.01));part.CFrame=CFrame.new(position)*(rotation or CFrame.new())
  part.Color=color;part.Material=Enum.Material.SmoothPlastic;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Reflectance=0;part.Parent=world
  return part
 end
 local function ray(a,b,width,color)
  local length=(b-a).Magnitude
  local halo=visualPart(world,Vector3.new(length,width*2.4,width*2.4),(a+b)/2,color,Enum.PartType.Cylinder);halo.Transparency=.68
  halo.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0)
  local core=visualPart(world,Vector3.new(length,width,width),(a+b)/2,color:Lerp(Color3.new(1,1,1),.7),Enum.PartType.Cylinder)
  core.CFrame=halo.CFrame
 end
 local function chips(position,color)
  for i=1,5 do
   local a=i*math.pi*2/5
   crystal(.35+i%2*.12,position+Vector3.new(math.cos(a)*.95,.1+i%2*.25,math.sin(a)*.65),color,CFrame.Angles(.2,a,.3))
  end
 end
 if identity=='double' then
  drone('Striker',2.75,Vector3.new(0,1.3,0))
  local tip=Vector3.new(0,-.74,.3)
  crystal(1.8,Vector3.new(0,-1.45,.3),Color3.fromRGB(255,116,129),CFrame.Angles(.16,.6,-.12))
  for _,side in ipairs({-1,1}) do
   local muzzle=Vector3.new(side*.75,.71,.25)
   visualPart(world,Vector3.new(.43,.26,.55),muzzle,accent)
   ray(muzzle,tip,.105,accent)
  end
 elseif identity=='boost' then
  drone('Striker',2.7,Vector3.new(.3,.25,0),CFrame.Angles(0,-.4,.10))
  for _,side in ipairs({-1,1}) do
   local pod=Vector3.new(.2,.15+side*.62,side*.72)
   visualPart(world,Vector3.new(.82,.28,.38),pod,accent)
   ray(pod-Vector3.xAxis*.35,pod-Vector3.xAxis*(side==1 and 2.2 or 1.75),.16,accent)
  end
 elseif identity=='duplicate' then
  drone('Striker',2.7,Vector3.new(0,1,0))
  for _,side in ipairs({-1,1}) do
   local pos=Vector3.new(side*1.06,-.9,.32)
   crystal(1.65,pos,accent,CFrame.Angles(0,side*.42,side*.22))
   crystal(.7,pos+Vector3.new(side*.54,-.47,.5),accent,CFrame.Angles(0,side*.5,-side*.3))
  end
 elseif identity=='press' then
  drone('Compactor',2.5,Vector3.new(0,.45,0),CFrame.Angles(0,-.2,0))
  local inputs=choice.effects.batchPress and 2 or 3
  for i=1,inputs do
   crystal(.66,Vector3.new(-1.55,-1.6+(i-1)*.57,.5),Color3.fromRGB(241,103,96),CFrame.Angles(0,i*.6,.2))
  end
  crystal(1.58,Vector3.new(1.25,-1.18,.48),Color3.fromRGB(250,91,143),CFrame.Angles(0,-.3,-.22))
 elseif identity=='orbital' then
  drone('Orbiter',2.6,Vector3.new(0,1.25,0))
  crystal(2,Vector3.new(0,-1.4,0),Color3.fromRGB(246,116,57),CFrame.Angles(0,.3,-.1))
  ray(Vector3.new(0,.75,0),Vector3.new(0,-.9,0),.2,accent)
  chips(Vector3.new(0,-1.65,0),accent)
 elseif identity=='swarm' then
  for i=1,3 do
   local x=(i-2)*1.45;local y=i==2 and .8 or .15
   drone('Scrapper',1.65,Vector3.new(x,y,0),CFrame.Angles(0,(i-2)*-.3,(i-2)*.15))
   ray(Vector3.new(x,y-.4,0),Vector3.new(x*.6,-1.1,0),.065,accent)
  end
  crystal(1.7,Vector3.new(0,-1.6,0),Color3.fromRGB(185,122,255),CFrame.Angles(0,.4,-.15));chips(Vector3.new(0,-1.5,0),accent)
 elseif identity=='aftershock' then
  drone('Striker',1.85,Vector3.new(-.8,1.25,0))
  crystal(1.7,Vector3.new(-.8,-1.25,0),Color3.fromRGB(255,116,129),CFrame.Angles(.16,.6,-.12))
  crystal(1.4,Vector3.new(1.18,-1.1,.15),Color3.fromRGB(247,139,205),CFrame.Angles(.12,.4,.22))
  ray(Vector3.new(-.8,.67,0),Vector3.new(-.8,-.65,0),.095,accent)
  local bend=Vector3.new(.16,-.72,.3)
  ray(Vector3.new(-.45,-1,.16),bend,.078,accent)
  ray(bend,Vector3.new(.87,-1.05,.24),.078,accent)
 elseif identity=='prism' then
  drone('Striker',1.85,Vector3.new(0,1.25,0),CFrame.Angles(0,-.3,.08))
  local prism=visualPart(world,Vector3.new(.85,1.1,.85),Vector3.new(0,-.15,0),accent)
  prism.CFrame=CFrame.new(0,-.15,0)*CFrame.Angles(0,math.rad(45),math.rad(25))
  ray(Vector3.new(0,.65,0),Vector3.new(0,.2,0),.11,accent)
  for _,sign in ipairs({-1,1}) do
   local color=sign<0 and Color3.fromRGB(129,255,179) or Color3.fromRGB(255,154,222)
   crystal(1.6,Vector3.new(sign*1.25,-1.35,0),color,CFrame.Angles(0,sign*.5,sign*.12))
   ray(Vector3.new(0,-.15,0),Vector3.new(sign*1.25,-.75,0),.11,color)
  end
 elseif identity=='cargo' then
  drone('Courier',3.1,Vector3.new(.25,.45,0),CFrame.Angles(0,-.25,.08))
  for i=1,3 do crystal(1.05,Vector3.new((i-2)*.6,-1.2,.8),accent,CFrame.Angles(0,i*.7,-.15)) end
 elseif identity=='repair' then
  drone('Medic',3.3,Vector3.new(0,.15,0),CFrame.Angles(.1,-.2,-.15))
  for i=1,3 do
   local x=(i-2)*1.25;local y=i==2 and 1.6 or -.9
   visualPart(world,Vector3.new(.14,.55,.14),Vector3.new(x,y,.5),accent)
   visualPart(world,Vector3.new(.55,.14,.14),Vector3.new(x,y,.5),accent)
  end
 elseif identity=='thrust' then
  drone('Striker',2.75,Vector3.new(.7,.15,0),CFrame.Angles(0,-.3,-.22))
  for i=-1,1 do ray(Vector3.new(-2.3,i*.5,-.2),Vector3.new(-.55,i*.5+.3,-.2),.12,accent) end
 elseif identity=='scanner' then
  drone('Dart',2.5,Vector3.new(0,.95,0),CFrame.Angles(0,-.3,0))
  for i=-1,1 do crystal(1.4,Vector3.new(i*1.25,-1.1,0),i==0 and accent or body:Lerp(accent,.4),CFrame.Angles(0,i*.4,.1)) end
  ray(Vector3.new(0,.4,0),Vector3.new(-1.25,-.4,0),.07,accent);ray(Vector3.new(0,.4,0),Vector3.new(1.25,-.4,0),.07,accent)
 elseif identity=='combat' then
  drone('Charger',3.1,Vector3.new(0,.45,0),CFrame.Angles(0,-.4,-.22))
  for i=-1,1 do ray(Vector3.new(i*.6,-.45,.2),Vector3.new(i*.9,-1.65,.2),.12,accent) end
  chips(Vector3.new(0,-1.6,0),accent)
 else
  drone('Striker',2,Vector3.new(-.8,1.05,0),CFrame.Angles(0,-.25,-.1))
  crystal(2.7,Vector3.new(.45,-.7,0),accent,CFrame.Angles(0,.35,-.17))
  ray(Vector3.new(-.8,.6,0),Vector3.new(.1,.05,0),.11,accent);chips(Vector3.new(0,-1.5,0),body:Lerp(accent,.65))
 end
 -- A single offset silhouette keeps the mechanism readable on enamel.
 local outline=viewport:Clone();outline.Name='ArtworkSilhouette';outline.CurrentCamera=camera
 local copiedCamera=outline:FindFirstChildOfClass('Camera');if copiedCamera then copiedCamera:Destroy() end
 outline.ImageColor3=Color3.fromRGB(16,24,36);outline.Position=viewport.Position+UDim2.fromOffset(2*FACE_PIXELS,3*FACE_PIXELS)
 outline.ZIndex=viewport.ZIndex-1;outline.Parent=parent
 return viewport,camera
end

-- Shipped radial light has transparent, feathered spokes and ends.
local function sunburst(_U,canvas,compact,color)
 local rays=Instance.new('ImageLabel');rays.Name='SpinningRays';rays.BackgroundTransparency=1
 rays.AnchorPoint=Vector2.new(.5,.5);rays.Position=UDim2.fromScale(.5,compact and .182 or .252)
 rays.Size=UDim2.fromScale(1,compact and .54 or .76);rays.Image='rbxasset://textures/glow.png'
 rays.ImageColor3=color:Lerp(Color3.new(1,1,1),.65);rays.ImageTransparency=.35;rays.ZIndex=canvas.ZIndex+2;rays.Parent=canvas
 local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Height;aspect.Parent=rays
 return rays
end

-- Concentric alpha layers approximate a continuous Gaussian without a
-- particle texture's colored/opaque RGB contaminating the card enamel.
local function softGlow(U,parent,name,color)
 local glow=Instance.new('CanvasGroup');glow.Name=name;glow.BackgroundTransparency=1;glow.AnchorPoint=Vector2.new(.5,.5)
 glow.Size=UDim2.fromScale(1.1,.8);glow.Position=UDim2.fromScale(.5,.25);glow.GroupTransparency=1;glow.ZIndex=parent.ZIndex+1;glow.Parent=parent
 local previous=0
 for i=1,12 do
  local radius=1-(i-1)/12
  local opacity=.6*(math.exp(-radius*radius*4)-math.exp(-4))/(1-math.exp(-4))
  local alpha=(opacity-previous)/math.max(.001,1-previous);previous=opacity
  local disc=U.frame(glow,UDim2.fromScale((1-radius)/2,(1-radius)/2),UDim2.fromScale(radius,radius),color)
  disc.ZIndex=glow.ZIndex;disc.BackgroundTransparency=1-alpha;U.corner(disc,999)
 end
 return glow
end

local function shineLayer(U,canvas,rim)
 local shine=Instance.new('CanvasGroup');shine.Name='FaceLight';shine.BackgroundTransparency=1;shine.Size=UDim2.fromScale(1,1);shine.ZIndex=canvas.ZIndex+2;shine.Parent=canvas;U.corner(shine,20*FACE_PIXELS)
 local sweep=U.frame(shine,UDim2.fromScale(-.6,-.25),UDim2.fromScale(.7,1.5),Color3.new(1,1,1));sweep.Name='GlossSweep';sweep.Rotation=22;sweep.Visible=false
 local g=Instance.new('UIGradient');g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,1),NumberSequenceKeypoint.new(.35,.95),NumberSequenceKeypoint.new(.5,.78),NumberSequenceKeypoint.new(.65,.95),NumberSequenceKeypoint.new(.82,1),NumberSequenceKeypoint.new(1,1)});g.Parent=sweep
 local spot=softGlow(U,shine,'MouseHighlight',Color3.new(1,1,1))
 local ambient=softGlow(U,shine,'EnamelLight',rim:Lerp(Color3.new(1,1,1),.65));ambient.GroupTransparency=.82;ambient.Size=UDim2.fromScale(1.3,.9);ambient.Position=UDim2.fromScale(.4,.17)
 local flash=Instance.new('ImageLabel');flash.Name='RimFlash';flash.BackgroundTransparency=1;flash.Image='rbxasset://textures/particles/sparkles_main.dds';flash.ImageColor3=rim:Lerp(Color3.new(1,1,1),.65);flash.Size=UDim2.fromOffset(32*FACE_PIXELS,32*FACE_PIXELS);flash.AnchorPoint=Vector2.new(.5,.5);flash.ImageTransparency=1;flash.ZIndex=canvas.ZIndex+7;flash.Parent=canvas
 return sweep,spot,flash
end
local function visibleRect(root)
 local position,size=root.AbsolutePosition,root.AbsoluteSize
 local left,top,right,bottom=position.X,position.Y,position.X+size.X,position.Y+size.Y
 local ancestor=root
 while ancestor do
  if ancestor:IsA('GuiObject') then
   if not ancestor.Visible then return nil end
   if ancestor~=root and (ancestor.ClipsDescendants or ancestor:IsA('ScrollingFrame')) then
    local p,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
    left=math.max(left,p.X);top=math.max(top,p.Y);right=math.min(right,p.X+s.X);bottom=math.min(bottom,p.Y+s.Y)
   end
  elseif ancestor:IsA('ScreenGui') and not ancestor.Enabled then return nil end
  ancestor=ancestor.Parent
 end
 if right-left<2 or bottom-top<2 or size.X<2 or size.Y<2 then return nil end
 return left,top,right,bottom
end
local function onPlane(camera,x,y,depth)
 -- AbsolutePosition and ScreenPointToRay both use CoreUISafeInsets coordinates.
 local ray=camera:ScreenPointToRay(x,y)
 local direction=camera.CFrame:VectorToObjectSpace(ray.Direction)
 return ray.Origin+ray.Direction*(depth/math.max(.001,-direction.Z))
end

function CardView.create(U,parent,choice,index,width,height,options)
 options=options or {};height=math.max(height or CardView.HEIGHT,CardView.MIN_HEIGHT)
 local compact=height<300
 local p=U.palette;local _,bodyColor,accentColor=CardView.identity(choice)
 local tier=table.find(Packs.Tiers,choice.rarity) or (choice.rarity=='Uncommon' and 2 or 1)
 local tierColor=rarityColor(tier)
 local slot=U.frame(parent,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),p.ink)
 slot.Name='CardChoice'..tostring(index);slot.LayoutOrder=index;slot.BackgroundTransparency=1
 local socket=U.frame(slot,UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),Color3.fromRGB(13,24,36))
 socket.Name='UpgradeSlot';socket.BackgroundTransparency=.64;U.corner(socket,14)
 local rail=U.stroke(socket,Color3.fromRGB(119,147,168),2);rail.Transparency=.32
 local latch=U.frame(slot,UDim2.new(.5,-22,1,-12),UDim2.fromOffset(44,7),Color3.fromRGB(62,89,108))
 latch.Name='SlotLatch';U.corner(latch,3)
 for _,side in ipairs({0,1}) do
  local handle=U.frame(slot,UDim2.new(side,side==0 and 0 or -6,.38,0),UDim2.new(0,6,.24,0),Color3.fromRGB(69,94,112))
  U.corner(handle,3)
 end
 width-=16;height-=16
 local card=U.frame(slot,UDim2.fromOffset(8,3),UDim2.fromOffset(width,height),p.paper)
 card.Name='MountedCard';card.BackgroundTransparency=1
 local badge=U.frame(card,UDim2.new(.5,-62,0,8),UDim2.fromOffset(124,25),tierColor)
 badge.Name='RarityBadge';U.corner(badge,8);U.stroke(badge,p.ink,1.5)
 local rarity=U.text(badge,UDim2.fromScale(0,0),UDim2.fromScale(1,1),string.upper(choice.rarity or Packs.Tiers[tier])..' '..string.rep('◆',tier),12,p.ink,true)
 rarity.TextXAlignment=Enum.TextXAlignment.Center
 local choose=U.button(card,UDim2.fromScale(0,0),UDim2.fromScale(1,1),'',options.onChoose,p.paper)
 choose.Name='ChooseCard';U.unskin(choose);choose.TextTransparency=1;choose.BackgroundTransparency=1
 local outline=choose:FindFirstChildOfClass('UIStroke');if outline then outline.Enabled=false end
 local scale=choose:FindFirstChild('ButtonScale');if scale then scale:Destroy() end
 local selection=Instance.new('Frame');selection.Name='SelectionMask';selection.BackgroundTransparency=1;selection.Size=UDim2.fromScale(1,1);selection.Parent=choose
 choose.SelectionImageObject=selection -- The physical card border supplies focus, not a second square outline.
 local model=Instance.new('Folder');model.Name='LocalUpgradeCard';model.Parent=workspace
 local part=visualPart(model,Vector3.new(2,3,.05),Vector3.zero,Color3.fromRGB(74,83,88));part.Name='CardBody';part.Transparency=1
 local surface=Instance.new('SurfaceGui');surface.Name='UpgradeCardFace';surface.Adornee=part;surface.Face=Enum.NormalId.Front
 surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.CanvasSize=Vector2.new(width*FACE_PIXELS,height*FACE_PIXELS)
 -- The current native renderer drops AlwaysOnTop faces, even on a minimal
 -- diagnostic part. Render these camera-local faces near the camera instead.
 surface.AlwaysOnTop=false;surface.LightInfluence=0;surface.Brightness=1;surface.MaxDistance=8;surface.Active=false;surface.Enabled=false;surface.ResetOnSpawn=false
 surface.ClipsDescendants=true;surface.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;surface.Parent=Players.LocalPlayer:WaitForChild('PlayerGui')
 local canvas=U.frame(surface,UDim2.fromOffset(0,0),UDim2.fromOffset(width*FACE_PIXELS,height*FACE_PIXELS),p.paper);canvas.Name='CardCanvas'
 local border=CardView.housing(U,canvas,bodyColor,accentColor)
 local rim=tierColor
 border.Color=bodyColor:Lerp(Color3.fromRGB(3,5,14),.75);border.Thickness=1.5*FACE_PIXELS
 -- Soft colored spill outside the bevel is drawn on a padded physical face.
 -- The enamel covers the overlapping centers, leaving only the feathered rim.
 local spill=Instance.new('Frame');spill.Name='RimGlow';spill.BackgroundTransparency=1;spill.Size=UDim2.fromScale(1,1);spill.ZIndex=canvas.ZIndex;spill.Parent=canvas
 for i=12,1,-1 do
  local spread=i*FACE_PIXELS
  local halo=U.frame(spill,UDim2.fromOffset(-spread,-spread),UDim2.new(1,spread*2,1,spread*2),tierColor)
  halo.BackgroundTransparency=.985-tier*.009;halo.ZIndex=spill.ZIndex;U.corner(halo,20*FACE_PIXELS+spread)
 end
 local rimFace=U.frame(canvas,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1));rimFace.Name='RimBevel';rimFace.ZIndex=canvas.ZIndex;U.corner(rimFace,20*FACE_PIXELS)
 local inner=U.frame(rimFace,UDim2.fromOffset(5*FACE_PIXELS,5*FACE_PIXELS),UDim2.new(1,-10*FACE_PIXELS,1,-10*FACE_PIXELS),Color3.new(1,1,1));inner.Name='Enamel';inner.ZIndex=canvas.ZIndex;U.corner(inner,15*FACE_PIXELS)
 local enamel=Instance.new('UIGradient');enamel.Rotation=90;enamel.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,bodyColor:Lerp(Color3.new(1,1,1),.12)),ColorSequenceKeypoint.new(.28,bodyColor:Lerp(Color3.new(1,1,1),.025)),ColorSequenceKeypoint.new(.62,bodyColor),ColorSequenceKeypoint.new(1,bodyColor:Lerp(Color3.new(0,0,0),.33))});enamel.Parent=inner
 local rimLight=Instance.new('UIGradient');rimLight.Name='RimLight';rimLight.Rotation=118
 rimLight.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,tierColor:Lerp(Color3.new(1,1,1),.66)),ColorSequenceKeypoint.new(.34,tierColor),ColorSequenceKeypoint.new(.60,tierColor:Lerp(p.ink,.36)),ColorSequenceKeypoint.new(.84,tierColor),ColorSequenceKeypoint.new(1,tierColor:Lerp(p.ink,.24))});rimLight.Parent=rimFace
 local edge=U.stroke(inner,bodyColor:Lerp(Color3.new(1,1,1),.5),FACE_PIXELS);edge.Transparency=.5
 local texture=canvas:FindFirstChild('StudTexture');texture.Position=UDim2.fromOffset(5*FACE_PIXELS,5*FACE_PIXELS);texture.Size=UDim2.new(1,-10*FACE_PIXELS,1,-10*FACE_PIXELS);texture:FindFirstChildOfClass('UICorner').CornerRadius=UDim.new(0,15*FACE_PIXELS)
 local rays=sunburst(U,canvas,compact,accentColor)
 local sweep,spot,flash=shineLayer(U,canvas,rim)
 rays.Parent=canvas.FaceLight
 local _,artCamera=mechanicVisual(canvas,choice,compact)
 local summary=CardView.summary(choice)
 local function escape(v) return (tostring(v):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')) end
 local heading=escape(choice.title or 'Run upgrade')
 local bodyText=escape(summary)
 local display='<b>'..heading..'</b>\n'..bodyText
 -- Keep font rasterization and scrolling in the native screen layer. The
 -- body/art retain real perspective; near-camera SurfaceGui glyphs otherwise
 -- lose rows of pixels in the depth pass on the verified phone renderer.
 local effectY=compact and .37 or .48
 local termsY=compact and .72 or .80
 local effect=U.text(card,UDim2.new(0,12,effectY,0),UDim2.new(1,-24,compact and .33 or .30,0),display,compact and 16 or 18,p.white,true)
 effect.RichText=true;effect.Name='CardEffect';effect.TextXAlignment=Enum.TextXAlignment.Center
 effect.TextStrokeColor3=Color3.fromRGB(13,23,48);effect.TextStrokeTransparency=.5
 local terms=U.text(card,UDim2.new(0,12,termsY,0),UDim2.new(1,-24,compact and .24 or .16,0),CardView.terms(choice,options.target,true),16,p.white,false)
 terms.Name='CardTerms';terms.TextXAlignment=Enum.TextXAlignment.Center
 terms.TextStrokeColor3=Color3.fromRGB(13,23,48);terms.TextStrokeTransparency=.6
 local focused,pressed,blend,selected=false,false,0,false
 local finishedAt,installed
 local revealSpeed=math.clamp(options.revealSpeed or 1,1,4);local revealStart=os.clock()+(options.skipReveal and 0 or ((index-1)*.13)/revealSpeed)
 local reducedMotion=options.reducedMotion==true
 pcall(function() reducedMotion=GuiService.ReducedMotionEnabled end)
 local function motionReduced()
  return reducedMotion or options.reducedMotion==true or Players.LocalPlayer:GetAttribute('ReducedMotion')==true or Players.LocalPlayer:GetAttribute('MA_ReducedMotion')==true
 end
 local signals={}
 local function connect(signal,fn) table.insert(signals,signal:Connect(fn)) end
 connect(choose.MouseEnter,function() focused=true end);connect(choose.MouseLeave,function() focused=false;pressed=false end)
 connect(choose.SelectionGained,function() focused=true end);connect(choose.SelectionLost,function() focused=false;pressed=false end)
 connect(choose.MouseButton1Down,function() pressed=true end);connect(choose.MouseButton1Up,function() pressed=false end)
 pcall(function() connect(GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'),function() reducedMotion=GuiService.ReducedMotionEnabled end) end)
 serial=serial+1;local stepName=bindPrefix..'Card'..serial
 local dead=false;local landed=false;local wasFocused=false;local focusAt=-10;local pointerX,pointerY=0,0
 local function dispose()
  if dead then return end;dead=true;RunService:UnbindFromRenderStep(stepName)
  for _,connection in ipairs(signals) do connection:Disconnect() end
  surface:Destroy();model:Destroy()
 end
 connect(slot.Destroying,dispose)
 RunService:BindToRenderStep(stepName,Enum.RenderPriority.Camera.Value+8,function(dt)
  if dead then return end
  local camera=workspace.CurrentCamera;local left,top,right,bottom=visibleRect(card)
  if not camera or not left then surface.Enabled=false;part.Transparency=1;return end
  local clock=os.clock();local age=clock-revealStart;local quiet=motionReduced()
  local instant=quiet or options.skipReveal
  if not instant and age<0 then choose.Visible=false;effect.Visible=false;terms.Visible=false;badge.Visible=false;surface.Enabled=false;return end
  local progress=instant and 1 or math.clamp(age/(.55/revealSpeed),0,1)
  local reveal=1-(1-progress)^3
  if progress>=.91 and not landed then
   landed=true
   if not options.skipReveal and options.onLand then options.onLand(tier) end
  end
  choose.Visible=progress>=1 and finishedAt==nil
  local resultAge=finishedAt and clock-finishedAt or 0
  local leaving=finishedAt and not installed and (quiet and 1 or math.clamp(resultAge/.24,0,1)^2) or 0
  if leaving>=1 then effect.Visible=false;terms.Visible=false;badge.Visible=false;surface.Enabled=false;return end
  local position,size=card.AbsolutePosition,card.AbsoluteSize
  local full=right-left>=size.X-.5 and bottom-top>=size.Y-.5
  local target=(selected or focused and choose.Active) and 1 or 0
  if target==1 and not wasFocused then focusAt=clock end;wasFocused=target==1
  local nx,ny=0,0
  if target==1 and UserInputService.MouseEnabled then local mouse=UserInputService:GetMouseLocation();nx=math.clamp((mouse.X-position.X)/math.max(1,size.X)*2-1,-1,1);ny=math.clamp((mouse.Y-position.Y)/math.max(1,size.Y)*2-1,-1,1) end
  local response=1-math.exp(-14*math.min(dt,.1));pointerX+=(nx-pointerX)*response;pointerY+=(ny-pointerY)*response
  blend=quiet and target or blend+(target-blend)*(1-math.exp(-18*math.min(dt,.1)))
  local latchPulse=instant and 0 or math.clamp(1-math.abs(progress-.91)/.09,0,1)
  local confirmPulse=installed and math.max(0,1-resultAge/.30) or 0
  socket.BackgroundTransparency=.55+.43*reveal
  latch.BackgroundColor3=tierColor:Lerp(Color3.new(1,1,1),math.max(latchPulse,confirmPulse)*.75)
  latch.BackgroundTransparency=selected and 0 or (1-reveal)*.76+.18
  rail.Color=tierColor
  rail.Transparency=selected and .02 or .58-tier*.07
  local lift=(full and not quiet and blend*6 or 0)-(pressed and 3 or 0)
  effect.Position=UDim2.new(0,12,effectY,-lift);terms.Position=UDim2.new(0,12,termsY,-lift)
  effect.Visible=progress>=.92 and leaving<.14;terms.Visible=effect.Visible
  badge.Visible=effect.Visible
  badge.Position=UDim2.new(.5,-62,0,8-lift)
  local bleed=0
  local x,y=(left+right)/2,(top+bottom)/2
  local origin=options.origin or Vector2.new(x+(2-index)*size.X*.22,y+size.Y*.43)
  local travel=1-reveal
  -- Approach the open dock, overshoot a few pixels, then drop into the latch.
  local arc=math.sin(progress*math.pi)*math.min(27,size.Y*.11)+math.sin(math.clamp((progress-.76)/.24,0,1)*math.pi)*7
  local depth=1
  local center=onPlane(camera,x+(origin.X-x)*travel,y+(origin.Y-y)*travel-arc-lift+leaving*52,depth+.015)
  local scale=(.44+.56*reveal)*(1-leaving*.34)
  local w=(onPlane(camera,right+bleed,y,depth)-onPlane(camera,left-bleed,y,depth)).Magnitude*scale
  local h=(onPlane(camera,x,top-bleed,depth)-onPlane(camera,x,bottom+bleed,depth)).Magnitude*scale
  local tilt=full and not quiet and math.rad(pointerX*blend*5+(index==1 and -1 or 1)*68*travel) or 0
  local pitch=full and not quiet and math.rad(-pointerY*blend*5-23*travel) or 0
  local roll=not quiet and math.rad((index-2)*20*travel) or 0
  part.Size=Vector3.new(math.max(.01,w),math.max(.01,h),.02)
  part.CFrame=CFrame.new(center)*camera.CFrame.Rotation*CFrame.Angles(pitch,math.pi+tilt,roll)
  part.Transparency=1;surface.Enabled=true;local canvasSize=Vector2.new(math.floor((right-left+bleed*2)*FACE_PIXELS+.5),math.floor((bottom-top+bleed*2)*FACE_PIXELS+.5));if surface.CanvasSize~=canvasSize then surface.CanvasSize=canvasSize end
  canvas.Size=UDim2.fromOffset(size.X*FACE_PIXELS,size.Y*FACE_PIXELS);canvas.Position=UDim2.fromOffset((position.X-left+bleed)*FACE_PIXELS,(position.Y-top+bleed)*FACE_PIXELS)
  canvas.BackgroundColor3=pressed and bodyColor:Lerp(p.ink,.18) or bodyColor:Lerp(accentColor,blend*.12)
  rimFace.BackgroundColor3=Color3.new(1,1,1)
  inner.BackgroundColor3=pressed and Color3.fromRGB(190,190,190) or Color3.new(1,1,1)
  rimLight.Offset=Vector2.new(quiet and 0 or pointerX*.15,quiet and 0 or pointerY*.2)
  rays.Rotation=quiet and 0 or (clock*9+index*27)%360
  rays.ImageTransparency=quiet and .4 or .4-blend*.1
  local pulse=clock-focusAt;local opening=age*revealSpeed
  local shine=opening<.9 and opening/.9 or (pulse<.7 and pulse/.7 or 2)
  sweep.Visible=not quiet and full and shine>=0 and shine<=1
  if sweep.Visible then sweep.Position=UDim2.fromScale(-.65+shine*2.1,-.25) end
  spot.GroupTransparency=quiet and 1 or 1-blend*.7
  spot.Position=UDim2.fromScale(.5+pointerX*.32,.3+pointerY*.22)
  local arrival=math.clamp(1-math.abs(progress-.94)/.14,0,1)
  if progress>=1 then arrival=math.clamp(1-(opening-.55)/.28,0,1)*.55 end
  local wink=not quiet and full and pulse>=0 and pulse<.65
  local intensity=wink and (1-math.abs(pulse/.65-.5)*2)*.75 or 0
  flash.ImageTransparency=not quiet and 1-math.max(intensity,options.skipReveal and 0 or arrival*(tier-1)/3) or 1
  flash.Position=UDim2.fromScale(pointerX<0 and .08 or .92,pointerY<0 and .08 or .92)
  artCamera.CFrame=CFrame.lookAt(Vector3.new(4+(quiet and 0 or pointerX*blend*.7),3+(quiet and 0 or -pointerY*blend*.35),7),Vector3.zero)
  effect.Text=choose.Text~='' and escape(choose.Text) or display
 end)
 return {root=slot,button=choose,select=function(value) selected=value end,
  finish=function(value) installed=value;finishedAt=os.clock() end}
end

-- The strip only reveals the committed result. The client supplies the motion.
function CardView.revealDrone(U,parent,width,reward,audio,isVisible,onClose)
 local p=U.palette
 local view=U.frame(parent,UDim2.fromOffset(0,10),UDim2.fromOffset(width,110),p.ink)
 view.Name='DroneRewardTicker';view.ClipsDescendants=true;U.corner(view,12)
 local strip=U.frame(view,UDim2.fromOffset(0,8),UDim2.fromOffset(0,94),p.ink);strip.BackgroundTransparency=1
 local cellWidth=math.min(134,math.floor(width*.46))
 local catalog=DroneCatalog.PrestigeRewards
 local winner=15
 for i=1,winner+2 do
  local entry=i==winner and {name=reward.rewardName,tier=reward.rewardTier} or catalog[(i+reward.prestiges-1)%#catalog+1]
  local tint=rarityColor(entry.tier)
  local cell=U.panel(strip,UDim2.fromOffset((i-1)*cellWidth+3,0),UDim2.fromOffset(cellWidth-6,94),p.ink:Lerp(tint,.25),8)
  U.stroke(cell,tint,2)
  U.icon(cell,'drone',UDim2.new(.5,-17,0,9),UDim2.fromOffset(34,34),tint)
  local name=U.text(cell,UDim2.fromOffset(2,44),UDim2.new(1,-4,0,25),entry.name,15,p.white,true)
  local tier=U.text(cell,UDim2.fromOffset(2,68),UDim2.new(1,-4,0,18),Packs.Tiers[entry.tier],12,tint,true)
  name.TextXAlignment=Enum.TextXAlignment.Center;tier.TextXAlignment=Enum.TextXAlignment.Center
 end
 local marker=U.frame(view,UDim2.new(.5,-2,0,0),UDim2.fromOffset(4,13),p.white);marker.ZIndex=10
 local detail=U.text(parent,UDim2.fromOffset(0,128),UDim2.fromOffset(width,56),'Adding a permanent drone…',18,p.text,true)
 detail.TextXAlignment=Enum.TextXAlignment.Center
 local settled=false
 local tint=rarityColor(reward.rewardTier)
 local trigger,connection
 local function place(index) strip.Position=UDim2.fromOffset(width*.5-(index-.5)*cellWidth,8) end
 local function settle()
  if settled then return end
  settled=true;place(winner);marker.BackgroundColor3=tint
  detail.Text=reward.rewardName..' joined your fleet\n'..reward.rewardJob
  trigger.Text='Continue';audio:play('pack_open',nil,{pitch=.95+reward.rewardTier*.11})
  if connection then connection:Disconnect();connection=nil end
 end
 trigger=U.button(parent,UDim2.new(.5,-74,0,198),UDim2.fromOffset(148,40),'Skip reveal',function()
  if settled then onClose() else settle() end
 end,tint)
 if reducedMotion() then settle();return end
 local start=os.clock();local last=2
 place(last)
 connection=RunService.RenderStepped:Connect(function()
  if not isVisible() then connection:Disconnect();connection=nil;return end
  local t=math.clamp((os.clock()-start)/(1.45+.17*reward.rewardTier),0,1)
  local index=2+(winner-2)*(1-(1-t)^3)
  place(index)
  local tick=math.floor(index+.5)
  if tick~=last and tick<winner then last=tick;audio:play('pack_step',nil,{pitch=.82+t*.37}) end
  if t>=1 then settle() end
 end)
 view.Destroying:Once(function() if connection then connection:Disconnect() end end)
end
return CardView
