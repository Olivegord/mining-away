-- Appended to the actual StartupFX module with Roblox API doubles by tools/test.py.
-- Exercises phase math, instance bounds and cleanup; does not establish Studio appearance.
local function finite(n) return n==n and math.abs(n)<math.huge end
local parent=Instance.new('Folder')
for _,style in ipairs({'Stars','Ignition','Coil'}) do
 for _,fps in ipairs({30,144}) do
  local f=StartupFX.create(parent,style,3)
  assert(#f.root:GetDescendants()==66,'unexpected per-effect instance growth')
  local visible=false
  for frame=0,fps do
   local p=frame/fps
   StartupFX.update(f,CFrame.new(10,20,30),p)
   for _,v in ipairs(f.root:GetDescendants()) do
    if v:IsA('Attachment') then
     assert(finite(v.Position.X) and finite(v.Position.Y) and finite(v.Position.Z))
     assert(v.Position.Magnitude<=3.5,'startup exceeds the local drone envelope')
    elseif v:IsA('Beam') and v.Enabled then
     visible=true
     local alpha=type(v.Transparency)=='number' and v.Transparency or v.Transparency.Keypoints[1].Value
     assert(alpha>=0 and alpha<=1)
     assert(v.Width0>0 and v.Width0<=.1)
    elseif v:IsA('BasePart') then error('effects should not add visible hull parts') end
   end
  end
  assert(visible,'style never becomes visible')
  assert(f.root.Transparency==1 and not f.root.CanCollide and not f.root.CanQuery and not f.root.CanTouch)
  StartupFX.destroy(f);assert(#parent:GetChildren()==0,'effect leaked after cancellation')
 end
 print('PASS startup FX '..style..' phase math, spatial/instance bounds and cleanup at 30/144 FPS (API doubles)')
end
for i=1,200 do
 local f=StartupFX.create(parent,'Stars',i)
 StartupFX.update(f,CFrame.new(),.5);StartupFX.destroy(f)
end
assert(#parent:GetChildren()==0)
print('PASS startup FX 200 interrupted charges leave no instances (API doubles; not visual testing)')
