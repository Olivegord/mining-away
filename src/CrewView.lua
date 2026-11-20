-- Crew ability buttons and their effects.
-- One big round button per drone type. Breaking rocks fills it from the
-- bottom; a full button bounces and sparkles until tapped (Q / F / G, or
-- gamepad X / Y / L1). Every player sees every crew's abilities in the world.
local Crew=require('./CrewAbilities')
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local View={};View.__index=View
View.Abilities=Crew
local KEYS={{Enum.KeyCode.Q,Enum.KeyCode.ButtonX,'Q'},{Enum.KeyCode.F,Enum.KeyCode.ButtonY,'F'},{Enum.KeyCode.G,Enum.KeyCode.ButtonL1,'G'}}
local INK=Color3.fromRGB(16,18,32)
local WHITE=Color3.new(1,1,1)
local SIZE=84

local function corner(parent,radius)
 local c=Instance.new('UICorner');c.CornerRadius=radius or UDim.new(1,0);c.Parent=parent;return c
end
local function label(parent,text,size,color)
 local l=Instance.new('TextLabel');l.BackgroundTransparency=1;l.Text=text;l.Font=Enum.Font.GothamBlack
 l.TextColor3=color or WHITE;l.TextScaled=true;l.TextStrokeColor3=INK;l.TextStrokeTransparency=.35;l.Parent=parent
 local limit=Instance.new('UITextSizeConstraint');limit.MaxTextSize=size;limit.MinTextSize=8;limit.Parent=l
 return l
end
local function pulse(age,duration)
 if age<0 or age>duration then return 0 end
 return math.sin(age/duration*math.pi)*(1-age/duration)
end
local function ease(t) t=math.clamp(t,0,1);return 1-(1-t)^3 end

-- True while the character stands on a square mining field.
function View.inField(world,position)
 local map=world and world:FindFirstChild('Map')
 local run=map and map:FindFirstChild('CrystalRun')
 if not run or not position then return false end
 for _,folder in ipairs(run:GetChildren()) do
  local part=folder:FindFirstChild('Field')
  if part and part:IsA('BasePart') and part:GetAttribute('WholeField') then
   local p=part.CFrame:PointToObjectSpace(position)
   if math.abs(p.X)<=part.Size.X*.5+3 and math.abs(p.Z)<=part.Size.Z*.5+3 and p.Y>-3 and p.Y<14 then return true end
  end
 end
 return false
end

function View.new(refs)
 local self=setmetatable({refs=refs,buttons={},list={},effects={},shocks={},banners={},beams={}},View)
 local dock=Instance.new('Frame');dock.Name='CrewAbilities';dock.BackgroundTransparency=1
 dock.AnchorPoint=Vector2.new(1,1);dock.Size=UDim2.fromOffset(3*(SIZE+12),SIZE+30)
 dock.Parent=refs.gui
 local row=Instance.new('UIListLayout');row.FillDirection=Enum.FillDirection.Horizontal
 row.HorizontalAlignment=Enum.HorizontalAlignment.Right;row.VerticalAlignment=Enum.VerticalAlignment.Bottom
 row.Padding=UDim.new(0,12);row.SortOrder=Enum.SortOrder.LayoutOrder;row.Parent=dock
 self.dock=dock
 self.input=UIS.InputBegan:Connect(function(input,processed)
  if processed then return end
  for i,keys in ipairs(KEYS) do
   if input.KeyCode==keys[1] or input.KeyCode==keys[2] then self:fire(i) end
  end
 end)
 local net=game:GetService('ReplicatedStorage'):WaitForChild('MiningAway')
 local event=net:WaitForChild('CrewFX',10)
 if event then self.fxConnection=event.OnClientEvent:Connect(function(record) self:onFX(record) end) end
 return self
end

