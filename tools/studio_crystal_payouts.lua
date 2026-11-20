-- Prefix with the Workshop and Mining modules from tools/build.py.
-- Stage wording on the five existing field boards, with no new instances.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
assert(not shared.CrystalPayoutSigns)
local run=workspace.MiningAway.Map.CrystalRun
local textService=game:GetService('TextService')
local edits,entries={},{}
local minVerticalRoom=math.huge
local function numberText(number)
 local digits=tostring(number)
 if number<1000 then return digits end
 return digits:sub(1,-4)..','..digits:sub(-3)
end
for index,tier in ipairs(Workshop.CRYSTAL_TIERS) do
 local zone=run[tier.name]
 assert(zone.Field:GetAttribute('CrystalZone')==index)
 local min,max=10,10 -- Crystal Run sets Ore=10 in World.initialize.
 if tier.hardness>1 then
  min=Mining.deepCrystal(50,tier.hardness,min).ore
  max=Mining.deepCrystal(100,tier.hardness,max).ore
 end
 min*=tier.value;max*=tier.value
 local payout=numberText(min)..(min~=max and '–'..numberText(max) or '')
 local before=string.format('%02d   %s',index,tier.name:upper())
 local after='<font size="64">'..before..'</font>\n'..payout..' QUARTZ / ROCK'
 local faces={}
 for _,face in ipairs(zone.ZoneSign:GetChildren()) do
  if not face:IsA('SurfaceGui') then continue end
  assert(face.Enabled and face.CanvasSize==Vector2.new(560,112) and face.SizingMode==Enum.SurfaceGuiSizingMode.FixedSize)
  assert(not faces[face.Face]);faces[face.Face]=true
  local label=face.TextLabel
  assert(label:IsA('TextLabel') and label.Text==before and label.TextSize==64 and not label.RichText)
  assert(label.Size==UDim2.fromScale(1,1) and not label.TextScaled and not label.TextWrapped)
  local params=Instance.new('GetTextBoundsParams')
  params.Width=1000;params.Size=34;params.Font=label.FontFace;params.RichText=true;params.Text=after
  local bounds=textService:GetTextBoundsAsync(params);params:Destroy()
  assert(bounds.X<=face.CanvasSize.X*.87 and bounds.Y<=face.CanvasSize.Y-12,'Payout label exceeds its face')
  minVerticalRoom=math.min(minVerticalRoom,face.CanvasSize.Y-bounds.Y)
  local edit={path=label:GetFullName(),face=face.Face.Name,before=before,after=after,min=min,max=max}
  table.insert(edits,edit);table.insert(entries,{label=label,edit=edit})
 end
 assert(faces[Enum.NormalId.Front] and faces[Enum.NormalId.Back])
end
assert(#edits==10)
local function verify()
 assert(game.RunService:IsEdit())
 for _,entry in ipairs(entries) do
  local label,edit=entry.label,entry.edit
  assert(label:GetFullName()==edit.path and label.Parent.Face.Name==edit.face)
  assert(label.Text==edit.after and label.TextSize==34 and label.RichText and label.Parent.Enabled)
 end
 return {placeId=game.PlaceId,universeId=game.GameId,boards=5,faces=#entries,edits=edits,minVerticalRoom=minVerticalRoom}
end
local function apply()
 assert(game.RunService:IsEdit())
 for _,entry in ipairs(entries) do
  assert(entry.label.Text==entry.edit.before and entry.label.TextSize==64 and not entry.label.RichText)
 end
 local ok,receipt=pcall(function()
  for _,entry in ipairs(entries) do
   entry.label.Text=entry.edit.after;entry.label.TextSize=34;entry.label.RichText=true
  end
  return verify()
 end)
 if not ok then
  for _,entry in ipairs(entries) do
   entry.label.Text=entry.edit.before;entry.label.TextSize=64;entry.label.RichText=false
  end
  error(receipt)
 end
 return receipt
end
shared.CrystalPayoutSigns={apply=apply,verify=verify}
return game:GetService('HttpService'):JSONEncode(edits)
