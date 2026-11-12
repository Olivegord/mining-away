--!strict
-- Client-only role visuals. The server publishes compact effect descriptions.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Effects = {}
local animations={}
local beamTimelines={}
local chargeTimelines={}
local orbitalTimelines={}
local pulseTimelines={}
local pulseCount=0
local eventAt=nil
local function clock() return eventAt or workspace:GetServerTimeNow() end
function Effects.setTime(at) eventAt=at end
local function animate(value,duration,style,direction,properties)
 local initial={};for key in pairs(properties) do initial[key]=value[key] end
 animations[value]={at=clock(),duration=duration,style=style,direction=direction,initial=initial,goal=properties}
end
local prismSpills=0
local scorchTimelines={}
local scorchCount=0
local function prismPart(parent,name)
 local part=Instance.new('Part')
 part.Name=name;part.Size=Vector3.one*.025;part.Anchored=true;part.CanCollide=false
 part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Transparency=1;part.Parent=parent
 return part
end
local function prismSpill(parent,from,to,color,normal)
 if prismSpills>=4 or BeamVFX.reduced() then return nil end
 prismSpills+=1
 parent.Destroying:Connect(function() prismSpills-=1 end)
 local outgoing=normal or (from-to).Unit
 local impact=prismPart(parent,'PrismImpactLight')
 impact.CFrame=CFrame.lookAt(to+outgoing*.17,to+outgoing)
 local glow=EnergyDisc.sprite(impact,'PrismContactGlow')
 local sparks=Instance.new('ParticleEmitter');sparks.Name='PrismContactSparks'
 EnergyDisc.configure(sparks,.34,.29,.80,.24)
 sparks.Color=ColorSequence.new(Color3.fromRGB(255,109,140),Color3.fromRGB(225,16,53))
 sparks.EmissionDirection=Enum.NormalId.Front;sparks.SpreadAngle=Vector2.new(56,56)
 sparks.Lifetime=NumberRange.new(.24,.51);sparks.Speed=NumberRange.new(6,15)
 sparks.Drag=2.2;sparks.Acceleration=Vector3.new(0,-14,0)
 sparks.Rate=0;sparks.Enabled=false;sparks.Parent=impact
 local lights={}
 for i=1,2 do
  local mount=i==1 and prismPart(parent,'PrismSourceLight') or impact
  if i==1 then mount.Position=from:Lerp(to,.22) end
  local lamp=Instance.new('PointLight')
  lamp.Color=color:Lerp(Color3.fromRGB(255,135,158),.70)
  lamp.Range=i==1 and 15 or 22;lamp.Brightness=0;lamp.Enabled=false;lamp.Parent=mount
  lights[i]=lamp
 end
 return {impact=impact,glow=glow,sparks=sparks,lights=lights}
end
local function stepPrismSpill(spill,fade)
 if BeamVFX.reduced() then fade=0 end
 local player=Players.LocalPlayer
 local flashScale=player and player:GetAttribute('ReducedFlashing')==true and .36 or 1
 for i,lamp in ipairs(spill.lights) do
  lamp.Enabled=fade>.01
  lamp.Brightness=fade*(i==1 and 4.6 or 7.13)*flashScale
 end
 EnergyDisc.place(spill.glow,spill.impact.Position,1.08+fade*.82,Color3.fromRGB(255,133,155),fade*.53*flashScale)
 spill.sparks.Enabled=fade>.02
 spill.sparks.Rate=47*fade
end
local function prismScorch(parent,point,normal,travel,at)
 if scorchCount>=16 or not BeamVFX.near(point,115) then return end
 local projected=travel-normal*travel:Dot(normal)
 local tangent=projected.Magnitude>.01 and projected.Unit or normal:Cross(Vector3.zAxis).Unit
 local across=normal:Cross(tangent).Unit
 local root=prismPart(parent,'PrismScorch')
 local layers={}
 for i=1,3 do
  local mark=prismPart(root,'CharredGround')
  mark.Shape=Enum.PartType.Cylinder;mark.Material=Enum.Material.Basalt
  mark.Color=i==1 and Color3.fromRGB(43,29,26) or Color3.fromRGB(25,20,20)
  local offset=i==1 and 0 or (i==2 and .76 or -1.05)
  local center=point+normal*(.024+i*.009)+tangent*offset+across*(i==3 and .28 or 0)
  mark.CFrame=CFrame.fromMatrix(center,normal,tangent,across)*CFrame.Angles(i==2 and .15 or -.08,0,0)
  mark.Size=i==1 and Vector3.new(.016,5.8,3.7) or Vector3.new(.016,3.30-i*.24,2.55-i*.16)
  layers[i]=mark
 end
 scorchCount+=1
 scorchTimelines[root]={at=at,layers=layers}
