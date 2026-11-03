local checks=0
local function check(name,fn) fn();checks+=1;print('PASS smooth animation '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-5,tostring(a)..' differs from '..tostring(b)) end
local function state() return assert(workspace:FindFirstChild('DroneRoleState')) end
local function visuals() return assert(workspace:FindFirstChild('DroneRoleClientEffects')) end
local function reset()
 RoleVisuals.setTime(nil);RoleVisuals.destroy()
 local source=workspace:FindFirstChild('DroneRoleState');if source then source:Destroy() end
end
check('server emits only state records for all role effects and scrap poses',function()
 realTime=100
 DroneRoleEffects.Beam(Vector3.zero,Vector3.one,Color3.new(1,1,1))
 DroneRoleEffects.Pulse(Vector3.zero,Color3.new(1,1,1))
 DroneRoleEffects.Heal(Vector3.zero,Vector3.one)
 DroneRoleEffects.Charge(Vector3.zero,Vector3.one,true)
 DroneRoleEffects.Grow(Vector3.zero,Vector3.one,true)
 DroneRoleEffects.BreakerPhase(Vector3.zero,Vector3.one,'Impact')
 DroneRoleEffects.Ability(4,{kind='charge',ability='Orbital',target={x=0,y=2,z=0}})
 DroneRoleEffects.Ability(4,{kind='orbital',target={x=0,y=2,z=0}})
 local template=Instance.new('Model');template.Parent=rs
 DroneRoleEffects.Ability(4,{kind='scrapPose',expires=110,bots={{id=1,x=0,y=3,z=0,active=true,pulse=1}}},template)
 for _,node in ipairs(state():GetDescendants()) do
  assert(node:IsA('Folder') or node:IsA('ObjectValue'),'server created animated geometry: '..node.ClassName)
 end
 assert(not workspace:FindFirstChild('DroneRoleClientEffects'),'server called the visual renderer')
 local swarm=state():FindFirstChild('ScrapSwarm');local bot=swarm:FindFirstChild('ScrapBot_1')
 assert(bot:GetAttribute('PoseAt')==100 and swarm.Template.Value==template)
 DroneRoleEffects.ClearAbility(4);assert(swarm.Parent==nil)
 reset();template:Destroy()
end)
check('two observers and a late join evaluate identical authoritative pulse time',function()
 realTime=200;DroneRoleEffects.Pulse(Vector3.zero,Color3.new(1,1,1),1,5,.8)
 local size
 for _,start in ipairs({200,200.1,200.24}) do
  local client=RoleEffectView.new();realTime=start;client:step(start)
  realTime=200.3;client:step(realTime)
  local parts=visuals():GetChildren();assert(#parts==1,'receipt replayed or disappeared')
  if size then near(parts[1].Size.X,size) else size=parts[1].Size.X end
  near(parts[1].Size.X,1+4*(1-(1-.3/.8)^2))
  client:step(realTime);assert(#visuals():GetChildren()==1,'receipt replayed on next frame')
  client:destroy()
 end
 reset()
end)
check('each display frame advances a local pulse at 30 60 and 144 fps',function()
 for _,fps in ipairs({30,60,144}) do
  realTime=300;DroneRoleEffects.Pulse(Vector3.zero,Color3.new(1,1,1),1,5,1)
  local client=RoleEffectView.new();client:step(300)
  local part=visuals():GetChildren()[1];local previous=part.Size.X
  for i=1,fps do realTime=300+i/fps;client:step(realTime);assert(part.Size.X>previous,'held pose between frames');previous=part.Size.X end
  near(part.Size.X,5);client:destroy();reset()
 end
end)
check('late join skips old impacts and ended orbitals',function()
 realTime=400;DroneRoleEffects.BreakerPhase(Vector3.zero,Vector3.one,'Impact')
 DroneRoleEffects.Ability(5,{kind='orbital',target={x=0,y=2,z=0}})
 DroneRoleEffects.Ability(5,{kind='orbitalEnd'})
 realTime=400.6;local client=RoleEffectView.new();client:step(realTime)
 assert(not workspace:FindFirstChild('DroneRoleClientEffects'),'late join replayed an old hit or strike')
 client:destroy();reset()
end)
check('orbital follows buffered position and ends without replay or server transforms',function()
 realTime=500;DroneRoleEffects.Ability(6,{kind='orbital',target={x=0,y=2,z=0}})
 local client=RoleEffectView.new();client:step(realTime)
 realTime=500.1;DroneRoleEffects.Ability(6,{kind='orbital',target={x=1,y=2,z=0}});client:step(realTime)
 realTime=500.15;client:step(realTime)
 local group=visuals():FindFirstChild('OrbitalMelt');near(group:GetAttribute('Position').X,.3)
 near(group:FindFirstChild('MeltCore').Position.X,.3)
 assert(#visuals():GetChildren()==1,'each frame rebuilt the orbital')
 DroneRoleEffects.Ability(6,{kind='orbitalEnd'});client:step(realTime)
 assert(group:GetAttribute('EndedAt')==realTime)
 local first=group.MeltCore.Size.Y
 realTime=500.2;client:step(realTime);assert(group.MeltCore.Size.Y<first)
 local count=#group:GetDescendants();client:step(realTime+.05);assert(#group:GetDescendants()==count,'end replayed afterglow')
 client:destroy();reset()
end)
check('overlapping charge receipts cannot cancel the newer charge',function()
 realTime=600;local client=RoleEffectView.new()
 DroneRoleEffects.Ability(7,{kind='charge',ability='Orbital',target={x=0,y=2,z=0}});client:step(realTime)
 DroneRoleEffects.Ability(7,{kind='charge',ability='Orbital',target={x=1,y=2,z=0}});client:step(realTime)
 local groups=visuals():GetChildren();local count=0
 for _,group in ipairs(groups) do if group.Name=='OrbitalTargetSight' then count+=1;near(group.ThinRedTargetCylinder.Position.X,1) end end
 assert(count==1);client:destroy();DroneRoleEffects.ClearAbility(7);reset()
end)
check('interpolation is frame-rate independent and bounded under delayed packets',function()
 for _,fps in ipairs({30,60,144}) do
  local samples={};local nextSample=0;local previous
  for frame=0,fps*2 do
   local now=frame/fps
   while nextSample<=now+1e-8 do
    MotionBuffer.push(samples,nextSample,CFrame.new(nextSample*10,0,0));nextSample+=.1
   end
   local x=MotionBuffer.pose(samples,now).Position.X
   if now>=.2 then near(x,(now-MotionBuffer.DELAY)*10) end
   if previous and now>.3 then near(x-previous,10/fps) end
   previous=x
  end
  assert(#samples<=6)
  local last=samples[#samples];near(MotionBuffer.pose(samples,50).Position.X,last.pose.Position.X+1)
  local before=#samples;MotionBuffer.push(samples,last.at-.5,CFrame.new(999,0,0));assert(#samples==before)
  MotionBuffer.push(samples,last.at+.1,last.pose);near(MotionBuffer.pose(samples,50).Position.X,last.pose.Position.X)
  MotionBuffer.push(samples,last.at+.2,CFrame.new(),true);near(MotionBuffer.pose(samples,50).Position.X,0)
 end
end)
check('partially replicated receipts wait until every required field is present',function()
 realTime=700
 local root=Instance.new('Folder');root.Name='DroneRoleState';root.Parent=workspace
 local client=RoleEffectView.new();local receipt=Instance.new('Folder')
 receipt:SetAttribute('Kind','Beam');receipt:SetAttribute('StartedAt',700);receipt:SetAttribute('Position',Vector3.one);receipt.Parent=root
 client:step(700);assert(not workspace:FindFirstChild('DroneRoleClientEffects'))
 receipt:SetAttribute('Color',Color3.new(1,1,1));receipt:SetAttribute('From',Vector3.zero)
 receipt:SetAttribute('Duration',.5);receipt:SetAttribute('Width',.2)
 client:step(700.1);assert(#visuals():GetChildren()==1)
 client:destroy();reset()
end)
check('render teardown disconnects all state observers',function()
 local client=RoleEffectView.new();local connections=table.clone(client.connections)
 client:destroy();for _,c in ipairs(connections) do assert(not c.on) end
 assert(not next(client.records))
end)
print(checks..' production state/client timeline checks; API doubles, no Studio Play')
