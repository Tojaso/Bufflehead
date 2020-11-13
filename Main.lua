-- Buffle is an addon to skin player buffs, including weapon enchants, and debuffs.
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

Buffle = LibStub("AceAddon-3.0"):NewAddon("Buffle", "AceConsole-3.0", "AceEvent-3.0")
local MOD = Buffle
local _

MOD.isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
MOD.frame = nil
MOD.headers = {}
MOD.db = nil
MOD.LibLDB = nil -- LibDataBroker support
MOD.ldb = nil -- set to addon's data broker object
MOD.ldbi = nil -- set for addon's minimap icon

local FILTER_BUFFS = "HELPFUL"
local FILTER_DEBUFFS = "HARMFUL"

local HEADER_NAME = "BuffleSecureHeader"
local BUFFS_TEMPLATE = "BuffleAuraTemplate"
local PLAYER_BUFFS = "PlayerBuffs"
local PLAYER_DEBUFFS = "PlayerDebuffs"
local HEADER_PLAYER_BUFFS = HEADER_NAME .. PLAYER_BUFFS
local HEADER_PLAYER_DEBUFFS = HEADER_NAME .. PLAYER_DEBUFFS

local pixelBackdrop = { -- backdrop initialization for icons when using optional one and two pixel borders
	bgFile = "Interface\\AddOns\\Buffle\\Media\\WhiteBar",
	edgeFile = [[Interface\BUTTONS\WHITE8X8.blp]], edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local anchorBackdrop = { -- backdrop initialization for icons when using optional one and two pixel borders
	edgeFile = [[Interface\BUTTONS\WHITE8X8.blp]], edgeSize = 2, insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local MSQ_ButtonData = { AutoCast = false, AutoCastable = false, Border = false, Checked = false, Cooldown = false, Count = false, Duration = false,
	Disabled = false, Flash = false, Highlight = false, HotKey = false, Icon = false, Name = false, Normal = false, Pushed = false }

local addonInitialized = false -- set when the addon is initialized
local addonEnabled = false -- set when the addon is enabled
local blizzHidden = false -- set when blizzard buffs and debuffs are hidden
local uiScaleChanged = false -- set in combat to defer running event handler
local MSQ = false -- replace with Masque reference when available

local UnitAura = UnitAura
local GetTime = GetTime
local CreateFrame = CreateFrame
local RegisterAttributeDriver = RegisterAttributeDriver
local RegisterStateDriver = RegisterStateDriver
local InCombatLockdown = InCombatLockdown

-- Functions used for pixel pefect calculations
local pixelScale = 1 -- scale factor used for size and alignment

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

-- Event called when addon is loaded, good time to load libraries
function MOD:OnInitialize()
	if addonInitialized then return end -- only run this code once
	addonInitialized = true
	MOD.frame = CreateFrame("Frame")-- create a frame to catch events
	LoadAddOn("LibDataBroker-1.1")
	LoadAddOn("LibDBIcon-1.0")
end

-- Adjust pixel perfect scale factor when the UIScale is changed
local function UIScaleChanged()
	if not enteredWorld then return end
	if InCombatLockdown() then
		uiScaleChanged = true
	else
		local pixelWidth, pixelHeight = GetPhysicalScreenSize() -- size in pixels of display in full screen, otherwise window size in pixels
		pixelScale = GetScreenHeight() / pixelHeight -- figure out how big virtual pixels are versus screen pixels
		uiScaleChanged = false
		MOD.Debug("Buffle: pixel w/h/scale", pixelWidth, pixelHeight, pixelScale)
		MOD.Debug("Buffle: UIParent scale/effective", UIParent:GetScale(), UIParent:GetEffectiveScale())
		for k, header in pairs(MOD.headers) do
			MOD.Debug("Buffle: updating", k)
			MOD.UpdateHeader(header)
		end
	end
end

-- Event called when addon is enabled, good time to register events and chat commands
function MOD:OnEnable()
	if addonEnabled then return end -- only run this code once
	addonEnabled = true

	MOD.db = LibStub("AceDB-3.0"):New("BuffleDB", MOD.DefaultProfile) -- get the current profile
	MOD:RegisterChatCommand("buffle", function() MOD.OptionsPanel() end)
	MOD.InitializeLDB() -- initialize the data broker and minimap icon
	MSQ = LibStub("Masque", true)

	self:RegisterEvent("UI_SCALE_CHANGED", UIScaleChanged)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Event called when play starts, initialize subsystems that had to wait for system bootstrap
function MOD:PLAYER_ENTERING_WORLD()
	if enteredWorld then return end -- only run this code once
	enteredWorld = true
	UIScaleChanged() -- initialize scale factor for pixel perfect size and alignment

	if MOD.db.profile.enabled then -- make sure addon is enabled
		MOD.CheckBlizzFrames() -- check blizz frames and hide the ones selected on the Defaults tab
		for name, group in pairs(MOD.db.profile.groups) do
			if group.enabled then -- create header for enabled group, must do /reload if change header-related options
				local unit, filter = group.unit, group.filter
				local header = CreateFrame("Frame", name, UIParent, "SecureAuraHeaderTemplate")
				MOD.headers[name] = header
				MOD.Debug("Buffle: header created", name, unit, filter)
				header:SetClampedToScreen(true)
				header:SetAttribute("unit", unit)
				header:SetAttribute("filter", filter)
				RegisterAttributeDriver(header, "state-visibility", "[petbattle] hide; show")

				if (unit == "player") then
					RegisterAttributeDriver(header, "unit", "[vehicleui] vehicle; player")
					if filter == FILTER_BUFFS then
						header:SetAttribute("consolidateDuration", -1) -- no consolidation
						header:SetAttribute("includeWeapons", 1)
						MOD.Debug("Buffle: includeWeapons!")
					end
				end

				if MSQ and MOD.db.profile.masque then --  create MSQ group if loaded and enabled
					header._MSQ = MSQ:Group("Buffle", group.name)
				else
					header._MSQ = nil
				end

				header.anchorBackdrop = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
				MOD.UpdateHeader(header)
			end
		end
	end
end

-- Event called when an aura changes on a unit
function MOD:UNIT_AURA(e, unit)
	MOD.Debug("Buffle: UNIT_AURA", unit)
end

-- Event called when leaving combat
function MOD:PLAYER_REGEN_ENABLED(e)
	if uiScaleChanged then UIScaleChanged() end
end

-- Create a data broker and minimap icon for the addon
function MOD.InitializeLDB()
	MOD.LibLDB = LibStub("LibDataBroker-1.1", true)
	if not MOD.LibLDB then return end
	MOD.ldb = MOD.LibLDB:NewDataObject("Buffle", {
		type = "launcher",
		text = "Buffle",
		icon = "Interface\\AddOns\\Buffle\\Media\\BuffleIcon",
		OnClick = function(_, msg)
			if msg == "RightButton" then
				if IsShiftKeyDown() then
					MOD.db.profile.hideBlizz = not MOD.db.profile.hideBlizz
					MOD.CheckBlizzFrames()
				else
					MOD.ToggleAnchors()
				end
			elseif msg == "LeftButton" then
				if IsShiftKeyDown() then
					MOD.db.profile.enabled = not MOD.db.profile.enabled
				else
					MOD.OptionsPanel()
				end
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end
			tooltip:AddLine("Buffle")
			tooltip:AddLine("|cffffff00Left-click|r to open/close options menu")
			tooltip:AddLine("|cffffff00Right-click|r to toggle locking anchors")
			tooltip:AddLine("|cffffff00Shift-left-click|r to enable/disable this addon")
			tooltip:AddLine("|cffffff00Shift-right-click|r to toggle Blizzard buffs and debuffs")
		end,
	})

	MOD.ldbi = LibStub("LibDBIcon-1.0", true)
	if MOD.ldbi then MOD.ldbi:Register("Buffle", MOD.ldb, MOD.db.global.Minimap) end
end

-- Show or hide the blizzard buff frames, called during update so synched with other changes
function MOD.CheckBlizzFrames()
	if not MOD.isClassic and C_PetBattles.IsInBattle() then return end -- don't change visibility of any frame during pet battles
	local frame = _G.BuffFrame
	local hideBlizz = MOD.db.profile.hideBlizz
	local hide, show = false, false
	local visible = frame:IsShown()
	if visible then
		if hideBlizz then hide = true end
	else
		if hideBlizz then show = false else show = blizzHidden end -- only show if this addon hid the frame
	end
	MOD.Debug("Buffle: hide/show", key, "hide:", hide, "show:", show, "vis: ", visible)
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
end

-- Function called when a new aura button is created
function MOD:Button_OnLoad(button)
	local header = button:GetParent()
	local name = header:GetName()
	local filter = header:GetAttribute("filter")
	MOD.Debug("Buffle: new button", name, filter)

	button.iconTexture = button:CreateTexture(nil, "ARTWORK")
	button.iconBorder = button:CreateTexture(nil, "BACKGROUND", nil, 3)
	button.iconBackdrop = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate")
	button.iconBackdrop:SetFrameLevel(button:GetFrameLevel() - 1) -- behind icon
	button.timeText = button:CreateFontString(nil, "OVERLAY")
	button.countText = button:CreateFontString(nil, "OVERLAY")
	button.bar = CreateFrame("StatusBar", nil, button, BackdropTemplateMixin and "BackdropTemplate")
	button.bar:SetFrameLevel(button:GetFrameLevel() + 1) -- in front of icon
	button.bar:SetFrameStrata(button:GetFrameStrata())

	if MSQ then -- if MSQ is loaded then initialize its required data table
		button.buttonMSQ = header._MSQ
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
	PSetPoint(tex, "CENTER", icon, "CENTER") -- texture is always positioned in center of icon's frame
end

-- Skin the icon's border
local function SkinBorder(button)
	button.iconBorder:ClearAllPoints()
	button.iconBackdrop:ClearAllPoints()

	local p = MOD.db.profile -- profile settings are shared across buffs and debuffs
	local opt = p.iconBorder -- option for type of border
	if opt == "raven" then -- skin with raven's border
		IconTextureTrim(button.iconTexture, button, true, p.iconSize * 0.91)
		button.iconBorder:SetTexture("Interface\\AddOns\\Buffle\\Media\\IconDefault")
		button.iconBorder:SetAllPoints(button)
		button.iconBorder:Show()
		button.iconBackdrop:Hide()
	elseif opt == "one" then -- skin with single pixel border
		IconTextureTrim(button.iconTexture, button, true, p.iconSize - 2)
		pixelBackdrop.edgeSize = PS(1)
		button.iconBackdrop:SetAllPoints(button)
		button.iconBackdrop:SetBackdrop(pixelBackdrop)
		button.iconBackdrop:SetBackdropColor(0, 0, 0, 1)
		button.iconBackdrop:Show()
		button.iconBorder:Hide()
	elseif opt == "two" then -- skin with double pixel border
		IconTextureTrim(button.iconTexture, button, true, p.iconSize - 4)
		pixelBackdrop.edgeSize = PS(2)
		button.iconBackdrop:SetAllPoints(button)
		button.iconBackdrop:SetBackdrop(pixelBackdrop)
		button.iconBackdrop:SetBackdropColor(0, 0, 0, 1)
		button.iconBackdrop:Show()
		button.iconBorder:Hide()
	elseif (opt == "masque") and MSQ and button.buttonMSQ and button.buttonData then -- use Masque only if available
		IconTextureTrim(button.iconTexture, button, false, p.iconSize)
		button.buttonMSQ:RemoveButton(button, true) -- may be needed so size changes work correctly
		button.iconBorder:SetAllPoints(button)
		button.iconBorder:Show()
		local bdata = button.buttonData
		bdata.Icon = button.iconTexture
		bdata.Normal = button:GetNormalTexture()
		bdata.Border = button.iconBorder
		button.buttonMSQ:AddButton(button, bdata)
		button.iconBackdrop:Hide()
	elseif opt == "default" then -- default is to just show blizzard's standard border
		IconTextureTrim(button.iconTexture, button, false, p.iconSize)
		button.iconBorder:Hide()
		button.iconBackdrop:Hide()
	end
end

-- Function called when an attribute for a button changes
function MOD:Button_OnAttributeChanged(k, v)
	local button = self
	local header = button:GetParent()
	-- MOD.Debug("Buffle: button attribute", button:GetName(), k, v)
	if k == "index" then -- update a buff or debuff
		local unit = header:GetAttribute("unit")
		local filter = header:GetAttribute("filter")
		local name, icon, count, btype, duration, expire = UnitAura(unit, v, filter)
		if name then
			button.iconTexture:ClearAllPoints(button)
			button.iconTexture:SetPoint("CENTER", button, "CENTER")
			button.iconTexture:SetTexture(icon)
			button.iconTexture:Show()
			SkinBorder(button)
		else
			button.iconTexture:Hide()
			button.iconBorder:Hide()
			button.iconBackdrop:Hide()
		end
	elseif k == "target-slot" then -- update player weapon enchant (v == 16 or 17)
		-- MOD.Debug("Buffle: weapon", v)
		if (v == 16) or (v == 17) then -- mainhand or offhand slot
			local _, expire, _, _, _, offExpire = GetWeaponEnchantInfo()
			if v == 17 then expire = offExpire end
			local icon = GetInventoryItemTexture("player", v)
			button.iconTexture:ClearAllPoints(button)
			button.iconTexture:SetPoint("CENTER", button, "CENTER")
			button.iconTexture:SetTexture(icon)
			button.iconTexture:Show()
			SkinBorder(button)
		else
			button.iconTexture:Hide()
			button.iconBorder:Hide()
			button.iconBackdrop:Hide()
		end
	end
end

-- Update secure header with optional attributes based on current profile settings
function MOD.UpdateHeader(header)
	local name = header:GetName()
	if name then
		local p = MOD.db.profile -- settings shared by buffs and debuffs
		local g = p.groups[name] -- settings specific to this header

		if g then
			local red, green = 1, 0 -- anchor color
			local filter = header:GetAttribute("filter")
			header:ClearAllPoints() -- set position any time called
			if g.enabled then
				local pt = "TOPRIGHT"
				if p.directionX > 0 then
					if p.directionY > 0 then pt = "BOTTOMLEFT" else pt = "BOTTOMRIGHT" end
				else
					if p.directionY > 0 then pt = "TOPLEFT" end
				end
				header:SetAttribute("point", pt) -- relative point on icons based on grow and wrap directions
				MOD.Debug("Buffle: grow/wrap", p.directionX, p.directionY, "relative point", pt)

				local s = BUFFS_TEMPLATE
				local i = tonumber(p.iconSize) -- use different template for each size, constrained by available templates
				if i and (i >= 12) and (i <= 64) then i = 2 * math.floor(i / 2); s = s .. tostring(i) end
				if filter == FILTER_BUFFS then
					red = 0; green = 1
					header:SetAttribute("consolidateTo", 0) -- no consolidation
					header:SetAttribute("weaponTemplate", s)
					MOD.Debug("Buffle: weaponTemplate", s)
				end
				header:SetAttribute("template", s)
				MOD.Debug("Buffle: template", s)

				header:SetAttribute("sortMethod", p.sortMethod)
				header:SetAttribute("sortDirection", p.sortDirection)
				header:SetAttribute("separateOwn", p.separateOwn)
				header:SetAttribute("wrapAfter", p.wrapAfter)
				header:SetAttribute("maxWraps", p.maxWraps)

				local dx, dy, mw, mh, wx, wy = 0, 0, 0, 0, 0, 0
				if p.growDirection == 1 then -- grow horizontally
					dx = p.directionX * (p.spaceX + p.iconSize)
					wy = p.directionY * (p.spaceY + p.iconSize)
					mw = (((p.wrapAfter == 1) and 0 or p.spaceX) + p.iconSize) * p.wrapAfter
					mh = (p.spaceY + p.iconSize) * p.maxWraps
				else -- otherwise grow vertically
					dy = p.directionY * (p.spaceY + p.iconSize)
					wx = p.directionX * (p.spaceX + p.iconSize)
					mw = (p.spaceX + p.iconSize) * p.maxWraps
					mh = (((p.wrapAfter == 1) and 0 or p.spaceY) + p.iconSize) * p.wrapAfter
				end
				header:SetAttribute("xOffset", PS(dx))
				header:SetAttribute("yOffset", PS(dy))
				header:SetAttribute("wrapXOffset", PS(wx))
				header:SetAttribute("wrapYOffset", PS(wy))
				header:SetAttribute("minWidth", PS(mw))
				header:SetAttribute("minHeight", PS(mh))
				MOD.Debug("Buffle: dx/dy", dx, dy, "wx/wy", wx, wy, "mw/mh", mw, mh)

				PSetSize(header, 100, 100)
				PSetPoint(header, g.attachPoint, g.anchorFrame, g.anchorPoint, g.anchorX, g.anchorY)
				header:Show()

				PSetSize(header.anchorBackdrop, mw - 2, mh - 2)
				PSetPoint(header.anchorBackdrop, g.attachPoint, g.anchorFrame, g.anchorPoint, g.anchorX, g.anchorY)
				anchorBackdrop.edgeSize = PS(2)
				header.anchorBackdrop:SetBackdrop(anchorBackdrop)
				header.anchorBackdrop:SetBackdropBorderColor(red, green, 0, 0.75) -- buffs have green border and debuffs have red border
				if p.locked then header.anchorBackdrop:Hide() else header.anchorBackdrop:Show() end

				MOD.Debug("Buffle: header updated", name)
			else
				header:Hide()
			end
		end
	end
end

-- Convert color codes from hex number to array with r, p, b, a fields (alpha set to 1.0)
function MOD.HexColor(hex)
	local n = tonumber(hex, 16)
	local red = math.floor(n / (256 * 256))
	local green = math.floor(n / 256) % 256
	local blue = n % 256

	return { r = red/255, p = green/255, b = blue/255, a = 1.0 }
	-- return CreateColor(red/255, green/255, blue/255, 1)
end

-- Return a copy of a color, if c is nil then return nil
function MOD.CopyColor(c)
	if not c then return nil end
	-- return CreateColor(c.r, c.p, c.b, c.a)
	return { r = c.r, p = c.p, b = c.b, a = c.a }
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

-- Convert a time value into a compact text string using a selected display format
local TimeFormatOptions = {
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
	if not timeFormat or (timeFormat > #MOD.Nest_TimeFormatOptions) then timeFormat = 24 end -- default to most compact
	timeFormat = math.floor(timeFormat)
	if timeFormat < 1 then timeFormat = 1 end
	local opt = TimeFormatOptions[timeFormat]
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

-- Default profile description used to initialize the SavedVariables persistent database
MOD.DefaultProfile = {
	global = { -- shared settings for all characters
		Minimap = { hide = false, minimapPos = 200, radius = 80, }, -- saved DBIcon minimap settings
	},
	profile = { -- settings specific to a profile
		enabled = true, -- enable addon
		hideBlizz = true, -- hide Blizzard buffs and debuffs
		locked = true, -- hide the anchors when locked
		masque = true, -- enable use of Masque
		iconSize = 36,
		iconBorder = "one", -- "default", "one", "two", "raven", "masque"
		offsetX = 0,
		offsetY = 0,
		growDirection = 1, -- horizontal = 1, otherwise vertical
		directionX = -1,
		directionY = -1,
		spaceX = 2,
		spaceY = 2,
		sortMethod = "TIME",
		sortDirection = "-",
		separateOwn = true,
		wrapAfter = 20,
		maxWraps = 2,
		showTime = true,
		timeFont = 0, -- use system font
		timeFontSize = 14,
		timeFontOutline = "OUTLINE",
		timeFormat = 0, -- use default time format
		timeSpaces = false, -- if true include spaces in time text
		timeCase = false, -- if true use upper case in time text
		timeLimit = 0, -- if timeLimit > 0 then only show time when < timeLimit
		showBar = false,
		barHeight = 6,
		barOffset = 2,
		barTexture = 0,
		barBorder = 0,
		barPosition = "TOP",
		groups = {
			[HEADER_PLAYER_BUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_BUFFS,
				name = PLAYER_BUFFS,
				attachPoint = "TOPRIGHT",
				anchorFrame = _G.MMHolder or _G.Minimap,
				anchorPoint = "TOPLEFT",
				anchorX = -44,
				anchorY = 0,
			},
			[HEADER_PLAYER_DEBUFFS] = {
				enabled = true,
				unit = "player",
				filter = FILTER_DEBUFFS,
				name = PLAYER_DEBUFFS,
				attachPoint = "TOPRIGHT",
				anchorFrame = _G.MMHolder or _G.Minimap,
				anchorPoint = "TOPLEFT",
				anchorX = -44,
				anchorY = -84, -- set to roughly maxWraps * (iconSize + spaceY) + 8
			},
		},
	},
}
