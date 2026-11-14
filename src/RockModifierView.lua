-- Cosmetic reactions follow the rendered rock and its loose cargo.
local V={}
local bits=Mining.ROCK_MODIFIERS
local charged=Color3.fromRGB(255,224,96)
local frost=Color3.fromRGB(135,224,255)
local dust=Color3.fromRGB(249,200,145)
local white=Color3.fromRGB(249,251,255)
local icons={
 {bit=bits.Charged,name='Charged',color=charged},
 {bit=bits.Frosted,name='Frosted',color=frost},
 {bit=bits.Massive,name='Massive',color=dust},
}
local disc=EnergyDisc.texture
local star='rbxassetid://77624818077620'
local elements=bit32.bor(bits.Charged,bits.Frosted)
local tintByElement={[bits.Charged]=charged,[bits.Frosted]=frost,[elements]=charged:Lerp(frost,.5)}

function V.tint(mask)
 return tintByElement[bit32.band(mask or 0,elements)]
end

local function emitter(part,name,color,texture,diameter,lifetime,speed,spread,gravity,streak)
 local p=Instance.new('ParticleEmitter')
 p.Name=name;p.Enabled=false;p.Rate=0;p.Texture=texture
 p.Color=ColorSequence.new(color:Lerp(white,.42),color)
 p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,diameter,diameter*.23),NumberSequenceKeypoint.new(1,0)})
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,streak and .12 or .29),NumberSequenceKeypoint.new(.25,.32),NumberSequenceKeypoint.new(1,1)})
 p.LightInfluence=0;p.LightEmission=streak and .52 or .32
 p.Lifetime=NumberRange.new(lifetime*.63,lifetime)
 p.Speed=NumberRange.new(speed*.48,speed);p.Drag=streak and 3 or 1
 p.Acceleration=Vector3.yAxis*gravity;p.SpreadAngle=Vector2.new(spread,spread)
 if streak then
  p.Orientation=Enum.ParticleOrientation.VelocityParallel;p.Squash=NumberSequence.new(.65)
 else p.RotSpeed=NumberRange.new(-55,55) end
 p.Parent=part
 return p
end
local function prepare(view,state,mask,drop)
 if bit32.btest(mask,bits.Charged) and not state.arc then
  state.arc=emitter(view,'ChargedSnap',charged,disc,drop and .39 or .57,.33,drop and 8 or 15,175,-20,true)
  state.ions=emitter(view,'DriftingIons',Color3.fromRGB(174,243,147),disc,.24,1.35,2.4,40,1.4)
  if not drop then state.crack=emitter(view,'ChargedCrack',charged,disc,.8,.47,30,165,-33,true) end
 end
 if bit32.btest(mask,bits.Frosted) and not state.flake then
  state.flake=emitter(view,'FrostDrift',frost,star,.44,1.7,1.9,95,-1.5)
  if not drop then state.ice=emitter(view,'FrostCrack',frost,star,.76,.76,15,160,-13) end
 end
 if bit32.btest(mask,bits.Massive) and not state.grit then
  state.grit=emitter(view,'MassiveFractureGrit',dust,disc,.64,.91,drop and 4 or 10,155,-24)
 end
end

local function line(parent,a,b,width,color,transparency)
 local p=Instance.new('Part')
 p.Name='LightningStroke';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Color=color;p.Material=Enum.Material.Neon;p.Transparency=transparency
 p.Size=Vector3.new(width,width,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)*.5,b);p.Parent=parent
 return p
end
local function event(view,bit,lowFlash,random)
 local top=view.Position+Vector3.yAxis*(view.Size.Y*.37)
 local parent=view.Parent
 if bit==bits.Charged then
  if lowFlash then return end
  local sky=top+Vector3.new(-3,25,2)
  local from=sky
  for i=1,6 do
   local to=if i==6 then top else sky:Lerp(top,i/6)+Vector3.new(random:NextNumber(-2.3,2.3),0,random:NextNumber(-2,2))
   local core=line(parent,from,to,.16,white,.1)
   local halo=line(parent,from,to,.47,charged,.61)
   task.delay(.12,function() core:Destroy() end)
   task.delay(.23,function() halo:Destroy() end)
   from=to
  end
 else
  local gust=Instance.new('Part')
  gust.Name='FrostGust';gust.Size=Vector3.new(.45,1.8,4);gust.Transparency=1;gust.Anchored=true
  gust.CanCollide=false;gust.CanQuery=false;gust.CanTouch=false;gust.CastShadow=false
  gust.CFrame=CFrame.lookAt(top-Vector3.xAxis*6,top)
  gust.Parent=parent
  local flakes=emitter(gust,'SweepingFrost',frost,star,.68,1.2,19,17,-2)
  flakes.EmissionDirection=Enum.NormalId.Front
  flakes:Emit(17)
  task.delay(1.25,function() gust:Destroy() end)
 end
end
local function ambient(state,now,lowFlash,drop)
 local random=state.random
 if state.arc and now>=(state.nextAt or 0) then
  state.nextAt=now+random:NextNumber(2.25,4.7)
  state.arc:Emit(lowFlash and 1 or 3)
 end
 if state.ions and now>=(state.nextIonAt or 0) then
  state.nextIonAt=now+random:NextNumber(.26,.68)
  state.ions:Emit(1)
 end
 if state.flake and now>=(state.nextFrostAt or 0) then
  state.nextFrostAt=now+random:NextNumber(.38,.93)
  state.flake:Emit(drop and 1 or 2)
 end
 if drop and state.grit and now>=(state.nextGritAt or 0) then
  state.nextGritAt=now+random:NextNumber(2.9,5.2)
  state.grit:Emit(2)
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
  local name=entry.name
  if entry.bit==bits.Massive or not bit32.btest(state.mask,entry.bit) then continue end
  local at=source:GetAttribute(name..'At')
  if at and at>now then state.eventPending=true;continue end
  if at and at~=state.seen[name] and now>=at then
   state.seen[name]=at
   if now-at<.55 and not record.visual.broken then
    event(view,entry.bit,lowFlash,state.random)
    if entry.bit==bits.Charged then
     state.arc:Emit(lowFlash and 4 or 12);state.ions:Emit(6)
    else state.flake:Emit(9) end
   end
  end
 end
 if eventKind=='stage' or eventKind=='break' then
  local final=eventKind=='break'
  if state.crack then state.crack:Emit(lowFlash and 4 or final and 16 or 9) end
  if state.ice then state.ice:Emit(final and 13 or 7) end
  if state.grit then state.grit:Emit(final and 10 or 4) end
 else
  ambient(state,now,lowFlash,false)
 end
end

function V.drop(record,now,landingAge,lowFlash)
 local state=record.modifierFX
 if not state then
  state={random=Random.new(record.seed)};record.modifierFX=state
 end
 if state.mask~=record.modifiers then
  state.mask=record.modifiers
  prepare(record.view,state,state.mask,true)
 end
 if landingAge and landingAge>=0 and not state.landed then
  state.landed=true
  if landingAge<.28 then
   if state.arc then state.arc:Emit(lowFlash and 2 or 7) end
   if state.flake then state.flake:Emit(7) end
   if state.grit then state.grit:Emit(6) end
  end
 end
 ambient(state,now,lowFlash,true)
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
