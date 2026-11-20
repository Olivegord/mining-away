-- Two compact equipment pockets. Selection only aims; the server validates and
-- saves every deployment. The reticle previews area and never deals damage.
local V={};V.__index=V
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local RunService=game:GetService('RunService')
function V.start(ctx)
 local self=setmetatable({ctx=ctx,selected=nil,candidate=nil,scan=0},V)
 local U=ctx.interface;local player=Players.LocalPlayer
 self.panel=U.panel(ctx.parent,UDim2.fromOffset(0,100),UDim2.fromOffset(270,76),U.palette.panel,10)
 self.panel.Name='BackpackTools';self.panel.Active=true
 local title=U.text(self.panel,UDim2.fromOffset(10,3),UDim2.new(1,-20,0,21),'TOOLS · stored separately from ore',14,U.palette.muted,true)
 self.title=title;self.buttons={}
 for index,kind in ipairs(Consumables.ORDER) do
  local item=Consumables.ITEMS[kind]
  local b=U.button(self.panel,UDim2.fromOffset(8+(index-1)*129,26),UDim2.fromOffset(125,44),item.short,function() self:select(kind) end,Color3.fromRGB(table.unpack(item.color)))
  b.Name=kind..'Pocket';b.TextSize=16;self.buttons[kind]=b
 end
 self.detail=U.text(self.panel,UDim2.fromOffset(10,76),UDim2.new(1,-20,0,44),'',16,U.palette.text)
 self.detail.TextWrapped=true
 self.deploy=U.button(self.panel,UDim2.fromOffset(8,124),UDim2.fromOffset(166,40),'Place tool',function() self:place() end,U.palette.accent)
 self.cancel=U.button(self.panel,UDim2.fromOffset(180,124),UDim2.fromOffset(82,40),'Cancel',function() self:select(nil) end,U.palette.paper)
 local ghost=Instance.new('Part');ghost.Name='ToolPlacement';ghost.Size=Vector3.new(1.3,.45,1.3);ghost.Anchored=true
 ghost.CanCollide=false;ghost.CanQuery=false;ghost.CanTouch=false;ghost.Material=Enum.Material.Metal;ghost.CastShadow=false;ghost.Transparency=1;ghost.Parent=ctx.localFX;self.ghost=ghost
 local area=Instance.new('Part');area.Name='ToolReach';area.Shape=Enum.PartType.Cylinder;area.Anchored=true
 area.CanCollide=false;area.CanQuery=false;area.CanTouch=false;area.CastShadow=false;area.Material=Enum.Material.Neon;area.Transparency=1;area.Parent=ctx.localFX;self.area=area
 local mark=Instance.new('Highlight');mark.Name='ToolTarget';mark.DepthMode=Enum.HighlightDepthMode.Occluded;mark.FillTransparency=.85;mark.OutlineTransparency=.1;mark.Enabled=false;mark.Parent=ctx.localFX;self.mark=mark
 self.connection=RunService.RenderStepped:Connect(function(dt) self:step(dt,player) end)
 return self
end
function V:select(kind)
 local p=self.ctx.profile()
 if kind then
  if self.ctx.hidden() or not p or not p.consumables or p.pendingTransaction or (p.consumables.counts[kind] or 0)<1
   or Players.LocalPlayer:GetAttribute('MA_ConsumableActive') then return end
  if self.selected==kind then kind=nil end
 end
 self.selected=kind;self.candidate=nil;self.mark.Enabled=false
 if kind and self.ctx.onSelect then self.ctx.onSelect() end
 if not kind then self.ghost.Transparency=1;self.area.Transparency=1 end
