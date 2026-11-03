-- Narrow host doubles used by the actual energy/fragment renderer tests.
-- These do not simulate Roblox visuals, asset loading or bloom rendering.
local NumberSequenceKeypoint={new=function(time,value,envelope) return {Time=time,Value=value,Envelope=envelope or 0} end}
local NumberRange={new=function(low,high) return {Min=low,Max=high or low} end}
local typeof=function(value) return getmetatable(value)==VM and 'Vector3' or type(value) end
Vector3.yAxis=Vector3.new(0,1,0);Vector3.zAxis=Vector3.new(0,0,1)
function IM:Emit(count) self.Emitted=(self.Emitted or 0)+count end
function IM:Clear() self.Cleared=true end

