-- Flat map with a ring of eight plots (owner, November 23):
-- "shops in the middle, then the expanse; there should be no elevation really anywhere",
-- plus 8 player plots around the hub that later expand outward.
--
-- Stages, in shared Edit of DRONEREVOLUTION:
--   * moves Map.QuarryWorld.Terraces (stepped basin rim), Map.QuarryWorld.Mesas and the old
--     MiningAway.DigPit (hole at 140,20) into ServerStorage.FlatMapArchive. Nothing is deleted.
--   * adds Map.PlotPit: the same ground plates, shaft walls and floor, cloned from the
--     old pit and refitted around the hole at 160,0 (DigCube.CENTER moves there in code).
--   * adds Map.PlotRing: eight 88x88 plot outlines on the ground, facing the hub, centers on a
--     160-stud ring. Plot 1 frames the Dig Cube hole exactly. Outlines have no collision and
--     no query, so nothing changes underfoot or for raycasts.
-- shared.FlatPlots = {snapshot, apply, undo}; export snapshot sections and mirror them with
-- tools/refresh_flat_plots.py.

assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong game")
assert(not game:GetService("RunService"):IsRunning(), "Run this in Edit, not Play")

local storage = game:GetService("ServerStorage")
local root = workspace.MiningAway
local map = root.Map
local quarry = map.QuarryWorld
assert(not map:FindFirstChild("PlotRing"), "PlotRing already exists")
assert(not map:FindFirstChild("PlotPit"), "PlotPit already exists")
assert(not storage:FindFirstChild("FlatMapArchive"), "FlatMapArchive already exists")

local GROUND = 3.8 -- top of Fields.Baseplate and the pit ground plates (DigCube.GROUND)
local RADIUS = 160
local SIZE = 88 -- DigCube.WIDTH: plot 1 frames the hole exactly
local LINE = 1.5
local THICK = .2
local COLOR = Color3.fromRGB(232, 214, 160)
local HOLE = Vector3.new(RADIUS, 0, 0) -- new DigCube.CENTER x/z
local EDGE = 1024 -- the ground plates run to +-1024 like Fields.Baseplate

-- Plot ring -------------------------------------------------------------------------------
local ring = Instance.new("Folder")
ring.Name = "PlotRing"
ring:SetAttribute("PlotCount", 8)
ring:SetAttribute("PlotSize", SIZE)
ring:SetAttribute("Radius", RADIUS)

local function strip(parent, name, cf, size)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = COLOR
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Size = size
    p.CFrame = cf
    p.Parent = parent
end

for k = 1, 8 do
    local a = (k - 1) * math.pi / 4
    local center = Vector3.new(math.cos(a) * RADIUS, GROUND + THICK / 2, math.sin(a) * RADIUS)
    -- Local -Z faces the hub, +Z points outward: the direction a plot grows.
    local look = CFrame.lookAt(center, Vector3.new(0, center.Y, 0))
    local plot = Instance.new("Folder")
    plot.Name = "Plot" .. k
    plot:SetAttribute("PlotIndex", k)
    plot:SetAttribute("Center", Vector3.new(center.X, GROUND, center.Z))
    plot:SetAttribute("AngleDegrees", math.deg(a))
    local h = SIZE / 2 + LINE / 2
    strip(plot, "EdgeInner", look * CFrame.new(0, 0, -h), Vector3.new(SIZE + LINE * 2, THICK, LINE))
    strip(plot, "EdgeOuter", look * CFrame.new(0, 0, h), Vector3.new(SIZE + LINE * 2, THICK, LINE))
    strip(plot, "EdgeLeft", look * CFrame.new(-h, 0, 0), Vector3.new(LINE, THICK, SIZE))
    strip(plot, "EdgeRight", look * CFrame.new(h, 0, 0), Vector3.new(LINE, THICK, SIZE))
    plot.Parent = ring
end

-- Pit refitted around the new hole -----------------------------------------------------------
-- The canonical file keeps the old pit under Map; shared Edit has it directly under MiningAway.
local old = root:FindFirstChild("DigPit") or map:FindFirstChild("DigPit")
assert(old, "Missing DigPit")
local x0, x1, z0, z1 = HOLE.X - SIZE / 2, HOLE.X + SIZE / 2, HOLE.Z - SIZE / 2, HOLE.Z + SIZE / 2
local base = root.Fields.Baseplate
local baseEast = base.Position.X + base.Size.X / 2
assert(math.abs(baseEast - 96) < .01, "Fields.Baseplate no longer ends at x=96: " .. baseEast)
local pit = Instance.new("Folder")
pit.Name = "PlotPit"
local function fit(name, from, x, z, sx, sz, y, sy)
    local src = old:FindFirstChild(from)
    assert(src and src:IsA("BasePart"), "Missing DigPit." .. from)
    local p = src:Clone()
    p.Name = name
    p.Size = Vector3.new(sx, sy or src.Size.Y, sz)
    p.CFrame = CFrame.new(x, y or src.Position.Y, z)
    p.Parent = pit
