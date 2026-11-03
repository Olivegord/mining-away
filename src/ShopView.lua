-- Adapts Roblox Creator Hub's interactive-menu and equal-cell shop tutorials:
-- https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/interactive-ui
-- https://create.roblox.com/docs/ui/grid-table-layouts
-- Native UIGridLayout, Activated buttons and independently scrolling content.
local V={}
function V.render(U,parent,options)
 local p=options.profile;local key=options.shop;local width=options.width
 local color=key=='Quartz' and Color3.fromRGB(41,139,214) or Color3.fromRGB(unpack(Shops.COLORS[key]));local ink=U.palette.text
 local function text(root,x,y,w,h,value,size,bold)
  return U.text(root,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),value,size or 16,ink,bold)
 end
 local function button(root,x,y,w,value,callback,tint)
  local b=U.button(root,UDim2.fromOffset(x,y),UDim2.fromOffset(w,44),value,callback,tint or U.palette.paper);b.TextSize=16;return b
 end
 if options.info then
  local entry=Shops.BY_ID[options.info]
  if entry then
   button(parent,2,2,140,'< Upgrades',function() options.onInfo(nil) end)
   text(parent,2,62,width-4,56,entry.title,24,true)
   local details=text(parent,2,124,width-4,0,entry.info..'\n\nCost: '..Shops.cost(entry,p.run.shopLevels[entry.id] or 0)..' '..entry.shop..'\n\nResets at prestige. Your permanent drones and guard clearances stay.',18)
   details.AutomaticSize=Enum.AutomaticSize.Y;details.TextYAlignment=Enum.TextYAlignment.Top
  end
  return
 end
 local tabs=Instance.new('ScrollingFrame');tabs.Name='ShopTabs';tabs.Position=UDim2.fromOffset(2,2);tabs.Size=UDim2.fromOffset(width-4,48)
 tabs.BackgroundTransparency=1;tabs.BorderSizePixel=0;tabs.ScrollBarThickness=2;tabs.ScrollingDirection=Enum.ScrollingDirection.X;tabs.AutomaticCanvasSize=Enum.AutomaticSize.X
 tabs.CanvasSize=UDim2.fromOffset(0,0);tabs.ZIndex=parent.ZIndex+1;tabs.Parent=parent
 local row=Instance.new('UIListLayout');row.FillDirection=Enum.FillDirection.Horizontal;row.SortOrder=Enum.SortOrder.LayoutOrder;row.Padding=UDim.new(0,6);row.Parent=tabs
 for index,shop in ipairs(Shops.ORDER) do
  local unlocked=Shops.unlocked(p,shop)
  local b=button(tabs,0,0,unlocked and 100 or 138,shop..(unlocked and '' or ' · locked'),function() options.onShop(shop) end,shop==key and color or U.palette.paper);b.LayoutOrder=index;b.Name='ShopTab_'..shop
 end
 local unlocked=Shops.unlocked(p,key);local index=table.find(Shops.ORDER,key) or 1
 text(parent,2,58,width-4,30,unlocked and (tostring(Shops.balance(p,key))..' '..key..'  ·  spend '..key..' here') or ('Locked · unlock in the '..Shops.ORDER[math.max(1,index-1)]..' shop'),18,true)
 local grid=U.frame(parent,UDim2.fromOffset(2,100),UDim2.fromOffset(width-4,0));grid.BackgroundTransparency=1;grid.Name='UpgradeGrid';grid.AutomaticSize=Enum.AutomaticSize.Y
 local columns=width>=560 and 2 or 1;local gap=10
 local layout=Instance.new('UIGridLayout');layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.FillDirectionMaxCells=columns
 layout.CellPadding=UDim2.fromOffset(gap,gap);layout.CellSize=UDim2.new(1/columns,-gap*(columns-1)/columns,0,190);layout.Parent=grid
 for index,entry in ipairs(Shops.CATALOG) do if entry.shop==key then
  local owned=p.run.shopLevels[entry.id] or 0;local cost=Shops.cost(entry,owned)
  local complete=owned>=entry.max or (entry.unlock and Shops.unlocked(p,entry.unlock))
  local cell=U.panel(grid,UDim2.fromOffset(0,0),UDim2.fromOffset(200,190),color:Lerp(U.palette.panel,.45),14);cell.Name='Upgrade_'..entry.id;cell.LayoutOrder=index
  local title=U.text(cell,UDim2.fromOffset(12,10),UDim2.new(1,-24,0,42),entry.title,18,ink,true);title.TextYAlignment=Enum.TextYAlignment.Top
  local desc=U.text(cell,UDim2.fromOffset(12,55),UDim2.new(1,-24,0,44),entry.description,16,ink);desc.TextYAlignment=Enum.TextYAlignment.Top
  U.text(cell,UDim2.fromOffset(12,102),UDim2.new(1,-24,0,24),complete and 'Installed' or ('Level '..owned..' / '..entry.max),16,U.palette.muted)
  local why=Shops.reason(p,entry);local available=not complete and not why and Shops.balance(p,key)>=cost and options.canBuy
  local buy=U.button(cell,UDim2.fromOffset(10,136),UDim2.new(1,-74,0,44),complete and 'Installed' or ('Buy · '..cost..' '..key),function() options.onBuy(entry,owned) end,color)
  buy.Name='BuyUpgrade';buy.TextSize=16;U.setEnabled(buy,available==true)
  local info=U.button(cell,UDim2.new(1,-54,0,136),UDim2.fromOffset(44,44),'i',function() options.onInfo(entry.id) end,U.palette.paper)
  info.Name='UpgradeInfo';info.TextSize=22
  if why then desc.Text=why end
 end end
end
return V
