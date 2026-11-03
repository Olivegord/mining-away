-- The real Studio preview crew must retain purchased permanent miners on reconnect.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS special preview '..name) end
local uid=98801
check('preview starts with approved eight roles and one permanent owner identity',function()
 local pl=player(uid);players.PlayerAdded:Fire(pl);local p=assert(profiles[uid])
 assert(preview and #p.drones==8 and #data(p).fleet==1)
 assert(p.player:GetAttribute('MA_DevToolsEnabled')==true and store.mode:sub(1,7)=='Preview')
end)
check('permanent special purchase appears beside preview roles and survives reconnect',function()
 local p=profiles[uid];local pl=p.player
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));data(p).run.wallet.Quartz=10000;data(p).run.credits=10000
 p.tokens=7;p.bucketAt=now
 command.OnServerEvent:Fire(pl,'BuyDrone',{droneType='Bubbler',txId='preview-permanent',runId=data(p).run.id})
 assert(#data(p).fleet==2 and #p.drones==9)
 local owned=data(p).fleet[2];assert(owned.role=='Bubbler')
 local id=owned.id;players.PlayerRemoving:Fire(pl);assert(not profiles[uid])
 local replacement=player(uid);players.PlayerAdded:Fire(replacement);p=assert(profiles[uid])
 assert(#data(p).fleet==2 and #p.drones==9)
 local count=0;for _,d in ipairs(p.drones) do if d.role=='Bubbler' then assert(d.id==id);count+=1 end end
 assert(count==1 and #p.testFleet==9 and Pro.validate(data(p),uid))
end)
print(checks..' Studio-preview ownership logic checks passed with API doubles; not Studio execution')
