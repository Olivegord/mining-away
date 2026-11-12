-- Local rock slabs sampled from the walkable surface and posed by server time.
local Rubble={}
local UP=Vector3.yAxis
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local STONE=Color3.fromRGB(70,66,63)
local MAX_SLABS=80
local MAX_AGE=4.65
local active={}
local live=0
local styles={
 Prism={count=16,rock=Color3.fromRGB(104,50,52),stretch=1.20},
 Nomad={count=18,rock=Color3.fromRGB(107,78,59),stretch=1.06},
 Orbital={count=14,rock=Color3.fromRGB(85,64,106),stretch=1.02},
 Breaker={count=10,rock=Color3.fromRGB(105,86,66),stretch=1.14},
 Specialist={count=8,rock=STONE,stretch=1.08},
}

local function smooth(q)
 q=math.clamp(q,0,1)
 return q*q*(3-2*q)
end

local function part(parent,class,name)
 local value=Instance.new(class)
 value.Name=name;value.Anchored=true;value.CanCollide=false
 value.CanTouch=false;value.CanQuery=false;value.CastShadow=false
 value.Transparency=1;value.Parent=parent
 return value
end

local function surface(position,query)
 local hit=workspace:Raycast(position+UP*4.6,-UP*9.4,query)
 if not hit or hit.Normal.Y<.65 then return nil end
 return hit
end

local function surfaceFinish(hit)
 local material=hit.Material
 local base=hit.Instance
 local color=base==workspace.Terrain and base:GetMaterialColor(material) or base.Color
 if material==Enum.Material.Grass or material==Enum.Material.LeafyGrass then material=Enum.Material.Ground end
 if material==Enum.Material.Plastic or material==Enum.Material.SmoothPlastic or material==Enum.Material.Neon
  or material==Enum.Material.ForceField or material==Enum.Material.Glass then material=Enum.Material.Slate end
 return color,material
end

local function dust(root,point,normal,direction,color,radius,count)
 local carrier=part(root,'Part','RubbleDust')
 carrier.Size=Vector3.one*.045
 carrier.CFrame=CFrame.lookAt(point+normal*.14,point+direction+normal*.31)
 local plume=Instance.new('ParticleEmitter');plume.Name='LiftedQuarryDust'
 plume.Texture=SMOKE;plume.Enabled=false;plume.Rate=0
 plume.Color=ColorSequence.new(color:Lerp(Color3.fromRGB(197,170,149),.32),color:Lerp(STONE,.43))
 local size=math.clamp(radius*.28,.84,3.6)
 plume.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.3),
  NumberSequenceKeypoint.new(.26,size,size*.21),NumberSequenceKeypoint.new(1,size*1.58)})
 plume.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.92),NumberSequenceKeypoint.new(.16,.58),
  NumberSequenceKeypoint.new(.57,.76),NumberSequenceKeypoint.new(1,1)})
 plume.EmissionDirection=Enum.NormalId.Front;plume.SpreadAngle=Vector2.new(33,21)
 plume.Lifetime=NumberRange.new(.54,1.36);plume.Speed=NumberRange.new(5,math.clamp(radius*1.55,7,20))
 plume.Acceleration=UP*.46;plume.Drag=3.8;plume.WindAffectsDrag=false
 plume.Rotation=NumberRange.new(-180,180);plume.RotSpeed=NumberRange.new(-34,34)
 plume.LightEmission=0;plume.LightInfluence=.54
 plume.Parent=carrier;plume:Emit(count)
end

local function pose(slab,age,steady)
 local value=slab.part
 if age<0 or slab.placed and age<=slab.hold then return end
 local sink=smooth((age-slab.hold)/slab.sinkTime)
 value.CFrame=steady and slab.frame or slab.frame-slab.up*(slab.sinkDepth*sink)
 value.Transparency=smooth((sink-.10)/.90)
 slab.placed=true
end

local function remove(root,ring)
 root:Destroy();active[root]=nil;live-=#ring.slabs
end

