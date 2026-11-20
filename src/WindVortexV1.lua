-- Pew's ground vortex, 29.997–33.7 s in Wind Moveset. All distances are in studs.
-- The authored rig is also the Edit pose. Only the cast clock crosses the network.
local Vortex = {}
Vortex.duration = 4.32
local NAME = "VERSION 1"
local TAU = 2 * math.pi
local Y = Vector3.yAxis
local v = Vector3.new
local ivory = Color3.fromRGB(255, 246, 213)
local paper = Color3.fromRGB(231, 221, 192)
local ink = Color3.fromRGB(62, 54, 46)
local vermilion = Color3.fromRGB(152, 12, 7)
local whiteSeq = ColorSequence.new(ivory)
local ashSeq = ColorSequence.new(ink, Color3.fromRGB(113, 102, 83))
local hotSeq = ColorSequence.new(Color3.fromRGB(255, 115, 39), vermilion)
local threadSeq = ColorSequence.new(paper)
local ERUPT = .91
local FINISH = 2.92
-- The largest opening, hollow crowns, and narrow lances do not have equal weights.
local strikes = {
 {0, 1, 1}, {.20, .82, .57}, {.39, .46, .48}, {.59, .37, .93}, {.79, .66, .45},
 {.99, .53, .66}, {1.07, .92, .88}, {1.27, .91, .70}, {1.47, .88, 1},
 {1.67, .78, .70}, {1.87, 1, .88},
}
local tells = {0, .102, .230, .322, .436, .548, .646}
local redTicks = {.222, .292, .365, .461, .526, .613, .68, .753}
local groups = {
 {"Pressure", 8}, {"Crown", 9}, {"Barbs", 16}, {"Talons", 21}, {"Column", 10},
 {"Skirt", 14}, {"Filaments", 6}, {"Splinters", 10},
}
local GRIT_COUNT, PLATE_COUNT = 26, 13
local function sat(x) return math.clamp(x, 0, 1) end
local function ease(x) return 1 - (1 - sat(x)) ^ 3 end
local function smooth(x)
 x = sat(x)
 return x * x * (3 - 2 * x)
end
local function polar(angle, radius, height)
 return v(math.cos(angle) * radius, height, math.sin(angle) * radius)
end
local function noise(i, salt)
 return (math.sin(i * 127.1 + salt * 311.7) * 43758.5453) % 1
end
local function axis(position, tangent)
 local x = tangent.Unit
 local z = x:Cross(math.abs(x.Y) > .96 and Vector3.zAxis or Y).Unit
 return CFrame.fromMatrix(position, x, z:Cross(x), z)
end
-- Quantize opacity only. Geometry is evaluated continuously against elapsed time.
local profiles, bandProfiles = {}, {}
for i = 0, 48 do
 local a = i / 48
 bandProfiles[i] = NumberSequence.new(1-a)
 profiles[i] = NumberSequence.new({
  NumberSequenceKeypoint.new(0, 1 - .04*a), NumberSequenceKeypoint.new(.12, 1 - .74*a),
  NumberSequenceKeypoint.new(.42, 1 - a), NumberSequenceKeypoint.new(.75, 1 - .88*a),
  NumberSequenceKeypoint.new(1, 1 - .02*a),
 })
end
local function hide(line)
 if line.b.Enabled then line.b.Enabled = false end
end
local function ribbon(line, p0, p1, d0, d1, w0, w1, opacity, color)
 if opacity < .012 then hide(line) return end
 line.a.CFrame = axis(p0, d0)
 line.z.CFrame = axis(p1, d1)
 local b = line.b
 b.CurveSize0, b.CurveSize1 = d0.Magnitude, d1.Magnitude
 b.Width0, b.Width1 = w0, w1
 local level = math.floor(sat(opacity) * 48 + .5)
 if level ~= line.level then b.Transparency = line.solid and bandProfiles[level] or profiles[level]; line.level = level end
 if line.color ~= color then
  b.Color = color
  b.LightEmission = (color == ashSeq or color == hotSeq) and .015 or .36
  line.color = color
 end
 b.Enabled = true
end
local function band(lines, radius, height, spin, width, opacity, tilt, color, broken)
 for i, line in ipairs(lines) do
  if opacity < .012 then hide(line) continue end
  local step = TAU / #lines
  local lo = spin + i * step
  local hi = lo + step * (broken and (.67 + .26 * noise(i, 4)) or 1.04)
  local handle = radius * 4/3 * math.tan((hi - lo)/4)
  local function point(a) return polar(a, radius, height + tilt * math.sin(a * 2 + .6)) end
  local function tangent(a) return v(-math.sin(a), 2 * tilt / radius * math.cos(a * 2 + .6), math.cos(a)) * handle end
  ribbon(line, point(lo), point(hi), tangent(lo), tangent(hi), width * .76,
   width * (broken and .23 or .95), opacity, color)
 end
