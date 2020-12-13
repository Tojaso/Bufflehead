-- Bufflehead is an addon to skin player buffs, including weapon enchants, and debuffs.
--
-- Features:
-- 1. Hide/show Blizzard buff frame (buffs, debuffs, weapon enchants)
-- 2. Options panel to configure display of player buffs and debuffs
-- 3. Option to use Masque to skin borders (note: no ElvUI option since doesn't make sense to use with ElvUI or Tukui)
-- 4. Options for direction, wrap, size, etc. as provided by SecureAuraHeaderTemplate
-- 5. Event-driven handler to make changes only when player buffs and debuffs change
--
-- Author: Tomber/Tojaso (curseforge, github, wowinterface)
-- Copyright 2020, All Rights Reserved

Bufflehead = LibStub("AceAddon-3.0"):NewAddon("Bufflehead", "AceConsole-3.0", "AceEvent-3.0")
local MOD = Bufflehead
local MOD_Options = "Bufflehead_Options"
local _

MOD.isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
MOD.frame = nil
MOD.headers = {}
MOD.previews = {}
MOD.db = nil
MOD.LibLDB = nil -- LibDataBroker support
MOD.ldb = nil -- set to addon's data broker object
MOD.ldbi = nil -- set for addon's minimap icon
MOD.uiOpen = false -- true when options panel is open
MOD.showAnchors = false -- toggle to show anchors

local FILTER_BUFFS = "HELPFUL"
local FILTER_DEBUFFS = "HARMFUL"
local BUFFS_TEMPLATE = "BuffleheadAuraTemplate"
local HEADER_NAME = "BuffleheadSecureHeader"
local HEADER_PLAYER_BUFFS = HEADER_NAME .. "PlayerBuffs"
local HEADER_PLAYER_DEBUFFS = HEADER_NAME .. "PlayerDebuffs"
local BUFFLE_ICON = "Interface\\AddOns\\Bufflehead\\Media\\BuffleheadIcon"
local PRESET_BUFF_ICON = "Interface\\Icons\\inv_bijou_green"
local PRESET_DEBUFF_ICON = "Interface\\Icons\\inv_bijou_red"
local HEADER_FRAME_LEVEL = 100
local DEFAULT_ICON_BORDER = "Interface\\Buttons\\UI-ActionButton-Border"
local RAVEN_ICON_BORDER = "Interface\\AddOns\\Bufflehead\\Media\\IconDefault"

local onePixelBackdrop = { -- backdrop initialization for icons when using optional one and two pixel borders
	bgFile = "Interface\\AddOns\\Bufflehead\\Media\\WhiteBar",
	edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp", edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local twoPixelBackdrop = { -- backdrop initialization for icons when using optional one and two pixel borders
	bgFile = "Interface\\AddOns\\Bufflehead\\Media\\WhiteBar",
	edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp", edgeSize = 2, insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local justifyH = { BOTTOM = "CENTER", BOTTOMLEFT = "LEFT", BOTTOMRIGHT = "RIGHT", CENTER = "CENTER", LEFT = "LEFT",
	RIGHT = "RIGHT", TOP = "CENTER", TOPLEFT = "LEFT", TOPRIGHT = "RIGHT" }

local justifyV = { BOTTOM = "BOTTOM", BOTTOMLEFT = "BOTTOM", BOTTOMRIGHT = "BOTTOM", CENTER = "MIDDLE", LEFT = "MIDDLE",
	RIGHT = "MIDDLE", TOP = "TOP", TOPLEFT = "TOP", TOPRIGHT = "TOP" }

local debuffTypes = { "none", "Disease", "Poison", "Curse", "Magic" }

local addonInitialized = false -- set when the addon is initialized
local addonEnabled = false -- set when the addon is enabled
local blizzHidden = false -- set when blizzard buffs and debuffs are hidden
local updateAll = false -- set in combat to defer running event handler
local MSQ_Group = nil -- create a single group for masque
local MSQ_ButtonData = nil -- template for masque button data structure
local weaponDurations = {} -- best guess for weapon buff durations, indexed by enchant id
local buffTooltip = {} -- temporary table for getting weapon enchant names
local previewMode = false -- toggle for preview mode extra icons
local pg, pp -- global and character-specific profiles

local UnitAura = UnitAura
local GetTime = GetTime
local GetScreenHeight = GetScreenHeight
local GetPhysicalScreenSize = GetPhysicalScreenSize
local CreateFrame = CreateFrame
local RegisterAttributeDriver = RegisterAttributeDriver
local RegisterStateDriver = RegisterStateDriver
local InCombatLockdown = InCombatLockdown
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture

-- Functions used for pixel pefect calculations
local pixelScale = 1 -- scale factor used for size and alignment
local screenWidth, screenHeight -- physical size of screen in pixels
local displayWidth, displayHeight, displayScale -- virtual size and scale of UIParent

local function PS(x) if type(x) == "number" then return pixelScale * math.floor(x / pixelScale + 0.5) else return x end end
local function PSetWidth(region, w) if w then w = pixelScale * math.floor(w / pixelScale + 0.5) end region:SetWidth(w) end
local function PSetHeight(region, h) if h then h = pixelScale * math.floor(h / pixelScale + 0.5) end region:SetHeight(h) end

local function PSetSize(frame, w, h)
	if w then w = pixelScale * math.floor(w / pixelScale + 0.5) end
	if h then h = pixelScale * math.floor(h / pixelScale + 0.5) end
	frame:SetSize(w, h)
end

local function PSetPoint(frame, point, relativeFrame, relativePoint, x, y)
	if x then x = pixelScale * math.floor(x / pixelScale + 0.5) end
	if y then y = pixelScale * math.floor(y / pixelScale + 0.5) end
	frame:SetPoint(point, relativeFrame, relativePoint, x or 0, y or 0)
end

-- Print debug messages with variable number of arguments in a useful format
function MOD.Debug(a, ...)
	if type(a) == "table" then
		for k, v in pairs(a) do print(tostring(k) .. " = " .. tostring(v)) end -- if first parameter is a table, print out its fields
	else
		local s = tostring(a) -- otherwise first argument is a string but just make sure
		local parm = {...}
		for i = 1, #parm do s = s .. " " .. tostring(parm[i]) end -- append remaining arguments converted to strings
		print(s)
	end
end

-- Check if the options panel is loaded, if not then get it loaded and ask it to toggle open/close status
function MOD.OptionsPanel()
  if not optionsLoaded and not optionsFailed then
    optionsLoaded = true
    local loaded, reason = LoadAddOn(MOD_Options) -- try to load the options panel on demand
    if not loaded then
        print("Bufflehead: failed to load " .. tostring(MOD_Options) .. ": " .. tostring(reason))
				optionsFailed = true
    end
	end
	if not optionsFailed then MOD:ToggleOptions() end
end

-- Initialize tooltip to be used for determining weapon buffs
-- This code is based on the Pitbull implementation
local function InitializeBuffTooltip()
	buffTooltip = CreateFrame("GameTooltip", nil, UIParent)
	buffTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	local fs = buffTooltip:CreateFontString()
	fs:SetFontObject(_G.GameFontNormal)
	buffTooltip.tooltipLines = {} -- cache of font strings for each line in the tooltip
	for i = 1, 30 do
		local ls = buffTooltip:CreateFontString()
		ls:SetFontObject(_G.GameFontNormal)
		buffTooltip:AddFontStrings(ls, fs)
		buffTooltip.tooltipLines[i] = ls
	end
end

-- Return the temporary table for storing buff tooltips
local function GetBuffTooltip()
	buffTooltip:ClearLines()
	if not buffTooltip:IsOwned(UIParent) then buffTooltip:SetOwner(UIParent, "ANCHOR_NONE") end
	return buffTooltip
end

-- No easy way to get this info, so scan item slot info for mainhand and offhand weapons using a tooltip
-- Weapon buffs are usually formatted in tooltips as name strings followed by remaining time in parentheses
-- This routine scans the tooltip for the first line that is in this format and extracts the weapon buff name without rank or time
local function GetWeaponBuffName(weaponSlot)
	local tt = GetBuffTooltip()
	tt:SetInventoryItem("player", weaponSlot)
	for i = 1, 30 do
		local text = tt.tooltipLines[i]:GetText()
		if text then
			local name = text:match("^(.+) %(%d+ [^$)]+%)$") -- extract up to left paren if match weapon buff format
			if name then
				name = (name:match("^(.*) %d+$")) or name -- remove any trailing numbers
				return name
			end
		else
			break
		end
	end

	local id = GetInventoryItemID("player", weaponSlot) -- fall back to returning weapon name
	if id then
		local name = C_Item.GetItemNameByID(id)
		if name then return name end -- fall back to returning name of the weapon
	end
	return "Unknown Enchant [" .. weaponSlot .. "]"
end

-- Event called when addon is loaded, good time to load libraries
function MOD:OnInitialize()
	if addonInitialized then return end -- only run this code once
	addonInitialized = true
	MOD.frame = CreateFrame("Frame")-- create a frame to catch events
	LoadAddOn("LibDataBroker-1.1")
	LoadAddOn("LibDBIcon-1.0")
end

-- Adjust a backdrop's insets for pixel perfect factor
local function SetInsets(backdrop, x)
	local t = backdrop.insets
	t.left = x; t.right = x; t.top = x; t.bottom = x
end

-- Calculate pixel perfect scale factor
local function SetPixelScale()
	screenWidth, screenHeight = GetPhysicalScreenSize() -- size in pixels of display in full screen, otherwise window size in pixels
	displayWidth = UIParent:GetWidth() -- saved for calculating anchor position
	displayHeight = UIParent:GetHeight()
	displayScale = UIParent:GetScale() -- adjusted by ElvUI and possibly others
	pixelScale = GetScreenHeight() / screenHeight -- figure out how big virtual pixels are versus screen pixels
	onePixelBackdrop.edgeSize = PS(1) -- update one pixel border backdrop
	SetInsets(onePixelBackdrop, PS(1))
	twoPixelBackdrop.edgeSize = PS(2) -- update two pixel border backdrop
	SetInsets(twoPixelBackdrop, PS(2))

	-- MOD.Debug("Bufflehead: pixel w/h/scale", screenWidth, screenHeight, pixelScale, displayWidth, displayHeight, displayScale)
	-- MOD.Debug("Bufflehead: UIParent scale/effective", UIParent:GetScale(), UIParent:GetEffectiveScale())
end

-- Adjust pixel perfect scale factor when the UIScale is changed
local function UIScaleChanged()
	if not enteredWorld then return end
	if InCombatLockdown() then
		updateAll = true
	else
		SetPixelScale()
		MOD.UpdateAll() -- redraw everything
	end
end

-- Completely redraw everything that can be redrawn without /reload
-- Only execute this when not in combat, defer to when leave combat if necessary
function MOD.UpdateAll()
	if not enteredWorld then return end
	if InCombatLockdown() then
		updateAll = true
	else
		updateAll = false
		for k, header in pairs(MOD.headers) do MOD.UpdateHeader(header) end
	end
end

-- Event called when addon is enabled, good time to register events and chat commands
function MOD:OnEnable()
	if addonEnabled then return end -- only run this code once
	addonEnabled = true

	MOD.db = LibStub("AceDB-3.0"):New("BuffleheadDB", MOD.DefaultProfile) -- get current profile
	pg = MOD.db.global; pp = MOD.db.profile

	MOD:RegisterChatCommand("bufflehead", function() MOD.OptionsPanel() end)
	MOD:RegisterChatCommand("buffle", function() MOD.OptionsPanel() end)
	MOD.InitializeLDB() -- initialize the data broker and minimap icon
	MOD.LSM = LibStub("LibSharedMedia-3.0")
	MOD.MSQ = LibStub("Masque", true)
	if MOD.MSQ then MSQ_Group = MOD.MSQ:Group("Bufflehead", "Buffs and Debuffs") end

	MSQ_ButtonData = { AutoCast = false, AutoCastable = false, Border = false, Checked = false, Cooldown = false, Count = false, Duration = false,
		Disabled = false, Flash = false, Highlight = false, HotKey = false, Icon = false, Name = false, Normal = false, Pushed = false }

	InitializeBuffTooltip()

	self:RegisterEvent("UI_SCALE_CHANGED", UIScaleChanged)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Event called when play starts, initialize subsystems that had to wait for system bootstrap
function MOD:PLAYER_ENTERING_WORLD()
	if enteredWorld then return end -- only run this code once
	enteredWorld = true
	SetPixelScale() -- initialize scale factor for pixel perfect size and alignment

	if pg.enabled then -- make sure addon is enabled
		MOD.CheckBlizzFrames() -- check blizz frames and hide the ones selected on the Defaults tab
		for name, group in pairs(pp.groups) do
			if group.enabled then -- create header for enabled group, must do /reload if change header-related options
				local unit, filter = group.unit, group.filter
				local header = CreateFrame("Frame", name, UIParent, "SecureAuraHeaderTemplate")
				header:SetFrameLevel(HEADER_FRAME_LEVEL)
				-- header:SetClampedToScreen(true)
				header:SetAttribute("unit", unit)
				header:SetAttribute("filter", filter)
				RegisterAttributeDriver(header, "state-visibility", "[petbattle] hide; show")
				MOD.headers[name] = header

				if (unit == "player") then
					RegisterAttributeDriver(header, "unit", "[vehicleui] vehicle; player")
					if filter == FILTER_BUFFS then
						header:SetAttribute("consolidateDuration", -1) -- no consolidation
						header:SetAttribute("includeWeapons", pp.weaponEnchants and 1 or 0)
					end
				end

				local backdrop = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
				backdrop.caption = backdrop:CreateFontString(nil, "OVERLAY")
				backdrop.caption:SetFontObject(ChatFontNormal)
				PSetPoint(backdrop.caption,"CENTER", backdrop, "BOTTOM")
				backdrop.caption:SetText(group.caption)
				backdrop:SetFrameStrata("LOW") -- show it behind Bufflehead's buttons
				backdrop:SetMovable(true)
				backdrop.headerName = name
				header.anchorBackdrop = backdrop
				MOD.UpdateHeader(header)
			end
		end
	end
end

-- Event called when leaving combat
function MOD:PLAYER_REGEN_ENABLED(e)
	if updateAll then MOD.UpdateAll() end
end

-- Create a data broker and minimap icon for the addon
function MOD.InitializeLDB()
	MOD.LibLDB = LibStub("LibDataBroker-1.1", true)
	if not MOD.LibLDB then return end
	MOD.ldb = MOD.LibLDB:NewDataObject("Bufflehead", {
		type = "launcher",
		text = "Bufflehead",
		icon = BUFFLE_ICON,
		OnClick = function(_, msg)
			if IsShiftKeyDown() or IsAltKeyDown() then return end
			if msg == "LeftButton" then
				MOD.OptionsPanel()
			elseif msg == "RightButton" then
				MOD.TogglePreviews()
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end
			tooltip:AddLine("Bufflehead")
			tooltip:AddLine("|cffffff00Left-click|r to open/close options menu")
			tooltip:AddLine("|cffffff00Right-click|r to toggle showing previews")
		end,
	})

	MOD.ldbi = LibStub("LibDBIcon-1.0", true)
	if MOD.ldbi then MOD.ldbi:Register("Bufflehead", MOD.ldb, pg.Minimap) end
end

-- Show or hide the blizzard buff frames, called during update so synched with other changes
function MOD.CheckBlizzFrames()
	if not MOD.isClassic and C_PetBattles.IsInBattle() then return end -- don't change visibility of any frame during pet battles
	local frame = _G.BuffFrame
	local hide, show = false, false
	local visible = frame:IsShown()
	if visible then
		if pg.hideBlizz then hide = true end
	else
		if pg.hideBlizz then show = false else show = blizzHidden end -- only show if this addon hid the frame
	end
	-- MOD.Debug("Bufflehead: hide/show", key, "hide:", hide, "show:", show, "vis: ", visible)
	if hide then
		BuffFrame:Hide()
		TemporaryEnchantFrame:Hide()
		BuffFrame:UnregisterAllEvents()
		blizzHidden = true
	elseif show then
		BuffFrame:Show()
		TemporaryEnchantFrame:Show()
		BuffFrame:RegisterEvent("UNIT_AURA")
		blizzHidden = false
	end
end

-- Toggle visibility of the anchors
function MOD.ToggleAnchors()
	MOD.showAnchors = not MOD.showAnchors
	MOD.UpdateAll()
end

-- Get weapon enchant duration, since this is not supplied by blizzard look at current detected duration
-- and compare it to longest previous duration for the given weapon buff in order to find maximum detected
local function WeaponDuration(buff, duration)
	local maxd = weaponDurations[buff]
	if not maxd or (duration > maxd) then
		weaponDurations[buff] = math.floor(duration + 0.5) -- round up
	else
		if maxd > duration then duration = maxd end
	end
	return duration
end

-- Function called when a new aura button is created
function MOD:Button_OnLoad(button)
	local level = button:GetFrameLevel()

	button.iconTexture = button:CreateTexture(nil, "ARTWORK")
	button.iconBorder = button:CreateTexture(nil, "OVERLAY", nil, -3)
	button.iconBackdrop = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate")
	button.iconBackdrop:SetFrameLevel(level - 1) -- behind icon
	button.iconHighlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.iconHighlight:SetColorTexture(1, 1, 1, 0.5)
	button.clock = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	local bc = button.clock
	bc.noCooldownCount = pg.hideOmniCC -- enable or disable OmniCC text
	bc:SetHideCountdownNumbers(true)
	bc:SetFrameLevel(level + 2) -- in front of icon but behind bar
	bc:SetSwipeTexture(0)
	bc:SetDrawBling(false)
	bc:ClearAllPoints()
	bc:SetPoint("CENTER", button, "CENTER") -- always centered on the button
	button.texts = CreateFrame("Frame", nil, button) -- all texts are in this frame
	button.texts:SetFrameLevel(level + 6) -- texts are on top of everything else
	button.timeText = button.texts:CreateFontString(nil, "OVERLAY")
	button.timeText:SetFontObject(ChatFontNormal)
	button.countText = button.texts:CreateFontString(nil, "OVERLAY")
	button.labelText = button.texts:CreateFontString(nil, "OVERLAY")
	button.bar = CreateFrame("StatusBar", nil, button, BackdropTemplateMixin and "BackdropTemplate")
	button.bar:SetFrameLevel(level + 4) -- in front of icon
	button.barBackdrop = CreateFrame("Frame", nil, button.bar, BackdropTemplateMixin and "BackdropTemplate")
	button.barBackdrop:SetFrameLevel(level + 3) -- behind bar but in front of icon

	if MOD.MSQ then -- if MSQ is loaded then initialize its required data table
		button.buttonData = {}
		for k, v in pairs(MSQ_ButtonData) do button.buttonData[k] = v end
	end

	button:SetScript("OnAttributeChanged", MOD.Button_OnAttributeChanged)
end

-- Trim and scale icon
local function IconTextureTrim(tex, icon, trim, iconSize)
	local left, right, top, bottom = 0, 1, 0, 1 -- default without trim
	if trim then left = 0.07; right = 0.93; top = 0.07; bottom = 0.93 end -- trim removes 7% of edges
	tex:SetTexCoord(left, right, top, bottom) -- set the corner coordinates
	PSetSize(tex, iconSize, iconSize)
end

-- Skin the icon's border
local function SkinBorder(button, c)
	local bib = button.iconBorder
	local bik = button.iconBackdrop
	local bih = button.iconHighlight
	local tex = button.iconTexture
	local masqueLoaded = MOD.MSQ and MSQ_Group and button.buttonData
	local opt = pp.iconBorder -- option for type of border
	bib:ClearAllPoints()
	bik:ClearAllPoints()
	if masqueLoaded then MSQ_Group:RemoveButton(button, true) end
	if not c then c = { r = 0.5, g = 0.5, b = 0.5, a = 1 } end

	if opt == "raven" then -- skin with raven's border
		IconTextureTrim(tex, button, true, pp.iconSize * 0.91)
		bib:SetAllPoints(button)
		bib:SetTexture(GetFileIDFromPath(RAVEN_ICON_BORDER))
		bib:SetVertexColor(c.r, c.g, c.b, c.a or 1)
		bib:SetBlendMode("ADD")
		bib:Show()
		bih:Hide()
		bik:Hide()
	elseif (opt == "one") or (opt == "two") then -- skin with single or double pixel border
		IconTextureTrim(tex, button, true, pp.iconSize - ((opt == "one") and PS(2) or PS(4)))
		bik:SetAllPoints(button)
		bik:SetBackdrop((opt == "one") and onePixelBackdrop or twoPixelBackdrop)
		bik:SetBackdropColor(0, 0, 0, 0)
		bik:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
		bik:Show()
		bih:Hide()
		bib:Hide()
	elseif (opt == "masque") and masqueLoaded then -- use Masque only if available
		IconTextureTrim(tex, button, false, pp.iconSize)
		bib:SetAllPoints(button)
		bib:SetVertexColor(c.r, c.g, c.b, c.a or 1)
		bib:SetBlendMode("ADD")
		bib:Show()
		bih:Show()
		local bdata = button.buttonData
		bdata.Icon = tex
		bdata.Normal = button:GetNormalTexture()
		bdata.Cooldown = button.clock
		bdata.Border = bib
		bdata.Highlight = button.iconHighlight
		MSQ_Group:AddButton(button, bdata)
		bik:Hide()
	elseif opt == "default" then -- show blizzard's standard border
		IconTextureTrim(tex, button, false, pp.iconSize)
		bib:SetTexture(GetFileIDFromPath(DEFAULT_ICON_BORDER))
		bib:SetVertexColor(c.r, c.g, c.b, c.a or 1)
		bib:SetBlendMode("ADD")
		PSetSize(bib, pp.iconSize * 1.7, pp.iconSize * 1.7)
		PSetPoint(bib, "CENTER", button, "CENTER")
		bib:Show()
		bih:Hide()
		bik:Hide()
	else -- no border (remove standard border)
		IconTextureTrim(tex, button, true, pp.iconSize)
		bib:Hide()
		bih:Hide()
		bik:Hide()
	end
end

-- Skin the icon's clock overlay, must be done after skinning the border
local function SkinClock(button, duration, expire)
	local bc = button.clock

	if pp.showClock and duration and duration > 0 and expire and expire > 0 then
		-- bc:ClearAllPoints()
		local w, h = button.iconTexture:GetSize()
		bc:SetDrawEdge(pp.clockEdge)
		bc:SetReverse(pp.clockReverse)
		local c = pp.clockColor
		-- bc:SetSwipeTexture(0)
		bc:SetSwipeColor(c.r, c.g, c.b, c.a or 1)
		bc:SetSize(w, h) -- icon texture was already sized and scaled
		-- bc:SetPoint("CENTER", button, "CENTER")
		bc:SetCooldown(expire - duration, duration)
		bc:Show()
	else
		bc:SetCooldown(0, 0)
		bc:Hide()
	end
end

-- Validate that have a valid font reference
local function ValidFont(name) return (name and (type(name) == "string") and (name ~= "")) end

-- Return font flags based on text settings
local function GetFontFlags(flags)
	local ff = ""
	if flags.outline then ff = "OUTLINE" end
	if flags.thick then if ff == "" then ff = "THICKOUTLINE" else ff = ff .. ", THICKOUTLINE" end end
	if flags.mono then if ff == "" then ff = "MONOCHROME" else ff = ff .. ", MONOCHROME" end end
	return ff
end

-- Clear the time text
local function StopButtonTime(button)
	button:SetScript("OnUpdate", nil) -- stop updating the time text
	button._expire = nil
	button._update = nil
	button.timeText:SetText(" ")
	button.timeText:Hide()
end

-- Update the time text for a button, triggered OnUpdate so keep it quick
local function UpdateButtonTime(button)
	if button and button._expire then -- make sure valid call
		local now = GetTime()
		local remaining = button._expire - now
		local c = pp.timeColor
		if remaining < 5 then c = pp.expireColor end -- set either regular or expiring color
		button.timeText:SetTextColor(c.r, c.g, c.b, c.a)
		if remaining > 0.05 then
			if (button._update == 0) or ((now - button._update) > 0.05) then -- about 20/second
				button._update = now
				button.timeText:SetText(MOD.FormatTime(remaining, pp.timeFormat, pp.timeSpaces, pp.timeCase))
			end
		else
			StopButtonTime(button)
		end
	end
end

-- Configure the button's time text for given duration and expire values
local function SkinTime(button, duration, expire)
	local bt = button.timeText
	local remaining = (expire or 0) - GetTime()

	if pp.showTime and duration and duration > 0.1 and remaining > 0.05 then -- check if limited duration
		bt:ClearAllPoints() -- need to reset because size changes
		bt:SetFontObject(ChatFontNormal)
		local font = pp.timeFontPath
		if ValidFont(font) then
			local flags = GetFontFlags(pp.timeFontFlags)
			bt:SetFont(font, pp.timeFontSize, flags)
		elseif ValidFont(pp.timeFont) then
			pp.timeFontPath = MOD.LSM:Fetch("font", pp.timeFont)
		end
		bt:SetText("0:00:00") -- set to widest time string, note this is overwritten later with correct string!
		local timeMaxWidth = bt:GetStringWidth() -- get maximum text width using current font
		PSetWidth(bt, timeMaxWidth) -- helps with jitter since keeps size static
		bt:SetShadowColor(0, 0, 0, pp.timeShadow and 1 or 0)
		local pos = pp.timePosition
		local pt = pos.point
		bt:SetJustifyV(justifyV[pt]); bt:SetJustifyH(justifyH[pt]) -- anchor point adjusts alignment too
		local frame = button
		if pp.showBar and (pos.anchor == "bar") then frame = button.bar end
		PSetPoint(bt, pos.point, frame, pos.relativePoint, pos.offsetX, pos.offsetY)
		button._update = 0
		UpdateButtonTime(button)
		bt:Show()
		button:SetScript("OnUpdate", UpdateButtonTime) -- start updating time text
	else
		StopButtonTime(button)
	end
end

-- Configure the button's count text for given value
local function SkinCount(button, count)
	local ct = button.countText

	if pp.showCount and count and count > 1 then -- check if valid parameters
		ct:ClearAllPoints()
		ct:SetFontObject(ChatFontNormal)
		local font = pp.countFontPath
		if ValidFont(font) then
			local flags = GetFontFlags(pp.countFontFlags)
			ct:SetFont(font, pp.countFontSize, flags)
		elseif ValidFont(pp.countFont) then
			pp.countFontPath = MOD.LSM:Fetch("font", pp.countFont)
		end
		local c = pp.countColor
		ct:SetTextColor(c.r, c.g, c.b, c.a)
		ct:SetShadowColor(0, 0, 0, pp.countShadow and 1 or 0)
		ct:SetText(count)
		local pos = pp.countPosition
		local pt = pos.point
		ct:SetJustifyV(justifyV[pt]); ct:SetJustifyH(justifyH[pt]) -- anchor point adjusts alignment too
		local frame = button
		if pp.showBar and (pos.anchor == "bar") then frame = button.bar end
		PSetPoint(ct, pt, frame, pos.relativePoint, pos.offsetX, pos.offsetY)
		ct:Show()
	else
		ct:Hide()
	end
end

-- Configure the button's count text for given value
local function SkinLabel(button, name)
	local lt = button.labelText

	if pp.showLabel and name and name ~= "" then -- check if valid parameters
		lt:ClearAllPoints()
		lt:SetFontObject(ChatFontNormal)
		local font = pp.labelFontPath
		if ValidFont(font) then
			local flags = GetFontFlags(pp.labelFontFlags)
			lt:SetFont(font, pp.labelFontSize, flags)
		elseif ValidFont(pp.labelFont) then
			pp.labelFontPath = MOD.LSM:Fetch("font", pp.labelFont)
		end

		local c = pp.labelColor
		lt:SetTextColor(c.r, c.g, c.b, c.a)
		lt:SetShadowColor(0, 0, 0, pp.labelShadow and 1 or 0)
		lt:SetText(name)
		if pp.labelMaxWidth > 0 then PSetWidth(lt, pp.labelMaxWidth) end
		lt:SetWordWrap(pp.labelWrap)
		lt:SetNonSpaceWrap(pp.labelWordWrap)

		local pos = pp.labelPosition
		local pt = pos.point
		lt:SetJustifyV(justifyV[pt]); lt:SetJustifyH(justifyH[pt]) -- anchor point adjusts alignment too
		local frame = button
		if pp.showBar and (pos.anchor == "bar") then frame = button.bar end
		PSetPoint(lt, pt, frame, pos.relativePoint, pos.offsetX, pos.offsetY)
		lt:Show()
	else
		lt:Hide()
	end
end

-- Clear the button's bar
local function StopBar(bb)
	if bb then
		bb:SetScript("OnUpdate", nil) -- stop updating the time text
		bb._duration = nil
		bb._expire = nil
		bb._limited = nil
		bb:Hide()
	end
end

-- Update the amount of fill for a button's bar, triggered OnUpdate so keep it quick
local function UpdateBar(bb)
	if bb and bb._duration and bb._expire then -- make sure valid call
		local duration = bb._duration
		local remaining = bb._expire - GetTime()
		local stopping = false

		if duration then
			if remaining > duration then remaining = duration end -- range check
			if duration > 0.1 then -- real timer bar
			 	if remaining < 0.05 then stopping = true end
			else -- unlimited bar, check if "full" or "empty"
				if bb._limited == "empty" then remaining = 0 else remaining = 100 end
			end
		end

		if not stopping then
			bb:SetValue(remaining)
		else
			StopBar(bb)
		end
	end
end

-- Configure the button's bar and its border
local function SkinBar(button, duration, expire, barColor, barBorderColor)
	local bb = button.bar
	local bbk = button.barBackdrop
	local opt = pp.barBorder -- option for type of border
	local remaining = (expire or 0) - GetTime()
	local showBorder = false -- set to true when showing border
	local delta, width = 0, 0

	if pp.showBar and ((pp.barUnlimited ~= "none") or (duration and (duration > 0.1) and (remaining > 0.05))) then
		bb:ClearAllPoints()
		bbk:ClearAllPoints()
		bbk:SetBackdrop(nil)
		bb._duration = duration or 0
		bb._expire = expire or 0
		bb._limited = pp.barUnlimited
		local pos = pp.barPosition
		PSetPoint(bb, pos.point, button, pos.relativePoint, pos.offsetX, pos.offsetY)
		local bw = (pp.barWidth > 0) and pp.barWidth or pp.iconSize
		local bh = (pp.barHeight > 0) and pp.barHeight or pp.iconSize

		bb:SetOrientation(pp.barOrientation and "HORIZONTAL" or "VERTICAL")
		bb:SetFillStyle(pp.barDirection and "STANDARD" or "REVERSE")

		local tex = pp.barTexture
		if tex == "None" then tex = nil end
		if tex then tex = MOD.LSM:Fetch("statusbar", tex) end
		if not tex then tex = "Interface\\AddOns\\Bufflehead\\Media\\WhiteBar" end
		bb:SetStatusBarTexture(tex)

		local drop = { -- backdrop initialization for bars, initialized to facilitate pixel borders
			bgFile = tex, edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
			tile = false, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 }
		}

		if (opt == "one") or (opt == "two") then -- skin single/double pixel border
			if (bw > 4) and (bh > 4) then -- check minimum dimensions for border
				if opt == "one" then delta = 2; width = 1 else delta = 4; width = 2 end
				drop.edgeSize = PS(width)
				showBorder = true
			end
		elseif (opt == "media") and (pp.barBorderMedia ~= "None") then -- use shared media border
			width = pp.barBorderOffset or 0
			delta = width * 2
			if (bw > delta) and (bh > delta) then -- check minimum dimensions for this border
				drop.edgeFile = MOD.LSM:Fetch("border", pp.barBorderMedia) or nil
				drop.edgeSize = PS(pp.barBorderWidth or 1)
				showBorder = true
			end
		end

		if showBorder then
			PSetPoint(bbk, "CENTER", bb, "CENTER") -- use backdrop to show the border
			PSetSize(bbk, bw, bh)
			SetInsets(drop, PS(width))
			bbk:SetBackdrop(drop)
			local c = barColor
			bbk:SetBackdropColor(c.r, c.g, c.b, pp.barBackgroundOpacity or c.a)
			c = barBorderColor -- bar backdrop color
			bbk:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
			bbk:Show()
		end

		PSetSize(bb, bw - delta, bh - delta) -- set bar size based on border adjustments

		local c = barColor
		bb:SetStatusBarColor(c.r, c.g, c.b, pp.barForegroundOpacity or 1)
		if (pp.barUnlimited ~= "none") and (duration == 0) then duration = 100 end -- ensure shows unlimited bars
		bb:SetMinMaxValues(0, duration)
		UpdateBar(bb)
		bb:Show()
		bb:SetScript("OnUpdate", UpdateBar) -- start updating bar fill
	else
		StopBar(bb)
		bb:Hide()
	end
