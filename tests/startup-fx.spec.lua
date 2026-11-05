-- Production force paths and startup visuals with API doubles, not visual approval.
for i=1,8 do
 local radius=math.huge
 for frame=0,240 do
  local p,v,captured=PullMotion.sample(i,frame/240)
  assert(p.Magnitude<=radius+.001,'particle moved outward before suction')
  assert(p.Magnitude==p.Magnitude and v.Magnitude==v.Magnitude)
  radius=p.Magnitude
 end
 assert(radius<.001,'stream was not captured before laser release')
 local a,va=PullMotion.sample(i,.1);local b,vb=PullMotion.sample(i,.4)
 assert(a:Dot(va)<0 and b:Dot(vb)<0,'stream is not already moving inward')
end
local parent=Instance.new('Folder')
for _,style in ipairs({'Stars','Ignition','Coil'}) do
 local expected
 for _,fps in ipairs({30,60,144}) do
  local f=StartupFX.create(parent,style,3)
  assert(#f.root:GetDescendants()<=90,'startup instance budget increased')
  for frame=0,fps do
   StartupFX.update(f,CFrame.new(10,20,30),frame/fps)
   for _,v in ipairs(f.root:GetDescendants()) do
    if v:IsA('Attachment') then assert(v.Position.Magnitude<=7) end
   end
  end
  StartupFX.update(f,CFrame.new(),.5)
  local pos=f.arcs[1].a.Position
  if expected then assert((pos-expected).Magnitude<1e-6,'frame rate changed the pull') else expected=pos end
  assert(f.arcs[1].beam.Enabled and f.root.Transparency==1)
  StartupFX.update(f,CFrame.new(),.94)
  for _,r in ipairs(f.plane.rays) do assert(r.beam.Enabled and math.abs(r.a.Position.Y)<1e-6 and math.abs(r.b.Position.Y)<1e-6) end
  StartupFX.hide(f)
  for _,v in ipairs(f.root:GetDescendants()) do if v:IsA('Beam') then assert(not v.Enabled) end end
  StartupFX.destroy(f);assert(#parent:GetChildren()==0)
 end
 print('PASS inward force motion, planar spread, bounded startup and cleanup '..style..' at 30/60/144 FPS (API doubles)')
end
