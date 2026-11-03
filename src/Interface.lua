-- Shared native skin: dark backing, colorful studded surfaces and purposeful input feedback.
local U={}
local TweenService=game:GetService('TweenService')
local GuiService=game:GetService('GuiService')
U.palette={ink=Color3.fromRGB(9,14,30),panel=Color3.fromRGB(24,29,49),paper=Color3.fromRGB(43,53,80),
 text=Color3.fromRGB(250,252,255),muted=Color3.fromRGB(192,205,230),accent=Color3.fromRGB(28,145,224),
 mineral=Color3.fromRGB(30,159,97),line=Color3.fromRGB(8,12,27),danger=Color3.fromRGB(217,49,76),white=Color3.fromRGB(255,255,255)}
local C=U.palette
local bases=setmetatable({},{__mode='k'});local tweens=setmetatable({},{__mode='k'});local enabledStates=setmetatable({},{__mode='k'})
local function buttonText(color)
 local brightness=color.R*.2126+color.G*.7152+color.B*.0722
 return brightness>.72 and C.ink or C.white
end
local function layer(parent) return parent:IsA('GuiObject') and parent.ZIndex+1 or 2 end
function U.corner(parent,radius)
 local c=parent:FindFirstChildOfClass('UICorner') or Instance.new('UICorner');c.CornerRadius=UDim.new(0,radius or 12);c.Parent=parent;return c
end
function U.stroke(parent,color,width)
 local s=parent:FindFirstChildOfClass('UIStroke') or Instance.new('UIStroke');s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color or C.line;s.Thickness=width or 2;s.Parent=parent;return s
end
function U.frame(parent,pos,size,color)
 local f=Instance.new('Frame');f.Position=pos;f.Size=size;f.BackgroundColor3=color or C.panel;f.BorderSizePixel=0;f.ZIndex=layer(parent);f.Parent=parent;return f
end
function U.gradient(parent,_color)
 local g=parent:FindFirstChildOfClass('UIGradient') or Instance.new('UIGradient');g.Name='SurfaceGradient';g.Rotation=90
 g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.38,Color3.fromRGB(242,242,242)),ColorSequenceKeypoint.new(1,Color3.fromRGB(180,180,180))});g.Enabled=true;g.Parent=parent;return g
end
function U.unskin(root)
 local texture=root:FindFirstChild('StudSurface');if texture then texture:Destroy() end
 local gradient=root:FindFirstChildOfClass('UIGradient');if gradient then gradient:Destroy() end
end
function U.skin(root,color,radius,textureOpacity)
 color=color or C.panel;radius=radius or 12
 root.BackgroundColor3=color;root.BackgroundTransparency=0;U.corner(root,radius)
 local edge=U.stroke(root,color:Lerp(C.ink,.72),2);edge.Transparency=0
 U.gradient(root,color)
 if root:IsA('GuiButton') then root:SetAttribute('EnabledColor',color);bases[root]=color end
 local texture=root:FindFirstChild('StudSurface')
 if not texture then
  texture=Instance.new('CanvasGroup');texture.Name='StudSurface';texture.BackgroundTransparency=1;texture.Position=UDim2.fromOffset(2,2);texture.Size=UDim2.new(1,-4,1,-4);texture.ZIndex=root.ZIndex+1;texture.Active=false;texture.Parent=root
  U.corner(texture,math.max(1,radius-2))
  local function fit()
   if not texture.Parent then return end
   local bands=math.clamp(math.ceil(math.max(root.Size.Y.Offset,root.AbsoluteSize.Y)/80),1,10)
   for i=#texture:GetChildren(),bands do -- UICorner is the first child.
    local tile=Instance.new('ImageLabel');tile.Name='StudBand';tile.BackgroundTransparency=1;tile.Position=UDim2.fromOffset(0,(i-1)*80);tile.Size=UDim2.new(1,0,0,80)
    tile.Image='rbxasset://textures/studs.dds';tile.ScaleType=Enum.ScaleType.Tile;tile.TileSize=UDim2.fromOffset(20,320);tile.ImageTransparency=textureOpacity or .94;tile.ZIndex=texture.ZIndex;tile.Parent=texture
   end
  end
  fit();root:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit)
 end
 return root
