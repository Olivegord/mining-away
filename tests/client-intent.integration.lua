local cases=0
local function check(name,fn) fn();cases+=1;print('PASS client field intent '..name) end
local node={Parent=workspace};function node:GetAttribute(k) if k=='FieldId' then return 1 end end
local function input(key,kind)
 listeners.input({KeyCode=key,UserInputType=kind or Enum.UserInputType.Keyboard},false)
end
local function reply(r) currentReceipt=r;listeners.receipt() end
local function latest() return calls[#calls] end
check('mouse sends production bounded field payload and shows named pending',function()
 mouse.Target=node;input('Unknown',Enum.UserInputType.MouseButton1)
 assert(latest().action=='Patch' and latest().payload.fieldId==1 and latest().payload.requestId=='req-1')
 assert(string.find(notice.Text,'Landing Quartz',1,true))
 reply({requestId='req-1',status='accepted',fieldId=1,reason='Fleet assigned'})
 assert(fieldPending==nil and string.find(notice.Text,'Landing Quartz',1,true) and string.find(notice.Text,'Fleet assigned',1,true))
end)
check('hotkey routes same payload and reports server range rejection',function()
 input('One');assert(latest().action=='Patch' and latest().payload.fieldId==1 and latest().payload.requestId=='req-2')
 reply({requestId='req-2',status='rejected',reason='Too far from field'})
 assert(fieldPending==nil and string.find(notice.Text,'Too far from field',1,true))
end)
check('context E invokes same field dispatch',function()
 contextSelect(1);input('E') -- actual keyboard handler and production contextual closure
 assert(latest().action=='Patch' and latest().payload.fieldId==1 and latest().payload.requestId=='req-3')
 reply({requestId='req-3',status='accepted',fieldId=1})
end)
check('uncertain timeout holds selection and same-field retry uses fresh id',function()
 requestField(1);local old=latest().payload.requestId;delayed[#delayed]()
 assert(fieldPending and fieldPending.timedOut)
 beginDroneSelection({id='unit'});assert(selectedDrone==nil,'cannot overlap field and individual requests')
 requestField(2);assert(latest().payload.requestId==old)
 requestField(1);local new=latest().payload.requestId;assert(new~=old)
 reply({requestId=old,status='accepted',fieldId=1});assert(fieldPending.id==new)
 reply({requestId=new,status='accepted',fieldId=1});assert(fieldPending==nil)
end)
check('recall replaces pending intent and stale field reply cannot hide recall',function()
 requestField(1);local old=latest().payload.requestId;requestRecall();local recallId=latest().payload.requestId
 assert(latest().action=='Recall' and recallId~=old)
 reply({requestId=old,status='accepted',fieldId=1});assert(fieldPending.id==recallId)
 reply({requestId=recallId,status='recalled',reason='Fleet recalled'});assert(fieldPending==nil and notice.Text=='Fleet recalled')
end)
check('target selection suppresses hidden E and field shortcuts',function()
 selectedDrone={id='drone'};local count=#calls
 input('E');input('One');assert(#calls==count)
 selectedDrone=nil
end)
print(cases..' extracted production client intent checks (command/GUI API doubles; not Studio/network)')
