-- Small indicators derive from the visible hull and authoritative job clocks.
local Status={}
local paper=Color3.fromRGB(237,245,248)
local ink=Color3.fromRGB(22,29,35)
local green=Color3.fromRGB(158,232,161)
local gold=Color3.fromRGB(255,200,113)
local blue=Color3.fromRGB(142,215,244)

local function frame(parent,name,width,height,tint)
 local part=Instance.new('Frame');part.Name=name;part.Size=UDim2.fromOffset(width,height)
 part.BorderSizePixel=0;part.BackgroundColor3=tint;part.Parent=parent
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(1,0);round.Parent=part
 return part
end
local function new(adornee)
 local gui=Instance.new('BillboardGui');gui.Name='DroneWorkStatus';gui.Adornee=adornee
 gui.StudsOffsetWorldSpace=Vector3.yAxis*(adornee.Size.Y*.5+1.2)
 gui.Size=UDim2.fromOffset(48,17);gui.MaxDistance=64;gui.LightInfluence=0
 gui.AlwaysOnTop=false;gui.Parent=adornee
 local track=frame(gui,'Track',30,6,ink)
 track.AnchorPoint=Vector2.new(.5,.5);track.Position=UDim2.fromScale(.5,.5)
 local fill=frame(track,'Level',28,4,green);fill.Position=UDim2.fromOffset(1,1)
 local wheel=Instance.new('Frame');wheel.Name='Thinking';wheel.Size=UDim2.fromOffset(14,14)
 wheel.AnchorPoint=Vector2.new(0,.5);wheel.Position=UDim2.fromOffset(34,8)
 wheel.BackgroundTransparency=1;wheel.Parent=gui
 for i=0,7 do
  local angle=math.pi*i/4
  local spoke=frame(wheel,'Spoke',2,4,paper)
  spoke.AnchorPoint=Vector2.new(.5,.5)
  spoke.Position=UDim2.fromOffset(7+math.sin(angle)*5,7-math.cos(angle)*5)
  spoke.Rotation=math.deg(angle);spoke.BackgroundTransparency=.08+.115*i
 end
 return {gui=gui,track=track,fill=fill,wheel=wheel}
end
function Status.draw(drone,source,state,role,alive,now,reducedMotion)
 local camera=workspace.CurrentCamera
 local rig=drone.workStatus
 if not alive or not camera or (camera.CFrame.Position-drone.pos).Magnitude>64 then
  if rig then rig.gui.Enabled=false end
  return
 end
 if not rig then rig=new(drone.view.PrimaryPart);drone.workStatus=rig end
 rig.gui.Enabled=true
 local thinking=now<(source:GetAttribute('ThinkUntil') or 0)
 local start=source:GetAttribute('PressStarted') or 0
 local finish=source:GetAttribute('PressFinish') or 0
 local pressing=start>0 and finish>start
 local cycleStart=source:GetAttribute('GunCycleStart') or 0
 local cycleEnd=source:GetAttribute('GunCycleEnd') or 0
 local fraction,tint
 if role=='Compactor' then
  fraction=pressing and (now-start)/(finish-start) or (state=='Press' and 1 or 0)
  tint=gold
 elseif role=='Striker' or role=='Ramiel' then
  fraction=(source:GetAttribute('Battery') or 0)/math.max(1,source:GetAttribute('MaxBattery') or 1)
  tint=fraction<.22 and gold or green
 elseif cycleEnd>cycleStart then
  fraction=(now-cycleStart)/(cycleEnd-cycleStart);tint=gold
 else
  fraction=(source:GetAttribute('HP') or 1)/math.max(1,source:GetAttribute('MaxHP') or 1)
  tint=blue
 end
 local spinner=thinking or pressing or role=='Compactor' and state=='Intake'
 rig.track.Visible=not thinking or pressing
 rig.track.Position=UDim2.fromOffset(spinner and 16 or 24,8)
 rig.fill.Size=UDim2.fromOffset(math.floor(math.clamp(fraction,0,1)*28+.5),4)
 rig.fill.BackgroundColor3=tint
 rig.wheel.Visible=spinner
 rig.wheel.Position=UDim2.fromOffset(rig.track.Visible and 33 or 17,8)
 if spinner then rig.wheel.Rotation=reducedMotion and 0 or now*420%360 end
end
return Status
