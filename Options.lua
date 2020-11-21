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
						BorderColor = {
							type = "color", order = 110, name = "Border Color", hasAlpha = true,
							desc = "Set color for buff icon borders.",
							get = function(info) local t = pp.iconBorderColor return t.r, t.g, t.b, t.a end,
							set = function(info, r, g, b, a) local t = pp.iconBorderColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
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
					},
				},
				ColorsGroup = {
					type = "group", order = 40, name = "Colors", inline = true,
					args = {
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
				TimeTextGroup = {
					type = "group", order = 40, name = "Time Text", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing formatted time text with each icon.",
							get = function(info) return pp.showTime end,
							set = function(info, value) pp.showTime = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 20, name = "Appearance", inline = true,
							args = {
								Font = {
									type = "select", order = 10, name = "Font",
									desc = "Select font.",
									dialogControl = "LSM30_Font",
									values = AceGUIWidgetLSMlists.font,
									get = function(info) return pp.timeFont end,
									set = function(info, value)
										pp.timeFont = value
										pp.timeFontPath = MOD.LSM:Fetch("font", value)
										UpdateAll()
									end,
								},
								FontSize = {
									type = "range", order = 20, name = "Font Size", min = 5, max = 50, step = 1,
									desc = "Set font size.",
									get = function(info) return pp.timeFontSize end,
									set = function(info, value) pp.timeFontSize = value; UpdateAll() end,
								},
								Color = {
									type = "color", order = 30, name = "Color", hasAlpha = true, width = "half",
									get = function(info)
										local t = pp.timeColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.timeColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								Space = { type = "description", name = "", order = 100 },
								Outline = {
									type = "toggle", order = 110, name = "Outline", width = "half",
									desc = "Add black outline.",
									get = function(info) return pp.timeFontFlags.outline end,
									set = function(info, value) pp.timeFontFlags.outline = value; UpdateAll() end,
								},
								Thick = {
									type = "toggle", order = 120, name = "Thick", width = "half",
									desc = "Add thick black outline.",
									get = function(info) return pp.timeFontFlags.thick end,
									set = function(info, value) pp.timeFontFlags.thick = value; UpdateAll() end,
								},
								Mono = {
									type = "toggle", order = 130, name = "Mono", width = "half",
									desc = "Render font without antialiasing.",
									get = function(info) return pp.timeFontFlags.mono end,
									set = function(info, value) pp.timeFontFlags.mono = value; UpdateAll() end,
								},
								Shadow = {
									type = "toggle", order = 140, name = "Shadow", width = "half",
									desc = "Render font with shadow.",
									get = function(info) return pp.timeShadow end,
									set = function(info, value) pp.timeShadow = value; UpdateAll() end,
								},
							},
						},
					},
				},
				CountTextGroup = {
					type = "group", order = 50, name = "Count Text", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing count, if greater than one, with each icon.",
							get = function(info) return pp.showCount end,
							set = function(info, value) pp.showCount = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 20, name = "Appearance", inline = true,
							args = {
								Font = {
									type = "select", order = 10, name = "Font",
									desc = "Select font.",
									dialogControl = "LSM30_Font",
									values = AceGUIWidgetLSMlists.font,
									get = function(info) return pp.countFont end,
									set = function(info, value)
										pp.countFont = value
										pp.countFontPath = MOD.LSM:Fetch("font", value)
										UpdateAll()
									end,
								},
								FontSize = {
									type = "range", order = 20, name = "Font Size", min = 5, max = 50, step = 1,
									desc = "Set font size.",
									get = function(info) return pp.countFontSize end,
									set = function(info, value) pp.countFontSize = value; UpdateAll() end,
								},
								Color = {
									type = "color", order = 30, name = "Color", hasAlpha = true, width = "half",
									get = function(info)
										local t = pp.countColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.countColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								Space = { type = "description", name = "", order = 100 },
								Outline = {
									type = "toggle", order = 110, name = "Outline", width = "half",
									desc = "Add black outline.",
									get = function(info) return pp.countFontFlags.outline end,
									set = function(info, value) pp.countFontFlags.outline = value; UpdateAll() end,
								},
								Thick = {
									type = "toggle", order = 120, name = "Thick", width = "half",
									desc = "Add thick black outline.",
									get = function(info) return pp.countFontFlags.thick end,
									set = function(info, value) pp.countFontFlags.thick = value; UpdateAll() end,
								},
								Mono = {
									type = "toggle", order = 130, name = "Mono", width = "half",
									desc = "Render font without antialiasing.",
									get = function(info) return pp.countFontFlags.mono end,
									set = function(info, value) pp.countFontFlags.mono = value; UpdateAll() end,
								},
								Shadow = {
									type = "toggle", order = 140, name = "Shadow", width = "half",
									desc = "Render font with shadow.",
									get = function(info) return pp.countShadow end,
									set = function(info, value) pp.countShadow = value; UpdateAll() end,
								},
							},
						},
					},
				},
				LabelTextGroup = {
					type = "group", order = 60, name = "Label Text", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing count, if greater than one, with each icon.",
							get = function(info) return pp.showLabel end,
							set = function(info, value) pp.showLabel = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 20, name = "Appearance", inline = true,
							args = {
								Font = {
									type = "select", order = 10, name = "Font",
									desc = "Select font.",
									dialogControl = "LSM30_Font",
									values = AceGUIWidgetLSMlists.font,
									get = function(info) return pp.labelFont end,
									set = function(info, value)
										pp.labelFont = value
										pp.labelFontPath = MOD.LSM:Fetch("font", value)
										UpdateAll()
									end,
								},
								FontSize = {
									type = "range", order = 20, name = "Font Size", min = 5, max = 50, step = 1,
									desc = "Set font size.",
									get = function(info) return pp.labelFontSize end,
									set = function(info, value) pp.labelFontSize = value; UpdateAll() end,
								},
								Color = {
									type = "color", order = 30, name = "Color", hasAlpha = true, width = "half",
									get = function(info)
										local t = pp.labelColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.labelColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								Space = { type = "description", name = "", order = 100 },
								Outline = {
									type = "toggle", order = 110, name = "Outline", width = "half",
									desc = "Add black outline.",
									get = function(info) return pp.labelFontFlags.outline end,
									set = function(info, value) pp.labelFontFlags.outline = value; UpdateAll() end,
								},
								Thick = {
									type = "toggle", order = 120, name = "Thick", width = "half",
									desc = "Add thick black outline.",
									get = function(info) return pp.labelFontFlags.thick end,
									set = function(info, value) pp.labelFontFlags.thick = value; UpdateAll() end,
								},
								Mono = {
									type = "toggle", order = 130, name = "Mono", width = "half",
									desc = "Render font without antialiasing.",
									get = function(info) return pp.labelFontFlags.mono end,
									set = function(info, value) pp.labelFontFlags.mono = value; UpdateAll() end,
								},
								Shadow = {
									type = "toggle", order = 140, name = "Shadow", width = "half",
									desc = "Render font with shadow.",
									get = function(info) return pp.labelShadow end,
									set = function(info, value) pp.labelShadow = value; UpdateAll() end,
								},
							},
						},
					},
				},
			},
		},
	},
}
