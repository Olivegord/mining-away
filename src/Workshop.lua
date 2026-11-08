-- Small Quartz run: draft three blueprints, then invest in those choices.
-- These local tuning values travel with the saved offer, so reconnects never reroll.
local W={SLOTS=3,PACK_PRICES={20,45,80},LEVEL_COST=20,LEVEL_GROWTH=1.7,PRESTIGE_BASE=360}
W.TIERS={'Common','Rare','Epic','Legendary'}
W.CATALOG={
 {id='Q_POWER',title='Power Cell',scope='Fleet',category='mining',max=6,step={mining=.5},color={246,113,93},icon='mining'},
 {id='Q_IGNITION',title='Quick Ignition',scope='Fleet',category='startup',max=6,step={startup=1},color={69,190,244},icon='startup'},
 {id='Q_CARGO',title='Deep Pockets',scope='Player',category='cargo',max=4,step={capacity=.5},color={255,190,65},icon='cargo'},
 {id='Q_YIELD',title='Quartz Polisher',scope='Fleet',category='cargo',max=4,step={yield=.25},color={188,119,245},icon='crystal'},
 {id='Q_SCANNER',title='Route Runner',scope='Fleet',category='flight',max=5,step={speed=.4},once={plotAuto=1},color={78,211,145},icon='flight'},
 {id='Q_SPLIT',title='Prism Relay',scope='Fleet',category='mining',max=4,step={fork=.1},once={forkRange=6},color={57,210,222},icon='relay'},
}
W.BY_ID={};for _,entry in ipairs(W.CATALOG) do W.BY_ID[entry.id]=entry end
function W.owned(p)
 local result={}
 for _,c in ipairs(p.run.cards) do if c.workshop then table.insert(result,c) end end
 return result
end
function W.find(p,id)
 for _,c in ipairs(p.run.cards) do if c.workshop and c.cardId==id then return c end end
 return nil
end
function W.price(p) return W.PACK_PRICES[#W.owned(p)+1] end
function W.levelCost(c) return math.floor(c.levelCost*c.levelGrowth^(c.level-1)+.5) end
function W.effects(c,level)
 local effects={}
 for k,v in pairs(c.step) do effects[k]=v*level end
 for k,v in pairs(c.once or {}) do effects[k]=v end
 return effects
end
function W.card(entry,tier)
 local c={cardId=entry.id,title=entry.title,scope=entry.scope,category=entry.category,workshop=true,
  level=math.min(tier,entry.max),maxLevel=entry.max,step=table.clone(entry.step),once=table.clone(entry.once or {}),
  levelCost=W.LEVEL_COST,levelGrowth=W.LEVEL_GROWTH,rarity=W.TIERS[tier],packTier=tier,expires='This run'}
 c.effects=W.effects(c,c.level)
 c.description='Starts at level '..c.level..'. Buy more levels in the Quartz Workshop.'
 c.headline='LEVEL '..c.level..' BLUEPRINT';c.purpose='Choose a build, then invest in it'
 c.tradeoff='Uses 1 of 3 build slots';c.stackText='Level '..c.level..' / '..c.maxLevel..' · This run'
 return c
end
function W.validate(c)
 if not c.workshop then return true end
 local entry=W.BY_ID[c.cardId]
 if not entry or c.workshop~=true or c.scope~=entry.scope or type(c.level)~='number' or c.level%1~=0
  or c.level<1 or c.level>entry.max or c.maxLevel~=entry.max or c.levelCost~=W.LEVEL_COST or c.levelGrowth~=W.LEVEL_GROWTH
  or type(c.step)~='table' or type(c.once)~='table' or type(c.effects)~='table'
  or type(c.packTier)~='number' or c.packTier%1~=0 or c.packTier<1 or c.packTier>4 or c.rarity~=W.TIERS[c.packTier] then return false end
 local function same(a,b)
  for k,v in pairs(a) do if b[k]~=v then return false end end
  for k,v in pairs(b) do if a[k]~=v then return false end end
  return true
 end
 return same(c.step,entry.step) and same(c.once,entry.once or {}) and same(c.effects,W.effects(c,c.level))
end
return W
