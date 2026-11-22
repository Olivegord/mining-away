-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local GemAppearance=RockFinish.Gems
local MineralLineup=require('./MineralLineup')
local V={};V.__index=V
local PICKUP_HIGHLIGHT=Color3.fromRGB(255,248,221)
local TRAIL_LIFETIME,TRAIL_LIMIT=.29,12
local GLINT_LIMIT=12
local DISPLAY_RANGE,DISPLAY_LIMIT=62,12
local DISPLAY_TAIL=.28
local HOVER_BOB_RATE,HOVER_TURN_RATE=2*math.pi/1.4,2*math.pi/26
local GEM_GLINT='rbxassetid://77624818077620'
local GLINT_LIFETIME=.46
local function liftDust(view,tint)
 local emitter=Instance.new('ParticleEmitter')
 emitter.Name='OreTransferDust';emitter.Enabled=false;emitter.Rate=14
 EnergyDisc.configure(emitter,.19,.32,1,.18,.22)
 emitter.Color=ColorSequence.new(tint:Lerp(PICKUP_HIGHLIGHT,.58),tint)
 emitter.EmissionDirection=Enum.NormalId.Bottom
 emitter.Lifetime=NumberRange.new(.25,.42);emitter.Speed=NumberRange.new(.35,1.1)
 emitter.SpreadAngle=Vector2.new(45,45);emitter.Acceleration=Vector3.new(0,-3,0)
 emitter.Parent=view
 return emitter
end
local function launchTrail(view,tint,halfWidth)
 local a=Instance.new('Attachment');a.Name='LaunchTrailLeft';a.Position=Vector3.new(-halfWidth,0,.04);a.Parent=view
 local b=Instance.new('Attachment');b.Name='LaunchTrailRight';b.Position=Vector3.new(halfWidth,0,.04);b.Parent=view
 local trail=Instance.new('Trail');trail.Name='CargoLaunchTrail'
 trail.Attachment0=a;trail.Attachment1=b;trail.FaceCamera=true
 trail.Lifetime=TRAIL_LIFETIME;trail.MinLength=.045;trail.MaxLength=7.5
 trail.LightEmission=.78;trail.LightInfluence=0
 trail.Color=ColorSequence.new(tint:Lerp(PICKUP_HIGHLIGHT,.85),tint:Lerp(PICKUP_HIGHLIGHT,.22))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.32,.46),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,.90),NumberSequenceKeypoint.new(.32,.52),NumberSequenceKeypoint.new(1,0)})
 trail.Parent=view
 return {trail=trail,a=a,b=b}
end
local function removeTrail(self,r)
 if not r.ribbon then return end
 r.ribbon.trail:Destroy();r.ribbon.a:Destroy();r.ribbon.b:Destroy()
 r.ribbon=nil;self.trailCount-=1
end
local function finishTrail(self,r,now)
 local ribbon=r.ribbon
 if not ribbon then return end
 if not ribbon.untilAt then
  ribbon.trail.Enabled=false;ribbon.untilAt=now+ribbon.trail.Lifetime
 elseif now>=ribbon.untilAt then removeTrail(self,r) end
end
local function makeGlint()
 local anchor=Instance.new('Attachment');anchor.Name='FacetGlint'
 local emitter=Instance.new('ParticleEmitter');emitter.Name='GemSparkle'
 emitter.Texture=GEM_GLINT;emitter.Enabled=false;emitter.Rate=0
 emitter.LightInfluence=0;emitter.LightEmission=.85;emitter.Brightness=2
 emitter.Orientation=Enum.ParticleOrientation.FacingCamera
 emitter.Speed=NumberRange.new(0);emitter.Lifetime=NumberRange.new(GLINT_LIFETIME)
 emitter.LockedToPart=true;emitter.Rotation=NumberRange.new(-18,18)
 emitter.ZOffset=.45;emitter.Parent=anchor
 return {anchor=anchor,emitter=emitter}
end
local function removeIdle(self,r)
 if not r.idle then return end
 r.idle.emitter:Clear()
 r.idle.anchor.Parent=nil;table.insert(self.idlePool,r.idle);r.idle=nil
 self.idleCount-=1
end
local function updateGlint(self,r,age,strength,now)
 if r.idle then
  if now<r.glintUntil then return end
  removeIdle(self,r)
 end
 local clock=age-.5+r.seed*.61
 local interval=r.view:GetAttribute('GemKind')=='Diamond' and 1.65 or 2.65
 local cycle=age<.5 and -1 or math.floor(clock/interval)
 local phase=age<.5 and age or clock%interval
 if phase>=.24 or strength<.04 or r.glintCycle==cycle or self.idleCount>=GLINT_LIMIT then return end
 r.glintCycle=cycle;r.glintUntil=now+GLINT_LIFETIME
 r.idle=table.remove(self.idlePool) or makeGlint();self.idleCount+=1
 local size=r.view.Size
 local side=r.seed%2==0 and 1 or -1
 local flare=r.view:GetAttribute('GemFlare'..((math.max(0,cycle)%3)+1))
 r.idle.anchor.Position=flare and size*flare or Vector3.new(side*size.X*.27,size.Y*.43,-side*size.Z*.08)
 local width=r.physical and 1.95 or 1.35
 local emitter=r.idle.emitter
 emitter.Brightness=flare and 3.2 or 2
 emitter.Size=NumberSequence.new({
  NumberSequenceKeypoint.new(0,width*.24),
  NumberSequenceKeypoint.new(.12,width),
  NumberSequenceKeypoint.new(.38,width*.62),
  NumberSequenceKeypoint.new(1,0),
 })
 emitter.Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,1-strength*.68),
  NumberSequenceKeypoint.new(.13,1-strength),
  NumberSequenceKeypoint.new(.82,1-strength*.80),
  NumberSequenceKeypoint.new(1,1),
 })
 r.idle.anchor.Parent=r.view
 emitter:Emit(1)
