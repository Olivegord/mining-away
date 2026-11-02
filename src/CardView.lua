-- Presentation only. Two text elements per card: effect and target/terms.
-- The complete saved server choice remains the selection contract.
local CardView={HEIGHT=320,MIN_HEIGHT=304}

local function percent(value) return string.format('%g%%',math.floor(value*100+.5)) end
local function amount(value,label) return '+'..percent(value)..' '..label end
local function reach(choice,key,fallback)
 for _,row in ipairs(choice.preview or {}) do if type(row)=='table' and row.label==key and type(row.after)=='number' then return row.after end end
 return fallback
end

function CardView.summary(choice)
 local e=choice.effects or {};local lines={}
 local function add(key,text) if type(e[key])=='number' and e[key]>0 then table.insert(lines,text) end end
 add('orbitalLaser','Unlock orbital strikes on the biggest rock')
 add('scrapSwarm','Unlock a 10-second swarm of tiny miners')
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
local function mechanicVisual(parent,choice)
 local viewport=Instance.new('ViewportFrame');viewport.Name='MechanicPreview';viewport.BackgroundTransparency=1;viewport.ZIndex=parent.ZIndex+2
 viewport.Position=UDim2.fromScale(.06,.035);viewport.Size=UDim2.fromScale(.88,.41)
 viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-3);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Name='Mechanic';world.Parent=viewport
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(Vector3.new(4,3,7),Vector3.zero);camera.Parent=viewport;viewport.CurrentCamera=camera
 local e=choice.effects or {};local identity,body,accent=CardView.identity(choice)
 local gray=Color3.fromRGB(27,35,61);local blue=accent;local green=Color3.fromRGB(143,255,163)
 -- An authored instrument stage with six radial teeth makes the silhouettes
 -- legible at card size. Only the scene varies; no extra label competes.
 for i=1,6 do
  local a=i*math.pi/3
  local tooth=visualPart(world,Vector3.new(.14,.38,.18),Vector3.new(math.cos(a)*2,math.sin(a)*1.65,-.7),body:Lerp(accent,.35))
  tooth.CFrame=CFrame.new(tooth.Position)*CFrame.Angles(0,0,a-math.pi/2)
 end
 local function gain(key) return type(e[key])=='number' and e[key]>0 end
 if gain('orbitalLaser') then
  local lens=visualPart(world,Vector3.new(.35,1.8,1.8),Vector3.new(0,1.1,0),gray,Enum.PartType.Cylinder)
  lens.CFrame=CFrame.new(0,1.1,0)*CFrame.Angles(0,0,math.pi/2)
  for i=-1,1 do visualPart(world,Vector3.new(.12,1.6,.12),Vector3.new(i*.7,-.2,0),Color3.fromRGB(231,173,84)) end
 elseif gain('scrapSwarm') then
  local template=workspace:FindFirstChild('Drone') or game:GetService('ReplicatedStorage'):FindFirstChild('Drone')
  if template and template:IsA('Model') then
   for i=1,3 do
    local drone=template:Clone()
    for _,child in ipairs(drone:GetDescendants()) do
     if child:IsA('LuaSourceContainer') or child:IsA('Sound') or child:IsA('BillboardGui') or child:IsA('SurfaceGui') then child:Destroy()
     elseif child:IsA('BasePart') then child.Anchored=true;child.CanCollide=false;child.CanTouch=false;child.CanQuery=false
     elseif child:IsA('Trail') or child:IsA('Beam') or child:IsA('ParticleEmitter') then child.Enabled=false end
    end
    drone:ScaleTo(drone:GetScale()*.14);drone:PivotTo(CFrame.new((i-2)*1.1,i==2 and .5 or -.4,0));drone.Parent=world
    visualPart(world,Vector3.new(.05,.8,.05),Vector3.new((i-2)*1.1,-1.1,0),green)
   end
  end
 elseif identity=='scanner' then
  local dish=visualPart(world,Vector3.new(.3,2.4,2.4),Vector3.zero,gray,Enum.PartType.Cylinder)
  dish.CFrame=CFrame.Angles(0,math.pi/2,0)
  visualPart(world,Vector3.new(.22,.22,1.6),Vector3.new(0,0,.6),accent)
  for i=-1,1 do visualPart(world,Vector3.new(.32,.32,.32),Vector3.new(i*.85,i==0 and -.85 or .5,.6),green,Enum.PartType.Ball) end
 elseif identity=='prism' then
  local prism=visualPart(world,Vector3.new(1.1,1.8,1.1),Vector3.zero,accent)
  prism.CFrame=CFrame.Angles(0,math.rad(45),math.rad(30))
  for i=-1,1,2 do
   local beam=visualPart(world,Vector3.new(.14,1.8,.14),Vector3.new(i*.7,-.8,0),i<0 and green or Color3.fromRGB(255,139,217))
   beam.CFrame=CFrame.new(beam.Position)*CFrame.Angles(0,0,i*.5)
  end
 elseif gain('capacity') or gain('fullAuto') then
  visualPart(world,Vector3.new(1.8,1.9,.7),Vector3.zero,gray)
  visualPart(world,Vector3.new(1.3,.7,.25),Vector3.new(0,-.45,.5),blue)
  visualPart(world,Vector3.new(.25,1.5,.3),Vector3.new(-.55,.1,-.5),gray)
  visualPart(world,Vector3.new(.25,1.5,.3),Vector3.new(.55,.1,-.5),gray)
 elseif gain('health') or gain('reduction') or gain('salvage') or gain('shield') then
  visualPart(world,Vector3.new(1.8,1.8,.4),Vector3.zero,gray)
  visualPart(world,Vector3.new(.45,1.4,.15),Vector3.new(0,0,.3),green)
  visualPart(world,Vector3.new(1.4,.45,.15),Vector3.new(0,0,.3),green)
 elseif gain('combat') or gain('rate') or gain('crit') or gain('splash') or gain('finisher') or gain('range') then
  local lens=visualPart(world,Vector3.new(.7,1.8,1.8),Vector3.zero,gray,Enum.PartType.Cylinder);lens.CFrame=CFrame.Angles(0,math.pi/2,0)
  local core=visualPart(world,Vector3.new(.15,.95,.95),Vector3.new(0,0,.4),accent,Enum.PartType.Cylinder);core.CFrame=CFrame.new(0,0,.4)*CFrame.Angles(0,math.pi/2,0)
 elseif gain('speed') or gain('startup') then
  for i=-1,1 do local fin=visualPart(world,Vector3.new(1.9,.25,.55),Vector3.new(0,i*.6,0),i==0 and blue or gray);fin.CFrame=CFrame.new(0,i*.6,0)*CFrame.Angles(0,0,math.rad(-20)) end
 else
  local original=game:GetService('ReplicatedStorage'):FindFirstChild('Crystal')
  local template=original and original:FindFirstChild('Mesh')
  local crystal=template and template:IsA('BasePart') and template:Clone() or Instance.new('WedgePart')
  for _,child in ipairs(crystal:GetDescendants()) do if child:IsA('LuaSourceContainer') then child:Destroy() end end
  crystal.Size=Vector3.one*1.7;crystal.CFrame=CFrame.Angles(0,math.rad(30),math.rad(-12));crystal.Color=blue;crystal.Material=Enum.Material.Slate;crystal.Reflectance=0
  crystal.Anchored=true;crystal.CanCollide=false;crystal.CanTouch=false;crystal.CanQuery=false;crystal.Parent=world
  visualPart(world,Vector3.new(.5,.5,.5),Vector3.new(0,1.7,0),gray)
 end
 return viewport
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
 surface.AlwaysOnTop=true;surface.LightInfluence=0;surface.MaxDistance=20;surface.Active=false;surface.Enabled=false;surface.ResetOnSpawn=false
 surface.ClipsDescendants=true;surface.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;surface.Parent=Players.LocalPlayer:WaitForChild('PlayerGui')
 local canvas=U.frame(surface,UDim2.fromOffset(0,0),UDim2.fromOffset(width*2,height*2),p.paper);canvas.Name='CardCanvas'
 local border=U.stroke(canvas,Color3.fromRGB(20,27,48),5)
 canvas.BackgroundColor3=bodyColor
 local artBay=U.frame(canvas,UDim2.fromScale(.025,.02),UDim2.fromScale(.95,.43),bodyColor:Lerp(Color3.fromRGB(20,27,48),.42))
 artBay.Name='MechanicArtBay'
 U.frame(canvas,UDim2.fromScale(.04,.465),UDim2.fromScale(.92,.012),accentColor)
 U.frame(canvas,UDim2.fromScale(.025,.755),UDim2.fromScale(.95,.225),Color3.fromRGB(19,27,47))
 mechanicVisual(canvas,choice)
 local summary=CardView.summary(choice)
 local effect=U.text(canvas,UDim2.new(0,24,.49,0),UDim2.new(1,-48,.245,0),summary,width<260 and 40 or 44,p.white,true)
 effect.Name='CardEffect';effect.TextXAlignment=Enum.TextXAlignment.Center
 local terms=U.text(canvas,UDim2.new(0,24,.765,0),UDim2.new(1,-48,.20,0),CardView.terms(choice,options.target),32,p.white,false)
 terms.Name='CardTerms';terms.TextXAlignment=Enum.TextXAlignment.Center
 local focused,pressed,blend=false,false,0
 local revealSpeed=math.clamp(options.revealSpeed or 1,1,4);local revealStart=os.clock()+((index-1)*.14)/revealSpeed
 local reducedMotion=false
 pcall(function() reducedMotion=GuiService.ReducedMotionEnabled end)
 local signals={}
 local function connect(signal,fn) table.insert(signals,signal:Connect(fn)) end
 connect(choose.MouseEnter,function() focused=true end);connect(choose.MouseLeave,function() focused=false;pressed=false end)
 connect(choose.SelectionGained,function() focused=true end);connect(choose.SelectionLost,function() focused=false;pressed=false end)
 connect(choose.MouseButton1Down,function() pressed=true end);connect(choose.MouseButton1Up,function() pressed=false end)
 pcall(function() connect(GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'),function() reducedMotion=GuiService.ReducedMotionEnabled end) end)
 serial=serial+1;local stepName='UpgradeCard'..serial
 local dead=false
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
  local age=os.clock()-revealStart
  if not reducedMotion and age<0 then choose.Visible=false;surface.Enabled=false;part.Transparency=1;return end
  choose.Visible=true
  local reveal=reducedMotion and 1 or math.clamp(age/(.55/revealSpeed),0,1);reveal=1-(1-reveal)^3
  local position,size=card.AbsolutePosition,card.AbsoluteSize
  local full=right-left>=size.X-.5 and bottom-top>=size.Y-.5
  local target=focused and choose.Active and 1 or 0
  blend=reducedMotion and target or blend+(target-blend)*(1-math.exp(-18*math.min(dt,.1)))
  local lift=(full and not reducedMotion and blend*3 or 0)-(1-reveal)*18
  local depth=5;local center=onPlane(camera,(left+right)/2,(top+bottom)/2-lift,depth+.025)
  local w=(onPlane(camera,right,(top+bottom)/2,depth)-onPlane(camera,left,(top+bottom)/2,depth)).Magnitude
  local h=(onPlane(camera,(left+right)/2,top,depth)-onPlane(camera,(left+right)/2,bottom,depth)).Magnitude
  local tilt=full and not reducedMotion and math.rad((index-2)*2+blend*2+(1-reveal)*25) or 0
  part.Size=Vector3.new(math.max(.01,w),math.max(.01,h),.05)
  part.CFrame=CFrame.new(center)*camera.CFrame.Rotation*CFrame.Angles(0,math.pi+tilt,0)
  part.Transparency=0;surface.Enabled=true;surface.CanvasSize=Vector2.new((right-left)*2,(bottom-top)*2)
  canvas.Size=UDim2.fromOffset(size.X*2,size.Y*2);canvas.Position=UDim2.fromOffset((position.X-left)*2,(position.Y-top)*2)
  canvas.BackgroundColor3=not choose.Active and bodyColor:Lerp(p.ink,.25) or pressed and bodyColor:Lerp(p.ink,.18) or bodyColor:Lerp(accentColor,blend*.12)
  border.Color=focused and accentColor or Color3.fromRGB(20,27,48);border.Thickness=focused and 7 or 5
  effect.Text=choose.Text~='' and choose.Text or summary
 end)
 return {root=card,button=choose}
end
return CardView