end

-- Show a button and skin all its enabled elements
local function ShowButton(button, name, icon, duration, expire, count, btype, barColor, borderColor, barBorderColor)
	if ((duration ~= 0) and (expire ~= button._expire)) or (duration ~= button._duration) or (icon ~= button._icon) or
		(count ~= button._count) or (name ~=button._name) or (btype ~= button._btype) or MOD.uiOpen then

		-- MOD.Debug("att", name, duration, GetTime(), (expire ~= button._expire), (duration ~= button._duration), (icon ~= button._icon),
		--	(count ~= button._count), (name ~=button._name), (btype ~= button._btype), MOD.uiOpen)

		button._expire = expire; button._duration = duration; button._icon = icon
		button._count = count; button._name = name; button._btype = btype

		local tex = button.iconTexture
		tex:ClearAllPoints()
		PSetPoint(tex, "CENTER", icon, "CENTER")
		tex:SetTexture(icon)
		tex:Show()
		SkinBorder(button, borderColor)
		SkinClock(button, duration, expire) -- after highlight!
		SkinTime(button, duration, expire)
		SkinCount(button, count)
		SkinLabel(button, name)
		SkinBar(button, duration, expire, barColor, barBorderColor)
	end
end

-- Hide a button and all its elements
local function HideButton(button)
	button._expire = nil; button._duration = nil; button._icon = nil
	button._count = nil; button._name = nil; button._btype = nil

	button.iconTexture:Hide()
	button.iconHighlight:Hide()
	button.iconBorder:Hide()
	button.iconBackdrop:Hide()
	button.barBackdrop:Hide()
