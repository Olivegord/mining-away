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
 add('doubleBeam','Two beams on one rock.\n2× laser damage.')
 add('twinThrusters','Two thrusters.\n2× top flight speed.')
 add('oreDuplicator','Gold ore chamber.\n2× cargo value from this miner.')
 add('compactor','Legacy unlock: presses 3 matching rocks into 1 block of equal total value.')
 add('batchPress','The press can start with one fewer rock.')
 add('denserPacking','Pack '..(e.denserPacking or 0)..' more rocks in each full block.')
 add('cargoRack','+'..(e.cargoRack or 0)..' cargo mount on each Emptier.')
 add('liveWire',amount(e.liveWire or 0,'laser damage above half battery'))
 local shift=(e.shiftRelay or 0)+(choice.stackBefore or 0)*(choice.step and choice.step.shiftRelay or 0)
 add('shiftRelay',Workshop.shiftDescription(shift))
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
 add('yield',amount(e.yield or 0,'cargo value per crystal'))
 add('range',amount(e.range or 0,'attack range'))
 add('crit',percent(e.crit or 0)..' chance to hit twice')
 add('fork','Hit a nearby crystal for '..percent(e.fork or 0)..' damage')
 add('deepCut',amount(e.deepCut or 0,'damage in Ruby through Emerald'))
 local echo=(e.aftershock or 0)+(choice.stackBefore or 0)*(choice.step and choice.step.aftershock or 0)
 add('aftershock','Cracks hit one weak rock.\n'..percent(echo).." of the cracked rock's HP.")
 local reclaim=(e.reclaim or 0)+(choice.stackBefore or 0)*(choice.step and choice.step.reclaim or 0)
 add('reclaim',Workshop.reclaimDescription(reclaim))
 add('earlyDrop',Workshop.LOOSE_SEAMS_TEXT)
 add('fieldCharge','Depleted drones recharge at your pin')
 add('magnetRange',string.format('Pull ore from %.1f studs farther away',(e.magnetRange or 0)*Workshop.ORE_REACH_SCALE))
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
 elseif e.compactor then target='Compactor at your pin'
 elseif e.batchPress or e.denserPacking then target='Your Compactor'
 elseif e.cargoRack then target='All Emptiers'
 elseif e.shiftRelay then target='Your mining pin'
 elseif e.magnetRange then target='Cargo collection'
 elseif e.capacity then target='Your backpack'
 elseif choice.scope=='Player' then target='Your run'
 elseif (e.aftershock or 0)>0 or (e.earlyDrop or 0)>0 then target='Mining drones'
 elseif (e.deepCut or 0)>0 or (e.fork or 0)>0 or e.liveWire then target='Laser miners'
 elseif e.capacity and e.capacity>0 then target='Drones + backpack'
 elseif work and not allRoles or (e.reclaim or 0)>0 then target='Mining drones'
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

function CardView.fitText(choice,target,stats,canCycle)
 if not target then return 'No eligible miners' end
 local name=target.name..(canCycle and '  ›' or '')
 if not stats then return name end
 local e=choice.effects
 if (e.doubleBeam or 0)>0 and stats.miningDPS then
  return name..string.format('\n%.0f → %.0f HP/s',stats.miningDPS,stats.miningDPS*2)
 elseif (e.twinThrusters or 0)>0 and stats.maxStep60 then
  return name..string.format('\n%.0f → %.0f studs/s',stats.maxStep60*60,stats.maxStep60*120)
 elseif (e.oreDuplicator or 0)>0 and stats.yieldMultiplier then
  return name..string.format('\n%.3g× → %.3g× value',stats.yieldMultiplier,stats.yieldMultiplier*2)
 end
 return name
end

-- ViewportFrame cannot render nested GuiObjects. The supported hierarchy is a
-- Rounded card stock and mechanic models render in ViewportFrames.
-- Screen-space text and hitboxes stay sharp across device layouts.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local GuiService=game:GetService('GuiService')
local serial=0
local bindPrefix='UpgradeCards'..game:GetService('HttpService'):GenerateGUID(false)
local function rarityColor(tier) return Color3.fromRGB(table.unpack(Packs.Palette[tier] or Packs.Palette[1])) end
function CardView.rarityColor(choice) return rarityColor(Packs.rarityTier(choice.rarity)) end

