local inputService={TouchEnabled=false,MouseEnabled=true}
function inputService:GetFocusedTextBox() return nil end
local baseService=game.GetService
function game:GetService(name) if name=='UserInputService' then return inputService end;return baseService(self,name) end
