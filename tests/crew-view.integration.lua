-- CrewView against the API doubles: buttons appear only on a field, charge
-- fills them, full buttons fire by tap or key, Overdrive glows on the boosted
-- drones and a Shockwave sweeps in, bursts and cleans up. Not engine QA.
local UDim={new=function(a,b) return {Scale=a,Offset=b} end}
local NumberSequenceKeypoint=NumberSequenceKeypoint or {new=function(t,v) return {Time=t,Value=v} end}
local NumberRange=NumberRange or {new=function(a,b) return {Min=a,Max=b or a} end}
do local nativeType=typeof; typeof=function(x) return getmetatable(x)==VM and (x.R~=nil and 'Color3' or 'Vector3') or nativeType(x) end end
local uis={InputBegan=signal(),TouchEnabled=false,KeyboardEnabled=true}
local stockService=game.GetService
function game:GetService(n)
 if n=='UserInputService' then return uis end
 if n=='GuiService' then return {GetGuiInset=function() return Vector2.new(0,0) end} end
 return stockService(self,n)
end
local stockNew=Instance.new
Instance.new=function(class)
 local i=stockNew(class)
 if class=='TextButton' then i.Activated=signal() end
 return i
end
Color3.fromRGB=Color3.fromRGB or function(r,g,b) return Color3.new(r/255,g/255,b/255) end
-- @module
local net=Instance.new('Folder');net.Name='MiningAway';net.Parent=game:GetService('ReplicatedStorage')
local fx=Instance.new('RemoteEvent');fx.Name='CrewFX';fx.Parent=net
local world=Instance.new('Folder');world.Name='MiningAway';world.Parent=workspace
local map=Instance.new('Folder');map.Name='Map';map.Parent=world
local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=map
local zone=Instance.new('Folder');zone.Name='Quartz';zone.Parent=run
local bed=fixturePart(zone,'Field',Vector3.new(0,4,-82),Vector3.new(32,1,32));bed:SetAttribute('WholeField',true)
local droneFolder=Instance.new('Folder');droneFolder.Name='Drones';droneFolder.Parent=world
local source=Instance.new('Model');source:SetAttribute('DroneId','7:drone:1');source.Parent=droneFolder
local localFX=Instance.new('Folder')
local viewModel=Instance.new('Model');viewModel.Name='View_7:drone:1';viewModel.Parent=localFX
local hull=Instance.new('Part');hull.Name='Hull';hull.Parent=viewModel;viewModel.PrimaryPart=hull
local pl=player(7)
local gui=Instance.new('Frame')
local sent={}
local beats,sounds=0,{}
local crew=CrewView.new({gui=gui,player=pl,world=world,localFX=localFX,
 command={FireServer=function(_,action,payload) table.insert(sent,{action=action,payload=payload}) end},
 audio={play=function(_,name) table.insert(sounds,name) end},
 presentation={cameraBeat=function() beats+=1 end},
 reduced=function() return false end,hidden=function() return false end,
 profile=function() return {run={id='run-1'}} end})
local http=game:GetService('HttpService')
local function setCrew(charge,activeUntil)
 pl:SetAttribute('MA_Crew',http:JSONEncode({{role='Striker',kind='Overdrive',name='Overdrive',color={90,230,255},charge=charge,need=6,activeUntil=activeUntil}}))
end
-- Off the field: no buttons.
pl.Character:PivotTo(CFrame.new(Vector3.new(0,4,0)))
setCrew(2)
crew:update(realTime)
assert(crew.dock.Visible==false,'buttons must hide off the field')
-- On the field: one button, partly filled, not ready.
pl.Character:PivotTo(CFrame.new(Vector3.new(0,7,-82)))
crew:update(realTime)
assert(crew.dock.Visible and crew.buttons[1] and crew.buttons[1].holder.Visible,'one button on the field')
assert(crew.buttons[1].name.Text=='Overdrive')
crew:fire(1)
assert(#sent==0,'a partly charged button must not fire')
-- Charged: tap and key both fire.
setCrew(6)
for _=1,30 do realTime+=1/60;crew:update(realTime) end
assert(crew.buttons[1].readyAt,'full button should be ready')
crew.buttons[1].ring.Activated:Fire()
assert(#sent==1 and sent[1].action=='CrewAbility' and sent[1].payload.role=='Striker' and sent[1].payload.runId=='run-1')
uis.InputBegan:Fire({KeyCode=Enum.KeyCode.Q},false)
assert(#sent==2,'Q fires the first button')
uis.InputBegan:Fire({KeyCode=Enum.KeyCode.Q},true)
assert(#sent==2,'typing in a text box must not fire')
-- Overdrive glow follows the server attribute on the visible drone copy.
source:SetAttribute('OverdriveUntil',realTime+3);source:SetAttribute('OverdriveColor',Color3.new(0,1,1))
crew:update(realTime)
assert(hull:FindFirstChild('CrewOverdrive'),'boosted drone should glow')
realTime+=4;crew:update(realTime)
assert(not hull:FindFirstChild('CrewOverdrive'),'glow must end with Overdrive')
-- Shockwave: ring sweeps in, bursts once with a camera beat, then cleans up.
local bursts=0
RoleVisuals.ImpactParticles=function() bursts+=1 end
fx.OnClientEvent:Fire({kind='Shockwave',name='Mega Ball',owner=7,position=Vector3.new(0,5,-82),color=Color3.new(1,0,1),radius=12,impact=.42})
assert(localFX:FindFirstChild('CrewShockwave'),'shockwave ring missing')
assert(#crew.banners==1,'the player who fired sees a banner')
realTime+=.5;crew:update(realTime)
assert(bursts==1 and beats==1,'shockwave should burst once with a camera beat')
realTime+=1;crew:update(realTime)
assert(not localFX:FindFirstChild('CrewShockwave') and #crew.shocks==0,'shockwave must clean up')
realTime+=2;crew:update(realTime)
assert(#crew.banners==0,'banner must clear')
-- Someone else's shockwave: visible, but no banner for this player.
fx.OnClientEvent:Fire({kind='Shockwave',name='Mega Ball',owner=99,position=Vector3.new(0,5,-82),color=Color3.new(1,0,1),radius=12,impact=.42})
assert(#crew.banners==0 and #crew.shocks==1)
print('PASS CrewView buttons, charge, tap/key firing, Overdrive glow and Shockwave cleanup (API doubles; not engine QA)')
