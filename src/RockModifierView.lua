-- Modifier effects frame the existing mineral and follow its authoritative events.
local V={}
local bits=Mining.ROCK_MODIFIERS
local charged=Color3.fromRGB(255,200,63)
local frost=Color3.fromRGB(135,225,255)
local dust=Color3.fromRGB(222,162,106)
local white=Color3.fromRGB(249,251,255)
local icons={
 {bit=bits.Charged,name='Charged',color=charged},
 {bit=bits.Frosted,name='Frosted',color=frost},
 {bit=bits.Massive,name='Massive',color=dust},
}
local square='rbxasset://textures/particles/SquareParticle.png'
local smoke='rbxasset://textures/particles/smoke_main.dds'
local star='rbxassetid://77624818077620'
local ringTexture='rbxasset://textures/ui/AvatarExperience/AxisRing.png'
local activeArcs,activeBreaks=0,0

function V.glow(mask)
 for _,entry in ipairs(icons) do
  if bit32.btest(mask,entry.bit) then return entry.color end
 end
end

-- Selection is a surface flash. Leave the limited Highlight slots for attack
-- outlines, and let the underlying damage and rock finish continue updating.
function V.clearSelectionFlash(r)
 local previous=r.selectionColor
 if not previous then return end
 r.view.Color=previous;r.selectionColor=nil
 if r.stoneGradient then RockFinish.setVisibility(r.stoneGradient,r.view.Transparency) end
end

function V.attackOutlines(records,_camera,now,steady,selection,strength,width)
 for _,r in pairs(records) do
  local outline=r.rockOutline
  local visible=not r.visual.broken and r.view.Parent and r.view.Transparency<1
   and (r.view.LocalTransparencyModifier or 0)<1
  local attacked=visible and now-math.max(r.lastBeamAt or -math.huge,r.lastHitAt or -math.huge)<=.72
  local selected=visible and selection and r.source:GetAttribute('FieldId')==selection.field
   and Mining.selectorContains(selection.point,(width or selection.width)*.5,r.source:GetAttribute('FullPosition') or r.source.Position)
  if selected and strength>0 then
   r.selectionColor=r.view.Color
   r.view.Color=r.selectionColor:Lerp(white,strength)
   if r.stoneGradient then RockFinish.setVisibility(r.stoneGradient,math.max(r.view.Transparency,strength)) end
  end
  if not attacked then
   if outline then outline:Destroy();r.rockOutline=nil end
  else
   if not outline then
    outline=Instance.new('Highlight');outline.Name='MiningRockFeedback'
    outline.DepthMode=Enum.HighlightDepthMode.Occluded;outline.Adornee=r.view
    outline.OutlineColor=r.baseColor:Lerp(white,.66);outline.FillColor=Color3.new(1,1,1)
    outline.Parent=r.view;r.rockOutline=outline
   end
   r.outlineStart=r.outlineStart or now
   local wave=steady and .5 or .5+.5*math.cos((now-r.outlineStart)*7.5)
   outline.OutlineTransparency=.50-.43*wave
   outline.FillTransparency=1
  end
  if not attacked then r.outlineStart=nil end
 end
end

local function carrier(parent,name)
 local p=Instance.new('Part')
 p.Name=name;p.Size=Vector3.one*.05;p.Anchored=true;p.Transparency=1
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Parent=parent
 return p
end

function V.groundRings(gui)
 local shadow=Instance.new('ImageLabel');shadow.Name='OuterContour'
 shadow.BackgroundTransparency=1;shadow.Image=ringTexture;shadow.ImageColor3=Color3.fromRGB(48,43,58)
 shadow.AnchorPoint=Vector2.new(.5,.5);shadow.Position=UDim2.fromScale(.5,.5)
 shadow.ZIndex=1;shadow.Visible=false;shadow.Parent=gui
 local rings={shadow=shadow}
 for i,entry in ipairs(icons) do
  local image=Instance.new('ImageLabel');image.Name=entry.name..'Ring'
  image.BackgroundTransparency=1;image.Image=ringTexture;image.ImageColor3=entry.color
  image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.5);image.Visible=false
  image.ZIndex=2;image.Parent=gui;rings[i]=image
 end
 return rings
