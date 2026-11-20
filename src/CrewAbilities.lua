-- Crew abilities: one big button per drone type the player owns.
-- Rock breaks fill every button; a full button can be tapped once.
-- Barrage: every drone of that type fires one big shot at its own rock, one
-- after another. Shockwave blasts every rock around the target at once.
-- Damage comes from the crew's own mining power, so a hard field stays hard.
-- Pure logic shared by the server (authority) and client (display).
local C={}
C.KINDS={
 Barrage={breaks=6,lead=.55,stagger=.16,shotSeconds=5},
 Shockwave={breaks=8,radius=12,fraction=.7,powerSeconds=4,impact=.42},
}
-- Each drone type keeps its own name and color so a new type feels new.
C.ROLES={
 Striker={kind='Barrage',name='Laser Barrage',color={90,230,255}},
 Needler={kind='Barrage',name='Dart Storm',color={255,195,94}},
 Gridcutter={kind='Barrage',name='Grid Strike',color={255,100,130}},
 Bubbler={kind='Barrage',name='Bubble Barrage',color={120,225,255}},
 Frostbite={kind='Barrage',name='Ice Volley',color={150,255,245}},
 Resonator={kind='Barrage',name='Resonance',color={125,255,160}},
 Charger={kind='Shockwave',name='Ground Pound',color={255,110,90}},
 Ballcaster={kind='Shockwave',name='Mega Ball',color={150,124,255}},
 Halver={kind='Shockwave',name='Split Quake',color={190,140,255}},
 Singularity={kind='Shockwave',name='Black Hole',color={155,100,255}},
 Starforge={kind='Shockwave',name='Solar Flare',color={255,170,60}},
 Ramiel={kind='Shockwave',name='Prism Blast',color={93,203,255}},
 Nomad={kind='Shockwave',name='Sky Rocket',color={101,194,255}},
}
C.ORDER={'Striker','Needler','Gridcutter','Bubbler','Frostbite','Resonator','Charger','Ballcaster','Halver','Singularity','Starforge','Ramiel','Nomad'}
C.MAX_BUTTONS=3
local legacy={Blue='Striker',Red='Charger'}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function C.role(role) return legacy[role] or role end
function C.definition(role)
 local entry=C.ROLES[C.role(role)];if not entry then return nil end
 return entry,C.KINDS[entry.kind]
end
-- The buttons a fleet earns, in a stable order, at most MAX_BUTTONS.
function C.buttons(roles)
 local owned={}
 for _,role in ipairs(roles or {}) do
  role=C.role(role)
  if C.ROLES[role] then owned[role]=true end
 end
 local list={}
 for _,role in ipairs(C.ORDER) do
  if owned[role] and #list<C.MAX_BUTTONS then table.insert(list,role) end
 end
 return list
end
function C.new() return {charge={},serial=0} end
function C.need(role)
 local _,kind=C.definition(role);return kind and kind.breaks or math.huge
end
-- One owned break fills every button by one step.
function C.onBreak(state,roles)
 for _,role in ipairs(C.buttons(roles)) do
  state.charge[role]=math.min(C.need(role),(state.charge[role] or 0)+1)
 end
end
function C.ready(state,role)
 role=C.role(role)
 return C.ROLES[role]~=nil and (state.charge[role] or 0)>=C.need(role)
end
-- Spend a full button. Returns the definition so the caller can act on it.
function C.trigger(state,role,roles,now)
 role=C.role(role)
 if not finite(now) or not table.find(C.buttons(roles),role) then return false,'You do not have that drone' end
 if not C.ready(state,role) then return false,'Break more rocks to charge it' end
 local entry,kind=C.definition(role)
 state.charge[role]=0
 state.serial+=1
 return true,entry,kind
end
-- Barrage: each shooter takes the open rock nearest to it that nobody else
-- picked. Returns {shooter, rock} pairs in firing order.
function C.barragePairs(rocks,shooters)
 local taken,pairs_={},{}
 for _,shooter in ipairs(shooters or {}) do
  local best,bestDistance=nil,math.huge
  for _,rock in ipairs(rocks or {}) do
   if not taken[rock] and rock.position and shooter.position then
    local d=(rock.position-shooter.position).Magnitude
    if d<bestDistance then best,bestDistance=rock,d end
   end
  end
  if best then taken[best]=true;table.insert(pairs_,{shooter=shooter,rock=best}) end
 end
 return pairs_
end
-- One shot is a few seconds of that drone's normal mining, never more than
-- the rock has left.
function C.shotDamage(power,hp)
 if not finite(power) or power<=0 or not finite(hp) or hp<=0 then return 0 end
 return math.min(hp,power*C.KINDS.Barrage.shotSeconds)
end
function C.shockDamage(power,hp,maxHP)
 if not finite(power) or power<=0 or not finite(hp) or hp<=0 or not finite(maxHP) then return 0 end
 local kind=C.KINDS.Shockwave
 return math.min(hp,maxHP*kind.fraction,power*kind.powerSeconds)
end
-- Rocks a shockwave reaches: within the radius of the center, nearest first.
function C.shockTargets(rocks,center,radius)
 local list={}
 for _,rock in ipairs(rocks or {}) do
  local p=rock.position
  if p then
   local dx,dz=p.X-center.X,p.Z-center.Z
   local d=math.sqrt(dx*dx+dz*dz)
   if d<=radius then table.insert(list,{rock=rock,distance=d}) end
  end
 end
 table.sort(list,function(a,b) if a.distance==b.distance then return tostring(a.rock.id)<tostring(b.rock.id) end;return a.distance<b.distance end)
 local out={}
 for i,entry in ipairs(list) do out[i]=entry.rock end
 return out
end
-- Compact replicated view for the buttons.
function C.view(state,roles,now)
 local out={}
 for _,role in ipairs(C.buttons(roles)) do
  local entry=C.ROLES[role]
  table.insert(out,{role=role,kind=entry.kind,name=entry.name,color=entry.color,
   charge=state.charge[role] or 0,need=C.need(role)})
 end
 return out
end
return C