end
function Vortex.bind(root)
 local origin = assert(root:FindFirstChild("VortexOrigin"))
 local rig = {origin = origin, grit = {}, plates = {}}
 for _, group in ipairs(groups) do
  local lines = {}
  for i = 1, group[2] do
   local b = assert(origin:FindFirstChild(group[1] .. i))
   lines[i] = {b = b, a = b.Attachment0, z = b.Attachment1, solid = group[1] == "Pressure"}
  end
  rig[group[1]] = lines
 end
 for i = 1, GRIT_COUNT do rig.grit[i] = root.Debris:FindFirstChild("Chip" .. i) end
 for i = 1, PLATE_COUNT do rig.plates[i] = root.Debris:FindFirstChild("Plate" .. i) end
 return rig
end

local function phase(t, events, duration)
 for i = #events, 1, -1 do
  if t >= events[i] then
   local u = (t - events[i]) / duration
   return i, u, u < 1 and (1 - smooth(u)) or 0
  end
 end
 return 0, 1, 0
end
local function renderRubble(rig, t)
 local base = rig.origin.CFrame
 for i, part in ipairs(rig.grit) do
  local born = ERUPT + noise(i, 2) * .22 + (i % 4 == 0 and .61 or 0)
  local age = t - born
  local endAt = 3.22 + .79 * noise(i, 7)
  if age < 0 or t > endAt then part.Transparency = 1 continue end
  local release = 2.70 + noise(i, 6) * .36
  local lift = ease(age / (.35 + .60 * noise(i, 3)))
  local drop = sat((t - release) / (endAt - release))
  local theta = i * 2.39996 + lift * .44 + age * .28
  local h = .22 + (4.2 + 15.5*noise(i, 1)) * lift * (1 - drop^2)
  local r = 2 + 6.8*noise(i, 8) + lift*(2 + 3*noise(i, 9)) + drop*3.3
  part.CFrame = base * CFrame.new(polar(theta, r, h)) * CFrame.Angles(i + age*1.6, age*1.4+i, i*.71+age*2)
  part.Transparency = 1 - smooth(age/.055) * (1 - smooth((drop-.62)/.38))
 end
 for i, part in ipairs(rig.plates) do
  local age = t - ERUPT - .07 * noise(i, 9)
  if age < 0 or t > Vortex.duration then part.Transparency = 1 continue end
  local a = TAU * i / #rig.plates + .34 * noise(i, 7)
  local lift = ease(age/.14)
  local settle = smooth((t-FINISH)/.37)
  local p = polar(a, 5.1 + 3.2 * noise(i, 5) + lift * 1.2, -.22 + lift * (.32 + .60 * noise(i, 3)) * (1-settle*.8))
  part.CFrame = base * CFrame.new(p) * CFrame.Angles(0,-a,0) * CFrame.Angles(.12,.70*(noise(i,3)-.5), lift*(.35+noise(i,4)*.48)*(1-.77*settle))
  part.Transparency = 1 - smooth(age/.09) * (1-smooth((t-3.66)/.66))
 end
