-- Native production-controller state check. Prepend Shops/DroneRoles/Cards.
-- Only local presentation attributes are changed and restored. Never buys,
-- grants, spends, sends a command, or mutates server/persistent state.
assert(game:GetService('RunService'):IsStudio(),'Studio only')
local player=game.Players.LocalPlayer;local http=game:GetService('HttpService');local run=game:GetService('RunService')
local original=player:GetAttribute('MA_Profile');local oldNotice=player:GetAttribute('MA_Notice')
local p=http:JSONDecode(original);assert(not p.run.pendingOffer,'Use an isolated preview without a real pending offer')
local picks={}
for _,id in ipairs({'G01','G02','D10'}) do for _,c in ipairs(Cards.CATALOG) do if c.cardId==id then table.insert(picks,c);break end end end
p.run.pendingOffer={id='native-ui-review:'..http:GenerateGUID(false),choices=picks}
local events={disabledFaces=0,destroyedCards=0,resizedCanvases=0}
local connections={}
local ok,result=xpcall(function()
 player:SetAttribute('MA_Profile',http:JSONEncode(p));task.wait(1)
 local sheet=player.PlayerGui.MiningAwayHUD:FindFirstChild('MenuSheet',true);local body=sheet.MenuContent
 local cards={};local texts={}
 for i=1,3 do cards[i]=assert(body:FindFirstChild('CardChoice'..i));texts[i]=cards[i].CardEffect.Text
  table.insert(connections,cards[i].Destroying:Connect(function() events.destroyedCards+=1 end))
 end
 for _,s in ipairs(player.PlayerGui:GetChildren()) do if s.Name=='UpgradeCardFace' then
  table.insert(connections,s:GetPropertyChangedSignal('Enabled'):Connect(function() if not s.Enabled then events.disabledFaces+=1 end end))
  table.insert(connections,s:GetPropertyChangedSignal('CanvasSize'):Connect(function() events.resizedCanvases+=1 end))
 end end
 for i=1,10 do
  p.cargoUnits=i;p.pendingTransaction=i%2==0
  player:SetAttribute('MA_Profile',http:JSONEncode(p));run.RenderStepped:Wait();run.RenderStepped:Wait()
  for j=1,3 do assert(body:FindFirstChild('CardChoice'..j)==cards[j],'Card renderer replaced during an unrelated profile update');assert(cards[j].CardEffect.Text==texts[j],'Saving replaced the card benefit') end
 end
 player:SetAttribute('MA_Notice','Native UI review');run.RenderStepped:Wait();run.RenderStepped:Wait()
 for j=1,3 do assert(body:FindFirstChild('CardChoice'..j)==cards[j],'Notice recreated an offer') end
 return {cardsReused=3,profileUpdates=10,noticeKeptCards=true,events=events,scope='Native production client; local presentation fixture, no gameplay commands or saved state changes'}
end,debug.traceback)
for _,c in ipairs(connections) do c:Disconnect() end
player:SetAttribute('MA_Notice',oldNotice);player:SetAttribute('MA_Profile',original)
if not ok then error(result) end
return result
