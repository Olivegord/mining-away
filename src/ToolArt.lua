-- Small original tool silhouettes reused in-world, in hand and in hotbar icons.
local A={}
function A.create(kind,parent,projectile)
 local def=ToolRules.ITEMS[kind];local model=Instance.new('Model');model.Name=kind
 local function part(name,size,offset,color,shape)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=offset;p.Color=color
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=Enum.Material.Metal;if shape then p.Shape=shape end;p.Parent=model;return p
 end
 local color=Color3.fromRGB(table.unpack(def.color));local dark=Color3.fromRGB(24,27,38)
 if kind=='BowlingBall' then
  model.PrimaryPart=part('Ball',Vector3.one*2.1,CFrame.new(),color,Enum.PartType.Ball)
  for _,v in ipairs({Vector3.new(-.24,.73,-.69),Vector3.new(.24,.73,-.69),Vector3.new(0,.36,-.96)}) do
   part('FingerHole',Vector3.new(.23,.23,.14),CFrame.lookAt(v,v*2),dark,Enum.PartType.Ball)
  end
 elseif kind=='Greatsword' then
  model.PrimaryPart=part('Grip',Vector3.new(.29,.95,.29),CFrame.new(),dark)
  part('Guard',Vector3.new(1.6,.22,.42),CFrame.new(0,.55,0),Color3.fromRGB(244,188,86))
  local blade=part('Blade',Vector3.new(1.04,4.15,.22),CFrame.new(0,2.69,0),color)
  blade.Material=Enum.Material.Metal
  part('Edge',Vector3.new(.16,4.05,.25),CFrame.new(-.48,2.65,0),Color3.fromRGB(235,250,255))
  part('Point',Vector3.new(.72,.72,.22),CFrame.new(0,4.74,0)*CFrame.Angles(0,0,math.pi/4),color)
 elseif kind=='Sledgehammer' then
  model.PrimaryPart=part('Handle',Vector3.new(.24,3,.24),CFrame.new(),dark)
  part('Head',Vector3.new(1.95,.86,.9),CFrame.new(0,1.55,0),color)
  part('Strike Face',Vector3.new(.25,.91,.98),CFrame.new(.96,1.55,0),Color3.fromRGB(212,224,232))
 elseif kind=='MoltenTongs' then
  if projectile then
   model.PrimaryPart=part('MoltenSteel',Vector3.one*1.24,CFrame.new(),color,Enum.PartType.Ball)
   model.PrimaryPart.Material=Enum.Material.Neon
  else
   model.PrimaryPart=part('TongsPivot',Vector3.new(.44,.32,.38),CFrame.new(),dark)
   for _,side in ipairs({-1,1}) do
    part('Handle',Vector3.new(.14,2.2,.18),CFrame.new(side*.33,-.52,0)*CFrame.Angles(0,0,side*.2),dark)
    for i=0,6 do
     local a=math.pi*i/6+ (side==1 and -math.pi*.5 or math.pi*.5)
     part('CircularJaw',Vector3.new(.16,.34,.24),CFrame.new(math.cos(a)*.68,1.15+math.sin(a)*.68,0)*CFrame.Angles(0,0,a),Color3.fromRGB(150,161,175))
    end
   end
   local ball=part('MoltenSteel',Vector3.one*1.21,CFrame.new(0,1.15,0),color,Enum.PartType.Ball);ball.Material=Enum.Material.Neon
  end
 elseif kind=='Scrap' or kind=='Orbital' then
  model.PrimaryPart=part('Capsule',Vector3.new(1.18,.78,1.18),CFrame.new(),dark)
  local signal=part('Charge',Vector3.new(.78,.68,.78),CFrame.new(0,.39,0),color,Enum.PartType.Ball);signal.Material=Enum.Material.Neon
  if kind=='Orbital' then part('Beacon',Vector3.new(.14,.86,.14),CFrame.new(0,.86,0),color) end
 elseif kind=='Crowbar' then
  model.PrimaryPart=part('Shaft',Vector3.new(.23,2,.27),CFrame.new(),color)
  part('Grip',Vector3.new(.3,.85,.32),CFrame.new(0,-.5,0),dark)
  part('Hook',Vector3.new(.24,.6,.27),CFrame.new(.17,1.12,0)*CFrame.Angles(0,0,-.7),color)
  part('Claw',Vector3.new(.5,.16,.28),CFrame.new(.49,1.27,0),Color3.fromRGB(204,211,218))
 else
  model.PrimaryPart=part('Jelly',Vector3.one,CFrame.new(),color,Enum.PartType.Ball)
  model.PrimaryPart.Material=Enum.Material.SmoothPlastic;model.PrimaryPart.Transparency=.16
  part('Cap',Vector3.new(.42,.23,.42),CFrame.new(0,.5,0),dark)
  part('Fuse',Vector3.new(.09,.4,.09),CFrame.new(.12,.75,0)*CFrame.Angles(0,0,-.3),Color3.fromRGB(255,225,116))
 end
 model.Parent=parent;return model
