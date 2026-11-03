--!strict

export type AttackStyle = "Bolt" | "Charge" | "Heal" | "Carry" | "Grow" | "Orbital" | "Swarm" | "Special"

export type DroneDefinition = {
	DisplayName: string,
	Description: string,
	Color: Color3,
	Accent: Color3,
	Scale: number,
	MaxHealth: number,
	Speed: number,
	FlightHeight: number,
	AttackStyle: AttackStyle,
	AttackRange: number,
	AttackCooldown: number,
	Damage: number,
	HealAmount: number?,
	ChargeWindup: number?,
	ChargeSpeed: number?,
	Weight: number,
	MiningDuration: number?,
}

local DroneConfig = {}

-- Both the authoritative model and its client view clone use this same ratio.
-- The original mesh, emitter and identity remain intact at worker scale.
DroneConfig.Swarm = {ModelScale=.58}

DroneConfig.Settings = {
	TestSquadMin = 2,
	TestSquadMax = 5,
	FormationSpacing = 5.5,
	MaxCommandDistance = 240,
	CommandCooldown = 0.08,
	RandomizeCooldown = 1.25,
	SimulationStep = 1 / 30,
	TargetRespawnTime = 3,
}

DroneConfig.Order = {
	Follow = "Follow",
	Move = "Move",
	Attack = "Attack",
	Hold = "Hold",
}

DroneConfig.Types = {
	Dart = {
		DisplayName = "Cultivator",
		Description = "Rock grower. Plants replacement crystals in depleted plots. Flies to an empty spot, seeds it, then the rock grows. Does not mine.",
		Color = Color3.fromRGB(131, 220, 151),
		Accent = Color3.fromRGB(224, 253, 255),
		Scale = 0.72,
		MaxHealth = 48,
		Speed = 35,
		FlightHeight = 3.2,
		AttackStyle = "Grow",
		AttackRange = 26,
		AttackCooldown = 0.38,
		Damage = 5,
		Weight = 4,
	},
	Striker = {
		DisplayName = "Striker",
		Description = "Miner. The crew's ordinary continuous mining laser; works above one crystal at a time.",
		Color = Color3.fromRGB(75, 122, 255),
		Accent = Color3.fromRGB(190, 206, 255),
		Scale = 0.9,
		MaxHealth = 78,
		Speed = 24,
		FlightHeight = 3.4,
		AttackStyle = "Bolt",
		AttackRange = 38,
		AttackCooldown = 0.9,
		Damage = 14,
		Weight = 5,
	},
	Medic = {
		DisplayName = "Medic",
		Description = "Tiny support disc. Repairs nearby drones for 10 health every 2 seconds.",
		Color = Color3.fromRGB(76, 255, 149),
		Accent = Color3.fromRGB(225, 255, 235),
		Scale = 0.48,
		MaxHealth = 64,
		Speed = 14.4,
		FlightHeight = 3.8,
		AttackStyle = "Heal",
		AttackRange = 12,
		AttackCooldown = 2,
		Damage = 0,
		HealAmount = 10,
		ChargeWindup = 0.4,
		Weight = 2,
	},
	Courier = {
		DisplayName = "Courier",
		Description = "Backpack emptier. Reserves up to 8 ore, takes its own parcel to orbital storage, then returns for another.",
		Color = Color3.fromRGB(218, 172, 81),
		Accent = Color3.fromRGB(243, 219, 162),
		Scale = 0.75,
		MaxHealth = 58,
		Speed = 24,
		FlightHeight = 3.2,
		AttackStyle = "Carry",
		AttackRange = 0,
		AttackCooldown = 2,
		Damage = 0,
		Weight = 3,
	},
	Charger = {
		DisplayName = "Charger",
		Description = "Breaker. Winds up, dives into a tough rock, impacts once, then recovers. No continuous mining beam.",
		Color = Color3.fromRGB(255, 113, 65),
		Accent = Color3.fromRGB(255, 226, 133),
		Scale = 1.12,
		MaxHealth = 132,
		Speed = 18,
		FlightHeight = 2.8,
		AttackStyle = "Charge",
		AttackRange = 11,
		AttackCooldown = 2.6,
		Damage = 38,
		ChargeWindup = 0.85,
		ChargeSpeed = 72,
		Weight = 2,
	},
	Orbiter = {
		DisplayName = "Orbiter",
		Description = "Orbital controller. Charges and calls a real strike on the biggest rock, then cools down. Does not mine normally.",
		Color = Color3.fromRGB(221, 165, 78),
		Accent = Color3.fromRGB(245, 223, 162),
		Scale = 0.84,
		MaxHealth = 80,
		Speed = 22,
		FlightHeight = 3.6,
		AttackStyle = "Orbital",
		AttackRange = 24,
		AttackCooldown = 0.8,
		Damage = 10,
		Weight = 2,
	},
	Scrapper = {
		DisplayName = "Scrapper",
		Description = "Swarm fabricator. Launches disposable mini miners for ten seconds, then waits to rebuild them. No normal mining beam.",
		Color = Color3.fromRGB(155, 181, 110),
		Accent = Color3.fromRGB(219, 230, 181),
		Scale = 0.82,
		MaxHealth = 84,
		Speed = 21,
		FlightHeight = 3.2,
		AttackStyle = "Swarm",
		AttackRange = 20,
		AttackCooldown = 0.9,
		Damage = 11,
		Weight = 2,
	},
} :: { [string]: DroneDefinition }

