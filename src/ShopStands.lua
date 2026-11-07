-- Grounded, named counters at the depot. Reuse the captured PackStation shell;
-- never move the original machine or replace field/world assets.
local Stands={}
function Stands.position(home,index,groundY)
 local offset=({-16,-20,12,24,36})[index]
 return Vector3.new(home.X+offset,groundY+1.5,home.Z+(index==1 and 32 or 18))
end
local function addSign(station,text,height)
  local sign=station:FindFirstChild('ShopSign')
  if not sign then sign=Instance.new('Part');sign.Name='ShopSign';sign.Parent=station end
  sign.Anchored=true;sign.CanCollide=false;sign.CanTouch=false;sign.CanQuery=false
  sign.Size=Vector3.new(7.5,2,.25);sign.CFrame=CFrame.new(station.Position+Vector3.new(0,station.Size.Y/2+height,0));sign.Material=Enum.Material.Metal;sign.Color=Color3.fromRGB(30,30,60)
  for _,side in ipairs({'Front','Back'}) do
   local face=sign:FindFirstChild(side) or Instance.new('SurfaceGui');face.Name=side;face.Face=Enum.NormalId[side]
   face.CanvasSize=Vector2.new(600,160);face.LightInfluence=0;face.Parent=sign
   local title=face:FindFirstChild('ShopName') or Instance.new('TextLabel');title.Name='ShopName'
   title.Size=UDim2.fromScale(1,1);title.BackgroundTransparency=1;title.TextColor3=station.Color
   title.Font=Enum.Font.SourceSansBold;title.TextSize=54;title.Text=text;title.Parent=face
  end
end
function Stands.mount(map,home,template)
 local stations={}
 addSign(template,'PACK SHOP',3)
 local packPrompt=template:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
 packPrompt.ActionText='Browse packs';packPrompt.ObjectText='Pack Shop'
 packPrompt.MaxActivationDistance=12;packPrompt.RequiresLineOfSight=false
 packPrompt.Parent=template
 template:SetAttribute('Interaction','Pack')
 local packBillboard=template:FindFirstChildOfClass('BillboardGui')
 if packBillboard then packBillboard:Destroy() end
 local pad=map:FindFirstChild('HubPad',true)
 local groundY=pad and pad.Position.Y+pad.Size.Y/2 or template.Position.Y-template.Size.Y/2
 for index,key in ipairs(Shops.ORDER) do
  local name=key..'Shop';local station=map:FindFirstChild(name)
  if not station then
   station=template:Clone();station.Name=name
   for _,child in ipairs(station:GetChildren()) do child:Destroy() end
  end
  station.Size=Vector3.new(6,3,4);station.Anchored=true;station.Material=Enum.Material.Metal;station.Reflectance=0
  station.Transparency=0;station.Color=Color3.fromRGB(unpack(Shops.COLORS[key]))
  station:SetAttribute('Interaction','Shop');station:SetAttribute('ShopKey',key);station:SetAttribute('ShopStandVersion',2)
  local position=Stands.position(home,index,groundY)
  station.CFrame=CFrame.new(position);station.Parent=map
  addSign(station,key:upper()..' SHOP',1)
  -- Remove the obsolete face painted onto the low, far-field cube.
  for _,child in ipairs(station:GetChildren()) do if child:IsA('SurfaceGui') then child:Destroy() end end
  local prompt=station:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
  prompt.ActionText='View upgrades';prompt.ObjectText=key..' shop';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=station
  stations[key]=station
 end
 return stations
end
return Stands
