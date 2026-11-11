-- Readable native lettering on the existing double-sided Crystal Run signs.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
assert(not shared.CrystalRunLettering)
local map=workspace.MiningAway.Map
local run=map.CrystalRun
local textService=game:GetService('TextService')
local plates=map.DepotStationPlates
local boards={
 {run.TrailSign,37,64}, {run.DepotWayfinder.Board,48,60}, {run.ChargingSign,40,60},
 {plates.PackStationPlate,56,64}, {plates.PrestigeStationPlate,56,64},
}
for _,name in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
 table.insert(boards,{run[name].ZoneSign,37,64})
end
local entries,edits={},{}
local function bounds(label,size)
 return textService:GetTextSize(label.Text,size,label.Font,Vector2.new(2000,1000))
end
for _,spec in ipairs(boards) do
 local board,before,after=table.unpack(spec)
 local faces={}
 for _,gui in ipairs(board:GetChildren()) do
  if not gui:IsA('SurfaceGui') then continue end
  local label=gui:FindFirstChild('TextLabel')
  assert(label and label:IsA('TextLabel') and label.TextSize==before and not label.TextScaled and not label.TextWrapped)
  assert(gui.Enabled and gui.SizingMode==Enum.SurfaceGuiSizingMode.FixedSize)
  assert(gui.Face==Enum.NormalId.Front or gui.Face==Enum.NormalId.Back)
  assert(not faces[gui.Face]);faces[gui.Face]=true
  local area=gui.CanvasSize*Vector2.new(label.Size.X.Scale,label.Size.Y.Scale)+Vector2.new(label.Size.X.Offset,label.Size.Y.Offset)
  local measured=bounds(label,after)
  assert(measured.X<=area.X*.87 and measured.Y<=area.Y*.62,'Lettering exceeds its face')
  local record={path=label:GetFullName(),face=gui.Face.Name,text=label.Text,before=before,after=after}
  table.insert(edits,record)
  table.insert(entries,{label=label,record=record,fill=measured.X/area.X})
 end
 assert(faces[Enum.NormalId.Front] and faces[Enum.NormalId.Back])
end
assert(#edits==20)

local function verify()
 assert(game.RunService:IsEdit())
 local maxFill=0
 for _,entry in ipairs(entries) do
  local label,record=entry.label,entry.record
  assert(label:GetFullName()==record.path and label.Parent.Face.Name==record.face)
  assert(label.TextSize==record.after and label.Text==record.text and label.Parent.Enabled)
  maxFill=math.max(maxFill,entry.fill)
 end
 return {placeId=game.PlaceId,universeId=game.GameId,boards=#boards,faces=#entries,maxFill=maxFill}
end
local function apply()
 assert(game.RunService:IsEdit())
 for _,entry in ipairs(entries) do assert(entry.label.TextSize==entry.record.before) end
 for _,entry in ipairs(entries) do entry.label.TextSize=entry.record.after end
 local ok,receipt=pcall(verify)
 if not ok then
  for _,entry in ipairs(entries) do entry.label.TextSize=entry.record.before end
  error(receipt)
 end
 return receipt
end
shared.CrystalRunLettering={edits=edits,apply=apply,verify=verify}
return game:GetService('HttpService'):JSONEncode(edits)