-- Creator Store icons. The public thumbnails load in this experience.
local icons={
 drone='rbxthumb://type=Asset&id=15332132841&w=150&h=150',
 player='rbxthumb://type=Asset&id=15728996325&w=150&h=150',
 fleet='rbxthumb://type=Asset&id=114339465861147&w=150&h=150',
}
function CardView.scopeIcon(choice)
 if choice.scope=='Player' then return icons.player end
 if choice.scope=='Individual' or choice.scope=='Color' then return icons.drone end
 return icons.fleet
end

function CardView.reducedMotion()
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
 if has('earlyDrop') then return 'seams',Color3.fromRGB(124,66,26),Color3.fromRGB(255,204,112) end
 if has('compactor') or has('batchPress') or has('denserPacking') then return 'press',Color3.fromRGB(135,71,19),Color3.fromRGB(255,208,116) end
 if has('cargoRack') then return 'rack',Color3.fromRGB(129,83,23),Color3.fromRGB(255,207,113) end
 if has('liveWire') then return 'thrust',Color3.fromRGB(29,111,71),Color3.fromRGB(178,255,116) end
 if has('shiftRelay') then return 'cargo',Color3.fromRGB(158,94,21),Color3.fromRGB(255,221,123) end
 if has('orbitalLaser') then return 'orbital',Color3.fromRGB(219,58,35),Color3.fromRGB(255,223,82) end
 if has('scrapSwarm') then return 'swarm',Color3.fromRGB(103,49,209),Color3.fromRGB(191,255,98) end
 if has('plotAuto') then return 'scanner',Color3.fromRGB(0,119,114),Color3.fromRGB(142,255,153) end
 if has('aftershock') then return 'aftershock',Color3.fromRGB(73,47,145),Color3.fromRGB(188,178,255) end
 if has('fork') then return 'prism',Color3.fromRGB(42,75,203),Color3.fromRGB(88,244,255) end
 if has('capacity') or has('fullAuto') or has('magnetRange') then return 'cargo',Color3.fromRGB(200,93,10),Color3.fromRGB(255,224,101) end
 if has('health') or has('reduction') or has('salvage') or has('shield') then return 'repair',Color3.fromRGB(12,125,65),Color3.fromRGB(164,255,180) end
 if has('combat') or has('rate') or has('crit') or has('splash') or has('finisher') or has('range') then return 'combat',Color3.fromRGB(178,30,80),Color3.fromRGB(255,161,198) end
 if has('speed') or has('startup') or has('reclaim') or has('fieldCharge') then return 'thrust',Color3.fromRGB(0,104,179),Color3.fromRGB(121,237,255) end
 return 'mineral',Color3.fromRGB(104,49,170),Color3.fromRGB(245,177,255)
end

local function safePreview(model)
 for _,c in ipairs(model:GetDescendants()) do
  if c:IsA('LuaSourceContainer') or c:IsA('Sound') or c:IsA('BillboardGui') or c:IsA('SurfaceGui') then c:Destroy()
  elseif c:IsA('BasePart') then c.Anchored=true;c.CanCollide=false;c.CanTouch=false;c.CanQuery=false;c.CastShadow=false;c.Reflectance=0
  elseif c:IsA('Trail') or c:IsA('Beam') or c:IsA('ParticleEmitter') then c.Enabled=false end
 end
end
local function previewDrone(role,tint,readable)
 local storage=game:GetService('ReplicatedStorage')
 local template=storage:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
 if not template or not template:IsA('Model') then return end
 local config=storage:FindFirstChild('Shared')
 config=config and config:FindFirstChild('DroneConfig')
 local model=template:Clone();safePreview(model)
 if config then
  require(config).decorate(model,role,nil,readable)
 else
  local shell=model:FindFirstChild('Mesh')
  if shell and shell:IsA('BasePart') then shell.Color=Color3.fromRGB(66,87,111):Lerp(tint,.25) end
 end
 safePreview(model)
 return model
end

function CardView.dronePortrait(parent,position,size,kind,tint)
 local role=kind=='Blue' and 'Striker' or kind=='Red' and 'Charger' or kind
 local model=previewDrone(role,tint,true)
 if not model then return end
 local viewport=Instance.new('ViewportFrame');viewport.Name='DronePortrait';viewport.BackgroundTransparency=1
 viewport.Position=position;viewport.Size=size;viewport.ZIndex=parent.ZIndex+2
 viewport.Ambient=Color3.fromRGB(182,187,198);viewport.LightColor=Color3.fromRGB(255,245,226)
 viewport.LightDirection=Vector3.new(-1,-2,1);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Parent=viewport
 local box,bounds=model:GetBoundingBox()
 model:PivotTo(box:Inverse()*model:GetPivot());model.Parent=world
 local camera=Instance.new('Camera');camera.FieldOfView=36
 local from=Vector3.new(1,.48,-1.35).Unit*bounds.Magnitude*1.65
 camera.CFrame=CFrame.lookAt(from,Vector3.zero);camera.Parent=viewport;viewport.CurrentCamera=camera
 return viewport
