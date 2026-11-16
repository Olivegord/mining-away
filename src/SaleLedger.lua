-- The receipt is presentation. Only the committed server sale moves money.
local Ledger={};Ledger.__index=Ledger
local WHITE=Color3.fromRGB(249,247,240)
local MUTED=Color3.fromRGB(178,184,180)
local MONEY=Color3.fromRGB(113,246,146)
local function text(parent,contents,size,color,align)
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1
 label.Text=contents;label.TextSize=size;label.TextColor3=color;label.Font=Enum.Font.SourceSansBold
 label.TextXAlignment=align or Enum.TextXAlignment.Left
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
 root.BackgroundColor3=Color3.fromRGB(19,24,25);root.BackgroundTransparency=.16;root.BorderSizePixel=0
 root.ZIndex=2;root.ClipsDescendants=true;root.Parent=parent
 local rounding=Instance.new('UICorner');rounding.CornerRadius=UDim.new(0,8);rounding.Parent=root
 local icon=text(root,cash and '$' or '◆',21,color,Enum.TextXAlignment.Center)
 icon.Name='CurrencyIcon';icon.Position=UDim2.fromOffset(7,4);icon.Size=UDim2.fromOffset(24,24)
 if cash then
  icon.BackgroundColor3=Color3.fromRGB(36,76,52);icon.BackgroundTransparency=.18
  local rim=Instance.new('UICorner');rim.CornerRadius=UDim.new(.5,0);rim.Parent=icon
 end
 local title=text(root,cash and 'Money' or Workshop.RESOURCE_NAMES[key],16,color)
 title.Position=UDim2.fromOffset(36,5);title.Size=UDim2.new(1,-45,0,22)
 local rule=Instance.new('Frame');rule.BackgroundColor3=color;rule.BackgroundTransparency=.5;rule.BorderSizePixel=0
 rule.Position=UDim2.new(0,9,1,-31);rule.Size=UDim2.new(1,-18,0,1);rule.ZIndex=3;rule.Parent=root
 local caption=text(root,'Total',14,MUTED)
 caption.Position=UDim2.new(0,10,1,-29);caption.Size=UDim2.fromOffset(40,28)
 local total=text(root,format(key,0),29,WHITE,Enum.TextXAlignment.Right);total.Name='RunningTotal'
 total.Position=UDim2.new(0,48,1,-30);total.Size=UDim2.new(1,-59,0,30)
 local terms=Instance.new('Frame');terms.BackgroundTransparency=1;terms.ClipsDescendants=true
 terms.Position=UDim2.fromOffset(7,28);terms.Size=UDim2.new(1,-18,1,-60);terms.ZIndex=3;terms.Parent=root
 return {key=key,root=root,terms=terms,total=total,color=color,history={},amount=0}
