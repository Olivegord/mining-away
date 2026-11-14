-- The resting ore display is local and borrows its position from the pickup view.
local Display={}
local WHITE=Color3.new(1,1,1)
local SOFT_GLOW='rbxasset://textures/ui/AvatarExperience/glowLight.png'
local RAY_COLORS={Color3.fromRGB(255,166,217),Color3.fromRGB(128,222,244),Color3.fromRGB(192,244,165)}
local SWEEP,SEGMENTS=math.pi*2.16,4
local widths={.008,.044,.050,.030,.004}
local transparencies={1,.34,.05,.29,1}
local strandAlpha={}
for i=1,SEGMENTS do
 strandAlpha[i]={}
 for level=0,24 do
  local opacity=level/24
  strandAlpha[i][level]=NumberSequence.new({NumberSequenceKeypoint.new(0,1-(1-transparencies[i])*opacity),
   NumberSequenceKeypoint.new(1,1-(1-transparencies[i+1])*opacity)})
 end
end

local function glowImage(parent,name,size)
 local image=Instance.new('ImageLabel');image.Name=name;image.Image=SOFT_GLOW
 image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.5)
 image.Size=UDim2.fromScale(size,size);image.BackgroundTransparency=1;image.Parent=parent
 return image
end

function Display.new(parent,slot)
 local base=Instance.new('Part');base.Name='OreDisplay';base.Anchored=true
 base.Transparency=1;base.CastShadow=false;base.CanCollide=false;base.CanTouch=false;base.CanQuery=false
 local surface=Instance.new('SurfaceGui');surface.Name='GroundGlow';surface.Face=Enum.NormalId.Top
 surface.CanvasSize=Vector2.new(160,160);surface.LightInfluence=0;surface.Brightness=1.8
 surface.Enabled=false;surface.Parent=base
 local halo=glowImage(surface,'Halo',1)
 local core=glowImage(surface,'Hotspot',.47)
 local outline=Instance.new('Highlight');outline.Name='OreOutline';outline.DepthMode=Enum.HighlightDepthMode.Occluded
 outline.FillTransparency=1;outline.Enabled=false;outline.Parent=base
 local points,curves,motes={},{},{}
 for i=1,SEGMENTS+1 do
  local point=Instance.new('Attachment');point.Name='OreStrandPoint';point.Parent=base;points[i]=point
 end
 for i=1,SEGMENTS do
  local beam=Instance.new('Beam');beam.Name='OreStrand';beam.Attachment0=points[i];beam.Attachment1=points[i+1]
  beam.FaceCamera=true;beam.Segments=9;beam.LightEmission=.9;beam.LightInfluence=0
  beam.Enabled=false;beam.Parent=base;curves[i]=beam
 end
 for i=1,5 do motes[i]=EnergyDisc.sprite(base,'RisingOreMote') end
 local rays={}
 for i=1,3 do
  local a=Instance.new('Attachment');a.Name='DiamondRayStart';a.Parent=base
  local b=Instance.new('Attachment');b.Name='DiamondRayEnd';b.Parent=base
  local beam=Instance.new('Beam');beam.Name='DiamondPrismRay';beam.Attachment0=a;beam.Attachment1=b
  beam.FaceCamera=true;beam.LightEmission=1;beam.LightInfluence=0;beam.Segments=1
  beam.Texture=SOFT_GLOW;beam.TextureMode=Enum.TextureMode.Stretch;beam.TextureSpeed=0
  beam.Color=ColorSequence.new(RAY_COLORS[i],WHITE)
  beam.Width0=.09;beam.Width1=.025;beam.Enabled=false;beam.Parent=base
  rays[i]={a=a,b=b,beam=beam}
 end
 base.Parent=parent
 -- Separate overlapping translucent ground sprites by a small, stable depth.
 return {base=base,surface=surface,halo=halo,core=core,outline=outline,points=points,curves=curves,motes=motes,
  rays=rays,groundOffset=Vector3.yAxis*((slot-1)*.004)}
end

function Display.hide(rig)
 rig.outline.Enabled=false;rig.surface.Enabled=false
 for _,ray in ipairs(rig.rays) do ray.beam.Enabled=false end
 if rig.rings then RockModifierView.drawRings(rig.rings,0,0) end
 for _,beam in ipairs(rig.curves) do beam.Enabled=false end
 for _,mote in ipairs(rig.motes) do mote.gui.Enabled=false end
end

