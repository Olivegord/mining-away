-- One contextual action, anchored above the actual rendered target.
local V={};V.__index=V
function V.new(gui,parent,activate)
 local billboard=Instance.new('BillboardGui');billboard.Name='FieldInteraction'
 billboard.Size=UDim2.fromOffset(190,48);billboard.AlwaysOnTop=true;billboard.LightInfluence=0
 billboard.Enabled=false;billboard.Active=true;billboard.Parent=gui.Parent
 local button=Instance.new('TextButton');button.Size=UDim2.fromScale(1,1);button.BackgroundColor3=Color3.fromRGB(25,29,35)
 button.BackgroundTransparency=.08;button.BorderSizePixel=0;button.Text='';button.Parent=billboard
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.new(1,1,1);stroke.Transparency=.25;stroke.Thickness=1.5;stroke.Parent=button
 local key=Instance.new('TextLabel');key.Position=UDim2.fromOffset(7,7);key.Size=UDim2.fromOffset(34,34)
 key.BackgroundColor3=Color3.fromRGB(246,248,250);key.TextColor3=Color3.fromRGB(25,29,35)
 key.BorderSizePixel=0;key.Font=Enum.Font.GothamBold;key.TextSize=20;key.Parent=button
 local kc=Instance.new('UICorner');kc.CornerRadius=UDim.new(0,5);kc.Parent=key
 local caption=Instance.new('TextLabel');caption.Position=UDim2.fromOffset(49,0);caption.Size=UDim2.new(1,-55,1,0)
 caption.BackgroundTransparency=1;caption.TextColor3=Color3.new(1,1,1);caption.Font=Enum.Font.GothamBold
 caption.TextSize=17;caption.TextXAlignment=Enum.TextXAlignment.Left;caption.Parent=button
 local anchor=Instance.new('Part');anchor.Name='InteractionAnchor';anchor.Anchored=true;anchor.Transparency=1
 anchor.CanQuery=false;anchor.CanTouch=false;anchor.CanCollide=false;anchor.Size=Vector3.one*.1;anchor.Parent=parent
 local highlight=Instance.new('Highlight');highlight.Name='InteractionTarget';highlight.FillColor=Color3.new(1,1,1)
 highlight.OutlineColor=Color3.new(1,1,1);highlight.FillTransparency=.88;highlight.OutlineTransparency=0
 highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Enabled=false;highlight.Parent=parent
 local self=setmetatable({gui=billboard,key=key,caption=caption,anchor=anchor,highlight=highlight,parent=parent},V)
 self.connection=button.Activated:Connect(activate)
 self.ownerConnection=gui.Destroying:Connect(function() self:destroy() end)
 return self
end
function V:show(action,target,point,height,key,alreadyHighlighted)
 self.gui.Enabled=action~=nil and point~=nil
 self.highlight.Enabled=false;self.highlight.Adornee=nil;self.point=nil
 if not self.gui.Enabled then return end
 local camera=workspace.CurrentCamera
 if camera then local _,visible=camera:WorldToViewportPoint(point);if not visible then self.gui.Enabled=false;return end end
 self.point=point;self.anchor.Position=point
 self.gui.Adornee=self.anchor;self.gui.StudsOffsetWorldSpace=Vector3.yAxis*((height or 0)*.5+1.3)
 self.key.Text=key;self.caption.Text=action
 if target and not alreadyHighlighted then self.highlight.Adornee=target;self.highlight.Enabled=true end
end
function V:select()
 if not self.point then return end
 local player=game:GetService('Players').LocalPlayer
 local reduced=player and (player:GetAttribute('ReducedEffects') or player:GetAttribute('MA_ReducedEffects'))
 local p=Instance.new('Part');p.Name='InteractionSelection';p.Size=Vector3.one*.1;p.Position=self.point
 p.Anchored=true;p.Transparency=1;p.CanQuery=false;p.CanTouch=false;p.CanCollide=false;p.Parent=self.parent
 local e=Instance.new('ParticleEmitter');e.Texture='rbxasset://textures/particles/sparkles_main.dds'
 e.Color=ColorSequence.new(Color3.new(1,1,1));e.LightEmission=.7;e.Rate=0
 e.Lifetime=NumberRange.new(.35,.65);e.Speed=NumberRange.new(3,7);e.Drag=5;e.SpreadAngle=Vector2.new(180,180)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.3,.18),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.6,.2),NumberSequenceKeypoint.new(1,1)})
 e.Parent=p;e:Emit(reduced and 3 or 14);game:GetService('Debris'):AddItem(p,1)
end
function V:destroy()
 if self.destroyed then return end;self.destroyed=true
 self.ownerConnection:Disconnect()
 self.connection:Disconnect();self.gui:Destroy();self.anchor:Destroy();self.highlight:Destroy()
end
return V