end

local function mechanicVisual(parent,choice,compact)
 local viewport=Instance.new('ViewportFrame');viewport.Name='MechanicPreview';viewport.BackgroundTransparency=1;viewport.ZIndex=parent.ZIndex+4
 viewport.Position=UDim2.fromScale(.045,.022);viewport.Size=UDim2.fromScale(.91,compact and .32 or .46)
 viewport.Ambient=Color3.fromRGB(205,210,225);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-3);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Name='Mechanic';world.Parent=viewport
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(Vector3.new(4,3,7),Vector3.new(0,-.1,0));camera.Parent=viewport;viewport.CurrentCamera=camera
 local identity,body,accent=CardView.identity(choice)
 local storage=game:GetService('ReplicatedStorage')
 local function drone(role,size,position,rotation)
  local model=previewDrone(role,body)
  if not model then return end
  local _,bounds=model:GetBoundingBox();model:ScaleTo(model:GetScale()*size/math.max(bounds.X,bounds.Y,bounds.Z,.01))
  local box=model:GetBoundingBox();model:PivotTo(CFrame.new(position)*(rotation or CFrame.new())*box:Inverse()*model:GetPivot())
  model.Parent=world;return model
 end
 local function crystal(size,position,color,rotation,material)
  local net=storage:FindFirstChild('MiningAway')
  local original=storage:FindFirstChild('Crystal') or workspace:FindFirstChild('Crystal')
  local template=(net and net:FindFirstChild('CargoCrystal')) or (original and original:FindFirstChild('Mesh',true))
  if not template or not template:IsA('BasePart') then return end
  local part=template:Clone();safePreview(part)
  part.Size=template.Size*(size/math.max(template.Size.Y,.01));part.CFrame=CFrame.new(position)*(rotation or CFrame.new())
  if part:IsA('PartOperation') then part.UsePartColor=true end
  part.Color=color;part.Material=material or Enum.Material.SmoothPlastic;part.MaterialVariant=''
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Reflectance=0;part.Parent=world
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
   visualPart(world,Vector3.new(.50,.31,.61),muzzle+Vector3.yAxis*.13,Color3.fromRGB(29,48,60))
   visualPart(world,Vector3.new(.31,.09,.44),muzzle,accent)
   ray(muzzle,tip,.105,accent)
  end
 elseif identity=='seams' then
  local cut=Color3.fromRGB(226,83,92)
  drone('Striker',2.12,Vector3.new(-.80,1.18,0))
  local remaining=crystal(1.56,Vector3.new(-.65,-1.24,.12),cut,CFrame.Angles(.14,.5,-.13))
  local cargo=crystal(.94,Vector3.new(1.05,-.62,.76),cut:Lerp(accent,.23),CFrame.Angles(.27,-.55,.43),Enum.Material.Glass)
  if remaining then remaining.Name='CrystalInCut' end
  if cargo then cargo.Name='ReleasedOre' end
  ray(Vector3.new(-.80,.64,.1),Vector3.new(-.65,-.59,.12),.085,Color3.fromRGB(231,250,255))
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
  local inputs=choice.effects.batchPress and 2 or (choice.effects.denserPacking and 5 or 3)
  for i=1,inputs do
   crystal(.66,Vector3.new(-1.55-(i-1)%2*.52,-1.5+math.floor((i-1)/2)*.54,.5),Color3.fromRGB(241,103,96),CFrame.Angles(0,i*.6,.2))
  end
  visualPart(world,Vector3.new(1.14,.76,.83),Vector3.new(1.4,-1.15,.54),Color3.fromRGB(241,103,96))
 elseif identity=='rack' then
  drone('Courier',3.05,Vector3.new(0,.65,0),CFrame.Angles(0,-.28,.08))
  for i=1,5 do
   local x=(i-3)*.67
   visualPart(world,Vector3.new(.56,.14,.79),Vector3.new(x,-1.08,.64),i==5 and accent or Color3.fromRGB(104,112,132))
   crystal(.76,Vector3.new(x,-.72,.64),i==5 and accent or Color3.fromRGB(144,217,246),CFrame.Angles(0,i*.5,.12))
  end
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
 return viewport
