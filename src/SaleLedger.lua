-- The receipt is presentation. Only the committed server sale moves money.
local Ledger={};Ledger.__index=Ledger
local WHITE=Color3.fromRGB(249,247,240)
local MONEY=Color3.fromRGB(113,246,146)
local function text(parent,name,contents,size,color,align)
 local label=Instance.new('TextLabel');label.Name=name;label.BackgroundTransparency=1
 label.Text=contents;label.TextSize=size;label.TextColor3=color;label.Font=Enum.Font.SourceSansBold
 label.TextStrokeTransparency=.65;label.TextXAlignment=align or Enum.TextXAlignment.Right
 label.TextTruncate=Enum.TextTruncate.AtEnd;label.ZIndex=3;label.Parent=parent
 return label
end
local function format(key,n)
 if key=='Money' then return '$'..tostring(n) end
 return (string.format('%.2f',n/100):gsub('0+$',''):gsub('%.$',''))
end
local function rowFor(parent,key)
 local cash=key=='Money'
 local color=cash and MONEY or Color3.fromRGB(table.unpack(Workshop.RESOURCE_COLORS[key]))
 local root=Instance.new('Frame');root.Name='Currency_'..key
 root.BackgroundTransparency=1;root.BorderSizePixel=0;root.ZIndex=2;root.Parent=parent
 local total=text(root,'RunningTotal',format(key,0),35,color)
 total.Position=UDim2.new(0,0,1,-41);total.Size=UDim2.new(1,-10,0,40)
 if not cash then
  local icon=text(root,'CurrencyIcon',key=='Stone' and '■' or '◆',13,color,Enum.TextXAlignment.Left)
  icon.Position=UDim2.new(0,9,1,-39);icon.Size=UDim2.fromOffset(15,36)
  total.Position=UDim2.new(0,25,1,-41);total.Size=UDim2.new(1,-35,0,40)
 end
 local terms=Instance.new('Frame');terms.BackgroundTransparency=1;terms.ClipsDescendants=true
 terms.Size=UDim2.new(1,-10,1,-44);terms.ZIndex=3;terms.Parent=root
 local bonus=Instance.new('Frame');bonus.Name='Modifier';bonus.BackgroundTransparency=1
 bonus.AnchorPoint=Vector2.new(.5,0);bonus.Size=UDim2.fromOffset(112,52)
 bonus.ZIndex=4;bonus.Visible=false;bonus.Parent=root
 local name=text(bonus,'Name','',16,WHITE,Enum.TextXAlignment.Center)
 name.Size=UDim2.new(1,0,0,20);name.ZIndex=4
 local multiplier=text(bonus,'Multiplier','',31,color,Enum.TextXAlignment.Center)
 multiplier.Position=UDim2.fromOffset(0,16);multiplier.Size=UDim2.new(1,0,0,36);multiplier.ZIndex=4
 return {key=key,root=root,terms=terms,total=total,color=color,history={},amount=0,bonus=bonus,bonusName=name,multiplier=multiplier}
