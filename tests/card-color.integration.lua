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
print('PASS '..count..' production card summaries/targets/palettes, '..families..' mechanic families, large-text color contrast and named-drone penalty. Native SurfaceGui legibility/focus/touch NOT VERIFIED.')
