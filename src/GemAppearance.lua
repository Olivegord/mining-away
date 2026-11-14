-- Shared per-mineral shells and opaque, fixed interior grains.
local Gem={}
local templates,meshes,attempted={},{},false
local rgb=Color3.fromRGB
local definitions={
 Quartz={sides=6,lean=.08,rings={{.18,.5},{.40,.27},{.45,-.30},{.22,-.47}},
  colors={rgb(36,71,123),rgb(64,181,197),rgb(196,255,234),rgb(158,120,231)},aspect=Vector3.new(.68,1.55,.70)},
 Ruby={sides=7,lean=-.12,rings={{.28,.46},{.48,.19},{.44,-.22},{.25,-.44}},
  colors={rgb(65,8,62),rgb(218,26,83),rgb(255,167,123),rgb(255,86,164)},aspect=Vector3.new(.94,1.10,.84)},
 Cobalt={sides=5,lean=.23,rings={{.07,.5},{.32,.27},{.47,-.25},{.20,-.48}},
  colors={rgb(17,20,92),rgb(33,93,235),rgb(133,250,255),rgb(133,52,240)},aspect=Vector3.new(.74,1.60,.63)},
 Violet={sides=6,lean=-.18,rings={{.08,.5},{.43,.10},{.38,-.25},{.07,-.50}},
  colors={rgb(35,13,97),rgb(127,40,216),rgb(255,159,226),rgb(76,197,255)},aspect=Vector3.new(.70,1.46,.78)},
 Emerald={sides=6,lean=.05,rings={{.31,.5},{.47,.28},{.47,-.29},{.26,-.47}},
  colors={rgb(5,60,66),rgb(12,157,116),rgb(197,250,122),rgb(55,232,214)},aspect=Vector3.new(.88,1.34,.73)},
}
function Gem.key(value)
 value=type(value)=='string' and value or 'Quartz'
 value=value:match('^Rock:(%a+):') or value:match('^Block:(%a+):') or value
 value=value:gsub('^Run','')
 return definitions[value] and value or 'Quartz'