end
function Effects.step(now)
 ImpactRubble.step(now)
 for root,mark in pairs(scorchTimelines) do
  local age=now-mark.at
  if not root.Parent or age>=17 then
   root:Destroy();scorchTimelines[root]=nil;scorchCount-=1
  else
   local darken=math.clamp(age/.26,0,1)*(1-math.clamp((age-11)/6,0,1))
   for i,layer in ipairs(mark.layers) do layer.Transparency=1-darken*(i==1 and .40 or .71) end
  end
 end
 for root,t in pairs(pulseTimelines) do
  local q=(now-t.at)/t.duration
  if not root.Parent or q>=1 then root:Destroy();pulseTimelines[root]=nil;pulseCount-=1
  elseif q<0 or BeamVFX.reduced() then PlaneBurst.hide(t.plane)
  else
   -- Attack pressure is immediate and strongly braked. A contracting target
   -- mark instead accelerates into contact; neither is an expanding ball.
   local u=t.last>=t.first and (1-math.exp(-q*14))*.88+.12*q or q*q*q
   local radius=(t.first+(t.last-t.first)*u)*.5
   PlaneBurst.pose(t.plane,t.normal or Vector3.yAxis,radius,t.sight and (.42+.5*q) or (1-q)^.7*.8,(.035+.055*(1-q))*(t.stroke or 1))
  end
 end
 for rig,t in pairs(beamTimelines) do
  local age=now-t.at
  local prism=rig.style=='Prism'
  if not rig.root.Parent or (prism and age>=t.duration) or age>t.duration+rig.profile.tail then
   BeamVFX.destroy(rig);beamTimelines[rig]=nil
  elseif age<0 then BeamVFX.hide(rig)
  elseif age<t.duration then
   if prism then
    local remaining=1-age/t.duration
    local opacity=remaining^.98
    BeamVFX.draw(rig,t.from,t.to,now,.64+.36*opacity,nil,age,t.scale)
    BeamVFX.fadePrism(rig,opacity)
    if t.spill and t.spill.impact.Parent then stepPrismSpill(t.spill,remaining^1.55) end
   else
    local expansion=math.min(1,age/.035)
    local collapse=1-math.clamp((age/t.duration-.62)/.38,0,1)
    BeamVFX.draw(rig,t.from,t.to,now,expansion*collapse,nil,age,t.scale)
   end
  else BeamVFX.after(rig,t.from,t.to,now,age-t.duration,t.scale) end
 end
 for group,t in pairs(chargeTimelines) do
  if not group.Parent then chargeTimelines[group]=nil
  else
   local q=math.clamp((now-t.at)/t.duration,0,1)
   local lock=math.clamp((q-.72)/.28,0,1)
   local reduced=BeamVFX.reduced() or now>=t.at+t.duration+.12
   for i,value in ipairs(t.rings) do
    local phase=math.clamp((q-(i-1)*.12)/.86,0,1)
    local y=(1-phase)^2*(2.5+i*2.9)+.12*i
    value.root.Position=t.floor+Vector3.yAxis*y
    local opacity=not reduced and math.clamp(phase*5,0,1)*(.25+.65*lock) or 0
    PlaneBurst.pose(value.plane,Vector3.yAxis,t.radius*(1.7-1.02*phase),opacity,.070+.056*lock)
   end
  end
 end
 for group,t in pairs(orbitalTimelines) do
  if not group.Parent or group:GetAttribute('EndedAt') then
   for _,ring in ipairs(t.rings) do ring.root:Destroy() end
   orbitalTimelines[group]=nil
  else
   local age=math.max(0,now-t.at)
   local reduced=BeamVFX.reduced()
   local surge=reduced and 0 or (1-math.clamp(age/.23,0,1))^3
   local rise=math.clamp(age/.045,0,1)
   local settle=math.max(.14,rise)*(1+.92*surge)
   for i,column in ipairs(t.columns) do
    local ripple=not reduced and i<#t.columns and .12*math.sin(age*24-i*1.8) or 0
    local width=t.widths[i]*(settle+ripple)
    column.Size=Vector3.new(column.Size.X,width,width)
   end
   local position=group:GetAttribute('Position')
   if position then
    for i,ring in ipairs(t.rings) do
     local phase=(age*2.6+(i-1)*.5)%1
     ring.root.Position=Vector3.new(position.X,t.floor+1+(1-phase)*14,position.Z)
     local strength=not reduced and not group:GetAttribute('Suspended') and math.sin(math.pi*phase)^.7 or 0
     PlaneBurst.pose(ring.plane,Vector3.yAxis,t.radius*(.31+phase*.38),strength,.11)
    end
   end
   if t.light then
    t.light.Brightness=group:GetAttribute('Suspended') and 0 or .85+2.2*surge
   end
  end
 end
 for value,animation in pairs(animations) do
  if not value.Parent then animations[value]=nil
  else
   local t=math.clamp((now-animation.at)/animation.duration,0,1)
   local alpha=TweenService:GetValue(t,animation.style,animation.direction)
   for key,goal in pairs(animation.goal) do
    local first=animation.initial[key]
    value[key]=type(goal)=='number' and first+(goal-first)*alpha or first:Lerp(goal,alpha)
   end
   if t>=1 then animations[value]=nil end
  end
 end