end
function V:isSelecting() return self.selected~=nil end
function V:aim(screen,center)
 if not self.selected then return end
 self.candidate=nil;self.mark.Enabled=false;self.ghost.Transparency=1;self.area.Transparency=1
 local camera=workspace.CurrentCamera;if not camera then return end
 local player=Players.LocalPlayer;local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 if not hr then return end
 local ray=center and camera:ViewportPointToRay(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5) or camera:ScreenPointToRay(screen.X,screen.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.ctx.localFX,player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*240,params);if not hit then return end
 local fields=self.ctx.world:FindFirstChild('Fields');if not fields then return end
 local fieldId,floor,fieldModel
 for _,field in ipairs(fields:GetChildren()) do
  local part=field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor')
  if part and part:IsA('BasePart') then
   local point=part.CFrame:PointToObjectSpace(hit.Position)
   if math.abs(point.X)<=part.Size.X*.5 and math.abs(point.Z)<=part.Size.Z*.5 and math.abs(point.Y)<32 then
    fieldId=field:GetAttribute('FieldId') or field:GetAttribute('Tier');floor=part;fieldModel=field;break
   end
  end
 end
 if not fieldId or not floor then return end
 local point=floor.CFrame:PointToObjectSpace(hit.Position)
 local ground=floor.CFrame:PointToWorldSpace(Vector3.new(point.X,floor.Size.Y*.5,point.Z))
 params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={floor,workspace.Terrain}
 local surface=workspace:Raycast(ground+Vector3.new(0,40,0),Vector3.new(0,-80,0),params);if surface then ground=surface.Position end
 local item=Consumables.ITEMS[self.selected];local profile=self.ctx.profile();local nearest,best,count=nil,math.huge,0
 local foreign={};local drones=self.ctx.world:FindFirstChild('Drones')
 if drones then for _,drone in ipairs(drones:GetChildren()) do
  local id=drone:GetAttribute('TargetId')
  if id and id~='' and drone:GetAttribute('Owner')~=player.UserId and (drone:GetAttribute('HP') or 0)>0 then foreign[id]=true end
 end end
 for _,r in pairs(self.ctx.resources) do
  local source=r.source;local pos=source:GetAttribute('FullPosition') or source.Position
  local delta=pos-ground;local distance=delta.X*delta.X+delta.Z*delta.Z
  if source:GetAttribute('FieldId')==fieldId and not foreign[source:GetAttribute('ResourceId')] and (source:GetAttribute('HP') or 0)>0
   and workspace:GetServerTimeNow()>=(source:GetAttribute('ReadyAt') or 0) and distance<=item.radius*item.radius then
   count+=1;if distance<best then best=distance;nearest=r end
  end
 end
 local unlocked=fieldModel:GetAttribute('AlwaysUnlocked')==true or Shops.unlocked(profile,fieldModel.Name)
 local phase=fieldModel:GetAttribute('Phase')
 local guarded=(phase=='Guarded' or phase=='Active') and not (profile.clearedFields or {})[fieldModel.Name]
 -- Replication can lag. The server repeats every ownership/defense/contact
 -- check before saving and on each actual mining contact.
 local valid=count>0 and unlocked and not guarded and (hr.Position-ground).Magnitude<=60
 local color=valid and Color3.fromRGB(table.unpack(item.color)) or Color3.fromRGB(235,104,96)
 self.ghost.Color=color;self.ghost.Position=ground+Vector3.new(0,.24,0);self.ghost.Transparency=.3
 self.area.Color=color;self.area.Size=Vector3.new(.06,item.radius*2,item.radius*2)
 self.area.CFrame=CFrame.new(ground+Vector3.new(0,.07,0))*CFrame.Angles(0,0,math.pi/2);self.area.Transparency=.94
 if valid then
  self.candidate={fieldId=fieldId,x=ground.X,z=ground.Z,count=count}
  if self.selected=='Orbital' and nearest then self.mark.Adornee=nearest.view;self.mark.FillColor=color;self.mark.OutlineColor=color;self.mark.Enabled=true end
 end
