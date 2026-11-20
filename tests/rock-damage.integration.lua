-- Production queue/substitution contracts under API doubles. This does not
-- validate CSG topology, native rendering, performance or multiplayer.
local previousIsA=IM.IsA
function IM:IsA(class) return (class=='PartOperation' and self.ClassName=='UnionOperation') or previousIsA(self,class) end
local substitutions=0
function IM:SubstituteGeometry(other) self.Size=other.Size;substitutions+=1 end
function IM:ApplyMesh(other) self.Size=other.Size;substitutions+=1 end
local geometry={cuts=0,hook=nil,fail=false,malformed=false,outputs={}}
function geometry:SubtractAsync(main,cutters,options)
 self.cuts+=1;assert(#cutters>0 and #cutters<=15 and options.SplitApart==false)
 assert(options.CollisionFidelity==Enum.CollisionFidelity.PreciseConvexDecomposition,'laser queries use carved collision shape')
 assert(main.Parent==nil and main.Size.X==4 and main.Size.Y==4 and main.Size.Z==4,'original at canonical bounds')
 assert(main.PivotOffset.Position.Magnitude==0,'local CSG operands never inherit legacy displaced pivots')
 for _,cutter in ipairs(cutters) do assert(cutter.Parent==nil and cutter.Shape==Enum.PartType.Ball,'unparented spherical cuts') end
 if self.hook then local hook=self.hook;self.hook=nil;hook() end
 if self.fail then error('Injected geometry failure') end
 local result=main:Clone();result.Size=self.malformed and Vector3.new(5.1,.73,1.78) or Vector3.new(3.8,3.6,3.84)
 self.outputs[#self.outputs+1]=result;return {result}
end
local scarHistory
local previousService=game.GetService
local assets={created=0,meshes={}}
function assets:CreateEditableMesh()
 self.created+=1
 local mesh={vertices=0,faces=0}
 function mesh:AddVertex(_) self.vertices+=1;return self.vertices end
 function mesh:AddTriangle(a,b,c) assert(a~=b and a~=c and b~=c);self.faces+=1 end
 function mesh:Destroy() self.destroyed=true end
 self.meshes[#self.meshes+1]=mesh;return mesh
end
function assets:CreateMeshPartAsync(content,_)
 assert(content.vertices==4 and content.faces==4)
 local part=Instance.new('MeshPart');part.Size=Vector3.one*4;return part
end
function game:GetService(name)
 if name=='GeometryService' then return geometry elseif name=='AssetService' then return assets
 elseif name=='HttpService' then return {JSONDecode=function() return scarHistory end} end
 return previousService(self,name)
end
local function resource(bubbles,dents)
 local source=Instance.new('UnionOperation');source.Size=Vector3.one*4;source.Parent=workspace
 source.PivotOffset=CFrame.new(0,1000,0)
 source:SetAttribute('HP',70);source:SetAttribute('BreakSerial',0);source:SetAttribute('BubbleBites',bubbles or 0);source:SetAttribute('SmashDents',dents or 0)
 local view=source:Clone();view.CFrame=CFrame.new(10,3,2);view.Parent=workspace
 return {source=source,view=view,baseColor=Color3.fromRGB(145,213,221)}
end
local checks=0
local prior
for n=1,6 do
 local specs=RockDamage.cutSpecs(0,n);assert(#specs==1)
 local dent=specs[1]
 if prior then assert(dent.size.X>prior.size.X and dent.size.Y>prior.size.Y and dent.center.Y==prior.center.Y,'nested cavity widens and deepens') end
 assert(dent.center.Y-dent.size.Y*.5>0,'dent preserves lower foot');prior=dent
end
assert(#RockDamage.cutSpecs(1000,1000)==7 and #RockDamage.cutSpecs(-1,-2)==0,'bounded immutable cutter plan');checks+=1
local ctrl=RockDamage.new();local r=resource()
ctrl:update(r,0);ctrl:step(0);assert(geometry.cuts==0,'intact resources never run CSG')
r.source:SetAttribute('BubbleBites',1);ctrl:update(r,1);ctrl:step(1)
assert(geometry.cuts==1 and substitutions==1)
assert(r.view:GetAttribute('PhysicalDamageKey')=='1:0' and r.dirty,'accepted hit changes local render only')
assert(r.source.Size.X==4 and r.source:GetAttribute('HP')==70 and r.source.PivotOffset.Position.Y==1000,'server state untouched')
assert(r.view.PivotOffset.Position.Magnitude==0,'substituted local view has ordinary origin')
local frame,size=RockDamage.basePose(r.view)
assert((size-Vector3.one*4).Magnitude<1e-6 and (frame.Position-Vector3.new(10,3,2)).Magnitude<1e-6,'cut bounds preserve original frame/scale');checks+=1
for i=1,100 do ctrl:update(r,1+i*.016);ctrl:step(1+i*.016) end
assert(geometry.cuts==1,'unchanged render frames never repeat geometry');checks+=1
geometry.hook=function() r.source:SetAttribute('BubbleBites',3);ctrl:update(r,4.1) end
r.source:SetAttribute('BubbleBites',2);ctrl:update(r,4);ctrl:step(4)
assert(r.view:GetAttribute('PhysicalDamageKey')=='1:0','yielded obsolete shape is discarded')
ctrl:step(4.2);assert(r.view:GetAttribute('PhysicalDamageKey')=='3:0','latest full history is coalesced');checks+=1
geometry.fail=true;r.source:SetAttribute('SmashDents',1);ctrl:update(r,5);ctrl:step(5)
assert(r.view:GetAttribute('PhysicalDamageKey')=='3:0' and not ctrl.working,'CSG failure retains prior authored render')
geometry.fail=false;geometry.malformed=true;r.source:SetAttribute('SmashDents',2);ctrl:update(r,6);ctrl:step(6)
assert(r.view:GetAttribute('PhysicalDamageKey')=='3:0','malformed legacy CSG result rejected');geometry.malformed=false;checks+=1
local late=resource(6,3);ctrl:update(late,7);ctrl:step(7)
assert(late.view:GetAttribute('PhysicalDamageKey')=='6:3','late join builds latest shape in one operation');checks+=1
geometry.hook=function() ctrl:remove(late);late.view:Destroy() end
late.source:SetAttribute('SmashDents',4);ctrl:update(late,8);ctrl:step(8)
assert(not ctrl.working and ctrl.records[late]==nil,'stream-out while yielding cannot resurrect render');checks+=1
local broken=resource(2,1);ctrl:update(broken,9);broken.source:SetAttribute('BreakSerial',1);ctrl:update(broken,9.1)
local cuts=geometry.cuts;ctrl:step(9.2);assert(geometry.cuts==cuts,'depletion removes queued work')
ctrl:destroy();assert(ctrl.closed and next(ctrl.records)==nil,'records cleaned')
for _,out in ipairs(geometry.outputs) do assert(out._destroyed,'temporary CSG output destroyed') end
checks+=1
CrystalGeometry={vertices={{0,0,0},{1,0,0},{0,1,0},{0,0,1}},triangles={{1,3,2},{1,2,4},{2,3,4},{3,1,4}}}
local recovered=RockDamage.new();local a=resource(1,1);local originalView=a.view
originalView.Name='View_Resource_preserve';originalView.Material=Enum.Material.Rock;originalView.Transparency=.04;originalView.LocalTransparencyModifier=.2
originalView:SetAttribute('ResourceId','preserve')
local attachment=Instance.new('Attachment');attachment.Parent=originalView
recovered:update(a,10);recovered:step(10)
assert(recovered.template:IsA('MeshPart') and a.view~=originalView and a.view:IsA('MeshPart') and originalView._destroyed,'first cut replaces only local union view')
assert(a.view:GetAttribute('PhysicalDamageKey')=='1:1' and a.view:GetAttribute('ResourceId')=='preserve')
assert(a.view.Name=='View_Resource_preserve' and a.view.Transparency==.04 and a.view.LocalTransparencyModifier==.2 and attachment.Parent==a.view,'replacement retains rendering metadata and attachments')
local stable=a.view;a.source:SetAttribute('BubbleBites',2);recovered:update(a,10.5);recovered:step(10.5)
assert(a.view==stable and a.view:GetAttribute('PhysicalDamageKey')=='2:1','subsequent MeshPart cuts preserve render identity')
local b=resource(2,0);recovered:update(b,11);recovered:step(11)
assert(assets.created==1 and not assets.meshes[1].destroyed,'one live editable template shared across resource jobs')
recovered:destroy();assert(assets.meshes[1].destroyed and recovered.template==nil,'template mesh lifetime ends with renderer');checks+=1
local pressure=RockDamage.new();local deep=resource(6,0)
local oldDiameter=RockDamage.cutSpecs(6,0,0)[1].size.X
pressure:update(deep,20);pressure:step(20)
for band=1,5 do
 deep.source:SetAttribute('DamageDepth',band/6+.001);pressure:update(deep,20+band);pressure:step(20+band)
 assert(deep.view:GetAttribute('PhysicalDamageKey')=='6:0:'..band,'post-cap accepted work still changes shape')
 local diameter=RockDamage.cutSpecs(6,0,band)[1].size.X
 assert(diameter>oldDiameter and #RockDamage.cutSpecs(6,0,band)==6,'later pressure grows existing cavities without adding cutters')
 oldDiameter=diameter
end
local operations=pressure.operations
deep.source:SetAttribute('DamageDepth',.84);pressure:update(deep,26);pressure:step(26)
assert(pressure.operations==operations,'same depth band does not recompute')
assert(RockDamage.depthBand(5,5,.9)==0 and RockDamage.depthBand(6,0,1)==6,'bounded six-band extension')
pressure:destroy();checks+=1
local cube=resource(2,1);cube.source.ClassName='Part';cube.view.ClassName='Part';cube.source:SetAttribute('CubicRock',true)
local assetCount=assets.created;local cubicDamage=RockDamage.new()
cubicDamage:update(cube,30);cubicDamage:step(30)
assert(cube.view:GetAttribute('PhysicalDamageKey')=='2:1' and cubicDamage.failures==0,'cube accepts both bite and dent subtraction')
assert(assets.created==assetCount and cube.source.ClassName=='Part','cube damage must not rebuild the historical crystal mesh or replace authority')
cubicDamage:destroy();checks+=1
local junk=resource(2,1)
junk.source.ClassName='Part';junk.view.ClassName='Part'
junk.source:SetAttribute('Kind','Junk')
junk.source:SetAttribute('CubicRock',true)
scarHistory={{-.5,.3,0,.755,.59,'X',false},{0,.5,0,.72,.55,'Y',true}}
junk.source:SetAttribute('ToolScars','first-two')
local oldSize=junk.source.Size
local pattern=Instance.new('Decal');pattern.Parent=junk.view
local shallow=RockDamage.new()
shallow:update(junk,31);shallow:step(31)
assert(shallow.operations==1 and shallow.failures==0 and junk.view:GetAttribute('PhysicalDamageKey')=='2:1:tools:first-two')
assert(pattern.Parent==junk.view and #junk.view:GetChildren()==1 and junk.source.Size==oldSize,'keep the printed face, without a separate shell or core')
table.insert(scarHistory,{.5,0,0,.475,.37,'X',false})
junk.source:SetAttribute('ToolScars','third')
shallow:update(junk,32);shallow:step(32)
assert(shallow.operations==2 and shallow.failures==0 and junk.view:GetAttribute('PhysicalDamageKey')=='2:1:tools:third')
local specs=RockDamage.cutSpecs(2,1,0,scarHistory,true)
for _,spec in ipairs(specs) do
 local axis=spec.axis or 'Y'
 assert(math.abs(spec.center[axis])==.5 and spec.size[axis]<=.29,'dents are shallow, open to the outside and follow the hit face')
end
assert(#specs==6 and specs[4].center.X==-.5 and specs[4].center.Y==.3 and specs[6].center.X==.5,'rebuild includes the older and newer side dents')
shallow:destroy();checks+=1
print('PASS '..checks..' physical rock damage queue/ownership checks (API double; native topology not established)')
