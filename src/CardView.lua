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
 if e.fullAuto and e.fullAuto>0 and choice.scope=='Player' then target='Your couriers'
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
local function mechanicVisual(parent,choice)
 local viewport=Instance.new('ViewportFrame');viewport.Name='MechanicPreview';viewport.BackgroundTransparency=1
 viewport.Position=UDim2.new(.5,-84,0,12);viewport.Size=UDim2.fromOffset(168,112)
 viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-3);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Name='Mechanic';world.Parent=viewport
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(Vector3.new(4,3,7),Vector3.zero);camera.Parent=viewport;viewport.CurrentCamera=camera
 local e=choice.effects or {};local gray=Color3.fromRGB(95,107,114);local blue=Color3.fromRGB(77,144,177);local green=Color3.fromRGB(102,159,114)
 local function gain(key) return type(e[key])=='number' and e[key]>0 end
 if gain('capacity') or gain('fullAuto') then
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
  local core=visualPart(world,Vector3.new(.15,.95,.95),Vector3.new(0,0,.4),Color3.fromRGB(174,102,89),Enum.PartType.Cylinder);core.CFrame=CFrame.new(0,0,.4)*CFrame.Angles(0,math.pi/2,0)
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
 local p=U.palette;local card=U.frame(parent,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),p.paper)
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
 U.stroke(canvas,p.line,3)
 mechanicVisual(canvas,choice)
 local summary=CardView.summary(choice)
 local effect=U.text(canvas,UDim2.new(0,24,0,132),UDim2.new(1,-48,0,292),summary,width<260 and 44 or 48,p.ink,true)
 effect.Name='CardEffect';effect.TextXAlignment=Enum.TextXAlignment.Center
 local terms=U.text(canvas,UDim2.new(0,24,1,-198),UDim2.new(1,-48,0,176),CardView.terms(choice,options.target),32,p.muted,false)
 terms.Name='CardTerms';terms.TextXAlignment=Enum.TextXAlignment.Center
 local focused,pressed,blend=false,false,0
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
  local position,size=card.AbsolutePosition,card.AbsoluteSize
  local full=right-left>=size.X-.5 and bottom-top>=size.Y-.5
  local target=focused and choose.Active and 1 or 0
  blend=reducedMotion and target or blend+(target-blend)*(1-math.exp(-18*math.min(dt,.1)))
  local lift=full and not reducedMotion and blend*3 or 0
  local depth=5;local center=onPlane(camera,(left+right)/2,(top+bottom)/2-lift,depth+.025)
  local w=(onPlane(camera,right,(top+bottom)/2,depth)-onPlane(camera,left,(top+bottom)/2,depth)).Magnitude
  local h=(onPlane(camera,(left+right)/2,top,depth)-onPlane(camera,(left+right)/2,bottom,depth)).Magnitude
  local tilt=full and not reducedMotion and math.rad((index-2)*2+blend*2) or 0
  part.Size=Vector3.new(math.max(.01,w),math.max(.01,h),.05)
  part.CFrame=CFrame.new(center)*camera.CFrame.Rotation*CFrame.Angles(0,math.pi+tilt,0)
  part.Transparency=0;surface.Enabled=true;surface.CanvasSize=Vector2.new((right-left)*2,(bottom-top)*2)
  canvas.Size=UDim2.fromOffset(size.X*2,size.Y*2);canvas.Position=UDim2.fromOffset((position.X-left)*2,(position.Y-top)*2)
  canvas.BackgroundColor3=not choose.Active and p.paper:Lerp(p.muted,.12) or pressed and p.paper:Lerp(p.accent,.22) or p.paper:Lerp(p.white,blend*.16)
  effect.Text=choose.Text~='' and choose.Text or summary
 end)
 return {root=card,button=choose}
end
return CardView
