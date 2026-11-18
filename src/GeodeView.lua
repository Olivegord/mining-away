-- Bounded cosmetic shells; authoritative attributes own every transition.
local V={}
V.TIERS={
 {name='COMMON',color=Color3.fromRGB(214,222,230),pitch=1.0,burst=.9},
 {name='RARE',color=Color3.fromRGB(80,170,255),pitch=1.1,burst=1.2},
 {name='EPIC',color=Color3.fromRGB(190,90,255),pitch=1.2,burst=1.6},
 {name='LEGENDARY',color=Color3.fromRGB(255,190,40),pitch=1.32,burst=2.1},
 {name='MYTHIC',color=Color3.fromRGB(255,70,140),pitch=1.45,burst=2.6},
}
-- A loot-reveal banner over the burst: tier name, then the gem count.
function V.reveal(parent,position,tierIndex,gems,audio,cameraBeat,now)
 local tier=V.TIERS[tierIndex] or V.TIERS[1]
 local reduced=BeamVFX.reduced()
 local anchor=Instance.new('Part');anchor.Name='GeodeReveal';anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Size=Vector3.one*.1
 anchor.Position=position+Vector3.yAxis*2.4;anchor.Parent=parent
 local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromOffset(260,90);gui.AlwaysOnTop=true;gui.LightInfluence=0
 gui.MaxDistance=140;gui.Adornee=anchor;gui.Parent=anchor
 local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Size=UDim2.new(1,0,.62,0)
 title.Font=Enum.Font.FredokaOne;title.TextScaled=true;title.Text=tier.name..'!';title.TextColor3=tier.color
 title.TextStrokeTransparency=0;title.TextStrokeColor3=Color3.fromRGB(20,16,30);title.Parent=gui
 local sub=Instance.new('TextLabel');sub.BackgroundTransparency=1;sub.Position=UDim2.fromScale(0,.6);sub.Size=UDim2.new(1,0,.4,0)
 sub.Font=Enum.Font.FredokaOne;sub.TextScaled=true;sub.Text='+'..gems..(gems==1 and ' GEM' or ' GEMS')
 sub.TextColor3=Color3.new(1,1,1);sub.TextStrokeTransparency=0;sub.TextStrokeColor3=Color3.fromRGB(20,16,30);sub.Parent=gui
 local scale=Instance.new('UIScale');scale.Scale=reduced and 1 or .2;scale.Parent=gui
 if audio then
  audio:play('gem_reveal',position,{pitch=tier.pitch,level=1})
  if tierIndex>=4 then audio:play('prism_blast',position,{pitch=1.1,level=.55}) end
 end
 if not reduced then
  RoleVisuals.ImpactParticles(position,tier.color,tier.burst,'GemReward')
  RoleVisuals.Pulse(position,tier.color,.6,4+tierIndex*2.2,.5)
  if tierIndex>=3 then RoleVisuals.Pulse(position,Color3.new(1,1,1),.4,3+tierIndex*1.6,.35) end
  if tierIndex>=4 then
   for i=1,3 do task.delay(i*.12,function() RoleVisuals.ImpactParticles(position+Vector3.yAxis*i*.6,V.TIERS[(i%5)+1].color,1.2,'GemReward') end) end
  end
  if cameraBeat then cameraBeat(tierIndex>=3 and 'HeavySplit' or 'Split',position,now,math.min(1.4,.6+tierIndex*.18)) end
 end
 local started=os.clock();local connection
 connection=game:GetService('RunService').RenderStepped:Connect(function()
  local age=os.clock()-started
  if not anchor.Parent or age>=1.9 then connection:Disconnect();anchor:Destroy();return end
  if not reduced then
   local pop=math.clamp(age/.22,0,1)
   scale.Scale=pop<1 and .2+1.15*(1-(1-pop)^3) or 1+.15*math.exp(-(age-.22)*9)*math.cos((age-.22)*30)
   anchor.Position=position+Vector3.yAxis*(2.4+age*.9)
   title.Rotation=tierIndex>=4 and math.sin(age*14)*4*math.exp(-age*2) or 0
  end
  local fade=math.clamp((age-1.45)/.45,0,1)
  title.TextTransparency=fade;title.TextStrokeTransparency=fade;sub.TextTransparency=fade;sub.TextStrokeTransparency=fade
  sub.Visible=age>=.18 or reduced
 end)
 return anchor
