-- The same world gesture grows from one rock to an entire field as automation
-- is earned. Color and outlines carry feedback without floating instructions.
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local BLUE=Color3.fromRGB(135,218,255)
local GOLD=Color3.fromRGB(255,201,100)
local GREEN=Color3.fromRGB(136,235,163)
local RED=Color3.fromRGB(233,134,120)
function V.new(ctx)
 local self=setmetatable({ctx=ctx,pool={},pending={},queued={},queueJSON='',clock=0},V)
 self.fields={};return self
end
function V:request(id)
 local profile=self.ctx.profile();if not profile or not profile.run then return end
 local at=os.clock();if self.pending[id] and at-self.pending[id].at<1 then return end
 local request=Http:GenerateGUID(false);self.pending[id]={at=at,request=request}
 self.ctx.command:FireServer('MineOre',{requestId=request,runId=profile.run.id,resourceId=id,toggle=true})
end
function V:reply(state)
 for id,pending in pairs(self.pending) do if pending.request==state.requestId then self.pending[id]=nil end end
 if state.resourceId then self.flash={id=state.resourceId,at=os.clock(),color=state.status=='accepted' and GREEN or state.status=='queued' and GOLD or RED} end
 if state.droneId and state.status=='accepted' then
  for source,d in pairs(self.ctx.drones) do if source:GetAttribute('DroneId')==state.droneId then
   if not self.worker then
    self.worker=Instance.new('Highlight');self.worker.Name='DispatchedWorker';self.worker.DepthMode=Enum.HighlightDepthMode.Occluded
    self.worker.FillColor=GREEN;self.worker.OutlineColor=GREEN;self.worker.FillTransparency=.88;self.worker.Parent=self.ctx.parent
   end
   self.worker.Adornee=d.view;self.workerUntil=os.clock()+1;break
  end end
 end
end
function V:update(dt,now)
 self.clock+=dt;if self.clock<.06 then return end;self.clock=0
 local ctx=self.ctx;local player=Players.LocalPlayer;local visible=not ctx.hidden()
 local queuedJSON=player:GetAttribute('QueuedOreIds') or '[]'
 if queuedJSON~=self.queueJSON then
  self.queueJSON=queuedJSON;self.queued={}
  local ok,list=pcall(Http.JSONDecode,Http,queuedJSON)
  if ok and type(list)=='table' then for index,id in ipairs(list) do self.queued[id]=index end end
 end
 local working={}
 for source in pairs(ctx.drones) do
  if source:GetAttribute('Owner')==player.UserId and (source:GetAttribute('HP') or 0)>0 then
   local id=source:GetAttribute('TargetId');if id and id~='' then working[id]=true end
  end
 end
 local automatic=player:GetAttribute('AutomationMineEnabled')==true
 local hover,hoverField=nil,nil;local camera=workspace.CurrentCamera
 if visible and camera and not UIS:GetFocusedTextBox() then
  local pointer=UIS:GetMouseLocation()
  local ray
  if UIS.GamepadEnabled and UIS:GetLastInputType()==Enum.UserInputType.Gamepad1 then
   ray=camera:ViewportPointToRay(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
  elseif UIS.MouseEnabled and not ctx.blocks(pointer) then ray=camera:ScreenPointToRay(pointer.X,pointer.Y) end
  if ray then
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={ctx.parent,player.Character}
   local hit=workspace:Raycast(ray.Origin,ray.Direction*240,params)
   if hit then
    local node=hit.Instance
    while node and node~=workspace do
     hover=hover or node:GetAttribute('ResourceId')
     hoverField=hoverField or node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier')
     node=node.Parent
    end
   end
  end
 end
 local fields=ctx.world and ctx.world:FindFirstChild('Fields')
 local assigned={}
 if automatic then
  for source in pairs(ctx.drones) do
   if source:GetAttribute('Owner')==player.UserId and (source:GetAttribute('HP') or 0)>0 then
    local id=source:GetAttribute('AutoFieldId');if id and id>0 then assigned[id]=true end
   end
  end
 end
 if fields then for _,field in ipairs(fields:GetChildren()) do
  local id=field:GetAttribute('FieldId') or field:GetAttribute('Tier')
  local floor=field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor')
  if floor and floor:IsA('BasePart') then
   local h=self.fields[field]
   if not h then
    h=Instance.new('Highlight');h.Name='FieldOrder';h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Adornee=floor;h.Parent=ctx.parent;self.fields[field]=h
   end
   h.Enabled=visible and automatic and (hoverField==id or assigned[id]==true)
   local color=assigned[id] and GREEN or BLUE
   h.FillColor=color;h.OutlineColor=color;h.FillTransparency=hoverField==id and .91 or .97;h.OutlineTransparency=hoverField==id and .02 or .38
  end
 end end
 for field,h in pairs(self.fields) do if not field.Parent then h:Destroy();self.fields[field]=nil end end
 local marked={};local records=ctx.resources
 if hover and records[hover] then table.insert(marked,hover) end
 for id in pairs(self.queued) do if id~=hover then table.insert(marked,id) end end
 for id in pairs(working) do if id~=hover and not self.queued[id] then table.insert(marked,id) end end
 for id,pending in pairs(self.pending) do
  if os.clock()-pending.at>3 then self.pending[id]=nil
  elseif id~=hover and not self.queued[id] and not working[id] then table.insert(marked,id) end
 end
 local flash=self.flash
 if flash and os.clock()-flash.at<.8 and flash.id~=hover and not working[flash.id] and not self.queued[flash.id] and not self.pending[flash.id] then table.insert(marked,flash.id) end
 if self.worker then self.worker.Enabled=visible and os.clock()<(self.workerUntil or 0) end
 local used=0
 for _,id in ipairs(marked) do
  local r=records[id]
  if visible and not automatic and r and r.view.Parent and (r.source:GetAttribute('HP') or 0)>0 and used<24 then
   used+=1
   local h=self.pool[used]
   if not h then
    h=Instance.new('Highlight');h.Name='RockOrder';h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=ctx.parent;self.pool[used]=h
   end
   local growing=now<(r.source:GetAttribute('ReadyAt') or 0)
   local busy=(r.source:GetAttribute('SlotsUsed') or 0)>=(r.source:GetAttribute('SlotCapacity') or 1)
   local color=working[id] and GREEN or self.queued[id] and GOLD or (growing or busy) and RED or BLUE
   local pulse=flash and flash.id==id and math.clamp(1-(os.clock()-flash.at)/.8,0,1) or 0
   if pulse>0 then color=flash.color end
   h.Adornee=r.view;h.Enabled=true;h.FillColor=color;h.OutlineColor=color
   h.FillTransparency=(id==hover and .86 or .95)-pulse*.2;h.OutlineTransparency=id==hover and .05 or .3

  end
 end
 for index=used+1,#self.pool do self.pool[index].Enabled=false end
end
function V:destroy()
 if self.worker then self.worker:Destroy() end;for _,h in ipairs(self.pool) do h:Destroy() end
 for _,h in pairs(self.fields) do h:Destroy() end
end
return V
