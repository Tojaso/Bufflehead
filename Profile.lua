-- Profile.lua contains the tables used to initialize the profile and presets

local MOD = Bufflehead
local _

-- Default profile description used to initialize the SavedVariables persistent database
MOD.DefaultProfile = {
	global = { -- shared settings for all characters
		enabled = true, -- enable addon
		hideBlizz = true, -- hide Blizzard buffs and debuffs
		Minimap = { hide = false, minimapPos = 200, radius = 80, }, -- saved DBIcon minimap settings
		hideOmniCC = true, -- only valid if OmniCC addon is available
	},
	profile = { -- settings specific to a profile
		showAnchors = true, -- show or hide the anchor rectangles
		iconSize = 48,
		iconBorder = "raven", -- "default", "one", "two", "raven", "masque"
		iconBorderColor = { r = 0.5, g = 1, b = 0.5, a = 1 },
		debuffColoring = true, -- use debuff color for border if applicable
		growDirection = 1, -- horizontal = 1, otherwise vertical
		directionX = -1, -- 1 = right, -1 = left
		directionY = -1, -- 1 = up, -1 = down
		wrapAfter = 20,
		maxWraps = 2,
		spaceX = 6, -- horizontal distance between icons (allow space for elements positioned between icons)
		spaceY = 24, -- vertical distance between icons (allow space for elements positioned between icons)
		sortMethod = "TIME", -- "INDEX", "NAME", "TIME"
		sortDirection = "-", -- ASCENDING = "+", DESCENDING = "-"
		separateOwn = 0, -- 0 = don't separate, 1 = sort before others, -1 = sort after others
		weaponEnchants = true, -- include weapon enchants in the buffs group
		showTime = true,
		timePosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = 0 },
		timeFormat = 24, -- use simple time format
		timeSpaces = false, -- if true include spaces in time text
		timeCase = false, -- if true use upper case in time text
		timeLimit = 0, -- if timeLimit > 0 then only show time when < timeLimit
		timeFont = "Arial Narrow", -- default font
		timeFontPath = 0, -- actual font path
		timeFontSize = 14,
		timeFontFlags = { outline = true, thick = false, mono = false },
		timeShadow = true,
		timeColor = { r = 1, g = 1, b = 1, a = 1 },
		expireColor = { r = 1, g = 0, b = 0, a = 1 },
		showCount = true,
		countPosition = { point = "CENTER", relativePoint = "CENTER", anchor = "icon", offsetX = 0, offsetY = 0 },
		countFont = "Arial Narrow", -- default font
		countFontPath = 0, -- actual font path
		countFontSize = 14,
		countFontFlags = { outline = true, thick = false, mono = false },
		countShadow = true,
		countColor = { r = 1, g = 1, b = 1, a = 1 },
		showLabel = false,
		labelPosition = { point = "BOTTOM", relativePoint = "TOP", anchor = "icon", offsetX = 0, offsetY = 0 },
		labelMaxWidth = 40, -- set if want to truncate or wrap
		labelWrap = false,
		labelWordWrap = false,
		labelFont = "Arial Narrow", -- default font
		labelFontPath = 0, -- actual font path
		labelFontSize = 14,
		labelFontFlags = { outline = true, thick = false, mono = false },
		labelShadow = true,
		labelColor = { r = 1, g = 1, b = 1, a = 1 },
		showClock = false, -- show clock overlay to indicate remaining time
		clockEdge = true,
		clockReverse = false,
		clockColor = { r = 0, g = 0, b = 0, a = 0.75 },
		showBar = false,
		barPosition = { point = "TOP", relativePoint = "BOTTOM", anchor = "icon", offsetX = 0, offsetY = 0 },
		barBuffColor = { r = 0, g = 0.75, b = 0, a = 1 },
		barDebuffColor = { r = 0.75, g = 0, b = 0, a = 1 },
		barBackgroundOpacity = 0.25,
		barWidth = 0, --  0 = same as icon width
		barHeight = 10, --  0 = same as icon height
		barOrientation = true, -- true = "HORIZONTAL", false = "VERTICAL"
		barDirection = true, -- true = "STANDARD", false = "REVERSE"
		barBorder = "two", -- "none", "one", "two"
		barBorderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
		groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				caption = PLAYER_BUFFS,
				anchorX = 0.8, -- fraction of screen from left edge, puts it near the mini-map
				anchorY = 0.98, -- fraction of the screen from bottom edge
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				caption = PLAYER_DEBUFFS,
				anchorX = 0.8,
				anchorY = 0.84, -- default places it below the buffs group
			},
		},
	},
}