DroneConfig.TypeOrder = { "Dart", "Striker", "Medic", "Charger", "Courier", "Orbiter", "Scrapper" }
-- Permanent specialist hardware extends the existing seven jobs. The server
-- completes one reserved rock through each role's distinct timed work cycle.
local specialDefinitions: {[string]: {description: string, color: {number}, duration: number, health: number}} = {
 Bubbler={description='Glass bubbles capture a rock, lift it, then fall and shatter into mineral drops.',color={120,225,255},duration=4.2,health=80},
 Halver={description='Repeatedly stretches and halves a levitating rock, then slowly ring-grinds its pieces into dust.',color={190,140,255},duration=8,health=110},
 Gridcutter={description='Scans an orthogonal laser grid, then nudges the sliced rock into a spill of cubes.',color={255,100,130},duration=5,health=80},
 Singularity={description='An expensive gravity specialist. A tiny black hole draws an entire rock into its event horizon.',color={155,100,255},duration=2.4,health=100},
 Starforge={description='A miniature contained sun heats a rock until it melts into glowing mineral rain.',color={255,170,60},duration=5,health=80},
 Frostbite={description='Flash-freezes a rock in a shell of ice, then shatters it with a sonic shockwave.',color={150,255,245},duration=5.5,health=80},
 Resonator={description='Three resonant rings pulse through a rock until it shakes apart into mineral dust.',color={125,255,160},duration=4.8,health=80},
}
local specialOrder = {'Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}
for _,name in ipairs(specialOrder) do
 local definition=specialDefinitions[name]
 local color=Color3.fromRGB(table.unpack(definition.color))
 DroneConfig.Types[name]={DisplayName=name,Description=definition.description,Color=color,Accent=color:Lerp(Color3.new(1,1,1),.55),Scale=.9,MaxHealth=definition.health,Speed=24,FlightHeight=3.4,AttackStyle='Special',AttackRange=24,AttackCooldown=.9,Damage=name=='Singularity' and 18 or 12,Weight=1,MiningDuration=definition.duration}
 table.insert(DroneConfig.TypeOrder,name)
end

-- The active place retains its original elapsed-time motion and mining equations.
-- These runtime traits preserve the prior Studio role tuning and never enter saved fleets.
DroneConfig.StudioRoles = {
 Dart = {height=3.2,base={miningDPS=30,combatDPS=9,maxHealth=50,maxStep60=.48,warmup=.8,range=20,shotInterval=.42}},
 Striker = {height=3.4,base={miningDPS=30,combatDPS=18,maxHealth=85,maxStep60=.35,warmup=.8,range=24,shotInterval=.8}},
 Medic = {height=3.8,base={miningDPS=30,combatDPS=6,maxHealth=72,maxStep60=.24,warmup=.8,range=12,shotInterval=2}},
 Courier = {height=3.2,base={miningDPS=30,combatDPS=6,maxHealth=58,maxStep60=.40,warmup=.8,range=12,shotInterval=2}},
 Charger = {height=2.8,base={miningDPS=30,combatDPS=14,maxHealth=135,maxStep60=.29,warmup=.8,range=16,shotInterval=2.4}},
 Orbiter = {height=3.6,base={miningDPS=30,combatDPS=12,maxHealth=80,maxStep60=.36,warmup=.8,range=24,shotInterval=.8}},
 Scrapper = {height=3.2,base={miningDPS=30,combatDPS=12,maxHealth=84,maxStep60=.35,warmup=.8,range=20,shotInterval=.9}},
}
for _,name in ipairs(specialOrder) do
 local definition=specialDefinitions[name]
 DroneConfig.StudioRoles[name]={height=3.4,base={miningDPS=30,combatDPS=name=='Singularity' and 20 or 12,maxHealth=definition.health,maxStep60=.38,warmup=.8,range=24,shotInterval=.8}}
end

DroneConfig.Courier = {BatchUnits=8,PickupDistance=4,PickupCooldown=2,PickupHold=.55,LaunchHold=.25,UnloadHold=.65}

-- Purely mechanical silhouettes. The mining drone keeps its authored shell;
-- support roles use a tiny disc or a two-drum box, with no face or character cues.
-- Call after ScaleTo, on either the server model or the local rendered clone.
function DroneConfig.decorate(model: Model, role: string): (Model, BasePart?, BasePart?)
 local body=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart',true)
 local emitter: any=model:FindFirstChild('Emmiter',true)
 if model:GetAttribute('RoleGeometry')==role then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end
 if specialDefinitions[role] then
  local pose=model:GetPivot();local scale=model:GetScale()
  local color=DroneConfig.Types[role].Color
  local dark=Color3.fromRGB(57,64,73)
  local function hardware(name: string,size: Vector3,offset: CFrame,tint: Color3,material: Enum.Material,kind: Enum.PartType?): Part
   local part=Instance.new('Part');part.Name=name;part.Anchored=true
   part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
   part.Material=material;part.MaterialVariant='';part.Color=tint;part.Reflectance=0
   part.Size=size*scale;part.CFrame=pose*CFrame.new(offset.Position*scale)*offset.Rotation
   part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
   if kind then part.Shape=kind end
   part.Parent=model;return part
  end
  if role=='Bubbler' then
   for _,side in ipairs({-1,1}) do
    local glass=hardware('BubbleReservoir',Vector3.one*.7,CFrame.new(side*.86,.12,0),color,Enum.Material.Glass,Enum.PartType.Ball)
    glass.Transparency=.32;glass.Reflectance=.15
    hardware('ReservoirCollar',Vector3.new(.14,.75,.75),CFrame.new(side*.86,-.1,0)*CFrame.Angles(0,0,math.pi/2),dark,Enum.Material.Metal,Enum.PartType.Cylinder)
   end
  elseif role=='Halver' then
   for _,side in ipairs({-1,1}) do
    hardware('SplitterArm',Vector3.new(.22,.22,1.5),CFrame.new(side*.85,-.15,0),dark,Enum.Material.Metal)
    hardware('SplitBlade',Vector3.new(.10,.5,.95),CFrame.new(side*1.0,-.35,0),color,Enum.Material.Metal)
   end
  elseif role=='Gridcutter' then
   for _,side in ipairs({-1,1}) do
    hardware('ScanRail',Vector3.new(.2,.25,1.45),CFrame.new(side*.8,-.1,0),dark,Enum.Material.Metal)
    for i=-1,1 do hardware('GridLens',Vector3.new(.13,.15,.16),CFrame.new(side*.8,-.28,i*.42),color,Enum.Material.Neon) end
   end
  elseif role=='Singularity' then
   hardware('GravityCore',Vector3.one*.55,CFrame.new(0,.65,0),Color3.fromRGB(10,7,20),Enum.Material.Glass,Enum.PartType.Ball)
   for i=1,4 do
    local angle=i*math.pi/2
    hardware('GravityBrace',Vector3.new(.18,.8,.18),CFrame.new(math.cos(angle)*.4,.55,math.sin(angle)*.4),color,Enum.Material.Metal)
   end
  elseif role=='Starforge' then
   hardware('SolarCore',Vector3.one*.55,CFrame.new(0,.65,0),color,Enum.Material.Neon,Enum.PartType.Ball)
   for _,side in ipairs({-1,1}) do
    hardware('SolarShield',Vector3.new(.15,.7,.9),CFrame.new(side*.55,.55,0),dark,Enum.Material.Metal)
    hardware('HeatVent',Vector3.new(.4,.1,.9),CFrame.new(side*.75,-.16,0),color,Enum.Material.Metal)
   end
  elseif role=='Frostbite' then
   for _,side in ipairs({-1,1}) do
    local tank=hardware('CryoTank',Vector3.new(.8,.42,.42),CFrame.new(side*.85,0,0)*CFrame.Angles(0,0,math.pi/2),color,Enum.Material.Glass,Enum.PartType.Cylinder)
    tank.Transparency=.2
    for i=-1,1 do hardware('CoolingFin',Vector3.new(.18,.5,.7),CFrame.new(side*.85,.06,i*.3),dark,Enum.Material.Metal) end
   end
  else
   for i=1,3 do
    hardware('ResonanceHorn',Vector3.new(.18,.75,.75),CFrame.new((i-2)*.65,.4,0)*CFrame.Angles(0,0,math.pi/2),color,Enum.Material.Metal,Enum.PartType.Cylinder)
   end
  end
  model:SetAttribute('RoleGeometry',role);return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
 end
 if role=='Orbiter' or role=='Scrapper' then
  -- Append working hardware to the authored drone; never replace its shell.
  local pose=model:GetPivot();local scale=model:GetScale()
  local function hardware(name: string,size: Vector3,offset: CFrame,color: Color3): Part
   local part=Instance.new('Part');part.Name=name;part.Anchored=true
   part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Material=Enum.Material.Metal
   part.MaterialVariant='';part.Color=color;part.Reflectance=0;part.Size=size*scale
   part.TopSurface=Enum.SurfaceType.Studs;part.BottomSurface=Enum.SurfaceType.Smooth
   part.CFrame=pose*CFrame.new(offset.Position*scale)*offset.Rotation;part.Parent=model;return part
  end
  if role=='Orbiter' then
   hardware('FocusingMast',Vector3.new(.15,.85,.15),CFrame.new(0,.62,0),Color3.fromRGB(90,96,98))
   for i=1,3 do
    local lens=hardware('OrbitalLens'..i,Vector3.new(.12,.8-i*.12,.8-i*.12),CFrame.new(0,.30+i*.23,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(205,171,101))
    lens.Shape=Enum.PartType.Cylinder
   end
  else
   for _,side in ipairs({-1,1}) do
    hardware('MiniDroneBay',Vector3.new(.4,.4,.95),CFrame.new(side*.78,-.26,0),Color3.fromRGB(104,117,85))
    hardware('BayLatch',Vector3.new(.44,.06,.16),CFrame.new(side*.78,-.02,-.25),Color3.fromRGB(174,188,131))
   end
  end
  model:SetAttribute('RoleGeometry',role);return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
 end
 if role=='Dart' or role=='Charger' then
  local pose=model:GetPivot();local scale=model:GetScale()
  for _,side in ipairs({-1,1}) do
   local part=Instance.new('Part');part.Name=role=='Dart' and 'MineralSeeder' or 'ImpactDrum'
   part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
   part.Material=Enum.Material.Metal;part.MaterialVariant='';part.Reflectance=0;part.Color=Color3.fromRGB(72,80,82)
   part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
   part.Size=(role=='Dart' and Vector3.new(.7,.4,.4) or Vector3.new(.7,.8,.8))*scale
   if part:IsA('Part') then part.Shape=Enum.PartType.Cylinder end
   part.CFrame=pose*CFrame.new(side*(role=='Dart' and .85 or 1.1)*scale,-.12*scale,0);part.Parent=model
  end
  model:SetAttribute('RoleGeometry',role);return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
 end
 if role~='Medic' and role~='Courier' then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end
 local pose=model:GetPivot();local scale=model:GetScale()
 -- Keep the captured template intact inside this disposable runtime clone.
 for _,part in ipairs(model:GetDescendants()) do if part:IsA('BasePart') then part.Transparency=1 end end
 local function shape(name: string,size: Vector3,offset: CFrame,color: Color3,material: Enum.Material,kind: Enum.PartType?): Part
  local part=Instance.new('Part');part.Name=name;part.Size=size*scale;part.CFrame=pose*CFrame.new(offset.Position*scale)*offset.Rotation
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=true
  part.Material=material;part.MaterialVariant='';part.Reflectance=0;part.Color=color
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  if kind then part.Shape=kind end
  part.Parent=model;return part
 end
 local slate=Color3.fromRGB(66,76,78)
 if role=='Medic' then
  body=shape('RepairDisc',Vector3.new(.24,1.25,1.25),CFrame.Angles(0,0,math.pi/2),slate,Enum.Material.Metal,Enum.PartType.Cylinder)
  shape('RepairCrossA',Vector3.new(.8,.05,.22),CFrame.new(0,.15,0),Color3.fromRGB(160,204,157),Enum.Material.Plastic)
  shape('RepairCrossB',Vector3.new(.22,.05,.8),CFrame.new(0,.15,0),Color3.fromRGB(160,204,157),Enum.Material.Plastic)
 else
  body=shape('CourierBox',Vector3.new(1.5,.7,1.15),CFrame.new(),Color3.fromRGB(136,120,88),Enum.Material.DiamondPlate)
  body.TopSurface=Enum.SurfaceType.Studs
  for _,side in ipairs({-1,1}) do
   shape('LiftDrum',Vector3.new(.8,.38,.38),CFrame.new(side*.9,0,0)*CFrame.Angles(0,0,math.pi/2),slate,Enum.Material.Metal,Enum.PartType.Cylinder)
  end
  shape('ParcelRail',Vector3.new(1.1,.10,.9),CFrame.new(0,-.42,0),slate,Enum.Material.Metal)
 end
 if not emitter or not emitter:IsA('BasePart') then emitter=shape('Emmiter',Vector3.one*.18,CFrame.new(),Color3.fromRGB(152,206,162),Enum.Material.Plastic) end
 emitter.Size=Vector3.one*.18*scale;emitter.CFrame=pose*CFrame.new(0,(role=='Medic' and -.20 or -.5)*scale,0)
 emitter.Material=Enum.Material.Plastic;emitter.Color=role=='Medic' and Color3.fromRGB(152,206,162) or Color3.fromRGB(221,187,108)
 emitter.Reflectance=0;emitter.Transparency=0
 local root=shape('SupportRoot',Vector3.one*.1,CFrame.new(),slate,Enum.Material.Plastic)
 root.Transparency=1;root.CastShadow=false;model.PrimaryPart=root;model:SetAttribute('RoleGeometry',role)
 return model,root,emitter
end

-- Optional discoveries reward active collection without interrupting autonomous mining.
DroneConfig.Discoveries = {
 Chance = .18,
 MinSpawnInterval = 22,
 PickupLifetime = 10,
 BoostDuration = 10,
 CollectDistance = 7,
 MinSpawnDistance = 14,
 MaxSpawnDistance = 65,
 YieldMultiplier = 2,
 SpeedMultiplier = 2,
}

-- Active mining plots: preserve crystal geometry while scaling durability by tier.
DroneConfig.Mining = {
 BackpackRange = 70,
 -- Health/work is authored in Config.Fields.Hardness and Mining.resource.
 -- This table owns only the live crew-responsive respawn tuning.
 RespawnRateBase = 1.10,
 RespawnRatePerDrone = .025,
 RespawnRateMaximum = 1.50,
}

return table.freeze(DroneConfig)