end
-- Gem aura (owner, Nov 22: now that everything is colored, dropped gems
-- need much more to stand out). Only rare gems, client-local, off with
-- Reduced Effects or far away:
--  * in flight: a comet of gem-colored sparkles left behind in the air
--  * landed: a soft camera-facing halo that breathes, a dim light (kept low:
--    bright break lights read as a flashbang), rising motes and twinkles
--  * a burst of twinkles the moment it lands
local SPARKLE='rbxasset://textures/particles/sparkles_main.dds'
local AURA_GLOW='rbxasset://textures/ui/AvatarExperience/glowLight.png'
local function auraEmitter(parent,name,color)
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Enabled=false;e.Rate=0
 e.LightInfluence=0;e.Color=ColorSequence.new(color:Lerp(PICKUP_HIGHLIGHT,.55),color)
 e.Parent=parent
 return e
end
local function makeAura(r)
 local color=r.effectColor or r.color
 local at=Instance.new('Attachment');at.Name='GemAura';at.Parent=r.view
 local comet=auraEmitter(at,'GemComet',color)
 comet.Texture=SPARKLE;comet.LightEmission=.8;comet.Brightness=1.6
 comet.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,0)})
 comet.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
 comet.Lifetime=NumberRange.new(.35,.7);comet.Speed=NumberRange.new(.5,2.5);comet.SpreadAngle=Vector2.new(180,180)
 comet.Drag=3;comet.Acceleration=Vector3.new(0,-4,0);comet.Rotation=NumberRange.new(0,360);comet.RotSpeed=NumberRange.new(-180,180)
 comet.Rate=70
 local motes=auraEmitter(at,'GemMotes',color)
 EnergyDisc.configure(motes,.22,.25,1,.2,.3)
 motes.LightEmission=.9;motes.Brightness=1.4
 motes.Lifetime=NumberRange.new(1.2,2);motes.Speed=NumberRange.new(1.2,2.4);motes.SpreadAngle=Vector2.new(35,35)
 motes.EmissionDirection=Enum.NormalId.Top;motes.Acceleration=Vector3.new(0,.6,0);motes.Drag=.8
 motes.Shape=Enum.ParticleEmitterShape.Sphere;motes.Rate=6
 local twinkle=auraEmitter(at,'GemTwinkle',color)
 twinkle.Texture=SPARKLE;twinkle.LightEmission=1;twinkle.Brightness=2
 twinkle.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.35,.7),NumberSequenceKeypoint.new(1,0)})
 twinkle.Lifetime=NumberRange.new(.4,.7);twinkle.Speed=NumberRange.new(0,.6);twinkle.SpreadAngle=Vector2.new(180,180)
 twinkle.Shape=Enum.ParticleEmitterShape.Sphere;twinkle.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
 twinkle.Rotation=NumberRange.new(0,360);twinkle.Rate=5
 local halo=Instance.new('BillboardGui');halo.Name='GemHalo';halo.LightInfluence=0;halo.Brightness=1.3
 halo.Size=UDim2.fromScale(3.4,3.4);halo.MaxDistance=90;halo.Enabled=false;halo.Parent=at
 local image=Instance.new('ImageLabel');image.BackgroundTransparency=1;image.Image=AURA_GLOW;image.ImageColor3=color
 image.Size=UDim2.fromScale(1,1);image.ImageTransparency=.45;image.Parent=halo
 local light=Instance.new('PointLight');light.Name='GemGlow';light.Color=color;light.Range=8;light.Brightness=.5
 light.Shadows=false;light.Enabled=false;light.Parent=at
 return {at=at,comet=comet,motes=motes,twinkle=twinkle,halo=halo,image=image,light=light,color=color}
end
local function stepAura(r,now,flight,resting,off)
 if not r.rareGem or r.stone then return end
 local a=r.aura
 if off or not (flight or resting) then
  if a and (a.comet.Enabled or a.halo.Enabled) then
   a.comet.Enabled=false;a.motes.Enabled=false;a.twinkle.Enabled=false;a.halo.Enabled=false;a.light.Enabled=false
  end
  return
 end
 if not a then a=makeAura(r);r.aura=a end
 local color=r.effectColor or r.color
 if a.color~=color then
  a.color=color;a.image.ImageColor3=color;a.light.Color=color
  local seq=ColorSequence.new(color:Lerp(PICKUP_HIGHLIGHT,.55),color)
  a.comet.Color=seq;a.motes.Color=seq;a.twinkle.Color=seq
 end
 if a.comet.Enabled~=flight then a.comet.Enabled=flight end
 if resting and not a.landed then
  a.landed=true;a.twinkle:Emit(12);a.motes:Emit(6)
 end
 if a.motes.Enabled~=resting then a.motes.Enabled=resting;a.twinkle.Enabled=resting end
 a.halo.Enabled=true;a.light.Enabled=true
 local breathe=.5+.5*math.sin(now*2.6+r.seed)
 local k=resting and 1 or .6
 a.halo.Size=UDim2.fromScale((3+.8*breathe)*k,(3+.8*breathe)*k)
 a.image.ImageTransparency=.5-.15*breathe
 a.light.Brightness=(.35+.2*breathe)*k
end
local function displayOrder(a,b)
 if a.displayDistance==b.displayDistance then return a.seed<b.seed end
 return a.displayDistance<b.displayDistance
