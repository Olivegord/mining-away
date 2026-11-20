-- Bundle DroneConfig, Feel, PickupMotion and Workshop before running in Edit.
local root=Instance.new('Folder');root.Name='TemporaryOverheadCourierChecks';root.Parent=workspace
local report={}
local ok,err=xpcall(function()
 for _,role in {'Needler','Ballcaster'} do
  local model=Instance.new('Model');model.Name=role;model.Parent=root
  local body=Instance.new('Part');body.CFrame=CFrame.new(0,400,0)*CFrame.Angles(0,.77,0)
  body.Name='Mesh';body.Anchored=true;body.Parent=model;model.PrimaryPart=body
  DroneConfig.decorate(model,role,nil,true)
  local part=model:FindFirstChild(role=='Needler' and 'DartRail' or 'OrbSeat')
  local down=role=='Needler' and part.CFrame.LookVector or part.CFrame.RightVector
  local muzzle=part.ShotMuzzle.WorldPosition
  local localPoint=model:GetPivot():PointToObjectSpace(muzzle)
  assert(down.Y<-.999 and math.abs(localPoint.X)<.001 and math.abs(localPoint.Z)<.001)
  assert(math.abs(localPoint.Y+DroneConfig.DownwardGunDepth[role])<.001)
  DroneConfig.fitBody(model,role)
  assert(math.abs(model:GetPivot():PointToObjectSpace(part.ShotMuzzle.WorldPosition).Y/model:GetScale()
   +DroneConfig.DownwardGunDepth[role])<.001)
  report[role..'MuzzleY']=localPoint.Y
 end
 local minUp,maxUp=1,0
 for seed=1,32 do
  local size=Vector3.new(4,2.2,3.7)
  local frame,top=Feel.groundedRockFrame(Vector3.zero,size,20,2,seed,true,true,false,true)
  local support=.5*(size.X*math.abs(frame.RightVector.Y)+size.Y*math.abs(frame.UpVector.Y)+size.Z*math.abs(frame.LookVector.Y))
  assert(math.abs(frame.Position.Y+support-top)<.001 and frame.Position.Y-support<=20)
  minUp=math.min(minUp,frame.UpVector.Y);maxUp=math.max(maxUp,frame.UpVector.Y)
  local x,y,z=Workshop.oreOrientation(seed,false)
  local r=CFrame.Angles(x,y,z)
  local exact=.5*(size.X*math.abs(r.RightVector.Y)+size.Y*math.abs(r.UpVector.Y)+size.Z*math.abs(r.LookVector.Y))
  assert(math.abs(PickupMotion.supportHeight(size.X,size.Y,size.Z,x,y,z)-exact)<.001)
 end
 assert(minUp<.89 and maxUp>.98,'seeded stone lean did not vary')
 local contact=CFrame.new(0,0,0)
 local velocity=Vector3.xAxis*Workshop.COURIER_SWEEP_SPEED
 local duration=Workshop.COURIER_REEL_TIME
 local function reel(t)
  local hull=Workshop.courierSwoop(Vector3.yAxis*Workshop.COURIER_HOOK_DROP,-math.pi/2,Vector3.zero,velocity,1+t,1,0)
  local cradle=CFrame.new(hull-Vector3.yAxis*1.14)
  return Workshop.grappleReel(contact,cradle,t,false)
 end
 local first=reel(0)
 local previous=first
 local maxStep,firstLift=0,nil
 for tick=1,math.ceil(duration*144) do
  local t=math.min(tick/144,duration)
  local pose=reel(t)
  if not firstLift and pose.Position.Y>.02 then firstLift=t end
  maxStep=math.max(maxStep,(pose.Position-previous.Position).Magnitude)
  previous=pose
 end
 local _,seated=reel(duration)
 assert(first==contact and seated and firstLift and firstLift<.1,'the reel kept the rock on the ground')
 assert(maxStep<.31,'the direct reel snapped between neighboring frames')
 local dock=Vector3.zero
 local destination=Vector3.new(-48,9,0)
 local yaw=-math.pi/2
 local offset=Vector3.new(-18,15,0)
 local approach=Workshop.courierApproachTime(offset)
 local turn=Workshop.courierReturnTurn(dock,yaw,destination)
 local exit=approach+Workshop.courierReturnDuration(turn)
 local position,tangent=Workshop.courierSwoop(dock,yaw,offset,velocity,exit,approach,turn)
 local late,lateVelocity=Workshop.courierSwoop(dock,yaw,offset,velocity,exit+.16,approach,turn)
 local regular,regularVelocity=Feel.inertialApproach(position,destination,tangent,.29,1/60,true,nil,1,1.6)
 assert((late-position).Magnitude>1.7 and tangent:Dot(lateVelocity)>120,'exit stalled between snapshots')
 assert((regular-position):Dot(tangent.Unit)>.17 and tangent.Unit:Dot(regularVelocity)>10.5,'delivery did not inherit the exit tangent')
 report.leanDotRange={minUp,maxUp};report.maximumReelStep=maxStep
 report.liftAt=firstLift
 report.exitSpeed=tangent.Magnitude;report.firstDeliverySpeed=regularVelocity.Magnitude
end,debug.traceback)
root:Destroy()
assert(ok,err)
return report
