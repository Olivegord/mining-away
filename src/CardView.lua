-- Presentation only. Two text elements per card: effect and target/terms.
-- The complete saved server choice remains the selection contract.
local CardView={HEIGHT=320,MIN_HEIGHT=212}

local function percent(value) return string.format('%g%%',math.floor(value*100+.5)) end
local function amount(value,label) return '+'..percent(value)..' '..label end
local function reach(choice,key,fallback)
 for _,row in ipairs(choice.preview or {}) do if type(row)=='table' and row.label==key and type(row.after)=='number' then return row.after end end
 return fallback
end

function CardView.summary(choice)
 local e=choice.effects or {};local lines={}
 local function add(key,text) if type(e[key])=='number' and e[key]>0 then table.insert(lines,text) end end
 add('orbitalLaser','Call an orbital strike on the biggest rock')
 add('scrapSwarm','Deploy tiny miners for 10 seconds')
 add('plotAuto','Drones choose stones for you')
 add('fullAuto',amount(e.fullAuto or 0,'courier speed'))
 add('mining',amount(e.mining or 0,'mining speed'))
 add('combat',amount(e.combat or 0,'attack damage'))
 add('rate',amount(e.rate or 0,'attack speed'))
 add('health',amount(e.health or 0,'drone health'))
 add('reduction','Block '..percent(e.reduction or 0)..' damage')
 add('capacity',amount(e.capacity or 0,'backpack space'))
 add('speed',amount(e.speed or 0,'drone speed'))
 add('startup',amount(e.startup or 0,'laser startup speed'))
 add('yield',amount(e.yield or 0,'ore per crystal'))
 add('range',amount(e.range or 0,'attack range'))
 add('crit',percent(e.crit or 0)..' chance to hit twice')
 add('fork','Hit a nearby crystal for '..percent(e.fork or 0)..' damage')
 add('splash','Hit a nearby sentry for '..percent(e.splash or 0)..' damage')
 add('shield','Start fights with '..percent(e.shield or 0)..' shield')
 add('finisher',amount(e.finisher or 0,'damage to weak sentries'))
 add('geode',amount(e.geode or 0,'geode damage'))
 add('salvage','Kills repair '..percent(e.salvage or 0)..' health')
 return #lines>0 and table.concat(lines,'\n') or (choice.description or choice.title or 'Run upgrade')
end

function CardView.terms(choice,_targetOverride)
 local e=choice.effects or {};local target
 local work=(e.mining or 0)>0 or (e.startup or 0)>0 or (e.yield or 0)>0 or (e.fork or 0)>0 or (e.geode or 0)>0 or (e.plotAuto or 0)>0
 local allRoles=(e.speed or 0)>0 or (e.health or 0)>0 or (e.reduction or 0)>0 or (e.shield or 0)>0
 if (e.orbitalLaser or 0)>0 then target='Your orbital laser'
 elseif (e.scrapSwarm or 0)>0 then target='Your scrap bots'
 elseif e.fullAuto and e.fullAuto>0 and choice.scope=='Player' then target='Your couriers'
 elseif choice.scope=='Individual' then target=choice.targetName or 'One drone'
 elseif choice.scope=='Color' then target=(choice.type or '')..(work and not allRoles and ' mining drones' or ' drones')
 elseif choice.scope=='Player' then target='Your backpack'
 elseif e.capacity and e.capacity>0 then target='Drones + backpack'
 elseif work and not allRoles then target='Mining drones'
 else target='All drones' end
 local details={target..' · This run'}
 local losses={}
 for _,entry in ipairs({{'speed','drone speed'},{'mining','mining speed'},{'combat','attack damage'},{'health','drone health'},{'startup','startup speed'},{'yield','ore yield'},{'capacity','backpack space'}}) do
  local n=e[entry[1]];if type(n)=='number' and n<0 then table.insert(losses,'−'..percent(-n)..' '..entry[2]) end
 end
 if #losses>0 then table.insert(details,table.concat(losses,', ')) end
 if (e.finisher or 0)>0 then table.insert(details,'Weak = below 35% health') end
 if (e.fork or 0)>0 then table.insert(details,string.format('One crystal within %g studs',reach(choice,'Split reach',6+math.clamp(e.forkRange or 0,0,6)))) end
 if (e.splash or 0)>0 then table.insert(details,string.format('One sentry within %g studs',reach(choice,'Arc reach',6+math.clamp(e.chain or 0,0,16)))) end
 return table.concat(details,'\n')
