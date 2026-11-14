-- The same material and silhouette cues identify a modifier before and after mining.
local V={}
local bits=Mining.ROCK_MODIFIERS
local charged=Color3.fromRGB(255,197,58)
local frost=Color3.fromRGB(146,226,255)
local dust=Color3.fromRGB(190,136,96)
local white=Color3.fromRGB(249,251,255)
local icons={
 {bit=bits.Charged,name='Charged',color=charged},
 {bit=bits.Frosted,name='Frosted',color=frost},
 {bit=bits.Massive,name='Massive',color=dust},
}
local star='rbxassetid://77624818077620'
local smoke='rbxasset://textures/particles/smoke_main.dds'
local obsidian=Color3.fromRGB(45,31,56)
local ice=Color3.fromRGB(83,176,221)
local sediment=Color3.fromRGB(126,72,42)
local activeArcs=0
local MAX_ARCS=10

function V.glow(mask)
 for _,entry in ipairs(icons) do
  if bit32.btest(mask,entry.bit) then return entry.color end
 end
end

local function prop(parent,class,name,material,color)
 local p=Instance.new(class)
 p.Name=name;p.Material=material;p.Color=color
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Transparency=1;p.Parent=parent
 return p
end

local function accent(state,class,name,material,color,offset,size,pitch,yaw,roll)
 local p=prop(state.root,class,name,material,color)
 table.insert(state.parts,{
  part=p,offset=Vector3.new(table.unpack(offset)),size=Vector3.new(table.unpack(size)),
  turn=CFrame.Angles(pitch,yaw,roll),
 })
end

local function chargedSeams(state,drop)
 -- The two exposed inlays follow different planes, leaving the ice and
 -- sediment pieces room on a rock with all three modifiers.
 for _,side in ipairs({-1,1}) do
  local x=side*(drop and .39 or .31)
  local z=-side*(drop and .33 or .29)
  local y=drop and .15 or .05
  local seam=drop and .29 or .36
  local turn=side*.97
  accent(state,'Part','GoldVein',Enum.Material.Neon,charged,{x,y,z},{.044,seam,.036},0,.54*side,turn)
  accent(state,'Part','GoldFork',Enum.Material.Neon,Color3.fromRGB(255,231,135),
   {x+.083*side,y+.13,z-.07*side},{.026,seam*.66,.030},.26,.54*side,-turn*.57)
  accent(state,'WedgePart','AmberFacet',Enum.Material.Metal,Color3.fromRGB(188,108,22),
   {x*1.08,y-.10,z*1.06},{.26,.30,.20},.13,side*2.35,-side*.42)
 end
end

local function frostRime(state,drop)
 for _,side in ipairs({-1,1}) do
  local x=side*(drop and .34 or .30)
  local z=side*(drop and .32 or .28)
  local y=drop and .13 or .18
  accent(state,'WedgePart','RimeBlade',Enum.Material.Ice,Color3.fromRGB(180,238,255),
   {x,y,z},{.34,.60,.29},side*.25,side*.93,side*.54)
  accent(state,'WedgePart','BlueIce',Enum.Material.Ice,ice,
   {x*1.28,y-.13,z*.89},{.23,.41,.23},side*.37,-side*1.40,side*.73)
 end
end

local function strata(state,drop)
 for i=1,3 do
  local yaw=.25+(i-1)*math.pi*2/3
  local x,z=math.sin(yaw),math.cos(yaw)
  local radius=drop and .33 or .38
  local y=drop and -.12 or -.30
  accent(state,'WedgePart','DenseStone',Enum.Material.Slate,sediment,
   {x*radius,y,z*radius},{.52,.35,.31},.18,yaw+.20,.15)
  accent(state,'WedgePart','OchreLayer',Enum.Material.Rock,Color3.fromRGB(217,161,99),
   {x*(radius+.027),y+.092,z*(radius+.027)},{.48,.17,.23},.19,yaw+.20,.15)
 end
end

