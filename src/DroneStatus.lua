-- One world-space status. Bars always report the drone's actual charge.
local Status={}
local paper=Color3.fromRGB(236,247,250)
local ink=Color3.fromRGB(17,23,30)
local empty=Color3.fromRGB(52,64,73)
local gold=Color3.fromRGB(255,192,99)
local spentColor=Color3.fromRGB(255,101,75)
local chargingColor=Color3.fromRGB(121,230,205)
local readyColor=Color3.fromRGB(236,255,248)
local boltRed=Color3.fromRGB(239,54,63)
local boltBright=Color3.fromRGB(255,132,120)
local busyStates={
 Travel=true, Waiting=true, Collect=true, Pickup=true, Deliver=true, Unload=true,
 Launch=true, Vacuum=true, Intake=true, GrowApproach=true, Plant=true,
 Heal=true, RepairCharge=true, Press=true,
}

local function rectangle(parent,name,width,height,tint)
 local frame=Instance.new('Frame')
 frame.Name=name;frame.Size=UDim2.fromOffset(width,height)
 frame.BorderSizePixel=0;frame.BackgroundColor3=tint;frame.Parent=parent
 return frame
end

local function centered(frame)
 frame.AnchorPoint=Vector2.new(.5,.5)
 frame.Position=UDim2.fromScale(.5,.5)
end

local function stroke(parent,name,from,to,width,tint,overlap)
 local delta=to-from
 local bar=rectangle(parent,name,delta.Magnitude+overlap,width,tint)
 local center=(to+from)*.5
 bar.AnchorPoint=Vector2.new(.5,.5);bar.Position=UDim2.fromOffset(center.X,center.Y)
 bar.Rotation=math.deg(math.atan2(delta.Y,delta.X))
 return bar
end

local function new(adornee)
 local gui=Instance.new('BillboardGui')
 gui.Name='DroneWorkStatus';gui.Adornee=adornee
 gui.StudsOffsetWorldSpace=Vector3.yAxis*(adornee.Size.Y*.5+1.45)
 gui.Size=UDim2.fromOffset(120,31);gui.MaxDistance=76;gui.LightInfluence=0
 gui.AlwaysOnTop=false;gui.Parent=adornee

 local track=rectangle(gui,'Power',1,14,ink)
 centered(track)
 local spinner=rectangle(gui,'Spinner',20,20,ink)
 centered(spinner);spinner.BackgroundTransparency=1
 local ticks={}
 local positions={{1,0},{2,0},{2,1},{2,2},{1,2},{0,2},{0,1},{0,0}}
 for i,position in ipairs(positions) do
  local tick=rectangle(spinner,'Step'..i,4,4,paper)
  tick.Position=UDim2.fromOffset(3+position[1]*5,3+position[2]*5)
  ticks[i]=tick
 end

 local bolt=rectangle(gui,'RechargeBolt',24,26,ink)
 centered(bolt);bolt.BackgroundTransparency=1
 local points={Vector2.new(16,3),Vector2.new(7,13),Vector2.new(16,13),Vector2.new(9,23)}
 local boltFaces={}
 for i=1,#points-1 do stroke(bolt,'Edge',points[i],points[i+1],7,ink,1.5) end
 for i=1,#points-1 do
  local face=stroke(bolt,'Bolt',points[i],points[i+1],4,boltRed,1)
  face.ZIndex=2;boltFaces[i]=face
 end
 return {gui=gui,track=track,cells={},spinner=spinner,ticks=ticks,bolt=bolt,boltFaces=boltFaces}
end

local function layoutPower(rig,capacity)
 local unit=Workshop.BATTERY_SEGMENT
 local count=math.ceil(capacity/unit)
 local gap=count<=8 and 2 or 1
 local width=math.clamp(math.floor((111-(count-1)*gap)/count),2,11)
 rig.track:ClearAllChildren()
 table.clear(rig.cells)
 local left=3
 for index=1,count do
  local start=(index-1)*unit
  local span=math.min(unit,capacity-start)
  local pixels=math.max(1,math.round(width*span/unit))
  local cell=rectangle(rig.track,'Segment'..index,pixels,8,empty)
  cell.Position=UDim2.fromOffset(left,3)
  rig.cells[index]={
   start=start,span=span,width=pixels,
   spent=rectangle(cell,'Spent',0,8,spentColor),
   fill=rectangle(cell,'Available',0,8,paper),
   gained=rectangle(cell,'Gained',0,8,readyColor),
  }
  left+=pixels+gap
 end
 rig.track.Size=UDim2.fromOffset(left-gap+3,14)
 rig.capacity=capacity
 rig.powerAt=nil
