-- Templates.lua contains tables used to initialize the templates

local MOD = Bufflehead
local _

local FILTER_BUFFS = "HELPFUL"
local FILTER_DEBUFFS = "HARMFUL"
local HEADER_NAME = "BuffleheadSecureHeader"
local PLAYER_BUFFS = "Player Buffs"
local PLAYER_DEBUFFS = "Player Debuffs"
local HEADER_PLAYER_BUFFS = HEADER_NAME .. "PlayerBuffs"
local HEADER_PLAYER_DEBUFFS = HEADER_NAME .. "PlayerDebuffs"
local DEFAULT_SPACING = 4
local MINIBAR_WIDTH = 10

MOD.SupportedTemplates = { -- table of templates to be used in options to select appropriate bar or icon template
  [1] = { desc = "Icons in rows, time shown as text", icons = true, base = 1, time = "text" },
  [2] = { desc = "Icons in rows, time shown with clock overlay", icons = true, base = 1, time = "clock" },
  [3] = { desc = "Icons in rows, time shown with bar below icon", icons = true, base = 1, time = "hbar" },
  [4] = { desc = "Icons in rows, time shown with bar beside icon", icons = true, base = 1, time = "vbar" },
  [5] = { desc = "Icons in columns, time shown as text", icons = true, base = 2, time = "text" },
  [6] = { desc = "Icons in columns, time shown with clock overlay", icons = true, base = 2, time = "clock" },
  [7] = { desc = "Icons in columns, time shown with bar below icon", icons = true, base = 2, time = "hbar" },
  [8] = { desc = "Icons in columns, time shown with bar beside icon", icons = true, base = 2, time = "vbar" },
	[9] = { desc = "Horizontal bar to the right of the icons", bars = true, base = 3 },
  [10] = { desc = "Horizontal bar to the left of the icons", bars = true, base = 4 },
  [11] = { desc = "Vertical bar below the icons", bars = true, base = 5 },
  [12] = { desc = "Vertical bar above the icons", bars = true, base = 6 },
}