end

-- Function called when an attribute for a button changes
function MOD:Button_OnAttributeChanged(k, v)
	local button = self
	local header = button:GetParent()
	local unit = header:GetAttribute("unit")
	local filter = header:GetAttribute("filter")
	local show, hide = false, false
	local name, icon, count, btype, duration, expire
	local enchant, remaining, id, offEnchant, offRemaining, offCount, offId
	local barColor = pp.barBuffColor
	local borderColor = pp.iconBuffColor
	local barBorderColor = pp.barBorderBuffColor

	if k == "index" then -- update a buff or debuff
		name, icon, count, btype, duration, expire = UnitAura(unit, v, filter)
		if name then
			show = true
			if filter == FILTER_DEBUFFS then
				barColor = pp.barDebuffColor
				borderColor = pp.iconDebuffColor
				barBorderColor = pp.barBorderDebuffColor
				btype = btype or "none"
				local c = _G.DebuffTypeColor[btype]
				if c then
					if pp.debuffColoring then borderColor = c end
					if pp.barDebuffColoring then barColor = c end
					if pp.barBorderDebuffColoring then barBorderColor = c end
				end
			end
		else
			hide = true
		end
	elseif k == "target-slot" and ((v == 16) or (v == 17)) then -- player mainhand or offhand weapon enchant
		enchanted, remaining, count, id, offEnchanted, offRemaining, offCount, offId = GetWeaponEnchantInfo()
		if v == 17 then enchanted = offEnchanted; remaining = offRemaining; count = offCount; id = offId end
		if enchanted then
			remaining = remaining / 1000 -- blizz function returned milliseconds
			expire = remaining + GetTime()
			expire = 0.01 * math.floor(expire * 100 + 0.5) -- round to nearest 1/100
			duration = WeaponDuration(id, remaining)
			icon = GetInventoryItemTexture("player", v)
			name = GetWeaponBuffName(v)
			btype = "none"
			show = true
		else
			hide = true
		end
	end

	if show then -- show the button after skinning all its elements
		ShowButton(button, name, icon, duration, expire, count, btype, barColor, borderColor, barBorderColor)
	elseif hide then -- hide the button and all its elements
		HideButton(button)
	end