end
local MAX_LIVE = 256
local live = 0
local ORBITAL_HEIGHT=260
local ORBITAL_COLOR=Color3.fromRGB(248,241,255)
local ORBITAL_VIOLET=Color3.fromRGB(170,102,255)
local ORBITAL_PINK=Color3.fromRGB(238,144,255)
local ORBITAL_TAIL=4.4

local function folder(): Folder
	local existing = workspace:FindFirstChild("DroneRoleClientEffects")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "DroneRoleClientEffects"
	created.Parent = workspace
	return created
end

local function part(): Part?
	if live >= MAX_LIVE then
		return nil
	end
	local value = Instance.new("Part")
	value.Name = "RoleEffect"
	value.Anchored = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.CastShadow = false
	value.Material = Enum.Material.Neon
	value.Parent = folder()
	live += 1
	local counted = true
	value.Destroying:Connect(function()
		if counted then
			counted = false
			live -= 1
		end
	end)
	return value
end

function Effects.Beam(from: Vector3, to: Vector3, color: Color3, width: number?, lifetime: number?, style: string?, groundNormal: Vector3?)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return
	end
	local duration = lifetime or 0.16
	local thickness = width or 0.18
	local at=clock();local now=workspace:GetServerTimeNow()
	local profile=BeamVFX.styles[style or 'Lance'] or BeamVFX.styles.Lance
	if now-at>duration+profile.tail then return end
	if style=='Prism' and groundNormal then prismScorch(folder(),to,groundNormal,delta.Unit,at) end
	local rig=BeamVFX.new(folder(),style or 'Lance',color,style~='Prism')
	if rig then
	 beamTimelines[rig]={at=at,duration=duration,from=from,to=to,scale=thickness/profile.body,
	  spill=style=='Prism' and prismSpill(rig.root,from,to,color,groundNormal) or nil}
	elseif now-at<duration then
	 -- Saturated cosmetic budget retains a simple readable shot.
	 local value=part();if not value then return end
	 value.Color=color;value.Size=Vector3.new(thickness*.35,thickness*.35,delta.Magnitude)
	 value.CFrame=CFrame.lookAt(from:Lerp(to,.5),to);value.Transparency=style=='Prism' and .20 or .45
	 local fadeTime=style=='Prism' and duration or math.max(.01,duration-(now-at))
	 animate(value,fadeTime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Transparency=1})
	 Debris:AddItem(value,math.max(.01,duration-(now-at))+.05)
	end
end

function Effects.Pulse(position: Vector3, color: Color3, startSize: number?, endSize: number?, lifetime: number?, normal: Vector3?, stroke: number?)
 local duration=math.max(.01,lifetime or .3)
 local at=clock()
 if pulseCount>=24 or workspace:GetServerTimeNow()-at>=duration or not BeamVFX.near(position,140) or BeamVFX.reduced() then return end
 local value=part();if not value then return end
 pulseCount+=1
 value.Name='RolePressureFront';value.Transparency=1;value.Size=Vector3.one*.025;value.Position=position
 pulseTimelines[value]={at=at,duration=duration,first=startSize or .8,last=endSize or 5,plane=PlaneBurst.create(value,color),normal=normal,stroke=stroke}
 Debris:AddItem(value,duration+.05)
end

function Effects.Crater(position: Vector3,radius: number,style: string,at: number,direction: Vector3?)
 if BeamVFX.reduced() or not BeamVFX.near(position,150) then return end
 local player=Players.LocalPlayer
 local steady=game:GetService('GuiService').ReducedMotionEnabled or (player and player:GetAttribute('ReducedMotion')==true)
 ImpactRubble.spawn(folder(),position,radius,style,at,workspace:GetServerTimeNow(),direction,steady)
end

