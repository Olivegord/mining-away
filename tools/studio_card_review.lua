-- Native presentation harness. Prepend build.module_bundle for
-- Shops, DroneRoles, Cards, UILayout, Interface and CardView, then execute on
-- the Studio Client. Uses real catalog/renderer; never buys or grants a card.
assert(game:GetService('RunService'):IsStudio(),'Studio only')
local player=game:GetService('Players').LocalPlayer
assert(player,'Run this in the Client DataModel')
if _G.MiningPackReview then _G.MiningPackReview.destroy() end
local gameHud=player.PlayerGui:FindFirstChild('MiningAwayHUD');local hudEnabled=gameHud and gameHud.Enabled
if gameHud then gameHud.Enabled=false end
local U=Interface
local gui=Instance.new('ScreenGui');gui.Name='PackVisualReview';gui.DisplayOrder=40;gui.ResetOnSpawn=false
gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player.PlayerGui
local root=U.frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1));root.BackgroundTransparency=1
local header=U.frame(root,UDim2.fromOffset(0,0),UDim2.fromOffset(600,88),Color3.fromRGB(29,104,210))
CardView.housing(U,header,Color3.fromRGB(29,104,210),Color3.fromRGB(120,230,255))
local title=U.text(header,UDim2.fromOffset(20,8),UDim2.new(1,-40,0,38),'Pick a card',30,U.palette.white,true)
title.TextStrokeColor3=Color3.fromRGB(13,23,48);title.TextStrokeTransparency=.4
local subtitle=U.text(header,UDim2.fromOffset(20,48),UDim2.new(1,-40,0,26),'Choose one · This run',18,Color3.fromRGB(215,240,255))
local body=Instance.new('ScrollingFrame');body.Name='ReviewCards';body.BackgroundTransparency=1;body.BorderSizePixel=0
body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.CanvasSize=UDim2.new();body.ScrollBarThickness=4;body.Parent=root
local owned={};local currentIds=nil
local function clear() for _,card in ipairs(owned) do card.root:Destroy() end;table.clear(owned);for _,c in ipairs(body:GetChildren()) do c:Destroy() end;body.CanvasPosition=Vector2.zero end
local function selected(ids)
 local found={}
 for _,id in ipairs(ids) do for _,choice in ipairs(Cards.CATALOG) do if choice.cardId==id then table.insert(found,choice);break end end end
 return found
end
local function draw(choices,width,height,quiet)
 clear()
 local layout=Instance.new('UIListLayout');layout.FillDirection=width>=800 and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
 layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.Padding=UDim.new(0,14);layout.Parent=body
 local columns=width>=800 and 3 or 1
 local panelWidth=math.min(820,width-24)
 local cardWidth=columns==3 and (panelWidth-52)/3 or math.min(460,width-62)
 header.Size=UDim2.fromOffset(panelWidth,height<500 and 64 or 88);header.Position=UDim2.fromOffset((width-header.Size.X.Offset)/2,math.max(12,(height-444)*.65))
 title.TextSize=height<500 and 23 or 30;title.Size=UDim2.new(1,-40,0,height<500 and 28 or 38)
 subtitle.Position=UDim2.fromOffset(20,height<500 and 36 or 48);subtitle.TextSize=height<500 and 16 or 18;subtitle.Size=UDim2.new(1,-40,0,height<500 and 22 or 26)
 local headerSpace=height<500 and 76 or 100
 body.Position=header.Position+UDim2.fromOffset(0,headerSpace);body.Size=UDim2.fromOffset(header.Size.X.Offset,math.max(100,height-header.Position.Y.Offset-headerSpace-12))
 for i,choice in ipairs(choices) do
  local cardHeight=height<500 and math.clamp(body.Size.Y.Offset-2,212,256) or 320
  local card=CardView.create(U,body,choice,i,cardWidth,cardHeight,{reducedMotion=quiet,onChoose=function() end});table.insert(owned,card)
 end
end
local function show(ids,quiet)
 currentIds=ids or currentIds
 draw(selected(currentIds),root.AbsoluteSize.X,root.AbsoluteSize.Y,quiet)
end
local connection=root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() if currentIds then show(currentIds) end end)
local function checkAll(width,height)
 local failures={};local textCount=0
 local oldSize=body.Size
 for start=1,#Cards.CATALOG,3 do
  local choices={};for i=start,math.min(start+2,#Cards.CATALOG) do table.insert(choices,Cards.CATALOG[i]) end
  draw(choices,width or 1280,height or 720,true)
  game:GetService('RunService').RenderStepped:Wait();game:GetService('RunService').RenderStepped:Wait()
  for _,card in ipairs(owned) do
   for _,label in ipairs(card.root:GetDescendants()) do if label:IsA('TextLabel') then
    textCount+=1
    if not label.TextFits then table.insert(failures,{text=label.Text,size=tostring(label.AbsoluteSize),bounds=tostring(label.TextBounds),kind=label.Name}) end
   end end
  end
 end
 show(currentIds)
 return {catalog=#Cards.CATALOG,texts=textCount,failures=failures,scope='Native production CardView rendering and font metrics; sample choices, no purchase or gameplay test'}
end
_G.MiningPackReview={show=show,checkAll=checkAll,destroy=function() connection:Disconnect();clear();gui:Destroy();if gameHud then gameHud.Enabled=hudEnabled end;_G.MiningPackReview=nil end}
task.wait()
local picks={}
for _,key in ipairs({'orbitalLaser','scrapSwarm','fork'}) do for _,choice in ipairs(Cards.CATALOG) do if (choice.effects[key] or 0)>0 then table.insert(picks,choice.cardId);break end end end
show(picks)
return {ids=picks,viewport=tostring(root.AbsoluteSize),scope='Native UI harness; no server state changed'}
