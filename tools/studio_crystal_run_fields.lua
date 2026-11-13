-- Stage only the obsolete Crystal Run patch markers and signs for background save.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335)
assert(not game:GetService("RunService"):IsRunning())
local storage = game:GetService("ServerStorage")
local run = workspace.MiningAway.Map.CrystalRun
local zones = {"Quartz", "Ruby", "Cobalt", "Violet", "Emerald"}
local archive = Instance.new("Folder")
archive.Name = "CrystalRunFieldArchive"
assert(not storage:FindFirstChild(archive.Name))
local moves, beds = {}, {}
local function add(parent, name, class)
 local item = assert(parent:FindFirstChild(name), name)
 assert(item.ClassName == class)
 table.insert(moves, {item = item, parent = parent, descendants = #item:GetDescendants()})
 return item
end
for _, name in zones do
 local zone = assert(run:FindFirstChild(name))
 local bed = assert(zone:FindFirstChild("Field"))
 assert(bed.Size.X == 108 and bed.Size.Z == 64 and bed.CanCollide and bed.CanQuery)
 table.insert(beds, bed)
 for i = 1, 3 do
  local patch = add(zone, "Patch"..i, "Part")
  assert(patch:GetAttribute("CrystalCluster") and not patch.CanCollide and not patch.CanQuery)
 end
 add(zone, "ZoneSign", "Part")
end
for _, name in {"ZoneSignPosts", "DepotWayfinder"} do add(run, name, "Folder") end
for _, name in {"ChargingSign", "TrailSign"} do add(run, name, "Part") end
local encoding = game:GetService("EncodingService")
local model = game:GetService("SerializationService"):SerializeInstancesAsync({archive})
local snapshot = buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(model, Enum.CompressionAlgorithm.Zstd)))
local http = game:GetService("HttpService")
local manifest = {}
for _, move in moves do manifest[move.item:GetFullName()] = move.descendants end
local function apply()
 assert(not game:GetService("RunService"):IsRunning() and not archive.Parent and not storage:FindFirstChild(archive.Name))
 for _, move in moves do assert(move.item.Parent == move.parent and #move.item:GetDescendants() == move.descendants) end
 archive.Parent = storage
 for _, move in moves do move.item.Parent = archive end
 local samples = 0
 local ok, err = pcall(function()
  assert(run:FindFirstChild("ChargingStation") and run:FindFirstChild("ChargeIndicator") and run:FindFirstChild("TrailGrove"))
  local ray = RaycastParams.new()
  ray.RespectCanCollide = true
  for _, bed in beds do
   for _, x in {-48,-24,0,24,48} do for _, z in {-25,0,25} do
    local point = bed.CFrame:PointToWorldSpace(Vector3.new(x,bed.Size.Y*.5,z))
    local hit = workspace:Raycast(point+Vector3.yAxis*2,-Vector3.yAxis*3,ray)
    assert(hit and hit.Instance == bed and math.abs(hit.Position.Y-point.Y)<.005, "Obstructed field "..bed.Parent.Name)
    samples += 1
   end end
  end
 end)
 if not ok then
  for _, move in moves do move.item.Parent = move.parent end
  archive.Parent = nil
  error(err)
 end
 return http:JSONEncode({place=game.PlaceId,universe=game.GameId,archived=#moves,groundSamples=samples})
end
shared.CrystalRunFieldStage = {apply=apply, snapshot=snapshot, manifest=manifest}
return http:JSONEncode({snapshot=snapshot,manifest=manifest})
