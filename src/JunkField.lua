-- Shared timings and finishes for the local Quartz prototype.
local J={BatchSize=4,Cap=10,LowWork=2,CrewCap=2,DropHeight=53,FallTime=.82,SettleTime=.32}
J.Props={
 {name='Pip Block',template='PipsCube',size=5.8,work=54,ore=10,color={232,220,194},interior='Wool'},
 {name='Plaid Cube',template='BlueGinghamPaver',size=6.3,work=65,ore=12,color={184,209,235},interior='Wool'},
 {name='Battered Crate',template='TimberCube',size=6.8,work=82,ore=15,color={164,103,76},interior='Cork'},
 {name='Knit Block',template='KnitCube',size=5.5,work=59,ore=11,color={211,153,155},interior='Foam'},
 {name='Daisy Cube',template='DaisiesCube',size=5.3,work=50,ore=9,color={224,196,154},interior='Wool'},
}
J.TemplateProps={
 {name='Suggestion Box',template='SuggestionBox',work=67,ore=12,interior='Wool'},
 {name='Gumball Dispenser',template='GumballDispenser',work=72,ore=13,interior='Wool'},
 {name='Alphabet Block',template='AlphabetBlock',work=52,ore=10,interior='Foam'},
 {name='Box Fan',template='BoxFan',work=79,ore=14,interior='Cork'},
 {name='Cube Aquarium',template='CubeAquarium',work=68,ore=12,interior='Wool'},
 {name='Ice Cube',template='IceCube',work=61,ore=11,interior='Wool'},
 {name='Ticket Box',template='TicketBox',work=57,ore=10,interior='Cork'},
 {name='Moving Box',template='MovingBox',work=62,ore=11,interior='Foam'},
}
local interiors={Wool={Enum.Material.Fabric,Color3.fromRGB(248,244,231)},
 Cork={Enum.Material.Wood,Color3.fromRGB(215,174,120)},Foam={Enum.Material.Fabric,Color3.fromRGB(193,237,211)}}
function J.finish(name)
 local finish=interiors[name]
 if finish then return finish[1],finish[2] end
end
function J.fallPose(age,grounded)
 if age<0 then return grounded+Vector3.yAxis*J.DropHeight end
 if age<J.FallTime then
  local t=age/J.FallTime
  return (grounded+Vector3.yAxis*(J.DropHeight*(1-t*t)))*CFrame.Angles(.62*(1-t),.95*(1-t),-.28*(1-t))
 end
 local t=math.clamp((age-J.FallTime)/J.SettleTime,0,1)
 return (grounded+Vector3.yAxis*(6.4*t*(1-t)))*CFrame.Angles(.13*math.sin(t*math.pi),0,0)
end
-- Give crews without a job the next object, then rotate within each job
-- count by least recent award. Failed/blocked requests cannot lose a turn.
function J.dispatch(crews,claim)
 while #crews>0 do
  table.sort(crews,function(a,b)
   if a.active~=b.active then return a.active<b.active end
   if a.turn~=b.turn then return a.turn<b.turn end
   return a.id<b.id
  end)
  local crew=crews[1]
  if crew.active>=J.CrewCap or not claim(crew) then table.remove(crews,1)
  else crew.active+=1 end
 end
end
return J