end

function V.drawRings(rings,mask,strength)
 -- The dark outer contour keeps the bright rings legible on pale ground.
 local index=0
 for i,entry in ipairs(icons) do
  local image=rings[i]
  local visible=strength>.02 and bit32.btest(mask,entry.bit)
  if image.Visible~=visible then image.Visible=visible end
  if visible then
   index+=1
   local scale=.59+(index-1)*.14
   local size=UDim2.fromScale(scale,scale)
   local alpha=1-strength*(.81-(index-1)*.09)
   if image.Size~=size then image.Size=size end
   if image.ImageTransparency~=alpha then image.ImageTransparency=alpha end
  end
 end
 local shadow=rings.shadow
 shadow.Visible=index>0
 if index>0 then
  local scale=.65+(index-1)*.14
  local size=UDim2.fromScale(scale,scale)
  local alpha=1-strength*.72
  if shadow.Size~=size then shadow.Size=size end
  if shadow.ImageTransparency~=alpha then shadow.ImageTransparency=alpha end
 end
end

local styles={
 spark={name='ElectricSparks',texture=square,light=1,size=.19,life={.055,.13},speed={29,76},squash=2.1,
  color=Color3.fromRGB(255,233,151),spread=103,gravity=-41,drag=.65,hard=true},
 ember={name='HotSparkFragments',texture=square,light=.68,size=.095,life={.11,.29},speed={9,31},squash=.8,
  color=Color3.fromRGB(255,154,38),spread=93,gravity=-37,drag=2,hard=true},
 frost={name='SnowFlurry',texture=star,light=.26,size=.45,life={.84,1.70},speed={2.2,6},
  color=white,endColor=frost,spread=77,gravity=-2,drag=1.65},
 sleet={name='IceSpray',texture=square,light=.30,size=.22,life={.22,.64},speed={12,29},squash=1.2,
  color=Color3.fromRGB(208,249,255),endColor=frost,spread=102,gravity=-22,drag=3},
 grit={name='HeavyGrit',texture=square,light=0,size=.22,life={.19,.56},speed={6,18},
  color=dust,endColor=Color3.fromRGB(149,105,81),spread=97,gravity=-29,drag=1.3},
 ionSmoke={name='ArcSmoke',texture=smoke,light=0,size=3.6,life={.77,1.72},speed={1.4,5.4},
  color=Color3.fromRGB(131,104,79),endColor=Color3.fromRGB(101,83,89),spread=64,gravity=.65,drag=1.9,cloud=true,alpha=.72},
 mist={name='ColdMist',texture=smoke,light=.08,size=4.55,life={1.05,2.74},speed={1.2,5.5},
  color=Color3.fromRGB(206,243,255),endColor=Color3.fromRGB(106,166,211),spread=77,gravity=.40,drag=2.25,cloud=true,alpha=.63},
 powder={name='StoneDust',texture=smoke,light=0,size=4.1,life={.86,2.20},speed={2.3,7.3},
  color=Color3.fromRGB(191,152,120),endColor=Color3.fromRGB(124,95,87),spread=96,gravity=.25,drag=2.85,cloud=true,alpha=.66},
}

