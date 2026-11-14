-- Scrolling beam textures and contact effects for Orbital and Ramiel.
local FX={}
local Players=game:GetService('Players')
local WHITE=Color3.fromRGB(255,253,235)
local FIRE='rbxasset://textures/particles/fire_main.dds'
local FOLD='rbxasset://textures/particles/forcefield_vortex_main.dds'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local ORBITAL={
 shadow=Color3.fromRGB(51,16,92),edge=Color3.fromRGB(155,61,255),hot=Color3.fromRGB(255,84,217),
 cold=Color3.fromRGB(99,231,255),ember=Color3.fromRGB(255,197,112),smoke=Color3.fromRGB(47,37,57),
}
local PRISM={
 shadow=Color3.fromRGB(71,9,31),edge=Color3.fromRGB(255,26,92),hot=Color3.fromRGB(255,80,188),
 cold=Color3.fromRGB(142,230,255),ember=Color3.fromRGB(255,223,124),smoke=Color3.fromRGB(54,34,42),
}
local function palette(orbital) return orbital and ORBITAL or PRISM end
local function opacity(a,b,c,d)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.18,b),
  NumberSequenceKeypoint.new(.77,c),NumberSequenceKeypoint.new(1,d)})
end
local function ribbon(root,name,colors,light)
 local a=Instance.new('Attachment');a.Parent=root
 local b=Instance.new('Attachment');b.Parent=root
 local beam=Instance.new('Beam');beam.Name=name;beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.LightInfluence=0;beam.LightEmission=light
 beam.Color=colors;beam.Enabled=false;beam.Parent=root
 return {a=a,b=b,beam=beam}
end

local surfaceCount=0
function FX.surface(root,orbital)
 if BeamVFX.reduced() or surfaceCount>=8 then return nil end
 surfaceCount+=1
 root.Destroying:Connect(function() surfaceCount-=1 end)
 local p=palette(orbital)
 local layers={
  ribbon(root,'RollingDarkFilaments',ColorSequence.new(p.shadow,p.edge),0),
  ribbon(root,'StreamingFlame',ColorSequence.new(p.edge,p.hot),.57),
  ribbon(root,'StreamingHotFolds',ColorSequence.new(p.hot,WHITE),.85),
  ribbon(root,'ChromaticFringe',ColorSequence.new(p.cold,p.hot),.78),
 }
 for i,line in ipairs(layers) do
  local beam=line.beam
  beam.Texture=i<=2 and FIRE or FOLD
  beam.TextureMode=Enum.TextureMode.Wrap
  beam.TextureLength=(i==1 and 13 or i==2 and 8.7 or i==3 and 6.2 or 11.1)*(orbital and 1.6 or 1)
  beam.TextureSpeed=0
  beam.Segments=12
  beam.ZOffset=(i-2)*.018
 end
 return layers
end

function FX.poseSurface(layers,from,to,width,age,alpha)
 if not layers then return end
 local delta=to-from
 local active=alpha>.01 and delta.Magnitude>.05 and not BeamVFX.reduced()
 for _,line in ipairs(layers) do line.beam.Enabled=active end
 if not active then return end
 local axis=delta.Unit
 local camera=workspace.CurrentCamera
 local eye=camera and camera.CFrame.Position-from or Vector3.zAxis
 local side=axis:Cross(eye)
 if side.Magnitude<.001 then side=axis:Cross(math.abs(axis.Y)>.95 and Vector3.zAxis or Vector3.yAxis) end
 side=side.Unit
 for i,line in ipairs(layers) do
  local beam=line.beam
  local s=i%2==0 and -1 or 1
  local widthScale=i==1 and 2.0 or i==2 and 1.64 or i==3 and .91 or .37
  local phase=age*(1.8+i*.49)
  local flow=age*(i==1 and .91 or i==2 and 2.32 or i==3 and 1.67 or 2.85)
  local shift=width*(i==4 and .38 or .16)*s
  line.a.WorldPosition=from+side*shift
  line.b.WorldPosition=to
  beam.Width0=width*widthScale*(.89+.11*math.sin(phase+i*2))
  beam.Width1=width*widthScale*(.44+.12*math.sin(phase*.77+i))
  local strength=alpha*(i==1 and .67 or i==2 and .93 or i==3 and .89 or .62)
  if line.strength~=strength then
   line.strength=strength
   beam.Transparency=opacity(1,1-strength,1-strength*.94,1-strength*.23)
  end
  -- Sample from the attack clock so all layers continue through a dropped frame.
  beam:SetTextureOffset((.37*i-flow)%1)
 end