end

-- ViewportFrame cannot render nested GuiObjects. The supported hierarchy is a
-- real camera-local card > SurfaceGui face > small ViewportFrame illustration.
-- Screen-space hitboxes retain ordinary touch, keyboard and controller input.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local GuiService=game:GetService('GuiService')
local serial=0

local function visualPart(parent,size,position,color,shape)
 local part=Instance.new('Part');part.Size=size;part.CFrame=CFrame.new(position);part.Color=color
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Material=Enum.Material.Plastic;part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 if shape then part.Shape=shape end
 part.Parent=parent;return part
end
-- Identity follows the mechanic, never a rainbow rarity assignment.
function CardView.identity(choice)
 local e=choice.effects or {}
 local function has(k) return type(e[k])=='number' and e[k]>0 end
 if has('orbitalLaser') then return 'orbital',Color3.fromRGB(219,58,35),Color3.fromRGB(255,223,82) end
 if has('scrapSwarm') then return 'swarm',Color3.fromRGB(103,49,209),Color3.fromRGB(191,255,98) end
 if has('plotAuto') then return 'scanner',Color3.fromRGB(0,119,114),Color3.fromRGB(142,255,153) end
 if has('fork') then return 'prism',Color3.fromRGB(42,75,203),Color3.fromRGB(88,244,255) end
 if has('capacity') or has('fullAuto') then return 'cargo',Color3.fromRGB(200,93,10),Color3.fromRGB(255,224,101) end
 if has('health') or has('reduction') or has('salvage') or has('shield') then return 'repair',Color3.fromRGB(12,125,65),Color3.fromRGB(164,255,180) end
 if has('combat') or has('rate') or has('crit') or has('splash') or has('finisher') or has('range') then return 'combat',Color3.fromRGB(178,30,80),Color3.fromRGB(255,161,198) end
 if has('speed') or has('startup') then return 'thrust',Color3.fromRGB(0,104,179),Color3.fromRGB(121,237,255) end
 return 'mineral',Color3.fromRGB(104,49,170),Color3.fromRGB(245,177,255)
end

-- A molded housing: a bright upper lip, dark lower edge and an inset face.
-- These stay local to packs; color does not compete with the working swarm.
function CardView.housing(U,root,color,accent)
 root.BackgroundColor3=color
 U.corner(root,8)
 local edge=U.stroke(root,Color3.fromRGB(13,23,48),3)
 local shade=Instance.new('UIGradient');shade.Name='MoldedFinish';shade.Rotation=90
 shade.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(235,241,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(160,178,218))});shade.Parent=root
 local lip=U.frame(root,UDim2.new(0,8,0,3),UDim2.new(1,-16,0,3),accent:Lerp(Color3.new(1,1,1),.35));lip.Name='UpperBevel';lip.BackgroundTransparency=.2;U.corner(lip,2)
 local heel=U.frame(root,UDim2.new(0,7,1,-7),UDim2.new(1,-14,0,4),Color3.fromRGB(14,25,54));heel.Name='LowerBevel';heel.BackgroundTransparency=.28;U.corner(heel,2)
 return edge
end

local function artFinish(U,bay,body,accent)
 bay.ClipsDescendants=true;U.corner(bay,10);U.stroke(bay,Color3.fromRGB(16,26,52),3)
 -- Four small fasteners leave the original role models as the focal point.
 for _,point in ipairs({{.035,.055},{.965,.055},{.035,.945},{.965,.945}}) do
  local rivet=U.frame(bay,UDim2.fromScale(point[1],point[2]),UDim2.fromOffset(9,9),body:Lerp(accent,.55))
  rivet.AnchorPoint=Vector2.new(.5,.5);rivet.Name='Fastener';U.corner(rivet,9);U.stroke(rivet,Color3.fromRGB(14,25,54),1)
 end
 local shine=U.frame(bay,UDim2.fromScale(-.6,-.4),UDim2.fromScale(.55,1.8),Color3.new(1,1,1));shine.Name='RevealGlint';shine.Rotation=22;shine.Visible=false
 local sweep=Instance.new('UIGradient');sweep.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,1),NumberSequenceKeypoint.new(.5,.7),NumberSequenceKeypoint.new(.6,1),NumberSequenceKeypoint.new(1,1)});sweep.Parent=shine
 local sparks={}
 for i=1,4 do
  local spark=U.frame(bay,UDim2.fromScale(.5,.5),UDim2.fromOffset(9,i%2==0 and 16 or 9),accent:Lerp(Color3.new(1,1,1),.35))
  spark.AnchorPoint=Vector2.new(.5,.5);spark.Rotation=45;spark.Visible=false;spark.Name='FocusSpark';table.insert(sparks,spark)
 end
 return shine,sparks