end
local function updateDisplays(self,now,reducedMotion,reducedEffects)
 local candidates=self.displayCandidates
 table.sort(candidates,displayOrder)
 local count=math.min(#candidates,DISPLAY_LIMIT)
 local free=self.freeDisplays;table.clear(free)
 for i=1,count do candidates[i].displayWanted=true end
 for _,rig in ipairs(self.displays) do
  local r=rig.record
  if r and r.displayWanted then
   rig.releaseAt=nil
  elseif r then
   rig.releaseAt=rig.releaseAt or now
   local tail=math.clamp(1-(now-rig.releaseAt)/DISPLAY_TAIL,0,1)*r.displayStrength
   if tail>.02 and (r.modifiers~=0 or not r.expiresAt or now<r.expiresAt) then
    PickupDisplay.draw(rig,r,r.displayGround,now,tail,reducedMotion,reducedEffects)
   else
    PickupDisplay.hide(rig);r.displayRig=nil;rig.record=nil;rig.outline.Adornee=nil
   end
  end
  if not rig.record then table.insert(free,rig) end
 end
 for i=1,count do
  local r=candidates[i]
  r.displayWanted=nil
  local rig=r.displayRig or table.remove(free)
  if not rig and #self.displays<DISPLAY_LIMIT then
   rig=PickupDisplay.new(self.parent,#self.displays+1);table.insert(self.displays,rig)
  end
  if rig then
   r.displayRig=rig;rig.releaseAt=nil
   PickupDisplay.draw(rig,r,r.displayGround,now,r.displayStrength,reducedMotion,reducedEffects)
  end
 end
end
local function backpack(owner,fallback)
 local character=owner and owner.Character
 local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
 if torso then return torso.CFrame:PointToWorldSpace(Vector3.new(0,.3,.8)),torso end
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 return hr and hr.Position or fallback,nil
end
local function pickupNumber(parent)
 local gui=Instance.new('BillboardGui');gui.Name='OrePickupAmount';gui.Size=UDim2.fromOffset(130,44)
 gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.MaxDistance=120;gui.Enabled=false
 local text=Instance.new('TextLabel');text.Name='Amount';text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
 text.Font=Enum.Font.GothamBold;text.TextSize=24;text.TextColor3=Color3.fromRGB(255,224,124)
 text.TextStrokeColor3=Color3.fromRGB(38,27,12);text.TextStrokeTransparency=.14;text.Parent=gui;gui.Parent=parent
 return gui,text
end
local function sample(r,source,now)
 -- A stationary pile can be combined or renewed without changing pose.
 r.units=source:GetAttribute('Units') or 1
 r.expiresAt=source:GetAttribute('ExpiresAt')
 local key=source:GetAttribute('Mineral')
 if key~=r.mineralKey or not r.mineral then
  r.mineralKey=key
  local material=Workshop.crystalCargo(key) or key
  local tier=Workshop.CRYSTAL_BY_MATERIAL[material]
  r.mineral=(tier and tier.name or material or 'Ore')..(r.stone and ' rock' or '')
  if r.label then r.label.Mineral.Text=r.mineral end
 end
 local modifiers=source:GetAttribute('RockModifiers') or 0
 if r.modifiers~=modifiers then
  r.modifiers=modifiers
  if r.label then r.label:Destroy();r.label=nil end
  local item=r.stone and Workshop.saleItem(r.mineralKey)
  r.effectColor=RockModifierView.glow(modifiers) or (item and Color3.fromRGB(table.unpack(item.color))) or r.color
 end
 local at=source:GetAttribute('SnapshotAt') or now
 if r.sampleAt and at<=r.sampleAt then return end
 local position=source:GetAttribute('Position') or source.Position
 local velocity=source:GetAttribute('Velocity') or Vector3.zero
 r.sampleAt=at
 table.insert(r.samples,{at=at,x=position.X,y=position.Y,z=position.Z,vx=velocity.X,vy=velocity.Y,vz=velocity.Z,
  floor=source:GetAttribute('FloorY'),homing=source:GetAttribute('Homing')==true,dronePull=source:GetAttribute('DronePull')==true,
  seated=source:GetAttribute('PressSocket')~=nil})
 while #r.samples>5 do table.remove(r.samples,1) end
end
local function grapplePart(kind,name,size,color,parent)
 local part=Instance.new(kind);part.Name=name;part.Size=size;part.Color=color
 part.Material=Enum.Material.Metal;part.Anchored=true;part.CanCollide=false
 part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Parent=parent
 return part
end
local function newGrapple(view)
 local root=Instance.new('Folder');root.Name='CompactorGrapple';root.Parent=view
 local brass=Color3.fromRGB(255,206,121)
 local winch=grapplePart('Part','Winch',Vector3.one*.05,brass,root);winch.Transparency=1
 local head=grapplePart('Part','GrappleHead',Vector3.new(.26,.25,.42),brass,root)
 local jaws={}
 for i=1,2 do jaws[i]=grapplePart('WedgePart','Jaw',Vector3.new(.13,.21,.30),brass,root) end
 local a=Instance.new('Attachment');a.Parent=winch
 local b=Instance.new('Attachment');b.Position=Vector3.new(0,0,.16);b.Parent=head
 local line=Instance.new('Beam');line.Name='GrappleCable';line.Attachment0=a;line.Attachment1=b
 line.FaceCamera=true;line.Width0=.115;line.Width1=.074;line.LightEmission=.56
 line.Color=ColorSequence.new(Color3.fromRGB(202,168,104),brass);line.Parent=root
 return {root=root,winch=winch,head=head,jaws=jaws}
end
local function clearGrapple(r)
 if r.grapple then r.grapple.root:Destroy();r.grapple=nil end
end
local function drawGrapple(self,r,source,displayAt,distance)
 local cast=source:GetAttribute('PressCastAt')
 local origin=source:GetAttribute('PressOrigin')
 if not cast or typeof(origin)~='Vector3' then r.pressVisual=nil;clearGrapple(r);return end
 local age=displayAt-cast
 if not r.pressVisual or r.pressVisual.cast~=cast then
  local start=r.view.CFrame
  if age>=Workshop.GRAPPLE_CAST then
   -- The rest pose may have been missed by a joining observer.
   local contact=origin+Vector3.yAxis*(r.size.Y*.45+(r.physical and 1.52 or 1.04))
   start=CFrame.new(contact)*start.Rotation
  end
  r.pressVisual={cast=cast,start=start}
 elseif age<0 then r.pressVisual.start=r.view.CFrame end
 local mount,winch
 if self.pressMount then
  mount,winch=self.pressMount(source:GetAttribute('PressDrone'),source:GetAttribute('PressSlot'))
 end
 if not mount or age<0 then clearGrapple(r);return end
 local start=r.pressVisual.start
 local reel=(age-Workshop.GRAPPLE_CAST)/Workshop.GRAPPLE_REEL
 local position=Workshop.grapplePull(start.Position,mount,reel)
 r.view.CFrame=CFrame.new(position)*start.Rotation
 r.drawPosition=position
 if reel>=1 or distance>=105 then clearGrapple(r);return end
 r.grapple=r.grapple or newGrapple(r.view)
 local rig=r.grapple
 local castProgress=math.clamp(age/Workshop.GRAPPLE_CAST,0,1)
 local grip=position+r.view.CFrame.UpVector*(r.size.Y*.24)
 winch=winch or mount
 local direction=grip-winch
 if direction.Magnitude<.01 then direction=-Vector3.yAxis else direction=direction.Unit end
 local tip=winch:Lerp(grip,castProgress)+Vector3.yAxis*(math.sin(castProgress*math.pi)*.5)
 rig.winch.Position=winch
 rig.head.CFrame=CFrame.lookAt(tip,tip+direction)
 local spread=castProgress<1 and .20 or .12
 for i,jaw in ipairs(rig.jaws) do
  local side=i==1 and -1 or 1
  jaw.CFrame=rig.head.CFrame*CFrame.new(side*spread,-.02,-.15)*CFrame.Angles(0,side*.34,-side*.16)
 end
end
local function showSelection(self,r,selected,marked)
 if not selected and not marked then
  if r.selection then r.selection:Destroy();r.selection=nil end
  if r.label then r.label:Destroy();r.label=nil end
  return
 end
 if not r.selection then
  local outline=Instance.new('Highlight');outline.Name='SelectedOre';outline.Adornee=r.view
  outline.Enabled=true;outline.Parent=self.parent;r.selection=outline
 end
 local tint=selected and Color3.fromRGB(247,253,255) or Color3.fromRGB(255,193,106)
 r.selection.DepthMode=selected and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
 r.selection.OutlineTransparency=0
 r.selection.FillTransparency=selected and .56 or .69
 r.selection.OutlineColor=tint;r.selection.FillColor=tint
 if not r.label then r.label=RockModifierView.dropLabel(r.view,r.mineral,r.modifiers) end
 r.label.AlwaysOnTop=selected;r.label.MaxDistance=selected and 100 or 62
end
-- Short pop-up word for a lucky drop or collected gem.
local function popText(parent,position,text,color,size)
 local anchor=Instance.new('Part');anchor.Name='PickupPop';anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Size=Vector3.one*.1;anchor.Position=position;anchor.Parent=parent
 local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromOffset(size*5,size*1.3);gui.AlwaysOnTop=true;gui.LightInfluence=0
 gui.MaxDistance=120;gui.Adornee=anchor;gui.Parent=anchor
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
 label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.Text=text;label.TextColor3=color
 label.TextStrokeTransparency=0;label.TextStrokeColor3=Color3.fromRGB(25,18,10);label.Parent=gui
 local scale=Instance.new('UIScale');scale.Scale=.3;scale.Parent=gui
 local started=os.clock();local connection
 connection=game:GetService('RunService').RenderStepped:Connect(function()
  local age=os.clock()-started
  if not anchor.Parent or age>=1.2 then connection:Disconnect();anchor:Destroy();return end
  local pop=math.clamp(age/.16,0,1)
  scale.Scale=pop<1 and .3+.95*(1-(1-pop)^3) or 1+.25*math.exp(-(age-.16)*10)*math.cos((age-.16)*28)
  anchor.Position=position+Vector3.yAxis*age*1.6
  local fade=math.clamp((age-.85)/.35,0,1);label.TextTransparency=fade;label.TextStrokeTransparency=fade
 end)
end
V.popText=popText
function V.new(root,parent,audio,reducedMotion)
 GemAppearance.prepare()
 local player=Players.LocalPlayer
 local self=setmetatable({records={},byId={},parent=parent,root=root,connections={},audio=audio,lastSound=0,reducedMotion=reducedMotion,
  player=player,trailCount=0,idleCount=0,idlePool={},displays={},freeDisplays={},displayCandidates={},lastTotal=player:GetAttribute('CollectedOreTotal') or 0},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  if (source:GetAttribute('CollectedAt') or 0)>0 or (source:GetAttribute('ProcessedAt') or 0)>0 then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view,faceted=GemAppearance.clone(source);view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false
  source.LocalTransparencyModifier=1;view.Transparency=1;if faceted then GemAppearance.update(view,0) end;view.Parent=parent
  local id=source:GetAttribute('PickupId')
  local r={lucky=source:GetAttribute('LuckyMultiplier'),view=view,faceted=faceted,gemOpacity=view:GetAttribute('GemOpacity') or .76,pos=position,size=view.Size,color=faceted and GemAppearance.tint(source:GetAttribute('Mineral')) or source.Color,seed=id,physical=source:GetAttribute('PhysicalCargo')==true,
   stone=source:GetAttribute('StoneCargo')==true,rareGem=source:GetAttribute('RareGemReward')==true,samples={},owner=source:GetAttribute('Owner'),
   born=source:GetAttribute('SpawnAt') or workspace:GetServerTimeNow()}
  local origin=source:GetAttribute('OreLaunchOrigin')
  local velocity=source:GetAttribute('OreLaunchVelocity')
  if typeof(origin)=='Vector3' and typeof(velocity)=='Vector3' and math.abs(velocity.X)+math.abs(velocity.Z)>.01 then
   r.hasArc=true
   local floor=source:GetAttribute('FloorY')
   if source:GetAttribute('CleanCargoArc') and type(floor)=='number' then
    r.arc=OreDrops.rawArc(origin.X,origin.Y,origin.Z,velocity.X,velocity.Y,velocity.Z,floor)
    r.landAge=r.arc.contact
    view.CastShadow=true
   end
   local height=math.max(0,origin.Y-(source:GetAttribute('FloorY') or origin.Y))
   r.arcTimeout=(velocity.Y+math.sqrt(velocity.Y^2+2*PickupMotion.GRAVITY*height))/PickupMotion.GRAVITY+.18
  end
  local contactAt=source:GetAttribute('GroundImpactAt')
  if not r.arc and type(contactAt)=='number' and contactAt>0 then r.landAge=math.max(0,contactAt-r.born) end
  self.records[source]=r;self.byId[id]=r;sample(r,source,workspace:GetServerTimeNow())
  return r
 end
 self.lineup=MineralLineup.new(parent,add,RockFinish)
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source]
  if r then r.removedAt=workspace:GetServerTimeNow() end
 end))
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_Collect'):Connect(function()
  local ok,receipt=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_Collect') or '')
  if not ok or type(receipt)~='table' or type(receipt.serial)~='number' or receipt.serial==self.lastReceipt then return end
  self.lastReceipt=receipt.serial
  local units=receipt.units or 0
  if type(receipt.total)=='number' then
   units=math.max(0,receipt.total-self.lastTotal);self.lastTotal=math.max(receipt.total,self.lastTotal)
  end
  local now=workspace:GetServerTimeNow()
  if math.abs(now-(receipt.at or 0))>.7 then return end
  local rootPart=player.Character and player.Character:FindFirstChild('HumanoidRootPart');if not rootPart then return end
  local r=self.byId[receipt.pickupId]
  if r and receipt.exhausted==true then
   r.collectAt=r.collectAt or now;r.collectFrom=r.collectFrom or r.drawPosition or r.pos
  end
  local target,torso=backpack(player,rootPart.Position)
  if type(units)=='number' and units>0 then
   if not self.amountGui then self.amountGui,self.amountText=pickupNumber(parent) end
   if now-(self.amountAt or -math.huge)<.4 then self.amount+=units
   else self.amount=units;self.amountStarted=now end
   local arrival=now+(r and r.physical and .18 or 0)
   self.amountAt=arrival
   self.amountGui.Adornee=torso or rootPart
   self.amountText.Text='+'..self.amount..(receipt.physical and ' cargo' or ' ore')
  end
  if audio and not receipt.quiet then self.soundAt=now+(r and r.physical and .18 or 0);self.soundTarget=target end
 end))
 return self
