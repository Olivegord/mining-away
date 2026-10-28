local Layout = require('../src/UILayout')
local passed = 0
local function check(name, fn)
 local ok, err = pcall(fn)
 assert(ok, name .. ': ' .. tostring(err))
 passed += 1
 print('PASS UI layout ' .. name)
end
local function rect(x, y, w, h) return {x=x, y=y, w=w, h=h} end
local function inside(r, width, height)
 assert(r.w > 0 and r.h > 0, 'empty rectangle')
 assert(r.x >= 0 and r.y >= 0, 'rectangle starts outside safe content')
 assert(r.x+r.w <= width+.001 and r.y+r.h <= height+.001, 'rectangle extends outside safe content')
end
local function separate(a, b)
 assert(a.x+a.w <= b.x+.001 or b.x+b.w <= a.x+.001 or a.y+a.h <= b.y+.001 or b.y+b.h <= a.y+.001,
  'persistent controls overlap')
end
local viewports = {
 {320,568,true}, {390,844,true}, {667,375,true}, {844,390,true},
 {667,317,true}, {568,262,true}, {844,332,true},
 {836,635,false},
 {836,595,false},
 {1024,768,true}, {1024,768,false}, {1920,1080,false},
}

for _, view in ipairs(viewports) do
 local width, height, touch = view[1], view[2], view[3]
 check(string.format('%dx%d %s controls stay inside safe content and apart', width,height,touch and 'touch' or 'keyboard'), function()
  local l = Layout.calculate(width,height,touch)
  local hud = rect(l.hudX,l.hudY,l.hudWidth,l.hudHeight)
  local objective = rect(l.hudX,l.objectiveY,l.objectiveWidth,l.objectiveHeight)
  local context = rect(l.contextX,l.contextY,l.contextWidth,l.contextHeight)
  local recall = rect(l.recallX,l.recallY,l.recallWidth,l.recallHeight)
  local evade = rect(l.evadeX,l.evadeY,l.recallWidth,l.recallHeight)
  -- The Client hides objectives in short landscape, and a visible context
  -- dock temporarily replaces resources below 300px native-safe height.
  local controls = {context,recall,evade}
  if not l.contextReplacesHUD then table.insert(controls,hud) end
  if not l.short then table.insert(controls,objective) end
  for index, control in ipairs(controls) do
   inside(control,width,height)
   for other=index+1,#controls do separate(control,controls[other]) end
  end
  -- Resources and fleet commands must also fit together when no context is
  -- visible; the dock never forces game buttons into a native touch corner.
  inside(hud,width,height);separate(hud,recall);separate(hud,evade)
  inside(rect(l.panelX,l.panelY,l.panelWidth,l.panelHeight),width,height)
  assert(l.recallHeight >= 44 and l.recallWidth >= 44, 'touch commands need usable targets')
  if touch then
   assert(context.y+context.h <= height-130, 'station command overlaps native touch strip')
   assert(recall.y+recall.h <= height-130 and evade.y+evade.h <= height-130, 'fleet commands overlap native touch strip')
  end
 end)
 check(string.format('%dx%d card columns fit and all choices remain scroll reachable',width,height),function()
  local l = Layout.calculate(width,height,touch)
  assert(l.cardWidth >= (l.cardColumns==3 and 240 or 260), 'card copy is too narrow')
  local occupied = l.cardColumns*l.cardWidth+(l.cardColumns-1)*l.cardGap
  assert(math.abs(occupied-l.bodyWidth)<.001, 'card row exceeds the scrolling content width')
  assert(l.headerHeight+l.bodyHeight+l.panelPadding <= l.panelHeight+.001, 'scroll body escapes the panel')
  assert(l.cardHeight >= (l.cardColumns==3 and 430 or 520), 'full effect/target/tradeoff/stack copy must remain available')
  local rows = math.ceil(3/l.cardColumns)
  local contentHeight = rows*l.cardHeight+(rows-1)*l.cardGap
  local maximumScroll = math.max(0,contentHeight-l.bodyHeight)
  -- Each button ends eight pixels above its card bottom. After scrolling the
  -- last choice into view, its complete 44px hit target must be reachable.
  local lastButtonBottom = contentHeight-8-maximumScroll
  assert(lastButtonBottom <= l.bodyHeight and lastButtonBottom-44 >= 0, 'last choose button cannot be reached')
 end)
end