end
function A.bar(part,hp,maxHP)
 local gui=Instance.new('BillboardGui');gui.Name='ToolDurability';gui.Adornee=part;gui.Size=UDim2.fromOffset(56,6)
 gui.StudsOffset=Vector3.new(0,1.7,0);gui.AlwaysOnTop=false;gui.MaxDistance=55;gui.Parent=part
 local track=Instance.new('Frame');track.Size=UDim2.fromScale(1,1);track.BackgroundColor3=Color3.fromRGB(28,29,38);track.BorderSizePixel=0;track.Parent=gui
 local fill=Instance.new('Frame');fill.Name='Remaining';fill.Size=UDim2.fromScale(hp/maxHP,1)
 fill.BackgroundColor3=Color3.fromRGB(156,231,102);fill.BorderSizePixel=0;fill.Parent=track
 return fill
end
-- Each pose gives the right shoulder pitch/yaw/roll, elbow pitch, wrist
-- pitch, and left shoulder pitch/roll. The model stays on the palm.
local function pose(x,y,z,elbow,wrist,left,spread)
 return {Vector3.new(x,y,z),Vector3.new(elbow,0,0),Vector3.new(wrist,0,0),Vector3.new(left or 0,0,spread or -8)}
end
local motions={
 BowlingBall={grip=Vector3.new(0,.61,-.75),tilt=-38,
  idle=pose(30,5,17,40,-10,21,12), load=pose(-34,-24,33,52,12,24,-16), strike=pose(86,6,9,12,-19,8,-20), recovery=.38},
 Crowbar={grip=Vector3.new(0,-.54,0),tilt=-83,
  idle=pose(24,2,13,32,0), load=pose(88,-38,36,67,-22,18,-17), strike=pose(66,28,-9,13,21,9,-14), recovery=.24},
 JellyGrenade={grip=Vector3.new(0,.03,-.44),tilt=-35,
  idle=pose(27,2,14,46,0), load=pose(97,-25,34,70,-26,13,-15), strike=pose(91,7,9,10,19,6,-16), recovery=.30},
 Greatsword={grip=Vector3.new(0,-.05,0),tilt=-91,
  idle=pose(28,12,19,39,-13,23,12), load=pose(70,-54,45,58,-19,48,10), strike=pose(77,43,-12,14,21,50,19), recovery=.37},
 Sledgehammer={grip=Vector3.new(0,-1.02,0),tilt=-89,
  idle=pose(27,10,18,40,-7,24,10), load=pose(111,-14,30,64,-11,94,15), strike=pose(42,9,9,8,-76,38,18), recovery=.36},
 MoltenTongs={grip=Vector3.new(.20,-1.14,0),tilt=-98,
  idle=pose(39,4,14,30,-8), load=pose(67,-12,21,42,-11,26,8), strike=pose(81,8,12,7,27,21,-5), recovery=.32},
 Scrap={grip=Vector3.new(0,-.22,-.45),tilt=-60,
  idle=pose(31,6,15,38,-4), load=pose(54,-12,23,60,-8), strike=pose(74,3,9,11,18), recovery=.28},
 Orbital={grip=Vector3.new(0,-.22,-.45),tilt=-64,
  idle=pose(36,7,14,38,-2), load=pose(69,-13,19,53,-16), strike=pose(81,4,8,10,17), recovery=.28},
}
local function smooth(x)
 x=math.clamp(x,0,1)
 return x*x*(3-2*x)
end
local function angles(v)
 return CFrame.Angles(math.rad(v.X),math.rad(v.Y),math.rad(v.Z))
end
function A.armRig(character)
 local joints={}
 local names={RightShoulder=1,RightElbow=2,RightWrist=3,LeftShoulder=4,['Right Shoulder']=1,['Left Shoulder']=4}
 for _,joint in ipairs(character:GetDescendants()) do
  local index=names[joint.Name]
  if index and (joint:IsA('Motor6D') or joint:IsA('AnimationConstraint')) and joint.Part0 then joints[index]=joint end
 end
 return joints
end
function A.poseArms(rig,kind,action,elapsed,heading,weight,applied)
 local motion=motions[kind]
 if not motion then return end
 local from,to,blend=motion.idle,motion.idle,0
 if action and elapsed<0 then
  local windup=ToolRules.ITEMS[kind].windup
  local progress=1+elapsed/windup
  local loadEnd=ToolRules.ITEMS[kind].melee and .70 or .77
  if progress<loadEnd then from,to,blend=motion.idle,motion.load,smooth(progress/loadEnd)
  else from,to,blend=motion.load,motion.strike,smooth((progress-loadEnd)/(1-loadEnd)) end
 elseif action then from,to,blend=motion.strike,motion.idle,smooth(elapsed/motion.recovery) end
 for i,joint in pairs(rig) do
  if not joint.Parent or not joint.Part0 then continue end
  local rotation=from[i]:Lerp(to[i],blend)
  if i==1 then
   rotation+=Vector3.new(rig[2] and 0 or from[2]:Lerp(to[2],blend).X*.42,heading,0)
  elseif i==4 then rotation+=Vector3.new(0,heading*.52,0) end
  local basis=joint.C0.Rotation
  local base=joint.Transform
  joint.Transform=base:Lerp(basis:Inverse()*angles(rotation)*basis,weight)
  applied[joint]=base
 end
end
function A.recovery(kind) return motions[kind] and motions[kind].recovery or 0 end
function A.grip(kind,hand)
 local motion=motions[kind]
 local attachment=hand:FindFirstChild('RightGripAttachment')
 local palm=CFrame.new(attachment and attachment.Position or Vector3.new(0,-hand.Size.Y*.40,0))
 return hand.CFrame*palm*CFrame.Angles(math.rad(motion.tilt),0,0)*CFrame.new(-motion.grip)
end
return A