end
function Ledger.new(gui,items)
 local keys={Money=true}
 for _,item in ipairs(items) do
  if item.resource and item.dust>0 then keys[item.resource]=true end
  if item.stoneUnits>0 then keys.Stone=true end
 end
 local panel=Instance.new('ScrollingFrame');panel.Name='SaleReceipt';panel.BackgroundTransparency=1;panel.ZIndex=2
 panel.ScrollBarThickness=0;panel.BorderSizePixel=0;panel.ScrollingDirection=Enum.ScrollingDirection.Y;panel.Parent=gui
 local self=setmetatable({panel=panel,rows={},order={},rules={}},Ledger)
 for _,key in ipairs({'Money',table.unpack(Workshop.RESOURCE_ORDER)}) do
  if keys[key] then
   local row=rowFor(panel,key)
   self.rows[key]=row;self.order[#self.order+1]=row
  end
 end
 return self
end
function Ledger:layout(x,y,width,height)
 self.panel.Position=UDim2.fromOffset(x,y);self.panel.Size=UDim2.fromOffset(width,height)
 local cols=math.min(#self.order,4,math.max(1,math.floor(width/99)))
 local bands=math.ceil(#self.order/cols)
 local lineHeight=width>=400 and 26 or 22
 local bandHeight=lineHeight*3+100
 local blockHeight=bands*bandHeight
 self.panel.CanvasSize=UDim2.fromOffset(0,blockHeight)
 local first=math.max(0,math.floor((height-blockHeight)*.45))
 local columnWidth=width/cols
 for i=1,bands do
  local rule=self.rules[i]
  if not rule then
   rule=Instance.new('Frame');rule.Name='AdditionRule';rule.BorderSizePixel=0
   rule.BackgroundColor3=WHITE;rule.BackgroundTransparency=.30;rule.ZIndex=3;rule.Parent=self.panel;self.rules[i]=rule
  end
  local count=math.min(cols,#self.order-(i-1)*cols)
  rule.Position=UDim2.fromOffset(0,first+i*bandHeight-43)
  rule.Size=UDim2.fromOffset(count*columnWidth-4,1);rule.Visible=true
 end
 for i=bands+1,#self.rules do self.rules[i].Visible=false end
 for i,row in ipairs(self.order) do
  row.root.Position=UDim2.fromOffset((i-1)%cols*columnWidth,first+math.floor((i-1)/cols)*bandHeight)
  row.root.Size=UDim2.fromOffset(columnWidth,bandHeight);row.lineHeight=lineHeight
  row.bonusWidth=math.min(112,columnWidth)
 end
end
function Ledger:stage(terms,now)
 for _,term in ipairs(terms) do
  local row=self.rows[term.key]
  if not row then continue end
  local history=row.history
  if history[1] then history[1].view.Text=history[1].effective end
  local nextLine=text(row.terms,'AdditionTerm','+ '..format(term.key,term.base),23,row.color)
  table.insert(history,1,{view=nextLine,y=7,at=now,from=7,effective=format(term.key,term.base+term.bonus)})
  if #history>3 then table.remove(history).view:Destroy() end
  for _,line in ipairs(history) do line.from=line.y;line.at=now end
 end
end
function Ledger:applyModifier(terms,now)
 for _,term in ipairs(terms) do
  local row=self.rows[term.key]
  if term.bonus>0 and row then
   local multiple=string.format('%.2f',1+term.bonus/term.base):gsub('0+$',''):gsub('%.$','')
   row.bonusName.Text=term.modifier;row.multiplier.Text=multiple..'×';row.modifierAt=now
  end
 end
end
function Ledger:add(terms,now)
 for _,term in ipairs(terms) do
  local row=self.rows[term.key]
  if row then
   row.history[1].view.Text='+ '..row.history[1].effective
   row.amount+=term.base+term.bonus;row.total.Text=format(row.key,row.amount);row.hitAt=now
  end
 end
end
function Ledger:finish(receipt,now)
 for _,row in ipairs(self.order) do
  row.amount=row.key=='Money' and (receipt.cash or 0) or ((receipt.resources or {})[row.key] or 0)
  row.total.Text=format(row.key,row.amount);row.hitAt=now
 end
end
function Ledger:update(now,reduced)
 for _,row in ipairs(self.order) do
  local height=row.lineHeight or 22
  for i,line in ipairs(row.history) do
   local t=reduced and 1 or math.clamp((now-line.at)/.19,0,1)
   line.y=line.from+(-(i-1)*height-line.from)*(1-(1-t)^3)
   line.view.Size=UDim2.new(1,0,0,height)
   line.view.Position=UDim2.new(0,0,1,line.y-height)
   line.view.TextSize=height-2;line.view.TextTransparency=i==1 and 0 or i==2 and .25 or .55
  end
  local impact=1-math.clamp((now-(row.hitAt or -100))/.24,0,1)
  row.total.TextSize=35+(reduced and 0 or math.floor(impact*5))
  row.total.TextColor3=row.color:Lerp(WHITE,impact*.8)
  local age=now-(row.modifierAt or -100)
  row.bonus.Visible=age<.36
  if row.bonus.Visible then
   local fade=math.min(math.clamp(age/.043,0,1),1-math.clamp((age-.19)/.17,0,1))
   row.bonus.Size=UDim2.fromOffset(row.bonusWidth or 105,52)
   row.bonus.Position=UDim2.new(.55,0,0,reduced and -3 or 6-14*math.clamp(age/.36,0,1))
   row.bonus.Rotation=reduced and -8 or -8-8*math.exp(-age*16)
   row.bonusName.TextTransparency=1-fade;row.multiplier.TextTransparency=1-fade
  end
 end
end
function Ledger:destroy() self.panel:Destroy() end
return Ledger
