-- PLAN_JSON is supplied by refresh_platform_surfaces.py. Edit-only, no Play.
local plan = game.HttpService:JSONDecode([==[PLAN_JSON]==])
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335)
assert(not game:GetService('RunService'):IsRunning())
local map = workspace.MiningAway.Map
assert(not map:FindFirstChild('PlatformSurfaceFill'))
local function resolve(path, anchor)
 local found={game}
 for name in path:gmatch('[^.]+') do
  local nextFound={}
  for _,parent in found do for _,child in parent:GetChildren() do
   if child.Name==name then table.insert(nextFound,child) end
  end end
  found=nextFound
 end
 if anchor then
  local matches={}
  for _,p in found do if p:IsA('BasePart') and (p.Position-Vector3.new(unpack(anchor))).Magnitude<.002 then table.insert(matches,p) end end
  found=matches
 end
 assert(#found==1,path..': ambiguous/missing instance')
 return found[1]
end
local staged={}
for _,e in plan.edits do
 local p=resolve(e.path,e.anchor)
 assert(p.ClassName==e.class and (p.Size-Vector3.new(unpack(e.anchorSize))).Magnitude<.002)
 assert(p.Anchored)
 table.insert(staged,{p=p,e=e,cf=p.CFrame,size=p.Size})
end
local fill=Instance.new('Folder');fill.Name='PlatformSurfaceFill'
for _,e in plan.fills do
 local source=resolve(e.source,e.anchor)
 assert(#source:GetChildren()==0,'Surface has authored children: '..e.source)
 local p=source:Clone();p.Name=e.name
 p.Size=Vector3.new(unpack(e.size));p.CFrame=CFrame.new(unpack(e.position))
 p:SetAttribute('SourceSurface',e.source);p.Parent=fill
end
-- Capture actual support before editing. Limit rays to architecture, excluding
-- foliage, displays and actors; the same geometry remains collidable after.
local geometry={}
for _,p in workspace.MiningAway:GetDescendants() do
 if p:IsA('BasePart') and p.CanCollide and p.Size.X*p.Size.Z>60 then table.insert(geometry,p) end
end
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=geometry
local samples={}
for x=-200,260,8 do for z=-184,216,8 do
 local origin=Vector3.new(x,110,z)
 local hit=workspace:Raycast(origin,Vector3.new(0,-140,0),params)
 if hit then table.insert(samples,{origin=origin,y=hit.Position.Y,part=hit.Instance}) end
end task.wait() end
local fields={}
for _,m in workspace.MiningAway.Fields:GetChildren() do
 local f=m:FindFirstChild('Field');if f then fields[f]={cf=f.CFrame,size=f.Size} end
end
local displayCount=#map.JunkCubeAreas:GetDescendants()
local function verify()
 local all=table.clone(geometry)
 for _,p in fill:GetChildren() do table.insert(all,p) end
 params.FilterDescendantsInstances=all
 local changed,maxDelta=0,0
 for i,s in samples do
  local hit=workspace:Raycast(s.origin,Vector3.new(0,-140,0),params)
  assert(hit,'Missing support at '..tostring(s.origin))
  local delta=math.abs(hit.Position.Y-s.y)
  local bridge=hit.Instance.Name=='QuartzBridge' or hit.Instance.Name=='TestBridge' or hit.Instance.Name=='QuartzBridgeWornCenter' or hit.Instance.Name=='TestBridgeWornCenter'
  local hubOverlay=s.part.Parent.Name=='MarketSquare' or s.part.Name=='GardenSoil'
  assert(delta<(bridge and .21 or hubOverlay and .081 or .003),'Changed support '..s.part:GetFullName()..' at '..tostring(s.origin)..' delta '..delta)
  if delta>.003 then changed+=1;maxDelta=math.max(maxDelta,delta) end
  if i%300==0 then task.wait() end
 end
 for f,b in fields do assert(f.CFrame==b.cf and f.Size==b.size) end
 assert(#map.JunkCubeAreas:GetDescendants()==displayCount)
 for _,s in staged do
  local e,p=s.e,s.p
  if e.after.position then assert((p.Position-Vector3.new(unpack(e.after.position))).Magnitude<.002) end
  if e.after.size then assert((p.Size-Vector3.new(unpack(e.after.size))).Magnitude<.002) end
 end
 return {supportSamples=#samples,supportSamplesAdjusted=changed,maxSupportDelta=maxDelta,fields=6,displayDescendants=displayCount,partsChanged=#staged,newSurfacePieces=#fill:GetChildren()}
end
local serialize,encode=game:GetService('SerializationService'),game:GetService('EncodingService')
local data=serialize:SerializeInstancesAsync({fill})
local exported=buffer.tostring(encode:Base64Encode(encode:CompressBuffer(data,Enum.CompressionAlgorithm.Zstd)))
local function apply()
 assert(not game:GetService('RunService'):IsRunning())
 for _,s in staged do assert(s.p.CFrame==s.cf and s.p.Size==s.size,'Surface changed since stage') end
 for _,s in staged do
  if s.e.after.size then s.p.Size=Vector3.new(unpack(s.e.after.size)) end
  if s.e.after.position then s.p.CFrame=CFrame.new(unpack(s.e.after.position))*s.cf.Rotation end
 end
 fill.Parent=map
 local ok,result=pcall(verify)
 if not ok then
  fill.Parent=nil
  for _,s in staged do s.p.Size=s.size;s.p.CFrame=s.cf end
  error(result)
 end
 return result
end
shared.PlatformSurfaces={apply=apply,verify=verify,export=exported}
return {staged=#staged,fills=#fill:GetChildren(),exportBytes=#exported,supportSamples=#samples}