local function emitter(parent,key,scale)
 local style=styles[key]
 local diameter=style.size*scale
 local p=Instance.new('ParticleEmitter')
 p.Name=style.name;p.Enabled=false;p.Rate=0;p.Texture=style.texture
 p.Color=ColorSequence.new(style.color,style.endColor or style.color)
 if style.hard then
  p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,diameter,diameter*.40),
   NumberSequenceKeypoint.new(1,diameter,diameter*.40)})
  p.Transparency=NumberSequence.new(0)
 elseif style.cloud then
  p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,diameter*.36),
   NumberSequenceKeypoint.new(.25,diameter,diameter*.26),NumberSequenceKeypoint.new(1,diameter*1.68)})
  p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.16,style.alpha),
   NumberSequenceKeypoint.new(.52,style.alpha+.10),NumberSequenceKeypoint.new(1,1)})
  p.ZOffset=-1.1*scale
 else
  p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,diameter,diameter*.40),
   NumberSequenceKeypoint.new(.55,diameter*.82),NumberSequenceKeypoint.new(1,0)})
  p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.10),NumberSequenceKeypoint.new(.55,.29),NumberSequenceKeypoint.new(1,1)})
 end
 p.LightEmission=style.light;p.LightInfluence=style.cloud and .38 or .10
 p.Lifetime=NumberRange.new(table.unpack(style.life));p.Speed=NumberRange.new(table.unpack(style.speed))
 p.Drag=style.drag;p.Acceleration=Vector3.yAxis*style.gravity;p.WindAffectsDrag=false
 p.SpreadAngle=Vector2.new(style.spread,style.spread)
 if style.squash then
  p.Orientation=Enum.ParticleOrientation.VelocityParallel;p.Squash=NumberSequence.new(style.squash)
 else
  p.Rotation=NumberRange.new(-180,180);p.RotSpeed=NumberRange.new(-55,63)
 end
 p.Parent=parent
 return p
end

local function prepare(view,state,mask,scale)
 if not state.air then
  state.air=Instance.new('Attachment');state.air.Name='ModifierParticles';state.air.Parent=view
  state.haze=Instance.new('Attachment');state.haze.Name='ModifierHaze';state.haze.Parent=view
 end
 for _,entry in ipairs(icons) do
  local enabled=bit32.btest(mask,entry.bit)
  local group=state[entry.name]
  if enabled and not group then
   if entry.bit==bits.Charged then
    group={spark=emitter(state.air,'spark',scale),fragments=emitter(state.air,'ember',scale),smoke=emitter(state.haze,'ionSmoke',scale)}
   elseif entry.bit==bits.Frosted then
    group={flakes=emitter(state.air,'frost',scale),sleet=emitter(state.air,'sleet',scale),mist=emitter(state.haze,'mist',scale)}
   else
    group={grit=emitter(state.air,'grit',scale),dust=emitter(state.haze,'powder',scale)}
   end
   state[entry.name]=group
  elseif not enabled and group then
   for _,p in pairs(group) do p:Destroy() end
   state[entry.name]=nil
  end
 end
end

local function point(parent,position)
 local a=Instance.new('Attachment');a.Position=position;a.Parent=parent
 return a
end

local function lightning(view,from,to,random,large,bend)
 if activeArcs>=8 or not view.Parent then return end
 local parent=carrier(view.Parent,'RockLightning')
 parent.Position=to
 activeArcs+=1
 parent.Destroying:Once(function() activeArcs-=1 end)
 local knots=large and 8 or 5
 local width=large and .16 or math.clamp(view.Size.Y*.038,.064,.18)
 local jitter=large and 2.30 or width*5
 local function line(a,b,weight)
  local beam=Instance.new('Beam');beam.Name='GoldEdge';beam.Attachment0=a;beam.Attachment1=b
  beam.Width0=width*2.45*weight;beam.Width1=width*1.94*weight
  beam.FaceCamera=true;beam.Segments=1;beam.LightEmission=.77;beam.LightInfluence=0
  beam.Color=ColorSequence.new(charged);beam.Transparency=NumberSequence.new(.42);beam.Parent=parent
  local core=beam:Clone();core.Name='WhiteCore'
  core.Width0=width*.72*weight;core.Width1=width*.53*weight;core.LightEmission=1
  core.Color=ColorSequence.new(white);core.Transparency=NumberSequence.new(.02);core.ZOffset=.035;core.Parent=parent
 end
 local previous=point(parent,from-to)
 for i=1,knots do
  local pos=if i==knots then Vector3.zero else (from-to)*(1-i/knots)
   +Vector3.new(random:NextNumber(-jitter,jitter),large and 0 or random:NextNumber(-jitter,jitter),random:NextNumber(-jitter,jitter))
  if bend then pos+=bend*math.sin(i/knots*math.pi) end
  local nextPoint=point(parent,pos)
  line(previous,nextPoint,1)
  if i==2 or i==knots-2 then
   local facing=i==2 and 1 or -1
   local elbow=point(parent,pos+Vector3.new(jitter*facing,-jitter*.57,jitter*.51))
   local tip=point(parent,pos+Vector3.new(jitter*1.9*facing,-jitter*1.42,-jitter*.14))
   line(nextPoint,elbow,.59);line(elbow,tip,.32)
  end
  previous=nextPoint
 end
 -- The white discharge ends abruptly while the gold edge contracts.
 local tween=game:GetService('TweenService')
 for _,beam in ipairs(parent:GetChildren()) do
  if beam:IsA('Beam') then
   local life=beam.Name=='WhiteCore' and .045 or .125
   tween:Create(beam,TweenInfo.new(life,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Width0=0,Width1=0}):Play()
  end
 end
 game:GetService('Debris'):AddItem(parent,.16)
