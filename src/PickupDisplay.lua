-- The resting ore display is local and borrows its position from the pickup view.
local Display={}
local WHITE=Color3.new(1,1,1)
local SOFT_GLOW='rbxasset://textures/ui/AvatarExperience/glowLight.png'
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
 base.Parent=parent
 -- Separate overlapping translucent ground sprites by a small, stable depth.
 return {base=base,surface=surface,halo=halo,core=core,outline=outline,points=points,curves=curves,motes=motes,
  groundOffset=Vector3.yAxis*((slot-1)*.004)}
end

function Display.hide(rig)
 rig.outline.Enabled=false;rig.surface.Enabled=false
 for _,beam in ipairs(rig.curves) do beam.Enabled=false end
 for _,mote in ipairs(rig.motes) do mote.gui.Enabled=false end
end

function Display.draw(rig,record,ground,now,strength,reducedMotion,reducedEffects)
 if rig.record~=record then
  rig.record=record
  rig.scale=record.physical and 1 or .73
  rig.base.Size=Vector3.new(5.7,.02,5.7)*rig.scale
  rig.outline.Adornee=record.view
  rig.outline.OutlineColor=record.color:Lerp(WHITE,.25)
  rig.halo.ImageColor3=record.color:Lerp(WHITE,.10);rig.core.ImageColor3=record.color:Lerp(WHITE,.62)
  rig.moteColor=record.color:Lerp(WHITE,.14)
  local strand=ColorSequence.new(record.color:Lerp(WHITE,.32))
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
   local t=cycle%1
   local angle=record.seed*.97+i*2.399963+t*1.05
   local reach=(.40+(i%3)*.31)*(1-.30*t)
   local position=ground+Vector3.new(math.cos(angle)*reach,.21+2.24*t,math.sin(angle)*reach)*scale
   local envelope=math.min(t/.16,1,(1-t)/.28)
   local diameter=.24+((record.seed*17+i*73+math.floor(cycle)*41)%101)*.003
   EnergyDisc.place(mote,position,diameter*scale*math.max(.02,envelope),rig.moteColor,math.sqrt(envelope)*strength*.82)
  end
 end
end

return Display
