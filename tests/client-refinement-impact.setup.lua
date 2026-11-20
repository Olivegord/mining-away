local kicks,cues={},{}
local presentation={}
function presentation:kick(position,strength,now) table.insert(kicks,{position=position,strength=strength,now=now}) end
local soundscape={}
function soundscape:play(name,position,options) table.insert(cues,{name=name,position=position,options=options}) end
local roleAudio,orbitalBurns={},{}
local impactCues=setmetatable({},{__mode='k'})