function View:button(i)
 local b=self.buttons[i]
 if b then return b end
 local holder=Instance.new('Frame');holder.Name='Ability'..i;holder.BackgroundTransparency=1
 holder.Size=UDim2.fromOffset(SIZE,SIZE+26);holder.LayoutOrder=i;holder.Parent=self.dock
 local ring=Instance.new('TextButton');ring.Name='Button';ring.Text='';ring.AutoButtonColor=false
 ring.Size=UDim2.fromOffset(SIZE,SIZE);ring.BackgroundColor3=INK;ring.BackgroundTransparency=.15
 ring.ClipsDescendants=false;ring.Parent=holder;corner(ring)
 local scale=Instance.new('UIScale');scale.Parent=ring
 local stroke=Instance.new('UIStroke');stroke.Thickness=3;stroke.Color=WHITE;stroke.Transparency=.4;stroke.Parent=ring
 -- The fill is a full circle; a gradient hides everything above the level,
 -- so it stays round (Roblox does not clip children to rounded corners).
 local fill=Instance.new('Frame');fill.Name='Fill';fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(1,1)
 fill.BackgroundTransparency=0;fill.Parent=ring;corner(fill)
 local wave=Instance.new('UIGradient');wave.Rotation=-90;wave.Parent=fill
 local name=label(ring,'',17);name.AnchorPoint=Vector2.new(.5,.5);name.Position=UDim2.fromScale(.5,.5);name.Size=UDim2.fromScale(.86,.4)
 name.TextWrapped=true;name.ZIndex=3
 local key=label(holder,'',15,Color3.fromRGB(230,232,255));key.Size=UDim2.new(1,0,0,20);key.Position=UDim2.new(0,0,1,-20)
 ring.Activated:Connect(function() self:fire(i) end)
 b={holder=holder,ring=ring,scale=scale,stroke=stroke,fill=fill,wave=wave,name=name,key=key,readyAt=nil,shown=0}
 self.buttons[i]=b
 return b
end

function View:fire(i)
 local entry=self.list[i]
 local profile=self.refs.profile()
 if not entry or not profile or not self.visible then return end
 local b=self.buttons[i]
 if entry.charge<entry.need then
  if b then b.denyAt=os.clock() end
  self.refs.audio:play('click',nil,{level=.5,pitch=.7})
  return
 end
 if b then b.firedAt=os.clock() end
 self.refs.command:FireServer('CrewAbility',{role=entry.role,runId=profile.run.id})
end

-- Big centered payoff word for the player who fired it.
function View:banner(text,color)
 local card=label(self.refs.gui,text,72,color);card.AnchorPoint=Vector2.new(.5,.5)
 card.Position=UDim2.fromScale(.5,.24);card.Size=UDim2.new(.8,0,0,84);card.TextStrokeTransparency=.05
 local scale=Instance.new('UIScale');scale.Parent=card
 table.insert(self.banners,{gui=card,scale=scale,start=os.clock()})
end

function View:onFX(record)
 if type(record)~='table' then return end
 local mine=record.owner==self.refs.player.UserId
 local color=typeof(record.color)=='Color3' and record.color or WHITE
 if mine then self:banner(string.upper(tostring(record.name or 'Ability'))..'!',color) end
 if record.kind=='Barrage' and type(record.shots)=='table' then
  if mine then self.refs.audio:play('charge',nil,{level=.8,pitch=1.4}) end
  for _,shot in ipairs(record.shots) do
   if type(shot)=='table' and typeof(shot.position)=='Vector3' and type(shot.at)=='number' then
    table.insert(self.beams,{drone=tostring(shot.drone),position=shot.position,at=shot.at,color=color,mine=mine,start=workspace:GetServerTimeNow()})
   end
  end
 elseif record.kind=='Shockwave' and typeof(record.position)=='Vector3' then
  self:shockwave(record.position,color,tonumber(record.radius) or 12,tonumber(record.impact) or .42,mine)
 end
end

local function beamPart(folder,name,color)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=color;p.Shape=Enum.PartType.Cylinder;p.Parent=folder
 return p
end
local function stretch(part,from,to,width)
 local d=(to-from).Magnitude
 part.Size=Vector3.new(math.max(.05,d),width,width)
 part.CFrame=CFrame.lookAt((from+to)/2,to)*CFrame.Angles(0,math.pi/2,0)
