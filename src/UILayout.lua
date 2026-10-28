-- Pixel layout inside the ScreenGui's safe content rectangle. This module has
-- no Roblox dependencies, so the same geometry can be exercised outside Studio.
-- Clients should pass their safe root's AbsoluteSize, not Camera.ViewportSize.
local Layout = {}

local function dimension(value, fallback)
 if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return fallback end
 return math.max(1, math.floor(value))
end

function Layout.calculate(viewportWidth, viewportHeight, touch)
 local width = dimension(viewportWidth, 1280)
 local height = dimension(viewportHeight, 720)
 local short = height < 500
 local compact = width < 980 or height < 650
 local mobile = width < 900 or (touch == true and short)
 local margin = width < 900 and 12 or 16
 local availableWidth = math.max(1, width - margin * 2)

 local hudWidth = math.min(360, availableWidth)
 local hudHeight = short and 76 or 88
 local hudX, hudY = margin, 12
 local objectiveHeight = short and 28 or 42
 local objectiveY = hudY + hudHeight + 8

 -- Touch controls occupy the lower corners in both orientations. Keeping the
 -- entire game command group above this strip also avoids jump/joystick hits
 -- when a station prompt becomes visible while the player is moving.
 local bottomReserve = touch == true and 130 or 16
 local contextWidth = math.min(short and 360 or 420, availableWidth)
 local contextHeight = short and 64 or 72
 local contextX = (width - contextWidth) / 2
 local contextY = math.max(margin, height - bottomReserve - contextHeight)

 local actionGap = 8
 local actionWidth = math.min(244, availableWidth)
 local actionHeight = 44
 local actionX = (width - actionWidth) / 2
 local actionY = contextY - actionGap - actionHeight
 local actionAtTop = short and touch == true and width >= 568
 if actionAtTop then
  actionX = width - margin - actionWidth
  actionY = 12
  hudWidth = math.min(hudWidth, availableWidth - actionWidth - 12)
 end
 -- Large keyboard screens have room for a separate bottom-right pair. The
 -- narrower layout keeps the pair centered above the station command dock.
 if width >= 1024 and touch ~= true then
  actionX = width - margin - actionWidth
  actionY = height - 16 - actionHeight
 end
 local actionButtonWidth = (actionWidth - actionGap) / 2

 local panelMargin = 12
 local panelWidth = math.min(1010, math.max(1, width - panelMargin * 2))
 local panelHeight = math.min(664, math.max(1, height - panelMargin * 2))
 local panelPadding = compact and 16 or 24
 local headerHeight = short and 96 or 112
 local bodyWidth = math.max(1, panelWidth - panelPadding * 2)
 local bodyHeight = math.max(1, panelHeight - headerHeight - panelPadding)
 local cardGap = 14
 local cardColumns = width >= 800 and bodyWidth >= 240 * 3 + cardGap * 2 and 3 or 1
 local cardWidth = (bodyWidth - cardGap * (cardColumns - 1)) / cardColumns
 local cardHeight = cardColumns == 3 and math.max(430, math.min(520, bodyHeight - 6)) or 520

 return {
  mobile = mobile,
  compact = compact,
  short = short,
  hudWidth = hudWidth,
  hudHeight = hudHeight,
  hudX = hudX,
  hudY = hudY,
  panelWidth = panelWidth,
  panelHeight = panelHeight,
  panelX = (width - panelWidth) / 2,
  panelY = (height - panelHeight) / 2,
  panelPadding = panelPadding,
  headerHeight = headerHeight,
  bodyWidth = bodyWidth,
  bodyHeight = bodyHeight,
  cardWidth = cardWidth,
  cardHeight = cardHeight,
  cardColumns = cardColumns,
  cardGap = cardGap,
  contextWidth = contextWidth,
  contextHeight = contextHeight,
  contextX = contextX,
  contextY = contextY,
  actionWidth = actionWidth,
  actionHeight = actionHeight,
  actionX = actionX,
  actionY = actionY,
  actionAtTop = actionAtTop,
  -- At very short native-safe heights, the station command uses the space
  -- occupied by resources. Show resources again when that command disappears.
  contextReplacesHUD = actionAtTop and height < 300,
  recallWidth = actionButtonWidth,
  recallHeight = actionHeight,
  recallX = actionX,
  recallY = actionY,
  evadeX = actionX + actionButtonWidth + actionGap,
  evadeY = actionY,
  objectiveWidth = math.min(360, availableWidth),
  objectiveHeight = objectiveHeight,
  objectiveY = objectiveY,
  bottomReserve = bottomReserve,
 }
end

