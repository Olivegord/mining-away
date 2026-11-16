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
 local velocity=Vector3.xAxis*11
 local function frame(t) return CFrame.new(11*t,5+2*t,.4*t) end
 local duration=Workshop.COURIER_DRAG_TIME+Workshop.COURIER_REEL_TIME
 local function slide(t)
  return Workshop.courierDragOffset(-math.pi/2,0,math.min(t,Workshop.COURIER_DRAG_TIME+.16))
 end
 local first=Workshop.grappleReel(contact,frame(0),velocity,0,false,slide(0))
 local last,seated=Workshop.grappleReel(contact,frame(duration),velocity,duration,false,slide(duration))
 local previous=first
 local maxStep=0
 for tick=1,math.ceil(duration*144) do
  local t=math.min(tick/144,duration)
  local pose=Workshop.grappleReel(contact,frame(t),velocity,t,false,slide(t))
  if t<=Workshop.COURIER_DRAG_TIME then assert(pose.Position.Y==0 and pose.Position.X>=previous.Position.X) end
  maxStep=math.max(maxStep,(pose.Position-previous.Position).Magnitude)
  previous=pose
 end
 assert(first==contact and seated and (last.Position-frame(duration).Position).Magnitude<.001)
 assert(maxStep<.31,'ground pull or reel snapped between neighboring frames')
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
 local groundPull=Workshop.grappleReel(contact,frame(2),velocity,2,false,slide(2)).Position
 assert(groundPull.Y==0 and groundPull.X>15,'two-second ground pull did not keep the rock moving')
 report.dragDistance=(groundPull-contact.Position).Magnitude
 report.exitSpeed=tangent.Magnitude;report.firstDeliverySpeed=regularVelocity.Magnitude
end,debug.traceback)
root:Destroy()
assert(ok,err)
return report
