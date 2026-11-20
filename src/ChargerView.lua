-- Read the active battery from the pad's authoritative charge progress.
-- The fill sits on the existing plate and stays local to the observer.
local View={}
View.__index=View
local DARK=Color3.fromRGB(24,53,41)

function View.new(world,parent,reducedMotion)
 return setmetatable({world=world,parent=parent,reducedMotion=reducedMotion},View)
end

function View:hide()
 if self.baseColor and self.pad and self.pad.Parent then self.pad.Color=self.baseColor end
 if self.fill and self.fill.Parent then self.fill.Parent=nil end
 self.baseColor=nil
 self.shown=nil
end

function View:update(dt)
 if not self.pad or not self.pad.Parent then
  self:hide()
  local map=self.world:FindFirstChild('Map')
  local route=map and map:FindFirstChild('CrystalRun')
  self.pad=route and route:FindFirstChild('ChargeIndicator')
 end
 local pad=self.pad
 if not pad then return end
 local progress=pad:GetAttribute('ChargeProgress')
 local camera=workspace.CurrentCamera
 if type(progress)~='number' or not camera or (camera.CFrame.Position-pad.Position).Magnitude>84 then
  if self.baseColor then self:hide() end
  return
 end
 if not self.baseColor then
  self.baseColor=pad.Color
  pad.Color=self.baseColor:Lerp(DARK,.88)
 end
 if not self.fill then
  local fill=Instance.new('Part')
  fill.Name='ChargeFill';fill.Anchored=true;fill.CanCollide=false;fill.CanTouch=false;fill.CanQuery=false;fill.CastShadow=false
  fill.TopSurface=Enum.SurfaceType.Smooth;fill.BottomSurface=Enum.SurfaceType.Smooth
  self.fill=fill
 end
 local fill=self.fill
 local shown=self.shown or progress
 if self.reducedMotion() or progress<shown then shown=progress
 else shown+=(progress-shown)*(1-math.exp(-math.min(dt,.1)*18)) end
 if math.abs(progress-shown)<.002 then shown=progress end
 if shown~=self.shown then
  local width=math.max(.05,pad.Size.X-.32)
  local length=math.max(.05,width*math.clamp(shown,0,1))
  fill.Size=Vector3.new(length,.04,math.max(.05,pad.Size.Z-.32))
  fill.CFrame=pad.CFrame*CFrame.new((length-width)*.5,pad.Size.Y*.5+.022,0)
  self.shown=shown
 end
 if not fill.Parent then
  fill.Material=pad.Material;fill.Color=self.baseColor;fill.Parent=self.parent
 end
end

function View:destroy()
 self:hide()
 if self.fill then self.fill:Destroy();self.fill=nil end
end
return View