end

-- Calculate screen position based on current settings and adjust both header and backdrop
local function UpdatePosition(header)
	if not header then return end -- make sure valid header
	local backdrop = header.anchorBackdrop -- backdrop for this header
	if not backdrop then return end -- make sure valid backdrop
	local name = backdrop.headerName
	local group = pp.groups[name] -- use settings specific to this header
	local pt = header.anchorPoint -- relative point for positioning

	local x = group.anchorX * displayWidth  -- anchor location is based on UIParent using fractions of its size for offsets
	local y = group.anchorY * displayHeight
	header:ClearAllPoints()
	PSetPoint(header, pt, UIParent, "BOTTOMLEFT", x, y)
	backdrop:ClearAllPoints()
	PSetPoint(backdrop, pt, UIParent, "BOTTOMLEFT", x, y)
end

-- While moving an anchor, keep the header moving in sync
local function UpdateBackdrop(backdrop)
	if backdrop._moving then
		local x = PS(backdrop:GetLeft())
		local y = PS(backdrop:GetBottom())
		if backdrop._lastX ~= x or backdrop._lastY ~= y then -- check if actually moving
			local header = MOD.headers[backdrop.headerName]
			local pt = header.anchorPoint -- relative point for positioning
			local name = backdrop.headerName
			local group = pp.groups[name] -- use settings specific to this header
			local dx, dy
			if pt == "TOPLEFT" then
				dx = backdrop:GetLeft()
				dy = backdrop:GetTop()
			elseif pt == "TOPRIGHT" then
				dx = backdrop:GetRight()
				dy = backdrop:GetTop()
			elseif pt == "BOTTOMRIGHT" then
				dx = backdrop:GetRight()
				dy = backdrop:GetBottom()
			elseif pt == "BOTTOMLEFT" then
				dx = backdrop:GetLeft()
				dy = backdrop:GetBottom()
			else
				MOD.Debug("Bufflehead: unknown anchor point", name, pt)
			end
			group.anchorX = dx / displayWidth
			group.anchorY = dy / displayHeight
			backdrop._lastX = x
			backdrop._lastY = y
			UpdatePosition(header)
			MOD.UpdateOptions() -- also update sliders in options panel, if it is open
		end
	end