-- Card offers use a smaller, world-visible sheet. Other menus retain their
-- existing larger scrolling layout. The source offer is already committed;
-- this function changes presentation geometry only.
function Layout.offer(viewportWidth, viewportHeight, touch)
 local l=Layout.calculate(viewportWidth,viewportHeight,touch)
 local width=dimension(viewportWidth,1280)
 local height=dimension(viewportHeight,720)
 l.panelWidth=math.min(500,math.max(1,width-24))
 l.panelHeight=math.min(520,math.max(1,height-24))
 l.panelX=(width-l.panelWidth)/2
 l.panelY=math.max(12,height-l.panelHeight-20)
 l.panelPadding=0
 l.shortOffer=height<550
 l.cardGap=10;l.cardColumns=3;l.cardWidth=150;l.cardHeight=200
 if l.shortOffer then
  -- In landscape the detail/controls sit beside a horizontally scrolling hand.
  l.detailWidth=math.min(220,math.max(150,math.floor(l.panelWidth*.4)))
  l.detailHeight=math.max(1,l.panelHeight-60);l.detailX=0;l.detailY=0
  l.bodyX=l.detailWidth+8;l.bodyY=0;l.bodyWidth=math.max(1,l.panelWidth-l.bodyX);l.bodyHeight=math.min(214,l.panelHeight-8)
  l.actionX=0;l.actionY=l.panelHeight-48;l.actionWidth=math.max(90,l.detailWidth-72)
  l.closeX=l.actionWidth+6;l.closeY=l.actionY;l.closeWidth=math.max(56,l.detailWidth-l.actionWidth-6)
 else
  l.detailWidth=math.min(300,l.panelWidth);l.detailHeight=246
  l.detailX=(l.panelWidth-l.detailWidth)/2;l.detailY=0
  l.bodyX=0;l.bodyY=252;l.bodyWidth=l.panelWidth;l.bodyHeight=212
  l.actionWidth=146;l.actionX=(l.panelWidth-l.actionWidth-70)/2;l.actionY=470
  l.closeWidth=64;l.closeX=l.actionX+l.actionWidth+6;l.closeY=l.actionY
 end
 l.cardWidth=math.max(56,math.min(150,math.floor((l.bodyWidth-2*l.cardGap)/3)-6))
 l.headerHeight=0
 return l
end

-- A fixed reveal rhythm for already-saved choices. This is cosmetic timing,
-- never a roll, selection, timer, or condition for a server transaction.
function Layout.revealDelay(index,reducedMotion)
 if reducedMotion then return 0 end
 return math.clamp((tonumber(index) or 1)-1,0,2)*.12
end

-- Only a matching server receipt can mark an assignment as complete.
function Layout.assignmentReceipt(pendingId,receipt,droneName,cancelDesired)
 if cancelDesired then return nil end
 if type(pendingId)~='string' or type(receipt)~='table' or receipt.requestId~=pendingId then return nil end
 if receipt.status=='accepted' then
  return 'accepted',(droneName or 'Drone')..' assigned'..(receipt.slot and (' · slot '..tostring(receipt.slot)) or '')
 elseif receipt.status=='rejected' then
  return 'rejected',tostring(receipt.reason or 'Assignment rejected')
 end
 return nil
end

-- Correlate fleet feedback to the exact field request; unsolicited/stale
-- attributes cannot be mistaken for the latest command's success.
function Layout.fieldReceipt(pendingId,receipt,expectedFieldId)
 if type(pendingId)~='string' or type(receipt)~='table' or receipt.requestId~=pendingId then return nil end
 if receipt.status=='accepted' and expectedFieldId~=nil and receipt.fieldId~=expectedFieldId then return nil end
 if receipt.status=='accepted' then return 'accepted',tostring(receipt.reason or 'Fleet assigned') end
 if receipt.status=='recalled' then return 'recalled',tostring(receipt.reason or 'Fleet recalled') end
 if receipt.status=='rejected' then return 'rejected',tostring(receipt.reason or 'Field assignment rejected') end
 return nil
end

-- Retrying an unresolved card must reuse the original durable idempotency key.
function Layout.claimRetryId(offerId,index,claim)
 if type(claim)=='table' and claim.offerId==offerId and claim.index==index then return claim.txId end
 return nil
end

-- Ignore foreign, stale and malformed transaction results; an uncertain
-- result stays locked until the server resolves the exact paid choice.
function Layout.offerReceipt(claim,receipt)
 if type(claim)~='table' or type(receipt)~='table' or receipt.txId~=claim.txId or receipt.runId~=claim.runId or receipt.offerId~=claim.offerId then return nil end
 if receipt.status=='accepted' then return 'accepted',tostring(receipt.reason or 'Card saved') end
 if receipt.status=='rejected' then return 'rejected',tostring(receipt.reason or 'Choice rejected') end
 if receipt.status=='uncertain' then return 'uncertain',tostring(receipt.reason or 'Save uncertain • reconciling') end
 return nil
end

-- Once submitted, only the same paid card may remain focused until the server
-- confirms or rejects the transaction. An uncertain timeout is not a reroll.
function Layout.offerFocusAllowed(offerId,index,claim)
 return not claim or claim.offerId~=offerId or claim.index==index
end

return Layout
