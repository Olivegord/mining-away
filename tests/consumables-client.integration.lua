local pl=player(44);players.LocalPlayer=pl
local world=Instance.new('Folder');world.Parent=workspace
local fields=Instance.new('Folder');fields.Name='Fields';fields.Parent=world
local field=Instance.new('Model');field.Name='Quartz';field:SetAttribute('FieldId',1);field.Parent=fields
local floor=Instance.new('Part');floor.Name='Field';floor.Size=Vector3.new(50,1,50);floor.Position=Vector3.zero;floor.Parent=field
pl.Character:PivotTo(CFrame.new(0,3,0))
local profile={run={id='run',shops={Quartz=true}},consumables=Consumables.fresh()}
profile.consumables.counts.Orbital=2;profile.consumables.counts.Scrap=1;profile.consumables.collected=3
local sent={};local cursor=Vector3.new(0,1,0);local mode=''
workspace.CurrentCamera={ViewportSize=Vector2.new(1280,720),
 ScreenPointToRay=function() mode='pointer';return {Origin=Vector3.new(0,30,0),Direction=Vector3.new(0,-1,0)} end,
 ViewportPointToRay=function() mode='center';return {Origin=Vector3.new(0,30,0),Direction=Vector3.new(0,-1,0)} end}
workspace.Raycast=function(_,_,_,params)
 return {Instance=floor,Position=params.FilterType==Enum.RaycastFilterType.Include and Vector3.new(cursor.X,.5,cursor.Z) or cursor}
end
local rock=Instance.new('Part');rock.Position=Vector3.new(2,2,0);rock.Parent=field
rock:SetAttribute('FieldId',1);rock:SetAttribute('ResourceId','rock');rock:SetAttribute('HP',100);rock:SetAttribute('ReadyAt',0)
local self=setmetatable({ctx={profile=function() return profile end,hidden=function() return false end,
 world=world,localFX=Instance.new('Folder'),resources={rock={source=rock,view=rock}},
 command={FireServer=function(_,action,payload) table.insert(sent,{action=action,payload=payload}) end}},
 ghost=Instance.new('Part'),area=Instance.new('Part'),mark=Instance.new('Highlight')},{__index=ConsumableView})
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS equipment input '..name) end
check('selection previews a real radius and nearest rock without spending',function()
 self:select('Orbital');self:aim(Vector2.new(10,10),false)
 assert(self.candidate and #sent==0 and self.mark.Adornee==rock and self.area.Size.Y==24)
 assert(self.ghost.Position.Y==.74 and profile.consumables.counts.Orbital==2)
end)
check('mouse placement emits one versioned intent and consumes the mining click',function()
 assert(self:click(Vector2.new(10,10),false));assert(#sent==1 and not self:isSelecting())
 local request=sent[1];assert(request.action=='PlaceConsumable' and request.payload.kind=='Orbital' and request.payload.fieldId==1)
 assert(request.payload.version==profile.consumables.version and request.payload.runId=='run' and request.payload.x==0 and request.payload.z==0)
 assert(not self:click(Vector2.new(10,10),false) and #sent==1 and profile.consumables.counts.Orbital==2)
end)
check('touch aims first and only the explicit Place action submits',function()
 self:select('Scrap');assert(self:click(Vector2.new(5,5),true));assert(#sent==1 and self:isSelecting())
 self:place();assert(#sent==2 and sent[2].payload.kind=='Scrap' and not self:isSelecting())
end)
check('cancel and invalid or locked ground spend nothing',function()
 self:select('Orbital');assert(self:input({KeyCode=Enum.KeyCode.Escape},false));assert(not self:isSelecting() and #sent==2)
 self:select('Orbital');cursor=Vector3.new(70,1,0);assert(self:click(Vector2.new(5,5),false));assert(not self.candidate and #sent==2)
 cursor=Vector3.new(0,1,0);profile.run.shops.Quartz=false;self:click(Vector2.new(5,5),false);assert(#sent==2)
 profile.run.shops.Quartz=true;self:select(nil)
end)
check('controller selects a pocket and places using the center aim ray',function()
 assert(self:input({KeyCode=Enum.KeyCode.DPadLeft},false));assert(self:isSelecting())
 assert(self:input({KeyCode=Enum.KeyCode.ButtonR1},false));assert(mode=='center' and #sent==3 and not self:isSelecting())
end)
check('saving and empty stock prevent selection or deployment',function()
 profile.pendingTransaction=true;self:select('Orbital');assert(not self:isSelecting())
 profile.pendingTransaction=false;profile.consumables.counts.Orbital=0;self:select('Orbital');assert(not self:isSelecting())
 assert(not self:input({KeyCode=Enum.KeyCode.X},true) and #sent==3)
end)
check('preview excludes foreign reservations and uncleared guards but retains owned work',function()
 profile.consumables.counts.Orbital=1;self:select('Orbital')
 local drones=Instance.new('Folder');drones.Name='Drones';drones.Parent=world
 local worker=Instance.new('Model');worker.Parent=drones
 worker:SetAttribute('HP',100);worker:SetAttribute('Owner',45);worker:SetAttribute('TargetId','rock')
 self:aim(Vector2.new(0,0),false);assert(not self.candidate and not self.mark.Enabled)
 worker:SetAttribute('Owner',44);self:aim(Vector2.new(0,0),false);assert(self.candidate)
 field:SetAttribute('Phase','Guarded');self:aim(Vector2.new(0,0),false);assert(not self.candidate)
 profile.clearedFields={Quartz=true};self:aim(Vector2.new(0,0),false);assert(self.candidate)
 self:select(nil);assert(#sent==3)
end)
print(checks..' production placement/input checks with API doubles; not engine UI or touch/controller device testing')
