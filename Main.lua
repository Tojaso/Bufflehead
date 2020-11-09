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
MOD.db = nil
MOD.ldb = nil
MOD.ldbi = nil -- set when using DBIcon library
MOD.LibLDB = nil
MOD.MSQ = nil

local FILTER_BUFFS = "HELPFUL"
local FILTER_DEBUFFS = "HARMFUL"

local HEADER_NAME = "BuffleSecureHeader"
local BUFFS_TEMPLATE = "BuffleAuraTemplate"
local PLAYER_BUFFS = "PlayerBuffs"
local PLAYER_DEBUFFS = "PlayerDebuffs"
local HEADER_PLAYER_BUFFS = HEADER_NAME .. PLAYER_BUFFS
local HEADER_PLAYER_DEBUFFS = HEADER_NAME .. PLAYER_DEBUFFS
local HEADER_DEFAULTS = { -- default settings to initialize headers
	enabled = true,
	iconSize = 36,
	iconBorder = "default", -- "default", "one", "two", "raven", "masque"
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
	timeLimit = 0, -- if timeLimit > 0 then only show time when < timeLimit
	showBar = false,
	barHeight = 6,
	barOffset = 2,
	barTexture = 0,
	barBorder = 0,
	barPosition = "TOP",
}

local addonInitialized = false -- set when the addon is initialized
local addonEnabled = false -- set when the addon is enabled
local blizzHidden = false -- set when blizzard buffs and debuffs are hidden
local headers = {} -- secure headers created by this addon

local UnitAura = UnitAura
local GetTime = GetTime
local CreateFrame = CreateFrame
local RegisterAttributeDriver = RegisterAttributeDriver
local RegisterStateDriver = RegisterStateDriver

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

-- Event called when addon is loaded, good time to load libraries
function MOD:OnInitialize()
	if addonInitialized then return end -- only run this code once
	addonInitialized = true
	MOD.frame = CreateFrame("Frame")-- create a frame to catch events
	LoadAddOn("LibDataBroker-1.1")
	LoadAddOn("LibDBIcon-1.0")
	MOD.MSQ = LibStub("Masque", true)
end

-- Adjust pixel perfect scale factor when the UIScale is changed
local function UIScaleChanged()
	pixelWidth, pixelHeight = GetPhysicalScreenSize() -- size in pixels of display in full screen, otherwise window size in pixels
	pixelScale = GetScreenHeight() / pixelHeight -- figure out how big virtual pixels are versus screen pixels
	MOD.Debug("RPB: pixel w/h/scale", pixelWidth, pixelHeight, pixelScale)
end

-- Event called when addon is enabled, good time to register events and chat commands
function MOD:OnEnable()
	if addonEnabled then return end -- only run this code once
	addonEnabled = true
	UIScaleChanged() -- initialize scale factor for pixel perfect size and alignment

	local b = MOD.CopyTable(HEADER_DEFAULTS) -- initialize settings for player buffs and debuffs
	b.unit = "player"; b.filter = FILTER_BUFFS; b.name = PLAYER_BUFFS; b.attachPoint = "TOPRIGHT"
	b.anchorFrame = _G.MMHolder or _G.Minimap; b.anchorPoint = "TOPLEFT"; b.anchorX = -20; b.anchorY = 0
	MOD.DefaultProfile.profile.groups[HEADER_PLAYER_BUFFS] = b

	local d = MOD.CopyTable(HEADER_DEFAULTS)
	d.unit = "player"; d.filter = FILTER_DEBUFFS; d.name = PLAYER_DEBUFFS; d.attachPoint = "BOTTOMRIGHT"
	d.anchorFrame = _G.MMHolder or _G.Minimap; d.anchorPoint = "BOTTOMLEFT"; d.anchorX = -20; d.anchorY = 0
	MOD.DefaultProfile.profile.groups[HEADER_PLAYER_DEBUFFS] = d

	MOD.db = LibStub("AceDB-3.0"):New("BuffleDB", MOD.DefaultProfile) -- get the current profile
	MOD:RegisterChatCommand("buffle", function() MOD.OptionsPanel() end)
	MOD.InitializeLDB() -- initialize the data broker and minimap icon

	self:RegisterEvent("UI_SCALE_CHANGED", UIScaleChanged)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_AURA")
end