end
local depthY = old.GroundEast.Position.Y
fit("GroundWest", "GroundEast", (baseEast + x0) / 2, 0, x0 - baseEast, EDGE * 2, depthY)
fit("GroundEast", "GroundEast", (x1 + EDGE) / 2, 0, EDGE - x1, EDGE * 2, depthY)
fit("GroundNorth", "GroundNorth", HOLE.X, (z1 + EDGE) / 2, SIZE, EDGE - z1, depthY)
fit("GroundSouth", "GroundSouth", HOLE.X, (z0 - EDGE) / 2, SIZE, EDGE + z0, depthY)
local wallY, floorY = old.ShaftNorth.Position.Y, old.ShaftFloor.Position.Y
fit("ShaftNorth", "ShaftNorth", HOLE.X, z1 + 1, SIZE + 4, 2, wallY)
fit("ShaftSouth", "ShaftSouth", HOLE.X, z0 - 1, SIZE + 4, 2, wallY)
fit("ShaftWest", "ShaftWest", x0 - 1, HOLE.Z, 2, SIZE, wallY)
fit("ShaftEast", "ShaftEast", x1 + 1, HOLE.Z, 2, SIZE, wallY)
fit("ShaftFloor", "ShaftFloor", HOLE.X, HOLE.Z, SIZE + 4, SIZE + 4, floorY)

-- Archive -----------------------------------------------------------------------------------
local archive = Instance.new("Folder")
archive.Name = "FlatMapArchive"
archive:SetAttribute("Reason", "Flat map with plot ring, November 23: archived, not deleted")

local moveHandles, moves = {}, {}
local function plan(inst, path)
    table.insert(moveHandles, {inst, inst.Parent})
    table.insert(moves, {path = path, class = inst.ClassName, descendants = #inst:GetDescendants(),
        to = "ServerStorage.FlatMapArchive"})
end
plan(quarry.Terraces, "Workspace.MiningAway.Map.QuarryWorld.Terraces")
plan(quarry.Mesas, "Workspace.MiningAway.Map.QuarryWorld.Mesas")
plan(old, "Workspace.MiningAway.DigPit")  -- either location; the saver resolves it

local serialize = game:GetService("SerializationService")
local enc = game:GetService("EncodingService")
local http = game:GetService("HttpService")
local function encode(b) return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(b, Enum.CompressionAlgorithm.Zstd))) end
local snapshot = {
    plots = encode(serialize:SerializeInstancesAsync({ring})),
    pit = encode(serialize:SerializeInstancesAsync({pit})),
    archive = encode(serialize:SerializeInstancesAsync({archive})),
    moves = encode(buffer.fromstring(http:JSONEncode(moves))),
}

local function apply()
    assert(not ring.Parent, "Already installed")
    for _, h in ipairs(moveHandles) do assert(h[1].Parent == h[2], "Concurrent map change: " .. h[1]:GetFullName()) end
    local history = game:GetService("ChangeHistoryService")
    local recording = history:TryBeginRecording("Flat map with plot ring")
    archive.Parent = storage
    for _, h in ipairs(moveHandles) do h[1].Parent = archive end
    pit.Parent = map
    ring.Parent = map
    if recording then history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
    -- The ground must be solid everywhere except the hole.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {root.Fields, pit}
    local misses, holeHits = 0, 0
    for x = -400, 400, 8 do
        for z = -400, 400, 8 do
            local hit = workspace:Raycast(Vector3.new(x + .5, 50, z + .5), Vector3.new(0, -60, 0), params)
            local inHole = x + .5 > x0 and x + .5 < x1 and z + .5 > z0 and z + .5 < z1
            if inHole then
                if hit and hit.Position.Y > 0 then holeHits += 1 end
            elseif not hit or math.abs(hit.Position.Y - GROUND) > .01 then
                misses += 1
            end
        end
    end
    return {plots = #ring:GetChildren(), pitParts = #pit:GetChildren(), archived = #archive:GetChildren(),
        groundMisses = misses, holeBlocked = holeHits}
end
local function undo()
    ring.Parent, pit.Parent = nil, nil
    for _, h in ipairs(moveHandles) do h[1].Parent = h[2] end
    archive.Parent = nil
end
shared.FlatPlots = {snapshot = snapshot, apply = apply, undo = undo}
return {moves = moves, bytes = {plots = #snapshot.plots, pit = #snapshot.pit, archive = #snapshot.archive}}