end
-- Barrage: each drone glows while it charges, then fires one thick beam.
function View:stepBeams(serverNow)
 for i=#self.beams,1,-1 do
  local b=self.beams[i]
  local view=self.refs.localFX:FindFirstChild('View_'..b.drone)
  local hull=view and (view.PrimaryPart or view:FindFirstChildWhichIsA('BasePart',true))
  local from=hull and hull.Position or b.position+Vector3.new(0,18,0)
  local left=b.at-serverNow
  if left>0 then
   -- Charging: a bright orb grows under the drone and a thin aim line appears.
   b.orb=b.orb or beamPart(self.refs.localFX,'CrewCharge',WHITE:Lerp(b.color,.4))
   b.orb.Shape=Enum.PartType.Ball
   local t=1-math.clamp(left/.7,0,1)
   local d=.4+t*1.6
   b.orb.Size=Vector3.new(d,d,d);b.orb.CFrame=CFrame.new(from-Vector3.yAxis*1.4);b.orb.Transparency=.3-.25*t
   b.aim=b.aim or beamPart(self.refs.localFX,'CrewAim',b.color)
   stretch(b.aim,from,b.position,.08+t*.12);b.aim.Transparency=.7-.4*t
  else
   if not b.fired then
    b.fired=true
    if b.orb then b.orb:Destroy();b.orb=nil end
    if b.aim then b.aim:Destroy();b.aim=nil end
    b.beam=beamPart(self.refs.localFX,'CrewBeam',WHITE:Lerp(b.color,.25))
    b.glow=beamPart(self.refs.localFX,'CrewBeamGlow',b.color);b.glow.Transparency=.55
    RoleVisuals.ImpactParticles(b.position+Vector3.yAxis*1.2,b.color,1.6,'CrystalBreak')
    self.refs.audio:play('prism_fire',b.position,{level=b.mine and .9 or .5})
    if self.refs.presentation then self.refs.presentation:cameraBeat('Split',b.position,os.clock(),b.mine and 1 or .4) end
   end
   local age=-left
   local t=math.clamp(age/.32,0,1)
   stretch(b.beam,from,b.position,1.1*(1-t)+.05)
   stretch(b.glow,from,b.position,2.6*(1-t)+.1)
   b.beam.Transparency=t;b.glow.Transparency=.55+.45*t
   if t>=1 then b.beam:Destroy();b.glow:Destroy();table.remove(self.beams,i) end
  end
 end
end

-- A glowing ring sweeps in, then everything inside it bursts.
function View:shockwave(position,color,radius,impact,mine)
 local folder=self.refs.localFX
 local ring=Instance.new('Part');ring.Name='CrewShockwave';ring.Anchored=true;ring.CanCollide=false;ring.CanQuery=false;ring.CanTouch=false
 ring.Shape=Enum.PartType.Cylinder;ring.Material=Enum.Material.Neon;ring.Color=color;ring.CastShadow=false
 ring.Size=Vector3.new(.25,radius*2,radius*2);ring.CFrame=CFrame.new(position+Vector3.yAxis*.4)*CFrame.Angles(0,0,math.pi/2)
 ring.Transparency=.55;ring.Parent=folder
 local core=ring:Clone();core.Name='CrewShockCore';core.Size=Vector3.new(.3,1,1);core.Transparency=.1;core.Color=WHITE:Lerp(color,.4);core.Parent=folder
 local attachment=Instance.new('Attachment');attachment.Parent=core
 local sparks=Instance.new('ParticleEmitter');sparks.Name='Gather';sparks.Color=ColorSequence.new(WHITE,color)
 sparks.LightEmission=.8;sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,0)})
 sparks.Lifetime=NumberRange.new(.3,.45);sparks.Speed=NumberRange.new(-radius*2.2,-radius*1.6);sparks.SpreadAngle=Vector2.new(180,10)
 sparks.Rate=0;sparks.Shape=Enum.ParticleEmitterShape.Sphere;sparks.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
 sparks.Parent=attachment
 if not self.refs.reduced() then sparks:Emit(mine and 36 or 18) end
 table.insert(self.shocks,{ring=ring,core=core,position=position,color=color,radius=radius,impact=impact,start=os.clock(),mine=mine})
 self.refs.audio:play('geode_windup',position,{level=mine and .9 or .5,pitch=1.25})
end

function View:stepShocks(now)
 for i=#self.shocks,1,-1 do
  local s=self.shocks[i]
  local age=now-s.start
  if age<s.impact then
   local t=ease(age/s.impact)
   local d=s.radius*2*(1-t*.92)
   s.ring.Size=Vector3.new(.25,d,d);s.ring.Transparency=.55-.35*t
   local c=1+t*2.2;s.core.Size=Vector3.new(.3,c,c)
  elseif not s.burst then
   s.burst=true
   s.ring.Size=Vector3.new(.25,1,1)
   local scale=1.4+s.radius*.09
   RoleVisuals.ImpactParticles(s.position+Vector3.yAxis*.8,s.color,scale,'CrystalBreak')
   self.refs.audio:play('geode_break',s.position,{level=s.mine and 1 or .55})
   self.refs.audio:play('prism_blast',s.position,{level=s.mine and .55 or .3})
   if self.refs.presentation then self.refs.presentation:cameraBeat('HeavySplit',s.position,os.clock(),s.mine and 1 or .5) end
  else
   local t=math.clamp((age-s.impact)/.55,0,1)
   local d=2+s.radius*2.6*ease(t)
   s.ring.Size=Vector3.new(.2,d,d);s.ring.Transparency=.25+.75*t
   s.core.Transparency=.1+.9*math.clamp(t*2,0,1)
   if t>=1 then s.ring:Destroy();s.core:Destroy();table.remove(self.shocks,i) end
  end
 end
