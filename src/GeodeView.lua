-- Bounded cosmetic shells; authoritative attributes own every transition.
local V={}
function V.new(parent,audio,feedback,findFracture,cameraBeat)
 local self={rigs={},count=0}
 function self:remove(r)
  local rig=self.rigs[r];if not rig then return end
  if audio then audio:stopLoop(rig) end
  rig.root:Destroy();r.shellModel=nil;self.rigs[r]=nil;self.count-=1
 end
 function self:update(r,now)
  local source=r.source
  local geode=source:GetAttribute('Kind')=='Geode'
  local ready=source:GetAttribute('OpenReady')==true
  local opening=source:GetAttribute('OpeningAt')
  local broken=(source:GetAttribute('BreakSerial') or 0)>0
  local progress=geode and (source:GetAttribute('CrackProgress') or 0) or (ready or opening) and 1 or 0
  local near=r.restPose and BeamVFX.near(r.restPose.Position,100)
  local rig=self.rigs[r]
  if not near or broken or not (geode or ready or opening) then self:remove(r);return end
  if not rig then
   if self.count>=24 then return end
   local template=findFracture(geode and 'Geode' or source:GetAttribute('CrystalCut') or 'Original')
   if not template then return end -- Replicated templates can arrive after resources.
   local root=Instance.new('Model');root.Name='OpeningRock';root.Parent=parent
   rig={root=root,angle=0,lastProgress=progress,lastRecoil=source:GetAttribute('GeodeRecoilAt') or 0}
   rig.halves={}
   if template then
    for index,name in ipairs({'Left','Right'}) do
     local original=template:FindFirstChild(name)
     if original then
      local half=original:Clone();half.Anchored=true;half.CanCollide=false;half.CanQuery=false;half.CanTouch=false
      half.Material=Enum.Material.Concrete;half.Color=r.stoneColor or r.view.Color;half.Parent=root
      rig.halves[#rig.halves+1]={part=half,side=index==1 and -1 or 1,
       size=original:GetAttribute('SizeRatio'),center=original:GetAttribute('CenterRatio')}
     end
    end
   end
   local core=Instance.new('Part');core.Name='LuminousSeam';core.Shape=Enum.PartType.Ball
   core.Anchored=true;core.CanCollide=false;core.CanQuery=false;core.CanTouch=false
   core.Material=Enum.Material.Neon;core.Color=r.baseColor;core.CastShadow=false;core.Parent=root;rig.core=core
   local glow=Instance.new('PointLight');glow.Color=r.baseColor;glow.Shadows=false;glow.Parent=core;rig.glow=glow
   local halo=Instance.new('BillboardGui');halo.Name='ReadyGlow';halo.Size=UDim2.fromScale(9,9);halo.AlwaysOnTop=false
   halo.Adornee=core;halo.LightInfluence=0;halo.MaxDistance=95;halo.Parent=core;rig.halo=halo
   local image=Instance.new('ImageLabel');image.BackgroundTransparency=1;image.Size=UDim2.fromScale(1,1)
   image.Image='rbxasset://textures/particles/flare_main.dds';image.ImageColor3=r.baseColor;image.Parent=halo;rig.image=image
   self.rigs[r]=rig;r.shellModel=root;self.count+=1
  end
  local player=game:GetService('Players').LocalPlayer
  local lowFlash=BeamVFX.reduced() or player and player:GetAttribute('ReducedFlashing')==true
  local target=source:GetAttribute('SealedDrop') and (opening and .32*math.clamp(1-(opening-now)/.85,0,1) or .025)
   or geode and (progress>0 and .025+.40*progress or 0) or .23
  local recoil=source:GetAttribute('GeodeRecoilAt') or 0
  if recoil>rig.lastRecoil then
   rig.lastRecoil=recoil
   if now-recoil<.4 then
    audio:play('geode_reject',r.restPose.Position)
    feedback:seamBurst(r,now,.65)
    cameraBeat('HeavySplit',r.restPose.Position,now,.85)
   end
  end
  local dt=math.min(.1,math.max(0,now-(rig.lastAt or now)));rig.lastAt=now
  rig.angle+=(target-rig.angle)*(1-math.exp(-dt*(target<rig.angle and 30 or 12)))
  local size=r.view.Size
  local frame=r.restPose
  local hinge=frame*CFrame.new(0,-size.Y*.5,0)
  for _,half in ipairs(rig.halves) do
   half.part.Size=size*half.size
   half.part.CFrame=hinge*CFrame.Angles(0,0,-half.side*rig.angle)*CFrame.new(size*half.center+Vector3.yAxis*size.Y*.5)
   half.part.Transparency=0
  end
  if #rig.halves==2 then r.view.Transparency=1;if r.stoneGradient then RockFinish.setVisibility(r.stoneGradient,1) end end
  local pulse=lowFlash and 1 or .92+.08*math.sin(now*2.7)
  rig.core.Size=size*(geode and .74 or .66);rig.core.CFrame=frame
  rig.core.Transparency=(progress>0 or ready or opening) and .12 or 1
  rig.glow.Range=(ready or opening) and 18 or 8
  rig.glow.Brightness=(ready or opening) and (lowFlash and .8 or 2.8)*pulse or progress*.6
  rig.halo.Enabled=ready or opening~=nil;rig.image.ImageTransparency=lowFlash and .82 or .48+.12*(1-pulse)
  if (ready or opening) and BeamVFX.near(frame.Position,60) then audio:setLoop(rig,'gem_ready',frame.Position,.7,geode and .77 or 1)
  else audio:stopLoop(rig) end
  if opening and rig.opening~=opening then
   rig.opening=opening
   if opening>now then audio:play(geode and 'geode_windup' or 'gem_reveal',frame.Position,{level=.7}) end
  end
  if geode and progress>rig.lastProgress+.045 and now>=(rig.nextDust or 0) then
   rig.nextDust=now+.48;rig.lastProgress=progress
   feedback:seamBurst(r,now,.20)
   audio:play('geode_crack',frame.Position,{pitch=.82+progress*.27,level=.65})
  elseif progress<rig.lastProgress then rig.lastProgress=progress end
 end
 function self:destroy()
  local all={};for r in pairs(self.rigs) do all[#all+1]=r end
  for _,r in ipairs(all) do self:remove(r) end
 end
 return self
end
return V
