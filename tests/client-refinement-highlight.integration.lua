local ctx={world=world,parent=fx,resources={rock={source=rock,view=view}},drones={},profile=function() return {run={id='run'}} end,hidden=function() return false end,blocks=function() return false end}
local v=CommandView.new(ctx)
v:update(.1,1000)
assert(v.pool[1] and v.pool[1].Enabled and v.pool[1].Adornee==view,'starter hover must mark the clicked rock')
assert(not v.fields[field].Enabled,'starter must not show automatic field scope')
localPlayer:SetAttribute('AutomationMineEnabled',true);v:update(.1,1000)
assert(not v.pool[1].Enabled and v.fields[field].Enabled and v.fields[field].Adornee==floor,'upgrade must switch the same hover to field scope')
for _,node in ipairs(fx:GetDescendants()) do assert(not node:IsA('BillboardGui'),'command feedback should not add floating text') end
v:destroy();assert(v.fields[field]._destroyed and v.pool[1]._destroyed,'highlights must be cleaned')
print('PASS current command highlight scope and cleanup (API doubles)')
