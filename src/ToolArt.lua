-- Small original tool silhouettes reused in-world, in hand and in hotbar icons.
local A={}
function A.create(kind,parent)
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