end
function V:update(dt,now)
 if self.soundAt and now>=self.soundAt then
  if now-self.lastSound>.09 then
   self.pickupChain=now-self.lastSound<.6 and math.min(6,(self.pickupChain or 0)+1) or 0
   self.lastSound=now;self.audio:play('pickup',backpack(self.player,self.soundTarget),{pitch=1+self.pickupChain*.045})
  end
  self.soundAt=nil
 end
 if self.amountGui then
  local age=math.max(0,now-self.amountAt)
  local reduced=self.player:GetAttribute('ReducedEffects')==true
  self.amountGui.Enabled=now>=self.amountAt and age<.93 and self.amountGui.Adornee.Parent~=nil
  if self.amountGui.Enabled then
   local rise=reduced and 0 or .78*(1-math.exp(-math.max(0,now-self.amountStarted)*4))
   self.amountGui.StudsOffset=Vector3.new(1.72,1.05+rise,0)
   self.amountText.TextSize=reduced and 24 or 24+math.floor(6*math.max(0,1-age/.18))
   local fade=math.clamp((age-.53)/.40,0,1)
   self.amountText.TextTransparency=fade;self.amountText.TextStrokeTransparency=.14+.86*fade
  end
 end
 local camera=workspace.CurrentCamera
 local cameraPosition=camera and camera.CFrame.Position
 local reducedEffects=self.player:GetAttribute('ReducedEffects')==true or self.player:GetAttribute('MA_ReducedEffects')==true
 local reducedFlashing=self.player:GetAttribute('ReducedFlashing')==true
 local glintStrength=reducedFlashing and .36 or 1
 local reducedMotion=self.reducedMotion and self.reducedMotion()
 local character=self.player.Character
 local rootPart=character and character:FindFirstChild('HumanoidRootPart')
 MineralLineup.update(self.lineup,now,reducedMotion,reducedEffects,rootPart and rootPart.Position,cameraPosition)
 local displayAt=now-PickupMotion.DELAY
 local focusId=self.pickupFocus and self.pickupFocus()
 table.clear(self.displayCandidates)
 for source,r in pairs(self.records) do
  local replayAt=r.previewReplayAt
  if replayAt and displayAt>=replayAt then
   r.born=replayAt;r.previewReplayAt=nil;replayAt=nil
   r.landCue=nil;r.glintCycle=nil;r.trailUsed=nil
   r.hoverAlpha=nil;r.hoverStartedAt=nil;r.restSample=nil
   removeTrail(self,r);removeIdle(self,r)
  end
  if not r.collectAt and source.Parent then
   local processed=source:GetAttribute('ProcessedAt')
   local collectedAt=processed or source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.processed=processed~=nil
    r.courierCollected=source:GetAttribute('CourierCollected')==true
    r.collectAt=(r.processed or r.courierCollected) and collectedAt or now
    r.collectFrom=r.drawPosition or r.pos
    if r.courierCollected then
     r.courierId=source:GetAttribute('CourierDroneId')
    end
    r.collectTarget=source:GetAttribute(r.processed and 'ProcessedPosition' or 'CollectedPosition')
   end
  end
  local opacity,glow,done=1,0,false
  local heldPose
  if r.collectAt and r.processed and r.collectTarget then
   local t=math.clamp((now-r.collectAt)/Workshop.PRESS_CONTACT,0,1)
   local close=math.clamp((t-.18)/.82,0,1)^2
   local ease=PickupMotion.collection(close)
   r.pos=r.collectFrom:Lerp(r.collectTarget,ease)
   opacity=1-math.clamp((close-.82)/.18,0,1)
   glow=.48*close;done=t>=1
  elseif r.collectAt and r.courierCollected then
   -- Keep the grounded copy until the closed claw's replicated cargo arrives.
   done=(self.cargoMount and self.cargoMount(r.courierId,r.seed)~=nil) or now-r.collectAt>=.23
   heldPose=r.view.CFrame
   r.pos=heldPose.Position
  elseif r.collectAt then
   if (r.rareGem or r.lucky) and not r.collectCue and r.owner==self.player.UserId then
    r.collectCue=true
    self.gemChain=now-(self.lastGemAt or -10)<1.2 and math.min(8,(self.gemChain or 0)+1) or 0
    self.lastGemAt=now
    local at=r.drawPosition or r.pos
    if self.audio then self.audio:play('sale_gem',at,{pitch=1.25+self.gemChain*.09,level=1.1}) end
    if r.rareGem then popText(self.parent,at+Vector3.yAxis*1.5,'+GEM',r.effectColor or r.color,20) end
    if not reducedEffects and not reducedMotion then RoleVisuals.ImpactParticles(at,r.effectColor or r.color,.7,'GemReward') end
   end
   local t=(now-r.collectAt)/(r.physical and .18 or .22);local ease=PickupMotion.collection(t)
   local owner=Players:GetPlayerByUserId(r.owner)
   local target=backpack(owner,r.collectTarget or r.collectFrom)
   local lift=math.sin(math.clamp(t,0,1)*math.pi)
   r.pos=r.collectFrom:Lerp(target,ease)+Vector3.new(0,lift*.52,0)
   opacity=1-math.clamp((t-.7)/.3,0,1)
   glow=.55*lift;done=t>=1
  elseif source.Parent and not r.removedAt then
   -- Landing pose is persistent state, even when its timestamp arrives too
   -- late to replay a sound. A streamed/stalled observer must still settle.
   local contactAt=source:GetAttribute('GroundImpactAt')
   if not r.landAge and type(contactAt)=='number' and contactAt>0 then
    r.landAge=math.max(0,contactAt-r.born)
   end
   sample(r,source,now)
   if r.modifiers==0 then opacity=PickupMotion.expiryOpacity(now,r.expiresAt,reducedEffects or reducedFlashing) end
  else
   r.removedAt=r.removedAt or now
   -- Keep the record briefly in case its collection receipt arrives late.
   opacity=0;done=now-r.removedAt>=.28
  end
  if replayAt then
   opacity*=math.clamp((replayAt-displayAt)/MineralLineup.fadeTime,0,1)
  end
  if r.arc and displayAt<r.born then opacity=0 end
  local latest=r.samples[#r.samples]
  local dust=not done and not reducedEffects and r.physical and cameraPosition
   and (r.pos-cameraPosition).Magnitude<75
   and not r.collectAt and source.Parent and latest and latest.dronePull
  if dust and not r.liftDust then r.liftDust=liftDust(r.view,r.effectColor) end
  if r.liftDust then r.liftDust.Enabled=dust==true end
  if done then
   if r.faceted then GemAppearance.update(r.view,0) end
   showSelection(self,r,false,false);clearGrapple(r)
   finishTrail(self,r,now);removeIdle(self,r)
   if r.liftDust and not r.liftTail then r.liftTail=now+.42 end
   if r.ribbon or r.liftTail and now<r.liftTail then r.view.Transparency=1
   else
    r.view:Destroy();self.byId[r.seed]=nil;self.records[source]=nil
   end
  else
   local live=source.Parent~=nil and not r.collectAt and not r.removedAt
   local seated=live and source:GetAttribute('PressSocket')~=nil
   local pulling=live and latest and latest.homing
   local docking=live and source:GetAttribute('CourierDocking')~=nil
   if r.arc and not r.arcExit and (pulling or seated or source:GetAttribute('CargoArcEnded')) then r.arcExit=latest.at end
   local age=math.max(0,displayAt-r.born)
   if r.lucky and not r.luckyCue and displayAt>=r.born then
    r.luckyCue=true
    local launch=source:GetAttribute('OreLaunchOrigin') or r.pos
    if age<.5 and cameraPosition and (cameraPosition-launch).Magnitude<110 and r.owner==self.player.UserId then
     local gold=Color3.fromRGB(255,206,64)
     popText(self.parent,launch+Vector3.yAxis*2,'LUCKY x'..r.lucky..'!',gold,r.lucky>=10 and 34 or 26)
     if self.audio then self.audio:play('gem_reveal',launch,{pitch=r.lucky>=10 and 1.5 or 1.2,level=.9}) end
     if not reducedEffects and not reducedMotion then
      RoleVisuals.ImpactParticles(launch,gold,r.lucky>=10 and 2.2 or 1.3,'GemReward')
      RoleVisuals.Pulse(launch,gold,.5,r.lucky>=10 and 9 or 5.5,.45)
     end
    end
   end
   if r.rareGem and not r.rewardCue and displayAt>=r.born then
    r.rewardCue=true
    local launch=source:GetAttribute('OreLaunchOrigin') or r.pos
    if age<.32 and cameraPosition and (cameraPosition-launch).Magnitude<90 then
     if self.audio then self.audio:play('gem_reveal',launch,{level=r.owner==self.player.UserId and 1 or .64}) end
     if not reducedEffects and not reducedMotion then
      RoleVisuals.ImpactParticles(launch,r.effectColor,1.5,'GemReward')
      RoleVisuals.ImpactParticles(launch,r.effectColor:Lerp(PICKUP_HIGHLIGHT,.4),1.1,'CrystalBreak',nil,r.effectColor)
      RoleVisuals.Pulse(launch,r.effectColor,.55,5.2,.42)
     end
    end
   end
   -- Regular ore fragments and large workshop cargo both land. Wait for the
   -- contact position/speed to replicate before consuming this one-shot cue.
   if r.hasArc and r.landAge and age>=r.landAge and not r.landCue and (live or r.arc) then
    local point=source:GetAttribute('GroundImpactPosition')
    local speed=source:GetAttribute('GroundImpactSpeed') or 0
    if r.arc then point=Vector3.new(r.arc.landX,r.arc.floor-.22,r.arc.landZ);speed=r.arc.speed end
    if age-r.landAge>=.28 then r.landCue=true
    elseif typeof(point)=='Vector3' and speed>0 then
     r.landCue=true
     if self.audio and not r.preview then
      local cue=r.rareGem and 'gem_land' or r.stone and 'stone_land' or 'ore_land'
      self.audio:play(cue,point,{level=math.clamp(speed/43,.67,1.18)*(r.arc and 1.12 or r.physical and 1 or .82),
       pitch=(r.physical and .84 or 1.02)+(r.seed%4)*.028})
     end
     if r.rareGem and not reducedEffects and not reducedMotion then
      RoleVisuals.ImpactParticles(point,r.effectColor,1.25,'GemReward')
      RoleVisuals.Pulse(point+Vector3.yAxis*.08,r.effectColor,.4,3.6,.4)
     end
    end
   end
   local resting=live and r.landAge and age>=r.landAge+(r.arc and 0 or PickupMotion.SETTLE_TIME)
    and PickupMotion.isResting(latest) and seated==latest.seated and now>=latest.at+PickupMotion.DELAY
   local arcMix=r.arc and (not r.arcExit and 1 or 1-math.clamp((displayAt-r.arcExit)/.12,0,1)) or 0
   local newPose=not (resting and r.restSample==latest and r.restUnits==r.units)
   if newPose then
    if live then
     local x,y,z=PickupMotion.position(r.samples,now)
     if x then r.pos=Vector3.new(x,y,z) end
     if arcMix>0 then
      local ax,ay,az=OreDrops.rawPose(r.arc,age)
      r.pos=r.pos:Lerp(Vector3.new(ax,ay,az),arcMix)
     end
    end
    local targetPull=pulling and 1 or 0
    r.pull=(r.pull or 0)+(targetPull-(r.pull or 0))*(1-math.exp(-math.min(dt,.1)*18))
    if r.pull<.001 then r.pull=0 end
    glow=math.max(glow,.34*r.pull)
    local rx,ry,rz,remaining
    if r.arc then
     remaining=reducedMotion and 0 or 1-math.clamp(age/math.max(.01,r.arc.contact*.87),0,1)
     local pitch,yaw,roll=Workshop.oreOrientation(r.seed,false)
     local sign=r.seed%2==0 and 1 or -1
     rx=pitch+sign*remaining^1.2*math.pi*(.50+math.abs(r.seed)%5*.09)
     ry=yaw+sign*.60*remaining;rz=roll+.48*math.sin(remaining*math.pi)*sign
    else
     local tumble=reducedMotion and 0 or PickupMotion.tumble(age,r.landAge)
     rx,ry,rz=r.seed*.71+tumble,r.seed*.9+tumble*.28,r.seed*.43+tumble*.21
    end
    local position=r.pos
    if not seated and not r.collectAt and latest and latest.floor then
     local support=PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,rx,ry,rz)
     if remaining and remaining<.18 and r.faceted then
      local exact=r.landingSupport or GemAppearance.support(r.view,CFrame.Angles(rx,ry,rz))
      if exact then
       support+=(exact-support)*(1-remaining/.18)
       if remaining==0 then r.landingSupport=exact end
      end
     end
     local raised=if r.arc then math.max(latest.floor,position.Y)+support-.22 else math.max(latest.floor+support-.22,position.Y)
     position=Vector3.new(position.X,raised,position.Z)
    end
    r.motionPose=heldPose or CFrame.new(position)*CFrame.Angles(rx,ry,rz)
    if glow~=(r.glow or 0) then r.glow=glow;r.view.Color=r.faceted and Color3.new(1,1,1) or r.color:Lerp(PICKUP_HIGHLIGHT,glow) end
    r.restSample=resting and r.pull==0 and latest or nil
    r.restUnits=r.units
   end
   local landingAge=r.landAge and age-r.landAge
   local hoverAge=landingAge and landingAge-(r.arc and OreDrops.GEM_CONTACT_HOLD or PickupMotion.SETTLE_TIME)
   local arcLanded=live and r.arc and not r.arcExit and landingAge>=0
   -- Once a landed gem starts hovering, transient stationary snapshot changes
   -- must not restart its lift. Only an actual pickup or socket ends the hover.
   local hovering=live and not seated and not pulling and not docking and hoverAge and hoverAge>=0
    and (r.hoverStartedAt~=nil or resting or arcLanded)
   local wasHovering=r.hoverAlpha~=nil
   if hovering then
    r.hoverStartedAt=r.hoverStartedAt or (now-hoverAge)
    local t=math.clamp((now-r.hoverStartedAt)/.72,0,1)
    r.hoverAlpha=t*t*(3-2*t)
    r.hoverTime=reducedMotion and 0 or hoverAge
   elseif wasHovering then
    -- Carry the displayed lift into homing, then hand off to its real trajectory.
    r.hoverAlpha*=math.exp(-math.min(dt,.1)*18)
    if not live or seated or r.hoverAlpha<.003 then r.hoverAlpha=nil end
   end
   if not hovering then r.hoverStartedAt=nil end
   if newPose or hovering or wasHovering or docking or r.dockFrom then
    local pose=r.motionPose
    if r.hoverAlpha and not heldPose then
     local t=r.hoverTime
     local lift=(r.physical and 1.52 or 1.04)+(reducedMotion and 0 or .045*math.sin(t*HOVER_BOB_RATE+r.seed))
     local yaw=t*HOVER_TURN_RATE
     pose=CFrame.new(0,lift*r.hoverAlpha,0)*pose*CFrame.Angles(0,yaw,0)
      *CFrame.Angles(.22*r.hoverAlpha,0,-.32*r.hoverAlpha)
    end
    if docking then
     if not r.dockFrom then r.dockFrom=r.view.CFrame;r.dockAt=now end
     local t=math.clamp((now-r.dockAt)/.26,0,1)
     local ground=latest.floor or r.pos.Y
     local packed=select(3,Workshop.crystalCargo(r.mineralKey))==true
     local pitch,yaw,roll=Workshop.oreOrientation(r.seed,packed)
     local support=r.landingSupport or PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,pitch,yaw,roll)
     r.dockTarget=CFrame.new(r.pos.X,ground-.22+support,r.pos.Z)*CFrame.Angles(pitch,yaw,roll)
     pose=r.dockFrom:Lerp(r.dockTarget,t*t*(3-2*t))
    else r.dockFrom=nil;r.dockTarget=nil end
    r.drawPosition=pose.Position;r.view.CFrame=pose
   end
   local floor=arcLanded and r.arc.floor or latest.floor
   if live and not seated and not pulling and landingAge and landingAge>=0 and floor and cameraPosition
    and (r.modifiers~=0 or not r.expiresAt or now<r.expiresAt) then
    local ground=Vector3.new(r.pos.X,floor-.21,r.pos.Z)
    local distance=(ground-cameraPosition).Magnitude
    if distance<DISPLAY_RANGE then
     r.displayGround=ground
     if r.arc then r.displayLandedAt=now-landingAge end
     -- Use the landing point to rank displays. A hovering pose must never
     -- move its glow and outline to another gem across adjacent render frames.
     r.displayDistance=distance-(r.displayRig and 2.5 or 0)
     -- Start the display on the same buffered contact frame as the clink.
     local contactStrength=1-.8*math.exp(-landingAge*11)
     r.displayStrength=contactStrength*math.clamp((DISPLAY_RANGE-distance)/10,0,1)*opacity
     table.insert(self.displayCandidates,r)
    end
   end
   local selected=live and r.seed==focusId and not r.preview and opacity>0 and cameraPosition~=nil
   local distance=cameraPosition and (r.drawPosition-cameraPosition).Magnitude or math.huge
   local marked=live and source:GetAttribute('PressMarked')==true and distance<62
   showSelection(self,r,selected,marked)
   -- Roblox does not reliably draw Highlight on the translucent optical shell.
   -- Give the selected gem its actual solid silhouette for the duration of the cue.
   local transparency=r.selection and 0 or 1-opacity*(r.faceted and r.gemOpacity or 1)
   if r.view.Transparency~=transparency then r.view.Transparency=transparency end
   r.opacity=opacity
   if live then drawGrapple(self,r,source,displayAt,distance) else clearGrapple(r) end
   if r.faceted then GemAppearance.update(r.view,opacity,cameraPosition) end
   local loose=live and not seated and not pulling and not docking and displayAt>=r.born and opacity>.24
   if r.modifiers~=0 and landingAge and landingAge>=0 and loose and distance<62 and not reducedEffects and not reducedMotion then
    RockModifierView.drop(r,now,landingAge,reducedFlashing)
   end
   local canGlint=landingAge and ((landingAge<.24 and (live or r.collectAt)) or (live and not seated and not pulling))
   if not r.stone and (r.arc or r.physical) and landingAge and landingAge>=0 and not reducedEffects and cameraPosition and (canGlint or r.idle) then
    local distanceFade=math.clamp((72-(r.drawPosition-cameraPosition).Magnitude)/12,0,1)
    updateGlint(self,r,landingAge,canGlint and glintStrength*distanceFade*opacity or 0,now)
   else removeIdle(self,r) end
   if r.rareGem then
    local inAir=live and not pulling and displayAt>=r.born and (r.landAge and age<r.landAge or not r.landAge and age<(r.arcTimeout or 1.2))
    local onGround=live and not seated and not pulling and not docking and landingAge~=nil and landingAge>=0
    stepAura(r,now,inAir==true,onGround==true,reducedEffects or not cameraPosition or (r.drawPosition-cameraPosition).Magnitude>90 or opacity<.2)
   end
   if not r.stone and (r.physical or r.hasArc) and cameraPosition then
    local offset=r.drawPosition-cameraPosition
    local distance=offset:Dot(offset)
    local air=r.landAge and age<r.landAge or not r.landAge and age<(r.arcTimeout or 1.2)
    local inFlight=air and live and not pulling and displayAt>=r.born
    if r.ribbon then
     if not inFlight or reducedEffects or r.ribbon.untilAt then finishTrail(self,r,now) end
    elseif inFlight and not r.trailUsed and distance<100^2 and self.trailCount<TRAIL_LIMIT and not reducedEffects then
     r.ribbon=launchTrail(r.view,r.effectColor,r.physical and .32 or r.rareGem and .3 or .16);r.trailUsed=true;self.trailCount+=1
     if r.rareGem then r.ribbon.trail.Lifetime=.5 end
    end
   elseif r.ribbon then
    finishTrail(self,r,now)
   end
  end
 end
 updateDisplays(self,now,reducedMotion,reducedEffects)
end
function V:destroy()
 if self.sales then self.sales:destroy() end
 if self.closed then return end;self.closed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do
  if source.Parent then source.LocalTransparencyModifier=0 end
  if r.selection then r.selection:Destroy() end
  r.view:Destroy()
 end
 for _,glint in ipairs(self.idlePool) do glint.anchor:Destroy() end
 for _,rig in ipairs(self.displays) do rig.base:Destroy() end
 if self.amountGui then self.amountGui:Destroy() end
 MineralLineup.destroy(self.lineup)
 self.records={};self.byId={}
end
return V
