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
local sent,requests=nil,0
local view=SelectorView.new({parent=fx,world=root,player=player,profile=function() return {run={id='test'}} end,
 command={FireServer=function(_,action,payload) assert(action=='PlaceSelector');sent=payload;requests+=1 end},
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
 player:SetAttribute('MA_SelectorField',1)
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
 assert(view.pinned.point==center and view.activeFloor.width==30 and view.activeFloor.gui.Enabled,'pin did not fill the entire base')
 assert(view.aimCursor.goal==hovered and not view.previewFloor.gui.Enabled and not view.flash.gui.Enabled,'hover was not cursor-only')
 local nearRay={Origin=ray.Origin+Vector3.xAxis*2.4,Direction=ray.Direction}
 view:showAim(.04,nearRay);view:showAim(.04,nearRay)
 assert(view.aimCursor.goal==hovered+Vector3.xAxis*2 and view.aimCursor.position~=view.aimCursor.goal,'stud snap did not ease toward the grid')
 view:showAim(.16,nearRay)
 assert(view.aimCursor.position==view.aimCursor.goal,'cursor did not settle at the snapped point')
 assert(view:commit(ray) and view:commit(shallow) and requests==0,'first click or click outside the preview submitted an order')
 view:showAim(.04,nil)
 local earlyWidth=view.previewFloor.width
 assert(earlyWidth>1 and earlyWidth<30 and not view.aimCursor.gui.Enabled,'first click did not expand from the frozen cursor')
 view:showAim(.26,nil)
 local draft,width,previewStrength=view:previewState()
 assert(draft.point==point and width==30 and view.previewFloor.width==30 and view.previewEdge.point==point,
  'moving away changed the preview or prevented full expansion')
 assert(view.pinned.point==center and not view.flash.gui.Enabled,'preview moved the pin or flashed the walls')
 local rendered=rock:Clone();rendered.Parent=fx
 rendered.Color=Color3.fromRGB(81,76,72);local stone=rendered.Color
 local neighbor=rock:Clone();neighbor.Position+=Vector3.xAxis*20;neighbor:SetAttribute('FullPosition',neighbor.Position);neighbor.Parent=zone
 local neighborView=neighbor:Clone();neighborView.Parent=fx
 local records={
  {source=rock,view=rendered,baseColor=rock.Color,visual={}},
  {source=neighbor,view=neighborView,baseColor=neighbor.Color,visual={},lastBeamAt=100},
 }
 RockModifierView.attackOutlines(records,nil,100,false,draft,previewStrength,width)
 local previewRed=rendered.Color.R
 assert(previewRed>stone.R and neighborView.Color==neighbor.Color,'preview tint missed the footprint boundary')
 assert(records[2].rockOutline.FillTransparency==1 and records[2].rockOutline.OutlineTransparency<.1,'rock outside the zone lost its attack outline')
 local confirmRay={Origin=point+Vector3.new(4,30,0),Direction=-Vector3.yAxis}
 assert(view:commit(confirmRay) and sent.fieldId==1 and sent.position==point and sent.requestId and requests==1,
  'second click moved the draft or did not send one command')
 assert(view:commit(confirmRay) and requests==1 and not view:flashState(),'pending placement retriggered the command or flash')
 assert(view:reply({requestId=sent.requestId,status='rejected'}) and view.draft==draft and not view:flashState(),'reject discarded or flashed the preview')
 assert(view:commit(confirmRay) and requests==2 and view:reply({requestId=sent.requestId,status='accepted'}),'retry did not confirm')
 player:SetAttribute('MA_Selector',point)
 view:showAim(.08,nil)
 local click,strength=view:flashState()
 assert(view.flash.gui.Enabled and view.pinned.point==point and view.pinned.emitted and not view.previewFloor.gui.Enabled,
  'accepted placement did not open the walls, emit sparks and swap the preview for the wash')
 RockModifierView.clearSelectionFlash(records[1])
 RockModifierView.attackOutlines(records,nil,100,false,click,strength)
 assert(rendered.Color.R>previewRed and not records[1].rockOutline,'confirmation did not brighten the preview rock')
 click.at-=.5
 view:showAim(.5,nil)
 assert(not view.flash.gui.Enabled and view.activeFloor.gui.Enabled,'fading the wash removed the footprint')
 records[1].lastBeamAt=100
 RockModifierView.clearSelectionFlash(records[1])
 RockModifierView.attackOutlines(records,nil,100.3,false)
 assert(rendered.Color==stone and records[1].rockOutline.FillTransparency==1 and records[1].rockOutline.OutlineTransparency<1,'selection failed to restore the rock or interrupted its attack outline')
 assert(view:commit(ray) and view:cancelPreview() and requests==2 and not view:previewState(),'cancelling a draft sent a command')
 report={nearWallFloor=idle,peak=peak,edgeLifetime=side.sparks.Lifetime.Max,previewStrength=previewStrength,clickFlash=strength}
end,debug.traceback)
camera.CFrame=before;view:destroy();root:Destroy();player:Destroy();assert(ok,err)
return report
