local cues={}
local crystalAudio={play=function(_,_,event)table.insert(cues,event)end}
local presentation={resourceImpact=function()end,resourceRise=function()end}
local rockDamage={update=function()end}
local Shops={ORDER={'Quartz'}}
