-- Native shared-skin review. Prepend Shops, DroneRoles, Cards, UILayout,
-- Interface and ShopView. This gallery never sends gameplay commands.
assert(game:GetService('RunService'):IsStudio(),'Studio only')
if _G.MiningUIReview then _G.MiningUIReview.destroy() end
local player=game.Players.LocalPlayer;local U=Interface
local actual=game:GetService('HttpService'):JSONDecode(player:GetAttribute('MA_Profile'))
local sample=game:GetService('HttpService'):JSONDecode(game:GetService('HttpService'):JSONEncode(actual))
sample.run.wallet.Quartz=1840 -- Render fixture, never applied to the player/server.
local hud=player.PlayerGui:FindFirstChild('MiningAwayHUD');local wasEnabled=hud and hud.Enabled;if hud then hud.Enabled=false end
local gui=Instance.new('ScreenGui');gui.Name='UnifiedUIReview';gui.DisplayOrder=45;gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player.PlayerGui
local root=U.frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1));root.Name='GalleryRoot';root.BackgroundTransparency=1
local coin=U.panel(root,UDim2.fromOffset(12,8),UDim2.fromOffset(144,30),Color3.fromRGB(28,132,216),10)
U.text(coin,UDim2.fromOffset(9,0),UDim2.new(1,-18,1,0),'Quartz 1,840',16,U.palette.white,true)
local cargo=U.panel(root,UDim2.fromOffset(162,8),UDim2.fromOffset(240,30),Color3.fromRGB(30,153,95),10)
U.text(cargo,UDim2.fromOffset(9,0),UDim2.new(1,-18,1,0),'Backpack 24 / 40',16,U.palette.white,true)
local frame=U.panel(root,UDim2.fromOffset(0,0),UDim2.fromOffset(760,540),U.palette.panel,24)
frame.Name='ReviewShopSheet'
local title=U.text(frame,UDim2.fromOffset(22,12),UDim2.new(1,-80,0,38),'QUARTZ SHOP',28,U.palette.white,true);title.Font=Enum.Font.Arcade
local sub=U.text(frame,UDim2.fromOffset(22,54),UDim2.new(1,-44,0,28),'Buy a useful upgrade. Info shows the full effect.',17,U.palette.muted)
U.button(frame,UDim2.new(1,-56,0,12),UDim2.fromOffset(40,40),'X',function() gui.Enabled=false end,U.palette.danger)
local body=Instance.new('ScrollingFrame');body.Name='ShopContent';body.BackgroundTransparency=1;body.BorderSizePixel=0;body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.CanvasSize=UDim2.new();body.ScrollBarThickness=3;body.ZIndex=frame.ZIndex+1;body.Parent=frame
local key='Quartz';local info=nil
local function render()
 for _,c in ipairs(body:GetChildren()) do c:Destroy() end
 local v=root.AbsoluteSize;local w=math.min(760,v.X-24);local h=math.min(540,v.Y-68)
 frame.Size=UDim2.fromOffset(w,h);frame.Position=UDim2.fromOffset((v.X-w)/2,math.max(52,(v.Y-h)/2))
 title.TextSize=w<400 and 23 or 28;title.Text=string.upper(key)..' SHOP'
 body.Position=UDim2.fromOffset(16,90);body.Size=UDim2.fromOffset(w-32,h-106)
 ShopView.render(U,body,{profile=sample,shop=key,width=w-36,info=info,canBuy=true,
  onShop=function(nextKey) key=nextKey;info=nil;render() end,onInfo=function(nextInfo) info=nextInfo;render() end,onBuy=function() end})
end
local connection=root:GetPropertyChangedSignal('AbsoluteSize'):Connect(render)
_G.MiningUIReview={interface=U,render=render,destroy=function() connection:Disconnect();gui:Destroy();if hud then hud.Enabled=wasEnabled end;_G.MiningUIReview=nil end}
task.wait();render();task.wait(.2)
return {kind='Native production ShopView/Interface gallery',currency='Sample profile only; no player/server mutation'}