MOD.BaseTemplates = { -- table of base template settings that are used to configuration selected template
  [1] = { -- icons in rows, includes settings for all time left options so can toggle them on/off
    iconSize = 40,
		orientation = 1, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
    mirrorX = false, -- true = directionX for debuffs is opposite of buffs
		mirrorY = false, -- true = directionY for debuffs is opposite of buffs
		wrapAfter = 20,
		maxWraps = 2,
		spaceX = 6, -- horizontal distance between icons (allow space for elements positioned between icons)
		spaceY = 24, -- vertical distance between icons (allow space for elements positioned between icons)
		showTime = false,
		timePosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = 0 },
		showCount = true,
		countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
		showLabel = false,
		showClock = false, -- show clock overlay to indicate remaining time
		showBar = false,
    barPosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = -4 },
		barWidth = 0, --  0 = same as icon width
		barHeight = MINIBAR_WIDTH, --  0 = same as icon height
		barOrientation = true, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = true, -- true = "STANDARD", false = "REVERSE"
		groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.83, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.98, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.83,
				anchorY = 0.83, -- default places it below the buffs group
			},
		},
  },
  [2] = { -- icons in columns, includes settings for all time left options so can toggle them on/off
    iconSize = 40,
    orientation = 0, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
    mirrorX = false, -- true = directionX for debuffs is opposite of buffs
		mirrorY = false, -- true = directionY for debuffs is opposite of buffs
		wrapAfter = 10,
		maxWraps = 4,
		showTime = false,
		timePosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = 0 },
		showCount = true,
		countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
		showLabel = false,
		showClock = false, -- show clock overlay to indicate remaining time
		showBar = false,
    barPosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = -4 },
		barWidth = 0, --  0 = same as icon width
		barHeight = MINIBAR_WIDTH, --  0 = same as icon height
		barOrientation = true, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = true, -- true = "STANDARD", false = "REVERSE"
		groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.83, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.98, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.68, -- default places it left of the buffs group
				anchorY = 0.98,
			},
		},
  },
  [3] = { -- horizontal bars, icon on left
    iconSize = 24,
		orientation = 0, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
    mirrorX = false, -- true = directionX for debuffs is opposite of buffs
		mirrorY = false, -- true = directionY for debuffs is opposite of buffs
		wrapAfter = 20,
		maxWraps = 2,
		spaceX = 270, -- horizontal distance between icons (allow space for elements positioned between icons)
		spaceY = 8, -- vertical distance between icons (allow space for elements positioned between icons)
    showTime = true,
		timePosition = { point = "RIGHT", relativePoint = "RIGHT", anchor = "bar", offsetX = -DEFAULT_SPACING, offsetY = 0 },
		showCount = true,
    countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
    showLabel = true,
		labelPosition = { point = "LEFT", relativePoint = "LEFT", anchor = "bar", offsetX = DEFAULT_SPACING, offsetY = 0 },
		labelMaxWidth = 160, -- set if want to truncate or wrap
		showClock = false, -- show clock overlay to indicate remaining time
    showBar = true,
    barPosition = { point = "LEFT", relativePoint = "RIGHT", anchor = "icon", offsetX = DEFAULT_SPACING, offsetY = 0 },
		barWidth = 200, --  0 = same as icon width
		barHeight = 0, --  0 = same as icon height
		barOrientation = true, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = true, -- true = "STANDARD", false = "REVERSE"
    groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.72, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.98, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.38,
				anchorY = 0.98, -- default places it below the buffs group
			},
		},
  },
  [4] = { -- horizontal bars, icon on right
    iconSize = 24,
		orientation = 0, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
    mirrorX = false, -- true = directionX for debuffs is opposite of buffs
		mirrorY = false, -- true = directionY for debuffs is opposite of buffs
		wrapAfter = 20,
		maxWraps = 2,
		spaceX = 270, -- horizontal distance between icons (allow space for elements positioned between icons)
		spaceY = 8, -- vertical distance between icons (allow space for elements positioned between icons)
    showTime = true,
		timePosition = { point = "RIGHT", relativePoint = "RIGHT", anchor = "bar", offsetX = 0, offsetY = 0 },
		showCount = true,
    countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
    showLabel = true,
		labelPosition = { point = "LEFT", relativePoint = "LEFT", anchor = "bar", offsetX = 0, offsetY = 0 },
		labelMaxWidth = 160, -- set if want to truncate or wrap
		showClock = false, -- show clock overlay to indicate remaining time
    showBar = true,
    barPosition = { point = "RIGHT", relativePoint = "LEFT", anchor = "icon", offsetX = -DEFAULT_SPACING, offsetY = 0 },
		barWidth = 200, --  0 = same as icon width
		barHeight = 0, --  0 = same as icon height
		barOrientation = true, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = false, -- true = "STANDARD", false = "REVERSE"
    groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.83, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.98, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.47,
				anchorY = 0.98, -- default places it below the buffs group
			},
		},
  },
  [5] = { -- vertical bars, icon on bottom
    iconSize = 24,
		orientation = 1, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
    mirrorX = false, -- true = directionX for debuffs is opposite of buffs
		mirrorY = false, -- true = directionY for debuffs is opposite of buffs
		wrapAfter = 20,
		maxWraps = 2,
		spaceX = 8, -- horizontal distance between icons (allow space for elements positioned between icons)
		spaceY = 190, -- vertical distance between icons (allow space for elements positioned between icons)
    showTime = false,
		timePosition = { point = "TOP", relativePoint = "TOP", anchor = "bar", offsetX = 0, offsetY = -DEFAULT_SPACING },
		showCount = true,
    countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
    showLabel = false,
		showClock = false, -- show clock overlay to indicate remaining time
    showBar = true,
    barPosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = -DEFAULT_SPACING },
		barWidth = 0, --  0 = same as icon width
		barHeight = 120, --  0 = same as icon height
		barOrientation = false, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = false, -- true = "STANDARD", false = "REVERSE"
		groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.83, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.98, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.47,
				anchorY = 0.98, -- default places it in near center and top of display, growing down
			},
		},
  },
  [6] = { -- vertical bars, icon on top
    iconSize = 24,
		orientation = 1, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
    mirrorX = false, -- true = directionX for debuffs is opposite of buffs
		mirrorY = false, -- true = directionY for debuffs is opposite of buffs
		wrapAfter = 20,
		maxWraps = 2,
		spaceX = 8, -- horizontal distance between icons (allow space for elements positioned between icons)
		spaceY = 190, -- vertical distance between icons (allow space for elements positioned between icons)
    showTime = false,
		timePosition = { point = "BOTTOM", relativePoint = "BOTTOM", anchor = "bar", offsetX = 0, offsetY = DEFAULT_SPACING },
		showCount = true,
    countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
    showLabel = false,
		showClock = false, -- show clock overlay to indicate remaining time
    showBar = true,
    barPosition = { point = "BOTTOM", relativePoint = "TOP", anchor = "icon", offsetX = 0, offsetY = DEFAULT_SPACING },
		barWidth = 0, --  0 = same as icon width
		barHeight = 120, --  0 = same as icon height
		barOrientation = false, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = true, -- true = "STANDARD", false = "REVERSE"
		groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.83, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.85, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.47,
				anchorY = 0.85, -- default places it in near center and top of display, growing down
			},
		},
  },
}