end
function Ledger.new(gui,items)
 local keys={Money=true}
 for _,item in ipairs(items) do
  if item.resource and item.dust>0 then keys[item.resource]=true end
  if item.stoneUnits>0 then keys.Stone=true end
 end
 local panel=Instance.new('Frame');panel.Name='SaleReceipt';panel.BackgroundTransparency=1;panel.ZIndex=2;panel.Parent=gui
 local header=text(panel,'Sale receipt',29,WHITE);header.Size=UDim2.new(1,0,0,31)
 local progress=text(panel,'Review your backpack',16,MUTED);progress.Position=UDim2.fromOffset(0,33);progress.Size=UDim2.new(1,0,0,21)
 local cards=Instance.new('ScrollingFrame');cards.Name='Currencies';cards.BackgroundTransparency=1
 cards.BorderSizePixel=0;cards.ScrollBarThickness=4;cards.ScrollBarImageColor3=MUTED;cards.ScrollingDirection=Enum.ScrollingDirection.Y
 cards.Position=UDim2.fromOffset(0,56);cards.Size=UDim2.new(1,0,1,-56);cards.ZIndex=2;cards.Parent=panel
 local self=setmetatable({panel=panel,header=header,progress=progress,cards=cards,rows={},order={},count=#items,added=0},Ledger)
 for _,key in ipairs({'Money',table.unpack(Workshop.RESOURCE_ORDER)}) do
  if keys[key] then
   local row=rowFor(cards,key)
   self.rows[key]=row;self.order[#self.order+1]=row
  end
 end
 return self
end
function Ledger:layout(x,y,width,height)
 self.panel.Position=UDim2.fromOffset(x,y);self.panel.Size=UDim2.fromOffset(width,height)
 local cols=(width>=285 and #self.order>2) and 2 or 1
 local bands=1+math.ceil((#self.order-1)/cols)
 local cardHeight=math.clamp(math.floor((height-56-(bands-1)*7)/bands),105,140)
 self.cards.CanvasSize=UDim2.fromOffset(0,bands*(cardHeight+7)-7)
 local columnWidth=(width-6-(cols-1)*8)/cols
 for i,row in ipairs(self.order) do
  local col=i==1 and 0 or (i-2)%cols
  local band=i==1 and 0 or 1+math.floor((i-2)/cols)
  row.root.Position=UDim2.fromOffset(col*(columnWidth+8),band*(cardHeight+7))
  row.root.Size=UDim2.fromOffset(i==1 and width-6 or columnWidth,cardHeight)
  row.lineHeight=math.clamp(math.floor((cardHeight-60)/2),21,25)
 end
end
function Ledger:stage(terms,now)
 for _,term in ipairs(terms) do
  local row=self.rows[term.key]
  if not row then continue end
  local history=row.history
  local nextLine=text(row.terms,'+ '..format(term.key,term.base),18,row.color,Enum.TextXAlignment.Right)
  nextLine.Name='AdditionTerm'
  local previous=history[1]
  if previous and previous.effective then
   previous.view.Text=previous.effective;previous.view.TextSize=18;previous.view.TextColor3=row.color
   previous.view.TextScaled=false
  end
  table.insert(history,1,{view=nextLine,y=8,at=now,from=8,effective='+ '..format(term.key,term.base+term.bonus)})
  if #history>3 then table.remove(history).view:Destroy() end
  for _,line in ipairs(history) do line.from=line.y;line.at=now end
 end
end
function Ledger:applyModifier(terms,now)
 for _,term in ipairs(terms) do
  local row=self.rows[term.key]
  if term.bonus>0 and row then
   local line=row.history[1].view
   line.Text=term.modifier..' +'..format(term.key,term.bonus)..'  →  + '..format(term.key,term.base+term.bonus)
   line.TextColor3=WHITE;line.TextScaled=true;row.modifierAt=now
   local size=Instance.new('UITextSizeConstraint');size.MinTextSize=12;size.MaxTextSize=18;size.Parent=line
  end
 end
end
function Ledger:add(terms,now)
 for _,term in ipairs(terms) do
  local row=self.rows[term.key]
  if row then
   row.amount+=term.base+term.bonus;row.total.Text=format(row.key,row.amount);row.hitAt=now
  end
 end
 self.added+=1;self.progress.Text=self.added..' / '..self.count..' added'
end
function Ledger:finish(receipt,now)
 for _,row in ipairs(self.order) do
  row.amount=row.key=='Money' and (receipt.cash or 0) or ((receipt.resources or {})[row.key] or 0)
  row.total.Text=format(row.key,row.amount);row.hitAt=now
 end
 self.progress.Text='Sale complete'
end
function Ledger:update(now,reduced)
 for _,row in ipairs(self.order) do
  local height=row.lineHeight or 16
  for i,line in ipairs(row.history) do
   local t=reduced and 1 or math.clamp((now-line.at)/.17,0,1)
   line.y=line.from+(-(i-1)*height-line.from)*(1-(1-t)^3)
   line.view.Size=UDim2.new(1,0,0,height)
   line.view.Position=UDim2.new(0,0,1,line.y-height)
   line.view.TextTransparency=i==1 and 0 or i==2 and .22 or .57
  end
  local impact=1-math.clamp((now-(row.hitAt or -100))/.24,0,1)
  local bonus=1-math.clamp((now-(row.modifierAt or -100))/.16,0,1)
  row.total.TextSize=28+(reduced and 0 or math.floor(impact*4))
  row.total.TextColor3=WHITE:Lerp(row.color,impact)
  row.root.BackgroundTransparency=.16-.12*bonus
 end
end
function Ledger:destroy() self.panel:Destroy() end
return Ledger
