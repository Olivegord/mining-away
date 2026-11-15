-- Native Edit component check. Bundle Mining, RockModifierView and SelectorView
-- with Workshop.selectorWidth returning 30 and BeamVFX.reduced returning false.
local root=Instance.new('Folder');root.Name='TemporarySelectorChecks';root.Parent=workspace
local map=Instance.new('Folder');map.Name='Map';map.Parent=root
local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=map
local zone=Instance.new('Folder');zone.Parent=run
local fx=Instance.new('Folder');fx.Parent=root
local player=Instance.new('Folder')
local character=Instance.new('Model');character.Name='Character';character.Parent=player
local center=Vector3.new(0,400,0)
local function part(parent,name,size,position,solid)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=solid
 p.CanQuery=true;p.Size=size;p.Position=position;p.Parent=parent
 return p
end
part(character,'HumanoidRootPart',Vector3.one,center+Vector3.new(0,3,0),false)
local bed=part(zone,'Field',Vector3.new(216,1,64),center-Vector3.yAxis*.5,true)
bed:SetAttribute('FieldId',1)
local rock=part(zone,'Rock',Vector3.new(4,4,4),center+Vector3.new(0,2,30),true)
rock:SetAttribute('ResourceId','test');rock:SetAttribute('FieldId',1)
rock:SetAttribute('FullPosition',rock.Position)
local cosmetic=part(root,'Cosmetic',Vector3.new(4,1,4),center+Vector3.new(0,11,12),false)
local sent
local view=SelectorView.new({parent=fx,world=root,player=player,profile=function() return {run={id='test'}} end,
 command={FireServer=function(_,action,payload) assert(action=='PlaceSelector');sent=payload end},
 hidden=function() return false end,reducedMotion=function() return false end})
local camera=workspace.CurrentCamera;local before=camera.CFrame
local report={}
local ok,err=xpcall(function()
 local ray={Origin=cosmetic.Position+Vector3.yAxis*10,Direction=-Vector3.yAxis}
 local hovered,id=view:aim(ray)
 assert(hovered==center+Vector3.zAxis*12 and id==1,'non-solid cosmetic swallowed a field hit')
 local blocker=part(root,'Blocker',Vector3.new(4,1,4),cosmetic.Position+Vector3.yAxis*2,true)
 assert(not view:aim(ray),'aim ray ignored a solid wall')
 blocker:Destroy()
 local shallow={Origin=center+Vector3.new(0,8,0),Direction=Vector3.new(0,-5,30).Unit}
 local point,field,lead,inRange=view:aim(shallow)
 assert(point==center+Vector3.zAxis*30 and field==1 and lead=='test' and inRange,'shallow rock hit lost the bed')
 player:SetAttribute('MA_Selector',center)
 camera.CFrame=CFrame.new(center+Vector3.yAxis*15)
 view:showAim(.08,ray)
 local side=view.pinned.sides[1]
 local peak=side.opacity;local startHeight=side.part.Size.Y
 view:showAim(.05,ray)
 assert(side.opacity==peak and side.part.Size.Y>3.7 and startHeight<2,'wall did not rise sharply and hold its flash')
 assert(side.edge.Size.X==30 and side.sparks.Lifetime.Max>=1.2 and view.pinned.emitted,'edge burst did not arm')
 view:showAim(.22,ray);local early=side.opacity
 view:showAim(.22,ray);local late=side.opacity
 view:showAim(.44,ray);local idle=side.opacity
 assert(math.abs(side.part.Size.Y-20/3)<.001,'wall height was not reduced by one third')
 assert(peak>.9 and early>late and late>idle and idle>=.32,'wall lost its brightness floor')
 assert(view.pinned.point==center and view.aimEdge.point==hovered and not view.flash.gui.Enabled,'aim moved the pin or painted its floor')
 assert(view:commit(shallow) and sent.fieldId==1 and sent.position==point and sent.requestId)
 local click,strength=view:flashState()
 view:showAim(.016,shallow)
 assert(view.flash.gui.Enabled and view.pinned.point==center,'click did not flash or prematurely moved the pin')
 local rendered=rock:Clone();rendered.Parent=fx
 rendered.Color=Color3.fromRGB(81,76,72);local stone=rendered.Color
 local neighbor=rock:Clone();neighbor.Position+=Vector3.xAxis*20;neighbor:SetAttribute('FullPosition',neighbor.Position);neighbor.Parent=zone
 local neighborView=neighbor:Clone();neighborView.Parent=fx
 local records={
  {source=rock,view=rendered,baseColor=rock.Color,visual={}},
  {source=neighbor,view=neighborView,baseColor=neighbor.Color,visual={},lastBeamAt=100},
 }
 RockModifierView.attackOutlines(records,nil,100,false,click,strength)
 assert(rendered.Color.R>.9 and rendered.Color.G>.9 and not records[1].rockOutline,'chosen rock did not flash white without a Highlight')
 assert(records[2].rockOutline.FillTransparency==1 and records[2].rockOutline.OutlineTransparency<.1,'rock outside the zone lost its attack outline')
 records[1].lastBeamAt=100
 RockModifierView.clearSelectionFlash(records[1])
 RockModifierView.attackOutlines(records,nil,100.3,false)
 assert(rendered.Color==stone and records[1].rockOutline.FillTransparency==1 and records[1].rockOutline.OutlineTransparency<1,'selection failed to restore the rock or interrupted its attack outline')
 player:SetAttribute('MA_Selector',point)
 view:showAim(.016,shallow)
 assert(view.pinned.point==point and view.activeEdge.point==point,'accepted pin did not move')
 report={nearWallFloor=idle,peak=peak,edgeLifetime=side.sparks.Lifetime.Max,clickFlash=strength}
end,debug.traceback)
camera.CFrame=before;view:destroy();root:Destroy();player:Destroy();assert(ok,err)
return report
