-- The production step/destroy methods are supplied by the runner.
local source=Instance.new('Model');source.Name='Carrier';source:SetAttribute('Class','Carrier');source:SetAttribute('Pose',CFrame.new(0,4,0))
local body=Instance.new('Part');body.Name='Frame';body.Parent=source;source.PrimaryPart=body;source.Parent=ctx.world
local scans,pivots=0,0;local originalDescendants,originalPivot=IM.GetDescendants,IM.PivotTo
function IM:GetDescendants() if self==source then scans+=1 end;return originalDescendants(self)end
function IM:PivotTo(cf) if self.Parent==ctx.localFX then pivots+=1 end;return originalPivot(self,cf)end
self:step(20,1/60);scans=0;pivots=0
for frame=1,600 do self:step(20+frame/60,1/60)end
print('METRIC','logistics',scans,pivots)
local record=assert(self.visuals[source])
if record.connections then
 assert(scans==0 and pivots==0,'stationary logistics still scan descendants or rewrite poses')
 local old=record.view
 local streamed=Instance.new('Part');streamed.Name='LatePart';streamed.Parent=source
 self:step(30.3,1/60);record=self.visuals[source]
 assert(record.view~=old and record.view:FindFirstChild('LatePart'),'streamed geometry did not refresh once')
 source:Destroy();self:step(30.6,1/60);assert(not self.visuals[source],'stream-out leaked a logistics record')
 for _,c in ipairs(record.connections)do assert(c.on==false,'stream-out leaked a connection')end
end
self:destroy()
print('PASS production logistics lifecycle exercised without Studio')
