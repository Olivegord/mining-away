local checks=0
local function check(name,fn) fn();checks+=1;print('PASS refinement intent '..name) end
check('one rock gesture naturally targets the field after automation unlock',function()
 assignField(resource);assert(#commandView.calls==1 and commandView.calls[1]=='rock' and #command.calls==0)
 player:SetAttribute('AutomationMineEnabled',true);assignField(resource)
 assert(#commandView.calls==1 and #command.calls==1 and command.calls[1].action=='Patch' and command.calls[1].payload==1)
 assert(notice.Text=='','upgrade should not create a mode instruction')
end)
check('locked background field click stays quiet and sends no impossible order',function()
 player:SetAttribute('AutomationMineEnabled',false);local before=#command.calls;requestPlot(1)
 assert(#command.calls==before and notice.Text=='')
end)
check('ability starts once and never sends a timed confirmation',function()
 activate('Orbital');local call=command.calls[#command.calls]
 assert(call.action=='MiningAbility' and call.payload.op=='begin' and call.payload.kind=='Orbital' and call.payload.token==nil)
 local before=#command.calls;realTime+=.2;state.charge={kind='Orbital',token='ignored'};activate('Orbital')
 assert(#command.calls==before,'charge should release on server, without second input')
end)
print(checks..' current client command cases (API doubles)')