-- World-space particles survive the rock, drone or beam that triggered them.
-- One capped carrier per beat keeps clustered finishes within a fixed budget.
local impactCount,prismImpactCount=0,0
local impactStyles={
 Bubbler={speed=NumberRange.new(2,7),spread=62,lift=2,count=6,dust=0},
 Halver={speed=NumberRange.new(10,20),spread=82,lift=-8,count=7,dust=0},
 Gridcutter={speed=NumberRange.new(12,22),spread=32,lift=-14,count=7,dust=0},
 Singularity={speed=NumberRange.new(3,8),spread=35,lift=4,count=7,dust=2},
 Starforge={speed=NumberRange.new(10,19),spread=63,lift=-19,count=12,dust=3},
 Frostbite={speed=NumberRange.new(13,24),spread=59,lift=-18,count=11,dust=0},
 Resonator={speed=NumberRange.new(5,12),spread=79,lift=-6,count=6,dust=1},
 Touchdown={speed=NumberRange.new(5,10),spread=79,lift=-16,count=4,dust=3},
 Scrap={speed=NumberRange.new(4,8),spread=52,lift=-18,count=3,dust=0},
}
function Effects.ImpactParticles(position: Vector3,color: Color3,scale: number,kind: string,normal: Vector3?)
 local prism=kind=='PrismBlast'
 if (prism and prismImpactCount>=32 or not prism and impactCount>=14) or BeamVFX.reduced() or not BeamVFX.near(position,115) then return end
 local root=part();if not root then return end
 root.Name=kind..'Particles';root.Transparency=1;root.Size=Vector3.one*.04;root.Position=position
 if normal then root.CFrame=CFrame.lookAt(position,position+normal) end
 if prism then
  prismImpactCount+=1;root.Destroying:Connect(function() prismImpactCount-=1 end)
 else
  impactCount+=1;root.Destroying:Connect(function() impactCount-=1 end)
 end
 local residual=kind=='OrbitalFallout'
 local orbital=kind=='OrbitalImpact' or residual
 local style=impactStyles[kind]
 local sparks=Instance.new('ParticleEmitter');sparks.Name='AirborneSparks'
 local diameter=math.min(2.15,(orbital and 1.40 or 1.15)*scale)
 EnergyDisc.configure(sparks,diameter,residual and .57 or .46,.64,.50)
 sparks.Enabled=false;sparks.Rate=0
 sparks.Color=ColorSequence.new(prism and Color3.fromRGB(255,114,144) or color:Lerp(Color3.fromRGB(255,248,216),.44),color)
 local spread=style and style.spread or 63
 sparks.EmissionDirection=normal and Enum.NormalId.Front or Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(spread,spread)
 sparks.Lifetime=residual and NumberRange.new(1.3,2.6) or NumberRange.new(.36,.84)
 sparks.Speed=style and style.speed or prism and NumberRange.new(15,27) or residual and NumberRange.new(2,5) or NumberRange.new(8,16)
 sparks.Acceleration=Vector3.new(0,style and style.lift or residual and .8 or -12,0);sparks.Drag=residual and 3.2 or 3.8
 sparks.Parent=root;sparks:Emit(style and style.count or prism and 20 or residual and 9 or orbital and 10 or 8)
 local dustCount=style and style.dust or prism and 9 or orbital and 5 or 4
 Debris:AddItem(root,residual and 2.7 or 1.4)
 if dustCount==0 then return end
 local dust=Instance.new('ParticleEmitter');dust.Name='DriftingDust'
 EnergyDisc.configure(dust,math.min(2.5,diameter*1.27),.74,.48,1.20)
 dust.Enabled=false;dust.Rate=0;dust.LightEmission=.13;dust.LightInfluence=.30
 dust.Color=ColorSequence.new(prism and Color3.fromRGB(73,17,32) or color:Lerp(Color3.fromRGB(206,183,183),.36))
 dust.EmissionDirection=sparks.EmissionDirection;dust.SpreadAngle=Vector2.new(76,76)
 dust.Lifetime=NumberRange.new(.64,residual and 2 or 1.28)
 dust.Speed=NumberRange.new(residual and 1 or 3,residual and 4 or 7);dust.Drag=4
 dust.Acceleration=Vector3.new(0,1.1,0)
 dust.Parent=root;dust:Emit(dustCount)
end

local specialistHits={
 Bubbler={color=Color3.fromRGB(167,244,225),cue='tool_stick',pitch=1.23,scale=.64,radius=1.85,tail=.28},
 Halver={color=Color3.fromRGB(246,246,255),cue='tool_slice',pitch=1.06,scale=.63,radius=2.7,tail=.18},
 Gridcutter={color=Color3.fromRGB(101,242,204),cue='crystal_electric',pitch=.85,scale=.59,radius=1.5,tail=.15},
 Singularity={color=Color3.fromRGB(169,116,255),cue='crystal_impact',pitch=.76,scale=.85,radius=2.6,tail=.35},
 Starforge={color=Color3.fromRGB(255,174,83),cue='tool_sizzle',pitch=.87,scale=.94,radius=3.1,tail=.32},
 Frostbite={color=Color3.fromRGB(166,226,255),cue='crystal_snap',pitch=1.31,scale=.8,radius=2.25,tail=.21},
 Resonator={color=Color3.fromRGB(249,165,255),cue='coil_hit',pitch=1.19,scale=.63,radius=3.15,tail=.39},
}
function Effects.SpecialistContact(kind: string,point: Vector3,normal: Vector3,depleted: boolean,audio: any)
 local hit=specialistHits[kind];if not hit then return end
 local scale=depleted and 1.25 or 1
 local plane=(kind=='Halver' or kind=='Resonator' or kind=='Starforge') and Vector3.yAxis or normal
 local closing=kind=='Singularity'
 Effects.Pulse(point+normal*.08,hit.color,closing and hit.radius*scale or .22,closing and .18 or hit.radius*scale,hit.tail,plane,kind=='Halver' and .62 or 1.25)
 Effects.ImpactParticles(point,hit.color,hit.scale*scale,kind,normal)
 audio:play(hit.cue,point,{pitch=hit.pitch,level=depleted and .85 or .62})
end

function Effects.PrismWave(position: Vector3,radius: number,duration: number)
 Effects.Pulse(position+Vector3.yAxis*.09,Color3.fromRGB(229,40,78),radius*.4,radius*2.7,duration,Vector3.yAxis,2.25)
 Effects.Pulse(position+Vector3.yAxis*.20,Color3.fromRGB(255,204,217),radius*.19,radius*1.87,duration*.62,Vector3.yAxis,1.65)
