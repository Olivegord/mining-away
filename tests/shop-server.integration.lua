-- Appended to actual server + Roblox API doubles. No engine/visual claims.
local shopChecks=0
local function shopCheck(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));shopChecks+=1;print('PASS shop server '..name) end
local shopUid=82000
local function shopPlayer()
 shopUid+=1;local pl=player(shopUid);players.PlayerAdded:Fire(pl);return pl,assert(profiles[shopUid])
end
local function shopInput(pl,p,id,tx,level)
 p.tokens=7;p.bucketAt=now
 command.OnServerEvent:Fire(pl,'BuyUpgrade',{upgradeId=id,txId=tx,level=level or 0,runId=data(p).run.id})
end
shopCheck('all five named counters are grounded and visible near the original depot',function()
 local ground=scene.packStation.Position.Y-scene.packStation.Size.Y/2
 for index,key in ipairs(Shops.ORDER) do
  local stand=assert(shopStations[key]);assert((stand.Position-home).Magnitude<55)
  assert(math.abs(stand.Position.Y-stand.Size.Y/2-ground)<1e-8)
  assert(stand.ShopSign.Front.ShopName.Text==key:upper()..' SHOP')
  assert(stand.ShopSign.Back.ShopName.Text==key:upper()..' SHOP')
  assert(math.abs(stand.Position.X-home.X)-stand.ShopSign.Size.X/2>=10,'leave the central approach clear')
  if index>1 then assert((stand.Position-shopStations[Shops.ORDER[index-1]].Position).Magnitude>=12) end
 end
end)
shopCheck('mounting counters again preserves live handler references and original assets',function()
 local original=scene.packStation.CFrame;local size=scene.packStation.Size
 local again=ShopStands.mount(scene.map,home,scene.packStation)
 for _,key in ipairs(Shops.ORDER) do assert(again[key]==shopStations[key]) end
 assert((scene.packStation.Position-original.Position).Magnitude==0 and (scene.packStation.Size-size).Magnitude==0)
 local count=0;for _,child in ipairs(scene.map:GetChildren()) do if child:GetAttribute('ShopKey') then count+=1 end end
 assert(count==5)
end)
shopCheck('remote cannot purchase away from its actual kiosk',function()
 local pl,p=shopPlayer();data(p).run.wallet.Quartz=1000;pl.Character:PivotTo(CFrame.new(home))
 shopInput(pl,p,'quartz_scanner','far');assert(data(p).run.wallet.Quartz==1000 and not data(p).run.shopLevels.quartz_scanner)
end)
shopCheck('kiosk purchase is saved once and updates real drone targeting stats',function()
 local pl,p=shopPlayer();data(p).run.wallet.Quartz=1000;pl.Character:PivotTo(shopStations.Quartz.CFrame)
 shopInput(pl,p,'quartz_scanner','scanner');assert(data(p).run.wallet.Quartz==960 and p.drones[1].stats.plotAuto==1)
 shopInput(pl,p,'quartz_scanner','scanner');assert(data(p).run.wallet.Quartz==960)
 local stored=assert(runtimeStore.values[p.session.key]);assert(stored.data.run.shopLevels.quartz_scanner==1 and stored.data.run.wallet.Quartz==960)
end)
shopCheck('shop access does not bypass the real Cobalt guard gate',function()
 local pl,p=shopPlayer();data(p).run.wallet.Quartz=1000;pl.Character:PivotTo(shopStations.Quartz.CFrame)
 assert(not playerCanMine(p,patches[2]));shopInput(pl,p,'quartz_ruby','ruby');assert(playerCanMine(p,patches[2]))
 data(p).run.wallet.Ruby=1000;pl.Character:PivotTo(shopStations.Ruby.CFrame);shopInput(pl,p,'ruby_cobalt','cobalt')
 assert(Shops.unlocked(data(p),'Cobalt'));assert(not playerCanMine(p,patches[3]))
 data(p).clearedFields.Cobalt=true;assert(playerCanMine(p,patches[3]))
end)
shopCheck('locked field commands cannot enroll a fleet into its encounter',function()
 local pl,p=shopPlayer();pl.Character:PivotTo(CFrame.new(patches[3].center));p.tokens=7
 command.OnServerEvent:Fire(pl,'Patch',{fieldId=3,requestId='locked-field'})
 assert(not p.drones[1].field);assert(patches[3].e.users[pl.UserId]==nil)
end)
print(shopChecks..' actual server shop integration checks passed using API doubles; not Studio evidence')