end

-- Start moving the anchor when mouse down detected (only out-of-combat)
local function Backdrop_OnMouseDown(backdrop)
	if InCombatLockdown() then return end -- don't move anchors in combat!
	if not backdrop.moving then
		backdrop._moving = true
		backdrop._lastX = PS(backdrop:GetLeft())
		backdrop._lastY = PS(backdrop:GetBottom())
		backdrop:SetFrameStrata("HIGH")
		backdrop:StartMoving()
		backdrop:SetScript("OnUpdate", UpdateBackdrop) -- start updating for anchor movement
		-- MOD.Debug("start moving", backdrop.headerName, backdrop._lastX, backdrop._lastY)
	end
end

-- Stop moving the anchor when mouse up detected
local function Backdrop_OnMouseUp(backdrop)
	if backdrop._moving then
		backdrop:SetScript("OnUpdate", nil) -- stop updating the time text
		UpdateBackdrop(backdrop) -- check for possible final movement
		backdrop._moving = false
		backdrop:StopMovingOrSizing()
		backdrop:SetFrameStrata("LOW")
		backdrop._lastX = nil
		backdrop._lastY = nil
	end
end

-- Update secure header with optional attributes based on current profile settings
function MOD.UpdateHeader(header)
	local name = header:GetName()
	if name then
		local group = pp.groups[name] -- settings specific to this header

		if group then
			local red, green = 1, 0 -- anchor color
			local filter = header:GetAttribute("filter")
			header:ClearAllPoints() -- set position any time called
			if group.enabled then
				local s = BUFFS_TEMPLATE
				local i = tonumber(pp.iconSize) -- use different template for each size, constrained by available templates
				if i and (i >= 12) and (i <= 64) then i = 2 * math.floor(i / 2); s = s .. tostring(i) end
				if filter == FILTER_BUFFS then
					red = 0; green = 1
					header:SetAttribute("consolidateTo", 0) -- no consolidation
					if pp.weaponEnchants then header:SetAttribute("weaponTemplate", s) end
				end
				header:SetAttribute("template", s)
				header:SetAttribute("sortMethod", pp.sortMethod)
				header:SetAttribute("sortDirection", pp.sortDirection)
				header:SetAttribute("separateOwn", pp.separateOwn)
				header:SetAttribute("wrapAfter", pp.wrapAfter)
				header:SetAttribute("maxWraps", pp.maxWraps)

				local pt = "TOPRIGHT"
				if pp.directionX > 0 then
					if pp.directionY > 0 then pt = "BOTTOMLEFT" else pt = "TOPLEFT" end
				else
					if pp.directionY > 0 then pt = "BOTTOMRIGHT" end
				end
				header:SetAttribute("point", pt) -- relative point on icons based on grow and wrap directions
				header.anchorPoint = pt

				local wraps = pp.maxWraps -- limit anchor to include just enough rows and columns for 40 buttons
				if (pp.maxWraps * pp.wrapAfter) > 40 then wraps = math.ceil(40 / pp.wrapAfter) end
				local dx, dy, mw, mh, wx, wy = 0, 0, 0, 0, 0, 0
				if pp.growDirection == 1 then -- grow horizontally
					dx = pp.directionX * (pp.spaceX + pp.iconSize)
					wy = pp.directionY * (pp.spaceY + pp.iconSize)
					mw = (PS(pp.spaceX + pp.iconSize) * (pp.wrapAfter - 1)) + PS(pp.iconSize)
					mh = PS(pp.spaceY + pp.iconSize) * wraps
				else -- otherwise grow vertically
					dy = pp.directionY * (pp.spaceY + pp.iconSize)
					wx = pp.directionX * (pp.spaceX + pp.iconSize)
					mw = (PS(pp.spaceX + pp.iconSize) * (wraps - 1)) + PS(pp.iconSize)
					mh = PS(pp.spaceY + pp.iconSize) * pp.wrapAfter
				end
				header:SetAttribute("xOffset", PS(dx))
				header:SetAttribute("yOffset", PS(dy))
				header:SetAttribute("wrapXOffset", PS(wx))
				header:SetAttribute("wrapYOffset", PS(wy))
				header:SetAttribute("minWidth", PS(mw))
				header:SetAttribute("minHeight", PS(mh))
				-- if IsAltKeyDown() then MOD.Debug("Bufflehead: dx/dy", dx, dy, "wx/wy", wx, wy, "mw/mh", mw, mh) end

				UpdatePosition(header) -- update screen position based on current settings
				PSetSize(header, 100, 100)
				header:Show()

				local k = 1
				local button = select(1, header:GetChildren())
				while button do
					button:SetSize(pp.iconSize, pp.iconSize)
					if k > (pp.wrapAfter * pp.maxWraps) and button:IsShown() then button:Hide() end
					k = k + 1
					button = select(k, header:GetChildren())
				end

				local backdrop = header.anchorBackdrop
				PSetSize(backdrop, mw, mh)
				backdrop:SetBackdrop(twoPixelBackdrop)
				backdrop:SetBackdropColor(0, 0, 0, 0) -- transparent background
				backdrop:SetBackdropBorderColor(red, green, 0, 0.5) -- buffs have green border and debuffs have red border

				if MOD.showAnchors then
					backdrop:SetScript("OnMouseDown", Backdrop_OnMouseDown)
					backdrop:SetScript("OnMouseUp", Backdrop_OnMouseUp)
					backdrop.headerName = name
					backdrop:EnableMouse(true)
					backdrop:Show()
				else
					backdrop:SetScript("OnMouseDown", nil)
					backdrop:SetScript("OnMouseUp", nil)
					backdrop:EnableMouse(false)
					backdrop:Hide()
				end
			else
				header:Hide()
			end
		end
	end