end
function Gem.tint(value) return definitions[Gem.key(value)].colors[2] end
local function build(key,spec)
 local assets=game:GetService('AssetService')
 local mesh=assert(assets:CreateEditableMesh());meshes[#meshes+1]=mesh
 local core=assert(assets:CreateEditableMesh());meshes[#meshes+1]=core
 local positions,ids={},{}
 local function vertex(p) positions[#positions+1]=p;ids[#ids+1]=mesh:AddVertex(p);return #ids end
 local function color(p,sector)
  local t=math.clamp(p.Y+.5,0,1)
  local c=t<.52 and spec.colors[1]:Lerp(spec.colors[2],t/.52)
   or spec.colors[2]:Lerp(spec.colors[3],(t-.52)/.48)
  return c:Lerp(spec.colors[4],sector%3==0 and .45 or .08)
 end
 local function triangle(a,b,c,sector)
  local n=(positions[b]-positions[a]):Cross(positions[c]-positions[a])
  if n:Dot((positions[a]+positions[b]+positions[c])/3)<0 then b,c=c,b;n=-n end
  local f=mesh:AddTriangle(ids[a],ids[b],ids[c]);local normal=mesh:AddNormal(n.Unit)
  mesh:SetFaceNormals(f,{normal,normal,normal})
  local colors={}
  for _,v in ipairs({a,b,c}) do
   local tint=color(positions[v],sector)
   colors[#colors+1]=mesh:AddColor(tint:Lerp(Color3.new(0,0,0),sector%2==0 and .12 or .38),.86)
  end
  mesh:SetFaceColors(f,colors)
 end
 local rings={}
 for level,ring in ipairs(spec.rings) do
  rings[level]={}
  for i=1,spec.sides do
   local angle=(i-1)*2*math.pi/spec.sides+.19
   local radius=ring[1]*(i%3==0 and .88 or 1)
   rings[level][i]=vertex(Vector3.new(math.cos(angle)*radius+ring[2]*spec.lean,ring[2],math.sin(angle)*radius))
  end
 end
 local top=vertex(Vector3.new(spec.lean*.5,.5,0));local bottom=vertex(Vector3.new(-spec.lean*.45,-.5,0))
 for i=1,spec.sides do
  local j=i%spec.sides+1
  triangle(top,rings[1][i],rings[1][j],i)
  for k=1,#rings-1 do
   triangle(rings[k][i],rings[k+1][i],rings[k+1][j],i)
   triangle(rings[k][i],rings[k+1][j],rings[k][j],i+1)
  end
  triangle(rings[#rings][i],bottom,rings[#rings][j],i)
 end
 local random=Random.new(593+spec.sides*17)
 local white=core:AddColor(rgb(255,255,255),1)
 -- Larger opaque grains at multiple depths; never orbit, twinkle or reroll.
 local coreMin,coreMax=Vector3.one*math.huge,-Vector3.one*math.huge
 for i=1,30 do
  local y=random:NextNumber(-.30,.32)
  local radius=(.28-math.abs(y)*.38)*math.sqrt(random:NextNumber())
  local a=random:NextNumber(0,math.pi*2)
  local center=Vector3.new(math.cos(a)*radius+y*spec.lean,y,math.sin(a)*radius)
  local s=random:NextNumber(.008,.015)*(i%9==0 and 1.35 or 1)
  local v,p={},{}
  for _,d in ipairs({Vector3.xAxis,-Vector3.xAxis,Vector3.yAxis,-Vector3.yAxis,Vector3.zAxis,-Vector3.zAxis}) do
   p[#p+1]=center+d*s;v[#v+1]=core:AddVertex(p[#p])
   coreMin=coreMin:Min(p[#p]);coreMax=coreMax:Max(p[#p])
  end
  for _,face in ipairs({{1,3,5},{5,3,2},{2,3,6},{6,3,1},{1,5,4},{5,2,4},{2,6,4},{6,1,4}}) do
   local x,y1,z=table.unpack(face)
   if (p[y1]-p[x]):Cross(p[z]-p[x]):Dot((p[x]+p[y1]+p[z])/3-center)<0 then y1,z=z,y1 end
   local f=core:AddTriangle(v[x],v[y1],v[z]);core:SetFaceColors(f,{white,white,white})
  end
 end
 local function part(m,name)
  local p=assets:CreateMeshPartAsync(Content.fromObject(m),{CollisionFidelity=Enum.CollisionFidelity.Box})
  p.Name=name;p.Anchored=true;p.Color=Color3.new(1,1,1);p.Material=Enum.Material.Neon
  p.Reflectance=0;p.DoubleSided=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  return p
 end
 local shell=part(mesh,'Faceted'..key)
 local grains=part(core,'FixedInclusions')
 local lo,hi=positions[1],positions[1]
 for _,p in ipairs(positions) do lo=lo:Min(p);hi=hi:Max(p) end
 grains:SetAttribute('SizeRatio',(coreMax-coreMin)/(hi-lo))
 grains:SetAttribute('CenterRatio',((coreMin+coreMax)-(lo+hi))*.5/(hi-lo))
 grains.Parent=shell;shell:SetAttribute('GemAspect',spec.aspect);shell.Transparency=.28
 return shell
end
function Gem.prepare()
 if attempted then return end;attempted=true
 for _,key in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
  local first=#meshes
  local ok,result=pcall(build,key,definitions[key])
  if ok then templates[key]=result
  else
   for i=#meshes,first+1,-1 do meshes[i]:Destroy();meshes[i]=nil end
   if warn then warn('GemAppearance '..key..': '..tostring(result)) end
  end
 end
end
function Gem.clone(source)
 local template=templates[Gem.key(source:GetAttribute('Mineral'))]
 if not template or source.Name=='PressedCargo' then return source:Clone(),false end
 local p=template:Clone();p.Size=source.Size*template:GetAttribute('GemAspect');p.CFrame=source.CFrame
 for k,v in pairs(source:GetAttributes()) do p:SetAttribute(k,v) end
 Gem.update(p,1)
 return p,true
end
function Gem.update(part,opacity)
 local core=part:FindFirstChild('FixedInclusions')
 if core then
  core.Size=part.Size*core:GetAttribute('SizeRatio')
  core.CFrame=part.CFrame*CFrame.new(part.Size*core:GetAttribute('CenterRatio'))
  core.Transparency=1-opacity
 end
end
return Gem
