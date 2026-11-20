-- Edit-only component check. Prepend build.module_bundle(("Mining","Workshop","SelectorView")).
-- Uses actual native raycasting; cleans up its fixture. Does not start Play.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and not game:GetService('RunService'):IsRunning())
local folder=Instance.new('Folder');folder.Name='GeodeFocusCheck';folder.Parent=workspace
local ok,result=xpcall(function()
 local map=Instance.new('Folder');map.Name='Map';map.Parent=folder
 local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=map
 local zone=Instance.new('Folder');zone.Parent=run
 local center=Vector3.new(12000,100,12000)
 local bed=Instance.new('Part');bed.Name='Field';bed.Anchored=true;bed.Size=Vector3.new(216,1,64);bed.Position=center-Vector3.yAxis*.5;bed:SetAttribute('FieldId',1);bed.Parent=zone
 local rock=Instance.new('Part');rock.Shape=Enum.PartType.Ball;rock.Anchored=true;rock.Size=Vector3.one*5;rock.Position=center+Vector3.new(4,2.5,0);rock:SetAttribute('ResourceId','focus-check');rock:SetAttribute('FullPosition',rock.Position);rock.Parent=zone
 local character=Instance.new('Model');character.Parent=folder
 local hr=Instance.new('Part');hr.Name='HumanoidRootPart';hr.Anchored=true;hr.Position=center+Vector3.new(-43,3,0);hr.Parent=character
 local fx=Instance.new('Folder');fx.Parent=folder
 local attributes={MA_Selector=center,MA_SelectorField=1,MA_SelectorWidth=30}
 local player={Character=character,GetAttribute=function(_,key) return attributes[key] end}
 local sent
 local view=SelectorView.new({player=player,world=folder,parent=fx,hidden=function() return false end,
  profile=function()return {run={id='native-check',cards={}}}end,
  command={FireServer=function(_,action,payload) sent={action=action,payload=payload} end}})
 view.draft={field=1,point=center+Vector3.xAxis*15}
 local ray=Ray.new(rock.Position+Vector3.new(0,20,20),Vector3.new(0,-1,-1).Unit)
 local point,field,id,inRange=view:aim(ray)
 assert(point and field==1 and id=='focus-check' and not inRange,'native ray missed sphere/range fixture')
 assert(view:aimPreview(ray) and not view.draft and sent and sent.action=='FocusResource')
 assert(sent.payload.resourceId=='focus-check' and sent.payload.runId=='native-check' and type(sent.payload.requestId)=='string')
 return 'PASS native Workspace ray -> spherical geode -> existing plot focus despite draft and projected point beyond placement range'
end,debug.traceback)
folder:Destroy()
assert(ok,result)
return result
