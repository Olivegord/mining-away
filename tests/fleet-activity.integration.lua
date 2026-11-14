-- Appended to the production HUD.activity classifier and the Roblox API double.
local folder=Instance.new('Folder')
local function drone(role,state,worker,target,auto,owner,hp)
 local d=Instance.new('Model');d.Parent=folder
 for key,value in pairs({Owner=owner or 1,HP=hp or 80,MaxHP=80,CanMine=worker,Role=role,State=state,TargetId=target or '',AutoFieldId=auto or 0}) do d:SetAttribute(key,value) end
 return d
end
local first=drone('Striker','Warmup',true,'rock1')
drone('Charger','BreakerImpact',true,'rock2')
for _,role in ipairs({'Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}) do drone(role,'SpecialMine',true,role,1) end
for _,role in ipairs({'Courier','Courier','Medic','Dart','Orbiter','Scrapper'}) do drone(role,'Travel',false) end
drone('Striker','Mine',true,'other',1,2)
local dead=drone('Bubbler','Destroyed',true,'',0,1,0)
local a=HUD.activity(folder,1)
assert(a.total==16 and a.living==15 and a.miners==9 and a.support==6 and a.assigned==9)
assert(a.delivering==0,'support travel must not be called mining or hauling')
first:SetAttribute('State','Recover');first:SetAttribute('TargetId','');first:SetAttribute('AutoFieldId',1)
a=HUD.activity(folder,1);assert(a.assigned==9,'short recovery/regrowth must retain the plot assignment')
first:SetAttribute('AutoFieldId',0);a=HUD.activity(folder,1);assert(a.assigned==8,'a recalled worker must leave assigned count')
first:SetAttribute('State','ToCharge')
a=HUD.activity(folder,1);assert(a.docking==1 and a.charging==0,'flight to the charger counted as charging')
first:SetAttribute('State','Charging')
a=HUD.activity(folder,1);assert(a.docking==0 and a.charging==1)
dead:SetAttribute('HP',80);a=HUD.activity(folder,1);assert(a.miners==10 and a.assigned==8,'reprinting must not invent an order')
print('PASS HUD classifies nine miners independently of six support, other owners, windup, specials, recovery and reprints')

local profile={nextPackPrice=20,run={index=1,packIndex=0,quartzEarnings=0,wallet={Quartz=19}}}
assert(HUD.nextStationHint(profile)==nil)
assert(HUD.needsFirstCutHint(profile,false) and not HUD.needsFirstCutHint(profile,true))
assert(HUD.firstCutHint({Name='MouseMovement'},false)=='Follow the Crystal Run signs')
assert(HUD.firstCutHint({Name='MouseMovement'},true)=='Click crystals to pin')
assert(HUD.firstCutHint(Enum.UserInputType.Touch,true)=='Tap crystals to pin')
assert(HUD.firstCutHint({Name='Gamepad1'},true)=='Pin crystals [RB]')
assert(HUD.packHoldHint({Name='MouseMovement'})=='Hold E to open pack')
assert(HUD.packHoldHint(Enum.UserInputType.Touch)=='Hold to open pack')
assert(HUD.packHoldHint({Name='Gamepad1'})=='Hold X to open pack')
profile.run.wallet.Quartz=9;profile.deliveryQuartz=10
assert(HUD.nextStationHint(profile,true)==nil,'an insufficient shipment sent the player to the counter')
profile.deliveryQuartz=11
assert(HUD.nextStationHint(profile,true)=='Pack Counter next')
profile.deliveryQuartz=0
assert(HUD.nextStationHint(profile,true)==nil,'a vanished manifest left an obsolete hint')
profile.run.wallet.Quartz=20
assert(HUD.nextStationHint(profile,true)=='Pack Counter ready')
profile.run.packIndex=1;profile.run.pendingOffer={opened=false}
assert(HUD.nextStationHint(profile,true)=='Open pack at counter')
profile.run.pendingOffer.opened=true
assert(HUD.nextStationHint(profile)=='Pick a card at counter')
profile.run.packIndex=2
assert(HUD.nextStationHint(profile,true)==nil,'later pack displaced active mining feedback')
assert(HUD.nextStationHint(profile,true,true)=='Pick a card at counter','the paid choice was hidden on the way back')
profile.run.pendingOffer=nil
profile.nextPackPrice=36
assert(HUD.nextStationHint(profile)==nil)
profile.deliveryQuartz=16
assert(HUD.nextStationHint(profile,true,true)=='Pack Counter next' and HUD.nextStationHint(profile,true)==nil)
profile.prestigePreview={eligible=false,saleRequired=360,earnings=344}
assert(HUD.nextStationHint(profile,true,true)=='Prestige after sale')
profile.run.wallet.Quartz=36
assert(HUD.nextStationHint(profile)=='Pack Counter ready' and HUD.nextStationHint(profile,true,true)=='Pack Counter ready')
assert(HUD.nextStationHint(profile,true)==nil)
profile.prestigePreview.eligible=true
assert(HUD.nextStationHint(profile)=='Prestige ready' and HUD.nextStationHint(profile,true,true)=='Prestige ready' and HUD.nextStationHint(profile,true)==nil)
profile.run.pendingOffer={opened=false}
assert(HUD.nextStationHint(profile)=='Open pack at counter')
profile.run.index=2;profile.run.packIndex=0
assert(not HUD.needsFirstCutHint(profile,false))
print('PASS first-cut and depot cues follow input, actual sales, saved choices and the return walk without displacing later mining feedback at the pin')
