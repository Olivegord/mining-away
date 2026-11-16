-- Draw status from the server's battery and job state.
local Status={}
local paper=Color3.fromRGB(236,244,248)
local ink=Color3.fromRGB(22,29,35)
local empty=Color3.fromRGB(58,71,78)
local green=Color3.fromRGB(158,232,161)
local gold=Color3.fromRGB(255,200,113)
local busyStates={
 Travel=true, Waiting=true, Warmup=true, ToCharge=true, Charging=true,
 Collect=true, Pickup=true, Deliver=true, Unload=true, Launch=true, Vacuum=true,
 Intake=true, GrowApproach=true, Plant=true, Heal=true, RepairCharge=true, BreakerWindup=true,
}
local cellCount,cellWidth=6,6

local function rectangle(parent,name,width,height,tint)
 local frame=Instance.new('Frame')
 frame.Name=name;frame.Size=UDim2.fromOffset(width,height)
 frame.BorderSizePixel=0;frame.BackgroundColor3=tint;frame.Parent=parent
 return frame
end

local function new(adornee)
 local gui=Instance.new('BillboardGui')
 gui.Name='DroneWorkStatus';gui.Adornee=adornee
 gui.StudsOffsetWorldSpace=Vector3.yAxis*(adornee.Size.Y*.5+1.45)
 gui.Size=UDim2.fromOffset(70,23);gui.MaxDistance=76;gui.LightInfluence=0
 gui.AlwaysOnTop=false;gui.Parent=adornee

 local track=rectangle(gui,'Track',47,13,ink)
 track.AnchorPoint=Vector2.new(.5,.5)
 local levels={}
 for i=1,cellCount do
  local cell=rectangle(track,'Cell'..i,cellWidth,7,empty)
  cell.Position=UDim2.fromOffset(3+(i-1)*(cellWidth+1),3)
  levels[i]=rectangle(cell,'Level',cellWidth,7,green)
 end

 local spinner=rectangle(gui,'Spinner',20,20,ink)
 spinner.AnchorPoint=Vector2.new(.5,.5);spinner.BackgroundTransparency=1
 local ticks={}
 local cells={{1,0},{2,0},{2,1},{2,2},{1,2},{0,2},{0,1},{0,0}}
 for i,cell in ipairs(cells) do
  local tick=rectangle(spinner,'Step'..i,4,4,paper)
  tick.Position=UDim2.fromOffset(3+cell[1]*5,3+cell[2]*5)
  ticks[i]=tick
 end
 return {gui=gui,track=track,levels=levels,spinner=spinner,ticks=ticks}
end

function Status.draw(drone,source,state,role,alive,now,reducedMotion)
 local camera=workspace.CurrentCamera
 local rig=drone.workStatus
 if not alive or not camera or (camera.CFrame.Position-drone.pos).Magnitude>76 then
  if rig then rig.gui.Enabled=false end
  return
 end

 local recallAt=source:GetAttribute('RecallAt') or 0
 local recalling=state=='Return' or recallAt>0 and now>=recallAt and now-recallAt<1.2
 local deciding=recalling or now<(source:GetAttribute('ThinkUntil') or 0)
 local start=source:GetAttribute('PressStarted') or 0
 local finish=source:GetAttribute('PressFinish') or 0
 local pressing=role=='Compactor' and state=='Press' and start>0 and finish>start
 local mining=state=='Mine' or state=='SpecialMine' or state=='BreakerDive' or state=='BreakerImpact'
 local fraction,tint
 if not deciding then
  if pressing then
   fraction=(now-start)/(finish-start);tint=gold
  elseif mining and source:GetAttribute('BatteryPowered') and not source:GetAttribute('WorkPaused') then
   local maximum=source:GetAttribute('MaxBattery') or 1
   fraction=(source:GetAttribute('Battery') or 0)/math.max(1,maximum)
   tint=fraction<.22 and gold or green
  end
 end
 local showBar=fraction~=nil
 local spinner=not showBar and (deciding or busyStates[state]==true
  or role=='Compactor' and source:GetAttribute('PressWaiting')==true)
 if not showBar and not spinner then
  if rig then rig.gui.Enabled=false end
  return
 end
 if not rig then rig=new(drone.view.PrimaryPart);drone.workStatus=rig end

 rig.gui.Enabled=true
 rig.track.Visible=showBar
 rig.spinner.Visible=spinner
 rig.track.Position=UDim2.fromScale(.5,.5)
 rig.spinner.Position=UDim2.fromScale(.5,.5)
 if showBar then
  local cells=math.clamp(fraction,0,1)*cellCount
  for i,level in ipairs(rig.levels) do
   local width=math.round(math.clamp(cells-i+1,0,1)*cellWidth)
   level.Visible=width>0
   if width>0 then level.Size=UDim2.fromOffset(width,7);level.BackgroundColor3=tint end
  end
 end
 if spinner then
  local step=reducedMotion and 0 or math.floor(now*12)%#rig.ticks
  if step~=rig.spinnerStep then
   rig.spinnerStep=step
   for i,tick in ipairs(rig.ticks) do
    local age=(step-i+1)%#rig.ticks
    tick.BackgroundTransparency=age==0 and 0 or age==1 and .26 or age==2 and .52 or .81
   end
  end
 end
end
return Status
