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
return A
