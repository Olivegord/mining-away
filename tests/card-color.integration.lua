local seen={};local count=0
local function luminance(c)
 local function linear(v) return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
 return linear(c.R)*.2126+linear(c.G)*.7152+linear(c.B)*.0722
end
for _,choice in ipairs(Cards.CATALOG) do
 local saved=choice.effects;local family,color,accent=CardView.identity(choice)
 assert(type(family)=='string' and color and accent and choice.effects==saved)
 seen[family]=true;count+=1
 local summary=CardView.summary(choice);local terms=CardView.terms(choice)
 assert(#summary>0 and terms:find('This run',1,true))
 local contrast=1.05/(luminance(color)+.05);assert(contrast>=3,'large benefit text lacks minimum contrast: '..family)
end
local families=0;for _ in pairs(seen) do families+=1 end;assert(families>=7)
local choice={scope='Individual',targetName='Cutter 4',effects={mining=.5,speed=-.2}}
local terms=CardView.terms(choice);assert(terms:find('Cutter 4',1,true) and terms:find('20%',1,true) and terms:find('drone speed',1,true))
assert(CardView.summary(choice):find('50%',1,true),'actual benefit is missing')
local first={}
for i,id in ipairs(Workshop.FIRST_PACK) do first[i]=Workshop.card(Workshop.BY_ID[id],2,0) end
assert(CardView.identity(first[1])=='double' and CardView.identity(first[2])=='seams' and CardView.identity(first[3])=='aftershock')
assert(CardView.summary(first[2])==Workshop.LOOSE_SEAMS_TEXT and CardView.terms(first[2]):find('Mining drones',1,true))
assert(CardView.summary(first[3]):find("Cracks hit one weak rock.\n12% of the cracked rock's HP",1,true))
assert(CardView.terms(first[3]):find('Mining drones',1,true))
local stacked=Workshop.card(Workshop.BY_ID.Q_AFTERSHOCK,2,1)
assert(CardView.summary(stacked):find("24% of the cracked rock's HP",1,true),'stacked offer showed only the added damage')
local miner={name='Striker 2'};local stats={miningDPS=31,maxStep60=.4,yieldMultiplier=1.25}
assert(CardView.fitText(first[1],miner,stats,true)=='Striker 2  ›\n31 → 62 HP/s')
assert(CardView.fitText(first[1],miner,nil,false)=='Striker 2')
assert(CardView.fitText(nil,nil,nil,false)=='No eligible miners')
assert(CardView.fitText(Workshop.card(Workshop.BY_ID.Q_TURBO_ROTOR,2),miner,stats,false):find('24 → 48 studs/s',1,true))
assert(CardView.fitText(Workshop.card(Workshop.BY_ID.Q_ORE_DUPLICATOR,2),miner,stats,false):find('1.25× → 2.5× value',1,true))
print('PASS '..count..' production card summaries/targets/palettes, '..families..' mechanic families, large-text color contrast and named-drone penalty. Native SurfaceGui legibility/focus/touch NOT VERIFIED.')
