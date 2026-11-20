-- Runs the production work renderer against API doubles; no visual claims.
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
Vector3.xAxis=Vector3.new(1,0,0);Vector3.yAxis=Vector3.new(0,1,0);Vector3.zAxis=Vector3.new(0,0,1)
function IM:Clear() self.cleared=(self.cleared or 0)+1 end
function IM:Emit(n) self.emitted=(self.emitted or 0)+n end
workspace.CurrentCamera={CFrame=CFrame.new(0,4,10)}