end
function Vortex.pose(rig, t)
 local wind = t - ERUPT
 local index, age, breadth, height = 0, 10, 0, 0
 for i = #strikes, 1, -1 do
  local pulse = strikes[i]
  if wind >= pulse[1] then
   index, age, breadth, height = i, wind-pulse[1], pulse[2], pulse[3]
   break
  end
 end
 local life = smooth(wind/.08) * (1 - smooth((t-FINISH)/.34))
 local first = index == 1
 local expansion = ease(age/(first and .095 or .07))
 local flash = (1 - smooth(age/(first and .17 or .145))) * smooth((age+.012)/.032)
 local tid, tu, tell = phase(t, tells, .082)
 local rid, ru, red = phase(t, redTicks, .036)
 local charging = t >= 0 and t < .80
 local release = t - FINISH
 local rimR, rimH, rimW, rimA, rimTilt = 1, 0, .1, 0, 0
 local skirtR, skirtW, skirtA = 1, .1, 0
 local rimColor = whiteSeq
 if charging then
  local spike = red > .09
  local u = spike and ru or tu
  local beat = spike and rid or tid
  local chargeR = (spike and 3.0 or 5.9) + (1-sat(u))*(spike and 2 or 3)
  rimR, rimH = chargeR, (spike and 4.3 or 2.6) + (beat%3)*.63 + ease(u)*1.3
  rimW, rimA = spike and 1.65 or 1.10, spike and red or .91*tell
  rimColor = spike and hotSeq or whiteSeq
  skirtR, skirtW, skirtA = chargeR*.81, .40, .74*tell
 elseif index > 0 and release < 0 then
  rimR = (3.4 + 10.0*breadth) * (.57 + .62*expansion)
  rimH = (3 + 8.6*height) * (.44 + .84*expansion)
  rimW, rimA, rimTilt = (first and 1.75 or 1.12)*(.55+.65*breadth), flash, .35+.7*height
  skirtR, skirtW = (first and 7.0 or 4.4) + (first and 11.4 or 6.8)*expansion, .62
  skirtA = .80*(1-smooth(age/.21))
 elseif release >= 0 then
  local u = sat(release/.56)
  skirtR, skirtW = 4.6 + 22.0*ease(u), (1.8-.94*u)
  skirtA = (1-smooth(u))*smooth((release+.017)/.048)
 end
 band(rig.Crown, rimR, rimH, t*2.0 + index*.57, rimW, rimA, rimTilt, rimColor, true)
 band(rig.Pressure, skirtR, .18+.20*skirtA, -t*1.2, skirtW, skirtA, .06, whiteSeq, false)

 -- Hooked teeth tear off the elevated rim while the lower bowl is still rising.
 for i,line in ipairs(rig.Barbs) do
  if charging or rimA < .025 or release >= 0 then hide(line) continue end
  local a = i*TAU/#rig.Barbs + t*2 + index*.57 + noise(i,3)*.19
  local j = noise(i,index)
  local h = rimH + rimTilt*math.sin(a*2+.6)
  local riser = (i%4==0 and -1 or 1) * (.75+4.0*j) * (.36+.76*expansion)
  ribbon(line,polar(a-.19,rimR*.97,h-.18),polar(a+.12,rimR+.20+j*.60,h+riser),
   polar(a+math.pi/2,rimR*.12,.11),polar(a+math.pi/2,.10,riser*.55),
   .57+.69*j,.025,rimA*.95,whiteSeq)
 end

 for i,line in ipairs(rig.Talons) do
  if not charging and (flash < .012 or release >= 0) then hide(line) continue end
  local a = i * 2.39996 + index*.91 + expansion*.15
  local j = noise(i,index)
  local color, alpha, foot, reach, top, width
  if charging then
   local isRed = red > .09
   local narrow = isRed and rid%3 ~= 1
   foot = narrow and 1.35 or rimR*.58
   reach = narrow and 2.4 or rimR
   top = rimH * (.68+.35*j) * (narrow and 2.0 or 1)
   width, alpha = isRed and 1.9 or .77, isRed and red or tell*.57
   color = isRed and (i%4==0 and ashSeq or hotSeq) or threadSeq
  else
   foot = (3.1+2.9*j) * (.76+.32*expansion)
   reach = (5.2 + 6.5*breadth + 3.4*j) * (.47+.63*expansion)
   top = (6.4 + 13.6*height) * (.32+.85*j) * (.30+.77*expansion)
   width = (first and 2.85 or 1.75)*(.48 + .90*j)
   color, alpha = i%6==0 and ashSeq or whiteSeq, flash*(.71+.29*j)
  end
  local p0, p1 = polar(a,foot,.16), polar(a+.38,reach,top)
  -- A heavy low hook bends into a long, razor-thin tip.
  ribbon(line,p0,p1,polar(a+.90,reach*.40,top*.07),
   polar(a+1.17,reach*.15,top*.56),width,.035,alpha,color)
 end
 for i,line in ipairs(rig.Column) do
  if life < .012 then hide(line) continue end
  local a = i*2.39996 + wind*1.4
  local j = noise(i,7)
  local climb = ease(age/.14)
  local r = 1.25 + j * 3.2
  local top = (8+14*j)*(.66 + .42*climb)
  local width = (.22 + (1-breadth)*1.55) * (1.22-j*.5)
  ribbon(line,polar(a,r*.55,.17),polar(a+.65,r*(1.1+climb*.4),top),
   polar(a-.64,r*.5,top*.22),polar(a+1.62,r*.7,top*.49),width,.035,
   life*(.075+.63*flash*(1.14-breadth*.60)),threadSeq)
 end
 for i,line in ipairs(rig.Skirt) do
  if life < .012 then hide(line) continue end
  local a=i*2.39996 + .11*wind
  local j=noise(i,1)
  local kick = .4 + .6*flash
  ribbon(line,polar(a,4.7+j,.17),polar(a+.25,7.9+2.8*j,1.6+2.7*j+kick*.9),
   polar(a+.77,1.4,.03),polar(a+.62,1.8,1.6),1.0+j,.09,life*(.29+.22*j),ashSeq)
 end
 for i,line in ipairs(rig.Splinters) do
  local u=(age-noise(i,2)*.055)/.21
  if release >= 0 or u < 0 or u >= 1 then hide(line) continue end
  local a=i*2.39996 + index*1.71
  local e=ease(u)
  local speed=5+4*noise(i,6)
  local r=5+speed*e
  local h=1+e*(1+3*noise(i,5))
  ribbon(line,polar(a,r-2*(1-u),h-.6),polar(a,r+.3,h+.18),polar(a,.6,.26),
   polar(a,.3,.06),.22*(1-u)+.035,.02,.82*(1-smooth(u)),whiteSeq)
 end
 for i,line in ipairs(rig.Filaments) do
  local tail = smooth((t-2.78)/.17) * (1-smooth((t-3.18)/.51))
  if tail < .012 then hide(line) continue end
  local s = t - 2.78
  local a = i*TAU/#rig.Filaments + s*2.05
  local r = 3+i*.56 + ease(s/.73)*3.2
  local h = 3+i*.76+s*4.4
  ribbon(line,polar(a,r,.65+s),polar(a+2.64,r*.62,h),
   polar(a+math.pi/2,r*1.40,.4),polar(a+2.64+math.pi/2,r*1.17,h*.38),
   .28,.065,tail*.47,threadSeq)
 end
 renderRubble(rig,t)
