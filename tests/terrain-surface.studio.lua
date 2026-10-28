-- Execute on a real Studio SERVER after prepending bundled Config/MapLayout.
-- This tests real geometric contact and raycasts; visual approval requires
-- independent moving player-camera evidence, not this numeric report.
local root=assert(workspace:FindFirstChild('MiningAway'),'Start Mining Away first')
local plan=MapLayout.plan(Config.Fields)
local terrain=assert(root.Map:FindFirstChild('ConnectedCliffs'))
local caps={}
for _,v in ipairs(terrain:GetDescendants()) do if v.Name=='StuddedGround' then table.insert(caps,v) end end
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=caps
local issues={};local samples=0;local worst=0
for i,cell in ipairs(plan.cells) do if i%3==0 then
 local x=(cell.a[1]+cell.c[1])/2;local z=(cell.a[3]+cell.c[3])/2;local y=cell.h+.04
 samples+=1;local hit=workspace:Raycast(Vector3.new(x,y+80,z),Vector3.new(0,-100,0),params)
 local gap=hit and math.abs(hit.Position.Y-y) or 999;worst=math.max(worst,gap)
 if gap>.05 then table.insert(issues,{kind='ground cap',x=x,z=z,expected=y,actual=hit and hit.Position.Y or 'missing'}) end
end end
local treeCount=0
for _,tree in ipairs(root.Map.BiomeGroves:GetChildren()) do
 local foot=tree:FindFirstChild('TreeFooting');local trunk=tree:FindFirstChild('Trunk');local roots=tree:FindFirstChild('Root')
 if not foot or not trunk or not roots then table.insert(issues,{kind='missing tree part',name=tree.Name})
 else
  treeCount+=1;local top=foot.Position.Y+foot.Size.Y/2;local bottom=foot.Position.Y-foot.Size.Y/2
  for _,part in ipairs({trunk,roots}) do
   local actual=part.Position.Y-part.Size.Y/2
   if math.abs(actual-top)>.03 then table.insert(issues,{kind='root detached',name=tree.Name,expected=top,actual=actual}) end
  end
  for _,dx in ipairs({-3.1,0,3.1}) do for _,dz in ipairs({-3.1,0,3.1}) do
   local hit=workspace:Raycast(Vector3.new(foot.Position.X+dx,top+80,foot.Position.Z+dz),Vector3.new(0,-100,0),params)
   if not hit or hit.Position.Y>top+.05 or hit.Position.Y<bottom-.05 then
    table.insert(issues,{kind='tree footing gap or burial',name=tree.Name,top=top,bottom=bottom,ground=hit and hit.Position.Y or 'missing'})
   end
  end end
 end