function V.finish(record,base,mask,drop)
 local view,state=record.view,record.modifierSurface
 if not state and mask==0 then return base end
 if not state then
  state={material=view.Material,variant=view.MaterialVariant,reflectance=view.Reflectance}
  record.modifierSurface=state
 end
 local hasCharge=bit32.btest(mask,bits.Charged)
 local hasFrost=bit32.btest(mask,bits.Frosted)
 local hasMass=bit32.btest(mask,bits.Massive)
 if state.mask~=mask or state.view~=view then
  if state.mask~=mask then
   if state.root then state.root:Destroy();state.root=nil end
   if mask~=0 then
    state.root=Instance.new('Folder');state.root.Name='ModifierSurface';state.root.Parent=view
    state.parts={}
    if hasMass then strata(state,drop) end
    if hasFrost then frostRime(state,drop) end
    if hasCharge then chargedSeams(state,drop) end
   end
  end
  state.mask=mask;state.view=view;state.pose=nil;state.size=nil;state.opacity=nil
  state.massive=hasMass
  state.frosted=hasFrost
  if mask==0 then
   view.Material=state.material;view.MaterialVariant=state.variant;view.Reflectance=state.reflectance
   record.modifierSurface=nil
  else
   view.Material=if hasCharge then (drop and Enum.Material.Metal or Enum.Material.Slate)
    elseif hasFrost then Enum.Material.Ice else Enum.Material.Slate
   view.MaterialVariant=''
   view.Reflectance=if hasCharge then (drop and .24 or .07) elseif hasFrost then .10 else .025
   if view:IsA('PartOperation') then view.UsePartColor=true end
  end
 end
 if hasCharge then return base:Lerp(obsidian,drop and .83 or .86) end
 if hasFrost then return base:Lerp(ice,drop and .95 or .86) end
 if hasMass then return base:Lerp(sediment,drop and .73 or .81) end
 return base
end

function V.syncSurface(record)
 local state=record.modifierSurface
 if not state then return end
 local view=record.view
 local pose,size,opacity=view.CFrame,view.Size,1-view.Transparency
 if state.pose==pose and state.size==size and state.opacity==opacity then return end
 local resizing=state.size~=size
 local moving=resizing or state.pose~=pose
 local fading=state.opacity~=opacity
 state.pose=pose;state.size=size;state.opacity=opacity
 for _,accentPart in ipairs(state.parts) do
  local p=accentPart.part
  if resizing then p.Size=accentPart.size*size end
  if moving then p.CFrame=pose*CFrame.new(accentPart.offset*size)*accentPart.turn end
  if fading then p.Transparency=1-opacity end
 end
end

local particleStyles={
 sparks={name='GoldSparks',texture=star,light=.70,size=.84,life={.16,.39},speed={8,23},
  color=charged,endColor=Color3.fromRGB(255,120,33),spread=78,gravity=-22,drag=4},
 ions={name='AmberIons',texture=EnergyDisc.texture,light=.36,size=.32,life={.52,1.24},speed={1.2,3.4},
  color=Color3.fromRGB(255,227,122),endColor=charged,spread=45,gravity=.8,drag=1.5},
 flakes={name='RimeFlakes',texture=star,light=.30,size=.60,life={.72,1.63},speed={1.2,3.1},
  color=white,endColor=frost,spread=71,gravity=-1.5,drag=1.35},
 iceChips={name='FlyingIce',texture=star,light=.22,size=.95,life={.31,.80},speed={5,15},
  color=frost,endColor=ice,spread=70,gravity=-23,drag=2.1},
 vapor={name='ColdVapor',texture=smoke,light=0,size=1.6,life={.66,1.48},speed={2,5.3},
  color=Color3.fromRGB(198,233,255),endColor=ice,spread=79,gravity=-.65,drag=2.1,cloud=true},
 powder={name='StonePowder',texture=smoke,light=0,size=1.45,life={.47,1.26},speed={3,7.2},
  color=Color3.fromRGB(224,180,137),endColor=sediment,spread=74,gravity=-2.1,drag=2.8,cloud=true},
}

local function emitter(parent,key,scale)
 local style=particleStyles[key]
 local diameter=style.size*scale
 local p=Instance.new('ParticleEmitter')
 p.Name=style.name;p.Enabled=false;p.Rate=0;p.Texture=style.texture
 p.Color=ColorSequence.new(style.color,style.endColor)
 if style.cloud then
  p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,diameter*.33),
   NumberSequenceKeypoint.new(.28,diameter,diameter*.22),NumberSequenceKeypoint.new(1,diameter*1.48)})
  p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.92),NumberSequenceKeypoint.new(.17,.56),
   NumberSequenceKeypoint.new(.65,.74),NumberSequenceKeypoint.new(1,1)})
 else
  p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,diameter,diameter*.38),
   NumberSequenceKeypoint.new(.39,diameter*.70),NumberSequenceKeypoint.new(1,0)})
  p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.09),NumberSequenceKeypoint.new(.53,.36),NumberSequenceKeypoint.new(1,1)})
 end
 p.LightEmission=style.light;p.LightInfluence=style.cloud and .58 or .12
 p.Lifetime=NumberRange.new(table.unpack(style.life));p.Speed=NumberRange.new(table.unpack(style.speed))
 p.Drag=style.drag;p.Acceleration=Vector3.yAxis*style.gravity
 p.SpreadAngle=Vector2.new(style.spread,style.spread)
 if key=='sparks' then
  p.Orientation=Enum.ParticleOrientation.VelocityParallel;p.Squash=NumberSequence.new(-.58)
 else
  p.Rotation=NumberRange.new(-180,180);p.RotSpeed=NumberRange.new(-82,74)
 end
 p.Parent=parent
 return p
