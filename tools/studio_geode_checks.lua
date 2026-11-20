-- One native Edit component fixture; does not start Play or run the server.
assert(not game:GetService('RunService'):IsRunning() and game.PlaceId==124078027733625 and game.GameId==10774898335)
if shared.GeodeCheck then shared.GeodeCheck.close() end
local root=Instance.new('Folder');root.Name='TemporaryGeodeCheck';root.Parent=workspace
local originalCamera=workspace.CurrentCamera.CFrame
local templates=Instance.new('Folder');templates.Parent=root
local ball=Instance.new('Part');ball.Shape=Enum.PartType.Ball;ball.Size=Vector3.one*6
local halves=assert(CrystalCuts.split(ball,'Geode'),'Native sphere split failed');ball:Destroy();halves.Parent=templates
local sounds={};local audio={play=function(_,name) sounds[name]=(sounds[name] or 0)+1 end,setLoop=function(_,key,name) sounds[name]=true end,stopLoop=function() end}
local feedback=CrystalImpactView.new(root,audio,function() end,function() end,function(name) return templates:FindFirstChild(name) end)
local position=workspace.CurrentCamera.CFrame.Position+workspace.CurrentCamera.CFrame.LookVector*18
local r={source=Instance.new('Part'),view=Instance.new('Part'),baseColor=Color3.fromRGB(246,148,57),stoneColor=Color3.fromRGB(111,102,107),restPose=CFrame.new(position)}
r.source.Shape=Enum.PartType.Ball;r.view.Shape=Enum.PartType.Ball
for _,p in ipairs({r.source,r.view}) do p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Size=Vector3.one*6;p.Position=position;p.Parent=root end
r.source.Transparency=1
r.source:SetAttribute('Kind','Geode');r.source:SetAttribute('FullSize',Vector3.one*6);r.source:SetAttribute('GroundY',position.Y-3)
local now=workspace:GetServerTimeNow()
r.source:SetAttribute('CrackProgress',0);feedback.openings:update(r,now)
local rig=assert(feedback.openings.rigs[r]);assert(#rig.halves==2 and rig.core.Transparency==1)
local whole=rig.halves[1].part.Size
r.source:SetAttribute('CrackProgress',.4)
for i=1,12 do feedback.openings:update(r,now+i/30) end
local open=rig.angle;assert(open>.15 and rig.halves[1].part.Size==whole,'shell shrank instead of opening')
r.source:SetAttribute('CrackProgress',0);r.source:SetAttribute('GeodeRecoilAt',now+.41)
for i=13,22 do feedback.openings:update(r,now+i/30) end
assert(rig.angle<.001 and sounds.geode_reject==1,'recoil did not close shell exactly once')
r.source:SetAttribute('CrackProgress',.999);r.source:SetAttribute('OpenReady',true)
for i=23,40 do feedback.openings:update(r,now+i/30) end
assert(rig.halo.Enabled and rig.glow.Brightness>0 and sounds.gem_ready,'ready glow/hum missing')
r.source:SetAttribute('OpeningAt',now+2.3);r.source:SetAttribute('OpenReady',false)
feedback.openings:update(r,now+1.4);assert(sounds.geode_windup==1)
local report={halves=#rig.halves,angleDegrees=math.deg(rig.angle),unchangedSize=rig.halves[1].part.Size==whole,recoilSounds=sounds.geode_reject,readyHum=sounds.gem_ready,windup=sounds.geode_windup}
shared.GeodeCheck={report=report,close=function() feedback:destroy();root:Destroy();workspace.CurrentCamera.CFrame=originalCamera;shared.GeodeCheck=nil end}
return report