end

function Effects.PrismShatter(position: Vector3,radius: number,at: number,direction: Vector3)
 Effects.Crater(position,radius,'Prism',at,direction)
 if workspace:GetServerTimeNow()-at>=.24 then return end
 local red=Color3.fromRGB(229,40,78)
 Effects.ImpactParticles(position+Vector3.yAxis*.55,red,2.1,'PrismBlast')
end

function Effects.Heal(from: Vector3, to: Vector3)
	local color = Color3.fromRGB(99, 255, 164)
	Effects.Beam(from, to, color, 0.14, 0.2,'Repair')
	Effects.Pulse(to, color, 0.5, 2.5, 0.24)
end

function Effects.Charge(position: Vector3, target: Vector3, impact: boolean?)
	local color = Color3.fromRGB(255, 137, 70)
	if impact then
		Effects.Beam(position, target, color, 0.3, 0.2,'Combat')
		Effects.Pulse(target, color, .7, 4.2, 0.28)
		Effects.ImpactParticles(target,color,.65,'Gridcutter')
	else
		Effects.Pulse(position, Color3.fromRGB(255, 218, 105), 0.5, 3.4, 0.8)
	end
end

-- Seeding dust falls from the actual grower; the bloom confirms a real spawn.
function Effects.Grow(from: Vector3,target: Vector3,planted: boolean)
 if BeamVFX.reduced() then return end
 local green=Color3.fromRGB(152,231,158)
 local value=part();if not value then return end
 value.Name=planted and 'CrystalSeedBloom' or 'CrystalSeedFall';value.Transparency=1
 if planted then value:SetAttribute('AudioCue','plant');value:SetAttribute('AudioAt',clock()) end
 value.Position=planted and target or from
 local tip=Instance.new('Attachment');tip.Parent=value
 local dust=Instance.new('ParticleEmitter');EnergyDisc.configure(dust,planted and .84 or .65,.60)
 dust.Enabled=false;dust.Rate=0;dust.Color=ColorSequence.new(green)
 dust.Lifetime=NumberRange.new(1,1.6);dust.Speed=NumberRange.new(planted and 3 or 1,planted and 5 or 2)
 dust.EmissionDirection=planted and Enum.NormalId.Top or Enum.NormalId.Bottom;dust.SpreadAngle=Vector2.new(22,22)
 dust.Acceleration=Vector3.new(0,planted and .1 or -.3,0);dust.Drag=planted and 8 or 3;dust.WindAffectsDrag=false
 dust.Parent=tip;dust:Emit(planted and 7 or 4);Debris:AddItem(value,1.8)
 if planted then Effects.Pulse(target+Vector3.new(0,.25,0),green,.2,1.6,.45) end
end

-- These are one-shot phase cues. The authoritative drone moves through its
-- windup/dive/recovery; none of these effects is a steady mining beam.
function Effects.BreakerPhase(position: Vector3,target: Vector3,phase: string,diameter: number?)
 local amber=Color3.fromRGB(220,164,81)
 local scale=math.clamp((diameter or 3)/3,.65,3)
 if phase=='Windup' then
  Effects.Pulse(target,amber,.2*scale,2.4*scale,.75)
 elseif phase=='Dive' then
  Effects.Pulse(target,Color3.fromRGB(239,211,154),2*scale,.25*scale,.25)
 elseif phase=='Impact' then
  local cue=part();if cue then cue.Name='ConfirmedMiningImpact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','Breaker');cue:SetAttribute('ImpactAt',clock());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(244,207,142),.35*scale,4.6*scale,.26)
  local shock=not BeamVFX.reduced() and part() or nil
  if shock then
   shock.Name='BreakerPressureWave';shock.Shape=Enum.PartType.Cylinder;shock.Color=Color3.fromRGB(221,196,142)
   shock.Transparency=1;shock.Size=Vector3.new(.055,.6,.6);shock.CFrame=CFrame.new(target)*CFrame.Angles(0,0,math.pi/2)
   local attachment=Instance.new('Attachment');attachment.CFrame=CFrame.Angles(0,0,-math.pi/2);attachment.Parent=shock
   local dust=Instance.new('ParticleEmitter');dust.Name='BreakerDust';EnergyDisc.configure(dust,1.18,.69,.60,1.22)
   dust.Color=ColorSequence.new(Color3.fromRGB(118,108,91));dust.LightEmission=0;dust.LightInfluence=.65;dust.Brightness=1
   dust.Enabled=false;dust.Rate=0;dust.Lifetime=NumberRange.new(1,1.6)
   dust.Speed=NumberRange.new(6,11);dust.Drag=7;dust.Acceleration=Vector3.new(0,.25,0);dust.WindAffectsDrag=false
   dust.EmissionDirection=Enum.NormalId.Top;dust.SpreadAngle=Vector2.new(80,80)
   dust.Parent=attachment;dust:Emit(10)
   Effects.Pulse(target,amber,.6*scale,6.4*scale,.65)
   Debris:AddItem(shock,1.8)
  end
  -- The actual fracture creates authored crystal fragments in Presentation.
  -- Avoid a second shower of generic weightless balls on the same event.
 elseif phase=='Hold' then
  -- This is physical touchdown, distinct from the later damaging fracture.
  -- A single server receipt drives both the local thud and camera impulse.
  local cue=part();if cue then cue.Name='ConfirmedBreakerContact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','BreakerContact');cue:SetAttribute('ImpactAt',clock());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(244,211,155),.3*scale,2.5*scale,.17)
  Effects.Pulse(target,Color3.fromRGB(255,206,107),.2*scale,1.1*scale,.9)
  Effects.ImpactParticles(target,amber,.52*scale,'Touchdown')
 elseif phase=='Recover' then
  Effects.Pulse(position,Color3.fromRGB(168,155,123),.15,.7,.2)
 end