function Rubble.spawn(parent,position,radius,style,at,now,direction,steady)
 if now-at>=MAX_AGE or live>MAX_SLABS-6 then return false end
 local world=workspace:FindFirstChild('MiningAway')
 local map=world and world:FindFirstChild('Map')
 if not map then return false end
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include
 query.RespectCanCollide=true;query.IgnoreWater=true;query.FilterDescendantsInstances={map,workspace.Terrain}
 local ground=surface(position,query)
 if not ground then return false end
 local center,normal=ground.Position,ground.Normal
 for _,ring in pairs(active) do
  if ring.style==style and math.abs(ring.at-at)<1.05 and (ring.center-center).Magnitude<math.min(ring.radius,radius)*.6 then return false end
 end
 local spec=styles[style] or styles.Specialist
 local count=math.min(MAX_SLABS-live,steady and math.max(6,spec.count-4) or spec.count)
 local root=Instance.new('Folder');root.Name=style..'Crater';root.Parent=parent
 local ring={at=at,center=center,radius=radius,style=style,slabs={},steady=steady}
 local random=Random.new((math.floor(at*1000)+math.floor(center.X*19)+math.floor(center.Z*41))%2147483647)
 local flat=direction and direction-normal*direction:Dot(normal) or nil
 local forward=flat and flat.Magnitude>.01 and flat.Unit or normal:Cross(Vector3.xAxis).Unit
 local across=normal:Cross(forward)
 local phase=random:NextNumber(0,math.pi*2)
 local arc=math.pi*2/count
 for i=1,count do
  local angle=phase+(i-1)*arc+random:NextNumber(-.21,.21)*arc
  local bearing=forward*math.cos(angle)+across*math.sin(angle)
  local offset=forward*(math.cos(angle)*spec.stretch)+across*math.sin(angle)
  local hit=surface(center+offset*radius*random:NextNumber(.85,1.14),query)
  if not hit or math.abs(hit.Position.Y-center.Y)>3.3 then continue end
  local up=hit.Normal
  local out=(bearing-up*bearing:Dot(up)).Unit
  local right=up:Cross(out).Unit
  local raw,material=surfaceFinish(hit)
  local piece=part(root,i%4==1 and 'WedgePart' or 'Part','BrokenSlab')
  piece.Material=material
  piece.Color=raw:Lerp(spec.rock,random:NextNumber(.30,.57)):Lerp(STONE,random:NextNumber(.02,.19))
  piece.Size=Vector3.new(radius*arc*random:NextNumber(.73,1.30),
   math.clamp(radius*random:NextNumber(.12,.24),.54,2.8),radius*random:NextNumber(.21,.39))
  piece.CastShadow=not steady and i%4==0
  local height=piece.Size.Y
  local center=hit.Position+up*(height*random:NextNumber(.02,.30))
  local frame=CFrame.fromMatrix(center,right,up)
   *CFrame.Angles(random:NextNumber(.18,.48),random:NextNumber(-.42,.42),random:NextNumber(-.24,.24))
  local slab={part=piece,frame=frame,up=up,hold=random:NextNumber(2.02,2.70),
   sinkTime=random:NextNumber(1.08,1.64),sinkDepth=height+piece.Size.Z*.44}
  ring.slabs[#ring.slabs+1]=slab
  pose(slab,now-at,steady)
  if not steady and i%3==0 and now-at<.26 then dust(root,hit.Position,up,out,raw,radius,style=='Specialist' and 3 or 5) end
 end
 if #ring.slabs==0 then root:Destroy();return false end
 -- A faint contact shadow anchors the tilted rim on the flat quarry bed.
 local stain=part(root,'Part','GroundScuff')
 stain.Shape=Enum.PartType.Cylinder;stain.Material=Enum.Material.Basalt
 local soil=surfaceFinish(ground)
 stain.Color=soil:Lerp(STONE,.76)
 stain.Size=Vector3.new(.025,radius*1.59,radius*1.57*spec.stretch)
 stain.CFrame=CFrame.fromMatrix(center+normal*.028,normal,across)
 ring.stain=stain
 if now>=at then stain.Transparency=.75+.25*smooth((now-at-2.5)/1.72) end
 active[root]=ring;live+=#ring.slabs
 return true
end

function Rubble.step(now)
 for root,ring in pairs(active) do
  local age=now-ring.at
  if not root.Parent or age>=MAX_AGE then remove(root,ring)
  else
   for _,slab in ipairs(ring.slabs) do pose(slab,age,ring.steady) end
   if age>=0 then ring.stain.Transparency=.75+.25*smooth((age-2.5)/1.72) end
  end
 end
end

function Rubble.clear()
 for root,ring in pairs(active) do remove(root,ring) end
end
return Rubble
