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
shopCheck('spawn and real character respawns face the centrally placed nearest Quartz field',function()
 local first=scene.fields[1];local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 assert(first.cfg.Key=='Quartz');assert(math.abs(first.center.X-home.X)<1e-8)
 assert(math.abs(first.center.Z-first.part.Size.Z/2-spawn.Position.Z-10)<1e-8)
 local distance=(first.center-spawn.Position).Magnitude
 for index=2,#scene.fields do assert((scene.fields[index].center-spawn.Position).Magnitude>distance) end
 local pl=shopPlayer();assert((pl.Character:GetPivot().Position-(scene.spawnPosition+Vector3.new(0,4,0))).Magnitude<1e-8)
 local ch=Instance.new('Model');local hr=Instance.new('Part');hr.Name='HumanoidRootPart';hr.Parent=ch;ch.PrimaryPart=hr;pl.Character=ch;ch.Parent=workspace
 pl.CharacterAdded:Fire(ch);assert((ch:GetPivot().Position-(scene.spawnPosition+Vector3.new(0,4,0))).Magnitude<1e-8)
end)
shopCheck('all five named counters are grounded and visible near the original depot',function()
 local pad=scene.map:FindFirstChild('HubPad',true)
 local ground=pad and pad.Position.Y+pad.Size.Y/2 or scene.packStation.Position.Y-scene.packStation.Size.Y/2
 for index,key in ipairs(Shops.ORDER) do
  local stand=assert(shopStations[key]);assert((stand.Position-home).Magnitude<55)
  assert(math.abs(stand.Position.Y-stand.Size.Y/2-ground)<1e-8)
  assert(stand.ShopSign.Front.ShopName.Text==key:upper()..' SHOP')
  assert(stand.ShopSign.Back.ShopName.Text==key:upper()..' SHOP')
  assert(math.abs(stand.Position.X-home.X)-stand.ShopSign.Size.X/2>=8,'leave the central approach clear')
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
shopCheck('counter feet use the real hub-pad top rather than an embedded machine bottom',function()
 local pad=Instance.new('Part');pad.Name='HubPad';pad.Position=Vector3.new(home.X,2,home.Z);pad.Size=Vector3.new(84,1,76);pad.Parent=scene.map
 local again=ShopStands.mount(scene.map,home,scene.packStation)
 for _,stand in pairs(again) do
  assert(math.abs(stand.Position.Y-stand.Size.Y/2-2.5)<1e-8)
  assert(math.abs(stand.Position.X-home.X)+stand.ShopSign.Size.X/2<42)
 end
 pad:Destroy();ShopStands.mount(scene.map,home,scene.packStation)
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