end

-- Gadget FX are consequences of the authoritative DroneAbilities state machine.
-- RoleEffectView supplies the replicated intent; no local pose feeds damage.
local swarms: {[any]: Folder} = {}
local markers: {[any]: Instance} = {}
local function clearSwarm(owner: any)
 local old=swarms[owner]
 if old then swarms[owner]=nil;old:Destroy() end
end
local function clearMarker(owner: any)
 local old=markers[owner];markers[owner]=nil
 if old then old:Destroy() end
end
local function location(p: any): Vector3 return Vector3.new(p.x,p.y,p.z) end
local function column(position: Vector3,height: number,width: number,color: Color3,duration: number)
 Effects.Beam(position+Vector3.yAxis*height,position,color,width,duration,'Resonance')
end
local burns: {[any]: Folder} = {}
local function clearBurn(owner: any)
 local old=burns[owner];burns[owner]=nil
 if not old or not old.Parent then return end
 -- Stop work immediately, but let the column collapse into suspended embers.
 -- Every observer evaluates the same authoritative end time locally.
 old:SetAttribute('EndedAt',clock())
 for _,effect in ipairs(old:GetDescendants()) do
  if effect:IsA('ParticleEmitter') then effect.Enabled=false end
  if effect:IsA('PointLight') then animate(effect,.38,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Brightness=0}) end
 end
 local core=old:FindFirstChild('MeltCore')
 local position=old:GetAttribute('Position')
 if typeof(position)=='Vector3' then
  local floor=old:GetAttribute('Ground') or position.Y
  Effects.ImpactParticles(Vector3.new(position.X,floor+.68,position.Z),ORBITAL_PINK,1.35,'OrbitalFallout')
 end
 if core and core:IsA('BasePart') and not BeamVFX.reduced() and typeof(position)=='Vector3' and BeamVFX.near(position,120) then
  -- A full volume leaves a continuous vertical trail, rather than twelve
  -- isolated pairs of dots. Its fixed carrier must not shrink with the laser.
  local trail=part()
  if trail then
   trail.Name='OrbitalResidualColumn';trail.Transparency=1;trail.Shape=Enum.PartType.Cylinder
   -- Concentrate the loose light in the part of the column players can see.
   trail.Size=Vector3.new(26,2,2);trail.CFrame=core.CFrame*CFrame.new(13-ORBITAL_HEIGHT*.5,0,0);trail.Parent=old
   local embers=Instance.new('ParticleEmitter');embers.Name='OrbitalAfterglow'
   EnergyDisc.configure(embers,1.45,.59,.62,.74);embers.Enabled=false;embers.Rate=0
   embers.Color=ColorSequence.new(ORBITAL_COLOR,ORBITAL_VIOLET)
   embers.Shape=Enum.ParticleEmitterShape.Cylinder;embers.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
   embers.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward;embers.ShapePartial=1;embers.EmissionDirection=Enum.NormalId.Right
   embers.Lifetime=NumberRange.new(2,4);embers.Speed=NumberRange.new(.65,2.3);embers.Drag=1.8;embers.WindAffectsDrag=false
   embers.LockedToPart=false;embers.VelocityInheritance=0
   embers.SpreadAngle=Vector2.new(180,180)
   embers.Acceleration=Vector3.new(0,.08,0)
   embers.Parent=trail;embers:Emit(25)
  end
 end
 for _,value in ipairs(old:GetChildren()) do if value:IsA('BasePart') and value.Name~='OrbitalResidualColumn' then
  local size=value.Name=='MeltContact' and Vector3.one*.03 or Vector3.new(value.Size.X,.015,.015)
  animate(value,.48,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Size=size,Transparency=1})
 end end
 Debris:AddItem(old,ORBITAL_TAIL)
end
-- A fixed timer from the strike's creation could cut off its last motes after
-- a storage pause. One watchdog per live group instead begins cleanup only
-- after contacts stop, then preserves a full final particle lifetime.
local function watchBurn(owner: any,group: Folder)
 task.delay(8,function()
  if not group.Parent or group:GetAttribute('EndedAt') then return end
  local at=group:GetAttribute('ContactAt') or 0
  if clock()-at<8 then watchBurn(owner,group);return end
  if burns[owner]==group then burns[owner]=nil end
  group:SetAttribute('EndedAt',clock())
  for _,object in ipairs(group:GetDescendants()) do
   if object:IsA('ParticleEmitter') then object.Enabled=false
   elseif object:IsA('PointLight') then object.Enabled=false
   elseif object:IsA('BasePart') then object.Transparency=1 end
  end
  Debris:AddItem(group,ORBITAL_TAIL)
 end)
