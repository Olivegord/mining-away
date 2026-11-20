-- One clear cutting axis, with asymmetrical ink shapes drawn in its projected
-- plane. The signed profiles are the silhouette; only their offsets breathe.
local V={}
V.Gold=Color3.fromRGB(255,234,47)
local cyan=Color3.fromRGB(44,242,234)
local ivory=Color3.fromRGB(255,255,179)
local navy=Color3.fromRGB(8,10,37)
local plum=Color3.fromRGB(31,5,25)
local function key(t,c) return ColorSequenceKeypoint.new(t,c) end
local spectrum=ColorSequence.new({key(0,V.Gold),key(.13,V.Gold),key(.32,ivory),
 key(.52,Color3.fromRGB(255,164,42)),key(.76,V.Gold),key(.89,Color3.fromRGB(144,255,89)),key(1,cyan)})
local function path(root,name,colors,opacity,lit,segments)
 local a=Instance.new('Attachment');a.Parent=root
 local b=Instance.new('Attachment');b.Parent=root
 local v=Instance.new('Beam');v.Name=name;v.Attachment0=a;v.Attachment1=b;v.FaceCamera=true
 v.Color=colors;v.Transparency=NumberSequence.new(opacity);v.LightEmission=lit and .88 or 0
 v.LightInfluence=0;v.Brightness=lit and 1.65 or 1;v.Segments=segments or 1;v.Enabled=false;v.Parent=root
 return {a=a,b=b,beam=v}
end
local details=0
local DETAIL_LIMIT=4
local outlines={
 -- fraction along the ray, signed offset, width. The three cuts on the
 -- opposite side leave clear gaps; the silhouette never becomes a second ray.
 {navy,{{.035,-.19,.015},{.15,-.27,.52},{.32,-.49,.80},{.53,-.42,.60},{.71,-.28,.20},{.86,-.06,0}}},
 {navy,{{.21,.18,.03},{.33,.53,.38},{.42,.86,.24},{.43,.68,.10},{.61,1.24,0}}},
 {plum,{{.45,.76,0},{.53,.87,.22},{.55,.77,.035},{.69,1.19,0}}},
 {plum,{{.58,-.47,0},{.72,-.52,.23},{.76,-.32,.045},{.87,-.39,0}}},
 {cyan,{{.11,.03,0},{.23,.35,.18},{.31,.42,0}}},
 {ivory,{{.02,.18,.03},{.08,.32,.32},{.19,.46,0}}},
}
local function new(parent)
 local root=Instance.new('Part');root.Name='Inkbeam';root.Size=Vector3.one*.025
 root.Anchored=true;root.CanQuery=false;root.CanTouch=false;root.CanCollide=false;root.CastShadow=false
 root.Transparency=1;root.Parent=parent
 local r={root=root,ink={},tip={},layers={
  path(root,'InkbeamGlow',spectrum,.76,true,20),
  path(root,'InkbeamColor',spectrum,.12,true,20),
  path(root,'InkbeamHotEdge',ColorSequence.new(ivory,V.Gold),.28,true,8),
 }}
 root.Destroying:Connect(function()
  if r.detailed then r.detailed=false;details-=1 end
 end)
 return r
end
function V.destroy(r)
 if r then r.root:Destroy() end
end
local function set(path,a,b,w0,w1,fade,opacity)
 path.a.Position=a;path.b.Position=b
 path.beam.Width0=w0;path.beam.Width1=w1
 path.beam.Enabled=fade>.006 and (b-a).Magnitude>.009
 -- Cache stable active opacity. Only a start/stop envelope updates it.
 local alpha=1-(1-opacity)*fade
 if path.alpha~=alpha then path.alpha=alpha;path.beam.Transparency=NumberSequence.new(alpha) end
