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

 local hudWidth = math.min(300, availableWidth)
 local hudHeight = short and 64 or 68
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
 local cardHeight = 320

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

return Layout

