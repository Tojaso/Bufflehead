-- Options.lua contains the tables used by the Bufflehead options panel as well its supporting functions

local MOD = Bufflehead
local _
local initialized = false -- set when options are first accessed
local pg, pp -- global and character-specific profiles
local templateType = "icons"
local selectedTemplate = 0
local savedProfile = false -- set when template is used

local HEADER_NAME = "BuffleheadSecureHeader"
local PLAYER_BUFFS = "PlayerBuffs"
local PLAYER_DEBUFFS = "PlayerDebuffs"
local HEADER_PLAYER_BUFFS = HEADER_NAME .. PLAYER_BUFFS
local HEADER_PLAYER_DEBUFFS = HEADER_NAME .. PLAYER_DEBUFFS
local DEFAULT_SPACING = 4
local MINIBAR_WIDTH = 10

local acereg = LibStub("AceConfigRegistry-3.0")
local acedia = LibStub("AceConfigDialog-3.0")

local weaponBuffs = { ["Mainhand Weapon"] = true, ["Offhand Weapon"] = true }

local anchorPoints = { BOTTOM = "BOTTOM", BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT", CENTER = "CENTER", LEFT = "LEFT",
	RIGHT = "RIGHT", TOP = "TOP", TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT" }

local sortMethods = { INDEX = "Sort by index", NAME = "Sort by name", TIME = "Sort by time left" }
local sortDirections = { ["+"] = "Ascending", ["-"] = "Descending" }
local separateOwnOptions = { [0] = "Don't separate", [1] = "Sort before others", [-1] = "Sort after others"}

-- Helper function for copying table, potentially with multiple levels of embedded tables
local function CopyTable(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			local t = dst[k]
			if not t or (type(t) ~= "table") then t = {} end
			CopyTable(v, t)
			dst[k] = t
		else
			dst[k] = v
		end
	end
end

-- Shortcut function to update all settings
local function UpdateAll() MOD.UpdateAll() end

-- Update options in case anything changes
function MOD.UpdateOptions()
	if initialized and acedia.OpenFrames["Bufflehead"] then
		acereg:NotifyChange("Bufflehead")
	end
end

-- Function called when profile is changed
local function UpdateProfile()
	MOD.UpdateOptions()
	MOD.UpdateAll()
end

-- Register the options table and link to the Blizzard addons interface
local function InitializeOptions()
	initialized = true -- only do this once
	local options = MOD.OptionsTable
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(MOD.db) -- fill in the profile section
	acereg:RegisterOptionsTable("Bufflehead", options)
	acereg:RegisterOptionsTable("Bufflehead: "..options.args.BuffleheadOptions.name, options.args.BuffleheadOptions)
	acereg:RegisterOptionsTable("Bufflehead: "..options.args.profile.name, options.args.profile)
	acereg:RegisterOptionsTable("Bufflehead Options", MOD.BlizzardInterfaceOptionsTable)
	acedia:AddToBlizOptions("Bufflehead Options", "Bufflehead")
	pg = MOD.db.global; pp = MOD.db.profile

	local w, h = 890, 680 -- somewhat arbitrary numbers that seem to work for the configuration dialog layout
	acedia:SetDefaultSize("Bufflehead", w, h)

	MOD.db.RegisterCallback(MOD, "OnProfileChanged", UpdateProfile)
	MOD.db.RegisterCallback(MOD, "OnProfileCopied", UpdateProfile)
	MOD.db.RegisterCallback(MOD, "OnProfileReset", UpdateProfile)
end

-- Toggle display of the options panel
function MOD.ToggleOptions()
	if not initialized then InitializeOptions() end
	if acedia.OpenFrames["Bufflehead"] then
		acedia:Close("Bufflehead")
		MOD.uiOpen = false
	else
		acedia:Open("Bufflehead")
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

-- Applying a template will overwrite most current settings so ask for confirmation
-- local function ConfirmTemplate() return "Using a template will overwrite current settings. Continue?" end

-- Get list of available templates given setting for bar or icon orientation
function MOD.GetTemplates()
	local i, t = 0, {}
	for k, template in ipairs(MOD.SupportedTemplates) do
		if ((templateType == "icons") and template.icons) or ((templateType == "bars") and template.bars) then
			i = i + 1
			t[i] = template.desc
		end
	end
	if i == 0 then selectedTemplate = 0; return nil end
	if selectedTemplate == 0 then selectedTemplate = 1 end
	return t
end

-- Save current settings
function MOD.SaveProfile()
	if not savedProfile then savedProfile = {} end
	CopyTable(pp, savedProfile)
end

-- Restore saved settings
function MOD.RestoreProfile()
	if savedProfile then CopyTable(savedProfile, pp) end
end

-- Apply the selected preset to the profile, overwriting current settings
function MOD.UseTemplate()
	local bp = pp.barPosition
	local lp = pp.labelPosition
	local tp = pp.timePosition

	if selectedTemplate == 0 then return end

	local i = 0
	for k, template in ipairs(MOD.SupportedTemplates) do
		if ((templateType == "icons") and template.icons) or ((templateType == "bars") and template.bars) then
			i = i + 1
			if i == selectedTemplate then
				CopyTable(MOD.BaseTemplates[template.base], pp) -- apply base template to the current profile
				if templateType == "icons" then
					if template.time == "text" then -- apply optional settings for icons
						pp.showTime = true
					elseif template.time == "clock" then
						pp.showClock = true
					elseif template.time == "hbar" then
						pp.showBar = true
					elseif template.time == "vbar" then
						pp.showBar = true
						pp.spaceX = (3 * DEFAULT_SPACING) + MINIBAR_WIDTH
						pp.barOrientation = false -- vertical orientation
						pp.barWidth = MINIBAR_WIDTH -- swap dimensions from hbar
						pp.barHeight = 0
						local bp = pp.barPosition
						bp.point = "RIGHT"
						bp.relativePoint = "LEFT"
						bp.offsetX = -DEFAULT_SPACING
						bp.offsetY = 0
					end
				end
				UpdateAll()
				return
			end
		end
	end
end

-- Reload the UI
local function ReloadUI() C_UI.Reload() end

-- Create a mini-options table to be inserted at top level in the Blizz interface
MOD.BlizzardInterfaceOptionsTable = {
	type = "group", order = 1,
	args = {
		Configure = {
			type = "execute", order = 90, name = "Configure",
			desc = "Open Bufflehead's standalone options panel.",
			func = function(info) MOD.OptionsPanel() end,
		},
	},
}

-- Create the options table to be used by the configuration GUI
MOD.OptionsTable = {
	type = "group", childGroups = "tab",
	args = {
		BuffleheadOptions = {
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
								if value then MOD.ldbi:Show("Bufflehead") else MOD.ldbi:Hide("Bufflehead") end
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
							type = "toggle", order = 120, name = "Weapon Enchants",
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
				TemplatesGroup = {
					type = "group", order = 20, name = "Templates", inline = true,
					args = {
						Description = {
							type = "description", order = 1, name = "Templates provide a starting point for new users and " ..
							"also demonstrate the variety of ways that Bufflehead can be configured. " ..
							"Select the icon-oriented or bar-oriented template closest to your preferred way to display player buffs and debuffs. " ..
							"Click on the Use Template button to apply the template's settings. " ..
							"Click on the Toggle Previews button to show what full sets of player buffs and debuffs look like."
						},
						IconConfiguration = {
							type = "toggle", order = 10, name = "Icon Templates",
							desc = "If checked, list icon-oriented templates.",
							get = function(info) return templateType == "icons" end,
							set = function(info, value) if templateType ~= "icons" then templateType = "icons"; selectedTemplate = 0 end end,
						},
						BarConfiguration = {
							type = "toggle", order = 20, name = "Bar Templates",
							desc = "If checked, list bar-oriented templates.",
							get = function(info) return templateType == "bars" end,
							set = function(info, value) if templateType ~= "bars" then templateType = "bars"; selectedTemplate = 0 end end,
						},
						Spacer1 = { type = "description", name = "", order = 100 },
						Configuration = {
							type = "select", order = 110, name = "Templates", width = "double",
							desc = "Select a template option for bars or icons.",
							get = function(info) if selectedTemplate == 0 then return nil else return selectedTemplate end end,
							set = function(info, value) selectedTemplate = value end,
							values = function(info) return MOD.GetTemplates() end,
							style = "dropdown",
						},
						UseTemplate = {
							type = "execute", order = 120, name = "Use Template",
							desc = "Save current settings and switch to the selected template. " ..
								"This will overwrite all layout-related settings but does not change fonts and other appearance options. " ..
								"Click the Restore button to revert to the saved settings.",
							func = function(info)
								MOD.SaveProfile()
								MOD.UseTemplate(selectedTemplate)
							end,
						},
						RestoreProfile = {
							type = "execute", order = 130, name = "Restore", width = "half",
							desc = function(info)
								if savedProfile then
									return "Restore settings saved when Use Template was last clicked."
								else
									return "No settings have been saved yet."
								end
							end,
							func = function(info) MOD.RestoreProfile(); UpdateAll() end,
						},
					},
				},
				PositionGroup = {
					type = "group", order = 30, name = "Positions", inline = true,
					args = {
						ShowBoundingBoxes = {
							type = "toggle", order = 10, name = "Show Bounding Boxes",
							desc = "If enabled, bounding boxes are shown around player buff and debuff icons. " ..
							"Buff and debuff positions can be moved using click-and-drag in the associated bounding box." ..
							"Texts and timer bars may be outside the bounding boxes around icons so be sure to provide sufficient space.",
							get = function(info) return MOD.showAnchors end,
							set = function(info, value) MOD.showAnchors = value; UpdateAll() end,
						},
						PreviewToggle = {
							type = "execute", order = 20, name = "Toggle Previews",
							desc = "Toggle display of previews. Previews demonstrate what full sets of player buffs and debuffs look like.",
							func = function(info) MOD.TogglePreviews(); UpdateAll() end,
						},
						Spacer1 = { type = "description", name = "", order = 100 },
						BuffsHorizontal = {
							type = "range", order = 110, name = "Buffs Offset X", min = 0, max = 100, step = 0.01,
							desc = "Set buffs horizontal position as percentage of display width.",
							disabled = function(info) return not MOD.showAnchors end,
							get = function(info) return pp.groups[HEADER_PLAYER_BUFFS].anchorX * 100 end,
							set = function(info, value) pp.groups[HEADER_PLAYER_BUFFS].anchorX = value / 100; UpdateAll() end,
						},
						BuffsVertical = {
							type = "range", order = 120, name = "Buffs Offset Y", min = 0, max = 100, step = 0.01,
							desc = "Set buffs vertical position as percentage of display height.",
							disabled = function(info) return not MOD.showAnchors end,
							get = function(info) return pp.groups[HEADER_PLAYER_BUFFS].anchorY * 100 end,
							set = function(info, value) pp.groups[HEADER_PLAYER_BUFFS].anchorY = value / 100; UpdateAll() end,
						},
						DebuffsHorizontal = {
							type = "range", order = 130, name = "Debuffs Offset X", min = 0, max = 100, step = 0.01,
							desc = "Set debuffs horizontal position as percentage of display width.",
							disabled = function(info) return not MOD.showAnchors end,
							get = function(info) return pp.groups[HEADER_PLAYER_DEBUFFS].anchorX * 100 end,
							set = function(info, value) pp.groups[HEADER_PLAYER_DEBUFFS].anchorX = value / 100; UpdateAll() end,
						},
						DebuffsVertical = {
							type = "range", order = 140, name = "Debuffs Offset Y", min = 0, max = 100, step = 0.01,
							desc = "Set debuffs vertical position as percentage of display height.",
							disabled = function(info) return not MOD.showAnchors end,
							get = function(info) return pp.groups[HEADER_PLAYER_DEBUFFS].anchorY * 100 end,
							set = function(info, value) pp.groups[HEADER_PLAYER_DEBUFFS].anchorY = value / 100; UpdateAll() end,
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
							type = "range", order = 20, name = "Horizontal Spacing", min = 0, max = 500, step = 1,
							desc = "Adjust horizontal spacing between icons.",
							get = function(info) return pp.spaceX end,
							set = function(info, value) pp.spaceX = value; UpdateAll() end,
						},
						SpacingY = {
							type = "range", order = 30, name = "Vertical Spacing", min = 0, max = 500, step = 1,
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
							get = function(info) return pp.orientation == 1 end,
							set = function(info, value) pp.orientation = (value and 1 or 0); UpdateAll() end,
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
							desc = "Limit the number of rows or columns. " ..
							"There can be no more than 40 total icons.",
							get = function(info) return pp.maxWraps end,
							set = function(info, value) pp.maxWraps = value; UpdateAll() end,
						},
						MirrorX = {
							type = "toggle", order = 130, name = "Mirror X", width = "half",
							desc = "If checked, horizontal direction for debuffs is opposite of buffs.",
							get = function(info) return pp.mirrorX end,
							set = function(info, value) pp.mirrorX = value; UpdateAll() end,
						},
						MirrorY = {
							type = "toggle", order = 140, name = "Mirror Y", width = "half",
							desc = "If checked, vertical direction for debuffs is opposite of buffs.",
							get = function(info) return pp.mirrorY end,
							set = function(info, value) pp.mirrorY = value; UpdateAll() end,
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
						NoBorder = {
							type = "toggle", order = 10, name = "None", width = "half",
							desc = "Don't show an icon border.",
							get = function(info) return pp.iconBorder == "none" or ((pp.iconBorder == "masque") and not MOD.MSQ) end,
							set = function(info, value) pp.iconBorder = "none"; UpdateAll() end,
						},
						DefaultBorder = {
							type = "toggle", order = 20, name = "Default", width = "half",
							desc = "Show Blizzard's default icon borders. " ..
							"Default borders do not support customized border colors but, " ..
							"when Debuff Type Override is enabled, glow effects with debuff type colors are shown when appropriate.",
							get = function(info) return pp.iconBorder == "default" end,
							set = function(info, value) pp.iconBorder = "default"; UpdateAll() end,
						},
						MasqueBorder = {
							type = "toggle", order = 30, name = "Masque", width = "half",
							desc = "Use the Masque addon to show icon borders. " ..
							"Masque borders support custom buff and debuff border colors but some masque skins may not look good. " ..
							"You can suppress the custom border colors by making them transparent. " ..
							"When Debuff Type Override is enabled, debuff type colors will still be shown when appropriate.",
							hidden = function(info) return not MOD.MSQ end, -- only show if Masque is loaded
							get = function(info) return pp.iconBorder == "masque" end,
							set = function(info, value) pp.iconBorder = "masque"; UpdateAll() end,
						},
						RavenBorder = {
							type = "toggle", order = 40, name = "Raven", width = "half",
							desc = "Use the custom icon border included in Raven.",
							get = function(info) return pp.iconBorder == "raven" end,
							set = function(info, value) pp.iconBorder = "raven"; UpdateAll() end,
						},
						OnePixelBorder = {
							type = "toggle", order = 50, name = "Pixel", width = "half",
							desc = "Use single pixel icon borders.",
							get = function(info) return pp.iconBorder == "one" end,
							set = function(info, value) pp.iconBorder = "one"; UpdateAll() end,
						},
						TwoPixelBorder = {
							type = "toggle", order = 60, name = "Two Pixel",
							desc = "Use two pixel icon borders.",
							get = function(info) return pp.iconBorder == "two" end,
							set = function(info, value) pp.iconBorder = "two"; UpdateAll() end,
						},
						Spacer = { type = "description", name = "", order = 100 },
						BuffBorderColor = {
							type = "color", order = 110, name = "Buff Borders", hasAlpha = true,
							desc = "Set color for icon borders.",
							disabled = function(info) return pp.iconBorder == "default" end,
							get = function(info)
								local t = pp.iconBuffColor
								return t.r, t.g, t.b, t.a
							end,
							set = function(info, r, g, b, a)
								local t = pp.iconBuffColor
								t.r = r; t.g = g; t.b = b; t.a = a
								UpdateAll()
							end,
						},
						DebuffBorderColor = {
							type = "color", order = 120, name = "Debuff Borders", hasAlpha = true,
							desc = "Set color for icon borders.",
							disabled = function(info) return pp.iconBorder == "default" end,
							get = function(info)
								local t = pp.iconDebuffColor
								return t.r, t.g, t.b, t.a
							end,
							set = function(info, r, g, b, a)
								local t = pp.iconDebuffColor
								t.r = r; t.g = g; t.b = b; t.a = a
								UpdateAll()
							end,
						},
						DebuffTypeColor = {
							type = "toggle", order = 130, name = "Debuff Type Override",
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
		TextsGroup = {
			type = "group", order = 40, name = "Texts",
			args = {
				CountTextGroup = {
					type = "group", order = 10, name = "Stack Count",
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
								Space1 = { type = "description", name = "", order = 100 },
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
								Space2 = { type = "description", name = "", order = 200 },
								Horizontal = {
									type = "range", order = 210, name = "Offset X", min = -100, max = 100, step = 1,
									desc = "Set horizontal offset from the anchor.",
									get = function(info) return pp.countPosition.offsetX end,
									set = function(info, value) pp.countPosition.offsetX = value; UpdateAll() end,
								},
								Vertical = {
									type = "range", order = 220, name = "Offset Y", min = -100, max = 100, step = 1,
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
					type = "group", order = 20, name = "Label",
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
								Space1 = { type = "description", name = "", order = 100 },
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
								Space2 = { type = "description", name = "", order = 200 },
								Horizontal = {
									type = "range", order = 210, name = "Offset X", min = -100, max = 100, step = 1,
									desc = "Set horizontal offset from the anchor.",
									get = function(info) return pp.labelPosition.offsetX end,
									set = function(info, value) pp.labelPosition.offsetX = value; UpdateAll() end,
								},
								Vertical = {
									type = "range", order = 220, name = "Offset Y", min = -100, max = 100, step = 1,
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
					type = "group", order = 30, name = "Time Left",
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
								Space1 = { type = "description", name = "", order = 100 },
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
								Space2 = { type = "description", name = "", order = 200 },
								Horizontal = {
									type = "range", order = 210, name = "Offset X", min = -100, max = 100, step = 1,
									desc = "Set horizontal offset from the anchor.",
									get = function(info) return pp.timePosition.offsetX end,
									set = function(info, value) pp.timePosition.offsetX = value; UpdateAll() end,
								},
								Vertical = {
									type = "range", order = 220, name = "Offset Y", min = -100, max = 100, step = 1,
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
								ExpireColor = {
									type = "color", order = 40, name = "Expiring Color", hasAlpha = true,
									get = function(info)
										local t = pp.expireColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.expireColor
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
			},
		},
		TimerBarGroup = {
			type = "group", order =50, name = "Bars",
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
						BarsGroup = {
							type = "group", order = 10, name = "Bars", inline = true,
							args = {
								BarTexture = {
									type = "select", order = 10, name = "Bar Texture",
									desc = "Select shared media texture for bars.",
									dialogControl = 'LSM30_Statusbar',
									values = AceGUIWidgetLSMlists.statusbar,
									get = function(info) return pp.barTexture end,
									set = function(info, value) pp.barTexture = value; UpdateAll() end,
								},
								ForegroundOpacity = {
									type = "range", order = 20, name = "Foreground Opacity", min = 0, max = 1, step = 0.05,
									desc = "Set foreground opacity for bars.",
									get = function(info) return pp.barForegroundOpacity end,
									set = function(info, value) pp.barForegroundOpacity = value; UpdateAll() end,
								},
								BackgroundOpacity = {
									type = "range", order = 30, name = "Background Opacity", min = 0, max = 1, step = 0.05,
									desc = "Set background opacity for bars.",
									get = function(info) return pp.barBackgroundOpacity end,
									set = function(info, value) pp.barBackgroundOpacity = value; UpdateAll() end,
								},
								Spacer1 = { type = "description", name = "", order = 100 },
								BuffColor = {
									type = "color", order = 110, name = "Buffs", hasAlpha = false,
									desc = "Set color for buff bars.",
									get = function(info)
										local t = pp.barBuffColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a) local t = pp.barBuffColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								DebuffColor = {
									type = "color", order = 120, name = "Debuffs", hasAlpha = false,
									desc = "Set color for debuff bars.",
									get = function(info)
										local t = pp.barDebuffColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.barDebuffColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								DebuffTypeColor = {
									type = "toggle", order = 130, name = "Debuff Type Override",
									desc = "Use debuff type colors for bars when appropriate.",
									get = function(info) return pp.barDebuffColoring end,
									set = function(info, value) pp.barDebuffColoring = value; UpdateAll() end,
								},
								Spacer2 = { type = "description", name = "", order = 200 },
								BackgroundColor = {
									type = "color", order = 210, name = "Background Color", hasAlpha = false,
									desc = "Set the background color for bars.",
									disabled = function(info) return pp.barUseForeground end,
									get = function(info)
										local t = pp.barBackgroundColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a) local t = pp.barBackgroundColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								BackgroundUseForegroundColor = {
									type = "toggle", order = 230, name = "Use Foreground Color",
									desc = "Use bar foreground color for its background.",
									get = function(info) return pp.barUseForeground end,
									set = function(info, value) pp.barUseForeground = value; UpdateAll() end,
								},
							},
						},
						BordersGroup = {
							type = "group", order = 20, name = "Borders", inline = true,
							args = {
								NoBorder = {
									type = "toggle", order = 10, name = "None", width = "half",
									desc = "Do not display bar borders.",
									get = function(info) return pp.barBorder == "none" end,
									set = function(info, value) pp.barBorder = "none"; UpdateAll() end,
								},
								MediaBorder = {
									type = "toggle", order = 20, name = "Media", width = "half",
									desc = "Use a shared media bar border.",
									get = function(info) return pp.barBorder == "media" end,
									set = function(info, value) pp.barBorder = "media"; UpdateAll() end,
								},
								OnePixelBorder = {
									type = "toggle", order = 30, name = "Pixel", width = "half",
									desc = "Use single pixel bar borders (requires bar width and height greater than 4).",
									get = function(info) return pp.barBorder == "one" end,
									set = function(info, value) pp.barBorder = "one"; UpdateAll() end,
								},
								TwoPixelBorder = {
									type = "toggle", order = 40, name = "Two Pixel",
									desc = "Use two pixel bar borders (requires bar width and height greater than 4).",
									get = function(info) return pp.barBorder == "two" end,
									set = function(info, value) pp.barBorder = "two"; UpdateAll() end,
								},
								Spacer1 = { type = "description", name = "", order = 100 },
								BorderTexture = {
									type = "select", order = 110, name = "Bar Border",
									desc = "Select shared media border for bars.",
									dialogControl = 'LSM30_Border',
									disabled = function(info) return pp.barBorder ~= "media" end,
									values = AceGUIWidgetLSMlists.border,
									get = function(info) return pp.barBorderMedia end,
									set = function(info, value) pp.barBorderMedia = value; UpdateAll() end,
								},
								BorderWidth = {
									type = "range", order = 120, name = "Edge Size", min = 0, max = 32, step = 0.01,
									desc = "Adjust width of the border's edge (best size depends on the selected border).",
									disabled = function(info) return pp.barBorder ~= "media" end,
									get = function(info) return pp.barBorderWidth end,
									set = function(info, value) pp.barBorderWidth = value; UpdateAll() end,
								},
								BorderOffset = {
									type = "range", order = 130, name = "Offset", min = -16, max = 16, step = 0.01,
									desc = "Adjust offset to the border from the bar (best offset depends on the selected border).",
									disabled = function(info) return pp.barBorder ~= "media" end,
									get = function(info) return pp.barBorderOffset end,
									set = function(info, value) pp.barBorderOffset = value; UpdateAll() end,
								},
								Spacer2 = { type = "description", name = "", order = 200 },
								BorderBuffColor = {
									type = "color", order = 210, name = "Buff Border Color", hasAlpha = true,
									desc = "Set color for the bar border.",
									get = function(info)
										local t = pp.barBorderBuffColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.barBorderBuffColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								BorderDebuffColor = {
									type = "color", order = 220, name = "Debuff Border Color", hasAlpha = true,
									desc = "Set color for the bar border.",
									get = function(info)
										local t = pp.barBorderDebuffColor
										return t.r, t.g, t.b, t.a
									end,
									set = function(info, r, g, b, a)
										local t = pp.barBorderDebuffColor
										t.r = r; t.g = g; t.b = b; t.a = a
										UpdateAll()
									end,
								},
								DebuffTypeColor = {
									type = "toggle", order = 230, name = "Debuff Type Override",
									desc = "Use debuff type colors for bar borders when appropriate.",
									get = function(info) return pp.barDebuffColoring end,
									set = function(info, value) pp.barDebuffColoring = value; UpdateAll() end,
								},
							},
						},
						UnlimitedGroup = {
							type = "group", order = 30, name = "Unlimited Duration", inline = true,
							args = {
								NoUnlimited = {
									type = "toggle", order = 10, name = "No Bar",
									desc = "Do not display a bar when duration is unlimited.",
									get = function(info) return pp.barUnlimited == "none" end,
									set = function(info, value) pp.barUnlimited = "none"; UpdateAll() end,
								},
								EmptyUnlimited = {
									type = "toggle", order = 20, name = "Empty Bar",
									desc = "Display an empty bar when duration is unlimited.",
									get = function(info) return pp.barUnlimited == "empty" end,
									set = function(info, value) pp.barUnlimited = "empty"; UpdateAll() end,
								},
								FullUnlimited = {
									type = "toggle", order = 30, name = "Full Bar",
									desc = "Display a full bar when duration is unlimited.",
									get = function(info) return pp.barUnlimited == "full" end,
									set = function(info, value) pp.barUnlimited = "full"; UpdateAll() end,
								},
							},
						},
					},
				},
			},
		},
	},
}
