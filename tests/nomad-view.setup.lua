-- Evaluate the production shot presentation at adjacent phase boundaries.
local BeamVFX={near=function() return true end,reduced=function() return false end}
local NumberSequenceKeypoint={new=function(t,value) return {Time=t,Value=value} end}
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