end
local function mechanicVisual(parent,choice,compact)
 local viewport=Instance.new('ViewportFrame');viewport.Name='MechanicPreview';viewport.BackgroundTransparency=1;viewport.ZIndex=parent.ZIndex+2
 viewport.Position=UDim2.fromScale(.045,.022);viewport.Size=UDim2.fromScale(.91,compact and .30 or .43)
 viewport.Ambient=Color3.fromRGB(205,210,225);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-3);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Name='Mechanic';world.Parent=viewport
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(Vector3.new(4,3,7),Vector3.new(0,-.1,0));camera.Parent=viewport;viewport.CurrentCamera=camera
 local identity,body,accent=CardView.identity(choice)
 local storage=game:GetService('ReplicatedStorage')
 local config=storage:FindFirstChild('Shared');config=config and config:FindFirstChild('DroneConfig')
 local roles=config and require(config)
 local function safe(model)
  for _,c in ipairs(model:GetDescendants()) do
   if c:IsA('LuaSourceContainer') or c:IsA('Sound') or c:IsA('BillboardGui') or c:IsA('SurfaceGui') then c:Destroy()
   elseif c:IsA('BasePart') then c.Anchored=true;c.CanCollide=false;c.CanTouch=false;c.CanQuery=false;c.CastShadow=false;c.Reflectance=0
   elseif c:IsA('Trail') or c:IsA('Beam') or c:IsA('ParticleEmitter') then c.Enabled=false end
  end
 end
 local function drone(role,size,position,rotation)
  local template=storage:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
  if not template or not template:IsA('Model') then return end
  local model=template:Clone();safe(model)
  local shell=model:FindFirstChild('Mesh')
  if shell and shell:IsA('BasePart') then
   shell.Color=Color3.fromRGB(66,87,111):Lerp(body,.25);shell.Material=Enum.Material.SmoothPlastic
   local eye=visualPart(model,Vector3.new(shell.Size.X*.74,shell.Size.Y*.15,.06),Vector3.zero,Color3.fromRGB(12,22,39))
   eye.CFrame=shell.CFrame*CFrame.new(0,-shell.Size.Y*.16,shell.Size.Z*.5+.035)
   local optic=visualPart(model,Vector3.new(shell.Size.X*.57,shell.Size.Y*.065,.075),Vector3.zero,accent)
   optic.CFrame=eye.CFrame*CFrame.new(0,0,.045)
   local emitter=model:FindFirstChild('Emmiter',true)
   if emitter and emitter:IsA('BasePart') then
    emitter.Size=Vector3.one*(shell.Size.Y*.25);emitter.Color=accent
    emitter.CFrame=shell.CFrame*CFrame.new(0,-shell.Size.Y*.61,0)
   end
  end
  if roles then roles.decorate(model,role) end
  -- Show the authored bolt-on hardware clear of the original cubic shell.
  -- This is an exploded card illustration, not a change to the world asset.
  for _,hardware in ipairs(model:GetChildren()) do if hardware:IsA('BasePart') then
   if hardware.Name:find('OrbitalLens') or hardware.Name=='FocusingMast' then hardware.CFrame+=Vector3.new(0,.8,0) end
   if hardware.Name=='MiniDroneBay' or hardware.Name=='BayLatch' then
    local localPosition=model:GetPivot():PointToObjectSpace(hardware.Position)
    hardware.CFrame+=model:GetPivot().RightVector*(localPosition.X<0 and -.5 or .5)
   end
  end end
  safe(model)
  local _,bounds=model:GetBoundingBox();model:ScaleTo(model:GetScale()*size/math.max(bounds.X,bounds.Y,bounds.Z,.01))
  local box=model:GetBoundingBox();model:PivotTo(CFrame.new(position)*(rotation or CFrame.new())*box:Inverse()*model:GetPivot())
  model.Parent=world;return model
 end
 local function crystal(size,position,color,rotation)
  local original=storage:FindFirstChild('Crystal') or workspace:FindFirstChild('Crystal')
  local template=original and original:FindFirstChild('Mesh',true)
  if not template or not template:IsA('BasePart') then return end
  local part=template:Clone();safe(part)
  part.Size=template.Size*(size/math.max(template.Size.Y,.01));part.CFrame=CFrame.new(position)*(rotation or CFrame.new())
  part.Color=color;part.Material=Enum.Material.SmoothPlastic;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Reflectance=0;part.Parent=world
  return part
 end
 local function ray(a,b,width,color)
  local length=(b-a).Magnitude
  local halo=visualPart(world,Vector3.new(length,width*2.4,width*2.4),(a+b)/2,color,Enum.PartType.Cylinder);halo.Transparency=.68
  halo.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0)
  local core=visualPart(world,Vector3.new(length,width,width),(a+b)/2,color:Lerp(Color3.new(1,1,1),.7),Enum.PartType.Cylinder)
  core.CFrame=halo.CFrame
 end
 local function chips(position,color)
  for i=1,5 do
   local a=i*math.pi*2/5
   crystal(.35+i%2*.12,position+Vector3.new(math.cos(a)*.95,.1+i%2*.25,math.sin(a)*.65),color,CFrame.Angles(.2,a,.3))
  end
 end
 if identity=='orbital' then
  drone('Orbiter',2.6,Vector3.new(0,1.25,0))
  crystal(2,Vector3.new(0,-1.4,0),Color3.fromRGB(246,116,57),CFrame.Angles(0,.3,-.1))
  ray(Vector3.new(0,.75,0),Vector3.new(0,-.9,0),.2,accent)
  chips(Vector3.new(0,-1.65,0),accent)
 elseif identity=='swarm' then
  for i=1,3 do
   local x=(i-2)*1.45;local y=i==2 and .8 or .15
   drone('Scrapper',1.65,Vector3.new(x,y,0),CFrame.Angles(0,(i-2)*-.3,(i-2)*.15))
   ray(Vector3.new(x,y-.4,0),Vector3.new(x*.6,-1.1,0),.065,accent)
  end
  crystal(1.7,Vector3.new(0,-1.6,0),Color3.fromRGB(185,122,255),CFrame.Angles(0,.4,-.15));chips(Vector3.new(0,-1.5,0),accent)
 elseif identity=='prism' then
  drone('Striker',1.85,Vector3.new(0,1.25,0),CFrame.Angles(0,-.3,.08))
  local prism=visualPart(world,Vector3.new(.85,1.1,.85),Vector3.new(0,-.15,0),accent)
  prism.CFrame=CFrame.new(0,-.15,0)*CFrame.Angles(0,math.rad(45),math.rad(25))
  ray(Vector3.new(0,.65,0),Vector3.new(0,.2,0),.11,accent)
  for _,sign in ipairs({-1,1}) do
   local color=sign<0 and Color3.fromRGB(129,255,179) or Color3.fromRGB(255,154,222)
   crystal(1.6,Vector3.new(sign*1.25,-1.35,0),color,CFrame.Angles(0,sign*.5,sign*.12))
   ray(Vector3.new(0,-.15,0),Vector3.new(sign*1.25,-.75,0),.11,color)
  end
 elseif identity=='cargo' then
  drone('Courier',3.1,Vector3.new(.25,.45,0),CFrame.Angles(0,-.25,.08))
  for i=1,3 do crystal(1.05,Vector3.new((i-2)*.6,-1.2,.8),accent,CFrame.Angles(0,i*.7,-.15)) end
 elseif identity=='repair' then
  drone('Medic',3.3,Vector3.new(0,.15,0),CFrame.Angles(.1,-.2,-.15))
  for i=1,3 do
   local x=(i-2)*1.25;local y=i==2 and 1.6 or -.9
   visualPart(world,Vector3.new(.14,.55,.14),Vector3.new(x,y,.5),accent)
   visualPart(world,Vector3.new(.55,.14,.14),Vector3.new(x,y,.5),accent)
  end
 elseif identity=='thrust' then
  drone('Striker',2.75,Vector3.new(.7,.15,0),CFrame.Angles(0,-.3,-.22))
  for i=-1,1 do ray(Vector3.new(-2.3,i*.5,-.2),Vector3.new(-.55,i*.5+.3,-.2),.12,accent) end
 elseif identity=='scanner' then
  drone('Dart',2.5,Vector3.new(0,.95,0),CFrame.Angles(0,-.3,0))
  for i=-1,1 do crystal(1.4,Vector3.new(i*1.25,-1.1,0),i==0 and accent or body:Lerp(accent,.4),CFrame.Angles(0,i*.4,.1)) end
  ray(Vector3.new(0,.4,0),Vector3.new(-1.25,-.4,0),.07,accent);ray(Vector3.new(0,.4,0),Vector3.new(1.25,-.4,0),.07,accent)
 elseif identity=='combat' then
  drone('Charger',3.1,Vector3.new(0,.45,0),CFrame.Angles(0,-.4,-.22))
  for i=-1,1 do ray(Vector3.new(i*.6,-.45,.2),Vector3.new(i*.9,-1.65,.2),.12,accent) end
  chips(Vector3.new(0,-1.6,0),accent)
 else
  drone('Striker',2,Vector3.new(-.8,1.05,0),CFrame.Angles(0,-.25,-.1))
  crystal(2.7,Vector3.new(.45,-.7,0),accent,CFrame.Angles(0,.35,-.17))
  ray(Vector3.new(-.8,.6,0),Vector3.new(.1,.05,0),.11,accent);chips(Vector3.new(0,-1.5,0),body:Lerp(accent,.65))
 end
 return viewport,camera
