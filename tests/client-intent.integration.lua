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
check('pending assignment locks crystal highlight for world taps and Next',function()
 local r1={Parent=workspace};function r1:GetAttribute(k) if k=='ResourceId' then return 'r1' end end
 local r2={Parent=workspace};function r2:GetAttribute(k) if k=='ResourceId' then return 'r2' end end
 resources[r1]={view=r1};resources[r2]={view=r2};selectedDrone={id='drone',name='Mica'}
 selectedResource=r1;marker.Adornee=r1;marker.Enabled=true;selectionTitle.Text='Assigning…';assignmentPending='pending-1'
 local count=#calls;mouse.Target=r2;input('Unknown',Enum.UserInputType.MouseButton1)
 assert(selectedResource==r1 and marker.Adornee==r1 and marker.Enabled and selectionTitle.Text=='Assigning…','world tap changed pending target or status')
 input('T')
 assert(selectedResource==r1 and marker.Adornee==r1 and marker.Enabled and selectionTitle.Text=='Assigning…','Next changed pending target or status')
 assert(#calls==count,'pending input sent another command')
 local beforeCancel=cancelCalls;input('Escape');assert(cancelCalls==beforeCancel+1,'pending selection must still permit Cancel')
 assignmentPending=nil;mouse.Target=r2;input('Unknown',Enum.UserInputType.MouseButton1)
 assert(selectedResource==r2 and marker.Adornee==r2,'target must be selectable after resolution')
 selectedDrone=nil;selectedResource=nil;resources[r1]=nil;resources[r2]=nil
end)
print(cases..' extracted production client intent checks (command/GUI API doubles; not Studio/network)')
