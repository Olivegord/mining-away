local V={}
local icons={
 quartz_power='mining',quartz_scanner='combat',quartz_backpack='cargo',quartz_miner_focus='startup',
 ruby_pack_speed='cards',ruby_rotors='flight',ruby_courier_hold='cargo',ruby_breaker_head='hammer',
 cobalt_orbital='laser',cobalt_pack_discount='coin',cobalt_relay='relay',cobalt_scout_memory='seed',
 violet_scrap='swarm',violet_courier='flight',violet_repair_kit='survival',
 emerald_orbital_cycle='laser',emerald_relay='relay',emerald_swarm_bay='swarm',emerald_pack_speed='cards',
}
function V.render(U,parent,options)
 local p=options.profile;local key=options.shop;local width=options.width
 local color=key=='Quartz' and Color3.fromRGB(41,139,214) or Color3.fromRGB(unpack(Shops.COLORS[key]))
 local tabs=Instance.new('ScrollingFrame');tabs.Name='ShopTabs';tabs.Size=UDim2.fromOffset(width,48)
 tabs.BackgroundTransparency=1;tabs.BorderSizePixel=0;tabs.ScrollBarThickness=2;tabs.ScrollingDirection=Enum.ScrollingDirection.X;tabs.AutomaticCanvasSize=Enum.AutomaticSize.X
 tabs.CanvasSize=UDim2.fromOffset(0,0);tabs.ZIndex=parent.ZIndex+1;tabs.Parent=parent
 local row=Instance.new('UIListLayout');row.FillDirection=Enum.FillDirection.Horizontal;row.SortOrder=Enum.SortOrder.LayoutOrder;row.Padding=UDim.new(0,6);row.Parent=tabs
 for index,shop in ipairs(Shops.ORDER) do
  local b=U.button(tabs,UDim2.fromOffset(0,0),UDim2.fromOffset(82,44),shop,function() options.onShop(shop) end,shop==key and color or U.palette.paper)
  b.TextSize=16;b.LayoutOrder=index;b.Name='ShopTab_'..shop
 end
 if not Shops.unlocked(p,key) then return end
 local grid=U.frame(parent,UDim2.fromOffset(0,56),UDim2.fromOffset(width,0));grid.BackgroundTransparency=1;grid.Name='UpgradeGrid';grid.AutomaticSize=Enum.AutomaticSize.Y
 local columns=width>=560 and 2 or 1;local gap=8
 local layout=Instance.new('UIGridLayout');layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.FillDirectionMaxCells=columns
 layout.CellPadding=UDim2.fromOffset(gap,gap);layout.CellSize=UDim2.new(1/columns,-gap*(columns-1)/columns,0,130);layout.Parent=grid
 for index,entry in ipairs(Shops.CATALOG) do if entry.shop==key then
  local owned=p.run.shopLevels[entry.id] or 0;local cost=Shops.cost(entry,owned)
  local complete=owned>=entry.max or (entry.unlock and Shops.unlocked(p,entry.unlock))
  local why=not complete and Shops.reason(p,entry)
  local available=not complete and not why and Shops.balance(p,key)>=cost and options.canBuy
  local cell=U.panel(grid,UDim2.fromOffset(0,0),UDim2.fromOffset(200,130),color:Lerp(U.palette.panel,.45),14);cell.Name='Upgrade_'..entry.id;cell.LayoutOrder=index
  local iconColor=entry.unlock and Color3.fromRGB(unpack(Shops.COLORS[entry.unlock])) or color
  U.icon(cell,entry.unlock and 'crystal' or icons[entry.id],UDim2.fromOffset(10,12),UDim2.fromOffset(38,38),iconColor)
  local title=entry.title
  if entry.max>1 then title=title..'  '..owned..'/'..entry.max end
  U.text(cell,UDim2.fromOffset(54,7),UDim2.new(1,-64,0,24),title,16,U.palette.text,true)
  U.text(cell,UDim2.fromOffset(54,33),UDim2.new(1,-64,0,40),entry.description,16,U.palette.text)
  local action=complete and (entry.unlock and 'Unlocked' or 'Owned') or why or ('Buy · '..cost..' '..key)
  local buy=U.button(cell,UDim2.fromOffset(10,76),UDim2.new(1,-20,0,44),action,function() options.onBuy(entry,owned) end,color)
  buy.Name='BuyUpgrade';buy.TextSize=16;U.setEnabled(buy,available==true)
 end end
end
return V
