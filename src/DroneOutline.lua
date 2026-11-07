-- Outline the rendered model, including late-joining observers' local copies.
local Outline={}
function Outline.attach(model)
 local h=model:FindFirstChild('DroneOutline') or Instance.new('Highlight')
 h.Name='DroneOutline';h.Adornee=model;h.Enabled=true
 h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
 h.FillTransparency=1;h.OutlineTransparency=0
 h.OutlineColor=Color3.fromRGB(16,27,43)
 h.Parent=model
 return h
end
return Outline