end

local function cardViewport(parent,name,zIndex)
 local view=Instance.new('ViewportFrame')
 view.Name=name;view.Size=UDim2.fromScale(1,1);view.BackgroundTransparency=1;view.ZIndex=zIndex
 view.Ambient=Color3.fromRGB(190,199,213);view.LightColor=Color3.fromRGB(252,246,231)
 view.LightDirection=Vector3.new(-.8,-1,-2)
 local camera=Instance.new('Camera');camera.FieldOfView=36
 camera.CFrame=CFrame.new(0,0,10);camera.Parent=view;view.CurrentCamera=camera
 local world=Instance.new('WorldModel');world.Parent=view
 view.Parent=parent
 return view,world
end

local function cardStock(world,color,stamped)
 local model=Instance.new('Model');model.Name='CardStock';model.WorldPivot=CFrame.new()
 local layers={}
 for index,tint in ipairs({Color3.fromRGB(13,16,31),color:Lerp(Color3.new(1,1,1),.26),color}) do
  local layer={}
  for partIndex=1,6 do
   local shape=partIndex>2 and Enum.PartType.Cylinder or nil
   layer[partIndex]=visualPart(model,Vector3.one,Vector3.zero,tint,shape)
  end
  layers[index]=layer
 end
 local stamps={}
 if stamped then
  for i=1,2 do stamps[i]=visualPart(model,Vector3.one,Vector3.zero,color:Lerp(Color3.new(1,1,1),.4)) end
 end
 model.Parent=world
 return {model=model,layers=layers,stamps=stamps}
end

local function drawStock(stock,width,height,pose)
 local depth=math.min(width,height)*.083
 for i,layer in ipairs(stock.layers) do
  local inset=i==1 and 0 or width*(i==2 and .052 or .070)
  local w,h=width-inset*2,height-inset*2
  local radius=math.min(width,height)*.142-inset*.6
  local z=depth*(i==1 and 0 or i==2 and .54 or .71)
  local thick=depth*(i==1 and 1 or .19)
  layer[1].Size=Vector3.new(w-2*radius,h,thick)
  layer[1].CFrame=pose*CFrame.new(0,0,z)
  layer[2].Size=Vector3.new(w,h-2*radius,thick*.98)
  layer[2].CFrame=pose*CFrame.new(0,0,z)
  for corner=1,4 do
   local x=corner%2==0 and 1 or -1
   local y=corner<=2 and 1 or -1
   local part=layer[corner+2]
   part.Size=Vector3.new(thick*.96,radius*2,radius*2)
   part.CFrame=pose*CFrame.new(x*(w/2-radius),y*(h/2-radius),z)*CFrame.Angles(0,math.pi/2,0)
  end
 end
 for i,part in ipairs(stock.stamps) do
  part.Size=Vector3.new(width*.24,height*.035,depth*.21)
  part.CFrame=pose*CFrame.new(0,(i-1.5)*height*.073,depth*.88)
 end
end

local enamelColors={
 {Color3.fromRGB(194,233,252),Color3.fromRGB(81,147,192),Color3.fromRGB(25,57,96)},
 {Color3.fromRGB(105,246,255),Color3.fromRGB(22,163,246),Color3.fromRGB(18,57,135)},
 {Color3.fromRGB(255,169,255),Color3.fromRGB(188,69,247),Color3.fromRGB(75,27,145)},
 {Color3.fromRGB(255,245,157),Color3.fromRGB(255,177,41),Color3.fromRGB(137,52,11)},
}
local function gradientFor(frame,angle,keys)
 local gradient=Instance.new('UIGradient');gradient.Rotation=angle
 gradient.Color=ColorSequence.new(keys);gradient.Parent=frame;return gradient
