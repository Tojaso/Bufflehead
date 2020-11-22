-- Options.lua contains the tables used by the Buffle options panel as well its supporting functions

local MOD = Buffle
local _
local initialized = false -- set when options are first accessed
local pg, pp -- global and character-specific profiles

local acereg = LibStub("AceConfigRegistry-3.0")
local acedia = LibStub("AceConfigDialog-3.0")

local weaponBuffs = { ["Mainhand Weapon"] = true, ["Offhand Weapon"] = true }

local anchorPoints = { BOTTOM = "BOTTOM", BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT", CENTER = "CENTER", LEFT = "LEFT",
	RIGHT = "RIGHT", TOP = "TOP", TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT" }

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
				CountTextGroup = {
					type = "group", order = 50, name = "Count Text", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing count, if greater than one, with each icon.",
							get = function(info) return pp.showCount end,
							set = function(info, value) pp.showCount = value; UpdateAll() end,
						},
						DetailsGroup = {
							type = "toggle", order = 20, name = "More ...",
							descStyle = "inline",
							hidden = function(info) return not pp.showCount end,
							get = function(info) return pp.showCountDetails end,
							set = function(info, value) pp.showCountDetails = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 30, name = "Appearance", inline = true,
							hidden = function(info) return not pp.showCount or not pp.showCountDetails end,
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
							desc = "Enable showing a label with the spell name for each icon. Be sure to allow " ..
								"room for long labels and set maximum width as needed to prevent overlaps.",
							get = function(info) return pp.showLabel end,
							set = function(info, value) pp.showLabel = value; UpdateAll() end,
						},
						DetailsGroup = {
							type = "toggle", order = 20, name = "More ...",
							descStyle = "inline",
							hidden = function(info) return not pp.showLabel end,
							get = function(info) return pp.showLabelDetails end,
							set = function(info, value) pp.showLabelDetails = value; UpdateAll() end,
						},
						PositionGroup = {
							type = "group", order = 30, name = "Position", inline = true,
							hidden = function(info) return not pp.showLabel or not pp.showLabelDetails end,
							args = {
								AnchorIcon = {
									type = "toggle", order = 10, name = "Icon Relative",
									desc = "Set position relative to icon.",
									get = function(info) return not pp.showBar or (pp.labelPosition.anchor ~= "bar") end,
									set = function(info, value) pp.labelPosition.anchor = "icon"; UpdateAll() end,
								},
								AnchorBar = {
									type = "toggle", order = 20, name = "Timer Bar Relative",
									desc = "Set position relative to timer bar.",
									disabled = function(info) return not pp.showBar end,
									get = function(info) return pp.labelPosition.anchor == "bar" end,
									set = function(info, value) pp.labelPosition.anchor = "bar"; UpdateAll() end,
								},
								Space = { type = "description", name = "", order = 100 },
								RelativePoint = {
									type = "select", order = 110, name = "Relative Point",
									desc = function(info) return "Select relative point on " .. ((pp.showBar and (pp.labelPosition.anchor == "bar")) and "bar." or "icon.") end,
									get = function(info) return pp.labelPosition.relativePoint end,
									set = function(info, value) pp.labelPosition.relativePoint = value end,
									values = function(info) return anchorPoints end,
									style = "dropdown",
								},
								AnchorPoint = {
									type = "select", order = 120, name = "Anchor Point",
									desc = "Select anchor point on label, aligning text as needed.",
									get = function(info) return pp.labelPosition.point end,
									set = function(info, value) pp.labelPosition.point = value end,
									values = function(info) return anchorPoints end,
									style = "dropdown",
								},
								Horizontal = {
									type = "range", order = 130, name = "Offset X", min = -100, max = 100, step = 1,
									desc = "Set horizontal offset from the anchor.",
									get = function(info) return pp.labelPosition.offsetX end,
									set = function(info, value) pp.labelPosition.offsetX = value; UpdateAll() end,
								},
								Vertical = {
									type = "range", order = 140, name = "Offset Y", min = -100, max = 100, step = 1,
									desc = "Set vertical offset from the anchor.",
									get = function(info) return pp.labelPosition.offsetY end,
									set = function(info, value) pp.labelPosition.offsetY = value; UpdateAll() end,
								},
							},
						},
						AppearanceGroup = {
							type = "group", order = 40, name = "Appearance", inline = true,
							hidden = function(info) return not pp.showLabel or not pp.showLabelDetails end,
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
				TimeTextGroup = {
					type = "group", order = 70, name = "Time Text", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing formatted time text with each icon.",
							get = function(info) return pp.showTime end,
							set = function(info, value) pp.showTime = value; UpdateAll() end,
						},
						DetailsGroup = {
							type = "toggle", order = 20, name = "More ...",
							descStyle = "inline",
							hidden = function(info) return not pp.showTime end,
							get = function(info) return pp.showTimeDetails end,
							set = function(info, value) pp.showTimeDetails = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 30, name = "Appearance", inline = true,
							hidden = function(info) return not pp.showTime or not pp.showTimeDetails end,
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
				ClockOverlayGroup = {
					type = "group", order = 80, name = "Clock Overlay", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing time left with a clock overlay on each icon.",
							get = function(info) return pp.showClock end,
							set = function(info, value) pp.showClock = value; UpdateAll() end,
						},
						DetailsGroup = {
							type = "toggle", order = 20, name = "More ...",
							descStyle = "inline",
							hidden = function(info) return not pp.showClock end,
							get = function(info) return pp.showClockDetails end,
							set = function(info, value) pp.showClockDetails = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 30, name = "Appearance", inline = true,
							hidden = function(info) return not pp.showClock or not pp.showClockDetails end,
							args = {
								Color = {
									type = "color", order = 10, name = "Color", hasAlpha = true, width = "half",
									desc = "Set the clock overlay color. Be sure to adjust the color's transparency as desired to see through the overlay.",
									get = function(info)
										local t = pp.clockColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.clockColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								Edge = {
									type = "toggle", order = 20, name = "Edge", width = "half",
									desc = "Set the clock overlay to have a bright moving edge.",
									get = function(info) return pp.clockEdge end,
									set = function(info, value) pp.clockEdge = value; UpdateAll() end,
								},
								Reverse = {
									type = "toggle", order = 30, name = "Reverse", width = "half",
									desc = "Set the clock overlay to display reversed.",
									get = function(info) return pp.clockReverse end,
									set = function(info, value) pp.clockReverse = value; UpdateAll() end,
								},
							},
						},
					},
				},
				TimerBarGroup = {
					type = "group", order = 90, name = "Timer Bar", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing a timer bar with each icon.",
							get = function(info) return pp.showBar end,
							set = function(info, value) pp.showBar = value; UpdateAll() end,
						},
						DetailsGroup = {
							type = "toggle", order = 20, name = "More ...",
							descStyle = "inline",
							hidden = function(info) return not pp.showBar end,
							get = function(info) return pp.showBarDetails end,
							set = function(info, value) pp.showBarDetails = value; UpdateAll() end,
						},
						AppearanceGroup = {
							type = "group", order = 30, name = "Appearance", inline = true,
							hidden = function(info) return not pp.showBar or not pp.showBarDetails end,
							args = {
								ColorsGroup = {
									type = "group", order = 40, name = "Colors", inline = true,
									args = {
										BuffColor = {
											type = "color", order = 10, name = "Buffs", hasAlpha = true,
											desc = "Set color for buff bars.",
											get = function(info) local t = pp.barBuffColor return t.r, t.g, t.b, t.a end,
											set = function(info, r, g, b, a) local t = pp.barBuffColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
										},
										DebuffColor = {
											type = "color", order = 20, name = "Debuffs", hasAlpha = true,
											desc = "Set color for debuff bars.",
											get = function(info) local t = pp.barDebuffColor return t.r, t.g, t.b, t.a end,
											set = function(info, r, g, b, a) local t = pp.barDebuffColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
										},
										BarBorderColor = {
											type = "color", order = 30, name = "Bar Border Color", hasAlpha = true,
											desc = "Set color for bar border.",
											get = function(info) local t = pp.barBorderColor return t.r, t.g, t.b, t.a end,
											set = function(info, r, g, b, a) local t = pp.barBorderColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
										},
										BackgroundOpacity = {
											type = "range", order = 40, name = "Background Opacity", min = 0, max = 1, step = 0.05,
											desc = "Set background opacity for bars.",
											get = function(info) return pp.barBackgroundOpacity end,
											set = function(info, value) pp.barBackgroundOpacity = value; UpdateAll() end,
										},
									},
								},
							},
						},
					},
				},
			},
		},
	},
}
