Vector3.yAxis=Vector3.new(0,1,0)
local source=Instance.new('Part');source:SetAttribute('FullSize',Vector3.one*4)
local view=Instance.new('Part');view.Size=Vector3.one;view.Color=Color3.new(1,1,1);view.Position=Vector3.zero;view.CFrame=CFrame.new()
local resource={source=source,view=view,baseColor=view.Color}
local chunks,bursts,kicks=0,0,0
local function burst()bursts+=1 end
local renderer={work={burst=burst,fracture=burst},kick=function()kicks+=1 end,_floor=function()return 0 end,_fragment=function()chunks+=1 end}
P.resourceImpact(renderer,resource,'stage',1);P.resourceImpact(renderer,resource,'break',2)
assert(chunks==12 and bursts==2 and kicks==1,'ordinary mining lost authored fracture/break feedback')
source:SetAttribute('EffectType','Halver');source:SetAttribute('EffectDoneAt',3)
P.resourceImpact(renderer,resource,'stage',3);P.resourceImpact(renderer,resource,'break',4)
assert(chunks==12 and bursts==2 and kicks==2,'completed specialist doubled its fragment shower or lost confirmed break shake')
print('PASS production ordinary fracture retained; specialist avoids duplicate showers and retains confirmed break shake')
