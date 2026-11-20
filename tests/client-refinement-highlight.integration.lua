local ctx={world=world,parent=fx,resources={rock={source=rock,view=view}},drones={},profile=function() return {run={id='run'}} end,hidden=function() return false end,blocks=function() return false end,touchPoint=function() return nil end}
local v=CommandView.new(ctx)
v:update(.1,1000)
assert(v.pool[1] and v.pool[1].Enabled and v.pool[1].Adornee==view,'starter hover must mark the clicked rock')
assert(v.pool[1].OutlineTransparency==1 and v.pool[1].FillTransparency<1,'hover needs a fill without an outline')
assert(v.meter.Enabled and v.meter.Adornee==view,'one contextual health meter follows hover')
hit=floor;v:update(.1,1000)
assert(not v.pool[1].Enabled and not v.meter.Enabled,'hovering the ground clears the rock cue')
local calls={};ctx.command={FireServer=function(_,action,payload) table.insert(calls,payload) end}
v:beginDrag();hit=rock;v:update(.1,1000);v:update(.1,1000)
assert(#calls==1 and calls[1].toggle==false,'holding over a rock must not repeat or cancel the order')
local drone=Instance.new('Model');drone.Parent=fx
local shell=Instance.new('Part');shell.Parent=drone
local authoritative=Instance.new('Model');authoritative:SetAttribute('DroneId','worker');authoritative.Parent=world
ctx.drones[authoritative]={view=drone}
v:reply({droneId='worker',resourceId='rock',status='accepted'})
for step=1,60 do v:update(.1,1000+step*.1) end
local outlines=0
for _,h in ipairs(fx:GetDescendants()) do if h:IsA('Highlight') and h.Adornee==drone then outlines+=1 end end
assert(outlines==0,'mining command created a drone outline')
v:endDrag()
rock:SetAttribute('OreValue',40);rock:SetAttribute('MaxHP',120)
hit=floor
local meter=v.meter
localPlayer:SetAttribute('MA_SelectorFocus','Queued:rock')
v:update(.1,1010)
assert(v.meter==meter and meter.Enabled and meter.Adornee==view and not meter.AlwaysOnTop and v.pair.Text=='Queued')
localPlayer:SetAttribute('MA_SelectorFocus','Travel:rock');v:update(.1,1010.1)
assert(v.pair.Text=='En route' and v.pool[1].OutlineTransparency==1)
localPlayer:SetAttribute('MA_SelectorFocus','Cutting:rock');v:update(.1,1010.2)
assert(v.pair.Text=='Cutting' and v.pair.Visible and v.title.Text=='Rock · 40 Quartz')
ctx.hidden=function() return true end;v:update(.1,1010.3)
assert(not meter.Enabled,'focus appeared over a menu')
ctx.hidden=function() return false end
localPlayer:SetAttribute('MA_SelectorFocus',nil);v:update(.1,1010.4)
assert(not meter.Enabled,'cleared focus left the meter visible')
v:destroy();assert(v.meter._destroyed,'context readout must be cleaned')
assert(v.pool[1]._destroyed,'highlights must be cleaned')
print('PASS current command highlight scope and cleanup (API doubles)')
