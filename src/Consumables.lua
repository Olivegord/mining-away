-- Earned field tools live in their own backpack pockets, never in ore cargo.
-- Pure rules shared by profile validation, server drops and the placement UI.
local C={STACK=3,MAX_DRY=8,ORDER={'Orbital','Scrap'}}
C.ITEMS={
 Orbital={name='Orbital Beacon',short='Orbital',radius=12,color={246,108,83},description='Place beside a tough rock. Melts the nearest ready rock in 4 seconds.'},
 Scrap={name='Scrap Capsule',short='Scrap bots',radius=16,color={161,131,244},description='Place among leftovers. Six tiny miners work this area for 10 seconds.'},
}
local function integer(n,max)
 return type(n)=='number' and n==n and n>=0 and n%1==0 and n<=(max or 1e12)
end
function C.fresh()
 return {counts={Orbital=0,Scrap=0},collected=0,misses=0,rocks=0,version=0}
end
function C.validate(s)
 if type(s)~='table' or type(s.counts)~='table' then return false,'Missing consumable backpack' end
 for _,kind in ipairs(C.ORDER) do if not integer(s.counts[kind],C.STACK) then return false,'Invalid consumable count' end end
 for kind in pairs(s.counts) do if not C.ITEMS[kind] then return false,'Unknown consumable' end end
 for _,key in ipairs({'collected','rocks','version'}) do if not integer(s[key]) then return false,'Invalid consumable progress' end end
 if not integer(s.misses,C.MAX_DRY) then return false,'Invalid discovery streak' end
 local pending=s.pending
 if pending~=nil then
  if type(pending)~='table' or not C.ITEMS[pending.kind] or s.counts[pending.kind]>=C.STACK
   or type(pending.txId)~='string' or #pending.txId<1 or #pending.txId>100
   or type(pending.runId)~='string' or #pending.runId<1 or #pending.runId>100 then return false,'Invalid reserved consumable' end
 end
 return true
end
function C.room(s,kind)
 return C.ITEMS[kind]~=nil and s.counts[kind]+(s.pending and s.pending.kind==kind and 1 or 0)<C.STACK
end
function C.onRock(s,tier,roll,choice)
 local available={}
 for _,kind in ipairs(C.ORDER) do if C.room(s,kind) then table.insert(available,kind) end end
 if #available==0 then return nil end
 s.rocks+=1;s.misses=math.min(C.MAX_DRY,s.misses+1)
 -- Teach both actions early. Afterwards randomness varies the opportunity,
 -- while the eighth eligible break guarantees useful equipment.
 if s.collected==0 then return s.misses>=3 and (C.room(s,'Orbital') and 'Orbital' or available[1]) or nil end
 if s.collected==1 then return s.misses>=5 and (C.room(s,'Scrap') and 'Scrap' or available[1]) or nil end
 local chance=.18+.03*math.clamp((tier or 1)-1,0,4)
 if s.misses<C.MAX_DRY and roll>=chance then return nil end
 return available[math.min(#available,1+math.floor(math.clamp(choice,0,.999999)*#available))]
end
function C.collect(s,kind)
 if not C.room(s,kind) then return false end
 s.counts[kind]+=1;s.collected+=1;s.misses=0;s.version+=1
 return true
end
function C.reserve(s,kind,version,txId,runId)
 if not C.ITEMS[kind] or s.counts[kind]<1 then return false,'That backpack pocket is empty' end
 if s.pending then return false,'A tool is already deploying' end
 if version~=s.version then return false,'Backpack changed; try again' end
 if type(txId)~='string' or #txId<1 or #txId>100 or type(runId)~='string' or #runId<1 or #runId>100 then return false,'Invalid deployment' end
 s.counts[kind]-=1;s.version+=1;s.pending={kind=kind,txId=txId,runId=runId}
 return true
end
function C.accept(s)
 if not s.pending then return false end
 s.pending=nil;s.version+=1;return true
end
function C.refund(s)
 local pending=s.pending;if not pending then return false end
 s.counts[pending.kind]+=1;s.pending=nil;s.version+=1;return true
end
return C
