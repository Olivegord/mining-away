local root=Instance.new('Folder');root.Parent=workspace
local w=WorkEffects.new(root)
local holder=Instance.new('Folder');holder.Parent=root
local marker=Instance.new('Part');marker.Parent=holder
local b={holder=holder,marker=marker,origin={WorldPosition=Vector3.new(0,5,0)},tint=Color3.fromRGB(94,190,255)}
local sample={alive=true,isMining=true,active=true,paused=false,warmupStart=0,key='rock',life=1,style='Cutter',pulseSerial=0}
w:mining(b,sample,Vector3.zero,Vector3.yAxis,1,0,10)
assert(b.work and b.work.tip.Parent==marker and b.work.impact.Parent==b.work.tip)
assert(b.work.impact.Enabled and b.work.impact.Rate>0 and b.work.impact.Rate<=6)
-- Contact discs launch and brake close to the crystal.
assert(b.work.impact.Speed.Max<=12 and b.work.impact.Drag>=4)
assert(b.work.impact.Orientation==Enum.ParticleOrientation.FacingCamera)
assert(b.work.impact.Texture=='rbxasset://textures/ui/VR/circleWhite.png' and not b.work.impact.WindAffectsDrag)
-- Discs stay round but no longer overpower the smoke and sparks.
assert(b.work.impact.Size[1].Value>=.4 and b.work.impact.Size[1].Value<=.6 and b.work.impact.Size[2].Value==0 and b.work.impact.Transparency[2].Value>=.55)
assert(b.work.impact.Rate<=4,'contact discs became overpowering again')
assert(b.work.hot.Enabled and b.work.hot.Orientation==Enum.ParticleOrientation.VelocityParallel and b.work.hot.Size[1].Value<=.16,'little sparks missing')
assert(b.work.smoke.Enabled and b.work.smoke.Texture=='rbxasset://textures/particles/smoke_main.dds','contact smoke missing')
assert(b.work.impact.LightEmission<.5 and b.work.impact.Brightness>=1 and b.work.impact.Brightness<=2 and b.work.impact.TimeScale==1)
assert(b.work.impact.Lifetime.Max>=.7 and b.work.impact.Acceleration.Y<0)
sample.stoneColor=Color3.fromRGB(133,95,93)
w:mining(b,sample,Vector3.zero,Vector3.yAxis,1,0,10.02)
assert(b.work.impact.Texture=='rbxasset://textures/ui/VR/circleWhite.png' and b.work.smoke.LightEmission==0,
 'stone contact must keep its discs and tint only the smoke')
sample.stoneColor=nil
w:mining(b,sample,Vector3.zero,Vector3.yAxis,1,0,10.04)
assert(b.work.impact.Texture=='rbxasset://textures/ui/VR/circleWhite.png','ordinary work particles retained the stone dust texture')
local tip=b.work.tip;local clears=b.work.impact.cleared
sample.paused=true;w:mining(b,sample,nil,nil,0,0,10.1)
assert(not b.work.impact.Enabled and b.work.impact.cleared==clears,'pause clipped existing particles instead of stopping emission')
sample.alive=false;w:mining(b,sample,nil,nil,0,0,10.2)
assert(b.work and not b.work.impact.Enabled and b.work.impact.cleared==clears and tip.Parent==marker,
 'a downed drone clipped particles that had already been emitted')
w:mining(b,sample,nil,nil,0,0,11.9)
assert(b.work==nil and tip.Parent==nil and w.miningCount==0)
w:destroy();root:Destroy()
print('PASS contact render actual tip sparks, save pause and final cleanup (API doubles; not native rendering)')
