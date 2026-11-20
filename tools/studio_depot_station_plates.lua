-- Stage the signs off-map and preserve both original station assemblies.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local map=workspace.MiningAway.Map
local depot=map.SimpleFlatTestMap
local reference=map.CrystalRun.DepotWayfinder.Board
assert(not map:FindFirstChild('DepotStationPlates') and not shared.DepotStationPlates)

local signs=Instance.new('Folder')
signs.Name='DepotStationPlates'
local oldLabels={}
local edits={}
local textService=game:GetService('TextService')
local back
for _,face in ipairs(reference:GetChildren()) do
 if face:IsA('SurfaceGui') and face.Face==Enum.NormalId.Back then back=face end
end
local returnLabel=assert(back).TextLabel
local outboundText='CRYSTAL RUN  ↑'
local returnText='←  PACK COUNTER'
assert(returnLabel.Text==outboundText)
assert(textService:GetTextSize(returnText,returnLabel.TextSize,returnLabel.Font,back.CanvasSize).X<back.CanvasSize.X-36)
table.insert(edits,{path=returnLabel:GetFullName(),face='Back',property='Text',before=outboundText,after=returnText})
for _,spec in ipairs({
 {station='PackStation',text='PACK COUNTER',width=9.2},
 {station='PrestigeStation',text='PRESTIGE',width=8.6},
}) do
 local station=depot[spec.station..'Assembly'][spec.station]
 local old=station.TestLabel
 assert(old:IsA('BillboardGui') and old.Enabled)
 table.insert(oldLabels,old)
 table.insert(edits,{path=old:GetFullName(),property='Enabled',before=true,after=false})
 local board=reference:Clone()
 board.Name=spec.station..'Plate'
 board.Size=Vector3.new(spec.width,1.76,.24)
 board.Position=station.Position+Vector3.yAxis*(station.Size.Y*.5+board.Size.Y*.5)
 for _,face in ipairs(board:GetChildren()) do
  assert(face:IsA('SurfaceGui') and (face.Face==Enum.NormalId.Front or face.Face==Enum.NormalId.Back))
  face.Name=face.Face.Name
  local label=face.TextLabel
  label.Text=spec.text
  label.TextSize=56
  local width=textService:GetTextSize(label.Text,label.TextSize,label.Font,face.CanvasSize).X
  assert(width<face.CanvasSize.X-36,'Nameplate needs side margins')
 end
 board.Parent=signs
end

local function verify()
 assert(signs.Parent==map and #signs:GetChildren()==2)
 local params=RaycastParams.new()
 params.RespectCanCollide=true
 local fromSpawn=Vector3.new(0,9,12)
 local fromFields=Vector3.new(0,9,54)
 for _,board in ipairs(signs:GetChildren()) do
  assert(board.Anchored and not board.CanCollide and not board.CanQuery and not board.CanTouch)
  assert(board.Front.Face==Enum.NormalId.Front and board.Back.Face==Enum.NormalId.Back)
  for _,origin in ipairs({fromSpawn,fromFields}) do
   assert(not workspace:Raycast(origin,board.Position-origin,params),'Blocked view of '..board.Name)
  end
 end
 for _,label in ipairs(oldLabels) do assert(not label.Enabled) end
 assert(returnLabel.Text==returnText)
 for _,face in ipairs(reference:GetChildren()) do
  if face:IsA('SurfaceGui') and face.Face==Enum.NormalId.Front then assert(face.TextLabel.Text==outboundText) end
 end
 return {path=signs:GetFullName(),plates=2,clearFromBothApproaches=true}
end

local function apply()
 assert(game.RunService:IsEdit() and not map:FindFirstChild(signs.Name))
 for _,label in ipairs(oldLabels) do assert(label.Enabled) end
 assert(returnLabel.Text==outboundText)
 signs.Parent=map
 for _,label in ipairs(oldLabels) do label.Enabled=false end
 returnLabel.Text=returnText
 local ok,receipt=pcall(verify)
 if not ok then
  signs.Parent=nil
  for _,label in ipairs(oldLabels) do label.Enabled=true end
  returnLabel.Text=outboundText
  error(receipt)
 end
 return receipt
end

local serializer=game:GetService('SerializationService')
local encoding=game:GetService('EncodingService')
local binary=serializer:SerializeInstancesAsync({signs})
local export=encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd))
shared.DepotStationPlates={scenery=buffer.tostring(export),edits=edits,apply=apply,verify=verify}
return {bytes=buffer.len(export),plates=2}