end

local function behind(view,state,lower)
 local camera=workspace.CurrentCamera
 local direction=camera and view.Position-camera.CFrame.Position or Vector3.zAxis
 local flat=Vector3.new(direction.X,0,direction.Z)
 flat=flat.Magnitude>.01 and flat.Unit or Vector3.zAxis
 local width=math.min(view.Size.X,view.Size.Z)
 local origin=view.Position+flat*(width*.54)+Vector3.yAxis*(view.Size.Y*lower)
 state.haze.Position=state.haze.Parent.CFrame:PointToObjectSpace(origin)
end

local function electric(state,lowFlash,count)
 local group=state.Charged
 group.spark.Brightness=lowFlash and .58 or 2.15
 group.spark:Emit(lowFlash and math.ceil(count*.36) or count)
 group.fragments:Emit(lowFlash and math.ceil(count*.24) or math.ceil(count*.70))
end

local function arc(view,state,now,lowFlash,drop,strike)
 local size,frame,random=view.Size,view.CFrame,state.random
 local side=random:NextNumber()<.5 and -1 or 1
 local from,to,bend
 if strike then
  to=frame:PointToWorldSpace(Vector3.yAxis*(size.Y*.44))
  from=to+Vector3.new(-3,25,2)
 else
  local camera=workspace.CurrentCamera
  local eye=camera and frame:PointToObjectSpace(camera.CFrame.Position) or Vector3.zAxis
  local toward=Vector3.new(eye.X,0,eye.Z)
  toward=toward.Magnitude>.01 and toward.Unit or Vector3.zAxis
  local across=Vector3.yAxis:Cross(toward)*side
  from=frame:PointToWorldSpace((toward*.36+across*.32+Vector3.yAxis*.43)*size)
  to=frame:PointToWorldSpace((toward*.42-across*.42+Vector3.yAxis*.06)*size)
  -- Bow around the near face so the middle of the arc stays above the stone.
  bend=frame:VectorToWorldSpace((toward*.28+Vector3.yAxis*.15)*size)
 end
 if not lowFlash then lightning(view,from,to,random,strike==true,bend) end
 if not strike and not lowFlash then
  state.air.Position=frame:PointToObjectSpace(from)
  electric(state,false,drop and 3 or 6)
 end
 state.air.Position=frame:PointToObjectSpace(to)
 electric(state,lowFlash,strike and 28 or drop and 7 or 12)
 behind(view,state,-.17)
 state.Charged.smoke:Emit(strike and 5 or drop and 1 or 2)
 state.nextArcAt=now+random:NextNumber(1.65,3.3)
end

local function frostGust(view,state)
 local group=state.Frosted
 behind(view,state,-.23)
 state.air.Position=Vector3.new(-view.Size.X*.29,view.Size.Y*.17,0)
 state.air.CFrame*=CFrame.Angles(0,0,-1.05)
 group.flakes:Emit(12);group.sleet:Emit(13)
 state.air.CFrame=CFrame.new(state.air.Position)
 group.mist:Emit(9)
end