end
function V.new(parent,audio,feedback,findFracture,cameraBeat)
 local self={rigs={},count=0}
 function self:remove(r)
  local rig=self.rigs[r];if not rig then return end
  if audio then audio:stopLoop(rig) end
  rig.root:Destroy();r.shellModel=nil;self.rigs[r]=nil;self.count-=1
 end
 -- One crack beat: louder, higher and brighter with each hit.
 function self:crack(r,now,hits)
  if not r.restPose then return end
  local strength=.25+.18*hits
  audio:play('geode_crack',r.restPose.Position,{pitch=.8+hits*.18,level=.75+hits*.1})
  audio:play('crystal_snap',r.restPose.Position,{pitch=1+hits*.12})
  feedback:seamBurst(r,now,strength)
  cameraBeat('Fracture',r.restPose.Position,now,.6+hits*.25)
 end
 function self:tap(r,now)
  local rig=self.rigs[r];if not rig then return end
  rig.tapAt=now
  self:crack(r,now,math.min(Mining.OPEN_HITS,(rig.hits or 0)+1))
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
  local tierIndex=source:GetAttribute('GeodeTier')
  if broken and tierIndex and not r.tierRevealed and source:GetAttribute('OpenOwner')~=nil then
   r.tierRevealed=true
   local at=r.restPose and r.restPose.Position or source.Position
   if (source:GetAttribute('CrystalBreakAt') or now)>now-1.5 then
    V.reveal(parent,at,tierIndex,source:GetAttribute('GeodeGems') or 1,
     source:GetAttribute('OpenOwner')==game:GetService('Players').LocalPlayer.UserId and audio or nil,cameraBeat,now)
   end
  end
  if not near or broken or not (geode or ready or opening) then self:remove(r);return end
  if source:GetAttribute('SealedDrop') then
   if not rig then
    if self.count>=24 then return end
    local root=Instance.new('Attachment');root.Name='SealedGeodeLight';root.Parent=r.view
    local light=Instance.new('PointLight');light.Color=Color3.fromRGB(255,221,157);light.Range=5;light.Brightness=.35;light.Parent=root
    local motes=Instance.new('ParticleEmitter');motes.Name='GeodeDust';motes.Texture='rbxasset://textures/particles/sparkles_main.dds'
    motes.Color=ColorSequence.new(Color3.fromRGB(255,229,176));motes.LightEmission=.5;motes.Rate=1
    motes.Lifetime=NumberRange.new(.6,1);motes.Speed=NumberRange.new(.15,.4);motes.Size=NumberSequence.new(.055)
    motes.Parent=root;rig={root=root,light=light,motes=motes};self.rigs[r]=rig;self.count+=1
   end
   local reduced=BeamVFX.reduced()
   rig.baseSize=rig.baseSize or r.view.Size
   local hits=source:GetAttribute('OpenHits') or 0
   local hitAt=source:GetAttribute('OpenHitAt') or 0
   if hits>(rig.hits or 0) then
    rig.hits=hits
    -- Skip the echo of a tap this client already predicted.
    if math.abs((rig.tapAt or -10)-now)>.35 then self:crack(r,now,hits) end
   end
   rig.motes.Enabled=not reduced and now>=(source:GetAttribute('ReadyAt') or 0)
   rig.motes.Rate=1+(rig.hits or 0)*4
   local t=opening and math.clamp(1-(opening-now)/.32,0,1) or 0
   local crack=math.clamp((rig.hits or 0)/Mining.OPEN_HITS,0,1)
   rig.light.Color=r.baseColor or rig.light.Color
   rig.light.Range=5+crack*9
   rig.light.Brightness=.35+crack*2.2+t*2
   -- Squash-and-stretch punch on every tap.
   local punchAge=now-math.max(rig.tapAt or -10,hitAt)
   local punch=reduced and 0 or math.exp(-punchAge*14)*math.cos(punchAge*38)
   r.view.Size=rig.baseSize*Vector3.new(1+.16*punch,1-.2*punch,1+.16*punch)*(1+.06*crack+.12*t)
   if r.baseColor then r.view.Color=(r.stoneColor or Color3.fromRGB(76,67,58)):Lerp(r.baseColor,crack*.45+t*.4) end
   if r.restPose then
    local shake=reduced and 0 or math.max(t,.5*math.exp(-punchAge*10))
    r.view.CFrame=r.restPose*CFrame.Angles(math.sin(now*48)*.05*shake,0,math.cos(now*43)*.06*shake)
    if opening and rig.opening~=opening then rig.opening=opening;audio:play('geode_windup',r.restPose.Position,{level=.7}) end
    if ready and now>=(source:GetAttribute('ReadyAt') or 0) then audio:setLoop(rig,'gem_ready',r.restPose.Position,.35,.77) else audio:stopLoop(rig) end
   end
   return
  end
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
