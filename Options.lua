-- Options.lua contains the tables used by the Buffle options panel as well its supporting functions

local MOD = Buffle
local _
local initialized = false -- set when options are first accessed
local pg, pp -- global and character-specific profiles

local acereg = LibStub("AceConfigRegistry-3.0")
local acedia = LibStub("AceConfigDialog-3.0")

local weaponBuffs = { ["Mainhand Weapon"] = true, ["Offhand Weapon"] = true }

local anchorTips = { BOTTOMLEFT = "BOTTOMLEFT", CURSOR = "CURSOR", DEFAULT = "DEFAULT", LEFT = "LEFT", RIGHT = "RIGHT",
	TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT" }

local anchorPoints = { BOTTOM = "BOTTOM", BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT", CENTER = "CENTER", LEFT = "LEFT",
	RIGHT = "RIGHT", TOP = "TOP", TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT" }

local unitList = { player = "Player", pet = "Pet", target = "Target", focus = "Focus",
	mouseover = "Mouseover", pettarget = "Pet's Target", targettarget = "Target's Target", focustarget = "Focus's Target" }

-- Saved variables don't handle being set to nil properly so need to use alternate value to indicate an option has been turned off
local Off = 0 -- value used to designate an option is turned off
local function IsOff(value) return value == nil or value == Off end -- return true if option is turned off
local function IsOn(value) return value ~= nil and value ~= Off end -- return true if option is turned on

-- Update all settings. If in combat then this is deferred until combat ends.
local function UpdateAll()
end

-- Convert color codes from hex number to array with r, pp, b, a fields (alpha set to 1.0)
function MOD.HexColor(hex)
	local n = tonumber(hex, 16)
	local red = math.floor(n / (256 * 256))
	local green = math.floor(n / 256) % 256
	local blue = n % 256

	return { r = red/255, pp = green/255, b = blue/255, a = 1.0 }
	-- return CreateColor(red/255, green/255, blue/255, 1)
end

-- Return a copy of a color, if c is nil then return nil
function MOD.CopyColor(c)
	if not c then return nil end
	-- return CreateColor(c.r, c.pp, c.b, c.a)
	return { r = c.r, g = c.g, b = c.b, a = c.a }
end

-- Return a copy of the contents of a table, assumes contents are at most one table deep
function MOD.CopyTable(a)
	local b = {}
  for k, v in pairs(a) do
		if type(v) == "table" then
			local t = {}
			for k1, v1 in pairs(v) do t[k1] = v1 end
			b[k] = t
		else
			b[k] = v
		end
	end
	return b
end

-- Update options in case anything changes
local function UpdateOptions()
	if initialized and acedia.OpenFrames["Buffle"] then
		acereg:NotifyChange("Buffle")
	end
	MOD:ForceUpdate()
end

-- Register the options table and link to the Blizzard addons interface
local function InitializeOptions()
	initialized = true -- only do this once
	local options = MOD.OptionsTable
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(MOD.db) -- fill in the profile section
	acereg:RegisterOptionsTable("Buffle", options)
	acereg:RegisterOptionsTable("Buffle: "..options.args.BuffleOptions.name, options.args.BuffleOptions)
	acereg:RegisterOptionsTable("Buffle: "..options.args.profile.name, options.args.profile)
	acedia:AddToBlizOptions("Buffle Options", "Buffle")
	pg = MOD.db.global; pp = MOD.db.profile

	local w, h = 890, 680 -- somewhat arbitrary numbers that seem to work for the configuration dialog layout
	acedia:SetDefaultSize("Buffle", w, h)

	MOD.db.RegisterCallback(MOD, "OnProfileChanged", UpdateOptions)
	MOD.db.RegisterCallback(MOD, "OnProfileCopied", UpdateOptions)
	MOD.db.RegisterCallback(MOD, "OnProfileReset", UpdateOptions)
end

-- Toggle display of the options panel
function MOD.OptionsPanel()
	if not initialized then InitializeOptions() end
	if acedia.OpenFrames["Buffle"] then
		acedia:Close("Buffle")
	else
		acedia:Open("Buffle")
	end
	if not InCombatLockdown() then collectgarbage("collect") end -- don't do in combat because could cause freezes/script too long error
end

-- Create the options table to be used by the configuration GUI
MOD.OptionsTable = {
	type = "group", childGroups = "tab",
	args = {
		BuffleOptions = {
			type = "group", order = 10, name = "Setup",
			args = {
				EnableGroup = {
					type = "group", order = 10, name = "Enable", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable Addon",
							desc = "If checked, this addon is enabled, otherwise all features are disabled.",
							get = function(info) return pg.enabled end,
							set = function(info, value) pg.enabled = value; UpdateAll() end,
						},
						EnableMinimapIcon = {
							type = "toggle", order = 20, name = "Minimap Icon",
							desc = "If checked, add a minimap icon for toggling the options panel.",
							hidden = function(info) return MOD.ldbi == nil end,
							get = function(info) return not pg.Minimap.hide end,
							set = function(info, value)
								pg.Minimap.hide = not value
								if value then MOD.ldbi:Show("Buffle") else MOD.ldbi:Hide("Buffle") end
							end,
						},
						EnableHideBlizz = {
							type = "toggle", order = 30, name = "Hide Blizzard",
							desc = "If checked, hide the default Blizzard buffs and debuffs (requires /reload).",
							get = function(info) return pg.hideBlizz end,
							set = function(info, value) pg.hideBlizz = value; UpdateAll() end,
						},
						EnableHideOmniCC = {
							type = "toggle", order = 40, name = "Hide OmniCC",
							desc = "If checked, the OmniCC addon can show time left on icons (requires /reload).",
							hidden = function(info) return not OmniCC end, -- only show if OmniCC is loaded
							get = function(info) return pg.hideOmniCC  end,
							set = function(info, value) pg.hideOmniCC = value; UpdateAll() end,
						},
					},
				},
				LayoutGroup = {
					type = "group", order = 10, name = "Layout", inline = true,
					args = {
						IconSize = {
							type = "range", order = 10, name = "Icon Size", min = 12, max = 64, step = 2,
							desc = "Set icon's width and height.",
							get = function(info) return pp.iconSize end,
							set = function(info, value) pp.iconSize = value; UpdateAll() end,
						},
						Spacing = {
							type = "range", order = 20, name = "Spacing", min = 0, max = 100, step = 1,
							desc = "Adjust spacing between icons.",
							get = function(info) return pp.spaceX end,
							set = function(info, value) pp.spaceX = value; UpdateAll() end,
						},
					},
				},
				PositionGroup = {
					type = "group", order = 20, name = "Position", inline = true,
					args = {
						Horizontal = {
							type = "range", order = 10, name = "Horizontal", min = 0, max = 100, step = 0.1,
							desc = "Set horizontal position for player buffs as percentage of overall width (cannot move beyond edge of display).",
							get = function(info) return MOD.GetBuffsPercentX() end,
							set = function(info, value) MOD.SetBuffsPercentX(value); UpdateAll() end,
						},
						Vertical = {
							type = "range", order = 20, name = "Vertical", min = 0, max = 100, step = 0.1,
							desc = "Set vertical position for player buffs as percentage of overall height (cannot move beyond edge of display).",
							get = function(info) return MOD.GetBuffsPercentY() end,
							set = function(info, value) MOD.SetBuffsPercentY(value); UpdateAll() end,
						},
					},
				},
				IconBorderGroup = {
					type = "group", order = 30, name = "Icon Border", inline = true,
					args = {
						DefaultBorder = {
							type = "toggle", order = 10, name = "Default", width = "half",
							desc = "Use default icon borders.",
							get = function(info) return pp.iconBorder == "none" or ((pp.iconBorder == "masque") and not MOD.MSQ) end,
							set = function(info, value) pp.iconBorder = "none"; UpdateAll() end,
						},
						MasqueBorder = {
							type = "toggle", order = 20, name = "Masque", width = "half",
							desc = "Use the Masque addon to show icon borders.",
							hidden = function(info) return not MOD.MSQ end, -- only show if Masque is loaded
							get = function(info) return pp.iconBorder == "masque" end,
							set = function(info, value) pp.iconBorder = "masque"; UpdateAll() end,
						},
						RavenBorder = {
							type = "toggle", order = 30, name = "Raven", width = "half",
							desc = "Use the custom icon border included in Raven.",
							get = function(info) return pp.iconBorder == "raven" end,
							set = function(info, value) pp.iconBorder = "raven"; UpdateAll() end,
						},
						OnePixelBorder = {
							type = "toggle", order = 40, name = "Pixel", width = "half",
							desc = "Use single pixel icon borders.",
							get = function(info) return pp.iconBorder == "one" end,
							set = function(info, value) pp.iconBorder = "one"; UpdateAll() end,
						},
						TwoPixelBorder = {
							type = "toggle", order = 50, name = "Two Pixel",
							desc = "Use two pixel icon borders.",
							get = function(info) return pp.iconBorder == "two" end,
							set = function(info, value) pp.iconBorder = "two"; UpdateAll() end,
						},
						spacer = { type = "description", name = "", order = 100 },
						BuffColor = {
							type = "color", order = 110, name = "Buffs", hasAlpha = true,
							desc = "Set color for buff icon borders.",
							get = function(info) local t = pp.iconBuffBorderColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.iconBuffBorderColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						DebuffColor = {
							type = "color", order = 120, name = "Debuffs", hasAlpha = true,
							desc = "Set color for debuff icons borders.",
							get = function(info) local t = pp.iconDebuffBorderColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.iconDebuffBorderColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						DebuffTypeColor = {
							type = "toggle", order = 130, name = "Debuff Type Color",
							desc = "Use debuff type colors for icon borders when appropriate.",
							get = function(info) return pp.debuffColoring end,
							set = function(info, value) pp.debuffColoring = value; UpdateAll() end,
						},
					},
				},
				TimeLeftGroup = {
					type = "group", order = 30, name = "Time Left", inline = true,
					args = {
						TextTimeLeft = {
							type = "toggle", order = 10, name = "Formatted Text",
							desc = "Show time left as formatted text for icons with duration.",
							get = function(info) return pp.showTime end,
							set = function(info, value) pp.showTime = value; UpdateAll() end,
						},
						ClockTimeLeft = {
							type = "toggle", order = 20, name = "Clock Overlay",
							desc = "Show time left with animated clock overlay for icons with duration.",
							get = function(info) return pp.showClock  end,
							set = function(info, value) pp.showClock = value; UpdateAll() end,
						},
						BarTimeLeft = {
							type = "toggle", order = 30, name = "Timer Bar",
							desc = "Show time left as animated timer bar for icons with duration.",
							get = function(info) return pp.showBar  end,
							set = function(info, value) pp.showBar = value; UpdateAll() end,
						},
						spacer = { type = "description", name = "", order = 100 },
						TimeColor = {
							type = "color", order = 110, name = "Time Color", hasAlpha = true,
							desc = "Set color for time text.",
							get = function(info) local t = pp.timeColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.timeColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						CountColor = {
							type = "color", order = 120, name = "Count Color", hasAlpha = true,
							desc = "Set color for count text.",
							get = function(info) local t = pp.countColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.countColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						BuffColor = {
							type = "color", order = 130, name = "Buffs", hasAlpha = true,
							desc = "Set color for buff bars.",
							get = function(info) local t = pp.barBuffColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.barBuffColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						DebuffColor = {
							type = "color", order = 140, name = "Debuffs", hasAlpha = true,
							desc = "Set color for debuff bars.",
							get = function(info) local t = pp.barDebuffColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.barDebuffColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						BarBorderColor = {
							type = "color", order = 150, name = "Bar Border Color", hasAlpha = true,
							desc = "Set color for bar border.",
							get = function(info) local t = pp.barBorderColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.barBorderColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
						},
						BackgroundOpacity = {
							type = "range", order = 160, name = "Background Opacity", min = 0, max = 1, step = 0.05,
							desc = "Set background opacity for bars.",
							get = function(info) return pp.barBackgroundOpacity end,
							set = function(info, value) pp.barBackgroundOpacity = value; UpdateAll() end,
						},
					},
				},
			},
		},
	},
}
