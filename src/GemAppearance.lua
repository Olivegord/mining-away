-- One shared local mesh gives loose gems hard normals and colored internal facets.
-- Keep the original replicated pickup as the authoritative source and fallback.
local Gem={}
local template,mesh,attempted
function Gem.prepare()
 if attempted then return end
 attempted=true
 local ok,result=pcall(function()
  local assets=game:GetService('AssetService')
  mesh=assert(assets:CreateEditableMesh())
  local positions,ids={},{}
  local function vertex(p)
   positions[#positions+1]=p;ids[#ids+1]=mesh:AddVertex(p)
   return #ids
  end
  local rings={}
  for level,spec in ipairs({{.24,.5},{.5,.12},{.47,.04}}) do
   rings[level]={}
   for i=1,8 do
    local angle=(i-1)*math.pi/4+math.pi/8
    rings[level][i]=vertex(Vector3.new(math.cos(angle)*spec[1],spec[2],math.sin(angle)*spec[1]))
   end
  end
  local top=vertex(Vector3.new(0,.5,0))
  local tip=vertex(Vector3.new(.04,-.5,-.02))
  local palette={Color3.fromRGB(255,145,181),Color3.fromRGB(190,24,72),Color3.fromRGB(102,9,52),
   Color3.fromRGB(238,48,104),Color3.fromRGB(255,202,205),Color3.fromRGB(143,12,74),
   Color3.fromRGB(239,76,155),Color3.fromRGB(76,8,43)}
  local colors={}
  for i,color in ipairs(palette) do colors[i]=mesh:AddColor(color:Lerp(Color3.new(0,0,0),.48),.72) end
  local function triangle(a,b,c,color,gradient)
   local normal=(positions[b]-positions[a]):Cross(positions[c]-positions[a])
   local center=(positions[a]+positions[b]+positions[c])/3
   if normal:Dot(center)<0 then b,c=c,b;normal=-normal end
   local face=mesh:AddTriangle(ids[a],ids[b],ids[c])
   local n=mesh:AddNormal(normal.Unit)
   mesh:SetFaceNormals(face,{n,n,n})
   mesh:SetFaceColors(face,{colors[color],colors[gradient or color],colors[color]})
  end
  for i=1,8 do
   local j=i%8+1
   triangle(top,rings[1][i],rings[1][j],1)
   triangle(rings[1][i],rings[2][i],rings[2][j],i,(i+2)%8+1)
   triangle(rings[1][i],rings[2][j],rings[1][j],j)
   triangle(rings[2][i],rings[3][i],rings[3][j],5)
   triangle(rings[2][i],rings[3][j],rings[2][j],5)
   triangle(rings[3][i],tip,rings[3][j],(i+3)%8+1,i)
  end
  -- Tiny solid inclusions have stable local positions and true depth/parallax.
  -- They share the gem mesh, so rotation never turns them into orbiting sparkles.
  colors[9]=mesh:AddColor(Color3.fromRGB(255,243,255),1)
  local random=Random.new(593)
  for i=1,26 do
   local y=random:NextNumber(-.24,.30)
   local radius=(.38-math.abs(y)*.55)*math.sqrt(random:NextNumber())
   local angle=random:NextNumber(0,math.pi*2)
   local center=Vector3.new(math.cos(angle)*radius,y,math.sin(angle)*radius)
   local size=random:NextNumber(.003,.006)
   local a=vertex(center+Vector3.new(size,size,size))
   local b=vertex(center+Vector3.new(-size,-size,size))
   local c=vertex(center+Vector3.new(-size,size,-size))
   local d=vertex(center+Vector3.new(size,-size,-size))
   triangle(a,b,c,9);triangle(a,d,b,9);triangle(a,c,d,9);triangle(b,d,c,9)
  end
  local part=assets:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
  part.Name='FacetedRuby';part.Anchored=true;part.Color=Color3.new(1,1,1)
  part.Material=Enum.Material.Neon;part.Transparency=.22;part.Reflectance=0;part.DoubleSided=true
  part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  return part
 end)
 if ok then template=result
 elseif mesh then mesh:Destroy();mesh=nil end
end
function Gem.clone(source)
 if not template or source.Name=='PressedCargo' then return source:Clone(),false end
 local part=template:Clone();part.Size=source.Size;part.CFrame=source.CFrame
 for key,value in pairs(source:GetAttributes()) do part:SetAttribute(key,value) end
 return part,true
end
return Gem