end

local contacts={}
local contactCount=0
local UP=Vector3.yAxis
local arcs={
 -- Heading, ground reach, lift, sideways curl, flight time, width.
 {.14,20,12, 5.0,.57,.61}, {1.10,13, 8,-3.8,.43,.34},
 {2.04,18,17, 4.1,.62,.53}, {2.86,11, 9,-3.2,.47,.31},
 {3.68,23,13,-5.4,.66,.72}, {4.57,14, 7, 3.6,.46,.33},
 {5.39,17,10, 4.2,.53,.47},
}
local function groundQuery()
 local world=workspace:FindFirstChild('MiningAway')
 local map=world and world:FindFirstChild('Map')
 local terrain=workspace:FindFirstChildOfClass('Terrain')
 local surfaces={}
 if map then surfaces[#surfaces+1]=map end
 if terrain then surfaces[#surfaces+1]=terrain end
 if #surfaces==0 then return nil end
 local query=RaycastParams.new()
 query.FilterType=Enum.RaycastFilterType.Include
 query.FilterDescendantsInstances=surfaces
 query.RespectCanCollide=true
 return query
end
local function trajectory(start,floor,shape,scale,query)
 local radial=Vector3.new(math.cos(shape[1]),0,math.sin(shape[1]))
 local side=UP:Cross(radial)
 local aim=floor+radial*shape[2]*scale
 local hit=query and workspace:Raycast(aim+UP*24,-UP*60,query)
 local last=(hit and hit.Position or aim)+UP*.13
 local height=shape[3]*scale
 local curl=side*shape[4]*scale
 local firstControl=start+radial*shape[2]*scale*.09+UP*height*1.48+curl*.58
 local lastControl=last-radial*shape[2]*scale*.22+UP*height*.98+curl
 return {start,firstControl,lastControl,last}
end
local flashAngles={.21,1.49,2.81,3.91,5.11}
local flashLengths={1.45,3.3,1.6,1.4,2.7}
local function tangentFrame(point,tangent)
 local axis=tangent.Unit
 local ref=math.abs(axis.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=axis:Cross(ref).Unit
 return CFrame.fromMatrix(point,axis,back:Cross(axis),back)
end
local function emitSmoke(root,p,scale)
 for i=1,2 do
  local dust=Instance.new('ParticleEmitter');dust.Name=i==1 and 'RollingSmoke' or 'SmokeFilaments'
  EnergyDisc.configure(dust,(i==1 and 4.1 or 2.8)*scale,i==1 and .25 or .43,.40,2.0,.31)
  dust.Texture=i==1 and SMOKE or FIRE
  dust.LightEmission=0;dust.Color=ColorSequence.new(i==1 and p.smoke or p.shadow,p.smoke)
  dust.EmissionDirection=Enum.NormalId.Front;dust.SpreadAngle=Vector2.new(82,82)
  dust.Speed=NumberRange.new(8*scale,19*scale);dust.Drag=3.3
  dust.Acceleration=Vector3.yAxis*2.1
  dust.Lifetime=NumberRange.new(.65,i==1 and 1.8 or 1.25)
  dust.Rotation=NumberRange.new(-180,180);dust.RotSpeed=NumberRange.new(-32,32)
  dust.Enabled=false;dust.Rate=0;dust.Parent=root;dust:Emit(i==1 and 8 or 5)
 end
end

function FX.impact(parent,point,normal,scale,at,orbital,ground)
 if contactCount>=8 or BeamVFX.reduced() or not BeamVFX.near(point,125) then return end
 local p=palette(orbital)
 local root=Instance.new('Part');root.Name=orbital and 'OrbitalImpactArtwork' or 'RamielImpactArtwork'
 root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.CastShadow=false
 root.Size=Vector3.one*.025;root.Transparency=1
 local center=point+normal*.24
 root.CFrame=CFrame.lookAt(center,center+normal);root.Parent=parent
 local state={center=center,at=at,scale=scale,arcs={},flash={},
  glow=EnergyDisc.sprite(root,'ContactWhiteFlash')}
 local ref=math.abs(normal.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 state.right=normal:Cross(ref).Unit;state.up=state.right:Cross(normal)
 contactCount+=1;contacts[root]=state
 root.Destroying:Connect(function() contacts[root]=nil;contactCount-=1 end)
 local player=Players.LocalPlayer
 local lowFlash=player and player:GetAttribute('ReducedFlashing')==true
 if not lowFlash then
  local light=Instance.new('PointLight')
  light.Color=p.hot;light.Range=16*scale;light.Brightness=0;light.Parent=root;state.light=light
  for i=1,#flashAngles do
   state.flash[i]=ribbon(root,'ImpactFlashRay',ColorSequence.new(WHITE,i%2==0 and p.ember or p.cold),1)
  end
 end
 if ground then
  local query=groundQuery()
  for i,shape in ipairs(arcs) do
   local tip=i%3==0 and p.cold or p.ember
   local colors=ColorSequence.new({
    ColorSequenceKeypoint.new(0,p.edge),ColorSequenceKeypoint.new(.56,p.hot),
    ColorSequenceKeypoint.new(.90,tip),ColorSequenceKeypoint.new(1,WHITE),
   })
   local stroke=ribbon(root,'GroundingImpactTendril',colors,.86)
   stroke.beam.Segments=22
   stroke.points=trajectory(center,ground,shape,scale,query)
   state.arcs[i]=stroke
  end
 end
 emitSmoke(root,p,scale)
 for i,hue in ipairs({p.ember,p.hot,p.cold}) do
  local sparks=EnergyDisc.accent(root,'HotImpactSparks',hue,(i==1 and .21 or .13)*scale,
   'streak',Enum.NormalId.Front,77)
  sparks.Speed=NumberRange.new(13*scale,29*scale);sparks.Drag=3.8
  sparks.Lifetime=NumberRange.new(.20,.56)
  sparks:Emit(i==1 and 10 or 6)
 end
end

function FX.step(now)
 for root,state in pairs(contacts) do
  local age=math.max(0,now-state.at)
  if age>=1.9 or BeamVFX.reduced() then root:Destroy();continue end
  local player=Players.LocalPlayer
  local lowFlash=player and player:GetAttribute('ReducedFlashing')==true
  local flash=lowFlash and 0 or (1-math.clamp(age/.16,0,1))^2
  local scale=state.scale
  local kick=(1-math.exp(-age*58))
  EnergyDisc.place(state.glow,state.center,scale*(.52+kick*1.52),WHITE,flash*.96)
  if state.light then state.light.Brightness=flash*5.6 end
  for i,line in ipairs(state.flash) do
   local angle=flashAngles[i]
   local ray=state.right*math.cos(angle)+state.up*math.sin(angle)
   line.beam.Enabled=flash>.012
   if line.beam.Enabled then
    line.a.WorldPosition=state.center
    line.b.WorldPosition=state.center+ray*scale*flashLengths[i]*(.36+.64*kick)
    line.beam.Width0=scale*(.07+.21*flash);line.beam.Width1=0
    line.beam.Transparency=opacity(1-flash,1-flash*.95,1-flash*.65,1)
   end
  end
  for i,line in ipairs(state.arcs) do
   local shape=arcs[i]
   local flight=shape[5]
   local launch=(i-1)*.012
   local elapsed=age-launch
   local decay=math.clamp((elapsed-flight)/.32,0,1)
   line.beam.Enabled=elapsed>0 and decay<1
   if not line.beam.Enabled then continue end
   local progress=math.clamp(elapsed/flight,0,1)
   local head=progress*progress*(3-2*progress)
   local tail=.97*decay
   local span=head-tail
   local start,first,last,finish=table.unpack(line.points)
   -- Tangents at the clipped endpoints preserve the exact cubic curve.
   local function frame(u)
    local v=1-u
    local point=start*(v^3)+first*(3*v*v*u)+last*(3*v*u*u)+finish*(u^3)
    local derivative=(first-start)*(3*v*v)+(last-first)*(6*v*u)+(finish-last)*(3*u*u)
    return tangentFrame(point,derivative),derivative.Magnitude*span/3
   end
   local from,c0=frame(tail)
   local to,c1=frame(head)
   line.a.WorldCFrame=from;line.b.WorldCFrame=to
   local fade=(1-decay)^1.3
   local width=scale*shape[6]*fade
   line.beam.CurveSize0=c0;line.beam.CurveSize1=c1
   line.beam.Width0=width;line.beam.Width1=width*.12
   line.beam.Transparency=opacity(1-fade*.57,1-fade*.89,1-fade*.97,1-fade*.75)
  end
 end
end
return FX
