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
local arcs={
 -- Angle, reach, bend, lifetime and thickness. Each stroke keeps its own arc.
 {.11,6.6, .42,.68,.29}, {1.10,4.4,-.36,.44,.14},
 {2.03,6.0, .56,.62,.23}, {2.85,3.9,-.22,.34,.12},
 {3.74,7.0,-.46,.71,.31}, {4.56,4.7, .31,.49,.16},
 {5.34,5.6, .52,.56,.22},
}
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

function FX.impact(parent,point,normal,scale,at,orbital)
 if contactCount>=8 or BeamVFX.reduced() or not BeamVFX.near(point,125) then return end
 local p=palette(orbital)
 local root=Instance.new('Part');root.Name=orbital and 'OrbitalImpactArtwork' or 'RamielImpactArtwork'
 root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.CastShadow=false
 root.Size=Vector3.one*.025;root.Transparency=1
 local center=point+normal*.24
 root.CFrame=CFrame.lookAt(center,center+normal);root.Parent=parent
 local state={center=center,at=at,scale=scale,arcs={},flash={},normal=normal,
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
 for i=1,#arcs do
  local tip=i%3==0 and p.cold or p.ember
  local stroke=ribbon(root,'PeelingImpactStroke',ColorSequence.new(p.hot,tip),.82)
  stroke.beam.Segments=14
  state.arcs[i]=stroke
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
   local q=math.clamp(age/shape[4],0,1)
   line.beam.Enabled=q<1
   if q>=1 then continue end
   local angle=shape[1]
   local radial=state.right*math.cos(angle)+state.up*math.sin(angle)
   local tangent=-state.right*math.sin(angle)+state.up*math.cos(angle)
   local curve=tangent*shape[3]-radial*.26
   local lift=state.normal*(.55+.16*(i%3))
   local reach=shape[2]*scale
   local head=1-(1-q)^2.25
   local tail=math.max(0,head-(.14+.51*(1-q)))
   local span=head-tail
   -- Exact cubic sub-curve between the moving head and its shorter-lived tail.
   local function frame(u)
    local point=state.center+reach*(radial*u+curve*u^3+lift*u*(1-u))
    local derivative=reach*(radial+curve*(3*u*u)+lift*(1-2*u))
    return tangentFrame(point,derivative),derivative.Magnitude*span/3
   end
   local first,c0=frame(tail)
   local last,c1=frame(head)
   line.a.WorldCFrame=first;line.b.WorldCFrame=last
   local fade=(1-q)^.68
   line.beam.CurveSize0=c0;line.beam.CurveSize1=c1
   line.beam.Width0=scale*shape[5]*fade;line.beam.Width1=.012*scale*fade
   line.beam.Transparency=opacity(1,1-fade*.86,1-fade*.96,1-fade*.44)
  end
 end
end
return FX
