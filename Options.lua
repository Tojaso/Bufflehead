-- Options.lua contains the tables used by the Buffle options panel as well its supporting functions

local MOD = Buffle
local _
local initialized = false -- set when options are first accessed
local pg, pp -- global and character-specific profiles
local selectPreset = 1

local HEADER_NAME = "BuffleSecureHeader"
local PLAYER_BUFFS = "PlayerBuffs"
local PLAYER_DEBUFFS = "PlayerDebuffs"
local HEADER_PLAYER_BUFFS = HEADER_NAME .. PLAYER_BUFFS
local HEADER_PLAYER_DEBUFFS = HEADER_NAME .. PLAYER_DEBUFFS

local acereg = LibStub("AceConfigRegistry-3.0")
local acedia = LibStub("AceConfigDialog-3.0")

local weaponBuffs = { ["Mainhand Weapon"] = true, ["Offhand Weapon"] = true }

local anchorPoints = { BOTTOM = "BOTTOM", BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT", CENTER = "CENTER", LEFT = "LEFT",
	RIGHT = "RIGHT", TOP = "TOP", TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT" }

local sortMethods = { INDEX = "Sort by index", NAME = "Sort by name", TIME = "Sort by time left" }
local sortDirections = { ["+"] = "Ascending", ["-"] = "Descending" }
local separateOwnOptions = { [0] = "Don't separate", [1] = "Sort before others", [-1] = "Sort after others"}

-- Call main function to update all settings.
local function UpdateAll() MOD.UpdateAll() end

-- Update options in case anything changes
local function UpdateOptions()
	if initialized and acedia.OpenFrames["Buffle"] then
		acereg:NotifyChange("Buffle")
	end
	UpdateAll()
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
		MOD.uiOpen = false
	else
		acedia:Open("Buffle")
		MOD.uiOpen = true
	end
	if not InCombatLockdown() then collectgarbage("collect") end -- don't do in combat because could cause freezes/script too long error
end

-- Prepare a table of time format options showing examples to choose from with select dropdown menu
local function GetTimeFormatList(s, c)
	local i, menu = 1, {}
	while i <= #MOD.TimeFormatOptions do
		local f = MOD.FormatTime
		local t1, t2, t3, t4, t5 = f(8125.8, i, s, c), f(343.8, i, s, c), f(75.3, i, s, c), f(42.7, i, s, c), f(3.6, i, s, c)
		menu[i] = t1 .. ", " .. t2 .. ", " .. t3 .. ", " .. t4 .. ", " .. t5
		i = i + 1
	end
	return menu
end

-- Some changes require reload of the UI, ask for confirmation before making the change
local function ConfirmChange() return "Changing this setting requires that you reload your user interface. Continue?" end

-- Applying a preset will overwrite most current settings so ask for confirmation
local function ConfirmPreset() return "Applying a preset will overwrite current settings. Continue?" end

-- Reload the UI
local function ReloadUI() C_UI.Reload() end

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
							confirm = ConfirmChange,
							get = function(info) return pg.enabled end,
							set = function(info, value) pg.enabled = value; ReloadUI() end,
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
							desc = "If checked, hide the default Blizzard buffs and debuffs.",
							confirm = ConfirmChange,
							get = function(info) return pg.hideBlizz end,
							set = function(info, value) pg.hideBlizz = value; ReloadUI() end,
						},
						EnableHideOmniCC = {
							type = "toggle", order = 40, name = "Hide OmniCC",
							desc = "If checked, the OmniCC addon can show time left on icons.",
							hidden = function(info) return not OmniCC end, -- only show if OmniCC is loaded
							confirm = ConfirmChange,
							get = function(info) return pg.hideOmniCC  end,
							set = function(info, value) pg.hideOmniCC = value; ReloadUI() end,
						},
						Spacer = { type = "description", name = "", order = 100 },
						EnableBuffs = {
							type = "toggle", order = 110, name = "Show Player Buffs",
							desc = "If checked, display player buffs.",
							confirm = ConfirmChange,
							get = function(info) return pp.groups[HEADER_PLAYER_BUFFS].enabled end,
							set = function(info, value) pp.groups[HEADER_PLAYER_BUFFS].enabled = value; ReloadUI() end,
						},
						EnableWeaponEnchants = {
							type = "toggle", order = 120, name = "Include Weapon Enchants",
							desc = "If checked, include weapon enchants in player buffs.",
							confirm = ConfirmChange,
							get = function(info) return pp.weaponEnchants end,
							set = function(info, value) pp.weaponEnchants = value; ReloadUI() end,
						},
						EnableDebuffs = {
							type = "toggle", order = 130, name = "Show Player Debuffs",
							desc = "If checked, also display player debuffs.",
							confirm = ConfirmChange,
							get = function(info) return pp.groups[HEADER_PLAYER_DEBUFFS].enabled end,
							set = function(info, value) pp.groups[HEADER_PLAYER_DEBUFFS].enabled = value; ReloadUI() end,
						},
					},
				},
				PresetsGroup = {
					type = "group", order = 20, name = "Presets", inline = true,
					args = {
						Description = {
							type = "description", order = 1, name = "These presets demonstrate several ways Buffle can be configured " ..
							"(use Toggle Previews to check them out). " ..
							"Presets also provide a convenient starting point for new users. " ..
							"Please note that presets overwrite all settings so be sure to use profiles to save/restore when necessary."
						},
						IconTextGroup = {
							type = "toggle", order = 10, name = "Icons + Time",
							get = function(info) return selectPreset == 1 end,
							set = function(info, value) selectPreset = 1 end,
						},
						Spacer1 = { type = "description", order = 11, width = "double",
							name = function() return "Icons laid out horizontally with time below each icon (default)." end,
						},
						Spacer1A = { type = "description", name = "", order = 12 },
						IconClockGroup = {
							type = "toggle", order = 20, name = "Icons + Clock",
							get = function(info) return selectPreset == 2 end,
							set = function(info, value) selectPreset = 2 end,
						},
						Spacer2 = { type = "description", order = 21, width = "double",
							name = function() return "Icons with clock overlays laid out vertically." end,
						},
						Spacer2A = { type = "description", name = "", order = 22 },
						IconMiniBarGroup = {
							type = "toggle", order = 30, name = "Icons + Mini-Bars",
							get = function(info) return selectPreset == 3 end,
							set = function(info, value) selectPreset = 3 end,
						},
						Spacer3 = { type = "description", order = 31, width = "double",
							name = function() return "Icons laid out horizontally with a timer mini-bar below each icon." end,
						},
						Spacer3A = { type = "description", name = "", order = 32 },
						HorizontalBarGroup = {
							type = "toggle", order = 40, name = "Full-Size Bars",
							get = function(info) return selectPreset == 4 end,
							set = function(info, value) selectPreset = 4 end,
						},
						Spacer4 = { type = "description", order = 41, width = "double",
							name = function() return "Full-size timer bars with labels." end,
						},
						Spacer4A = { type = "description", name = "", order = 42 },
						ApplyPreset = {
							type = "execute", order = 100, name = "Apply Preset",
							desc = "Apply the selected preset.",
							confirm = ConfirmPreset,
							func = function(info) MOD.ApplyPreset() end,
						},
						PreviewToggle = {
							type = "execute", order = 110, name = "Toggle Previews",
							desc = "Toggle display of previews. Previews show what a full set of player buffs/debuffs look like.",
							func = function(info) MOD.TogglePreviews(); UpdateAll() end,
						},
					},
				},
				PositionGroup = {
					type = "group", order = 30, name = "Position", inline = true,
					args = {
						AnchorToggle = {
							type = "execute", order = 10, name = "Toggle Anchors",
							desc = "Toggle display of anchors. When unlocked, anchors can be moved by clicking and dragging with the mouse.",
							func = function(info) MOD.ToggleAnchors(); UpdateAll() end,
						},
					},
				},
			},
		},
		IconGroup = {
			type = "group", order = 20, name = "Icons",
			args = {
				DimensionGroup = {
					type = "group", order = 10, name = "Size and Spacing", inline = true,
					args = {
						IconSize = {
							type = "range", order = 10, name = "Icon Size", min = 12, max = 64, step = 2,
							desc = "Set icon's width and height.",
							get = function(info) return pp.iconSize end,
							set = function(info, value) pp.iconSize = value; UpdateAll() end,
						},
						SpacingX = {
							type = "range", order = 20, name = "Horizontal Spacing", min = 0, max = 100, step = 1,
							desc = "Adjust horizontal spacing between icons.",
							get = function(info) return pp.spaceX end,
							set = function(info, value) pp.spaceX = value; UpdateAll() end,
						},
						SpacingY = {
							type = "range", order = 30, name = "Vertical Spacing", min = 0, max = 100, step = 1,
							desc = "Adjust vertical spacing between icons.",
							get = function(info) return pp.spaceY end,
							set = function(info, value) pp.spaceY = value; UpdateAll() end,
						},
					},
				},
				GrowGroup = {
					type = "group", order = 20, name = "Layout", inline = true,
					args = {
						Orientation = {
							type = "toggle", order = 10, name = "Orientation",
							desc = "If checked, icons are laid out horizontally in rows, otherwise vertically in columns.",
							get = function(info) return pp.growDirection == 1 end,
							set = function(info, value) pp.growDirection = (value and 1 or 0); UpdateAll() end,
						},
						HorizontalDirection = {
							type = "toggle", order = 20, name = "Horizontal Direction",
							desc = "If checked, horizontal direction is right-to-left, otherwise left-to-right.",
							get = function(info) return pp.directionX == -1 end,
							set = function(info, value) pp.directionX = (value and -1 or 1); UpdateAll() end,
						},
						VerticalDirection = {
							type = "toggle", order = 30, name = "Vertical Direction",
							desc = "If checked, vertical direction is top-to-bottom, otherwise bottom-to-top.",
							get = function(info) return pp.directionY == -1 end,
							set = function(info, value) pp.directionY = (value and -1 or 1); UpdateAll() end,
						},
						Spacer = { type = "description", name = "", order = 100 },
						WrapAfter = {
							type = "range", order = 110, name = "Wrap After", min = 1, max = 40, step = 1,
							desc = "Set the number of icons before wrapping to the next row or column. " ..
							"There can be no more than 40 total icons, independent of the number of rows and columns.",
							get = function(info) return pp.wrapAfter end,
							set = function(info, value) pp.wrapAfter = value; UpdateAll() end,
						},
						MaxWraps = {
							type = "range", order = 120, name = "Maximum Wraps", min = 1, max = 40, step = 1,
							desc = "Set the number of times that icons can wrap to another row or column. " ..
							"There can be no more than 40 total icons, independent of the number of rows and columns.",
							get = function(info) return pp.maxWraps end,
							set = function(info, value) pp.maxWraps = value; UpdateAll() end,
						},
					},
				},
				SortGroup = {
					type = "group", order = 30, name = "Sorting", inline = true,
					args = {
						SortMethod = {
							type = "select", order = 10, name = "Sort Method",
							desc = function(info) return "Select whether to sort by time, name, or index." end,
							get = function(info) return pp.sortMethod end,
							set = function(info, value) pp.sortMethod = value; UpdateAll() end,
							values = function(info) return sortMethods end,
							style = "dropdown",
						},
						SortDirection = {
							type = "select", order = 20, name = "Sort Direction",
							desc = function(info) return "Select whether to sort by ascending or descending values." end,
							get = function(info) return pp.sortDirection end,
							set = function(info, value) pp.sortDirection = value; UpdateAll() end,
							values = function(info) return sortDirections end,
							style = "dropdown",
						},
						SeparateOwn = {
							type = "select", order = 30, name = "Separate Own",
							desc = function(info) return "Select whether to separate buffs and debuffs cast by the player and show them before or after others." end,
							get = function(info) return pp.separateOwn end,
							set = function(info, value) pp.separateOwn = value; UpdateAll() end,
							values = function(info) return separateOwnOptions end,
							style = "dropdown",
						},
					},
				},
				IconBorderGroup = {
					type = "group", order = 40, name = "Icon Border", inline = true,
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
						Spacer = { type = "description", name = "", order = 100 },
						BorderColor = {
							type = "color", order = 110, name = "Border Color", hasAlpha = true,
							desc = "Set color for icon borders.",
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
				ClockOverlayGroup = {
					type = "group", order = 50, name = "Clock Overlay", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable",
							desc = "Enable showing time left with a clock overlay on each icon.",
							get = function(info) return pp.showClock end,
							set = function(info, value) pp.showClock = value; UpdateAll() end,
						},
						Color = {
							type = "color", order = 20, name = "Color", hasAlpha = true, width = "half",
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
							type = "toggle", order = 30, name = "Edge", width = "half",
							desc = "Set the clock overlay to have a bright moving edge.",
							get = function(info) return pp.clockEdge end,
							set = function(info, value) pp.clockEdge = value; UpdateAll() end,
						},
						Reverse = {
							type = "toggle", order = 40, name = "Reverse", width = "half",
							desc = "Set the clock overlay to display reversed.",
							get = function(info) return pp.clockReverse end,
							set = function(info, value) pp.clockReverse = value; UpdateAll() end,
						},
					},
				},
			},
		},
		CountTextGroup = {
			type = "group", order = 40, name = "Count Text",
			args = {
				EnableGroup = {
					type = "toggle", order = 10, name = "Enable",
					desc = "Enable showing count, if greater than one, with each icon.",
					get = function(info) return pp.showCount end,
					set = function(info, value) pp.showCount = value; UpdateAll() end,
				},
				PositionGroup = {
					type = "group", order = 20, name = "Position", inline = true,
					args = {
						AnchorIcon = {
							type = "toggle", order = 10, name = "Icon Relative",
							desc = "Set position relative to icon.",
							get = function(info) return not pp.showBar or (pp.countPosition.anchor ~= "bar") end,
							set = function(info, value) pp.countPosition.anchor = "icon"; UpdateAll() end,
						},
						AnchorBar = {
							type = "toggle", order = 20, name = "Timer Bar Relative",
							desc = "Set position relative to timer bar.",
							disabled = function(info) return not pp.showBar end,
							get = function(info) return pp.countPosition.anchor == "bar" end,
							set = function(info, value) pp.countPosition.anchor = "bar"; UpdateAll() end,
						},
						Space = { type = "description", name = "", order = 100 },
						RelativePoint = {
							type = "select", order = 110, name = "Relative Point",
							desc = function(info) return "Select relative point on " .. ((pp.showBar and (pp.countPosition.anchor == "bar")) and "bar." or "icon.") end,
							get = function(info) return pp.countPosition.relativePoint end,
							set = function(info, value) pp.countPosition.relativePoint = value end,
							values = function(info) return anchorPoints end,
							style = "dropdown",
						},
						AnchorPoint = {
							type = "select", order = 120, name = "Anchor Point",
							desc = "Select anchor point on count text, aligning as needed.",
							get = function(info) return pp.countPosition.point end,
							set = function(info, value) pp.countPosition.point = value end,
							values = function(info) return anchorPoints end,
							style = "dropdown",
						},
						Horizontal = {
							type = "range", order = 130, name = "Offset X", min = -100, max = 100, step = 1,
							desc = "Set horizontal offset from the anchor.",
							get = function(info) return pp.countPosition.offsetX end,
							set = function(info, value) pp.countPosition.offsetX = value; UpdateAll() end,
						},
						Vertical = {
							type = "range", order = 140, name = "Offset Y", min = -100, max = 100, step = 1,
							desc = "Set vertical offset from the anchor.",
							get = function(info) return pp.countPosition.offsetY end,
							set = function(info, value) pp.countPosition.offsetY = value; UpdateAll() end,
						},
					},
				},
				AppearanceGroup = {
					type = "group", order = 30, name = "Appearance", inline = true,
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
			type = "group", order = 50, name = "Label Text",
			args = {
				EnableGroup = {
					type = "toggle", order = 10, name = "Enable",
					desc = "Enable showing a label with the spell name for each icon. Be sure to allow " ..
						"room for long labels and set maximum width as needed to prevent overlaps.",
					get = function(info) return pp.showLabel end,
					set = function(info, value) pp.showLabel = value; UpdateAll() end,
				},
				PositionGroup = {
					type = "group", order = 20, name = "Position", inline = true,
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
							desc = "Select anchor point on label text, aligning as needed.",
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
					type = "group", order = 30, name = "Appearance", inline = true,
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
				WrapGroup = {
					type = "group", order = 40, name = "Wrapping", inline = true,
					args = {
						TextWrap = {
							type = "toggle", order = 10, name = "Text Wrap",
							desc = "If checked, text can wrap to more than one line. Otherwise, long text is truncated.",
							get = function(info) return pp.labelWrap end,
							set = function(info, value) pp.labelWrap = value; UpdateAll() end,
						},
						WordWrap = {
							type = "toggle", order = 20, name = "Word Wrap",
							desc = "If checked, longer words can wrap to more than one line. Otherwise, long words are truncated.",
							get = function(info) return pp.labelWordWrap end,
							set = function(info, value) pp.labelWordWrap = value; UpdateAll() end,
						},
						MaxTextWidth = {
							type = "range", order = 30, name = "Maximum Text Width", min = 0, max = 500, step = 1,
							desc = "Set maximum width for text before wrapping or truncating. Set to 0 for unlimited width.",
							get = function(info) return pp.labelMaxWidth end,
							set = function(info, value) pp.labelMaxWidth = value; UpdateAll() end,
						},
					},
				},
			},
		},
		TimeTextGroup = {
			type = "group", order = 60, name = "Time Text",
			args = {
				EnableGroup = {
					type = "toggle", order = 10, name = "Enable",
					desc = "Enable showing formatted time text with each icon.",
					get = function(info) return pp.showTime end,
					set = function(info, value) pp.showTime = value; UpdateAll() end,
				},
				PositionGroup = {
					type = "group", order = 20, name = "Position", inline = true,
					args = {
						AnchorIcon = {
							type = "toggle", order = 10, name = "Icon Relative",
							desc = "Set position relative to icon.",
							get = function(info) return not pp.showBar or (pp.timePosition.anchor ~= "bar") end,
							set = function(info, value) pp.timePosition.anchor = "icon"; UpdateAll() end,
						},
						AnchorBar = {
							type = "toggle", order = 20, name = "Timer Bar Relative",
							desc = "Set position relative to timer bar.",
							disabled = function(info) return not pp.showBar end,
							get = function(info) return pp.timePosition.anchor == "bar" end,
							set = function(info, value) pp.timePosition.anchor = "bar"; UpdateAll() end,
						},
						Space = { type = "description", name = "", order = 100 },
						RelativePoint = {
							type = "select", order = 110, name = "Relative Point",
							desc = function(info) return "Select relative point on " .. ((pp.showBar and (pp.timePosition.anchor == "bar")) and "bar." or "icon.") end,
							get = function(info) return pp.timePosition.relativePoint end,
							set = function(info, value) pp.timePosition.relativePoint = value end,
							values = function(info) return anchorPoints end,
							style = "dropdown",
						},
						AnchorPoint = {
							type = "select", order = 120, name = "Anchor Point",
							desc = "Select anchor point on time text, aligning as needed.",
							get = function(info) return pp.timePosition.point end,
							set = function(info, value) pp.timePosition.point = value end,
							values = function(info) return anchorPoints end,
							style = "dropdown",
						},
						Horizontal = {
							type = "range", order = 130, name = "Offset X", min = -100, max = 100, step = 1,
							desc = "Set horizontal offset from the anchor.",
							get = function(info) return pp.timePosition.offsetX end,
							set = function(info, value) pp.timePosition.offsetX = value; UpdateAll() end,
						},
						Vertical = {
							type = "range", order = 140, name = "Offset Y", min = -100, max = 100, step = 1,
							desc = "Set vertical offset from the anchor.",
							get = function(info) return pp.timePosition.offsetY end,
							set = function(info, value) pp.timePosition.offsetY = value; UpdateAll() end,
						},
					},
				},
				AppearanceGroup = {
					type = "group", order = 30, name = "Appearance", inline = true,
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
						Space1 = { type = "description", name = "", order = 200 },
						TimeFormat = {
							type = "select", order = 210, name = "Time Format", width = "double",
							desc = "Select format for time text.",
							get = function(info) return pp.timeFormat end,
							set = function(info, value) pp.timeFormat = value; UpdateAll() end,
							values = function(info)
								local s, c = pp.timeSpaces, pp.timeCase
								return GetTimeFormatList(s, c)
							end,
							style = "dropdown",
						},
						Spaces = {
							type = "toggle", order = 220, name = "Spaces", width = "half",
							desc = "Include spaces between values in time format.",
							get = function(info) return pp.timeSpaces end,
							set = function(info, value) pp.timeSpaces = value; UpdateAll() end,
						},
						Capitals = {
							type = "toggle", order = 230, name = "H,M,S", width = "half",
							desc = "If checked, use uppercase H, M and S in time format, otherwise use lowercase.",
							get = function(info) return pp.timeCase end,
							set = function(info, value) pp.timeCase = value; UpdateAll() end,
						},
					},
				},
			},
		},
		TimerBarGroup = {
			type = "group", order =80, name = "Timer Bars",
			args = {
				EnableGroup = {
					type = "toggle", order = 10, name = "Enable",
					desc = "Enable showing a timer bar with each icon.",
					get = function(info) return pp.showBar end,
					set = function(info, value) pp.showBar = value; UpdateAll() end,
				},
				LayoutGroup = {
					type = "group", order = 20, name = "Layout", inline = true,
					args = {
						BarWidth = {
							type = "range", order = 10, name = "Width", min = 0, max = 400, step = 2,
							desc = "Set timer bar's width (if set to 0 then same as icon's size).",
							get = function(info) return pp.barWidth end,
							set = function(info, value) pp.barWidth = value; UpdateAll() end,
						},
						BarHeight = {
							type = "range", order = 20, name = "Height", min = 0, max = 400, step = 2,
							desc = "Set timer bar's height (if set to 0 then same as icon's size).",
							get = function(info) return pp.barHeight end,
							set = function(info, value) pp.barHeight = value; UpdateAll() end,
						},
						BarOrientation = {
							type = "toggle", order = 30, name = "Orientation",
							desc = "If checked, timer bar is displayed in horizontal orientation, otherwise in vertical orientation.",
							get = function(info) return pp.barOrientation end,
							set = function(info, value) pp.barOrientation = value; UpdateAll() end,
						},
						BarDirection = {
							type = "toggle", order = 40, name = "Direction",
							desc = "If checked, horizontal bars are left-to-right and vertical bars are bottom-to-top. " ..
								"If not checked, horizontal bars are right-to-left and vertical bars are top-to-bottom.",
							get = function(info) return pp.barDirection end,
							set = function(info, value) pp.barDirection = value; UpdateAll() end,
						},
					},
				},
				PositionGroup = {
					type = "group", order = 30, name = "Position", inline = true,
					args = {
						RelativePoint = {
							type = "select", order = 110, name = "Relative Point",
							desc = function(info) return "Select relative point on icon." end,
							get = function(info) return pp.barPosition.relativePoint end,
							set = function(info, value) pp.barPosition.relativePoint = value end,
							values = function(info) return anchorPoints end,
							style = "dropdown",
						},
						AnchorPoint = {
							type = "select", order = 120, name = "Anchor Point",
							desc = "Select anchor point on timer bar.",
							get = function(info) return pp.barPosition.point end,
							set = function(info, value) pp.barPosition.point = value end,
							values = function(info) return anchorPoints end,
							style = "dropdown",
						},
						Horizontal = {
							type = "range", order = 130, name = "Offset X", min = -100, max = 100, step = 1,
							desc = "Set horizontal offset from the anchor.",
							get = function(info) return pp.barPosition.offsetX end,
							set = function(info, value) pp.barPosition.offsetX = value; UpdateAll() end,
						},
						Vertical = {
							type = "range", order = 140, name = "Offset Y", min = -100, max = 100, step = 1,
							desc = "Set vertical offset from the anchor.",
							get = function(info) return pp.barPosition.offsetY end,
							set = function(info, value) pp.barPosition.offsetY = value; UpdateAll() end,
						},
					},
				},
				AppearanceGroup = {
					type = "group", order = 40, name = "Appearance", inline = true,
					args = {
						BorderGroup = {
							type = "group", order = 10, name = "Bar Border", inline = true,
							args = {
								DefaultBorder = {
									type = "toggle", order = 10, name = "None", width = "half",
									desc = "Do not display bar borders.",
									get = function(info) return pp.barBorder == "none" end,
									set = function(info, value) pp.barBorder = "none"; UpdateAll() end,
								},
								OnePixelBorder = {
									type = "toggle", order = 20, name = "Pixel", width = "half",
									desc = "Use single pixel bar borders (requires bar width and height greater than 4).",
									get = function(info) return pp.barBorder == "one" end,
									set = function(info, value) pp.barBorder = "one"; UpdateAll() end,
								},
								TwoPixelBorder = {
									type = "toggle", order = 30, name = "Two Pixel",
									desc = "Use two pixel bar borders (requires bar width and height greater than 4).",
									get = function(info) return pp.barBorder == "two" end,
									set = function(info, value) pp.barBorder = "two"; UpdateAll() end,
								},
								BorderColor = {
									type = "color", order = 40, name = "Border Color", hasAlpha = true,
									desc = "Set color for bar borders.",
									get = function(info) local t = pp.barBorderColor return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a) local t = pp.barBorderColor t.r = r; t.g = g; t.b = b; t.a = a; UpdateAll() end,
								},
							},
						},
						ColorsGroup = {
							type = "group", order = 20, name = "Bar Colors", inline = true,
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
								BackgroundOpacity = {
									type = "range", order = 30, name = "Background Opacity", min = 0, max = 1, step = 0.05,
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
}
