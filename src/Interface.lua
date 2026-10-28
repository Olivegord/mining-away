-- Native Roblox interface kit. No uploaded art, gameplay state or persistence.
local U={}
local TweenService=game:GetService('TweenService')
U.palette={ink=Color3.fromRGB(27,59,68),panel=Color3.fromRGB(255,250,231),paper=Color3.fromRGB(240,234,210),
 text=Color3.fromRGB(27,59,68),muted=Color3.fromRGB(83,114,116),accent=Color3.fromRGB(255,190,78),
 mineral=Color3.fromRGB(87,216,186),line=Color3.fromRGB(39,78,85),danger=Color3.fromRGB(229,106,116),white=Color3.fromRGB(255,255,246)}
local C=U.palette
local function layer(parent) return parent:IsA('GuiObject') and parent.ZIndex+1 or 2 end
function U.corner(parent,radius)
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,radius or 12);c.Parent=parent;return c
end
function U.stroke(parent,color,width)
 local s=Instance.new('UIStroke');s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color or C.line;s.Thickness=width or 2;s.Parent=parent;return s
end
function U.frame(parent,pos,size,color)
 local f=Instance.new('Frame');f.Position=pos;f.Size=size;f.BackgroundColor3=color or C.panel;f.BorderSizePixel=0;f.ZIndex=layer(parent);f.Parent=parent;return f
end
function U.gradient(parent,color)
 local g=Instance.new('UIGradient');g.Color=ColorSequence.new(color:Lerp(C.white,.16),color);g.Rotation=90;g.Parent=parent;return g
end
function U.panel(parent,pos,size,color,radius)
 local f=U.frame(parent,pos,size,color or C.panel);U.corner(f,radius or 14);U.stroke(f,C.line,2.5)
 return f
end
function U.text(parent,pos,size,text,sizePx,color,bold)
 local t=Instance.new('TextLabel');t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.BorderSizePixel=0
 t.Text=text or '';t.TextColor3=color or C.text;t.TextSize=sizePx or 14;t.TextXAlignment=Enum.TextXAlignment.Left
 t.TextYAlignment=Enum.TextYAlignment.Center;t.Font=bold and Enum.Font.FredokaOne or Enum.Font.GothamMedium
 t.TextWrapped=true;t.ZIndex=layer(parent);t.Parent=parent;return t
end
function U.badge(parent,pos,size,text,color)
 local b=U.frame(parent,pos,size,(color or C.mineral):Lerp(C.white,.65));U.corner(b,8)
 local t=U.text(b,UDim2.fromOffset(6,2),UDim2.new(1,-12,1,-4),text,11,C.ink,true);t.TextXAlignment=Enum.TextXAlignment.Center
 return b
end
local bases=setmetatable({},{__mode='k'});local tweens=setmetatable({},{__mode='k'})
local reducedMotion=false
function U.setReducedMotion(enabled) reducedMotion=enabled==true end
local function paint(button,color,scale)
 if tweens[button] then for _,t in ipairs(tweens[button]) do t:Cancel() end end
 if reducedMotion then
  button.BackgroundColor3=color
  local uiScale=button:FindFirstChild('ButtonScale');if uiScale then uiScale.Scale=1 end
  tweens[button]=nil;return
 end
 local a=TweenService:Create(button,TweenInfo.new(.11,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=color})
 local uiScale=button:FindFirstChild('ButtonScale');local b=uiScale and TweenService:Create(uiScale,TweenInfo.new(.11),{Scale=scale or 1})
 tweens[button]={a,b};a:Play();if b then b:Play() end
end
function U.button(parent,pos,size,text,callback,color)
 local b=Instance.new('TextButton');b.Position=pos;b.Size=size;b.BackgroundColor3=color or C.mineral;b.BorderSizePixel=0
 b.Text=text;b.TextColor3=C.ink;b.TextSize=16;b.Font=Enum.Font.FredokaOne;b.TextWrapped=true;b.AutoButtonColor=false
 b.TextStrokeTransparency=1;b.ZIndex=layer(parent);b.Parent=parent;U.corner(b,10);U.stroke(b,C.line,2)
 U.gradient(b,b.BackgroundColor3)
 local highlight=U.frame(b,UDim2.fromOffset(8,3),UDim2.new(1,-16,0,2),C.white);highlight.BackgroundTransparency=.45;U.corner(highlight,1)
 local scale=Instance.new('UIScale');scale.Name='ButtonScale';scale.Parent=b
 local edge=U.frame(b,UDim2.new(0,6,1,-3),UDim2.new(1,-12,0,3),C.ink);edge.BackgroundTransparency=.72;U.corner(edge,2)
 bases[b]=b.BackgroundColor3
 b.MouseEnter:Connect(function() if b.Active then paint(b,bases[b]:Lerp(C.white,.14),1.025) end end)
 b.MouseLeave:Connect(function() if b.Active then paint(b,bases[b],1) end end)
 b.SelectionGained:Connect(function() if b.Active then paint(b,bases[b]:Lerp(C.white,.14),1.025) end end)
 b.SelectionLost:Connect(function() if b.Active then paint(b,bases[b],1) end end)
 b.MouseButton1Down:Connect(function() if b.Active then paint(b,bases[b]:Lerp(C.ink,.10),.975) end end)
 b.MouseButton1Up:Connect(function() if b.Active then paint(b,bases[b],1) end end)
 b.Activated:Connect(function() if b.Active and callback then callback() end end)
 b.Destroying:Connect(function() if tweens[b] then for _,t in ipairs(tweens[b]) do t:Cancel() end end;tweens[b]=nil;bases[b]=nil end)
 return b