local function ambient(view,state,now,lowFlash,drop)
 local random=state.random
 if state.Charged and now>=(state.nextArcAt or 0) then arc(view,state,now,lowFlash,drop,false) end
 if now<(state.nextAt or 0) then return end
 state.nextAt=now+random:NextNumber(.55,.86)
 behind(view,state,-.29)
 local bearing=random:NextNumber(0,2*math.pi)
 local size=view.Size
 state.air.Position=Vector3.new(math.cos(bearing)*size.X*.37,size.Y*.18,math.sin(bearing)*size.Z*.37)
 if state.Frosted then
  state.Frosted.flakes:Emit(drop and 2 or 3)
  state.Frosted.mist:Emit(drop and 1 or 2)
 end
 if state.Massive and now>=(state.nextDustAt or 0) then
  state.nextDustAt=now+random:NextNumber(1.1,2.2)
  state.Massive.dust:Emit(drop and 1 or 2)
 end
end

local function burst(view,state,lowFlash,kind)
 local final=kind=='break'
 local ground=kind=='land'
 state.air.Position=Vector3.yAxis*(view.Size.Y*(ground and -.20 or .26))
 behind(view,state,ground and -.45 or -.26)
 if state.Charged then
  electric(state,lowFlash,final and 32 or ground and 12 or 9)
  state.Charged.smoke:Emit(final and 7 or 2)
 end
 if state.Frosted then
  state.Frosted.sleet:Emit(final and 23 or ground and 10 or 8)
  state.Frosted.flakes:Emit(final and 16 or 6)
  state.Frosted.mist:Emit(final and 12 or ground and 4 or 3)
 end
 if state.Massive then
  state.Massive.grit:Emit(final and 21 or 7)
  state.Massive.dust:Emit(final and 11 or ground and 5 or 4)
 end
 if final and activeBreaks<10 and view.Parent then
  -- The source rock expires before the cold breath. Keep the tails on a
  -- detached carrier in the same frame until the longest emitter has finished.
  local tail=carrier(view.Parent,'RockModifierFallout')
  tail.CFrame=view.CFrame
  local rings=state.ringBase
  if rings then
   rings.Parent=tail;rings.Rings.Enabled=true
   local target=Vector3.new(rings.Size.X*1.74,.02,rings.Size.Z*1.74)
   local tween=game:GetService('TweenService')
   local ease=TweenInfo.new(.43,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
   tween:Create(rings,ease,{Size=target}):Play()
   for _,image in pairs(state.rings) do tween:Create(image,ease,{ImageTransparency=1}):Play() end
   state.ringBase=nil
  end
  state.air.Parent=tail;state.haze.Parent=tail
  activeBreaks+=1
  tail.Destroying:Once(function() activeBreaks-=1 end)
  game:GetService('Debris'):AddItem(tail,2.8)
 end
end

function V.rock(record,now,lowFlash,eventKind)
 local mask=record.modifiers
 local view=record.view
 local state=record.modifierFX
 if not state then
  state={seen={},random=Random.new(record.source:GetAttribute('StageSeed') or 1)}
  record.modifierFX=state
 end
 local changed=state.mask~=mask
 if not changed and not eventKind and now<(state.checkAt or 0) then return end
 state.checkAt=now+.11
 if mask==0 then
  if state.ringBase then state.ringBase:Destroy() end
  if state.air then state.air:Destroy();state.haze:Destroy() end
  record.modifierFX=nil
  return
 end
 local near=BeamVFX.near(view.Position,84)
 local broken=record.visual.broken
 local visible=not broken and view.Transparency<1 and (view.LocalTransparencyModifier or 0)<1
 -- Mineral channels replace modifier silhouette and ground outlines.
 if not near or (not visible and eventKind~='break') or BeamVFX.reduced() then return end
 if broken and state.finished then return end
 if state.mask~=mask then
  prepare(view,state,mask,math.clamp(view.Size.Magnitude*.18,.83,1.32))
  state.mask=mask
 end
 for _,entry in ipairs(icons) do
  if entry.bit==bits.Massive or not bit32.btest(mask,entry.bit) then continue end
  local name=entry.name
  local at=record.source:GetAttribute(name..'At')
  if at and at~=state.seen[name] and now>=at then
   state.seen[name]=at
   if now-at<.55 and not broken then
    if entry.bit==bits.Charged then arc(view,state,now,lowFlash,false,true)
    else frostGust(view,state);state.nextAt=now+.55 end
   end
  end
 end
 if eventKind then
  if eventKind=='break' then state.finished=true end
  if eventKind=='break' and state.Charged and not lowFlash then
   local from=view.Position+Vector3.yAxis*(view.Size.Y*.44)
   local to=view.Position+view.CFrame.RightVector*(view.Size.X*.82)-Vector3.yAxis*(view.Size.Y*.19)
   lightning(view,from,to,state.random,false)
  end
  burst(view,state,lowFlash,eventKind)
 else ambient(view,state,now,lowFlash,false) end
end

function V.drop(record,now,landingAge,lowFlash)
 local state=record.modifierFX
 if not state then
  state={random=Random.new(record.seed)}
  record.modifierFX=state
 end
 local view=record.view
 if state.mask~=record.modifiers then
  prepare(view,state,record.modifiers,.65)
  state.mask=record.modifiers
 end
 if not state.landed then
  state.landed=true
  if landingAge<.28 then
   burst(view,state,lowFlash,'land')
   state.nextAt=now+.44
   state.nextArcAt=now+.72
  end
 end
 ambient(view,state,now,lowFlash,true)
end

local function icon(parent,entry,order)
 local frame=Instance.new('Frame')
 frame.Name=entry.name;frame.Size=UDim2.fromOffset(10,12)
 frame.BackgroundTransparency=1;frame.LayoutOrder=order;frame.Parent=parent
 local function stroke(x,y,width,height,rotation)
  local piece=Instance.new('Frame')
  piece.BorderSizePixel=0;piece.BackgroundColor3=entry.color;piece.AnchorPoint=Vector2.new(.5,.5)
  piece.Position=UDim2.fromOffset(x,y);piece.Size=UDim2.fromOffset(width,height);piece.Rotation=rotation
  piece.Parent=frame
 end
 if entry.bit==bits.Charged then
  stroke(4,4,2,6,33);stroke(5,6,6,2,0);stroke(6,8,2,6,33)
 elseif entry.bit==bits.Frosted then
  for angle=0,120,60 do stroke(5,6,1,10,angle) end
  stroke(5,6,4,4,45)
 else
  stroke(5,6,6,6,45);stroke(5,6,2,2,0)
 end
end

function V.dropLabel(view,material,mask)
 local gui=Instance.new('BillboardGui');gui.Name='OreLabel'
 gui.MaxDistance=44;gui.LightInfluence=0;gui.Size=UDim2.fromOffset(126,18)
 gui.StudsOffsetWorldSpace=Vector3.yAxis*(view.Size.Magnitude*.5+.34)
 gui.AlwaysOnTop=false;gui.Adornee=view
 local row=Instance.new('UIListLayout');row.FillDirection=Enum.FillDirection.Horizontal
 row.HorizontalAlignment=Enum.HorizontalAlignment.Center;row.VerticalAlignment=Enum.VerticalAlignment.Center
 row.SortOrder=Enum.SortOrder.LayoutOrder;row.Padding=UDim.new(0,3);row.Parent=gui
 local text=Instance.new('TextLabel');text.Name='Mineral';text.Text=material;text.TextSize=12;text.LayoutOrder=0
 text.AutomaticSize=Enum.AutomaticSize.X;text.Size=UDim2.fromOffset(0,18);text.BackgroundTransparency=1
 text.Font=Enum.Font.GothamMedium;text.TextColor3=white;text.TextStrokeColor3=Color3.fromRGB(18,23,32)
 text.TextStrokeTransparency=.18;text.Parent=gui
 for i,entry in ipairs(icons) do
  if bit32.btest(mask,entry.bit) then icon(gui,entry,i) end
 end
 gui.Parent=view
 return gui
end
return V