end
function V.draw(r,parent,from,to,width,age,detail)
 local delta=to-from;local length=delta.Magnitude
 if length<.02 or width<=.001 then V.destroy(r);return nil end
 r=r or new(parent)
 r.root.CFrame=CFrame.new(from)
 local axis=delta/length
 local camera=workspace.CurrentCamera
 local eye=camera and camera.CFrame.Position-(from+to)*.5 or Vector3.zAxis
 local side=axis:Cross(eye)
 if side.Magnitude<.01 then side=axis:Cross(math.abs(axis.Y)>.95 and Vector3.zAxis or Vector3.yAxis) end
 side=side.Unit
 local envelope=math.clamp(width,0,1)
 local scale=math.min(1.25,length*.30)*envelope
 local impulse=1+.28*math.exp(-math.max(0,age)*11)
 local clock=math.max(0,age)
 local heat=detail and (1+.045*math.sin(clock*10)) or 1
 local front=side:Cross(axis)*math.min(.08,length*.016)
 set(r.layers[1],Vector3.zero,delta,1.27*scale*heat*impulse,.12*scale,envelope,.76)
 set(r.layers[2],front,delta,.53*scale*heat*impulse,.039*scale,envelope,.12)
 set(r.layers[3],front*2+side*.11*scale,delta*.59+front*2,.115*scale,.002,envelope,.28)
 if not detail and r.detailed then
  r.detailed=false;details-=1
  for _,row in ipairs(r.ink) do
   for _,segment in ipairs(row) do segment.beam:Destroy();segment.a:Destroy();segment.b:Destroy() end
  end
  table.clear(r.ink)
  for _,ray in ipairs(r.tip) do ray.beam:Destroy();ray.a:Destroy();ray.b:Destroy() end
  table.clear(r.tip)
 end
 if detail and (r.detailed or details<DETAIL_LIMIT) then
  if not r.detailed then
   r.detailed=true;details+=1
   for i=1,4 do r.tip[i]=path(r.root,'InkbeamContactStar',ColorSequence.new(ivory,V.Gold),.12,true) end
   for i,outline in ipairs(outlines) do
    local row={};r.ink[i]=row
    for j=2,#outline[2] do row[j-1]=path(r.root,'InkbeamContour',ColorSequence.new(outline[1]),.04,i>=5,i==1 and 5 or 1) end
   end
  end
  local star=scale*(.29+.16*math.exp(-clock*12))
  local hub=delta-axis*.075+front
  for i,ray in ipairs(r.tip) do
   local skew=(i==1 or i==3) and axis*.76+side*.64 or axis*.62-side*.78
   local extent=star*(i<=2 and 1 or -.54)
   local point=hub+skew*extent
   -- Tuck the tips before the surface rather than piercing the target.
   point-=axis*math.max(0,point:Dot(axis)-length+.025)
   set(ray,hub,point,star*.35,0,envelope,.16)
  end
  for i,outline in ipairs(outlines) do
   local points=outline[2]
   local function at(p)
    local wave=math.sin(clock*4.1-p[1]*7+i*.8)*.087
    return delta*p[1]+side*((p[2]+wave)*scale*impulse)+front*(i>=5 and 2.4 or .44)
   end
   local a=at(points[1])
   for j=2,#points do
    local b=at(points[j])
    local segment=r.ink[i][j-1]
    set(segment,a,b,points[j-1][3]*scale,points[j][3]*scale,envelope,i>=5 and .12 or .03)
    -- The big dark sweep is one smooth shape; the offshoots keep hard bends.
    if i==1 and segment.beam.Enabled then
     local before=at(points[math.max(1,j-2)])
     local after=at(points[math.min(#points,j+1)])
     local startTangent=(b-before).Unit
     local endTangent=(after-a).Unit
     local up=front.Unit
     segment.a.CFrame=CFrame.fromMatrix(a,startTangent,up,startTangent:Cross(up))
     segment.b.CFrame=CFrame.fromMatrix(b,endTangent,up,endTangent:Cross(up))
     local handle=(b-a).Magnitude/3
     segment.beam.CurveSize0=handle;segment.beam.CurveSize1=handle
    end
    a=b
   end
  end
 end
 return r
end
return V