end
function U.setEnabled(b,enabled)
 if tweens[b] then for _,t in ipairs(tweens[b]) do t:Cancel() end end
 b.Active=enabled;b.Selectable=enabled;b.BackgroundColor3=enabled and (b:GetAttribute('EnabledColor') or bases[b] or C.mineral) or C.paper
 b.TextColor3=enabled and C.ink or C.muted
 local s=b:FindFirstChild('ButtonScale');if s then s.Scale=1 end
 local g=b:FindFirstChildOfClass('UIGradient');if g then g.Color=ColorSequence.new(b.BackgroundColor3:Lerp(C.white,.16),b.BackgroundColor3) end
end
function U.icon(parent,kind,pos,size,color)
 local root=U.frame(parent,pos,size,C.white);root.BackgroundTransparency=1;root.Name='Icon_'..kind
 local tint=color or C.mineral
 local function shape(x,y,w,h,c,r,turn,outline)
  local p=U.frame(root,UDim2.fromScale(x,y),UDim2.fromScale(w,h),c);if r then local round=Instance.new('UICorner');round.CornerRadius=UDim.new(r,0);round.Parent=p end
  if turn then p.Rotation=turn end;if outline then U.stroke(p,C.ink,1.8) end;return p
 end
 if kind=='coin' then
  shape(.12,.12,.76,.76,tint,1,nil,true);shape(.25,.25,.5,.5,tint:Lerp(C.white,.28),1)
  local t=U.text(root,UDim2.fromScale(.18,.16),UDim2.fromScale(.64,.64),'C',math.max(16,size.X.Offset*.43),C.ink,true);t.TextXAlignment=Enum.TextXAlignment.Center
 elseif kind=='cargo' then
  shape(.30,.10,.4,.22,C.ink,.25);shape(.19,.24,.62,.62,tint,.16,nil,true)
  shape(.29,.55,.42,.20,tint:Lerp(C.ink,.18),.12);shape(.47,.28,.07,.55,C.white,.1)
 elseif kind=='cards' then
  shape(.15,.20,.42,.62,tint:Lerp(C.ink,.22),.1,-14,true);shape(.42,.17,.42,.62,tint,.1,10,true)
  shape(.51,.31,.23,.23,C.white,.12,45)
 elseif kind=='drone' or kind=='fleet' then
  shape(.03,.25,.27,.09,C.ink,.25,-25);shape(.70,.25,.27,.09,C.ink,.25,25)
  shape(.22,.24,.56,.52,tint,.16,nil,true);shape(.30,.46,.40,.10,C.ink,.1)
  shape(.36,.48,.26,.04,C.white,.1);shape(.47,.09,.06,.15,C.ink,.2)
 elseif kind=='combat' then
  shape(.38,.38,.24,.24,tint,.1,45,true)
  for _,v in ipairs({{.44,.08,.12,.22},{.44,.70,.12,.22},{.08,.44,.22,.12},{.70,.44,.22,.12}}) do shape(v[1],v[2],v[3],v[4],C.ink,.2) end
 elseif kind=='survival' then
  shape(.24,.14,.52,.60,tint,.32,nil,true);shape(.32,.50,.36,.36,tint,.1,45)
  shape(.45,.25,.10,.39,C.ink,.1);shape(.33,.39,.34,.10,C.ink,.1)
 elseif kind=='prestige' then
  shape(.24,.24,.52,.52,tint,.08,45,true);shape(.17,.37,.66,.26,tint,.08)
  shape(.45,.27,.10,.46,C.ink,.1);shape(.29,.45,.42,.10,C.ink,.1)
 elseif kind=='startup' then
  shape(.14,.14,.72,.72,tint,.9,nil,true);shape(.44,.28,.12,.30,C.ink,.1);shape(.44,.48,.27,.10,C.ink,.1,25)
 elseif kind=='flight' then
  shape(.22,.39,.56,.20,tint,.15,nil,true);shape(.34,.20,.15,.6,C.ink,.1,42);shape(.56,.27,.15,.54,C.ink,.1,-42)
 else
  shape(.23,.22,.40,.60,tint,.06,24,true);shape(.52,.36,.27,.43,tint:Lerp(C.white,.2),.06,38,true)
  shape(.29,.26,.09,.32,C.white,.05,24)
 end
 return root
end
return U