end

-- Scan through all the buff locations and show/hide previews as needed
local function UpdatePreviews()
	if not previewMode then MOD.frame:SetScript("OnUpdate", nil) end

	for k, header in pairs(MOD.headers) do
		local pt = header:GetAttribute("point") -- relative point on icons based on grow and wrap directions
		local dx = header:GetAttribute("xOffset")
		local dy = header:GetAttribute("yOffset")
		local wx = header:GetAttribute("wrapXOffset")
		local wy = header:GetAttribute("wrapYOffset")
		local filter = header:GetAttribute("filter")
		local columns, rows = pp.wrapAfter, pp.maxWraps
		local num = rows * columns -- number of icons needed for previewing
		if num > 40 then num = 40 end -- respect the limit on player buffs/debuffs
		local previewButtons = MOD.previews[k]

		for i = 1, #previewButtons do -- check if any icon displayed in each location and show/hide previews
			local button = previewButtons[i]
			local hide = true
			local column = (i - 1) % columns -- which column the button is in, numbered from 0
			local row = math.floor((i - 1) / columns) -- which row the button is in, numbered from 0

			if previewMode and i <= num then
				local real = header:GetAttribute("child" .. i)

				if not real or not real:IsShown() then -- check if real button is currently shown
					button:ClearAllPoints()
					PSetPoint(button, pt, header.anchorBackdrop, pt, (dx * column) + (wx * row), (dy * column) + (wy * row))
					button:SetSize(pp.iconSize, pp.iconSize)
					-- if IsAltKeyDown() then MOD.Debug("Preview: x/y", math.floor((dx * column) + (wx * row)), math.floor((dy * column) + (wy * row)), i, column, row,
					--	math.floor(dx), math.floor(dy), math.floor(wx), math.floor(wy)) end

					local duration = i * 5
					local expire = button._expire or button.bar._expire or (GetTime() + duration)
					local name = "#" .. i
					local icon = PRESET_BUFF_ICON
					local btype = "none"
					local count = (i % 5) + 1
					local borderColor = pp.iconBuffColor
					local barColor = pp.barBuffColor
					local barBorderColor = pp.barBorderBuffColor
					if filter == FILTER_DEBUFFS then
						icon = PRESET_DEBUFF_ICON
						iconColor = pp.iconDebuffColor
						barColor = pp.barDebuffColor
						barBorderColor = pp.barBorderDebuffColor
						local btype = debuffTypes[count]
						if btype ~= "none" then
							local c = _G.DebuffTypeColor[btype]
							if c then
								if pp.debuffColoring then borderColor = c end
								if pp.barDebuffColoring then barColor = c end
								if pp.barBorderDebuffColoring then barBorderColor = c end
							end
						end
					end
					ShowButton(button, name, GetFileIDFromPath(icon), duration, expire, count, btype, barColor, borderColor, barBorderColor)
					button:Show()
					hide = false
				end
			end
			if hide and button:IsShown() then button:Hide(); HideButton(button) end
		end
	end
