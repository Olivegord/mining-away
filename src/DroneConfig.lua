--!strict

export type AttackStyle = "Bolt" | "Charge" | "Heal" | "Carry"

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
		DisplayName = "Dart",
		Description = "Very fast skirmisher with low durability.",
		Color = Color3.fromRGB(45, 224, 255),
		Accent = Color3.fromRGB(224, 253, 255),
		Scale = 0.72,
		MaxHealth = 48,
		Speed = 35,
		FlightHeight = 3.2,
		AttackStyle = "Bolt",
		AttackRange = 26,
		AttackCooldown = 0.38,
		Damage = 5,
		Weight = 4,
	},
	Striker = {
		DisplayName = "Striker",
		Description = "Reliable mid-range damage and medium speed.",
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
		Description = "Takes 8 ore from your backpack to the depot and sells it.",
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
		Description = "Low-flying bruiser with a telegraphed impact dash.",
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
		Description = "Survey drone with an orbital focusing mast. Unlocks the timed orbital gadget.",
		Color = Color3.fromRGB(221, 165, 78),
		Accent = Color3.fromRGB(245, 223, 162),
		Scale = 0.84,
		MaxHealth = 80,
		Speed = 22,
		FlightHeight = 3.6,
		AttackStyle = "Bolt",
		AttackRange = 24,
		AttackCooldown = 0.8,
		Damage = 10,
		Weight = 2,
	},
	Scrapper = {
		DisplayName = "Scrapper",
		Description = "Workshop drone carrying disposable mini-drone bays. Unlocks the 10-second scrap swarm.",
		Color = Color3.fromRGB(155, 181, 110),
		Accent = Color3.fromRGB(219, 230, 181),
		Scale = 0.82,
		MaxHealth = 84,
		Speed = 21,
		FlightHeight = 3.2,
		AttackStyle = "Bolt",
		AttackRange = 20,
		AttackCooldown = 0.9,
		Damage = 11,
		Weight = 2,
	},
} :: { [string]: DroneDefinition }

DroneConfig.TypeOrder = { "Dart", "Striker", "Medic", "Charger", "Courier", "Orbiter", "Scrapper" }

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

DroneConfig.Courier = {BatchUnits=8,PickupDistance=4,PickupCooldown=2,PickupHold=.55,LaunchHold=.25,UnloadHold=.65}

-- Purely mechanical silhouettes. The mining drone keeps its authored shell;
-- support roles use a tiny disc or a two-drum box, with no face or character cues.
-- Call after ScaleTo, on either the server model or the local rendered clone.
function DroneConfig.decorate(model: Model, role: string): (Model, BasePart?, BasePart?)
 local body=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart',true)
 local emitter: any=model:FindFirstChild('Emmiter',true)
 if model:GetAttribute('RoleGeometry')==role then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end
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
   local part=Instance.new(role=='Dart' and 'WedgePart' or 'Part');part.Name=role=='Dart' and 'ScoutRail' or 'ImpactDrum'
   part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
   part.Material=Enum.Material.Metal;part.MaterialVariant='';part.Reflectance=0;part.Color=Color3.fromRGB(72,80,82)
   part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
   part.Size=(role=='Dart' and Vector3.new(.22,.35,1.8) or Vector3.new(.7,.8,.8))*scale
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