end
local function targetSight(owner: any,target: any,duration: number?)
 local group=Instance.new('Folder');group.Name='OrbitalTargetSight';group.Parent=folder();markers[owner]=group
 local value=part();local cue=part()
 if not value or not cue then if value then value:Destroy() end;if cue then cue:Destroy() end;group:Destroy();return end
 local seconds=duration or 2.4
 local radius=math.clamp((target.radius or 1)*1.5,1.65,12)
 local floor=Vector3.new(target.x,(target.ground or target.y)+.065,target.z)
 local red=Color3.fromRGB(255,168,194)
 value.Name='ThinRedSight';value.Shape=Enum.PartType.Cylinder;value.Color=red;value.Transparency=.28
 value.Size=Vector3.new(ORBITAL_HEIGHT,.095,.095)
 value.CFrame=CFrame.new(floor+Vector3.yAxis*(ORBITAL_HEIGHT*.5))*CFrame.Angles(0,0,math.pi/2)
 value.Parent=group
 cue.Name='OrbitalFootprint';cue.Transparency=1;cue.Size=Vector3.one*.025;cue.Position=floor;cue.Parent=group
 cue:SetAttribute('AudioLoop','orbital_charge');cue:SetAttribute('AudioAt',clock());cue:SetAttribute('AudioUntil',clock()+seconds)
 if not BeamVFX.reduced() and pulseCount<24 then
  pulseCount+=1
  pulseTimelines[cue]={at=clock(),duration=seconds,first=radius*2.85,last=radius*2,plane=PlaneBurst.create(cue,red),sight=true}
 end
 local rings={}
 for i=1,3 do
  local mark=Instance.new('Part');mark.Name='ConvergingLock';mark.Anchored=true;mark.CanCollide=false;mark.CanTouch=false;mark.CanQuery=false
  mark.Size=Vector3.one*.025;mark.Transparency=1;mark.CastShadow=false;mark.Position=floor;mark.Parent=group
  rings[i]={root=mark,plane=PlaneBurst.create(mark,i==3 and ORBITAL_COLOR or ORBITAL_VIOLET)}
 end
 chargeTimelines[group]={at=clock(),duration=seconds,floor=floor,radius=radius,rings=rings}
 animate(value,seconds,Enum.EasingStyle.Sine,Enum.EasingDirection.In,{Transparency=.06})
 Debris:AddItem(group,seconds+1.15)