end

-- Toggle preview mode and allocate preview buttons as needed
function MOD.TogglePreviews()
	previewMode = not previewMode -- toggle on/off preview mode
	if previewMode then
		local num = pp.maxWraps * pp.wrapAfter -- number of icons needed for previewing
		if num > 40 then num = 40 end -- respect the limit on player buffs/debuffs
		for k, header in pairs(MOD.headers) do
			if not MOD.previews[k] then MOD.previews[k] = {} end -- allocate preview buttons on demand
			local previewButtons = MOD.previews[k]
			local currentIcons = #previewButtons -- current number of preview icons
			for i = currentIcons + 1, num do
				local button = CreateFrame("Button", "BuffleheadPreviewButton" .. i, UIParent, BackdropTemplateMixin and "BackdropTemplate")
				MOD:Button_OnLoad(button)
				previewButtons[i] = button
			end
		end
		MOD.frame:SetScript("OnUpdate", UpdatePreviews)
	end
end

-- Convert a time value into a compact text string using a selected display format
MOD.TimeFormatOptions = {
	{ 1, 1, 1, 1, 1 }, { 1, 1, 1, 3, 5 }, { 1, 1, 1, 3, 4 }, { 2, 3, 1, 2, 3 }, -- 4
	{ 2, 3, 1, 2, 2 }, { 2, 3, 1, 3, 4 }, { 2, 3, 1, 3, 5 }, { 2, 2, 2, 2, 3 }, -- 8
	{ 2, 2, 2, 2, 2 }, { 2, 2, 2, 2, 4 }, { 2, 2, 2, 3, 4 }, { 2, 2, 2, 3, 5 }, -- 12
	{ 2, 3, 2, 2, 3 }, { 2, 3, 2, 2, 2 }, { 2, 3, 2, 2, 4 }, { 2, 3, 2, 3, 4 }, -- 16
	{ 2, 3, 2, 3, 5 }, { 2, 3, 3, 2, 3 }, { 2, 3, 3, 2, 2 }, { 2, 3, 3, 2, 4 }, -- 20
	{ 2, 3, 3, 3, 4 }, { 2, 3, 3, 3, 5 }, { 3, 3, 3, 2, 3 }, { 3, 3, 3, 3, 5 }, -- 24
	{ 4, 3, 1, 2, 3 }, { 4, 3, 1, 2, 2 }, { 4, 3, 1, 3, 4 }, { 4, 3, 1, 3, 5 }, -- 28
	{ 5, 1, 1, 2, 3 }, { 5, 1, 1, 2, 2 }, { 5, 1, 1, 3, 4 }, { 5, 1, 1, 3, 5 }, -- 32
	{ 3, 3, 3, 2, 2 }, { 3, 3, 3, 3, 4 }, -- 34
}

