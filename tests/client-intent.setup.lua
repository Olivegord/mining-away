-- Host doubles for extracted production client routing; not native input or network.
local listeners={};local UIS={InputBegan='input'}
function UIS:GetFocusedTextBox() return nil end
local function connect(signal,fn) listeners[signal]=fn end
local enumKeys={'Escape','T','Return','KeypadEnter','One','Two','Three','Four','Five','R','Q','E'}
local Enum={KeyCode={},UserInputType={MouseButton1='mouse',Keyboard='keyboard'}}
for _,k in ipairs(enumKeys) do Enum.KeyCode[k]=k end
local task={};local delayed={};function task.delay(_,fn) table.insert(delayed,fn) end
local workspace={};local player={UserId=7}
local mouse={};function player:GetMouse() return mouse end
local selectedDrone,selectedResource,assignmentPending,cancelRequest,cancelDesired,fieldPending=nil,nil,nil,nil,false,nil
local assignmentAcknowledgedUntil=0
local marker={};local selectionDock={};local selectionTitle={};local nextTarget={};local assignTarget={};local cancelTarget={}
local function clearSelectionVisuals() marker.Enabled=false;marker.Adornee=nil;selectedResource=nil end
local notice={Text=''};local noticeUntil=0;local modal={Visible=false};local modalMode=nil
local offerActions={};local offerConfirmAction=nil;local contextAction=nil;local requestRecall,beginDroneSelection
local function cycleCandidate() end;local function submitCandidate() end;local function cancelSelection() end
local function updateSelectedResource() end;local function openFleet() end
local resources={};local calls={};local command={}
function command:FireServer(action,payload) table.insert(calls,{action=action,payload=payload}) end
local serial=0;local function tx() serial+=1;return 'req-'..serial end
local field={Name='Quartz'}
function field:GetAttribute(k) if k=='FieldId' then return 1 elseif k=='DisplayName' then return 'Landing Quartz' end end
local folder={};function folder:GetChildren() return {field} end
local world={};function world:FindFirstChild(k) if k=='Fields' then return folder end end
local currentReceipt={};local gui={Parent={}}
function gui.Parent:GetAttributeChangedSignal(_) return 'receipt' end
function gui.Parent:GetAttribute(_) return 'json' end
local Http={};function Http:JSONDecode(_) return currentReceipt end