-- Event called when play starts, initialize subsystems that had to wait for system bootstrap
function MOD:PLAYER_ENTERING_WORLD()
	if enteredWorld then return end -- only run this code once
	enteredWorld = true

	if MOD.db.profile.enabled then -- make sure addon is enabled, must do /reload if change in options
		MOD.CheckBlizzFrames() -- check blizz frames and hide the ones selected on the Defaults tab
		for name, group in pairs(MOD.db.profile.groups) do
			if group.enabled then -- create headers for enabled groups, must do /reload if change in options
				MOD.CreateHeader(name, group) -- create the header, set its position, and apply all settings
			end
		end
	end
end

-- Event called when an aura changes on a unit, returns the unit name
function MOD:UNIT_AURA(e, unit)
end

-- Create a data broker and minimap icon for the addon
function MOD.InitializeLDB()
	MOD.LibLDB = LibStub("LibDataBroker-1.1", true)
	if not MOD.LibLDB then return end
	MOD.ldb = MOD.LibLDB:NewDataObject("Buffle", {
		type = "launcher",
		text = "Buffle",
		icon = "Interface\\Icons\\Spell_Nature_Wispsplode",
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
	MOD.Debug("hide/show", key, "hide:", hide, "show:", show, "vis: ", visible)
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

-- Toggle visibility of the anchors
function MOD.ToggleAnchors()
end

-- Create secure header for player buffs or debuffs and set essential attributes
function MOD.CreateHeader(name, group)
	local unit, filter = group.unit, group.filter
	local isBuffs = (filter == "BUFFS_FILTER")
	local header = CreateFrame("Frame", name, UIParent, "SecureAuraHeaderTemplate")
	MOD.Debug("RPB: header created", name, unit, filter)
	header:SetClampedToScreen(true)
	header:SetAttribute("unit", unit)
	header:SetAttribute("filter", filter)
	RegisterAttributeDriver(header, "state-visibility", "[petbattle] hide; show")
	if (unit == "player") then
		RegisterAttributeDriver(header, "unit", "[vehicleui] vehicle; player")
		if isBuffs then
			header:SetAttribute("consolidateTo", 0) -- no consolidation
			header:SetAttribute("includeWeapons", 1)
		end
	end
	MOD.UpdateHeader(header)
end

-- Function called when a new aura button is created
function MOD:Button_OnLoad(button)
	local header = button:GetParent()
	local name = header:GetName()
	local filter = header:GetAttribute("filter")
	local isBuff = (filter == FILTER_BUFFS)
	MOD.Debug("RPB: new button", name, filter, isBuff)

	button.iconTexture = button:CreateTexture(nil, "ARTWORK")
	button.iconBorder = button:CreateTexture(nil, "BACKGROUND", nil, 3)

	button:SetScript("OnAttributeChanged", MOD.Button_OnAttributeChanged)
end

-- Skin the icon's border
local function SkinBorder(g, button)
	button.iconTexture:ClearAllPoints()
	button.iconBorder:ClearAllPoints()
	local opt = g.iconBorder -- option for type of border
	local x = g.iconSize
	if opt == "raven" then -- skin with raven's border
		button.iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim away blizzard's default border
		PSetSize(button.iconTexture, x * 0.86, x * 0.86) -- size icon to fit in center of button
		button.iconTexture:SetPoint("CENTER", button, "CENTER")
		button.iconBorder:SetTexture("Interface\\AddOns\\Buffle\\Borders\\IconDefault")
		button.iconBorder:SetAllPoints(button)
		button.iconBorder:Show()
	elseif opt == "default" then -- skin with blizzard's default border
		button.iconTexture:SetTexCoord(0, 1, 0, 1) -- show blizzard's default border
		PSetSize(button.iconTexture, x, x) -- size icon to fill the button
		button.iconTexture:SetPoint("CENTER", button, "CENTER")
		button.iconBorder:Hide()
	elseif (opt == "one") or (opt == "two") then -- skin with single or double pixel border
	elseif opt == "masque" then -- skin using Masque
	end
end

-- Function called when an attribute for a button changes
function MOD:Button_OnAttributeChanged(k, v)
	local button = self
	local header = button:GetParent()
	local name = header:GetName()
	if name then
		local g = MOD.db.profile.groups[name]
		if g then
			-- MOD.Debug("RPB: button attribute", button:GetName(), k, v)
			if k == "index" then -- update a buff or debuff
				local unit = header:GetAttribute("unit")
				local filter = header:GetAttribute("filter")
				local name, icon, count, btype, duration, expire = UnitAura(unit, v, filter)
				if name then
					SkinBorder(g, button)
					button.iconTexture:SetTexture(icon)
					button.iconTexture:Show()
					button:Show()
				else
					button.iconTexture:Hide()
					button.iconBorder:Hide()
					button:Hide()
				end
			elseif k == "target-slot" then -- update a weapon enchant
			end
		end
	end
end

-- Update secure header with optional attributes based on current profile settings
function MOD.UpdateHeader(header)
	local name = header:GetName()
	if name then
		local g = MOD.db.profile.groups[name]
		if g then
			header:ClearAllPoints() -- set position any time called
			if g.enabled then
				local pt = "TOPRIGHT"
				if g.directionX > 0 then
					if g.directionY > 0 then pt = "BOTTOMLEFT" else pt = "BOTTOMRIGHT" end
				else
					if g.directionY > 0 then pt = "TOPLEFT" end
				end
				header:SetAttribute("point", pt) -- relative point on icons based on grow and wrap directions
				MOD.Debug("RPB: grow/wrap", g.directionX, g.directionY, "relative point", pt)

				local s = BUFFS_TEMPLATE
				local i = tonumber(g.iconSize) -- use different template for each size, constrained by available templates
				if i and (i >= 12) and (i <= 64) then i = 2 * math.floor(i / 2); s = s .. tostring(i) end
				MOD.Debug("RPB: template", s)
				header:SetAttribute("template", s)
				header:SetAttribute("weaponTemplate", s)

				header:SetAttribute("sortMethod", g.sortMethod)
				header:SetAttribute("sortDirection", g.sortDirection)
				header:SetAttribute("separateOwn", g.separateOwn)
				header:SetAttribute("wrapAfter", g.wrapAfter)
				header:SetAttribute("maxWraps", g.maxWraps)

				local dx, dy, mw, mh, wx, wy = 0, 0, 0, 0, 0, 0
				if g.growDirection == 1 then -- grow horizontally
					dx = g.directionX * (g.spaceX + g.iconSize)
					wy = g.directionY * (g.spaceY + g.iconSize)
					mw = (((g.wrapAfter == 1) and 0 or g.spaceX) + g.iconSize) * g.wrapAfter
					mh = (g.spaceY + g.iconSize) * g.maxWraps
				else -- otherwise grow vertically
					dy = g.directionY * (g.spaceY + g.iconSize)
					wx = g.directionX * (g.spaceX + g.iconSize)
					mw = (g.spaceX + g.iconSize) * g.maxWraps
					mh = (((g.wrapAfter == 1) and 0 or g.spaceY) + g.iconSize) * g.wrapAfter
				end
				header:SetAttribute("xOffset", PS(dx))
				header:SetAttribute("yOffset", PS(dy))
				header:SetAttribute("wrapXOffset", PS(wx))
				header:SetAttribute("wrapYOffset", PS(wy))
				header:SetAttribute("minWidth", PS(mw))
				header:SetAttribute("minHeight", PS(mh))
				MOD.Debug("RPB: dx/dy", dx, dy, "wx/wy", wx, wy, "mw/mh", mw, mh)

				PSetSize(header, 100, 100)
				PSetPoint(header, g.attachPoint, g.anchorFrame, g.anchorPoint, g.anchorX, g.anchorY)
				header:Show()
				MOD.Debug("RPB: header updated", name)
			else
				header:Hide()
			end
		end
	end
end

-- Convert color codes from hex number to array with r, g, b, a fields (alpha set to 1.0)
function MOD.HexColor(hex)
	local n = tonumber(hex, 16)
	local red = math.floor(n / (256 * 256))
	local green = math.floor(n / 256) % 256
	local blue = n % 256

	return { r = red/255, g = green/255, b = blue/255, a = 1.0 }
	-- return CreateColor(red/255, green/255, blue/255, 1)
end

-- Return a copy of a color, if c is nil then return nil
function MOD.CopyColor(c)
	if not c then return nil end
	-- return CreateColor(c.r, c.g, c.b, c.a)
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

-- Default profile description used to initialize the SavedVariables persistent database
MOD.DefaultProfile = {
	global = { -- shared settings for all characters
		Minimap = { hide = false, minimapPos = 200, radius = 80, }, -- saved DBIcon minimap settings
	},
	profile = { -- settings specific to a profile
		enabled = true, -- enable addon
		hideBlizz = true, -- hide Blizzard buffs and debuffs
		groups = {}, -- settings for each group of buffs and debuffs
	},
}