end
local function enamelFace(U,parent,tier,accent)
 local white=Color3.new(1,1,1)
 local top,mid,deep=table.unpack(enamelColors[tier])
 local outline=U.frame(parent,UDim2.fromOffset(2,1),UDim2.new(1,-4,1,-7),deep:Lerp(Color3.fromRGB(9,10,23),.82))
 outline.Name='HeavyInkOutline';outline.ZIndex=parent.ZIndex+2;U.corner(outline,21)
 local rim=U.frame(outline,UDim2.fromOffset(6,6),UDim2.new(1,-12,1,-12),white)
 rim.Name='EnamelBevel';U.corner(rim,15)
 local metal=gradientFor(rim,123,{
  ColorSequenceKeypoint.new(0,white),ColorSequenceKeypoint.new(.25,top),ColorSequenceKeypoint.new(.56,mid),
  ColorSequenceKeypoint.new(.81,deep),ColorSequenceKeypoint.new(.96,top),ColorSequenceKeypoint.new(1,mid),
 })
 local face=U.frame(rim,UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8),white)
 face.Name='GlossyEnamel';U.corner(face,11)
 gradientFor(face,90,{
  ColorSequenceKeypoint.new(0,top),ColorSequenceKeypoint.new(.30,mid),ColorSequenceKeypoint.new(.51,mid:Lerp(deep,.28)),
  ColorSequenceKeypoint.new(.80,deep),ColorSequenceKeypoint.new(1,deep:Lerp(Color3.fromRGB(13,15,32),.35)),
 })
 local lights=Instance.new('CanvasGroup');lights.Name='FaceLight';lights.Size=UDim2.fromScale(1,1)
 lights.BackgroundTransparency=1;lights.ZIndex=face.ZIndex+1;lights.Parent=face;U.corner(lights,11)
 local glow=Instance.new('ImageLabel');glow.Name='EnamelGlow';glow.Image='rbxasset://textures/glow.png'
 glow.AnchorPoint=Vector2.new(.5,.5);glow.Position=UDim2.fromScale(.5,.30);glow.Size=UDim2.fromScale(1.35,.81)
 glow.BackgroundTransparency=1;glow.ImageColor3=accent:Lerp(white,.46);glow.ImageTransparency=.35;glow.Parent=lights
 local rays=U.frame(lights,UDim2.fromScale(.5,.29),UDim2.fromScale(.93,.55),mid)
 rays.Name='RarityRays';rays.AnchorPoint=Vector2.new(.5,.5);rays.BackgroundTransparency=1
 for i=1,6 do
  local ray=U.frame(rays,UDim2.fromScale(.5,.5),UDim2.fromScale(1,.15),top:Lerp(white,.62))
  ray.AnchorPoint=Vector2.new(.5,.5);ray.Rotation=i*30;ray.BackgroundTransparency=.63
  local falloff=Instance.new('UIGradient');falloff.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.33,.15),NumberSequenceKeypoint.new(.50,.82),
   NumberSequenceKeypoint.new(.67,.15),NumberSequenceKeypoint.new(1,1),
  });falloff.Parent=ray
 end
 -- A static specular shoulder reads as polished even when motion is reduced.
 local gloss=U.frame(lights,UDim2.fromScale(.03,.015),UDim2.fromScale(.94,.16),white)
 U.corner(gloss,10);gloss.BackgroundTransparency=.46
 local shoulder=Instance.new('UIGradient');shoulder.Rotation=94
 shoulder.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.40,.60),NumberSequenceKeypoint.new(1,1)})
 shoulder.Parent=gloss
 local sweep=U.frame(lights,UDim2.fromScale(-.75,-.25),UDim2.fromScale(.58,1.5),white)
 sweep.Name='GlossSweep';sweep.Rotation=23;sweep.Visible=false
 local gradient=Instance.new('UIGradient')
 gradient.Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.29,1),NumberSequenceKeypoint.new(.47,.82),
  NumberSequenceKeypoint.new(.54,.36),NumberSequenceKeypoint.new(.58,.57),NumberSequenceKeypoint.new(.78,1),NumberSequenceKeypoint.new(1,1),
 });gradient.Parent=sweep
 local glints={}
 for i,position in ipairs({Vector2.new(.13,.09),Vector2.new(.86,.22),Vector2.new(.80,.87)}) do
  local glint=Instance.new('ImageLabel');glint.Name='CornerGlint';glint.Image='rbxasset://textures/particles/sparkles_main.dds'
  glint.BackgroundTransparency=1;glint.ImageColor3=top:Lerp(white,.8);glint.ImageTransparency=1
  glint.AnchorPoint=Vector2.new(.5,.5);glint.Position=UDim2.fromScale(position.X,position.Y)
  glint.Size=UDim2.fromOffset(39-i*5,39-i*5);glint.ZIndex=outline.ZIndex+2;glint.Parent=outline
  glints[i]=glint
 end
 return {glow=glow,rays=rays,sweep=sweep,glints=glints,metal=metal}
end

local function ancestorsVisible(root)
 local ancestor=root
 while ancestor do
  if ancestor:IsA('GuiObject') and not ancestor.Visible then return false end
  if ancestor:IsA('ScreenGui') and not ancestor.Enabled then return false end
  ancestor=ancestor.Parent
 end
 return true