end

local function clear(rig)
 for _,g in ipairs(groups) do for _,line in ipairs(rig[g[1]]) do hide(line) end end
 for _,part in ipairs(rig.grit) do part.Transparency=1 end
 for _,part in ipairs(rig.plates) do part.Transparency=1 end
end
local dustBeats = {{.91,12,20},{1.30,4,6},{1.70,4,6},{2.18,5,7},{2.39,5,9},{2.78,5,7},{2.94,12,16}}
function Vortex.mount(scriptOwner)
 local run = game:GetService("RunService")
 local model, rig, clockChanged, frame
 local function detach()
  if frame then frame:Disconnect(); frame=nil end
  if clockChanged then clockChanged:Disconnect(); clockChanged=nil end
  model, rig=nil,nil
 end
 local function attach(root)
  if root.Name ~= NAME or not root:IsA("Model") or root:GetAttribute("WindVortexVersion") ~= 1 then return end
  detach()
  model,rig=root,Vortex.bind(root)
  local function start()
   if frame then frame:Disconnect(); frame=nil end
   clear(rig)
   local clock=root:GetAttribute("CastAt")
   if type(clock)~="number" or workspace:GetServerTimeNow()-clock>=Vortex.duration then return end
   local previous=-1
   local function draw()
    local t=workspace:GetServerTimeNow()-clock
    if t<0 then return end
    if t>=Vortex.duration then
     clear(rig)
     if frame then frame:Disconnect(); frame=nil end
     return
    end
    Vortex.pose(rig,t)
    for _,cue in ipairs(dustBeats) do
     if previous<cue[1] and t>=cue[1] and t-cue[1]<.12 then
      rig.origin.DustShelf:Emit(cue[2]); rig.origin.StoneGrit:Emit(cue[3])
     end
    end
    previous=t
   end
   frame=run.RenderStepped:Connect(draw)
   draw()
  end
  clockChanged=root:GetAttributeChangedSignal("CastAt"):Connect(start)
  start()
 end
 local added=workspace.ChildAdded:Connect(attach)
 local removed=workspace.ChildRemoved:Connect(function(child) if child==model then detach() end end)
 local root=workspace:FindFirstChild(NAME)
 if root then attach(root) end
 scriptOwner.Destroying:Once(function() added:Disconnect(); removed:Disconnect(); detach() end)
end
-- One static set of layers lives in Workspace and can be inspected in Edit.
Vortex.groups, Vortex.gritCount, Vortex.plateCount = groups, GRIT_COUNT, PLATE_COUNT
return Vortex