end
local joints=0;local trailSupportSamples=0;local worstTrailSupportGap=0
for _,lane in ipairs(root.Map.WindingRoutes:GetChildren()) do
 for _,support in ipairs(lane:GetChildren()) do if support.Name=='TrailEarth' then
  local trail=nil;local segment=support:GetAttribute('RouteSegment')
  for _,part in ipairs(lane:GetChildren()) do if part.Name=='Trail' and part:GetAttribute('RouteSegment')==segment then trail=part;break end end
  if not trail then table.insert(issues,{kind='trail support has no road segment',route=lane.Name,index=segment})
  else
   local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={trail}
   for _,offset in ipairs({-.45,0,.45}) do
    local origin=support.Position+Vector3.new(0,support.Size.Y/2,0)+support.CFrame.LookVector*(offset*support.Size.Z)
    local hit=workspace:Raycast(origin,Vector3.new(0,10,0),ray);trailSupportSamples+=1
    if not hit then table.insert(issues,{kind='trail support does not meet road above',route=lane.Name,index=segment,offset=offset})
    else
     local gap=hit.Position.Y-origin.Y;worstTrailSupportGap=math.max(worstTrailSupportGap,gap)
     if gap>.3 then table.insert(issues,{kind='trail support separated from road',route=lane.Name,index=segment,offset=offset,gap=gap}) end
    end
   end
  end
 end end
 for _,joint in ipairs(lane:GetChildren()) do if joint.Name=='RouteJoint' then
  joints+=1;local supportLimit=joint:GetAttribute('SupportTop')
  local trails={};for _,part in ipairs(lane:GetChildren()) do if part.Name=='Trail' then table.insert(trails,part) end end
  local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances=trails
  local hit=workspace:Raycast(joint.Position+Vector3.new(0,1,0),Vector3.new(0,-3,0),ray)
  if not hit or math.abs(hit.Position.Y-joint.Position.Y)>.7 then
   table.insert(issues,{kind='route seam detached from walking slabs',route=lane.Name,index=joint:GetAttribute('JointIndex')})
  end
  if type(supportLimit)~='number' then table.insert(issues,{kind='route support limit missing',route=lane.Name,index=joint:GetAttribute('JointIndex')})
  elseif supportLimit>.2 then
   local support=nil;local index=joint:GetAttribute('JointIndex')
   for _,part in ipairs(lane:GetChildren()) do if part.Name=='JointEarth' and part:GetAttribute('JointIndex')==index then support=part;break end end
   if not support then table.insert(issues,{kind='unsupported route joint',route=lane.Name,index=index})
   else
    local supportTop=support.Position.Y+support.Size.Y/2
    if math.abs(supportTop-supportLimit)>.03 then table.insert(issues,{kind='route joint support exceeds planned limit',route=lane.Name,index=index,actual=supportTop,limit=supportLimit}) end
   end
  end
 end end
end
local details=assert(root.Map:FindFirstChild('ValleyDetails'));local supported=0
for _,part in ipairs(details:GetChildren()) do
 if part:IsA('BasePart') and (part.Name=='OverlookSupport' or part.Name=='AqueductPier') then
  supported+=1;local bottom=part.Position.Y-part.Size.Y/2
  local hit=workspace:Raycast(Vector3.new(part.Position.X,bottom+2,part.Position.Z),Vector3.new(0,-5,0),params)
  if not hit or math.abs(hit.Position.Y-bottom)>.06 then
   table.insert(issues,{kind='landmark support detached',name=part.Name,bottom=bottom,ground=hit and hit.Position.Y or 'missing'})
  end
 elseif part:IsA('BasePart') and part.Name=='RubyPortalRock' then
  supported+=1;local bottom=part.Position.Y-part.Size.Y/2;local match=false
  for _,base in ipairs(details:GetChildren()) do
   if base.Name=='PortalFooting' and (Vector3.new(base.Position.X,0,base.Position.Z)-Vector3.new(part.Position.X,0,part.Position.Z)).Magnitude<.05 and math.abs(base.Position.Y+base.Size.Y/2-bottom)<.06 then match=true;break end
  end
  if not match then table.insert(issues,{kind='portal rock has no contacting base',name=part.Name}) end
 end
end
local landmark=workspace:FindFirstChild('construct');local plinth=details:FindFirstChild('ConstructPlinth')
if landmark and landmark.PrimaryPart and plinth then
 local bottom=landmark.PrimaryPart.Position.Y-landmark.PrimaryPart.Size.Y/2
 local top=plinth.Position.Y+plinth.Size.Y/2
 if math.abs(bottom-top)>.06 then table.insert(issues,{kind='original construct detached from plinth',bottom=bottom,top=top}) end
else table.insert(issues,{kind='original construct or plinth missing'}) end
return game:GetService('HttpService'):JSONEncode({kind='real engine part-cap, tree-footing, landmark and route-joint contact rays; not a visual or multiplayer pass',groundSamples=samples,worstGroundError=worst,trees=treeCount,routeJoints=joints,trailSupportSamples=trailSupportSamples,worstTrailSupportGap=worstTrailSupportGap,majorSupports=supported,issues=issues})