end

function View:update(now)
 now=now or os.clock()
 local serverNow=workspace:GetServerTimeNow()
 local player=self.refs.player
 local raw=player:GetAttribute('MA_Crew')
 if raw~=self.raw then
  self.raw=raw
  local ok,decoded=pcall(function() return game:GetService('HttpService'):JSONDecode(raw) end)
  self.list=ok and type(decoded)=='table' and decoded or {}
 end
 local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 self.visible=#self.list>0 and root~=nil and View.inField(self.refs.world,root.Position) and not self.refs.hidden()
 self.dock.Visible=self.visible
 -- Leave room for the touch jump button on phones.
 local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 self.dock.Position=touch and UDim2.new(1,-150,1,-18) or UDim2.new(1,-20,1,-20)
 for i=1,math.max(#self.list,#self.buttons) do
  local entry=self.list[i]
  local b=entry and self:button(i) or self.buttons[i]
  if b then
   b.holder.Visible=entry~=nil
   if entry then
    local color=Color3.fromRGB(table.unpack(entry.color or {255,255,255}))
    local ratio=math.clamp((entry.charge or 0)/math.max(1,entry.need or 1),0,1)
    local active=false
    b.shown+=(ratio-b.shown)*.2
    b.fill.BackgroundColor3=color
    -- Rotation -90 runs bottom (0) to top (1): opaque up to the level.
    local level=math.clamp(b.shown,0,1)
    if level<=.001 then b.wave.Transparency=NumberSequence.new(1)
    elseif level>=.999 then b.wave.Transparency=NumberSequence.new(.05)
    else b.wave.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(level,.05),
     NumberSequenceKeypoint.new(math.min(.999,level+.001),1),NumberSequenceKeypoint.new(1,1)}) end
    b.name.Text=entry.name or ''
    local ready=ratio>=1 and not active
    if ready and not b.readyAt then b.readyAt=now;self.refs.audio:play('sale_credit',nil,{level=.7,pitch=1.5}) end
    if not ready then b.readyAt=nil end
    local bounce=ready and (.06*math.sin((now-b.readyAt)*7)+.12*pulse(now-b.readyAt,.35)) or 0
    local deny=b.denyAt and -.08*pulse(now-b.denyAt,.25) or 0
    local fired=b.firedAt and .25*pulse(now-b.firedAt,.3) or 0
    b.scale.Scale=1+bounce+deny+fired
    b.stroke.Color=ready and WHITE or color;b.stroke.Thickness=ready and 4+2*math.sin(now*9) or 3
    b.stroke.Transparency=ready and 0 or .45
    b.ring.BackgroundColor3=INK:Lerp(color,ready and .25 or .05)
    local keys=KEYS[i]
    b.key.Text=touch and '' or (ready and ('Press '..keys[3]) or keys[3])
    b.key.TextColor3=ready and WHITE or Color3.fromRGB(170,175,205)
   end
  end
 end
 for i=#self.banners,1,-1 do
  local banner=self.banners[i]
  local age=now-banner.start
  banner.scale.Scale=.6+.5*ease(age/.18)-.1*ease((age-.18)/.3)
  local fade=math.clamp((age-1.1)/.35,0,1)
  banner.gui.TextTransparency=fade;banner.gui.TextStrokeTransparency=.05+.95*fade
  banner.gui.Visible=not self.refs.hidden()
  if age>1.5 then banner.gui:Destroy();table.remove(self.banners,i) end
 end
 self:stepShocks(now)
 self:stepBeams(serverNow)
end

function View:blocks(point)
 if not self.dock.Visible then return false end
 local p,s=self.dock.AbsolutePosition,self.dock.AbsoluteSize
 return point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y
end

function View:destroy()
 if self.input then self.input:Disconnect() end
 if self.fxConnection then self.fxConnection:Disconnect() end
 self.dock:Destroy()
end
return View