check('short landscape preserves native movement space without hiding commands',function()
 for _, view in ipairs({{667,375},{844,390},{667,317},{568,262},{844,332}}) do
  local l = Layout.calculate(view[1],view[2],true)
  assert(l.short and l.mobile)
  assert(l.actionAtTop and l.actionY==12, 'short touch commands belong above the native movement controls')
  assert(l.actionY+l.actionHeight < l.contextY, 'fleet and station commands collide')
  assert(l.hudX+l.hudWidth+12 <= l.actionX, 'resources collide with top-right fleet commands')
  assert(l.bodyHeight < l.cardHeight, 'short screen must use the scroll surface')
 end
end)
check('default Studio window compares three choices while phones stay stacked',function()
 local l = Layout.calculate(836,635,false)
 assert(l.cardColumns==3 and l.cardWidth>=240)
 local phone = Layout.calculate(390,844,true)
 assert(phone.cardColumns==1 and phone.cardWidth>=260)
 local narrow = Layout.calculate(799,635,false)
 assert(narrow.cardColumns==1, 'the compact three-card row must not spread into phone widths')
end)
check('compact desktop cards show the entire choose target without vertical scrolling',function()
 local l = Layout.calculate(836,595,false)
 assert(l.cardColumns==3 and l.cardHeight>=430)
 assert(l.bodyHeight>=l.cardHeight, 'desktop choice should fit in the menu body')
 local buttonBottom=l.cardHeight-12
 assert(buttonBottom<=l.bodyHeight and buttonBottom-44>=0, 'the complete choose target must be visible')
 assert(Layout.calculate(390,844,true).cardHeight==520, 'stacked phone cards retain full readable spacing')
end)
check('adaptive desktop heights keep the complete choose target visible through the compact boundary',function()
 for _, size in ipairs({{658,500},{668,510},{677,519}}) do
  local l=Layout.calculate(836,size[1],false)
  assert(l.cardColumns==3 and l.cardHeight==size[2])
  local buttonTop=l.cardHeight-56
  local buttonBottom=buttonTop+44
  assert(buttonTop>=0 and buttonBottom<=l.bodyHeight, 'adaptive choose button escapes the visible body')
  assert(l.bodyHeight-l.cardHeight==6, 'adaptive desktop card should leave a small scroll-free gutter')
 end
end)
check('very short context temporarily replaces resources instead of overlapping',function()
 local l = Layout.calculate(568,262,true)
 assert(l.contextReplacesHUD, 'Client must hide resources while the station command is visible')
 assert(not Layout.calculate(667,317,true).contextReplacesHUD)
 assert(l.hudWidth>=260, 'resources retain a usable text width')
end)
check('desktop compares all three cards without vertical scrolling',function()
 local l = Layout.calculate(1920,1080,false)
 assert(not l.mobile and not l.compact and l.cardColumns==3)
 assert(l.bodyHeight >= l.cardHeight)
 assert(l.panelWidth <= 1010 and l.panelHeight <= 664, 'modal should not grow across the world')
end)
check('input fallback is deterministic while safe root is initializing',function()
 local l = Layout.calculate(nil,0/0,false)
 assert(l.panelWidth==1010 and l.panelHeight==664)
 assert(l.hudWidth==360)
end)
check('offer tray keeps portrait choices and world visible',function()
 for _,size in ipairs({{800,600},{836,635},{1280,720},{1920,1080}}) do
  local w,h=size[1],size[2];local l=Layout.offer(w,h,false)
  inside(rect(l.panelX,l.panelY,l.panelWidth,l.panelHeight),w,h)
  assert(l.panelWidth<=500 and l.cardHeight>l.cardWidth and l.cardWidth>=130)
  assert(3*(l.cardWidth+6)+2*l.cardGap<=l.bodyWidth)
  assert(l.bodyHeight>=l.cardHeight+6 and l.panelWidth*l.panelHeight<w*h*.55)
 end
end)
check('phone and short landscape keep cards scroll reachable and controls inside',function()
 for _,size in ipairs({{320,568},{390,844},{667,375},{568,262}}) do
  local w,h=size[1],size[2];local l=Layout.offer(w,h,true)
  inside(rect(l.panelX,l.panelY,l.panelWidth,l.panelHeight),w,h)
  inside(rect(l.bodyX,l.bodyY,l.bodyWidth,l.bodyHeight),l.panelWidth,l.panelHeight)
  inside(rect(l.detailX,l.detailY,l.detailWidth,l.detailHeight),l.panelWidth,l.panelHeight)
  inside(rect(l.actionX,l.actionY,l.actionWidth,44),l.panelWidth,l.panelHeight)
  inside(rect(l.closeX,l.closeY,l.closeWidth,44),l.panelWidth,l.panelHeight)
  assert(l.actionWidth>=44 and l.closeWidth>=44 and l.bodyHeight>=l.cardHeight+6)
  assert(3*(l.cardWidth+6)+2*l.cardGap<=l.bodyWidth,'all three silhouettes must fit')
  local total=3*(l.cardWidth+6)+2*l.cardGap
  assert(total-math.max(0,total-l.bodyWidth)<=l.bodyWidth)
 end
end)
check('only matching server assignment receipts produce an accessible status',function()
 assert(Layout.assignmentReceipt('request-a',{requestId='stale',status='accepted'},'Blue 1')==nil)
 assert(Layout.assignmentReceipt(nil,{status='accepted'},'Blue 1')==nil)
 local status,message=Layout.assignmentReceipt('request-a',{requestId='request-a',status='accepted',slot=2},'Blue 1')
 assert(status=='accepted' and message=='Blue 1 assigned · slot 2')
 status,message=Layout.assignmentReceipt('request-a',{requestId='request-a',status='rejected',reason='Resource is busy'},'Blue 1')
 assert(status=='rejected' and message=='Resource is busy')
 assert(Layout.assignmentReceipt('request-a',{requestId='request-a',status='recalled'},'Blue 1')==nil)
end)
check('reveal is brief, bounded, deterministic and immediately bypassed for reduced motion',function()
 assert(Layout.revealDelay(1,false)==0)
 assert(math.abs(Layout.revealDelay(2,false)-.12)<1e-9)
 assert(math.abs(Layout.revealDelay(3,false)-.24)<1e-9)
 assert(Layout.revealDelay(1,true)==0 and Layout.revealDelay(3,true)==0)
 assert(Layout.revealDelay(999,false)==Layout.revealDelay(3,false),'late/invalid index cannot extend the reveal')
end)
check('committed offer focus cannot drift during pending or uncertain confirmation',function()
 local claim={offerId='offer-a',index=2}
 assert(Layout.offerFocusAllowed('offer-a',2,claim))
 assert(not Layout.offerFocusAllowed('offer-a',1,claim))
 assert(not Layout.offerFocusAllowed('offer-a',3,claim))
 assert(Layout.offerFocusAllowed('offer-a',1,nil),'failure clears focus lock')
 assert(Layout.offerFocusAllowed('offer-b',1,claim),'a different saved offer owns its own focus')
end)
check('field acknowledgments match only the current bounded request',function()
 assert(Layout.fieldReceipt('a',{requestId='old',status='accepted'})==nil)
 local status,message=Layout.fieldReceipt('a',{requestId='a',status='rejected',reason='Too far from field'})
 assert(status=='rejected' and message=='Too far from field')
 status,message=Layout.fieldReceipt('a',{requestId='a',status='accepted',reason='Fleet assigned'})
 assert(status=='accepted' and message=='Fleet assigned')
 status,message=Layout.fieldReceipt('recall',{requestId='recall',status='recalled',reason='Fleet recalled'})
 assert(status=='recalled' and message=='Fleet recalled')
 assert(Layout.fieldReceipt('recall',{requestId='old-field',status='accepted'})==nil,'a field receipt cannot reverse later Recall feedback')
 assert(Layout.fieldReceipt('a',{requestId='a',status='accepted',fieldId=2},1)==nil,'accepted receipt must match destination')
 assert(Layout.fieldReceipt('a',{requestId='a',status='accepted',fieldId=1},1)=='accepted')
 assert(Layout.assignmentReceipt('a',{requestId='a',status='accepted'},'Blue 1',true)==nil,'late assignment is ignored while cancellation remains desired')
end)
check('offer transaction receipts are tied to exact tx run and offer',function()
 local claim={txId='tx',runId='run',offerId='offer',index=2}
 assert(Layout.claimRetryId('offer',2,claim)=='tx','same card retry keeps durable idempotency key')
 assert(Layout.claimRetryId('offer',1,claim)==nil and Layout.claimRetryId('other',2,claim)==nil)
 local rejected={txId='tx',runId='run',offerId='offer',status='rejected',reason='Choice no longer available'}
 local state,reason=Layout.offerReceipt(claim,rejected)
 assert(state=='rejected' and reason=='Choice no longer available')
 rejected.txId='old';assert(Layout.offerReceipt(claim,rejected)==nil);rejected.txId='tx'
 rejected.runId='other';assert(Layout.offerReceipt(claim,rejected)==nil);rejected.runId='run'
 rejected.offerId='other';assert(Layout.offerReceipt(claim,rejected)==nil);rejected.offerId='offer'
 rejected.status='uncertain';assert(Layout.offerReceipt(claim,rejected)=='uncertain')
 rejected.status='accepted';assert(Layout.offerReceipt(claim,rejected)=='accepted')
end)
print(string.format('PASS %d responsive safe-content geometry tests (rendering and native touch controls still require Studio)',passed))