function MOD.FormatTime(t, timeFormat, timeSpaces, timeCase)
	if not timeFormat or (timeFormat > #MOD.TimeFormatOptions) then timeFormat = 24 end -- default to most compact
	timeFormat = math.floor(timeFormat)
	if timeFormat < 1 then timeFormat = 1 end
	local opt = MOD.TimeFormatOptions[timeFormat]
	local d, h, m, hplus, mplus, s, ts, f
	local o1, o2, o3, o4, o5 = opt[1], opt[2], opt[3], opt[4], opt[5]
	if t >= 86400 then -- special case for more than one day which applies regardless of selected format
		d = math.floor(t / 86400); h = math.floor((t - (d * 86400)) / 3600)
		if (d >= 2) then f = string.format("%.0fd", d) else f = string.format("%.0fd %.0fh", d, h) end
	else
		h = math.floor(t / 3600); m = math.floor((t - (h * 3600)) / 60); s = math.floor(t - (h * 3600) - (m * 60))
		hplus = math.floor((t + 3599.99) / 3600); mplus = math.floor((t - (h * 3600) + 59.99) / 60) -- provides compatibility with tooltips
		ts = math.floor(t * 10) / 10 -- truncated to a tenth second
		if t >= 3600 then
			if o1 == 1 then f = string.format("%.0f:%02.0f:%02.0f", h, m, s) elseif o1 == 2 then f = string.format("%.0fh %.0fm", h, m)
				elseif o1 == 3 then f = string.format("%.0fh", hplus) elseif o1 == 4 then f = string.format("%.0fh %.0f", h, m)
				else f = string.format("%.0f:%02.0f", h, m) end
		elseif t >= 120 then
			if o2 == 1 then f = string.format("%.0f:%02.0f", m, s) elseif o2 == 2 then f = string.format("%.0fm %.0fs", m, s)
				else f = string.format("%.0fm", mplus) end
		elseif t >= 60 then
			if o3 == 1 then f = string.format("%.0f:%02.0f", m, s) elseif o3 == 2 then f = string.format("%.0fm %.0fs", m, s)
				else f = string.format("%.0fm", mplus) end
		elseif t >= 10 then
			if o4 == 1 then f = string.format(":%02.0f", s) elseif o4 == 2 then f = string.format("%.0fs", s)
				else f = string.format("%.0f", s) end
		else
			if o5 == 1 then f = string.format(":%02.0f", s) elseif o5 == 2 then f = string.format("%.1fs", ts)
				elseif o5 == 3 then f = string.format("%.0fs", s) elseif o5 == 4 then f = string.format("%.1f", ts)
				else f = string.format("%.0f", s) end
		end
	end
	if not timeSpaces then f = string.gsub(f, " ", "") end
	if timeCase then f = string.upper(f) end
	return f
end