end

local function prepare(view,state,mask,drop)
 if state.prepared==mask then return end
 if state.anchor then state.anchor:Destroy() end
 state.anchor=Instance.new('Attachment');state.anchor.Name='RockModifierParticles';state.anchor.Parent=view
 state.prepared=mask
 local scale=drop and .60 or 1
 state.sparks=nil;state.ions=nil;state.flakes=nil;state.iceChips=nil;state.vapor=nil;state.powder=nil
 if bit32.btest(mask,bits.Charged) then
  state.sparks=emitter(state.anchor,'sparks',scale)
  state.ions=emitter(state.anchor,'ions',scale)
 end
 if bit32.btest(mask,bits.Frosted) then
  state.flakes=emitter(state.anchor,'flakes',scale)
  state.iceChips=emitter(state.anchor,'iceChips',scale)
  state.vapor=emitter(state.anchor,'vapor',scale)
 end
 if bit32.btest(mask,bits.Massive) then state.powder=emitter(state.anchor,'powder',scale) end
end

local function stroke(parent,a,b,width,color,alpha,life)
 local p=prop(parent,'Part','LightningStroke',Enum.Material.Neon,color)
 p.Size=Vector3.new(width,width,(b-a).Magnitude)
 p.CFrame=CFrame.lookAt((a+b)*.5,b);p.Transparency=alpha
 game:GetService('TweenService'):Create(p,TweenInfo.new(life),{Transparency=1}):Play()
end

local function lightning(view,from,to,random,large)
 if not large and activeArcs>=MAX_ARCS then return end
 local root=Instance.new('Folder');root.Name=large and 'ModifierStrike' or 'ModifierArc';root.Parent=view
 activeArcs+=1
 root.Destroying:Once(function() activeArcs-=1 end)
 local knots=large and 7 or 4
 local width=large and .17 or math.clamp(view.Size.Y*.035,.047,.13)
 local jitter=large and 2.1 or width*3.4
 local previous=from
 for i=1,knots do
  local point=if i==knots then to else from:Lerp(to,i/knots)
   +Vector3.new(random:NextNumber(-jitter,jitter),large and 0 or random:NextNumber(-jitter,jitter),random:NextNumber(-jitter,jitter))
  stroke(root,previous,point,width,white,.03,.14)
  stroke(root,previous,point,width*2.3,charged,.56,.27)
  if i==2 or (large and i==5) then
   local tip=point+Vector3.new(jitter*1.55,-jitter*1.30,-jitter*.73)
   local elbow=point:Lerp(tip,.46)+Vector3.new(0,jitter*.43,jitter*.33)
   stroke(root,point,elbow,width*.63,charged,.09,.17)
   stroke(root,elbow,tip,width*.42,charged,.22,.20)
  end
  previous=point
 end
 game:GetService('Debris'):AddItem(root,.29)
end

local function gust(view)
 local frame,size=view.CFrame,view.Size
 local top=frame.Position+Vector3.yAxis*(size.Y*.22)
 local carrier=prop(view,'Part','FrostGust',Enum.Material.SmoothPlastic,white)
 carrier.Size=Vector3.new(.08,.08,.08)
 carrier.CFrame=CFrame.lookAt(top-Vector3.xAxis*size.X*.97,top)
 local mist=emitter(carrier,'vapor',1.56)
 local flakes=emitter(carrier,'flakes',1.18)
 for _,p in ipairs({mist,flakes}) do
  p.EmissionDirection=Enum.NormalId.Front;p.Speed=NumberRange.new(9,19);p.SpreadAngle=Vector2.new(22,18)
 end
 mist:Emit(8);flakes:Emit(16)
 game:GetService('Debris'):AddItem(carrier,1.7)
