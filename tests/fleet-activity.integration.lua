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
dead:SetAttribute('HP',80);a=HUD.activity(folder,1);assert(a.miners==10 and a.assigned==8,'reprinting must not invent an order')
print('PASS HUD classifies nine miners independently of six support, other owners, windup, specials, recovery and reprints')
