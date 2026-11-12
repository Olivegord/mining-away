-- Evaluate the production shot presentation at adjacent phase boundaries.
local BeamVFX={near=function() return true end,reduced=function() return false end}
local RoleVisuals={pulses=0,craters=0,setTime=function() end}
function RoleVisuals.Pulse() RoleVisuals.pulses+=1 end
function RoleVisuals.Crater(_,radius,style,at)
 assert(radius>30 and style=='Nomad')
 RoleVisuals.craterAt=at
 RoleVisuals.craters+=1
end
local NumberSequenceKeypoint={new=function(t,value) return {Time=t,Value=value} end}
local function typeof(value) return getmetatable(value)==VM and 'Vector3' or type(value) end
function IM:Emit(count) self.Emitted=(self.Emitted or 0)+count end
local fromMatrix=CFrame.fromMatrix
function CFrame.fromMatrix(position,right,up,back)
 return fromMatrix(position,right,up,back or right:Cross(up))
end
local getService=game.GetService
function game:GetService(name)
 if name=='GuiService' then return {ReducedMotionEnabled=false} end
 return getService(self,name)
end
workspace.CurrentCamera=Instance.new('Camera')
workspace.CurrentCamera.CFrame={RightVector=Vector3.xAxis,PointToObjectSpace=function(_,point)
 return point-Vector3.new(0,0,55)
end}
