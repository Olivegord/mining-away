-- Extend the shared API double only for APIs used by the retained role modules.
-- No tween execution, mesh scaling or rendering is asserted by these doubles.
local baseGetService=game.GetService
function game:GetService(name)
 if name=='TweenService' then return {Create=function() return {Play=function() end,Cancel=function() end} end} end
 return baseGetService(self,name)
end
function IM:GetScale() return self._scale or 1 end
function IM:ScaleTo(value) self._scale=value end
