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
