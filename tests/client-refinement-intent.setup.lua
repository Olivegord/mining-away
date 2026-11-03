local player=player(7)
local world=Instance.new('Folder');world.Parent=workspace
local fields=Instance.new('Folder');fields.Name='Fields';fields.Parent=world
local field=Instance.new('Model');field.Name='Quartz';field:SetAttribute('FieldId',1);field:SetAttribute('Phase','Safe');field.Parent=fields
local resource=Instance.new('Part');resource:SetAttribute('ResourceId','rock');resource:SetAttribute('FieldId',1);resource.Parent=field
local profile={run={id='run'}}
local function fieldUnlocked() return true end
local function availableAutomaticWorker() return true end
local modal={Visible=false};local notice={Text=''};local noticeUntil=0
local logisticsView={selected=nil,dispatchField=function() return false end,isOpen=function() return false end}
local function menusVisible() return modal.Visible or logisticsView:isOpen() end
local command={calls={}}
function command:FireServer(action,payload) table.insert(self.calls,{action=action,payload=payload}) end
local commandView={calls={}}
function commandView:request(id) table.insert(self.calls,id) end
local function openFleet() error('Unexpected fleet open') end
local options={hidden=function() return false end,profile=function() return profile end,command=command}
local function enabled() return true end
local function nearestField() return 1 end
local state={runId='run'};local lastSend=0
