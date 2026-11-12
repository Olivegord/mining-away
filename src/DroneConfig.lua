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

-- Reference size for the original non-miner world rigs and previews.
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
		DisplayName = "Orbital",
		Description = "Charges a sky laser that melts the biggest available crystal and damages a second nearby rock.",
		Color = Color3.fromRGB(172, 115, 231),
		Accent = Color3.fromRGB(228, 207, 255),
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
-- removes a bounded chunk through each role's distinct timed work cycle.
local specialDefinitions: {[string]: {description: string, color: {number}, duration: number, health: number}} = {
 Bubbler={description='Pressure vessels pull loose chips into a buoyant bubble, then pop it. Repeats until the rock breaks.',color={120,225,255},duration=2.8,health=80},
 Halver={description='Wide articulated jaws shear off a seam and ring-grind its chips. Hard rocks need repeated cuts.',color={190,140,255},duration=3.6,health=110},
 Gridcutter={description='A rectangular scanning gantry scores and ejects one layer of mineral cubes per pass.',color={255,100,130},duration=2.5,health=80},
 Singularity={description='A tilted containment ring feeds a small gravity well that strips a bounded chunk per pulse.',color={155,100,255},duration=2,health=100},
 Starforge={description='A tall furnace focuses solar heat into a seam, releasing a short stream of molten chips.',color={255,170,60},duration=3,health=80},
 Frostbite={description='Long cryogenic tanks freeze a surface layer, then a sharp pressure pulse cracks it away.',color={150,255,245},duration=2.4,health=80},
 Resonator={description='Three tuning forks build a coherent vibration, then snap off one resonant mineral chunk.',color={125,255,160},duration=2.6,health=80},
}
local specialOrder = {'Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}
for _,name in ipairs(specialOrder) do
 local definition=specialDefinitions[name]
 local color=Color3.fromRGB(table.unpack(definition.color))
 DroneConfig.Types[name]={DisplayName=name,Description=definition.description,Color=color,Accent=color:Lerp(Color3.new(1,1,1),.55),Scale=.9,MaxHealth=definition.health,Speed=24,FlightHeight=3.4,AttackStyle='Special',AttackRange=24,AttackCooldown=.9,Damage=name=='Singularity' and 18 or 12,Weight=1,MiningDuration=definition.duration}
 table.insert(DroneConfig.TypeOrder,name)
end
local fieldTestRoles={
 Ramiel={label='Ramiel',color=Color3.fromRGB(93,203,255),detail='Locks into a five-pointed glass star and fires one red beam.'},
 Needler={label='Needler',color=Color3.fromRGB(255,195,94),detail='Fires quick darts. Hits exposed deep cores 25% harder.'},
 Ballcaster={label='Ballcaster',color=Color3.fromRGB(150,124,255),detail='Deals 50% more damage through the first two layers of deep crystals.'},
 Vacuum={label='Vacuum',color=Color3.fromRGB(95,226,184),detail='Flies to loose ore, pulls it in and sends it to your backpack.'},
 Compactor={label='Compactor',color=Color3.fromRGB(255,184,83),detail='Presses loose rocks into one block worth the sum of its inputs.'},
}
for name,role in pairs(fieldTestRoles) do
 DroneConfig.Types[name]={DisplayName=role.label,Description=role.detail,Color=role.color,Accent=role.color:Lerp(Color3.new(1,1,1),.5),Scale=.9,MaxHealth=80,Speed=26,FlightHeight=3.2,AttackStyle='Special',AttackRange=20,AttackCooldown=1,Damage=12,Weight=1}
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
for name in pairs(fieldTestRoles) do
 DroneConfig.StudioRoles[name]={height=3.2,base={miningDPS=30,combatDPS=12,maxHealth=80,maxStep60=.43,warmup=.065,range=20,shotInterval=1}}
end

DroneConfig.Courier = {BatchUnits=8,PickupDistance=4,PickupCooldown=2,PickupHold=.55,LaunchHold=.25,UnloadHold=.65}
DroneConfig.PressSockets = {Vector3.new(0,-1.05,.96),Vector3.new(-1.02,-1.05,.27),Vector3.new(1.02,-1.05,.27),Vector3.new(-.58,-1.05,-.86),Vector3.new(.58,-1.05,-.86)}

-- Quarry machines share painted stone-gray panels and worn metal at working
-- surfaces. The old Mesh, weld and emitter stay in every clone as the rig.
-- This only builds the visible hull; flight, reach and articulation are unchanged.
-- A native solid pyramid supplies Ramiel's rigid glass forms. The same
-- octahedral silhouette can be drawn with triangles if that solid is absent.
local function ramielWedges(a: Vector3,b: Vector3,c: Vector3,left: BasePart,right: BasePart)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then a,c=c,a
 elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local normal=ac:Cross(ab).Unit
 local depth=bc.Unit
 local up=bc:Cross(normal).Unit
 local height=math.abs(ab:Dot(up));local thickness=.045
 left.Size=Vector3.new(thickness,height,math.max(.02,math.abs(ab:Dot(depth))))
 left.CFrame=CFrame.fromMatrix((a+b)*.5,normal,up,depth)
 right.Size=Vector3.new(thickness,height,math.max(.02,math.abs(ac:Dot(depth))))
 right.CFrame=CFrame.fromMatrix((a+c)*.5,-normal,up,-depth)
end
local RAMIEL_GLASS=Color3.fromRGB(44,126,235)
local RAMIEL_RED=Color3.fromRGB(255,37,59)
function DroneConfig.ramielRig(model: Model)
 local folder=model:FindFirstChild('RamielGlass');if not folder then return nil end
 local rig={faces={},solids={},core=folder:FindFirstChild('Core') :: BasePart,scale=model:GetScale()}
 for _,part in ipairs(folder:GetChildren()) do
  if part:IsA('BasePart') then rig.solids[part.Name]=part end
 end
 for i=1,8 do
  local left=rig.solids['Pane'..i..'A'];local right=rig.solids['Pane'..i..'B']
  if left and right then rig.faces[i]={left,right} end
 end
 return rig
end
-- Main Yashima shot, blocked for the gameplay camera. The facets first pull
-- in, then sweep past the locked silhouette. The aperture catches up and
-- keeps gathering light after the large glass shapes have settled.
local RAMIEL_POSE={
 -- phase, reach, outer roll, fold, aperture roll, aperture reach, energy
 {0,    0,     0,  71,   0,   0,    0},
 {.12,  0,   -23,  72,  -9,   0,    .025},
 {.22, .13,  -27,  63,   3,  .12,   .07},
 {.37, .69,   27,  29,  31,  .40,   .13},
 {.47, .54,   21,  44,  58,  .53,   .16},
 {.60,1.08,   71,   9, 113,  .83,   .24},
 {.69,1.00,   75,   0, 151, 1.06,   .33},
 {.79,1.00,   72,   0, 147, 1.00,   .47},
 {.89,1.00,   72,   0, 148, 1.01,   .73},
 {.95, .975,  72,   4, 149,  .94,   .92},
 {1,   1.00,  72,   0, 150, 1.00,  1.00},
}
local function smoothstep(t: number): number
 t=math.clamp(t,0,1);return t*t*(3-2*t)
end
local function ramielSlope(left: number,right: number): number
 if left*right<=0 then return 0 end
 return 2*left*right/(left+right)
end
local function ramielTrack(index: number,t: number,channel: number): number
 local a,b=RAMIEL_POSE[index],RAMIEL_POSE[index+1]
 local span=b[1]-a[1]
 local delta=(b[channel]-a[channel])/span
 local before,after=RAMIEL_POSE[index-1],RAMIEL_POSE[index+2]
 local start=before and ramielSlope((a[channel]-before[channel])/(a[1]-before[1]),delta)*span or 0
 local finish=after and ramielSlope(delta,(after[channel]-b[channel])/(after[1]-b[1]))*span or 0
 local t2=t*t;local t3=t2*t
 return math.clamp((2*t3-3*t2+1)*a[channel]+(t3-2*t2+t)*start
  +(-2*t3+3*t2)*b[channel]+(t3-t2)*finish,math.min(a[channel],b[channel]),math.max(a[channel],b[channel]))
end
local function pyramid(part: BasePart,frame: CFrame,axis: Vector3,base: Vector3,height: number,width: number,visibility: number,roll: number)
 local center=frame:PointToWorldSpace(base+axis*(height*.5))
 local up=frame:VectorToWorldSpace(axis)
 local right=frame.LookVector:Cross(up).Unit
 part.Size=Vector3.new(width,height,width)
 part.CFrame=CFrame.fromMatrix(center,right,up,right:Cross(up))*CFrame.Angles(0,roll,0)
 part.Transparency=1-.86*visibility
end
DroneConfig.RamielRecovery=.69
function DroneConfig.poseRamiel(rig: any,pivot: CFrame,aim: Vector3?,charge: number,recovery: number?,roll: number,reduced: boolean?): number
 local time=math.clamp(charge,0,1)
 local index=1
 while index<#RAMIEL_POSE-1 and time>RAMIEL_POSE[index+1][1] do index+=1 end
 local t=(time-RAMIEL_POSE[index][1])/(RAMIEL_POSE[index+1][1]-RAMIEL_POSE[index][1])
 local reach,outerRoll,fold,frontRoll,frontReach,energy=ramielTrack(index,t,2),ramielTrack(index,t,3),ramielTrack(index,t,4),
  ramielTrack(index,t,5),ramielTrack(index,t,6),ramielTrack(index,t,7)
 local closing=recovery and smoothstep((recovery-.29)/(DroneConfig.RamielRecovery-.29)) or 0
 local gather=smoothstep(time/.19)*(1-.68*smoothstep((time-.18)/.48))
 local recoil=0
 if recovery then
  local follow=smoothstep(recovery/.073)*(1-smoothstep((recovery-.073)/.33))
  reach=(1+.072*follow)*(1-closing);frontReach=1-closing
  fold=closing*62;outerRoll=72+5*follow-21*closing;frontRoll=150+34*closing
  energy=1-smoothstep((recovery-.045)/.32)
  gather=.32*(1-closing);recoil=follow
 end
 local reveal=smoothstep((time-.15)/.39)*(1-closing)
 if reduced then
  reach=reveal;outerRoll=72;fold=0;frontRoll=150;frontReach=reveal;energy*=.38
  gather=0;recoil=0
 end
 local frame=pivot*CFrame.Angles(0,roll,0)
 if aim and (aim-pivot.Position).Magnitude>.01 then
  local forward=(aim-pivot.Position).Unit
  local up=math.abs(forward.Y)>.94 and Vector3.zAxis or Vector3.yAxis
  local lock=smoothstep(time/.48)*(1-closing)
  frame=frame:Lerp(CFrame.lookAt(pivot.Position,aim,up),lock)
  local squeeze=smoothstep(time/.18)*(1-smoothstep((time-.20)/.31))*(recovery and 0 or 1)
  frame*=CFrame.new(0,.16*gather,.45*gather+.28*recoil)*CFrame.Angles(-squeeze*.14,0,math.rad(-20)*squeeze)
 end
 local radius=rig.scale*1.35
 local solids=rig.solids
 if solids.Upper then
  local size=radius*(1-.18*gather-.58*reveal)
  pyramid(solids.Upper,frame,Vector3.yAxis,Vector3.zero,size,size*1.43,1-reveal,math.pi*.25)
  pyramid(solids.Lower,frame,-Vector3.yAxis,Vector3.zero,size,size*1.43,1-reveal,math.pi*.25)
  for i=1,5 do
   local angle=math.pi*.5+(i-.5)*math.pi*2/5+math.rad(outerRoll-72)
   local drag=math.sin(i*2.4)*math.min(13,fold*.37)
   local hinge=math.rad(fold+drag)
   local axis=Vector3.new(math.cos(angle)*math.cos(hinge),math.sin(angle)*math.cos(hinge),math.sin(hinge))
   local root=Vector3.new(math.cos(angle),math.sin(angle),0)*radius*(.10+.18*reach)
   local length=radius*(.50+(i==3 and .84 or 1.40)*reach)
   local ray=solids['Star'..i]
   local fan=smoothstep((time-.17-(i-1)*.014)/.34)*(1-closing)
   pyramid(ray,frame,axis,root,length,radius*(.38+.55*reach),reduced and reveal or fan,.30+math.rad(fold)*.66)
   local blue=RAMIEL_GLASS:Lerp(Color3.fromRGB(18,39,135),i%2==0 and .54 or .28)
   ray.Color=blue:Lerp(Color3.fromRGB(249,177,240),energy^1.6*.70)
   local front=solids['Aperture'..i]
   if front then
    local turn=math.pi*.5+(i-.5)*math.pi*2/5+math.rad(frontRoll)
    local inner=Vector3.new(math.cos(turn),math.sin(turn),-.08).Unit
    pyramid(front,frame,inner,Vector3.new(0,0,-.31*radius),radius*(.14+.59*frontReach),
     radius*(.12+.33*frontReach),reveal*smoothstep((time-.27)/.34),.58)
    front.Color=Color3.fromRGB(147,201,255):Lerp(Color3.fromRGB(255,224,241),energy*.88)
   end
  end
 else
  for i,panes in ipairs(rig.faces) do
   local sign=i<=4 and 1 or -1
   local angle=(i-1)%4*math.pi*.5
   local size=radius*(1-reveal*.28)
   local a=Vector3.new(math.cos(angle),0,math.sin(angle))*size
   local b=Vector3.new(math.cos(angle+math.pi*.5),0,math.sin(angle+math.pi*.5))*size
   local c=Vector3.yAxis*sign*size
   ramielWedges(frame:PointToWorldSpace(c),frame:PointToWorldSpace(a),frame:PointToWorldSpace(b),panes[1],panes[2])
  end
 end
 rig.core.CFrame=frame*CFrame.new(0,0,-(.17+.23*reveal)*radius)
 rig.core.Size=Vector3.one*radius*(.17+.64*energy^1.55)
 rig.core.Transparency=1-math.max(reveal,smoothstep((time-.13)/.24)*.66*(1-closing))*(.76+.24*energy)
 rig.core.Color=RAMIEL_RED:Lerp(Color3.fromRGB(255,215,229),energy^1.6*.93)
 local light=rig.core:FindFirstChild('ApertureLight')
 if light and light:IsA('PointLight') then
  light.Enabled=energy>.15
  light.Brightness=3.8*energy^1.6
 end
 return energy
end

-- Fit the visible idle hull. Hidden mining mounts and opened effect poses
-- must not set the size of an otherwise small drone.
function DroneConfig.fitBody(model: Model)
 local pivot=model:GetPivot()
 local originalScale=model:GetScale()
 local low=Vector3.one*math.huge;local high=-low
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA('BasePart') and part.Transparency<.95 then
   local frame=pivot:ToObjectSpace(part.CFrame)
   local extent=part.Size*.5
   local r,u,f=frame.RightVector,frame.UpVector,frame.LookVector
   local half=Vector3.new(
    math.abs(r.X)*extent.X+math.abs(u.X)*extent.Y+math.abs(f.X)*extent.Z,
    math.abs(r.Y)*extent.X+math.abs(u.Y)*extent.Y+math.abs(f.Y)*extent.Z,
    math.abs(r.Z)*extent.X+math.abs(u.Z)*extent.Y+math.abs(f.Z)*extent.Z)
   low=low:Min(frame.Position-half);high=high:Max(frame.Position+half)
  end
 end
 local size=high-low
 local span=math.max(size.X,size.Y,size.Z)
 if span<=.01 then return end
 model:ScaleTo(originalScale*2.65/span)
 if model:GetAttribute('RoleGeometry')=='Compactor' then
  -- The authoritative ore flight still ends at the original input sockets.
  for i,position in ipairs(DroneConfig.PressSockets) do
   local socket=model:FindFirstChild('PressSocket'..i)
   if socket and socket:IsA('BasePart') then
    socket.CFrame=pivot*CFrame.new(position*(originalScale*DroneConfig.Swarm.ModelScale)-Vector3.yAxis*(.28*model:GetScale()))
     *CFrame.Angles(0,0,math.pi/2)
   end
  end
 end
end

function DroneConfig.decorate(model: Model, role: string, finishColor: Color3?, readable: boolean?): (Model, BasePart?, BasePart?)
 local body=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart',true)
 local emitter: any=model:FindFirstChild('Emmiter',true)
 if model:GetAttribute('RoleGeometry')==role then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end
 local def=DroneConfig.Types[role]
 if not body or not def then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end

 local pose,scale=model:GetPivot(),model:GetScale()
 local color=finishColor or def.Color
 local dark=readable and Color3.fromRGB(37,47,63) or Color3.fromRGB(67,76,84)
 local pale=readable and Color3.fromRGB(240,239,225) or Color3.fromRGB(211,219,219)
 local painted=readable and color:Lerp(pale,.23) or Color3.fromRGB(199,203,205):Lerp(color,.55)
 local metal=Enum.Material.Metal
 local slate=Enum.Material.Slate
 local smooth=Enum.Material.SmoothPlastic
 local cylinder=Enum.PartType.Cylinder
 local vertical=CFrame.Angles(0,0,math.pi/2)
 local foreAft=CFrame.Angles(0,math.pi/2,0)
 body.Transparency=1;body.CastShadow=false
 if emitter and emitter:IsA('BasePart') then emitter.Transparency=1;emitter.CastShadow=false end

 local function hardware(name: string,size: Vector3,offset: CFrame,tint: Color3,material: Enum.Material,kind: Enum.PartType?,motion: string?,side: number?,wedge: boolean?): BasePart
  local part: BasePart=if wedge then Instance.new('WedgePart') else Instance.new('Part')
  part.Name=name;part.Anchored=true
  part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  part.Material=material;part.Color=tint;part.Reflectance=0
  if readable and (material==metal or material==slate) then
   part.Material=smooth
  elseif material==metal then
   part.Material=Enum.Material.CorrodedMetal;part.MaterialVariant='QuarryDrone_Ribbed'
  elseif material==slate then
   part.MaterialVariant='QuarryDrone_Painted'
  end
  part.Size=size*scale;part.CFrame=pose*CFrame.new(offset.Position*scale)*offset.Rotation
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  if kind and part:IsA('Part') then part.Shape=kind end
  if motion then part:SetAttribute('SpecialMotion',motion);part:SetAttribute('MotionSide',side or 1) end
  part.Parent=model;return part
 end
 local function pod(name: string,diameter: number,height: number,y: number,tint: Color3,material: Enum.Material)
  return hardware(name,Vector3.new(height,diameter,diameter),CFrame.new(0,y,0)*vertical,tint,material,cylinder)
 end
 local function lens(name: string,point: Vector3,tint: Color3,radius: number)
  return hardware(name,Vector3.new(.12,radius,radius),CFrame.new(point)*vertical,tint,Enum.Material.Neon,cylinder)
 end
 local function shotMuzzle(part: BasePart,position: Vector3)
  if not readable then return end
  local mount=Instance.new('Attachment');mount.Name='ShotMuzzle';mount.Position=position;mount.Parent=part
 end

 if specialDefinitions[role] then
  -- Working assemblies retain their original joints and travel. Each now gets
  -- a small chassis suited to its tool instead of the common square behind it.
  if role=='Bubbler' then
   pod('PressureManifold',1.48,.50,-.06,painted,slate)
   pod('ManifoldSeal',1.30,.14,-.33,dark,metal)
  elseif role=='Halver' then
   hardware('ShearCounterweight',Vector3.new(.68,.62,1.95),CFrame.new(0,.16,.46),painted,slate,cylinder)
   hardware('JawPump',Vector3.new(.56,.42,1.02),CFrame.new(0,.33,.58),dark,metal)
  elseif role=='Gridcutter' then
   hardware('RaisedBridge',Vector3.new(2.28,.33,.62),CFrame.new(0,.34,.43),painted,slate)
   hardware('RelayCap',Vector3.new(.44,.78,.78),CFrame.new(0,.39,.39)*vertical,dark,metal,cylinder)
  elseif role=='Singularity' then
   pod('FieldSpindle',1.52,.36,-.14,painted,slate)
   pod('SpindleClamp',1.12,.15,-.35,dark,metal)
  elseif role=='Starforge' then
   pod('ForgeBelly',1.65,.44,-.15,painted,slate)
   pod('InsulatedGasket',1.41,.16,-.42,dark,metal)
  elseif role=='Frostbite' then
   hardware('CryoKeel',Vector3.new(.85,.46,2.10),CFrame.new(0,.03,.02),painted,slate,nil,nil,nil,true)
   hardware('ColdPlate',Vector3.new(.62,.15,1.58),CFrame.new(0,-.20,.11),pale,metal)
  else
   hardware('ResonatorKeel',Vector3.new(2.45,.35,.75),CFrame.new(0,-.04,0),painted,slate,cylinder)
   hardware('DampingPlate',Vector3.new(1.92,.16,.57),CFrame.new(0,-.24,0),dark,metal)
  end
  if role=='Bubbler' then
   -- Two large pressure bulbs and their open roll cage read as rounded tanks,
   -- rather than another recolored copy of the small authored chassis.
   for _,side in ipairs({-1,1}) do
    local glass=hardware('PressureBulb',Vector3.one*1.2,CFrame.new(side*1.2,.38,0),color,Enum.Material.Glass,Enum.PartType.Ball,'Bulb',side)
    glass.Transparency=.28;glass.Reflectance=.12
    hardware('BulbFoot',Vector3.new(.18,1.05,1.05),CFrame.new(side*1.2,-.15,0)*CFrame.Angles(0,0,math.pi/2),dark,metal,Enum.PartType.Cylinder,'Bulb',side)
    hardware('PressureNeck',Vector3.new(.18,.38,.18),CFrame.new(side*1.2,1.07,0),pale,metal,nil,'Valve',side)
    hardware('ValveHandle',Vector3.new(.48,.10,.13),CFrame.new(side*1.2,1.28,0),dark,metal,nil,'Valve',side)
   end
   hardware('PressureBridge',Vector3.new(2.4,.15,.22),CFrame.new(0,.9,.55),dark,metal)
   hardware('BubbleNozzle',Vector3.new(.55,.44,.44),CFrame.new(0,-.65,-.45)*CFrame.Angles(0,0,math.pi/2),pale,metal,Enum.PartType.Cylinder,'Nozzle')
  elseif role=='Halver' then
   -- Wide cantilevered jaws have a heavy, open tool silhouette even at rest.
   for _,side in ipairs({-1,1}) do
    hardware('JawHinge',Vector3.new(.3,.55,.55),CFrame.new(side*.95,.12,.45)*CFrame.Angles(0,0,math.pi/2),pale,metal,Enum.PartType.Cylinder,'Jaw',side)
    hardware('Cantilever',Vector3.new(.38,.28,1.9),CFrame.new(side*1.4,-.08,-.25)*CFrame.Angles(0,side*.18,0),dark,metal,nil,'Jaw',side)
    hardware('ShearBlade',Vector3.new(.16,.8,1.15),CFrame.new(side*1.7,-.45,-.75)*CFrame.Angles(0,0,-side*.14),color,metal,nil,'Jaw',side)
    hardware('BladeEdge',Vector3.new(.08,.7,.95),CFrame.new(side*1.6,-.5,-.83),pale,metal,nil,'Jaw',side)
   end
   hardware('JawCrossbrace',Vector3.new(2.6,.22,.3),CFrame.new(0,.12,.65),dark,metal)
  elseif role=='Gridcutter' then
   -- The square perimeter remains readable without any active laser effect.
   for _,side in ipairs({-1,1}) do
    hardware('GantryRail',Vector3.new(.18,.28,2.5),CFrame.new(side*1.25,-.32,0),dark,metal)
    hardware('GantryEnd',Vector3.new(2.65,.24,.18),CFrame.new(0,-.32,side*1.25),pale,metal)
    hardware('RailMount',Vector3.new(.18,.5,.22),CFrame.new(side*1.25,-.02,0),dark,metal)
   end
   hardware('ScanCarriage',Vector3.new(2.35,.2,.28),CFrame.new(0,-.55,0),color,metal,nil,'Scanner')
   for i=-2,2 do hardware('GridLens',Vector3.new(.12,.12,.13),CFrame.new(i*.43,-.72,0),color,Enum.Material.Neon,nil,'Scanner') end
  elseif role=='Singularity' then
   local ring=CFrame.new(0,.85,0)*CFrame.Angles(.75,0,.25)
   for i=1,12 do
    local angle=(i-.5)*math.pi/6
    hardware('ContainmentSegment',Vector3.new(.18,.18,.69),ring*CFrame.new(math.cos(angle)*1.3,0,math.sin(angle)*1.3)*CFrame.Angles(0,-angle,0),i%3==0 and color or dark,metal,nil,'Containment')
   end
   hardware('GravityCore',Vector3.one*.68,CFrame.new(0,.85,0),Color3.fromRGB(10,7,20),Enum.Material.Glass,Enum.PartType.Ball,'GravityCore')
   for _,side in ipairs({-1,1}) do hardware('RingYoke',Vector3.new(.18,.8,.25),CFrame.new(side*.8,.28,.6),pale,metal) end
  elseif role=='Starforge' then
   -- A vertical furnace, chimney and radial cooling plates contrast the wide tools.
   hardware('Furnace',Vector3.new(1.45,.82,.82),CFrame.new(0,.95,0)*CFrame.Angles(0,0,math.pi/2),dark,metal,Enum.PartType.Cylinder)
   hardware('SolarCore',Vector3.one*.64,CFrame.new(0,1.72,0),color,Enum.Material.Neon,Enum.PartType.Ball,'FurnaceCore')
   hardware('ChimneyCap',Vector3.new(.16,1.05,1.05),CFrame.new(0,2.06,0)*CFrame.Angles(0,0,math.pi/2),pale,metal,Enum.PartType.Cylinder,'FurnaceCap')
   for i=1,4 do
    local angle=i*math.pi/2
    hardware('RadiatorFin',Vector3.new(.15,1.15,.78),CFrame.new(math.cos(angle)*.66,.87,math.sin(angle)*.66)*CFrame.Angles(0,-angle,0),color,metal,nil,'HeatFin',i)
   end
   hardware('SlagNozzle',Vector3.new(.4,.55,.4),CFrame.new(0,-.65,0),pale,metal,nil,'Nozzle')
  elseif role=='Frostbite' then
   -- Long cold tanks, rear caps and forward needle nozzles read as a low sled.
   for _,side in ipairs({-1,1}) do
    local tank=hardware('CryoTank',Vector3.new(2.65,.58,.58),CFrame.new(side*1.12,.05,0)*CFrame.Angles(0,math.pi/2,0),color,Enum.Material.Glass,Enum.PartType.Cylinder,'CryoTank',side)
    tank.Transparency=.18
    for _,endSide in ipairs({-1,1}) do hardware('TankCap',Vector3.new(.14,.66,.66),CFrame.new(side*1.12,.05,endSide*1.31)*CFrame.Angles(0,math.pi/2,0),pale,metal,Enum.PartType.Cylinder,'CryoTank',side) end
    hardware('CryoNeedle',Vector3.new(.18,.18,.75),CFrame.new(side*1.12,-.1,-1.7),dark,metal,nil,'CryoNozzle',side)
    for z=-1,1 do hardware('CoolingFin',Vector3.new(.75,.12,.14),CFrame.new(side*1.12,.46,z*.73),dark,metal) end
   end
  else
   -- Three actual U-shaped tuning forks: a tall, thin comb in silhouette.
   for i=-1,1 do
    local height=i==0 and 1.9 or 1.35
    hardware('ForkStem',Vector3.new(.14,.55,.18),CFrame.new(i*.94,.54,0),dark,metal,nil,'Fork',i)
    hardware('ForkHeel',Vector3.new(.58,.15,.2),CFrame.new(i*.94,.87,0),pale,metal,nil,'Fork',i)
    for _,side in ipairs({-1,1}) do hardware('TuningProng',Vector3.new(.12,height,.2),CFrame.new(i*.94+side*.23,.87+height*.5,0),color,metal,nil,'Prong',i*3+side) end
   end
  end
  model:SetAttribute('RoleGeometry',role);return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
 end
 if role=='Ramiel' then
  local glass=Instance.new('Folder');glass.Name='RamielGlass';glass.Parent=model
  local net=game:GetService('ReplicatedStorage'):FindFirstChild('MiningAway')
  local template=net and net:FindFirstChild('RamielPyramid')
  if template and template:IsA('BasePart') then
   for i,name in ipairs({'Upper','Lower','Star1','Star2','Star3','Star4','Star5',
    'Aperture1','Aperture2','Aperture3','Aperture4','Aperture5'}) do
    local solid=template:Clone();solid.Name=name
    solid.Anchored=true;solid.CanCollide=false;solid.CanTouch=false;solid.CanQuery=false;solid.CastShadow=false
    solid.Material=Enum.Material.Glass;solid.Reflectance=.16
    solid.Color=RAMIEL_GLASS:Lerp(i%2==0 and Color3.fromRGB(25,48,158) or Color3.fromRGB(127,211,255),.28)
    solid.Parent=glass
   end
  else
   for i=1,8 do
    local tint=RAMIEL_GLASS:Lerp(i<=4 and Color3.fromRGB(179,235,255) or Color3.fromRGB(23,62,176),.24+((i-1)%4)*.085)
    for _,suffix in ipairs({'A','B'}) do
     local pane=hardware('Pane'..i..suffix,Vector3.one*.04,CFrame.new(),tint,Enum.Material.Glass,nil,nil,nil,true)
     pane.Transparency=.18;pane.Reflectance=.12;pane.CastShadow=false;pane.Parent=glass
    end
   end
  end
  local core=hardware('Core',Vector3.one*.6,CFrame.new(),RAMIEL_RED,Enum.Material.Neon,Enum.PartType.Ball)
  core.Parent=glass
  local light=Instance.new('PointLight');light.Name='ApertureLight';light.Color=Color3.fromRGB(255,58,108)
  light.Range=8;light.Enabled=false;light.Parent=core
  DroneConfig.poseRamiel(DroneConfig.ramielRig(model),pose,nil,0,nil,0)
 elseif role=='Needler' then
  local hull=hardware('DartHull',Vector3.new(1.5,.48,1.75),CFrame.new(),painted,slate)
  shotMuzzle(hull,Vector3.new(0,.08,-1.73)*scale)
  for _,side in ipairs({-1,1}) do
   hardware('DartRail',Vector3.new(.26,.29,1.5),CFrame.new(side*.52,.07,-.79),dark,metal,nil,'DartSlide')
   hardware('DartTip',Vector3.new(.21,.20,.34),CFrame.new(side*.52,.07,-1.55),pale,smooth,nil,'DartSlide')
  end
  hardware('RailCover',Vector3.new(1.24,.10,.38),CFrame.new(0,.28,.27),pale,smooth)
  hardware('ChamberedDart',Vector3.new(.23,.24,.80),CFrame.new(0,.19,-1.40),Color3.fromRGB(255,220,138),Enum.Material.Neon,nil,'DartLoad')
 elseif role=='Ballcaster' then
  pod('CoilHull',1.88,.58,0,painted,slate)
  local ring=hardware('LaunchRing',Vector3.new(.24,1.28,1.28),CFrame.new(0,.14,-.96)*foreAft,dark,metal,cylinder,'BallSlide')
  shotMuzzle(ring,Vector3.new(.16,0,0)*scale)
  hardware('CoilFace',Vector3.new(.10,.94,.94),CFrame.new(0,.14,-1.10)*foreAft,pale,smooth,cylinder,'BallSlide')
  hardware('LoadedOrb',Vector3.one*.62,CFrame.new(0,.14,-1.24),color,Enum.Material.Neon,Enum.PartType.Ball,'BallReload')
 elseif role=='Vacuum' then
  pod('VacuumHousing',1.82,.57,.03,painted,slate)
  hardware('WideIntake',Vector3.new(.30,1.46,1.46),CFrame.new(0,-.46,0)*vertical,dark,metal,cylinder,'Intake')
  hardware('IntakeGlow',Vector3.new(.12,.80,.80),CFrame.new(0,-.62,0)*vertical,color,Enum.Material.Neon,cylinder,'Intake')
  for _,side in ipairs({-1,1}) do
   hardware('SuctionCanister',Vector3.new(1.34,.52,.52),CFrame.new(side*.94,.22,0)*foreAft,pale,smooth,cylinder,'Canister',side)
  end
 elseif role=='Compactor' then
  hardware('PressHull',Vector3.new(1.9,.56,1.62),CFrame.new(),painted,slate)
  hardware('PressCap',Vector3.new(1.43,.20,1.23),CFrame.new(0,.32,0),pale,smooth)
  hardware('PressIntake',Vector3.new(.19,.95,.95),CFrame.new(0,-.45,0)*vertical,dark,metal,cylinder)
  hardware('PressIndicator',Vector3.new(.09,.57,.57),CFrame.new(0,-.56,0)*vertical,color,Enum.Material.Neon,cylinder)
  for i,position in ipairs(DroneConfig.PressSockets) do
   hardware('PressSocket'..i,Vector3.new(.13,.63,.63),CFrame.new(position-Vector3.yAxis*.28)*vertical,dark,metal)
  end
  for _,side in ipairs({-1,1}) do
   hardware('PressRail',Vector3.new(.27,.91,1.52),CFrame.new(side*.93,-.21,0),dark,metal)
   hardware('PressJaw',Vector3.new(.27,.25,1.31),CFrame.new(side*.76,-.73,0),pale,metal,nil,'PressJaw',side)
   hardware('PressFoot',Vector3.new(.39,.33,1.22),CFrame.new(side*.97,-.49,0),pale,metal,nil,'PressFoot',side)
  end
 elseif role=='Striker' then
  pod('RoundMinerHull',2.12,.48,.05,painted,slate)
  pod('ShoulderRing',1.99,.16,-.26,dark,metal)
  pod('CeramicNoseCap',1.47,.20,.38,pale,smooth)
  local underside=Vector3.new(0,-body.Size.Y/(2*scale),0)
  pod('OpticCollar',.82,.20,math.min(-.37,underside.Y+.12),dark,metal)
  lens('MiningOptic',Vector3.new(underside.X,math.min(-.49,underside.Y),underside.Z),color,.32)
  for _,side in ipairs({-1,1}) do
   hardware('SideVent',Vector3.new(.32,.23,.66),CFrame.new(side*.91,.07,.15),dark,metal)
  end
 elseif role=='Dart' then
  hardware('SeedDartHull',Vector3.new(1.02,.54,2.4),CFrame.new(0,.14,-.09)*CFrame.Angles(0,math.pi,0),painted,slate,nil,nil,nil,true)
  hardware('SeederKeel',Vector3.new(.76,.22,1.91),CFrame.new(0,-.22,.03),dark,metal)
  for _,side in ipairs({-1,1}) do
   hardware('MineralSeeder',Vector3.new(1.34,.40,.40),CFrame.new(side*.58,-.08,.14)*foreAft,pale,metal,cylinder,'Seeder',side)
  end
  lens('SeedOutlet',Vector3.new(0,-.40,-.31),color,.23)
 elseif role=='Charger' then
  hardware('RamCylinder',Vector3.new(2.15,1.27,1.27),CFrame.new(0,.01,0)*foreAft,painted,slate,cylinder)
  hardware('ForgedRamFace',Vector3.new(.30,1.32,1.32),CFrame.new(0,.01,-1.09)*foreAft,dark,metal,cylinder)
  hardware('RamCap',Vector3.new(.12,.93,.93),CFrame.new(0,.01,-1.29)*foreAft,color,smooth,cylinder)
  for _,side in ipairs({-1,1}) do
   hardware('ImpactDrum',Vector3.new(.72,.74,.74),CFrame.new(side*.79,-.08,.32),dark,metal,cylinder)
  end
 elseif role=='Orbiter' then
  pod('RelayUndercarriage',1.31,.52,-.10,dark,metal)
  hardware('FocusingMast',Vector3.new(.20,.76,.20),CFrame.new(0,.34,0),dark,metal)
  local dish=CFrame.new(0,.81,0)*CFrame.Angles(.26,0,-.17)*vertical
  hardware('ReceiverDish',Vector3.new(.22,2.39,2.39),dish,painted,slate,cylinder)
  hardware('DishInlay',Vector3.new(.12,1.99,1.99),dish*CFrame.new(.15,0,0),pale,smooth,cylinder)
  hardware('OrbitalLens',Vector3.new(.23,.66,.66),dish*CFrame.new(.28,0,0),color,smooth,cylinder)
  for _,side in ipairs({-1,1}) do
   hardware('RelayWing',Vector3.new(.88,.11,.55),CFrame.new(side*.89,-.12,.29)*CFrame.Angles(0,0,side*.13),dark,metal)
  end
 elseif role=='Scrapper' then
  hardware('FabricatorYoke',Vector3.new(2.06,.24,.56),CFrame.new(0,.13,.37),painted,slate)
  for _,side in ipairs({-1,1}) do
   hardware('MiniDroneBay',Vector3.new(1.47,.66,.66),CFrame.new(side*.62,.03,-.07)*foreAft,dark,metal,cylinder)
   hardware('BayLatch',Vector3.new(.13,.69,.69),CFrame.new(side*.62,.03,-.79)*foreAft,painted,slate,cylinder)
   hardware('BayMouth',Vector3.new(.09,.41,.41),CFrame.new(side*.62,.03,-.87)*foreAft,Color3.fromRGB(41,46,39),smooth,cylinder)
  end
  lens('FabricatorIndicator',Vector3.new(0,.33,.35),color,.26)
 elseif role=='Medic' then
  pod('RepairDisc',1.51,.24,.01,dark,metal)
  pod('CeramicCover',1.32,.20,.20,pale,smooth)
  hardware('RepairCrossA',Vector3.new(.76,.06,.21),CFrame.new(0,.33,0),color,smooth)
  hardware('RepairCrossB',Vector3.new(.21,.06,.76),CFrame.new(0,.33,0),color,smooth)
  lens('RepairOutlet',Vector3.new(0,-.29,0),color,.28)
 elseif role=='Courier' then
  hardware('ParcelSling',Vector3.new(1.05,.20,1.36),CFrame.new(0,-.38,0),painted,slate)
  hardware('FrontKeel',Vector3.new(.91,.38,1.04),CFrame.new(0,-.07,-.27),painted,slate,nil,nil,nil,true)
  for _,side in ipairs({-1,1}) do
   hardware('LiftDrum',Vector3.new(.75,.48,.48),CFrame.new(side*.81,.09,0)*vertical,dark,metal,cylinder)
   hardware('LiftDrumCap',Vector3.new(.13,.52,.52),CFrame.new(side*.81,.52,0)*vertical,pale,smooth,cylinder)
   hardware('ParcelRail',Vector3.new(.13,.16,1.31),CFrame.new(side*.52,-.22,.05),dark,metal)
  end
  lens('ParcelIndicator',Vector3.new(0,-.49,.35),color,.22)
 end
 if (role=='Medic' or role=='Courier') and emitter and emitter:IsA('BasePart') then
  emitter.Size=Vector3.one*.18*scale;emitter.CFrame=pose*CFrame.new(0,(role=='Medic' and -.20 or -.5)*scale,0)
 end
 model:SetAttribute('RoleGeometry',role)
 return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
end

-- Equipment drops are rolled by the saved consumable rules, not timed buffs.
DroneConfig.Discoveries = {
 PickupLifetime = 30,
 CollectDistance = 7,
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