function Display.draw(rig,record,ground,now,strength,reducedMotion,reducedEffects)
 local tint=record.effectColor or record.color
 if rig.record~=record or rig.tint~=tint then
  rig.record=record
  rig.tint=tint
  rig.scale=record.physical and 1 or .73
  rig.base.Size=Vector3.new(5.7,.02,5.7)*rig.scale
  rig.outline.Adornee=record.view
  rig.outline.OutlineColor=tint:Lerp(WHITE,.25)
  rig.halo.ImageColor3=tint:Lerp(WHITE,.10);rig.core.ImageColor3=tint:Lerp(WHITE,.62)
  rig.moteColor=tint:Lerp(WHITE,.14)
  local strand=ColorSequence.new(tint:Lerp(WHITE,.32))
  for i,beam in ipairs(rig.curves) do
   beam.Color=strand;beam.Width0=widths[i]*rig.scale;beam.Width1=widths[i+1]*rig.scale
  end
 end
 if strength<=.02 then Display.hide(rig);return end
 local scale=rig.scale
 ground+=rig.groundOffset
 if rig.base.Position~=ground then rig.base.Position=ground end
 rig.outline.OutlineTransparency=1-strength*.94
 rig.outline.Enabled=record.view.Parent~=nil and record.view.Transparency<1
 rig.halo.ImageTransparency=1-strength*(reducedEffects and .37 or .83)
 rig.core.ImageTransparency=1-strength*(reducedEffects and .49 or .98)
 rig.surface.Enabled=true
 local mask=record.modifiers or 0
 if mask~=0 and not rig.rings then rig.rings=RockModifierView.groundRings(rig.surface) end
 if rig.rings then RockModifierView.drawRings(rig.rings,mask,strength) end

 -- Three short facet rays, attached to Diamond's body, with staggered slow
 -- breaths. Reused with the display pool and disabled by Reduced Effects.
 local diamond=record.view:GetAttribute('GemKind')=='Diamond'
 for i,ray in ipairs(rig.rays) do
  ray.beam.Enabled=diamond and not reducedEffects
  if ray.beam.Enabled then
   local angle=i*2.399+record.seed*.31
   local start=record.view.CFrame:PointToWorldSpace(record.view.Size*Vector3.new(math.cos(angle)*.23,(i-2)*.22,math.sin(angle)*.23))
   ray.a.Position=start-ground
   ray.b.Position=ray.a.Position+Vector3.new(math.cos(angle),.22*(i-2),math.sin(angle))*(1.15+i*.2)
   local power=strength*(reducedMotion and .4 or (.25+.32*(.5+.5*math.sin(now*.9+i*2.1))^3))
   ray.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.16,1-power),NumberSequenceKeypoint.new(1,1)})
  end
 end
 local phase=(reducedMotion and 0 or now*1.5)+record.seed*1.47
 if not reducedEffects then
  -- Adjacent cubic segments share the helix's tangent and width at each join.
  local radius=1.57;local taper=-.84;local rise=1.52
  for i,point in ipairs(rig.points) do
   local t=(i-1)/SEGMENTS;local angle=phase+t*SWEEP
   local c,s=math.cos(angle),math.sin(angle);local reach=radius+taper*t
   local derivative=Vector3.new(taper*c-SWEEP*reach*s,rise,taper*s+SWEEP*reach*c)*scale
   local right=derivative.Unit;local back=right:Cross(Vector3.yAxis).Unit
   point.CFrame=CFrame.fromMatrix(Vector3.new(c*reach,.17+rise*t,s*reach)*scale,right,back:Cross(right),back)
   local handle=derivative.Magnitude/(SEGMENTS*3)
   if i<=SEGMENTS then rig.curves[i].CurveSize0=handle end
   if i>1 then rig.curves[i-1].CurveSize1=handle end
  end
  local alpha=math.floor(strength*24+.5)
  for i,beam in ipairs(rig.curves) do beam.Transparency=strandAlpha[i][alpha];beam.Enabled=true end
 else
  for _,beam in ipairs(rig.curves) do beam.Enabled=false end
 end
 for i,mote in ipairs(rig.motes) do
  if reducedEffects or reducedMotion then mote.gui.Enabled=false
  else
   local cycle=now*(.53+i*.039)+i*.191+record.seed*.137
   if record.displayLandedAt then
    -- Start the first motes at the floor, staggered through the contact beat.
    cycle=math.max(0,now-record.displayLandedAt-(i-1)*.038)*(.61+i*.065)
   end
   local t=cycle%1
   local angle=record.seed*.97+i*2.399963+t*1.05
   local reach=(.40+(i%3)*.31)*(1-.30*t)
   angle+=.24*math.sin(t*math.pi*2+i)
   local position=ground+Vector3.new(math.cos(angle)*reach,.30+4.3*t,math.sin(angle)*reach)*scale
   local diameter=.45+((record.seed*17+i*73+math.floor(cycle)*41)%101)*.004
   local remaining=1-t
   local tint=rig.moteColor:Lerp(record.color:Lerp(Color3.fromRGB(119,62,166),.24),t*t)
   local opacity=(1-math.exp(-t*18))*math.sqrt(remaining)*strength*.82
   EnergyDisc.place(mote,position,diameter*scale*remaining,tint,opacity)
  end
 end
end

return Display