end
local function visibleRect(root)
 local position,size=root.AbsolutePosition,root.AbsoluteSize
 local left,top,right,bottom=position.X,position.Y,position.X+size.X,position.Y+size.Y
 local ancestor=root
 while ancestor do
  if ancestor:IsA('GuiObject') then
   if not ancestor.Visible then return nil end
   if ancestor~=root and (ancestor.ClipsDescendants or ancestor:IsA('ScrollingFrame')) then
    local p,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
    left=math.max(left,p.X);top=math.max(top,p.Y);right=math.min(right,p.X+s.X);bottom=math.min(bottom,p.Y+s.Y)
   end
  elseif ancestor:IsA('ScreenGui') and not ancestor.Enabled then return nil end
  ancestor=ancestor.Parent
 end
 if right-left<2 or bottom-top<2 or size.X<2 or size.Y<2 then return nil end
 return left,top,right,bottom
end
local function onPlane(camera,x,y,depth)
 -- AbsolutePosition and ScreenPointToRay both use CoreUISafeInsets coordinates.
 local ray=camera:ScreenPointToRay(x,y)
 local direction=camera.CFrame:VectorToObjectSpace(ray.Direction)
 return ray.Origin+ray.Direction*(depth/math.max(.001,-direction.Z))
end

function CardView.create(U,parent,choice,index,width,height,options)
 options=options or {};height=math.max(height or CardView.HEIGHT,CardView.MIN_HEIGHT)
 local compact=height<300
 local p=U.palette;local _,bodyColor,accentColor=CardView.identity(choice);local card=U.frame(parent,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),p.paper)
 card.Name='CardChoice'..tostring(index);card.LayoutOrder=index;card.BackgroundTransparency=1
 local choose=U.button(card,UDim2.fromScale(0,0),UDim2.fromScale(1,1),'',options.onChoose,p.paper)
 choose.Name='ChooseCard';choose.TextTransparency=1;choose.BackgroundTransparency=1
 local outline=choose:FindFirstChildOfClass('UIStroke');if outline then outline.Enabled=false end
 local scale=choose:FindFirstChild('ButtonScale');if scale then scale:Destroy() end
 local model=Instance.new('Folder');model.Name='LocalUpgradeCard';model.Parent=workspace
 local part=visualPart(model,Vector3.new(2,3,.05),Vector3.zero,Color3.fromRGB(74,83,88));part.Name='CardBody';part.Transparency=1
 local surface=Instance.new('SurfaceGui');surface.Name='UpgradeCardFace';surface.Adornee=part;surface.Face=Enum.NormalId.Front
 surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.CanvasSize=Vector2.new(width*2,height*2)
 -- The current native renderer drops AlwaysOnTop faces, even on a minimal
 -- diagnostic part. Render these camera-local faces near the camera instead.
 surface.AlwaysOnTop=false;surface.LightInfluence=0;surface.Brightness=1;surface.MaxDistance=8;surface.Active=false;surface.Enabled=false;surface.ResetOnSpawn=false
 surface.ClipsDescendants=true;surface.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;surface.Parent=Players.LocalPlayer:WaitForChild('PlayerGui')
 local canvas=U.frame(surface,UDim2.fromOffset(0,0),UDim2.fromOffset(width*2,height*2),p.paper);canvas.Name='CardCanvas'
 local border=CardView.housing(U,canvas,bodyColor,accentColor);border.Thickness=5
 local artBay=U.frame(canvas,UDim2.fromScale(.035,.028),UDim2.fromScale(.93,compact and .295 or .42),bodyColor:Lerp(Color3.fromRGB(20,27,48),.35))
 artBay.Name='MechanicArtBay'
 local glint,sparks=artFinish(U,artBay,bodyColor,accentColor)
 local separator=U.frame(canvas,UDim2.fromScale(.055,compact and .345 or .465),UDim2.fromScale(.89,.012),accentColor);U.corner(separator,4)
 local footer=U.frame(canvas,UDim2.fromScale(.035,compact and .66 or .75),UDim2.fromScale(.93,compact and .315 or .225),Color3.fromRGB(19,27,47));footer.Name='InsetTerms';U.corner(footer,8);U.stroke(footer,bodyColor:Lerp(accentColor,.3),2)
 local _,artCamera=mechanicVisual(canvas,choice,compact)
 local summary=CardView.summary(choice)
 -- Keep font rasterization and scrolling in the native screen layer. The
 -- body/art retain real perspective; near-camera SurfaceGui glyphs otherwise
 -- lose rows of pixels in the depth pass on the verified phone renderer.
 local effectY=compact and .37 or .49
 local termsY=compact and .68 or .765
 local effect=U.text(card,UDim2.new(0,12,effectY,0),UDim2.new(1,-24,compact and .275 or .245,0),summary,compact and 18 or (width<260 and 20 or 22),p.white,true)
 effect.Name='CardEffect';effect.TextXAlignment=Enum.TextXAlignment.Center
 effect.TextStrokeColor3=Color3.fromRGB(13,23,48);effect.TextStrokeTransparency=.35
 local terms=U.text(card,UDim2.new(0,12,termsY,0),UDim2.new(1,-24,compact and .29 or .20,0),CardView.terms(choice,options.target),16,p.white,false)
 terms.Name='CardTerms';terms.TextXAlignment=Enum.TextXAlignment.Center
 local focused,pressed,blend=false,false,0
 local revealSpeed=math.clamp(options.revealSpeed or 1,1,4);local revealStart=os.clock()+((index-1)*.14)/revealSpeed
 local reducedMotion=options.reducedMotion==true
 pcall(function() reducedMotion=GuiService.ReducedMotionEnabled end)
 local function motionReduced()
  return reducedMotion or options.reducedMotion==true or Players.LocalPlayer:GetAttribute('ReducedMotion')==true or Players.LocalPlayer:GetAttribute('MA_ReducedMotion')==true
 end
 local signals={}
 local function connect(signal,fn) table.insert(signals,signal:Connect(fn)) end
 connect(choose.MouseEnter,function() focused=true end);connect(choose.MouseLeave,function() focused=false;pressed=false end)
 connect(choose.SelectionGained,function() focused=true end);connect(choose.SelectionLost,function() focused=false;pressed=false end)
 connect(choose.MouseButton1Down,function() pressed=true end);connect(choose.MouseButton1Up,function() pressed=false end)
 pcall(function() connect(GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'),function() reducedMotion=GuiService.ReducedMotionEnabled end) end)
 serial=serial+1;local stepName='UpgradeCard'..serial
 local dead=false;local wasFocused=false;local focusAt=-10
 local function dispose()
  if dead then return end;dead=true;RunService:UnbindFromRenderStep(stepName)
  for _,connection in ipairs(signals) do connection:Disconnect() end
  surface:Destroy();model:Destroy()
 end
 connect(card.Destroying,dispose)
 RunService:BindToRenderStep(stepName,Enum.RenderPriority.Camera.Value+8,function(dt)
  if dead then return end
  local camera=workspace.CurrentCamera;local left,top,right,bottom=visibleRect(card)
  if not camera or not left then surface.Enabled=false;part.Transparency=1;return end
  local clock=os.clock();local age=clock-revealStart;local quiet=motionReduced()
  if not quiet and age<0 then choose.Visible=false;surface.Enabled=false;part.Transparency=1;return end
  choose.Visible=true
  local reveal=quiet and 1 or math.clamp(age/(.55/revealSpeed),0,1);reveal=1-(1-reveal)^3
  local position,size=card.AbsolutePosition,card.AbsoluteSize
  local full=right-left>=size.X-.5 and bottom-top>=size.Y-.5
  local target=focused and choose.Active and 1 or 0
  if target==1 and not wasFocused then focusAt=clock end;wasFocused=target==1
  blend=quiet and target or blend+(target-blend)*(1-math.exp(-18*math.min(dt,.1)))
  local lift=(full and not quiet and blend*5 or 0)-(1-reveal)*18-(pressed and 2 or 0)
  effect.Position=UDim2.new(0,12,effectY,-lift);terms.Position=UDim2.new(0,12,termsY,-lift)
  effect.Visible=age>=0 or quiet;terms.Visible=effect.Visible
  local depth=1;local center=onPlane(camera,(left+right)/2,(top+bottom)/2-lift,depth+.015)
  local w=(onPlane(camera,right,(top+bottom)/2,depth)-onPlane(camera,left,(top+bottom)/2,depth)).Magnitude
  local h=(onPlane(camera,(left+right)/2,top,depth)-onPlane(camera,(left+right)/2,bottom,depth)).Magnitude
  local tilt=full and not quiet and math.rad((index-2)*2+blend*3+(1-reveal)*25) or 0
  part.Size=Vector3.new(math.max(.01,w),math.max(.01,h),.02)
  part.CFrame=CFrame.new(center)*camera.CFrame.Rotation*CFrame.Angles(0,math.pi+tilt,0)
  part.Transparency=0;surface.Enabled=true;surface.CanvasSize=Vector2.new((right-left)*2,(bottom-top)*2)
  canvas.Size=UDim2.fromOffset(size.X*2,size.Y*2);canvas.Position=UDim2.fromOffset((position.X-left)*2,(position.Y-top)*2)
  canvas.BackgroundColor3=not choose.Active and bodyColor:Lerp(p.ink,.25) or pressed and bodyColor:Lerp(p.ink,.18) or bodyColor:Lerp(accentColor,blend*.12)
  border.Color=focused and accentColor or Color3.fromRGB(20,27,48);border.Thickness=focused and 7 or 5
  -- One opening sweep, then a short focus response. Everything settles.
  local opening=age*revealSpeed
  local pulse=clock-focusAt
  local sweep=opening<.75 and opening/.75 or (pulse<.45 and pulse/.45 or 2)
  glint.Visible=not quiet and full and sweep>=0 and sweep<=1
  if glint.Visible then glint.Position=UDim2.fromScale(-.6+sweep*2.1,-.4) end
  for i,spark in ipairs(sparks) do
   spark.Visible=not quiet and full and target==1 and pulse<.35
   if spark.Visible then
    local progress=math.clamp(pulse/.35,0,1);local a=(i-.5)*math.pi/2
    spark.Position=UDim2.fromScale(.5+math.cos(a)*(.26+progress*.26),.5+math.sin(a)*(.22+progress*.24))
    spark.BackgroundTransparency=progress;spark.Rotation=45+progress*35
   end
  end
  artCamera.CFrame=CFrame.lookAt(Vector3.new(4+(quiet and 0 or blend*.65),3,7),Vector3.zero)
  effect.Text=choose.Text~='' and choose.Text or summary
 end)
 return {root=card,button=choose}
end
return CardView
