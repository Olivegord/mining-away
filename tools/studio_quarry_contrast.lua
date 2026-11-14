-- Retain subdued surfaces as the default; use strong photo texture at a few
-- recognizable landmarks and on quartz/cobalt ore. Do not change any geometry.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335,'Wrong shared place')
assert(not game:GetService('RunService'):IsRunning(),'Stop Play first')
local root=workspace.MiningAway
assert(root.Map:FindFirstChild('QuarryDepthPass'),'Expected the depth pass')
local mat=game:GetService('MaterialService')
local rgb=Color3.fromRGB
local variants={}
local function define(name,from,asset,scale,pattern)
 assert(not mat:FindFirstChild(name),'Reconcile existing contrast pass: '..name)
 local m=mat[from]:Clone();m.Name=name;m.ColorMap='rbxassetid://'..asset
 m.StudsPerTile=scale;m.MaterialPattern=pattern
 table.insert(variants,m);return m
end
local organic,regular=Enum.MaterialPattern.Organic,Enum.MaterialPattern.Regular
local veins=define('QuarryOre_Veined','QuarryOre_Polished','101826947844494',4.8,regular)
local turf=define('QuarryAccent_LushGrass','QuarryPhoto_Grass','136005318797247',17,organic)
local gravel=define('QuarryAccent_RoughBed','QuarryPhoto_Pebble','83637161982243',21,organic)
define('QuarryDrone_Painted','QuarryPhoto_Slate','140053828439773',.92,regular)
define('QuarryDrone_Ribbed','QuarryAccent_Ribbed','130262067528876',.64,regular)
local function bytes(c) return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)} end
local edits,handles={},{}
local function stage(p,finish,tint)
 assert(p.ClassName=='Part' and p.Material==finish.BaseMaterial,p:GetFullName())
 local pos=p.Position
 table.insert(edits,{path=p:GetFullName(),class=p.ClassName,anchor={pos.X,pos.Y,pos.Z},
  before={color=bytes(p.Color),variant=p.MaterialVariant},after={color=bytes(tint),variant=finish.Name}})
 table.insert(handles,p)
end
local zones={
 -- Contiguous texture patches: Quartz foreground and west rim, a green
 -- pocket outside Ruby, and the two high shore/lookout approaches.
 {x=-100,z=117,rx=18,rz=24},{x=-85,z=64,rx=14,rz=10},
 {x=-92,z=43,rx=15,rz=11},{x=94,z=-144,rx=13,rz=13},
 {x=-99,z=-142,rx=13,rz=11},{x=107,z=122,rx=12,rz=14},
}
for _,p in ipairs(root.Map.DronerevolutionTerraces:GetDescendants()) do
 if p.ClassName=='Part' and p.Name=='Turf' and p.MaterialVariant=='QuarryPhoto_Grass' then
  for _,z in ipairs(zones) do
   local dx,dz=(p.Position.X-z.x)/z.rx,(p.Position.Z-z.z)/z.rz
   if dx*dx+dz*dz<1 then
    stage(p,turf,p.Color:Lerp(rgb(211,221,194),.27))
    break
   end
  end
 end
end
local floor=root.Fields.Quartz.Field
assert(floor.MaterialVariant=='QuarryPhoto_Pebble','Reconcile Quartz floor first')
stage(floor,gravel,rgb(222,211,190))
assert(#edits>=12 and #edits<=85,'Unexpected size of texture accent pass')
local enc=game:GetService('EncodingService')
local function encode(b)
 return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(b,Enum.CompressionAlgorithm.Zstd)))
end
local serialized=game:GetService('SerializationService'):SerializeInstancesAsync(variants)
local json=game:GetService('HttpService'):JSONEncode({edits=edits,moves={}})
-- JSON encodes an empty Luau table as an array in this context.
local snapshot={variants=encode(serialized),edits=encode(buffer.fromstring(json))}
for _,m in ipairs(variants) do m.Parent=mat end
for i,p in ipairs(handles) do
 p.MaterialVariant=edits[i].after.variant;p.Color=rgb(table.unpack(edits[i].after.color))
end
shared.QuarryContrastSnapshot=snapshot
return {parts=#edits,ore=veins.Name,variants=#variants,exportBytes={variants=#snapshot.variants,edits=#snapshot.edits}}
