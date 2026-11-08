-- Cosmetic CSG of cubic rocks and retained crystal previews. Server hits provide the
-- persistent counts; this module cannot grant damage, ore or reservations.
local R={MAX_CUTS=6}
local CANONICAL=4
local views=setmetatable({},{__mode='k'})
local function count(value) return math.clamp(math.floor(tonumber(value) or 0),0,R.MAX_CUTS) end
local function divide(a,b) return Vector3.new(a.X/b.X,a.Y/b.Y,a.Z/b.Z) end
function R.bite(index,depthBand)
 local i=math.clamp(math.floor(index or 1),1,R.MAX_CUTS)
 local angle=(i-1)*2.39996323+.35
 local pressure=math.clamp(math.floor(depthBand or 0),0,6)/6
 return Vector3.new(math.cos(angle)*.23,.10+(i%2)*.035,math.sin(angle)*.23),.60+.12*pressure
end
function R.depthBand(bubbles,dents,depth)
 if count(bubbles)<R.MAX_CUTS and count(dents)<R.MAX_CUTS then return 0 end
 return math.clamp(math.floor(math.clamp(tonumber(depth) or 0,0,1)*6+1e-7),0,6)
end
function R.cutSpecs(bubbles,dents,depthBand,ballPoint,ballCount,heat,dentWidth,meltPoint)
 local result={}
 for i=1,count(bubbles) do
  local center,diameter=R.bite(i,count(bubbles)>=R.MAX_CUTS and depthBand or 0)
  result[#result+1]={center=center,size=Vector3.one*diameter,kind='Bubbler'}
 end
 local n=count(dents)
 if n>0 then
  local pressure=n>=R.MAX_CUTS and math.clamp(math.floor(depthBand or 0),0,6)/6 or 0
  -- One nested ellipsoid: each accepted hammer strike widens AND deepens
  -- the same cavity. Its lower rim never cuts through the grounded foot.
  result[#result+1]={center=Vector3.new(.025,.49,.015),size=Vector3.new(.60+.10*n+.20*pressure,.36+.10*n+.18*pressure,.60+.10*n+.20*pressure),kind='Smasher'}
 end
 if ballPoint then
  local axis='Y';if math.abs(ballPoint.X)>math.abs(ballPoint[axis]) then axis='X' end
  if math.abs(ballPoint.Z)>math.abs(ballPoint[axis]) then axis='Z' end
  local width=(dentWidth or .65)+.035*math.clamp(ballCount or 1,1,4);local depth=width*.78
  local size=Vector3.new(axis=='X' and depth or width,axis=='Y' and depth or width,axis=='Z' and depth or width)
  result[#result+1]={center=ballPoint,size=size,kind='BowlingBall'}
 end
 if heat and heat>0 then
  result[#result+1]={center=meltPoint or Vector3.new(0,.52,0),size=Vector3.new(.48+.12*heat,.35+.1*heat,.48+.12*heat),kind='Melt'}
 end
 return result
end
function R.basePose(view)
 local record=views[view]
 if not record then return view.CFrame,view.Size end
 local size=divide(view.Size,record.damageScale or Vector3.one)
 return view.CFrame*CFrame.new(-(size*(record.damageOffset or Vector3.zero))),size
end
local function clean(part)
 for _,child in ipairs(part:GetChildren()) do child:Destroy() end
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.PivotOffset=CFrame.new()
 part.LocalTransparencyModifier=0;part.Transparency=0
 if part:IsA('PartOperation') then part.UsePartColor=true end
end
local function discard(parts)
 if type(parts)=='table' then for _,part in ipairs(parts) do part:Destroy() end end
end
local function placeInterior(record)
 local interior=record.interior
 if not interior then return end
 local frame,size=R.basePose(record.view)
 interior.part.Size=size*interior.scale
 interior.part.CFrame=frame*CFrame.new(size*interior.offset)
 interior.part.Transparency=record.view.Transparency
end
function R.new(options)
 options=options or {}
 local self={records={},queued={},working=false,nextAt=0,closed=false,operations=0,failures=0}
 local function failure(record,state,key,message)
  self.failures+=1;self.lastError=tostring(message);state.failed=key
  if record.view.Parent then record.view:SetAttribute('PhysicalDamageError',self.lastError:sub(1,350)) end
 end
 function self:register(record)
  if self.closed or self.records[record] then return end
  self.records[record]={requested='',applied='',generation=0}
  views[record.view]=record
 end
 function self:update(record,now)
  if self.closed then return end
  self:register(record)
  local state=self.records[record];local source=record.source
  if not state or not source.Parent or not record.view.Parent then return end
  placeInterior(record)
  if (source:GetAttribute('BreakSerial') or 0)>0 or (source:GetAttribute('HP') or 1)<=0 then self.queued[record]=nil;return end
  local bubbles=count(source:GetAttribute('BubbleBites'));local dents=count(source:GetAttribute('SmashDents'))
  local band=R.depthBand(bubbles,dents,source:GetAttribute('DamageDepth'))
  local ball=source:GetAttribute('BallDentPoint');local ballCount=source:GetAttribute('BallDents') or 0
  local heat=source:GetAttribute('MeltBand') or 0
  local key=bubbles..':'..dents..(band>0 and ':'..band or '')..(ball and ':ball'..(source:GetAttribute('BallDentSerial') or 0) or '')..(heat>0 and ':heat'..heat or '')
  if key==state.requested then return end
  state.requested=key;state.generation+=1
  if bubbles+dents==0 and not ball and heat==0 then return end
  -- Only the local render clone is touched, never the replicated source.
  if not record.view:IsA('PartOperation') and not record.view:IsA('MeshPart') and source:GetAttribute('CubicRock')~=true then return end
  self.queued[record]={bubbles=bubbles,dents=dents,depthBand=band,ball=ball,ballCount=ballCount,heat=heat,meltPoint=source:GetAttribute('MeltPoint'),dentWidth=source:GetAttribute('DentWidth'),generation=state.generation,key=key,at=now}
 end
 local function execute(record,request,state)
  local geometry=game:GetService('GeometryService')
  local cubic=record.source:GetAttribute('CubicRock')==true
  if not cubic and CrystalGeometry and not self.templateAttempted then
   self.templateAttempted=true
   local editable
   local made,template=pcall(function()
    local assets=game:GetService('AssetService')
    editable=assert(assets:CreateEditableMesh(),'Local crystal mesh budget unavailable')
    local ids={}
    for i,vertex in ipairs(CrystalGeometry.vertices) do
     ids[i]=editable:AddVertex(Vector3.new(vertex[1],vertex[2],vertex[3])*CANONICAL)
    end
    for _,triangle in ipairs(CrystalGeometry.triangles) do
     editable:AddTriangle(ids[triangle[1]],ids[triangle[2]],ids[triangle[3]])
    end
    return assets:CreateMeshPartAsync(Content.fromObject(editable),{
     CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,
    })
   end)
   if made and template and not self.closed then
    self.template=template;self.editableTemplate=editable
    clean(template);template.CFrame=CFrame.new();template.Size=Vector3.one*CANONICAL
   else
    if made and template then template:Destroy() end
    if editable then editable:Destroy() end
    self.templateError=tostring(template)
    failure(record,state,request.key,'Template: '..self.templateError)
   end
  end
  if self.closed or self.records[record]~=state then return end
  -- Cubic resources use their pristine server Part. For retained crystal
  -- previews, use original geometry; never normalize a legacy union
  -- by re-unioning it: old URL-backed operands can resolve to a plain box.
  -- CrystalGeometry recovers the original asset's collision hull surface;
  -- intact rocks retain their original render, only damaged rocks use it.
  local template=cubic and record.source or (options.template and options.template(record) or self.template or record.source)
  local base=template:Clone();clean(base)
  base.CFrame=CFrame.new();base.Size=Vector3.one*CANONICAL
  local cutters={}
  for _,spec in ipairs(R.cutSpecs(request.bubbles,request.dents,request.depthBand,request.ball,request.ballCount,request.heat,request.dentWidth,request.meltPoint)) do
   local cutter=Instance.new('Part');cutter.Shape=Enum.PartType.Ball
   cutter.Size=spec.size*CANONICAL;cutter.CFrame=CFrame.new(spec.center*CANONICAL)
   cutter.Anchored=true;cutter.CanCollide=false;cutter.CanTouch=false;cutter.CanQuery=false
   cutters[#cutters+1]=cutter
  end
  self.operations+=1
  local interiorMaterial,interiorColor
  if request.ball and record.source:GetAttribute('JunkInterior') then
   interiorMaterial,interiorColor=JunkField.finish(record.source:GetAttribute('JunkInterior'))
  end
  local core
  if interiorMaterial then
   core=Instance.new('Part');core.Size=Vector3.one*(CANONICAL*.92);core.CFrame=CFrame.new()
   table.insert(cutters,core)
  end
  local geometryOptions={
   CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,RenderFidelity=Enum.RenderFidelity.Automatic,SplitApart=false,
  }
  local ok,parts=pcall(function()
   return geometry:SubtractAsync(base,cutters,geometryOptions)
  end)
  local coreParts
  if core then
   table.remove(cutters)
   if ok and type(parts)=='table' and #parts==1 then
    -- A small gap between the two cavity surfaces keeps the wool and shell
    -- from fighting for the same pixels at the cut.
    for _,cutter in ipairs(cutters) do cutter.Size*=1.025 end
    local coreOK,result=pcall(function() return geometry:SubtractAsync(core,cutters,geometryOptions) end)
    if not coreOK or type(result)~='table' or #result~=1 then
     failure(record,state,request.key,'Interior: '..tostring(result));discard(parts);discard(result);parts=nil
    else coreParts=result end
   end
   core:Destroy()
  end
  base:Destroy();discard(cutters)
  if not parts and core then return end
  if not ok or type(parts)~='table' or #parts~=1 then
   failure(record,state,request.key,'Subtract: '..(ok and ('expected one result, received '..tostring(type(parts)=='table' and #parts or type(parts))) or tostring(parts)))
   discard(parts);return
  end
  local result=parts[1]
  local ratio=result.Size/CANONICAL
  -- Some legacy unions have invalid CSG operand data. A subtraction cannot
  -- expand its source; refuse a malformed result and retain original art.
  local valid=ratio.X>.24 and ratio.Y>.24 and ratio.Z>.24 and ratio.X<1.03 and ratio.Y<1.03 and ratio.Z<1.03
  if valid and not self.closed and self.records[record]==state and state.generation==request.generation
   and record.source.Parent and record.view.Parent and (record.source:GetAttribute('BreakSerial') or 0)==0 then
   local view=record.view;local frame,size=R.basePose(view)
   local offset=result.CFrame.Position/CANONICAL
   local priorPivot=view.PivotOffset
   local swapped,swapError=pcall(function()
    if (view:IsA('Part') and cubic) or (view:IsA('PartOperation') and result:IsA('MeshPart')) then
     -- Native verification found SubstituteGeometry(MeshPart) reports success
     -- but keeps the old union render. Convert the local view once, retaining
     -- its logical record and metadata; later cuts use stable ApplyMesh.
     local old=view
     clean(result)
     for _,property in ipairs({'Name','Material','MaterialVariant','Color','Transparency','LocalTransparencyModifier','Reflectance','CastShadow'}) do
      if old[property]~=nil then result[property]=old[property] end
     end
     for name,value in pairs(old:GetAttributes()) do result:SetAttribute(name,value) end
     result.Size=size*ratio;result.CFrame=frame*CFrame.new(size*offset)
     for _,child in ipairs(old:GetChildren()) do child.Parent=result end
     result.Parent=old.Parent
     record.view=result;views[old]=nil;views[result]=record
     view=result;parts={};old:Destroy()
    elseif view:IsA('PartOperation') and result:IsA('PartOperation') then
     view.PivotOffset=CFrame.new();view:SubstituteGeometry(result)
    elseif view:IsA('MeshPart') and result:IsA('MeshPart') then
     view.PivotOffset=CFrame.new();view:ApplyMesh(result)
    else error('Incompatible local crystal geometry') end
   end)
   if swapped then
    record.damageScale=ratio;record.damageOffset=offset
    view.Size=size*ratio;view.CFrame=frame*CFrame.new(size*offset)
    view.Color=record.baseColor;view:SetAttribute('PhysicalDamageKey',request.key)
    view:SetAttribute('PhysicalDamageError',nil)
    if record.interior then record.interior.part:Destroy();record.interior=nil end
    if coreParts then
     local inner=coreParts[1]
     clean(inner);inner.Name='JunkInterior';inner.Material=interiorMaterial;inner.MaterialVariant='';inner.Color=interiorColor
     record.interior={part=inner,scale=inner.Size/CANONICAL,offset=inner.CFrame.Position/CANONICAL}
     placeInterior(record);inner.Parent=view;coreParts=nil
    end
    record.dirty=true;state.applied=request.key
   else view.PivotOffset=priorPivot;failure(record,state,request.key,'Substitute: '..tostring(swapError)) end
  elseif not valid then failure(record,state,request.key,string.format('Invalid bounds %.4f, %.4f, %.4f; template=%s',ratio.X,ratio.Y,ratio.Z,self.template and self.template.ClassName or 'original')) end
  discard(parts);discard(coreParts)
 end
 function self:step(now)
  if self.closed or self.working or now<self.nextAt then return end
  local camera=workspace.CurrentCamera;local selected,request,best=nil,nil,math.huge
  for record,pending in pairs(self.queued) do
   if not record.source.Parent or not record.view.Parent then self.queued[record]=nil
   else
    local distance=camera and (record.view.Position-camera.CFrame.Position).Magnitude or 0
    -- Distant damage remains queued; a returning observer gets the latest
    -- full shape, without replaying intermediate contacts or sound.
    if distance<160 and distance<best then selected=record;request=pending;best=distance end
   end
  end
  if not selected then return end
  self.queued[selected]=nil;self.working=true;self.nextAt=now+.12
  local state=self.records[selected]
  task.spawn(function()
   local ok,err=pcall(execute,selected,request,state)
   if not ok then failure(selected,state,request.key,'Worker: '..tostring(err)) end
   self.working=false
  end)
 end
 function self:remove(record)
  self.queued[record]=nil;self.records[record]=nil;views[record.view]=nil
 end
 function self:destroy()
  self.closed=true
  if self.template then self.template:Destroy();self.template=nil end
  if self.editableTemplate then self.editableTemplate:Destroy();self.editableTemplate=nil end
  for record in pairs(self.records) do views[record.view]=nil end
  table.clear(self.queued);table.clear(self.records)
 end
 return self
end
return R