end

local function drawRange(frame,left,right,color)
 local visible=right>left
 if frame.Visible~=visible then frame.Visible=visible end
 if not visible then return end
 local position=UDim2.fromOffset(left,0)
 local size=UDim2.fromOffset(right-left,8)
 if frame.Position~=position then frame.Position=position end
 if frame.Size~=size then frame.Size=size end
 if frame.BackgroundColor3~=color then frame.BackgroundColor3=color end
end

local function drawPower(rig,target,capacity,now,charging,steady)
 if rig.capacity~=capacity then layoutPower(rig,capacity) end
 local dt=now-(rig.powerAt or now)
 if not rig.powerAt or dt<0 or dt>.4 or steady then
  rig.shown=target;rig.spent=target;rig.gained=target;rig.holdUntil=now
 else
  if target<rig.lastTarget then
   rig.spent=math.max(rig.spent,rig.lastTarget)
   if rig.lastTarget-target>=Workshop.BATTERY_SEGMENT*.4 then rig.holdUntil=now+.09 end
  elseif target>rig.lastTarget then
   rig.gained=math.min(rig.gained,rig.lastTarget)
  end

  rig.shown+=(target-rig.shown)*(1-math.exp(-dt*27))
  if math.abs(target-rig.shown)<.04 then rig.shown=target end
  local tail=math.exp(-dt*7.5)
  if now>=rig.holdUntil then rig.spent=rig.shown+math.max(0,rig.spent-rig.shown)*tail end
  rig.gained=rig.shown-math.max(0,rig.shown-rig.gained)*tail
 end
 rig.powerAt=now;rig.lastTarget=target
 local tint=charging and chargingColor or target<capacity*.25 and gold or paper
 for _,cell in ipairs(rig.cells) do
  local fill=math.round(cell.width*math.clamp((rig.shown-cell.start)/cell.span,0,1))
  local spent=math.round(cell.width*math.clamp((rig.spent-cell.start)/cell.span,0,1))
  local gained=math.round(cell.width*math.clamp((rig.gained-cell.start)/cell.span,0,1))
  drawRange(cell.spent,fill,spent,spentColor)
  drawRange(cell.fill,0,fill,tint)
  drawRange(cell.gained,gained,fill,readyColor)
 end
end

function Status.draw(drone,source,state,role,alive,now,reducedMotion,reducedFlashing)
 local camera=workspace.CurrentCamera
 local rig=drone.workStatus
 if not alive or not camera or (camera.CFrame.Position-drone.pos).Magnitude>76 then
  if rig then rig.gui.Enabled=false;rig.powerAt=nil end
  return
 end

 local recallAt=source:GetAttribute('RecallAt') or 0
 local deciding=state=='Return' or (recallAt>0 and now>=recallAt and now-recallAt<1.2)
  or now<(source:GetAttribute('ThinkUntil') or 0)
 local powered=source:GetAttribute('BatteryPowered')==true
 local toCharge=powered and state=='ToCharge'
 local charging=powered and state=='Charging'
 local working=powered and source:GetAttribute('BatteryWorking')==true and not source:GetAttribute('WorkPaused')
 local bar=charging or working
 local spinner=not toCharge and not bar and (deciding or busyStates[state]==true
  or role=='Compactor' and source:GetAttribute('PressWaiting')==true)
 if not toCharge and not bar and not spinner then
  if rig then rig.gui.Enabled=false;rig.powerAt=nil end
  return
 end
 if not rig then rig=new(drone.view.PrimaryPart);drone.workStatus=rig end

 rig.gui.Enabled=true
 rig.track.Visible=bar and not toCharge
 rig.spinner.Visible=spinner
 rig.bolt.Visible=toCharge
 if rig.track.Visible then
  local capacity=math.max(1,source:GetAttribute('MaxBattery') or Workshop.BATTERY)
  local target=math.clamp(source:GetAttribute('Battery') or 0,0,capacity)
  drawPower(rig,target,capacity,now,charging,reducedMotion)
 else
  rig.powerAt=nil
 end

 if toCharge then
  local phase=(now*1.65)%1
  local pulse=(reducedMotion or reducedFlashing) and .52
   or .12+.88*math.max(0,math.sin(phase*math.pi*2))^1.8
  local tint=boltRed:Lerp(boltBright,pulse)
  for _,face in ipairs(rig.boltFaces) do face.BackgroundColor3=tint end
 elseif spinner then
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