end
function U.panel(parent,pos,size,color,radius)
 local tint=color or C.panel
 if tint.R*.2126+tint.G*.7152+tint.B*.0722>.54 then tint=C.panel:Lerp(tint,.44) end
 local f=U.frame(parent,pos,size,tint);U.skin(f,tint,radius or 14);f.Active=true;return f
end
function U.text(parent,pos,size,text,sizePx,color,bold)
 local t=Instance.new('TextLabel');t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.BorderSizePixel=0
 t.Text=text or '';t.TextColor3=color or C.text;t.TextSize=sizePx or 16;t.TextXAlignment=Enum.TextXAlignment.Left
 t.TextYAlignment=Enum.TextYAlignment.Center;t.Font=bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
 t.TextWrapped=true;t.ZIndex=layer(parent)+1;t.Parent=parent;return t
end
function U.badge(parent,pos,size,text,color)
 local b=U.panel(parent,pos,size,(color or C.mineral):Lerp(C.panel,.35),8)
 local t=U.text(b,UDim2.fromOffset(6,2),UDim2.new(1,-12,1,-4),text,12,C.text,true);t.TextXAlignment=Enum.TextXAlignment.Center
 return b
end
local function quiet()
 local reduced=false;pcall(function() reduced=GuiService.ReducedMotionEnabled end)
 local player=game:GetService('Players').LocalPlayer
 return reduced or (player and (player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true))
end
local function paint(button,color,scale)
 if tweens[button] then for _,t in ipairs(tweens[button]) do t:Cancel() end end
 local a=TweenService:Create(button,TweenInfo.new(.13,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=color})
 local uiScale=button:FindFirstChild('ButtonScale');local b=uiScale and TweenService:Create(uiScale,TweenInfo.new(.13),{Scale=quiet() and 1 or scale or 1})
 tweens[button]={a,b};a:Play();if b then b:Play() end
end
function U.button(parent,pos,size,text,callback,color)
 local b=Instance.new('TextButton');b.Position=pos;b.Size=size;b.BackgroundColor3=color or C.mineral;b.BorderSizePixel=0
 b.Text=text;b.TextColor3=buttonText(b.BackgroundColor3);b.TextSize=16;b.Font=Enum.Font.SourceSansBold;b.TextWrapped=true;b.AutoButtonColor=false
 b.TextStrokeColor3=C.ink;b.TextStrokeTransparency=.65;b.ZIndex=layer(parent);b.Parent=parent;U.skin(b,b.BackgroundColor3,11,.92)
 local scale=Instance.new('UIScale');scale.Name='ButtonScale';scale.Parent=b
 local function base() return b:GetAttribute('EnabledColor') or bases[b] or C.mineral end
 local function focus() if b.Active then paint(b,base():Lerp(C.white,.16),1.025) end end
 local function rest() if b.Active then paint(b,base(),1) end end
 b.MouseEnter:Connect(focus);b.MouseLeave:Connect(rest);b.SelectionGained:Connect(focus);b.SelectionLost:Connect(rest)
 b.MouseButton1Down:Connect(function() if b.Active then paint(b,base():Lerp(C.ink,.16),.975) end end)
 b.MouseButton1Up:Connect(focus)
 b.Activated:Connect(function() if b.Active and callback then callback() end end)
 b.Destroying:Connect(function() if tweens[b] then for _,t in ipairs(tweens[b]) do t:Cancel() end end;tweens[b]=nil;bases[b]=nil;enabledStates[b]=nil end)
 return b
end
function U.setEnabled(b,enabled)
 enabled=enabled==true
 local color=b:GetAttribute('EnabledColor') or bases[b] or C.mineral
 local state=enabledStates[b]
 if state and state.enabled==enabled and state.color==color then return end
 enabledStates[b]={enabled=enabled,color=color}
 if tweens[b] then for _,t in ipairs(tweens[b]) do t:Cancel() end end
 b.Active=enabled;b.Selectable=enabled;b.BackgroundColor3=enabled and color or C.paper
 b.TextColor3=enabled and buttonText(color) or C.muted
 local s=b:FindFirstChild('ButtonScale');if s then s.Scale=1 end
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
  local t=U.text(root,UDim2.fromScale(.18,.16),UDim2.fromScale(.64,.64),'C',size.X.Offset*.43,C.ink,true);t.TextXAlignment=Enum.TextXAlignment.Center
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