end

function CardView.create(U,parent,choice,index,width,height,options)
 options=options or {};height=math.max(height or CardView.HEIGHT,CardView.MIN_HEIGHT)
 local compact=height<300
 local p=U.palette
 local tier=Packs.rarityTier(choice.rarity)
 local _,_,accent=CardView.identity(choice)
 local bodyColor=enamelColors[tier][2]
 local slot=U.frame(parent,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),p.ink)
 slot.Name='CardChoice'..tostring(index);slot.LayoutOrder=index;slot.BackgroundTransparency=1
 local card=U.frame(slot,UDim2.fromOffset(4,3),UDim2.new(1,-8,1,-6),p.paper)
 card.Name='MountedCard';card.BackgroundTransparency=1;card.Visible=false
 local scale=Instance.new('UIScale');scale.Parent=card
 local shell,shellWorld=cardViewport(card,'CardShell',card.ZIndex+1)
 local stock=cardStock(shellWorld,bodyColor,false)
 local finish=enamelFace(U,card,tier,accent)
 local art=mechanicVisual(card,choice,compact)
 art.Position=UDim2.fromScale(.12,compact and .13 or .10);art.Size=UDim2.fromScale(.76,compact and .24 or .35)
 local badge=U.text(card,UDim2.fromOffset(13,10),UDim2.new(1,-62,0,22),string.upper(choice.rarity or Packs.Tiers[tier]),12,p.white,true)
 badge.Name='RarityBadge';badge.ZIndex=card.ZIndex+6
 badge.TextStrokeColor3=p.ink;badge.TextStrokeTransparency=.18
 local scopeIcon=Instance.new('ImageLabel')
 scopeIcon.Name='CardScope';scopeIcon.Image=CardView.scopeIcon(choice)
 scopeIcon.BackgroundTransparency=1;scopeIcon.Position=UDim2.new(1,-41,0,9);scopeIcon.Size=UDim2.fromOffset(28,28)
 scopeIcon.ScaleType=Enum.ScaleType.Fit;scopeIcon.ZIndex=card.ZIndex+6;scopeIcon.Parent=card
 local function escape(v) return (tostring(v):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')) end
 local display='<b>'..escape(choice.title or 'Run upgrade')..'</b>\n'..escape(CardView.summary(choice))
 local effect=U.text(card,UDim2.new(0,12,compact and .37 or .45,0),UDim2.new(1,-24,compact and .35 or .32,0),display,compact and 16 or 18,p.white,true)
 effect.RichText=true;effect.Name='CardEffect';effect.TextStrokeColor3=p.ink;effect.TextStrokeTransparency=.35;effect.TextXAlignment=Enum.TextXAlignment.Center;effect.ZIndex=card.ZIndex+5
 local terms=U.text(card,UDim2.new(0,12,compact and .72 or .77,0),UDim2.new(1,-24,compact and .24 or .19,0),CardView.terms(choice,options.target,true),15,p.white,false)
 terms.Name='CardTerms';terms.TextStrokeColor3=p.ink;terms.TextStrokeTransparency=.48;terms.TextXAlignment=Enum.TextXAlignment.Center;terms.ZIndex=card.ZIndex+5
 local choose=U.button(card,UDim2.fromScale(0,0),UDim2.fromScale(1,1),'',options.onChoose,p.paper)
 choose.Name='ChooseCard';choose.ZIndex=card.ZIndex+8;U.unskin(choose);choose.TextTransparency=1;choose.BackgroundTransparency=1
 local outline=choose:FindFirstChildOfClass('UIStroke');if outline then outline.Enabled=false end
 local buttonScale=choose:FindFirstChild('ButtonScale');if buttonScale then buttonScale:Destroy() end
 local selection=Instance.new('Frame');selection.Name='SelectionMask';selection.BackgroundTransparency=1;selection.Size=UDim2.fromScale(1,1);selection.Parent=choose
 choose.SelectionImageObject=selection

 local reelParent=options.reelParent or parent:FindFirstAncestorWhichIsA('ScreenGui')
 local reel,reelWorld
 local tiles={}
 local revealSpeed=math.clamp(options.revealSpeed or 1,1,4)
 local revealStart=options.revealStart or os.clock()
 local landed,focused,pressed=false,false,false
 local blend,lastCell=0,-1
 local shellAspect
 local settleAt=Packs.reelFinish(index)
 local focusAt=-10
 local function destroyReel()
  if reel then reel:Destroy();reel=nil;table.clear(tiles) end
 end
 local function spin(offset,stop)
  if not reel then
   local z=reelParent:IsA('GuiObject') and reelParent.ZIndex+4 or 20
   reel,reelWorld=cardViewport(reelParent,'FullHeightCardReel',z)
  end
  local size,origin=reel.AbsoluteSize,reel.AbsolutePosition
  if size.Y<2 or size.X<2 then return end
  reel.Visible=true
  local tall=options.portrait==true
  local position,cardSize=slot.AbsolutePosition-origin,slot.AbsoluteSize
  local targetX,targetY=position.X+cardSize.X*.5,position.Y+cardSize.Y*.5
  local laneX=tall and size.X*(index-.5)/3 or targetX
  local laneY=tall and size.Y*.52 or targetY
  local laneWidth=tall and math.min(cardSize.X-12,size.X*.29) or cardSize.X-12
  local laneHeight=tall and laneWidth*1.38 or cardSize.Y-10
  local spacing=laneHeight*.89+16
  local units=2*10*math.tan(math.rad(18))/size.Y
  local shown={}
  local first=math.max(0,math.floor(offset+(laneY-size.Y-laneHeight)/spacing))
  local last=math.min(stop,math.ceil(offset+(laneY+laneHeight)/spacing))
  for cell=first,last do
   local final=cell==stop
   local approach=final and math.clamp(1-(stop-offset)/1.3,0,1) or 0
   approach=approach*approach*(3-2*approach)
   local centerY=laneY+(offset-cell)*spacing+(targetY-laneY)*approach
   local w=laneWidth+(cardSize.X-12-laneWidth)*approach
   local h=laneHeight+(cardSize.Y-10-laneHeight)*approach
   if centerY+h*.55<0 or centerY-h*.55>size.Y then continue end
   local tile=tiles[cell]
   if not tile then
    local tint=final and bodyColor or enamelColors[(cell+index)%#Packs.Tiers+1][2]
    tile=cardStock(reelWorld,tint,true);tiles[cell]=tile
   end
   shown[cell]=true
   local x=laneX+(targetX-laneX)*approach
   local pose=CFrame.new((x-size.X*.5)*units,(size.Y*.5-centerY)*units,0)
   drawStock(tile,w*units,h*units,pose)
  end
  for cell,tile in pairs(tiles) do
   if not shown[cell] then tile.model:Destroy();tiles[cell]=nil end
  end
 end

 choose.MouseEnter:Connect(function() focused=true;focusAt=os.clock() end)
 choose.MouseLeave:Connect(function() focused=false;pressed=false end)
 choose.SelectionGained:Connect(function() focused=true;focusAt=os.clock() end)
 choose.SelectionLost:Connect(function() focused=false;pressed=false end)
 choose.MouseButton1Down:Connect(function() pressed=true end)
 choose.MouseButton1Up:Connect(function() pressed=false end)
 serial+=1;local stepName=bindPrefix..'Card'..serial
 slot.Destroying:Connect(function()
  RunService:UnbindFromRenderStep(stepName);destroyReel()
 end)
 RunService:BindToRenderStep(stepName,Enum.RenderPriority.Camera.Value+8,function(dt)
  if not ancestorsVisible(slot) then
   if reel then reel.Visible=false end
   return
  end
  local clock=os.clock()
  local age=clock-revealStart
  local quiet=options.reducedMotion==true or CardView.reducedMotion()
  local instant=quiet or options.skipReveal
  local offset,stop,settled,started=Packs.reel(age,index,revealSpeed)
  if instant then settled=true end
  card.Visible=settled
  if not settled then
   if started and reelParent then
    local cell=math.floor(offset)
    if cell~=lastCell and options.onTick then options.onTick() end
    lastCell=cell
    spin(offset,stop)
   end
   return
  end
  destroyReel()
  if not landed and not instant and age*revealSpeed<settleAt+.2 and options.onLand then options.onLand(tier) end
  landed=true
  local _,_,allSettled=Packs.reel(age,3,revealSpeed)
  choose.Visible=instant or allSettled
  local target=choose.Active and focused and 1 or 0
  blend=quiet and 0 or blend+(target-blend)*(1-math.exp(-18*math.min(dt,.1)))
  local settle=instant and 0 or math.clamp(1-(age*revealSpeed-settleAt)/.22,0,1)^2
  local landing=math.max(0,age*revealSpeed-settleAt)
  scale.Scale=1+blend*.038-(pressed and .045 or 0)
   +(instant and 0 or .060*math.sin(landing*23)*math.exp(-landing*12))
  local idleShine=(clock+index*1.73)%7.8
  local shine=math.min(instant and math.huge or landing,clock-focusAt,idleShine)
  finish.rays.Rotation=quiet and 0 or (clock*15+index*32)%360
  finish.glow.ImageTransparency=.33-.17*blend-.13*settle
  finish.metal.Offset=Vector2.new(quiet and 0 or math.sin(clock*1.7+index)*(.05+blend*.14),0)
  finish.sweep.Visible=not quiet and shine>=0 and shine<.73
  if finish.sweep.Visible then finish.sweep.Position=UDim2.fromScale(-.75+shine*2.5,-.25) end
  for i,glint in ipairs(finish.glints) do
   local phase=math.clamp((shine-.067*i)/.48,0,1)
   glint.ImageTransparency=quiet and 1 or 1-math.sin(phase*math.pi)^2*.95
  end
  local aspect=shell.AbsoluteSize.X/math.max(1,shell.AbsoluteSize.Y)
  if shellAspect~=aspect then
   local span=2*10*math.tan(math.rad(18))
   drawStock(stock,span*math.max(.01,aspect)*.978,span*.981,CFrame.new())
   shellAspect=aspect
  end
 end)
 return {root=slot,button=choose}
end

-- This acknowledges the chosen drone after the save commits.
function CardView.revealDrone(U,parent,width,reward,audio,onClose,settled)
 local p=U.palette
 local tint=rarityColor(reward.rewardTier)
 local art=width<270 and 60 or 88
 local textX=art+19
 local textWidth=width-6-textX-10
 local measure=game:GetService('TextService')
 local nameHeight=measure:GetTextSize(reward.rewardName,22,Enum.Font.SourceSansBold,Vector2.new(textWidth,1000)).Y+4
 local jobHeight=measure:GetTextSize(reward.rewardJob,16,Enum.Font.SourceSans,Vector2.new(textWidth,1000)).Y+4
 local count=tonumber(reward.fleetCount)
 local height=math.max(art+16,18+nameHeight+jobHeight)+(count and 33 or 0)
 local view=U.frame(parent,UDim2.fromOffset(3,12),UDim2.fromOffset(width-6,height),p.ink:Lerp(tint,.12))
 view.Name='PrestigeReward';U.corner(view,5);U.stroke(view,tint,1)
 CardView.dronePortrait(view,UDim2.fromOffset(8,8),UDim2.fromOffset(art,art),reward.droneType,tint)
 U.text(view,UDim2.fromOffset(textX,9),UDim2.fromOffset(textWidth,nameHeight),reward.rewardName,22,p.white,true)
 U.text(view,UDim2.fromOffset(textX,9+nameHeight),UDim2.fromOffset(textWidth,jobHeight),reward.rewardJob,16,p.white,false)
 if count then
  local row=U.frame(view,UDim2.new(0,8,1,-32),UDim2.new(1,-16,0,24),p.ink)
  row.BackgroundTransparency=1
  U.text(row,UDim2.fromOffset(2,0),UDim2.new(1,-65,1,0),'Permanent drones',16,p.muted,false)
  local ticker=U.frame(row,UDim2.new(1,-61,0,0),UDim2.fromOffset(60,24),p.ink)
  ticker.ClipsDescendants=true;U.corner(ticker,3)
  local function digit(value,y)
   local text=U.text(ticker,UDim2.fromOffset(0,y),UDim2.fromScale(1,1),tostring(value),18,p.white,true)
   text.TextXAlignment=Enum.TextXAlignment.Center
   return text
  end
  local reduced=settled==true
  pcall(function() reduced=reduced or GuiService.ReducedMotionEnabled end)
  local player=Players.LocalPlayer
  reduced=reduced or (player and (player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true))
  local current=digit(count,reduced and 0 or 24)
  if not reduced then
   local before=digit(count-1,0)
   local tween=game:GetService('TweenService')
   local duration=TweenInfo.new(.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
   tween:Create(before,duration,{Position=UDim2.fromOffset(0,-24)}):Play()
   tween:Create(current,duration,{Position=UDim2.fromOffset(0,0)}):Play()
  end
 end
 U.button(parent,UDim2.new(.5,-74,0,height+24),UDim2.fromOffset(148,42),'Continue',onClose,tint)
 if not settled then audio:play('prestige') end
end
return CardView