end
function V:place()
 local p=self.ctx.profile();local aim=self.candidate;local kind=self.selected
 if not aim or not kind or not p or not p.run or p.pendingTransaction then return end
 if (p.consumables.counts[kind] or 0)<1 then self:select(nil);return end
 self.ctx.command:FireServer('PlaceConsumable',{kind=kind,runId=p.run.id,version=p.consumables.version,
  txId=Http:GenerateGUID(false),fieldId=aim.fieldId,x=aim.x,z=aim.z})
 self:select(nil)
end
function V:click(screen,touch)
 if not self.selected then return false end
 self:aim(screen,false)
 if not touch then self:place() end
 return true
end
function V:input(input,processed)
 local key=input.KeyCode
 if self.selected and (key==Enum.KeyCode.Escape or key==Enum.KeyCode.ButtonB) then self:select(nil);return true end
 if processed or UIS:GetFocusedTextBox() or self.ctx.hidden() then return false end
 if key==Enum.KeyCode.Z or key==Enum.KeyCode.DPadLeft then self:select('Orbital');return true end
 if key==Enum.KeyCode.X or key==Enum.KeyCode.DPadRight then self:select('Scrap');return true end
 if self.selected and (key==Enum.KeyCode.ButtonR1 or key==Enum.KeyCode.ButtonR2) then self:aim(nil,true);self:place();return true end
 return false
end
function V:step(dt,player)
 self.scan+=dt;if self.scan<.06 then return end;self.scan=0
 local p=self.ctx.profile();local s=p and p.consumables
 local hidden=self.ctx.hidden();local active=player:GetAttribute('MA_ConsumableActive')
 if self.selected and (hidden or not s or (s.counts[self.selected] or 0)<1 or active) then self:select(nil) end
 self.panel.Visible=s~=nil and s.collected>0 and not hidden
 if not self.panel.Visible then return end
 local width=math.min(270,self.ctx.parent.AbsoluteSize.X-24)
 self.panel.Position=UDim2.new(1,-width-12,0,100);self.panel.Size=UDim2.fromOffset(width,self.selected and 172 or 76)
 local buttonWidth=(width-20)/2
 for index,kind in ipairs(Consumables.ORDER) do
  local b=self.buttons[kind];b.Size=UDim2.fromOffset(buttonWidth,44);b.Position=UDim2.fromOffset(8+(index-1)*(buttonWidth+4),26)
  local key=UIS.TouchEnabled and '' or (index==1 and '[Z] ' or '[X] ')
  b.Text=key..Consumables.ITEMS[kind].short..'\n×'..s.counts[kind]
  self.ctx.interface.setEnabled(b,s.counts[kind]>0 and not p.pendingTransaction and not active)
 end
 self.title.Text=active and (Consumables.ITEMS[active] and Consumables.ITEMS[active].name..' working…' or 'Tool working…') or 'TOOLS · 3 charges per pocket'
 local selecting=self.selected~=nil;self.detail.Visible=selecting;self.deploy.Visible=selecting;self.cancel.Visible=selecting
 self.cancel.Position=UDim2.fromOffset(width-90,124);self.deploy.Size=UDim2.fromOffset(width-104,40)
 if selecting then
  local gamepad=UIS:GetLastInputType()==Enum.UserInputType.Gamepad1
  if gamepad then self:aim(nil,true)
  elseif UIS.MouseEnabled and not UIS.TouchEnabled then
   local pointer=UIS:GetMouseLocation()
   if not self.ctx.blocks(pointer) then self:aim(pointer,false) end
  end
  self.detail.Text=self.candidate and (self.selected=='Orbital' and 'Melts the outlined rock in 4 seconds.' or ('Six bots · '..self.candidate.count..' nearby rocks · 10 seconds.'))
   or 'Aim inside an unlocked field near ready rocks.'
  self.ctx.interface.setEnabled(self.deploy,self.candidate~=nil and not p.pendingTransaction)
 end
end
function V:destroy()
 self.connection:Disconnect();self.panel:Destroy();self.ghost:Destroy();self.area:Destroy();self.mark:Destroy()
end
return V