end
local function sustainedStrike(owner: any,event: any)
 local group=burns[owner]
 if group and not group.Parent then burns[owner]=nil;group=nil end
 if not group then
  group=Instance.new('Folder');group.Name='OrbitalMelt';burns[owner]=group
  group:SetAttribute('OrbitalBurn',true)
  group:SetAttribute('StartedAt',event.startedAt or clock())
  local radius=math.clamp(event.target.radius or 1,1,8)
  local floor=Vector3.new(event.target.x,(event.target.ground or event.target.y)+.045,event.target.z)
  group:SetAttribute('Ground',floor.Y)
  local age=workspace:GetServerTimeNow()-(event.startedAt or clock())
  if age<.32 then
   Effects.Pulse(floor,ORBITAL_VIOLET,radius*.9,radius*5.2,.72)
   Effects.Pulse(floor+Vector3.yAxis*.18,ORBITAL_PINK,radius*.6,radius*3.6,.47)
   Effects.Pulse(location(event.target),ORBITAL_COLOR,radius*.28,radius*2.2,.29)
   Effects.ImpactParticles(floor+Vector3.yAxis*.7,ORBITAL_VIOLET,math.clamp(radius*.58,1,1.6),'OrbitalImpact')
  end
  local scale=math.clamp(.75+radius*.2,1,1.85)
  local reduced=BeamVFX.reduced()
  local columns,widths={},reduced and {.56*scale,.20*scale} or {2.1*scale,.89*scale,.27*scale}
  for index,width in ipairs(widths) do
   local value=part();if not value then break end
   local core=index==#widths
   value.Name=core and 'MeltCore' or index==1 and 'MeltHalo' or 'MeltSheath';value.Shape=Enum.PartType.Cylinder
   value.Color=core and ORBITAL_COLOR or index==1 and ORBITAL_VIOLET or ORBITAL_PINK
   value.Transparency=core and .10 or index==1 and .86 or .59
   value.Size=Vector3.new(ORBITAL_HEIGHT,width,width);value.Parent=group;columns[index]=value
   value:SetAttribute('BurnTransparency',value.Transparency)
  end
  local rings={}
  if not reduced and BeamVFX.near(floor,100) then
   for i=1,2 do
    local ring=part();if not ring then break end
    ring.Name='OrbitalCompressionRing';ring.Transparency=1;ring.Size=Vector3.one*.025
    ring.Parent=group;rings[i]={root=ring,plane=PlaneBurst.create(ring,i==1 and ORBITAL_COLOR or ORBITAL_PINK)}
   end
  end
  local contact=not reduced and part() or nil
  local light
  if contact then
   contact.Name='MeltContact';contact.Shape=Enum.PartType.Ball;contact.Color=ORBITAL_COLOR
   contact.Transparency=.28;contact.Size=Vector3.one*(.83*scale);contact.Parent=group;contact:SetAttribute('BurnTransparency',.28)
   light=Instance.new('PointLight');light.Color=ORBITAL_PINK;light.Range=13;light.Parent=contact
   local tip=Instance.new('Attachment');tip.Parent=contact
   local sparks=Instance.new('ParticleEmitter');sparks.Name='MoltenSparks'
   EnergyDisc.configure(sparks,1.27*scale,.58,.56,.72)
   sparks.Color=ColorSequence.new(ORBITAL_COLOR,ORBITAL_PINK)
   sparks.Lifetime=NumberRange.new(.65,1.26);sparks.Speed=NumberRange.new(4,9);sparks.Drag=4.1
   sparks.Acceleration=Vector3.new(0,-.4,0);sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(60,60)
   sparks.Rate=8;sparks.Parent=tip
  end
  orbitalTimelines[group]={at=event.startedAt or clock(),columns=columns,widths=widths,rings=rings,radius=radius,floor=floor.Y,light=light}
  group:SetAttribute('Position',location(event.target));group:SetAttribute('ContactAt',clock())
  group.Parent=folder();watchBurn(owner,group)
 end
 local position=location(event.target)
 group:SetAttribute('Position',position);group:SetAttribute('ContactAt',clock())
 local fresh=workspace:GetServerTimeNow()-clock()<=.3
 local suspended=not fresh
 if group:GetAttribute('Suspended')~=suspended then
  group:SetAttribute('Suspended',suspended)
  for _,v in ipairs(group:GetDescendants()) do if v:IsA('ParticleEmitter') then v.Enabled=fresh end end
 end
 for _,value in ipairs(group:GetChildren()) do if value:IsA('BasePart') and value.Name~='OrbitalCompressionRing' then
  local pose=value.Name=='MeltContact' and CFrame.new(position) or CFrame.new(position+Vector3.new(0,ORBITAL_HEIGHT*.5,0))*CFrame.Angles(0,0,math.pi/2)
  value.CFrame=pose
  value.Transparency=not fresh and 1 or (value:GetAttribute('BurnTransparency') or value.Transparency)
 end end
 group:SetAttribute('Placed',true)
end
function Effects.ClearAbility(owner: any)
 clearSwarm(owner);clearMarker(owner);clearBurn(owner)
end
function Effects.Ability(owner: any,event: any,template: Model?)
 local kind=event.kind
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clearMarker(owner)
 elseif kind=='clearScrap' then clearSwarm(owner)
 elseif kind=='orbitalEnd' then clearBurn(owner)
 elseif kind=='charge' then
  clearMarker(owner)
  if event.ability=='Orbital' then targetSight(owner,event.target,event.duration);return end
  local value=part();if not value then return end
  value.Name='GadgetCharge';value.Shape=Enum.PartType.Ball;value.Size=Vector3.one*.45
  value:SetAttribute('AudioLoop','swarm_charge');value:SetAttribute('AudioAt',clock());value:SetAttribute('AudioUntil',clock()+2.6)
  value.Color=event.ability=='Orbital' and Color3.fromRGB(240,173,88) or Color3.fromRGB(178,202,151)
  value.Transparency=.7;value.Position=location(event.target)+Vector3.new(0,5,0)
  markers[owner]=value;Debris:AddItem(value,2.6)
 elseif kind=='orbital' then
  clearMarker(owner)
  sustainedStrike(owner,event)
 elseif kind=='relay' then
  local position=location(event.target)
  column(position,9,.18,Color3.fromRGB(176,218,255),.3)
  Effects.Pulse(position,Color3.fromRGB(176,218,255),.2,1.7,.3)
 elseif kind=='scrapStart' then clearMarker(owner)
 elseif kind=='recycle' then Effects.Pulse(location(event.target),Color3.fromRGB(173,222,146),.4,2.8,.4)

 end
end

function Effects.destroy()
 ImpactRubble.clear()
 for rig in pairs(beamTimelines) do BeamVFX.destroy(rig) end
 table.clear(beamTimelines);table.clear(chargeTimelines);table.clear(orbitalTimelines)
 for root in pairs(scorchTimelines) do root:Destroy() end
 table.clear(scorchTimelines);scorchCount=0
 table.clear(animations)
 for root in pairs(pulseTimelines) do root:Destroy() end;table.clear(pulseTimelines);pulseCount=0;table.clear(markers);table.clear(burns);table.clear(swarms)
 eventAt=nil
 local root=workspace:FindFirstChild('DroneRoleClientEffects');if root then root:Destroy() end
end
return Effects

