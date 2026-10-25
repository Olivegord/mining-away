local W={}
function W.part(parent,name,pos,size,color,material)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false
 p.CanQuery=false;p.CanTouch=false;p.Size=size;p.Position=pos;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Parent=parent
 return p
end
function W.label(part,text,offset)
 local b=Instance.new('BillboardGui');b.Name='Readout';b.Size=UDim2.fromOffset(240,64);b.StudsOffset=offset or Vector3.new(0,5,0);b.AlwaysOnTop=true;b.MaxDistance=170;b.Parent=part
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=.25;t.BackgroundColor3=Color3.fromRGB(15,20,32);t.TextColor3=Color3.new(1,1,1);t.TextSize=14;t.Font=Enum.Font.GothamBold;t.TextWrapped=true;t.Text=text;t.Parent=b
 return t
end
function W.beam(parent,color)
 local a=Instance.new('Attachment');a.Parent=parent
 local endpoint=W.part(parent,'Endpoint',parent.Position,Vector3.new(.15,.15,.15),color,Enum.Material.Neon);endpoint.Transparency=1
 local b=Instance.new('Attachment');b.Parent=endpoint
 local beams={}
 for i=1,2 do
  local beam=Instance.new('Beam');beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=true;beam.Segments=1;beam.LightEmission=1
  beam.Color=ColorSequence.new(i==1 and Color3.new(1,1,1) or color)
  beam.Width0=i==1 and .07 or .32;beam.Width1=i==1 and .1 or .5
  beam.Transparency=NumberSequence.new(i==1 and .05 or .7);beam.Enabled=false;beam.Parent=parent;table.insert(beams,beam)
 end
 return {beams=beams,endpoint=endpoint}
end
function W.setBeam(b,on,pos)
 for _,v in ipairs(b.beams) do v.Enabled=on end
 if pos then b.endpoint.Position=pos end
end
function W.drone(parent,template,pos,color)
 local model
 if template and template:IsA('Model') then model=template:Clone() else model=Instance.new('Model') end
 model.Name='Drone'
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Trail') then v.Enabled=false end
 end
 local root=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart',true)
 if not root then root=W.part(model,'Hull',pos,Vector3.new(2,1,2),color) end
 root.CanQuery=false;root.CanTouch=false;model.PrimaryPart=root;model.Parent=parent;model:PivotTo(CFrame.new(pos))
 local eye=W.part(model,'MiningEmitter',pos,Vector3.new(.35,.35,.35),color,Enum.Material.Neon)
 return model,root,eye
end
return W