end

local function ambient(view,state,now,lowFlash,drop)
 local random=state.random
 if now<(state.nextAmbientAt or 0) then return end
 state.nextAmbientAt=now+random:NextNumber(.44,.87)
 local side=random:NextNumber()<.5 and -1 or 1
 local size=view.Size
 state.anchor.Position=Vector3.new(side*size.X*.26,size.Y*.27,-side*size.Z*.22)
 if state.ions then
  state.ions:Emit(drop and 1 or 2)
  if not lowFlash and now>=(state.nextArcAt or 0) then
   state.nextArcAt=now+random:NextNumber(1.7,3.6)
   local frame=view.CFrame
   local from=frame:PointToWorldSpace(state.anchor.Position)
   local to=frame:PointToWorldSpace(Vector3.new(side*size.X*.52,-size.Y*.18,side*size.Z*.34))
   lightning(view,from,to,random,false)
   state.sparks:Emit(drop and 2 or 4)
  end
 end
 if state.flakes then
  state.anchor.Position=Vector3.new(side*size.X*.31,size.Y*.30,side*size.Z*.32)
  state.flakes:Emit(drop and 1 or 2)
  if now>=(state.nextMistAt or 0) then
   state.nextMistAt=now+random:NextNumber(1.7,3.2)
   state.vapor:Emit(drop and 1 or 2)
  end
 end
end

local function burst(view,state,lowFlash,full)
 state.anchor.Position=Vector3.yAxis*(view.Size.Y*.36)
 if state.sparks then
  state.sparks:Emit(lowFlash and 3 or full and 17 or 7)
  state.ions:Emit(full and 8 or 3)
 end
 if state.iceChips then
  state.iceChips:Emit(full and 12 or 5)
  state.flakes:Emit(full and 7 or 3)
  state.vapor:Emit(full and 5 or 2)
 end
 if state.powder then
  state.anchor.Position=Vector3.yAxis*(-view.Size.Y*.26)
  state.powder:Emit(full and 11 or 4)
 end
end

function V.rock(record,now,lowFlash,eventKind)
 local state=record.modifierFX
 local source,view=record.source,record.view
 if not state or record.modifiersDirty then
  record.modifiersDirty=nil
  state=state or {seen={}}
  state.mask=source:GetAttribute('RockModifiers') or 0
  record.modifierFX=state
 end
 V.syncSurface(record)
 local freshEvent=eventKind~=nil or state.eventPending or state.lastMask~=state.mask
 state.lastMask=state.mask
 if not freshEvent and now<(state.checkAt or 0) then return end
 state.checkAt=now+.13
 if state.mask==0 or not BeamVFX.near(view.Position,78) then return end
 if (record.visual.broken and eventKind~='break') or BeamVFX.reduced() then return end
 prepare(view,state,state.mask,false)
 state.random=state.random or Random.new(source:GetAttribute('StageSeed') or 1)
 state.eventPending=false
 for _,entry in ipairs(icons) do
  if entry.bit==bits.Massive or not bit32.btest(state.mask,entry.bit) then continue end
  local name=entry.name
  local at=source:GetAttribute(name..'At')
  if at and at>now then state.eventPending=true;continue end
  if at and at~=state.seen[name] and now>=at then
   state.seen[name]=at
   if now-at<.55 and not record.visual.broken then
    state.anchor.Position=Vector3.yAxis*(view.Size.Y*.33)
    if entry.bit==bits.Charged then
     local top=view.CFrame:PointToWorldSpace(state.anchor.Position)
     if not lowFlash then lightning(view,top+Vector3.new(-3,25,2),top,state.random,true) end
     state.nextArcAt=now+1.6
     state.sparks:Emit(lowFlash and 4 or 17);state.ions:Emit(7)
    else gust(view);state.nextMistAt=now+1.3 end
   end
  end
 end
 if eventKind=='stage' or eventKind=='break' then
  burst(view,state,lowFlash,eventKind=='break')
 else
  ambient(view,state,now,lowFlash,false)
 end
end

function V.drop(record,now,landingAge,lowFlash)
 local state=record.modifierFX
 if not state then
  state={random=Random.new(record.seed)};record.modifierFX=state
 end
 local view=record.view
 prepare(view,state,record.modifiers,true)
 if not state.landed then
  state.landed=true
  if landingAge<.28 then
   burst(view,state,lowFlash,false)
   state.nextAmbientAt=now+.32
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
