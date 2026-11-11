-- Stage a native copy of the existing Crystal Run sign at the first turn.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local map=workspace.MiningAway.Map
local run=map.CrystalRun
assert(not run:FindFirstChild('DepotWayfinder') and not shared.CrystalWayfinder)
local reference=run.TrailSign
assert(reference:IsA('Part') and reference.Sign.TextLabel.Text:find('CRYSTAL RUN',1,true))
local filters=RaycastParams.new()
filters.RespectCanCollide=true
local origin=Vector3.new(13,4,51)
local wayfinder=Instance.new('Folder')
wayfinder.Name='DepotWayfinder'
local board=reference:Clone()
board.Name='Board'
board.Size=Vector3.new(10.6,1.85,.24)
board.Position=origin+Vector3.yAxis*2.15
board.Parent=wayfinder
for _,face in ipairs(board:GetChildren()) do
 face.TextLabel.TextSize=48
end
local function deckAt(position)
 local hit=workspace:Raycast(position+Vector3.yAxis*9,-Vector3.yAxis*12,filters)
 assert(hit and hit.Instance.Name=='ServiceDeck' and math.abs(hit.Position.Y-origin.Y)<.01,'Wayfinder needs the service deck')
end
for _,side in ipairs({-1,1}) do
 local at=origin+Vector3.new(side*4.35,0,.18)
 deckAt(at)
 local post=Instance.new('Part')
 post.Name=side<0 and 'WestPost' or 'EastPost'
 post.Size=Vector3.new(.34,1.75,.36)
 post.Position=at+Vector3.yAxis*.86
 post.Color=reference.Color
 post.Material=Enum.Material.Metal
 post.TopSurface=Enum.SurfaceType.Smooth
 post.BottomSurface=Enum.SurfaceType.Smooth
 post.Anchored=true
 post.CanCollide=false;post.CanQuery=false;post.CanTouch=false
 post.Parent=wayfinder
end
local function verify()
 assert(game.RunService:IsEdit() and wayfinder.Parent==run)
 local from=Vector3.new(0,11,12)
 assert(not workspace:Raycast(from,board.Position-from,filters),'Wayfinder obscured from spawn')
 assert(board.Position.X-board.Size.X*.5>7,'Sign crossed the center walking lane')
 for _,part in ipairs(wayfinder:GetChildren()) do
  assert(part:IsA('Part') and part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch)
  deckAt(Vector3.new(part.Position.X,origin.Y,part.Position.Z))
 end
 return {path=wayfinder:GetFullName(),parts=#wayfinder:GetChildren(),visibleFromSpawn=true}
end
local function apply()
 assert(game.RunService:IsEdit() and run.Parent==map and not run:FindFirstChild(wayfinder.Name))
 wayfinder.Parent=run
 local ok,receipt=pcall(verify)
 if not ok then wayfinder.Parent=nil;error(receipt) end
 return receipt
end
local serializer=game:GetService('SerializationService')
local encoding=game:GetService('EncodingService')
local binary=serializer:SerializeInstancesAsync({wayfinder})
local export=encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd))
shared.CrystalWayfinder={scenery=buffer.tostring(export),apply=apply,verify=verify}
return {bytes=buffer.len(export),position=tostring(board.Position)}
