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
	acereg:RegisterOptionsTable("Buffle: "..options.args.FrontPage.name, options.args.FrontPage)
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
		FrontPage = {
			type = "group", order = 10, name = "Setup",
			args = {
				EnableGroup = {
					type = "group", order = 1, name = "Enable", inline = true,
					args = {
						EnableGroup = {
							type = "toggle", order = 10, name = "Enable Addon",
							desc = "If checked, this addon is enabled, otherwise all features are disabled.",
							get = function(info) return pg.enabled end,
							set = function(info, value) pg.enabled = value end,
						},
						EnableHideBlizz = {
							type = "toggle", order = 20, name = "Hide Blizzard",
							desc = "If checked, hide the default Blizzard buffs and debuffs.",
							get = function(info) return pg.hideBlizz end,
							set = function(info, value) pg.hideBlizz = value end,
						},
						EnableMinimapIcon = {
							type = "toggle", order = 35, name = "Minimap Icon",
							desc = "If checked, add a minimap icon for toggling the options panel.",
							hidden = function(info) return MOD.ldbi == nil end,
							get = function(info) return not pg.Minimap.hide end,
							set = function(info, value)
								pg.Minimap.hide = not value
								if value then MOD.ldbi:Show("Buffle") else MOD.ldbi:Hide("Buffle") end
							end,
						},
					},
				},
			},
		},
--[[
		BarGroups = {
			type = "group", order = 25, name = L["Bar Groups"], childGroups = "tab",
			disabled = function(info) return InMode("Not") end,
			args = {
				SelectBarGroup = {
					type = "select", order = 1, name = L["Bar Group"],
					get = function(info) UpdateBarList(); return GetSelectedBarGroup() end,
					set = function(info, value) SetSelectedBarGroup(value) end,
					disabled = function(info) return NoBarGroup() or InMode("Bar") end,
					values = function(info) return GetBarGroupList() end,
					style = "dropdown",
				},
				Space1 = { type = "description", name = "", order = 2, width = "half" },
				NewBarGroupButton = {
					type = "execute", order = 3, name = L["New Custom Group"],
					desc = L["Create a new bar group with manually added bars."],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return bars.enter end,
					func = function(info) bars.enter, bars.toggle, bars.auto = true, true, false end,
				},
				NewAutoBarGroupButton = {
					type = "execute", order = 4, name = L["New Auto Group"],
					desc = L["Create a new bar group with automatically displayed bars."],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return bars.enter end,
					func = function(info) bars.enter, bars.toggle, bars.auto = true, true, true end,
				},
				NewCustomBarGroupName = {
					type = "input", order = 5, name = L["Enter Custom Group Name"],
					desc = L["Enter name of new custom bar group."],
					hidden = function(info) return not bars.enter or bars.auto end,
					validate = function(info, n) if not n or (n == "") then return L["Invalid name."] else return true end end,
					confirm = function(info, value) return ConfirmNewBarGroup(value) end,
					get = function(info)
						bars.enter = bars.toggle; enterNewBarGroupType = false
						if bars.toggle then bars.toggle = false end
						if not bars.enter then UpdateOptions() end
						return false
					end,
					set = function(info, value) bars.enter = false
						local bg = CreateBarGroup(value, false, false, true, 0, 0); bg.showNoDuration = true
					end,
				},
				NewAutoBarGroupName = {
					type = "input", order = 6, name = L["Enter Auto Group Name"],
					desc = L["Enter name of new auto bar group."],
					hidden = function(info) return not bars.enter or not bars.auto end,
					validate = function(info, n) if not n or (n == "") then return L["Invalid name."] else return true end end,
					confirm = function(info, value) return ConfirmNewBarGroup(value) end,
					get = function(info)
						bars.enter = bars.toggle; enterNewBarGroupType = false
						if bars.toggle then bars.toggle = false end
						if not bars.enter then UpdateOptions() end
						return false
					end,
					set = function(info, value)
						bars.enter = false
						local bg = CreateBarGroup(value, true, false, true, 0, 0); bg.showNoDuration = true
					end,
				},
				CancelNewBarGroup = {
					type = "execute", order = 7, name = L["Cancel"], width = "half",
					desc = L["Cancel creating a new bar group."],
					hidden = function(info) return not bars.enter end,
					func = function(info) bars.enter, bars.toggle = false, false end,
				},
				DeleteBarGroup = {
					type = "execute", order = 8, name = L["Delete"], width = "half",
					desc = L["Delete the selected bar group."],
					disabled = function(info) return NoBarGroup() or InMode("Bar") end,
					hidden = function(info) return bars.enter end,
					func = function(info) DeleteBarGroup() end,
					confirm = function(info) return L["Delete bar group string"](GetBarGroupField("name")) end,
				},
				GeneralTab = {
					type = "group", order = 10, name = L["General"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() end,
					args = {
						SettingsGroup = {
							type = "group", order = 1, name = L["Settings"], inline = true,
							args = {
								EnableBarGroup = {
									type = "toggle", order = 10, name = L["Enable Bar Group"],
									desc = L["Enable bar group string"],
									get = function(info) return GetBarGroupField("enabled") end,
									set = function(info, value) SetBarGroupField("enabled", value) end,
								},
								LockAnchor = {
									type = "execute", order = 50, name = L["Lock Anchor"],
									desc = L["Lock and hide the anchor for the bar group."],
									func = function(info) SetBarGroupField("locked", true) end,
								},
								UnlockAnchor = {
									type = "execute", order = 55, name = L["Unlock Anchor"],
									desc = L["Unlock and show the anchor for the bar group."],
									func = function(info) SetBarGroupField("locked", false) end,
								},
								Space1 = { type = "description", name = "", order = 60 },
								Rename = {
									type = "input", order = 65, name = L["Rename Bar Group"],
									validate = function(info, n) if not n or (n == "") then return L["Invalid name."] else return true end end,
									confirm = function(info, value) return ConfirmNewBarGroup(value) end,
									desc = L["Enter new name for the bar group."],
									get = function(info) return GetBarGroupField("name") end,
									set = function(info, value) RenameBarGroup(value) end,
								},
								FrameStrata = {
									type = "select", order = 66, name = L["Frame Strata"],
									desc = L["Frame strata string"],
									disabled = function(info) return GetBarGroupField("merged") end,
									get = function(info) return GetBarGroupField("strata") end,
									set = function(info, value) SetBarGroupField("strata", value) end,
									values = function(info) return stratas end,
									style = "dropdown",
								},
								EnableMerge = {
									type = "toggle", order = 75, name = L["Merge Bar Group"],
									desc = L["Merge bar group string"],
									get = function(info) return GetBarGroupField("merged") end,
									set = function(info, value) SetBarGroupField("merged", value) end,
								},
								MergeBarGroup = {
									type = "select", order = 76, name = L["Bar Group To Merge Into"],
									desc = L["Select a bar group to merge into."],
									disabled = function(info) return not GetBarGroupField("merged") end,
									get = function(info) return GetMergeBarGroup() end,
									set = function(info, value) SetMergeBarGroup(value) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
							},
						},
						SharingGroup = {
							type = "group", order = 5, name = L["Sharing"], inline = true,
							args = {
								LinkSettings = {
									type = "toggle", order = 10, name = L["Link Settings"],
									desc = L["Link settings string"],
									get = function(info) return GetBarGroupField("linkSettings") end,
									set = function(info, value)
										if value then MOD:LoadBarGroupSettings(GetBarGroupEntry()) end -- if enabling link then get shared settings
										SetBarGroupField("linkSettings", value)
									end,
									confirm = function(info)
										local n = GetBarGroupField("name")
										if GetBarGroupField("linkSettings") then return L["Confirm unlink string"] end
										if MOD.db.global.Settings[n] then return L["Confirm link string"] end
										return false
									end
								},
								LoadSettings = {
									type = "execute", order = 15, name = L["Load Settings"],
									desc = L["Click to load the shared settings used by bar groups with same name in other profiles."],
									disabled = function(info) return GetBarGroupField("linkSettings") end,
									func = function(info) MOD:LoadBarGroupSettings(GetBarGroupEntry()) end,
									confirm = function(info)
										local n = GetBarGroupField("name")
										if MOD.db.global.Settings[n] then return L["Confirm load string"] end
										return L["No linked settings string"]
									end
								},
								SaveSettings = {
									type = "execute", order = 20, name = L["Save Settings"],
									desc = L["Click to save to the shared settings used by bar groups with same name in other profiles."],
									disabled = function(info) return GetBarGroupField("linkSettings") end,
									func = function(info) MOD:SaveBarGroupSettings(GetBarGroupEntry()) end,
									confirm = function(info) return L["Confirm save string"] end,
								},
								Space1 = { type = "description", name = "", order = 25 },
								LinkBars = {
									type = "toggle", order = 30, name = L["Link Custom Bars"],
									desc = L["Link bars string"],
									hidden = function(info) return GetBarGroupField("auto") end,
									get = function(info) return GetBarGroupField("linkBars") end,
									set = function(info, value)
										if value then MOD:LoadCustomBars(GetBarGroupEntry()) end -- if enabling link then get shared bars
										SetBarGroupField("linkBars", value)
									end,
									confirm = function(info)
										local n = GetBarGroupField("name")
										if GetBarGroupField("linkBars") then return L["Confirm unlink bars string"] end
										if MOD.db.global.CustomBars[n] then return L["Confirm link bars string"] end
										return false
									end
								},
								LoadBars = {
									type = "execute", order = 35, name = L["Load Custom Bars"],
									hidden = function(info) return GetBarGroupField("auto") end,
									disabled = function(info) return GetBarGroupField("linkBars") end,
									desc = L["Click to load the shared custom bars used by bar groups with same name in other profiles."],
									func = function(info) MOD:LoadCustomBars(GetBarGroupEntry()) end,
									confirm = function(info)
										local n = GetBarGroupField("name")
										if MOD.db.global.CustomBars[n] then return L["Confirm load bars string"] end
										return L["No linked bars string"]
									end
								},
								SaveBars = {
									type = "execute", order = 40, name = L["Save Custom Bars"],
									hidden = function(info) return GetBarGroupField("auto") end,
									disabled = function(info) return GetBarGroupField("linkBars") end,
									desc = L["Click to save to the shared custom bars used by bar groups with same name in other profiles."],
									func = function(info) MOD:SaveCustomBars(GetBarGroupEntry()) end,
									confirm = function(info) return L["Confirm save bars string"] end,
								},
							},
						},
						SortingGroup = {
							type = "group", order = 10, name = L["Sort Order"], inline = true,
							hidden = function(info) return GetBarGroupField("merged") end,
							args = {
								AtoZOrder = {
									type = "toggle", order = 10, name = L["A to Z"], width = "half",
									desc = L["If checked, sort in ascending alphabetical order starting at bar closest to the anchor."],
									get = function(info) return GetBarGroupField("sor") == "A" end,
									set = function(info, value) SetBarGroupField("sor", "A") end,
								},
								TimeLeftOrder = {
									type = "toggle", order = 20, name = L["Time Left"], width = "half",
									desc = L["If checked, sort by time left in ascending order starting at bar closest to the anchor."],
									get = function(info) return GetBarGroupField("sor") == "T" end,
									set = function(info, value) SetBarGroupField("sor", "T") end,
								},
								DurationOrder = {
									type = "toggle", order = 30, name = L["Duration"], width = "half",
									desc = L["If checked, sort by overall duration in ascending order starting at bar closest to the anchor."],
									get = function(info) return GetBarGroupField("sor") == "D" end,
									set = function(info, value) SetBarGroupField("sor", "D") end,
								},
								StartOrder = {
									type = "toggle", order = 35, name = L["Creation"], width = "half",
									desc = L["If checked, show bars in order created with oldest bar closest to the anchor."],
									get = function(info) return GetBarGroupField("sor") == "S" end,
									set = function(info, value) SetBarGroupField("sor", "S") end,
								},
								CustomOrder = {
									type = "toggle", order = 50, name = L["Custom"], width = "half",
									desc = L["If checked, allow manually setting the order of bars."],
									hidden = function(info) return GetBarGroupField("auto") end,
									get = function(info) return GetBarGroupField("sor") == "X" end,
									set = function(info, value) SetBarGroupField("sor", "X") end,
								},
								ReverseSortOrder = {
									type = "toggle", order = 60, name = L["Reverse Order"],
									desc = L['If checked, reverse the sort order (e.g., "A to Z" becomes "Z to A").'],
									get = function(info) return GetBarGroupField("reverseSort") end,
									set = function(info, value) SetBarGroupField("reverseSort", value) end,
								},
								spacer = { type = "description", name = "", order = 70, },
								TimeSortOrder = {
									type = "toggle", order = 75, name = L["Also Time Left"],
									desc = L['If checked, before applying selected sort order, first sort by time left.'],
									get = function(info) return GetBarGroupField("timeSort") end,
									set = function(info, value) SetBarGroupField("timeSort", value) end,
								},
								PlayerSortOrder = {
									type = "toggle", order = 80, name = L["Also Player First"],
									desc = L['If checked, after applying selected sort order, sort bars with actions by player first.'],
									get = function(info) return GetBarGroupField("playerSort") end,
									set = function(info, value) SetBarGroupField("playerSort", value) end,
								},
							},
						},
						ShowWhenGroup = {
							type = "group", order = 20, name = L["Show When"], inline = true,
							args = {
								InCombatGroup = {
									type = "toggle", order = 10, name = L["In Combat"],
									desc = L["If checked, bar group is shown when the player is in combat."],
									get = function(info) return GetBarGroupField("showCombat") end,
									set = function(info, value) SetBarGroupField("showCombat", value) end,
								},
								OutOfCombatGroup = {
									type = "toggle", order = 11, name = L["Out Of Combat"],
									desc = L["If checked, bar group is shown when the player is out of combat."],
									get = function(info) return GetBarGroupField("showOOC") end,
									set = function(info, value) SetBarGroupField("showOOC", value) end,
								},
								RestingGroup = {
									type = "toggle", order = 12, name = L["Resting"],
									desc = L["If checked, bar group is shown when the player is resting."],
									get = function(info) return GetBarGroupField("showResting") end,
									set = function(info, value) SetBarGroupField("showResting", value) end,
								},
								StealthGroup = {
									type = "toggle", order = 13, name = L["Stealthed"],
									desc = L["If checked, bar group is shown when the player is stealthed."],
									get = function(info) return GetBarGroupField("showStealth") end,
									set = function(info, value) SetBarGroupField("showStealth", value) end,
								},
								MountedGroup = {
									type = "toggle", order = 20, name = L["Mounted"],
									desc = L["If checked, bar group is shown when the player is mounted."],
									get = function(info) return GetBarGroupField("showMounted") end,
									set = function(info, value) SetBarGroupField("showMounted", value) end,
								},
								EnemyGroup = {
									type = "toggle", order = 22, name = L["Enemy"],
									desc = L["If checked, bar group is shown when the target is an enemy."],
									get = function(info) return GetBarGroupField("showEnemy") end,
									set = function(info, value) SetBarGroupField("showEnemy", value) end,
								},
								FriendGroup = {
									type = "toggle", order = 23, name = L["Friendly"],
									desc = L["If checked, bar group is shown when the target is friendly."],
									get = function(info) return GetBarGroupField("showFriend") end,
									set = function(info, value) SetBarGroupField("showFriend", value) end,
								},
								NeutralGroup = {
									type = "toggle", order = 24, name = L["Neutral"],
									desc = L["If checked, bar group is shown when the target is neutral."],
									get = function(info) return GetBarGroupField("showNeutral") end,
									set = function(info, value) SetBarGroupField("showNeutral", value) end,
								},
								SoloGroup = {
									type = "toggle", order = 30, name = L["Solo"],
									desc = L["If checked, bar group is shown when the player is not in a party or raid."],
									get = function(info) return GetBarGroupField("showSolo") end,
									set = function(info, value) SetBarGroupField("showSolo", value) end,
								},
								PartyGroup = {
									type = "toggle", order = 31, name = L["In Party"],
									desc = L["If checked, bar group is shown when the player is in a party."],
									get = function(info) return GetBarGroupField("showParty") end,
									set = function(info, value) SetBarGroupField("showParty", value) end,
								},
								RaidGroup = {
									type = "toggle", order = 32, name = L["In Raid"],
									desc = L["If checked, bar group is shown when the player is in a raid."],
									get = function(info) return GetBarGroupField("showRaid") end,
									set = function(info, value) SetBarGroupField("showRaid", value) end,
								},
								BattlegroundGroup = {
									type = "toggle", order = 33, name = L["In Battleground"],
									desc = L["If checked, bar group is shown when the player is in a battleground."],
									get = function(info) return GetBarGroupField("showBattleground") end,
									set = function(info, value) SetBarGroupField("showBattleground", value) end,
								},
								InstanceGroup = {
									type = "toggle", order = 34, name = L["In Instance"],
									desc = L["If checked, bar group is shown when the player is in a 5-man or raid instance."],
									get = function(info) return GetBarGroupField("showInstance") end,
									set = function(info, value) SetBarGroupField("showInstance", value) end,
								},
								NotInstanceGroup = {
									type = "toggle", order = 35, name = L["Not In Instance"],
									desc = L["If checked, bar group is shown when the player is not in a 5-man or raid instance."],
									get = function(info) return GetBarGroupField("showNotInstance") end,
									set = function(info, value) SetBarGroupField("showNotInstance", value) end,
								},
								ArenaGroup = {
									type = "toggle", order = 36, name = L["In Arena"],
									desc = L["If checked, bar group is shown when the player is in an arena."],
									get = function(info) return GetBarGroupField("showArena") end,
									set = function(info, value) SetBarGroupField("showArena", value) end,
								},
								PetBattleGroup = {
									type = "toggle", order = 37, name = L["In Pet Battle"],
									desc = L["If checked, bar group is shown when the player is in a pet battle."],
									get = function(info) return GetBarGroupField("showPetBattle") end,
									set = function(info, value) SetBarGroupField("showPetBattle", value) end,
								},
								ShowIfBlizzard = {
									type = "toggle", order = 45, name = L["Blizzard Buffs Enabled"],
									desc = L["If checked, the bar group is shown if the default user interface for buffs is enabled."],
									get = function(info) return GetBarGroupField("showBlizz") end,
									set = function(info, value) SetBarGroupField("showBlizz", value) end,
								},
								ShowNotBlizzard = {
									type = "toggle", order = 46, name = L["Blizzard Buffs Disabled"],
									desc = L["If checked, the bar group is shown if the default user interface for buffs is disabled."],
									get = function(info) return GetBarGroupField("showNotBlizz") end,
									set = function(info, value) SetBarGroupField("showNotBlizz", value) end,
								},
								VehicleGroup = {
									type = "toggle", order = 49, name = L["Vehicle"],
									desc = L["If checked, bar group is shown when the player is in a vehicle."],
									get = function(info) return GetBarGroupField("showVehicle") end,
									set = function(info, value) SetBarGroupField("showVehicle", value) end,
								},
								OnTaxi = {
									type = "toggle", order = 50, name = L["On Taxi"],
									desc = L["If checked, bar group is shown when player is flying on a taxi."],
									get = function(info) return GetBarGroupField("showOnTaxi") end,
									set = function(info, value) SetBarGroupField("showOnTaxi", value) end,
								},
								FocusTargetGroup = {
									type = "toggle", order = 55, name = L["Focus=Target"],
									desc = L["If checked, bar group is shown when focus is same as target."],
									get = function(info) return GetBarGroupField("showFocusTarget") end,
									set = function(info, value) SetBarGroupField("showFocusTarget", value) end,
								},
								SelectClass = {
									type = "group", order = 75, name = L["Player Class"], inline = true,
									args = {
										Druid = {
											type = "toggle", order = 10, name = L["Druid"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.DRUID end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { DRUID = not value } ) else t.DRUID = not value end
											end
										},
										Hunter = {
											type = "toggle", order = 15, name = L["Hunter"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.HUNTER end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { HUNTER = not value } ) else t.HUNTER = not value end
											end
										},
										Mage = {
											type = "toggle", order = 20, name = L["Mage"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.MAGE end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { MAGE = not value } ) else t.MAGE = not value end
											end
										},
										Monk = {
											type = "toggle", order = 22, name = L["Monk"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.MONK end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { MONK = not value } ) else t.MONK = not value end
											end
										},
										Paladin = {
											type = "toggle", order = 25, name = L["Paladin"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.PALADIN end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { PALADIN = not value } ) else t.PALADIN = not value end
											end
										},
										Priest = {
											type = "toggle", order = 30, name = L["Priest"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.PRIEST end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { PRIEST = not value } ) else t.PRIEST = not value end
											end
										},
										Rogue = {
											type = "toggle", order = 35, name = L["Rogue"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.ROGUE end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { ROGUE = not value } ) else t.ROGUE = not value end
											end
										},
										Shaman = {
											type = "toggle", order = 40, name = L["Shaman"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.SHAMAN end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { SHAMAN = not value } ) else t.SHAMAN = not value end
											end
										},
										Warlock = {
											type = "toggle", order = 45, name = L["Warlock"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.WARLOCK end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { WARLOCK = not value } ) else t.WARLOCK = not value end
											end
										},
										Warrior = {
											type = "toggle", order = 50, name = L["Warrior"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.WARRIOR end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { WARRIOR = not value } ) else t.WARRIOR = not value end
											end
										},
										DeathKnight = {
											type = "toggle", order = 55, name = L["Death Knight"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.DEATHKNIGHT end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { DEATHKNIGHT = not value } ) else t.DEATHKNIGHT = not value end
											end
										},
										DemonHunter = {
											type = "toggle", order = 60, name = L["Demon Hunter"], width = "half",
											get = function(info) local t = GetBarGroupField("showClasses"); return not t or not t.DEMONHUNTER end,
											set = function(info, value)
												local t = GetBarGroupField("showClasses")
												if not t then SetBarGroupField("showClasses", { DEMONHUNTER = not value } ) else t.DEMONHUNTER = not value end
											end
										},
									},
								},
								SelectSpecialization = {
									type = "group", order = 85, name = L["Player Specialization"], inline = true,
									args = {
										SpecializationCheck = {
											type = "input", order = 10, name = L["Specialization"], width = "double",
											desc = L["Enter comma-separated specialization names or numbers to check (leave blank to ignore specialization)."],
											get = function(info) return GetBarGroupField("showSpecialization") end,
											set = function(info, value) SetBarGroupField("showSpecialization", value);
												SetBarGroupField("specializationList", ParseStringTable(value)) end,
										},
									},
								},
								SelectCondition = {
									type = "group", order = 90, name = L["Condition"], inline = true,
									args = {
										CheckCondition = {
											type = "toggle", order = 10, name = L["Condition Is True"],
											desc = L["If checked, bar group is shown only when the selected condition is true."],
											get = function(info) return GetBarGroupField("checkCondition") end,
											set = function(info, value) if not value then SetBarGroupField("condition", nil) end; SetBarGroupField("checkCondition", value) end,
										},
										SelectCondition = {
											type = "select", order = 15, name = L["Condition"],
											disabled = function(info) return not GetBarGroupField("checkCondition") end,
											get = function(info) return GetBarGroupSelectedCondition(GetSelectConditionList()) end,
											set = function(info, value) SetBarGroupField("condition", GetSelectConditionList()[value]) end,
											values = function(info) return GetSelectConditionList() end,
											style = "dropdown",
										},
									},
								},
							},
						},
						OpacityGroup = {
							type = "group", order = 25, name = L["Opacity"], inline = true,
							args = {
								InCombatlpha = {
									type = "range", order = 10, name = L["In Combat"], min = 0, max = 1, step = 0.05,
									desc = L["Set opacity for bar group when in combat."],
									disabled = function(info) return GetBarGroupField("disableAlpha") end,
									get = function(info) return GetBarGroupField("bgCombatAlpha") end,
									set = function(info, value) SetBarGroupField("bgCombatAlpha", value) end,
								},
								OutOfCombatAlpha = {
									type = "range", order = 20, name = L["Out Of Combat"], min = 0, max = 1, step = 0.05,
									desc = L["Set opacity for bar group when out of combat."],
									disabled = function(info) return GetBarGroupField("disableAlpha") end,
									get = function(info) return GetBarGroupField("bgNormalAlpha") end,
									set = function(info, value) SetBarGroupField("bgNormalAlpha", value) end,
								},
								MouseAlpha = {
									type = "range", order = 30, name = L["Mouseover"], min = 0, max = 1, step = 0.05,
									desc = L["Set opacity for bar group when mouse is over it (overrides in and out of combat opacities)."],
									disabled = function(info) return GetBarGroupField("disableAlpha") end,
									get = function(info) return GetBarGroupField("mouseAlpha") end,
									set = function(info, value) SetBarGroupField("mouseAlpha", value) end,
								},
								FadeAlpha = {
									type = "range", order = 40, name = L["Fade Effects"], min = 0, max = 1, step = 0.05,
									desc = L["Set opacity for faded bars."],
									disabled = function(info) return GetBarGroupField("disableAlpha") end,
									get = function(info) return GetBarGroupField("fadeAlpha") end,
									set = function(info, value) SetBarGroupField("fadeAlpha", value) end,
								},
							},
						},
						EffectsGroup = {
							type = "group", order = 30, name = L["Special Effects"], inline = true,
							args = {
								EnableBGSFX = {
									type = "toggle", order = 1, name = L["Enable"], width = "half",
									desc = L["If checked, bar group special effects are enabled."],
									get = function(info) return not GetBarGroupField("disableBGSFX") end,
									set = function(info, value) SetBarGroupField("disableBGSFX", not value) end,
								},
								StartTab = {
									type = "group", order = 10, name = L["Start Effects"],
									hidden = function(info) return GetBarGroupField("disableBGSFX") end,
									args = {
										Shine = {
											type = "toggle", order = 10, name = L["Shine"], width = "half",
											desc = L["Enable shine effect when bar is started."],
											get = function(info) return GetBarGroupField("shineStart") end,
											set = function(info, value) SetBarGroupField("shineStart", value) end,
										},
										Sparkle = {
											type = "toggle", order = 11, name = L["Sparkle"], width = "half",
											desc = L["Enable sparkle effect when bar is started."],
											get = function(info) return GetBarGroupField("sparkleStart") end,
											set = function(info, value) SetBarGroupField("sparkleStart", value) end,
										},
										Pulse = {
											type = "toggle", order = 12, name = L["Pulse"], width = "half",
											desc = L["Enable icon pulse when bar is started."],
											get = function(info) return GetBarGroupField("pulseStart") end,
											set = function(info, value) SetBarGroupField("pulseStart", value) end,
										},
										Glow = {
											type = "toggle", order = 13, name = L["Glow"], width = "half",
											desc = L["Enable glow effect when bar is started."],
											get = function(info) return GetBarGroupField("glowStart") end,
											set = function(info, value) SetBarGroupField("glowStart", value) end,
										},
										Flash = {
											type = "toggle", order = 14, name = L["Flash"],
											desc = L["Enable flashing when bar is started."], width = "half",
											get = function(info) return GetBarGroupField("flashStart") end,
											set = function(info, value) SetBarGroupField("flashStart", value) end,
										},
										space0 = { type = "description", name = "", order = 15 },
										FadeEnable = {
											type = "toggle", order = 16, name = L["Fade"], width = "half",
											desc = L["Enable fade effect when bar is started."],
											get = function(info) return GetBarGroupField("fade") end,
											set = function(info, value) SetBarGroupField("fade", value) end,
										},
										HideEnable = {
											type = "toggle", order = 17, name = L["Hide"], width = "half",
											desc = L["Enable hiding timer bars when started (does not hide bars with unlimited duration)."],
											get = function(info) return GetBarGroupField("hide") end,
											set = function(info, value) SetBarGroupField("hide", value) end,
										},
										Desaturate = {
											type = "toggle", order = 18, name = L["Desaturate"],
											desc = L["Desaturate icon when bar is started."],
											get = function(info) return GetBarGroupField("desatStart") end,
											set = function(info, value) SetBarGroupField("desatStart", value) end,
										},
										space1 = { type = "description", name = "", order = 20 },
										DelayTime = {
											type = "range", order = 26, name = L["Delay Time"], min = 0, max = 100, step = 1,
											desc = L["Set number of seconds to wait before showing start effects."],
											get = function(info) return GetBarGroupField("delayTime") or 0 end,
											set = function(info, value) SetBarGroupField("delayTime", value) end,
										},
										EffectTime = {
											type = "range", order = 27, name = L["Effect Time"], min = 0, max = 100, step = 1,
											desc = L["Set number of seconds to show start effects (set to 0 for unlimited time)."],
											get = function(info) return GetBarGroupField("startEffectTime") or 5 end,
											set = function(info, value) SetBarGroupField("startEffectTime", value) end,
										},
										space2 = { type = "description", name = "", order = 30 },
										SpellStartSound = {
											type = "toggle", order = 35, name = L["Start Spell Sound"],
											desc = L["Play associated spell sound, if any, when bar starts (spell sounds are set up on Spells tab)."],
											get = function(info) return GetBarGroupField("soundSpellStart") end,
											set = function(info, value) SetBarGroupField("soundSpellStart", value) end,
										},
										AltStartSound = {
											type = "select", order = 36, name = L["Alternative Start Sound"],
											desc = L["Select sound to play when there is no associated spell sound (or spell sound is not enabled)."],
											dialogControl = 'LSM30_Sound',
											values = AceGUIWidgetLSMlists.sound,
											get = function(info) return GetBarGroupField("soundAltStart") end,
											set = function(info, value) SetBarGroupField("soundAltStart", value) end,
										},
										ReplayEnable = {
											type = "toggle", order = 37, name = L["Replay"], width = "half",
											desc = L["Enable replay of start sound (after a specified amount of time) while bar is active."],
											get = function(info) return GetBarGroupField("replay") end,
											set = function(info, value) SetBarGroupField("replay", value) end,
										},
										ReplayDelay = {
											type = "range", order = 38, name = L["Replay Time"], min = 1, max = 60, step = 1,
											desc = L["Set number of seconds between replays of start sound."],
											get = function(info) return GetBarGroupField("replayTime") or 5 end,
											set = function(info, value) SetBarGroupField("replayTime", value) end,
										},
										space3 = { type = "description", name = "", order = 100 },
										CombatWarning = {
											type = "toggle", order = 101, name = L["Combat Text"],
											desc = L["Enable combat text when bar is started."],
											get = function(info) return GetBarGroupField("combatStart") end,
											set = function(info, value) SetBarGroupField("combatStart", value) end,
										},
										CombatColor = {
											type = "color", order = 102, name = L["Color"], hasAlpha = true, width = "half",
											desc = L["Set color for combat text."],
											disabled = function(info) return not GetBarGroupField("combatStart") end,
											get = function(info)
												local t = GetBarGroupField("combatColorStart"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("combatColorStart"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("combatColorStart", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										CombatCritical = {
											type = "toggle", order = 103, name = L["Critical"], width = "half",
											desc = L["Set combat text to show as critical."],
											disabled = function(info) return not GetBarGroupField("combatStart") end,
											get = function(info) return GetBarGroupField("combatCriticalStart") end,
											set = function(info, value) SetBarGroupField("combatCriticalStart", value) end,
										},
										space4 = { type = "description", name = " ", order = 120 },
										SelectByType = {
											type = "group", order = 200, name = L["Filters For Start Effects"],
											hidden = function(info) return not GetBarGroupField("auto") end,
											args = {
												All = {
													type = "toggle", order = 1, name = L["All"], width = "half",
													desc = L["Apply special effects to all bars when started."],
													get = function(info) return GetBarGroupField("selectAll") end,
													set = function(info, value) SetBarGroupField("selectAll", value) end,
												},
												Player = {
													type = "toggle", order = 2, name = L["Player"], width = "half",
													desc = L["Apply special effects to buffs and debuffs cast by the player."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectPlayer") end,
													set = function(info, value) SetBarGroupField("selectPlayer", value) end,
												},
												Pet = {
													type = "toggle", order = 3, name = L["Pet"], width = "half",
													desc = L["Apply special effects to buffs and debuffs cast by the player's pet."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectPet") end,
													set = function(info, value) SetBarGroupField("selectPet", value) end,
												},
												Boss = {
													type = "toggle", order = 4, name = L["Boss"], width = "half",
													desc = L["Apply special effects to buffs and debuffs cast by a boss."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectBoss") end,
													set = function(info, value) SetBarGroupField("selectBoss", value) end,
												},
												Dispel = {
													type = "toggle", order = 5, name = L["Dispel"], width = "half",
													desc = L["Apply special effects to debuffs that the player can dispel."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectDispel") end,
													set = function(info, value) SetBarGroupField("selectDispel", value) end,
												},
												Stealable = {
													type = "toggle", order = 6, name = L["Stealable"],
													desc = L["Apply special effects to buffs that the player can steal."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectSteal") end,
													set = function(info, value) SetBarGroupField("selectSteal", value) end,
												},
												space2 = { type = "description", name = "", order = 10 },
												Poison = {
													type = "toggle", order = 11, name = L["Poison"], width = "half",
													desc = L["Apply special effects to poison debuffs."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectPoison") end,
													set = function(info, value) SetBarGroupField("selectPoison", value) end,
												},
												Curse = {
													type = "toggle", order = 12, name = L["Curse"], width = "half",
													desc = L["Apply special effects to curse debuffs."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectCurse") end,
													set = function(info, value) SetBarGroupField("selectCurse", value) end,
												},
												Magic = {
													type = "toggle", order = 13, name = L["Magic"], width = "half",
													desc = L["Apply special effects to magic buffs and debuffs."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectMagic") end,
													set = function(info, value) SetBarGroupField("selectMagic", value) end,
												},
												Disease = {
													type = "toggle", order = 14, name = L["Disease"], width = "half",
													desc = L["Apply special effects to disease debuffs."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectDisease") end,
													set = function(info, value) SetBarGroupField("selectDisease", value) end,
												},
												Enrage = {
													type = "toggle", order = 15, name = L["Enrage"], width = "half",
													desc = L["Apply special effects to enrage buffs."],
													disabled = function(info) return GetBarGroupField("selectAll") end,
													get = function(info) return GetBarGroupField("selectEnrage") end,
													set = function(info, value) SetBarGroupField("selectEnrage", value) end,
												},
											},
										},
									},
								},
								ExpireTab = {
									type = "group", order = 30, name = L["Expire Effects"],
									hidden = function(info) return GetBarGroupField("disableBGSFX") end,
									args = {
										Shine = {
											type = "toggle", order = 10, name = L["Shine"], width = "half",
											desc = L["Enable shine effect when bar is expiring."],
											get = function(info) return GetBarGroupField("shineExpiring") end,
											set = function(info, value) SetBarGroupField("shineExpiring", value) end,
										},
										Sparkle = {
											type = "toggle", order = 11, name = L["Sparkle"], width = "half",
											desc = L["Enable sparkle effect when bar is expiring."],
											get = function(info) return GetBarGroupField("sparkleExpiring") end,
											set = function(info, value) SetBarGroupField("sparkleExpiring", value) end,
										},
										Pulse = {
											type = "toggle", order = 12, name = L["Pulse"], width = "half",
											desc = L["Enable icon pulse when bar is expiring."],
											get = function(info) return GetBarGroupField("pulseExpiring") end,
											set = function(info, value) SetBarGroupField("pulseExpiring", value) end,
										},
										Glow = {
											type = "toggle", order = 13, name = L["Glow"], width = "half",
											desc = L["Enable glow effect when bar is expiring."],
											get = function(info) return GetBarGroupField("glowExpiring") end,
											set = function(info, value) SetBarGroupField("glowExpiring", value) end,
										},
										Flash = {
											type = "toggle", order = 14, name = L["Flash"],
											desc = L["Enable flashing when bar is expiring."], width = "half",
											get = function(info) return GetBarGroupField("flashExpiring") end,
											set = function(info, value) SetBarGroupField("flashExpiring", value) end,
										},
										Desaturate = {
											type = "toggle", order = 15, name = L["Desaturate"],
											desc = L["Desaturate icon when bar is expiring."],
											get = function(info) return GetBarGroupField("desatExpiring") end,
											set = function(info, value) SetBarGroupField("desatExpiring", value) end,
										},
										space1 = { type = "description", name = "", order = 20 },
										ExpireTime = {
											type = "range", order = 25, name = L["Expire Time"], min = 0, max = 300, step = 0.1,
											desc = L["Set number of seconds before timer bar finishes to show expire effects."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") and not GetBarGroupField("shineExpiring") and
												not GetBarGroupField("flashExpiring") and not GetBarGroupField("glowExpiring") and not GetBarGroupField("pulseExpiring") and
												not GetBarGroupField("desatExpiring") and not GetBarGroupField("expireMSBT") and not GetBarGroupField("soundSpellExpire") and
												not (GetBarGroupField("soundAltExpire") and GetBarGroupField("soundAltExpire") ~= "None") end,
											get = function(info) return GetBarGroupField("flashTime") end,
											set = function(info, value) SetBarGroupField("flashTime", value) end,
										},
										ExpirePercentage = {
											type = "range", order = 26, name = L["Expire Percentage"], min = 0, max = 100, step = 1,
											desc = L["Set minimum percentage of duration for the Expire Time setting (use whichever is longer)."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") and not GetBarGroupField("shineExpiring") and
												not GetBarGroupField("flashExpire") and not GetBarGroupField("glowExpiring") and not GetBarGroupField("pulseExpiring") and
												not GetBarGroupField("desatExpiring") and not GetBarGroupField("expireMSBT") and not GetBarGroupField("soundSpellExpire") and
												not (GetBarGroupField("soundAltExpire") and GetBarGroupField("soundAltExpire") ~= "None") end,
											get = function(info) return GetBarGroupField("expirePercentage") or 0 end,
											set = function(info, value) SetBarGroupField("expirePercentage", value) end,
										},
										MinimumTime = {
											type = "range", order = 27, name = L["Minimum Duration"], min = 0, max = 60, step = 0.1,
											desc = L["Set minimum duration in minutes required to trigger expire special effects."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") and not GetBarGroupField("shineExpiring") and
												not GetBarGroupField("flashExpire") and not GetBarGroupField("glowExpiring") and not GetBarGroupField("pulseExpiring") and
												not GetBarGroupField("desatExpiring") and not GetBarGroupField("expireMSBT") and not GetBarGroupField("soundSpellExpire") and
												not (GetBarGroupField("soundAltExpire") and GetBarGroupField("soundAltExpire") ~= "None") end,
											get = function(info) return (GetBarGroupField("expireMinimum") or 0) / 60 end,
											set = function(info, value) if value == 0 then value = nil else value = value * 60 end
												SetBarGroupField("expireMinimum", value) end,
										},
										space1a = { type = "description", name = "", order = 30 },
										SpellExpireTimeOverride = {
											type = "toggle", order = 31, name = L["Use Spell Expire Time"],
											desc = L["Use spell's expire time when set on the Spells tab."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") and not GetBarGroupField("shineExpiring") and
												not GetBarGroupField("flashExpire") and not GetBarGroupField("glowExpiring") and not GetBarGroupField("pulseExpiring") and
												not GetBarGroupField("desatExpiring") and not GetBarGroupField("expireMSBT") and not GetBarGroupField("soundSpellExpire") and
												not (GetBarGroupField("soundAltExpire") and GetBarGroupField("soundAltExpire") ~= "None") end,
											get = function(info) return not GetBarGroupField("spellExpireTimes") end,
											set = function(info, value) SetBarGroupField("spellExpireTimes", not value) end,
										},
										SpellExpireColorOverride = {
											type = "toggle", order = 32, name = L["Use Spell Expire Color"],
											desc = L["Use spell's expire color when set on the Spells tab."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") and not GetBarGroupField("shineExpiring") and
												not GetBarGroupField("flashExpire") and not GetBarGroupField("glowExpiring") and not GetBarGroupField("pulseExpiring") and
												not GetBarGroupField("desatExpiring") and not GetBarGroupField("expireMSBT") and not GetBarGroupField("soundSpellExpire") and
												not (GetBarGroupField("soundAltExpire") and GetBarGroupField("soundAltExpire") ~= "None") end,
											get = function(info) return GetBarGroupField("spellExpireColors") end,
											set = function(info, value) SetBarGroupField("spellExpireColors", value) end,
										},
										space2 = { type = "description", name = "", order = 40 },
										ColorExpiring = {
											type = "toggle", order = 45, name = L["Expire Colors"],
											desc = L["Enable color changes for expiring bars."],
											get = function(info) return GetBarGroupField("colorExpiring") end,
											set = function(info, value) SetBarGroupField("colorExpiring", value) end,
										},
										ExpireColor = {
											type = "color", order = 46, name = L["Bar"], hasAlpha = true, width = "half",
											desc = L["Set bar color for when about to expire (set invisible opacity to disable color change)."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") end,
											get = function(info)
												local t = GetBarGroupField("expireColor"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("expireColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("expireColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										LabelTextColor = {
											type = "color", order = 47, name = L["Label"], hasAlpha = true, width = "half",
											desc = L["Set label color for when bar is about to expire (set invisible opacity to disable color change)."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") end,
											get = function(info)
												local t = GetBarGroupField("expireLabelColor"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 0 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("expireLabelColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("expireLabelColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										TimeTextColor = {
											type = "color", order = 48, name = L["Time"], hasAlpha = true, width = "half",
											desc = L["Set time color for when bar is about to expire (set invisible opacity to disable color change)."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") end,
											get = function(info)
												local t = GetBarGroupField("expireTimeColor"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 0 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("expireTimeColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("expireTimeColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										TickColor = {
											type = "color", order = 49, name = L["Tick"], hasAlpha = true, width = "half",
											desc = L["Set color for expire time tick (set invisible opacity to disable showing tick on bar)."],
											disabled = function(info) return not GetBarGroupField("colorExpiring") end,
											get = function(info)
												local t = GetBarGroupField("tickColor"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 0 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("tickColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("tickColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										space3 = { type = "description", name = "", order = 60 },
										SpellExpireSound = {
											type = "toggle", order = 61, name = L["Expire Spell Sound"],
											desc = L["Play associated spell sound, if any, when bar is about to expire (spell sounds are set up on Spells tab)."],
											get = function(info) return GetBarGroupField("soundSpellExpire") end,
											set = function(info, value) SetBarGroupField("soundSpellExpire", value) end,
										},
										AltExpireSound = {
											type = "select", order = 62, name = L["Alternative Expire Sound"],
											desc = L["Select sound to play when there is no associated spell sound (or spell sound is not enabled)."],
											dialogControl = 'LSM30_Sound',
											values = AceGUIWidgetLSMlists.sound,
											get = function(info) return GetBarGroupField("soundAltExpire") end,
											set = function(info, value) SetBarGroupField("soundAltExpire", value) end,
										},
										space7 = { type = "description", name = "", order = 100 },
										CombatWarning = {
											type = "toggle", order = 101, name = L["Combat Text"],
											desc = L["Enable combat text when bar is started."],
											get = function(info) return GetBarGroupField("expireMSBT") end,
											set = function(info, value) SetBarGroupField("expireMSBT", value) end,
										},
										CombatColor = {
											type = "color", order = 102, name = L["Color"], hasAlpha = true, width = "half",
											desc = L["Set color for combat text."],
											disabled = function(info) return not GetBarGroupField("expireMSBT") end,
											get = function(info)
												local t = GetBarGroupField("colorMSBT"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("colorMSBT"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("colorMSBT", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										CombatCritical = {
											type = "toggle", order = 103, name = L["Critical"], width = "half",
											desc = L["Set combat text to show as critical."],
											disabled = function(info) return not GetBarGroupField("expireMSBT") end,
											get = function(info) return GetBarGroupField("criticalMSBT") end,
											set = function(info, value) SetBarGroupField("criticalMSBT", value) end,
										},
									},
								},
								FinishTab = {
									type = "group", order = 40, name = L["Finish Effects"],
									hidden = function(info) return GetBarGroupField("disableBGSFX") end,
									args = {
										ShineEnd = {
											type = "toggle", order = 10, name = L["Shine"], width = "half",
											desc = L["Enable shine effect when bar is finishing."],
											get = function(info) return GetBarGroupField("shineEnd") end,
											set = function(info, value) SetBarGroupField("shineEnd", value) end,
										},
										SparkleEnd = {
											type = "toggle", order = 11, name = L["Sparkle"], width = "half",
											desc = L["Enable sparkle effect when bar is finishing."],
											get = function(info) return GetBarGroupField("sparkleEnd") end,
											set = function(info, value) SetBarGroupField("sparkleEnd", value) end,
										},
										PulseEnd = {
											type = "toggle", order = 12, name = L["Pulse"], width = "half",
											desc = L["Enable icon pulse when bar is finishing."],
											get = function(info) return GetBarGroupField("pulseEnd") end,
											set = function(info, value) SetBarGroupField("pulseEnd", value) end,
										},
										SplashEnd = {
											type = "toggle", order = 13, name = L["Splash"], width = "half",
											desc = L["Enable splash effect when bar is finished."],
											get = function(info) return GetBarGroupField("splash") end,
											set = function(info, value) SetBarGroupField("splash", value) end,
										},
										GhostEnable = {
											type = "toggle", order = 14, name = L["Ghost"], width = "half",
											desc = L["Enable ghost effect when bar is finished (i.e., continue to show after would normally disappear)."],
											get = function(info) return GetBarGroupField("ghost") end,
											set = function(info, value) SetBarGroupField("ghost", value) end,
										},
										space1 = { type = "description", name = "", order = 20 },
										EffectTime = {
											type = "range", order = 25, name = L["Effect Time"], min = 1, max = 100, step = 1,
											desc = L["Set number of seconds to show special effects at finish."],
											disabled = function(info) return not GetBarGroupField("ghost") end,
											get = function(info) return GetBarGroupField("endEffectTime") or 5 end,
											set = function(info, value) SetBarGroupField("endEffectTime", value) end,
										},
										space2 = { type = "description", name = "", order = 30 },
										SpellEndSound = {
											type = "toggle", order = 35, name = L["Finish Spell Sound"],
											desc = L["Play associated spell sound, if any, when bar finishes (spell sounds are set up on Spells tab)."],
											get = function(info) return GetBarGroupField("soundSpellEnd") end,
											set = function(info, value) SetBarGroupField("soundSpellEnd", value) end,
										},
										AltEndSound = {
											type = "select", order = 36, name = L["Alternative Finish Sound"],
											desc = L["Select sound to play when there is no associated spell sound (or spell sound is not enabled)."],
											dialogControl = 'LSM30_Sound',
											values = AceGUIWidgetLSMlists.sound,
											get = function(info) return GetBarGroupField("soundAltEnd") end,
											set = function(info, value) SetBarGroupField("soundAltEnd", value) end,
										},
										space3 = { type = "description", name = "", order = 100 },
										CombatWarning = {
											type = "toggle", order = 101, name = L["Combat Text"],
											desc = L["Enable combat text when bar is finished."],
											get = function(info) return GetBarGroupField("combatEnd") end,
											set = function(info, value) SetBarGroupField("combatEnd", value) end,
										},
										CombatColor = {
											type = "color", order = 102, name = L["Color"], hasAlpha = true, width = "half",
											desc = L["Set color for combat text."],
											disabled = function(info) return not GetBarGroupField("combatEnd") end,
											get = function(info)
												local t = GetBarGroupField("combatColorEnd"); if t then return t.r, t.g, t.b, t.a else return 1, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("combatColorEnd"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("combatColorEnd", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										CombatCritical = {
											type = "toggle", order = 103, name = L["Critical"], width = "half",
											desc = L["Set combat text to show as critical."],
											disabled = function(info) return not GetBarGroupField("combatEnd") end,
											get = function(info) return GetBarGroupField("combatCriticalEnd") end,
											set = function(info, value) SetBarGroupField("combatCriticalEnd", value) end,
										},
									},
								},
								CustomizationTab = {
									type = "group", order = 50, name = L["Customize"], inline = true,
									hidden = function(info) return GetBarGroupField("disableBGSFX") end,
									args = {
										EnableBGSFXCustomization = {
											type = "toggle", order = 1, name = L["Enable"], width = "half",
											desc = L["If checked, enable customization of special effects for this bar group."],
											get = function(info) return GetBarGroupField("customizeSFX") end,
											set = function(info, value) SetBarGroupField("customizeSFX", value) end,
										},
										space0 = { type = "description", name = "", order = 10, hidden = function(info) return not GetBarGroupField("customizeSFX") end, },
										ShineColor = {
											type = "color", order = 20, name = L["Shine"], hasAlpha = false, width = "half",
											desc = L["Set color for shine effects."],
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											get = function(info)
												local t = GetBarGroupField("shineColor"); if t then return t.r, t.g, t.b else return 1, 1, 1 end
											end,
											set = function(info, r, g, b)
												local t = GetBarGroupField("shineColor"); if t then t.r = r; t.g = g; t.b = b else
													t = { r = r, g = g, b = b }; SetBarGroupField("shineColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										SparkleColor = {
											type = "color", order = 21, name = L["Sparkle"], hasAlpha = false, width = "half",
											desc = L["Set color for sparkle effects."],
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											get = function(info)
												local t = GetBarGroupField("sparkleColor"); if t then return t.r, t.g, t.b else return 1, 1, 1 end
											end,
											set = function(info, r, g, b)
												local t = GetBarGroupField("sparkleColor"); if t then t.r = r; t.g = g; t.b = b else
													t = { r = r, g = g, b = b }; SetBarGroupField("sparkleColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										GlowColor = {
											type = "color", order = 22, name = L["Glow"], hasAlpha = false, width = "half",
											desc = L["Set color for glow effects."],
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											get = function(info)
												local t = GetBarGroupField("glowColor"); if t then return t.r, t.g, t.b else return 1, 1, 1 end
											end,
											set = function(info, r, g, b)
												local t = GetBarGroupField("glowColor"); if t then t.r = r; t.g = g; t.b = b else
													t = { r = r, g = g, b = b }; SetBarGroupField("glowColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										space1 = { type = "description", name = "", order = 30, hidden = function(info) return not GetBarGroupField("customizeSFX") end, },
										FlashPeriod = {
											type = "range", order = 31, name = L["Flash Period"], min = 0.5, max = 5, step = 0.1,
											desc = L["Set number of seconds for period to be used in flash effects."],
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											get = function(info) return GetBarGroupField("flashPeriod") or 1.2 end,
											set = function(info, value) SetBarGroupField("flashPeriod", value) end,
										},
										FlashPercent = {
											type = "range", order = 32, name = L["Flash Percentage"], min = 1, max = 100, step = 1,
											desc = L["Set minimum opacity during flash effects as percentage of bar's current opacity."],
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											get = function(info) return GetBarGroupField("flashPercent") or 50 end,
											set = function(info, value) SetBarGroupField("flashPercent", value) end,
										},
										space2 = { type = "description", name = "", order = 40, hidden = function(info) return not GetBarGroupField("customizeSFX") end, },
										ExpireFGBGColor = {
											type = "toggle", order = 41, name = L["Expire Bar Color Only Changes Foreground"], width = "full",
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											desc = L["If checked, expire bar color effect only changes foreground color, otherwise it changes both foreground and background colors."],
											get = function(info) return not GetBarGroupField("expireFGBG") end,
											set = function(info, value) SetBarGroupField("expireFGBG", not value) end,
										},
										space3 = { type = "description", name = "", order = 50, hidden = function(info) return not GetBarGroupField("customizeSFX") end, },
										CombatTextFormat = {
											type = "toggle", order = 51, name = L["Combat Text Includes Bar Group"], width = "full",
											hidden = function(info) return not GetBarGroupField("customizeSFX") end,
											desc = L["If checked, combat text includes the name of the bar group."],
											get = function(info) return not GetBarGroupField("combatTextExcludesBG") end,
											set = function(info, value) SetBarGroupField("combatTextExcludesBG", not value) end,
										},
									},
								},
							},
						},
						OptionsGroup = {
							type = "group", order = 40, name = L["Miscellaneous Options"], inline = true,
							hidden = function(info) return GetBarGroupField("merged") end,
							args = {
								TooltipAnchor = {
									type = "select", order = 15, name = L["Tooltip Anchor"],
									desc = L["Tooltip anchor string"],
									disabled = function(info) return GetBarGroupField("noMouse") end,
									get = function(info) return GetBarGroupField("anchorTips") end,
									set = function(info, value) SetBarGroupField("anchorTips", value) end,
									values = function(info) return anchorTips end,
									style = "dropdown",
								},
								NoMouse = {
									type = "toggle", order = 35, name = L["Non-Interactive"],
									desc = L["If checked, the bar group is non-interactive and doesn't show tooltips or respond to clicks. Tooltips must also be enabled in the bar group's Format settings."],
									get = function(info) return GetBarGroupField("noMouse") end,
									set = function(info, value) SetBarGroupField("noMouse", value) end,
								},
								BarOrIcon = {
									type = "toggle", order = 40, name = L["Only Icons Interact"],
									desc = L["If checked, only icons show tooltips and respond to clicks, otherwise entire bar does. Tooltips must also be enabled in the bar group's Format settings."],
									disabled = function(info) return GetBarGroupField("noMouse") end,
									get = function(info) return GetBarGroupField("iconMouse") end,
									set = function(info, value) SetBarGroupField("iconMouse", value) end,
								},
								CombatTooltips = {
									type = "toggle", order = 45, name = L["Combat Tooltips"],
									desc = L["If checked, tooltips are shown during combat. Tooltips must also be enabled in the bar group's Format settings."],
									disabled = function(info) return GetBarGroupField("noMouse") end,
									get = function(info) return GetBarGroupField("combatTips") end,
									set = function(info, value) SetBarGroupField("combatTips", value) end,
								},
								Space3 = { type = "description", name = "", order = 48 },
								Headers = {
									type = "toggle", order = 50, name = L["Show Headers"],
									hidden = function(info) return not GetBarGroupField("auto") end,
									desc = L["When showing all buffs or debuffs cast by player, add headers for each affected target."],
									get = function(info) return not GetBarGroupField("noHeaders") end,
									set = function(info, value) SetBarGroupField("noHeaders", not value) end,
								},
								TargetFirst = {
									type = "toggle", order = 60, name = L["Sort Target First"],
									hidden = function(info) return not GetBarGroupField("auto") end,
									desc = L["When showing all buffs or debuffs cast by player, sort ones for target first."],
									get = function(info) return GetBarGroupField("targetFirst") end,
									set = function(info, value) SetBarGroupField("targetFirst", value) end,
								},
								TargetAlpha = {
									type = "range", order = 65, name = L["Non-Target Opacity"], min = 0, max = 1, step = 0.05,
									hidden = function(info) return not GetBarGroupField("auto") end,
									desc = L["When showing all buffs or debuffs cast by player, set opacity for ones not on target."],
									get = function(info) return GetBarGroupField("targetAlpha") end,
									set = function(info, value) SetBarGroupField("targetAlpha", value) end,
								},
								TargetNames = {
									type = "toggle", order = 70, name = L["Targets"], width = "half",
									hidden = function(info) return not GetBarGroupField("auto") end,
									disabled = function(info) return not GetBarGroupField("noHeaders") end,
									desc = L["When showing all buffs or debuffs cast by player without headers, show target names in labels."],
									get = function(info) return not GetBarGroupField("noTargets") end,
									set = function(info, value) SetBarGroupField("noTargets", not value) end,
								},
								SpellNames = {
									type = "toggle", order = 75, name = L["Spells"], width = "half",
									hidden = function(info) return not GetBarGroupField("auto") end,
									disabled = function(info) return not GetBarGroupField("noHeaders") end,
									desc = L["When showing all buffs or debuffs cast by player without headers, show spell names in labels."],
									get = function(info) return not GetBarGroupField("noLabels") end,
									set = function(info, value) SetBarGroupField("noLabels", not value) end,
								},
								HeaderSpacing = {
									type = "toggle", order = 77, name = L["Spacing"], width = "half",
									hidden = function(info) return not GetBarGroupField("auto") end,
									disabled = function(info) return not GetBarGroupField("noHeaders") end,
									desc = L["When showing all buffs or debuffs cast by player without headers, keep spacing between groups."],
									get = function(info) return GetBarGroupField("headerGaps") end,
									set = function(info, value) SetBarGroupField("headerGaps", value) end,
								},
								space4 = { type = "description", name = "", order = 80 },
								ReverseDirection = {
									type = "toggle", order = 82, name = L["Clock Direction"],
									desc = L["Set empty/fill direction for clock animations on icons."],
									get = function(info) return GetBarGroupField("clockReverse") end,
									set = function(info, value) SetBarGroupField("clockReverse", value) end,
								},
								KongAlpha = {
									type = "toggle", order = 85, name = L["External Fader"],
									desc = L["Support external fader addons by disabling bar group opacity options (requires /reload)."],
									get = function(info) return GetBarGroupField("disableAlpha") end,
									set = function(info, value) SetBarGroupField("disableAlpha", value) end,
								},
								ShowSpell = {
									type = "toggle", order = 88, name = L["Spell ID"],
									desc = L["If checked, holding down control and alt keys will add spell ID to tooltips when known."],
									get = function(info) return GetBarGroupField("spellTips") end,
									set = function(info, value) SetBarGroupField("spellTips", value) end,
								},
								ShowCaster = {
									type = "toggle", order = 90, name = L["Caster"],
									desc = L["If checked, tooltips include caster for buffs and debuffs when known."],
									get = function(info) return GetBarGroupField("casterTips") end,
									set = function(info, value) SetBarGroupField("casterTips", value) end,
								},
							},
						},
					},
				},
				BarTab = {
					type = "group", order = 15, name = L["Custom Bars"],
					hidden = function(info) return NoBarGroup() or GetBarGroupField("auto") end,
					args = {
						NewBarButton = {
							type = "execute", order = 1, name = L["New"], width = "half",
							desc = L["Create a new bar."],
							disabled = function(info) return InMode("Bar") end,
							func = function(info) EnterNewBar("start") end,
						},
						DeleteBar = {
							type = "execute", order = 2, name = L["Delete"], width = "half",
							desc = L["Delete the selected bar."],
							disabled = function(info) return NoBar() end,
							func = function(info) DeleteBar() end,
							confirm = function(info) return L['DELETE BAR\nAre you sure you want to delete the selected bar?'] end,
						},
						-- Bars get plugged in here, with order starting at 10
					},
				},
				DetectBuffsTab = {
					type = "group", order = 20, name = L["Buffs"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() or not GetBarGroupField("auto") end,
					args = {
						EnableGroup = {
							type = "group", order = 1, name = L["Enable"], inline = true,
							args = {
								DetectEnable = {
									type = "toggle", order = 1, name = L["Auto Buffs"],
									desc = L['Enable automatically displaying bars for buffs that match these settings.'],
									get = function(info) return GetBarGroupField("detectBuffs") end,
									set = function(info, value) SetBarGroupField("detectBuffs", value) end,
								},
								AnyCastByPlayer = {
									type = "toggle", order = 5, name = L["All Cast By Player"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") end,
									desc = L['Include all buffs cast by player on others.'],
									get = function(info) return GetBarGroupField("detectAllBuffs") end,
									set = function(info, value) SetBarGroupField("detectAllBuffs", value) end,
								},
								IncludeTotems = {
									type = "toggle", order = 10, name = L["Include Totems"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") end,
									hidden = function(info) return MOD.myClass ~= "SHAMAN" end,
									desc = L['Include active totems as buffs.'],
									get = function(info) return GetBarGroupField("includeTotems") end,
									set = function(info, value) SetBarGroupField("includeTotems", value) end,
								},
							},
						},
						MonitorUnitGroup = {
							type = "group", order = 10, name = L["Action On"], inline = true,
							hidden = function(info) return GetBarGroupField("detectAllBuffs") end,
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								PlayerBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, only add bars for buffs if they are on the player."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "player" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "player") end,
								},
								PetBuff = {
									type = "toggle", order = 15, name = L["Pet"],
									desc = L["If checked, only add bars for buffs if they are on the player's pet."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "pet" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "pet") end,
								},
								TargetBuff = {
									type = "toggle", order = 20, name = L["Target"],
									desc = L["If checked, only add bars for buffs if they are on the target."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "target" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "target") end,
								},
								FocusBuff = {
									type = "toggle", order = 30, name = L["Focus"],
									desc = L["If checked, only add bars for buffs if they are on the focus."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "focus" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "focus") end,
								},
								Space1 = { type = "description", name = "", order = 35 },
								MouseoverBuff = {
									type = "toggle", order = 40, name = L["Mouseover"],
									desc = L["If checked, only add bars for buffs if they are on the mouseover unit."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "mouseover" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "mouseover") end,
								},
								PetTargetBuff = {
									type = "toggle", order = 45, name = L["Pet's Target"],
									desc = L["If checked, only add bars for buffs if they are on the pet's target."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "pettarget" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "pettarget") end,
								},
								TargetTargetBuff = {
									type = "toggle", order = 50, name = L["Target's Target"],
									desc = L["If checked, only add bars for buffs if they are on the target's target."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "targettarget" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "targettarget") end,
								},
								FocusTargetBuff = {
									type = "toggle", order = 60, name = L["Focus's Target"],
									desc = L["If checked, only add bars for buffs if they are on the focus's target."],
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "focustarget" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "focustarget") end,
								},
								Space2 = { type = "description", name = "", order = 65, hidden = function(info) return not MOD.db.global.IncludePartyUnits end },
								Party1Buff = {
									type = "toggle", order = 66, name = L["Party1"],
									desc = L["If checked, only add bars for buffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "party1" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "party1") end,
								},
								Party2Buff = {
									type = "toggle", order = 67, name = L["Party2"],
									desc = L["If checked, only add bars for buffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "party2" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "party2") end,
								},
								Party3Buff = {
									type = "toggle", order = 68, name = L["Party3"],
									desc = L["If checked, only add bars for buffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "party3" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "party3") end,
								},
								Party4Buff = {
									type = "toggle", order = 69, name = L["Party4"],
									desc = L["If checked, only add bars for buffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "party4" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "party4") end,
								},
								Space3 = { type = "description", name = "", order = 70, hidden = function(info) return not MOD.db.global.IncludeBossUnits end },
								Boss1Buff = {
									type = "toggle", order = 71, name = L["Boss1"],
									desc = L["If checked, only add bars for buffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "boss1" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "boss1") end,
								},
								Boss2Buff = {
									type = "toggle", order = 72, name = L["Boss2"],
									desc = L["If checked, only add bars for buffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "boss2" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "boss2") end,
								},
								Boss3Buff = {
									type = "toggle", order = 73, name = L["Boss3"],
									desc = L["If checked, only add bars for buffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "boss3" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "boss3") end,
								},
								Boss4Buff = {
									type = "toggle", order = 74, name = L["Boss4"],
									desc = L["If checked, only add bars for buffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "boss4" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "boss4") end,
								},
								Boss5Buff = {
									type = "toggle", order = 75, name = L["Boss5"], width = "half",
									desc = L["If checked, only add bars for buffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "boss5" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "boss5") end,
								},
								Space4 = { type = "description", name = "", order = 80, hidden = function(info) return not MOD.db.global.IncludeArenaUnits end },
								Arena1Buff = {
									type = "toggle", order = 81, name = L["Arena1"],
									desc = L["If checked, only add bars for buffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "arena1" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "arena1") end,
								},
								Arena2Buff = {
									type = "toggle", order = 82, name = L["Arena2"],
									desc = L["If checked, only add bars for buffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "arena2" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "arena2") end,
								},
								Arena3Buff = {
									type = "toggle", order = 83, name = L["Arena3"],
									desc = L["If checked, only add bars for buffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "arena3" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "arena3") end,
								},
								Arena4Buff = {
									type = "toggle", order = 84, name = L["Arena4"],
									desc = L["If checked, only add bars for buffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "arena4" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "arena4") end,
								},
								Arena5Buff = {
									type = "toggle", order = 85, name = L["Arena5"], width = "half",
									desc = L["If checked, only add bars for buffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectBuffsMonitor") == "arena5" end,
									set = function(info, value) SetBarGroupField("detectBuffsMonitor", "arena5") end,
								},
							},
						},
						ExcludeUnitGroup = {
							type = "group", order = 15, name = L["Exclude On"], inline = true,
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								PlayerBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, exclude buffs if they are on the player."],
									get = function(info) return GetBarGroupField("noPlayerBuffs") end,
									set = function(info, value) SetBarGroupField("noPlayerBuffs", value) end,
								},
								PetBuff = {
									type = "toggle", order = 15, name = L["Pet"],
									desc = L["If checked, exclude buffs if they are on the player's pet."],
									get = function(info) return GetBarGroupField("noPetBuffs") end,
									set = function(info, value) SetBarGroupField("noPetBuffs", value) end,
								},
								TargetBuff = {
									type = "toggle", order = 20, name = L["Target"],
									desc = L["If checked, exclude buffs if they are on the target."],
									get = function(info) return GetBarGroupField("noTargetBuffs") end,
									set = function(info, value) SetBarGroupField("noTargetBuffs", value) end,
								},
								FocusBuff = {
									type = "toggle", order = 30, name = L["Focus"],
									desc = L["If checked, exclude buffs if they are on the focus."],
									get = function(info) return GetBarGroupField("noFocusBuffs") end,
									set = function(info, value) SetBarGroupField("noFocusBuffs", value) end,
								},
							},
						},
						CastUnitGroup = {
							type = "group", order = 20, name = L["Cast By"], inline = true, width = "full",
							hidden = function(info) return GetBarGroupField("detectAllBuffs") end,
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								MyBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, only add bars for buffs if cast by the player."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "player" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "player") end,
								},
								PetBuff = {
									type = "toggle", order = 15, name = L["Pet"],
									desc = L["If checked, only add bars for buffs if cast by the player's pet."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "pet" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "pet") end,
								},
								TargetBuff = {
									type = "toggle", order = 20, name = L["Target"],
									desc = L["If checked, only add bars for buffs if cast by the target."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "target" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "target") end,
								},
								FocusBuff = {
									type = "toggle", order = 25, name = L["Focus"],
									desc = L["If checked, only add bars for buffs if cast by the focus."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "focus" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "focus") end,
								},
								OurBuff = {
									type = "toggle", order = 27, name = L["Player Or Pet"],
									desc = L["If checked, only add bars for buffs if cast by player or pet."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "ours" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "ours") end,
								},
								YourBuff = {
									type = "toggle", order = 30, name = L["Other"],
									desc = L["If checked, only add bars for buffs if cast by anyone other than the player or pet."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "other" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "other") end,
								},
								AnyBuff = {
									type = "toggle", order = 35, name = L["Anyone"],
									desc = L["If checked, add bars for buffs if cast by anyone, including player."],
									get = function(info) return GetBarGroupField("detectBuffsCastBy") == "anyone" end,
									set = function(info, value) SetBarGroupField("detectBuffsCastBy", "anyone") end,
								},
							},
						},
						IncludeByType = {
							type = "group", order = 30, name = L["Include By Type"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Include buff types string"],
									get = function(info) return GetBarGroupField("detectBuffTypes") end,
									set = function(info, v) SetBarGroupField("detectBuffTypes", v) end,
								},
								Castable = {
									type = "toggle", order = 15, name = L["Castable"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs that the player can cast.'],
									get = function(info) return GetBarGroupField("detectCastable") end,
									set = function(info, value) SetBarGroupField("detectCastable", value) end,
								},
								Stealable = {
									type = "toggle", order = 20, name = L["Stealable"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs that mages can spellsteal.'],
									get = function(info) return GetBarGroupField("detectStealable") end,
									set = function(info, value) SetBarGroupField("detectStealable", value) end,
								},
								Magic = {
									type = "toggle", order = 30, name = L["Magic"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include magic buffs but not those considered stealable (magic buffs can usually be removed with abilities like Purge).'],
									get = function(info) return GetBarGroupField("detectMagicBuffs") end,
									set = function(info, value) SetBarGroupField("detectMagicBuffs", value) end,
								},
								CastByNPC = {
									type = "toggle", order = 35, name = L["NPC"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs cast by an NPC (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("detectNPCBuffs") end,
									set = function(info, value) SetBarGroupField("detectNPCBuffs", value) end,
								},
								CastByVehicle = {
									type = "toggle", order = 40, name = L["Vehicle"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs cast by a vehicle (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("detectVehicleBuffs") end,
									set = function(info, value) SetBarGroupField("detectVehicleBuffs", value) end,
								},
								Boss = {
									type = "toggle", order = 42, name = L["Boss"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs cast by boss.'],
									get = function(info) return GetBarGroupField("detectBossBuffs") end,
									set = function(info, value) SetBarGroupField("detectBossBuffs", value) end,
								},
								Enrage = {
									type = "toggle", order = 43, name = L["Enrage"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include enrage buffs.'],
									get = function(info) return GetBarGroupField("detectEnrageBuffs") end,
									set = function(info, value) SetBarGroupField("detectEnrageBuffs", value) end,
								},
								Effects = {
									type = "toggle", order = 45, name = L["Effect Timers"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Include buffs from effect timers triggered by a spell cast."],
									get = function(info) return GetBarGroupField("detectEffectBuffs") end,
									set = function(info, value) SetBarGroupField("detectEffectBuffs", value) end,
								},
								Alerts = {
									type = "toggle", order = 47, name = L["Spell Alerts"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Include buffs from spell alerts."],
									get = function(info) return GetBarGroupField("detectAlertBuffs") end,
									set = function(info, value) SetBarGroupField("detectAlertBuffs", value) end,
								},
								Weapons = {
									type = "toggle", order = 50, name = L["Weapon Buffs"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Include weapon buffs."],
									get = function(info) return GetBarGroupField("detectWeaponBuffs") end,
									set = function(info, value) SetBarGroupField("detectWeaponBuffs", value) end,
								},
								Tracking = {
									type = "toggle", order = 55, name = L["Tracking"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Include tracking buffs."],
									get = function(info) return GetBarGroupField("detectTracking") end,
									set = function(info, value) SetBarGroupField("detectTracking", value) end,
								},
								Resources = {
									type = "toggle", order = 56, name = L["Resources"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Include buffs for resources (e.g., monk's Chi)."],
									get = function(info) return GetBarGroupField("detectResources") end,
									set = function(info, value) SetBarGroupField("detectResources", value) end,
								},
								Mounts = {
									type = "toggle", order = 57, name = L["Mounts"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Include mount buffs."],
									get = function(info) return GetBarGroupField("detectMountBuffs") end,
									set = function(info, value) SetBarGroupField("detectMountBuffs", value) end,
								},
								Tabard = {
									type = "toggle", order = 58, name = L["Tabard"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs from equipped tabard (player only).'],
									get = function(info) return GetBarGroupField("detectTabardBuffs") end,
									set = function(info, value) SetBarGroupField("detectTabardBuffs", value) end,
								},
								Minion = {
									type = "toggle", order = 59, name = L["Minions"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include timers for warlock minions (player only).'],
									get = function(info) return GetBarGroupField("detectMinionBuffs") end,
									set = function(info, value) SetBarGroupField("detectMinionBuffs", value) end,
								},
								Other = {
									type = "toggle", order = 60, name = L["Other"],
									disabled = function(info) return not GetBarGroupField("detectBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Include buffs not selected by other types.'],
									get = function(info) return GetBarGroupField("detectOtherBuffs") end,
									set = function(info, value) SetBarGroupField("detectOtherBuffs", value) end,
								},
							},
						},
						ExcludeByType = {
							type = "group", order = 35, name = L["Exclude By Type"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Exclude buff types string"],
									get = function(info) return GetBarGroupField("excludeBuffTypes") end,
									set = function(info, v) SetBarGroupField("excludeBuffTypes", v) end,
								},
								Castable = {
									type = "toggle", order = 15, name = L["Castable"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs that the player can cast.'],
									get = function(info) return GetBarGroupField("excludeCastable") end,
									set = function(info, value) SetBarGroupField("excludeCastable", value) end,
								},
								Stealable = {
									type = "toggle", order = 20, name = L["Stealable"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs that mages can spellsteal.'],
									get = function(info) return GetBarGroupField("excludeStealable") end,
									set = function(info, value) SetBarGroupField("excludeStealable", value) end,
								},
								Magic = {
									type = "toggle", order = 30, name = L["Magic"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude magic buffs except those considered stealable.'],
									get = function(info) return GetBarGroupField("excludeMagicBuffs") end,
									set = function(info, value) SetBarGroupField("excludeMagicBuffs", value) end,
								},
								CastByNPC = {
									type = "toggle", order = 35, name = L["NPC"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs cast by an NPC (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("excludeNPCBuffs") end,
									set = function(info, value) SetBarGroupField("excludeNPCBuffs", value) end,
								},
								CastByVehicle = {
									type = "toggle", order = 40, name = L["Vehicle"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs cast by a vehicle (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("excludeVehicleBuffs") end,
									set = function(info, value) SetBarGroupField("excludeVehicleBuffs", value) end,
								},
								Boss = {
									type = "toggle", order = 42, name = L["Boss"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs cast by boss.'],
									get = function(info) return GetBarGroupField("excludeBossBuffs") end,
									set = function(info, value) SetBarGroupField("excludeBossBuffs", value) end,
								},
								Enrage = {
									type = "toggle", order = 43, name = L["Enrage"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude enrage buffs.'],
									get = function(info) return GetBarGroupField("excludeEnrageBuffs") end,
									set = function(info, value) SetBarGroupField("excludeEnrageBuffs", value) end,
								},
								Effects = {
									type = "toggle", order = 45, name = L["Effect Timers"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Exclude buffs from effect timers triggered by a spell cast."],
									get = function(info) return GetBarGroupField("excludeEffectBuffs") end,
									set = function(info, value) SetBarGroupField("excludeEffectBuffs", value) end,
								},
								Alerts = {
									type = "toggle", order = 47, name = L["Spell Alerts"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Exclude buffs from spell alerts."],
									get = function(info) return GetBarGroupField("excludeAlertBuffs") end,
									set = function(info, value) SetBarGroupField("excludeAlertBuffs", value) end,
								},
								Weapons = {
									type = "toggle", order = 50, name = L["Weapon Buffs"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Exclude weapon buffs."],
									get = function(info) return GetBarGroupField("excludeWeaponBuffs") end,
									set = function(info, value) SetBarGroupField("excludeWeaponBuffs", value) end,
								},
								Tracking = {
									type = "toggle", order = 55, name = L["Tracking"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Exclude tracking buffs."],
									get = function(info) return GetBarGroupField("excludeTracking") end,
									set = function(info, value) SetBarGroupField("excludeTracking", value) end,
								},
								Resources = {
									type = "toggle", order = 56, name = L["Resources"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Exclude buffs for resources (e.g., monk's Chi)."],
									get = function(info) return GetBarGroupField("excludeResources") end,
									set = function(info, value) SetBarGroupField("excludeResources", value) end,
								},
								Mounts = {
									type = "toggle", order = 57, name = L["Mounts"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L["Exclude mount buffs."],
									get = function(info) return GetBarGroupField("excludeMountBuffs") end,
									set = function(info, value) SetBarGroupField("excludeMountBuffs", value) end,
								},
								Tabard = {
									type = "toggle", order = 58, name = L["Tabard"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs from equipped tabard (player only).'],
									get = function(info) return GetBarGroupField("excludeTabardBuffs") end,
									set = function(info, value) SetBarGroupField("excludeTabardBuffs", value) end,
								},
								Minion = {
									type = "toggle", order = 59, name = L["Minions"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude timers for warlock minions (player only).'],
									get = function(info) return GetBarGroupField("excludeMinionBuffs") end,
									set = function(info, value) SetBarGroupField("excludeMinionBuffs", value) end,
								},
								Other = {
									type = "toggle", order = 60, name = L["Other"],
									disabled = function(info) return not GetBarGroupField("excludeBuffTypes") or not GetBarGroupField("detectBuffs") end,
									desc = L['Exclude buffs not selected by other types.'],
									get = function(info) return GetBarGroupField("excludeOtherBuffs") end,
									set = function(info, value) SetBarGroupField("excludeOtherBuffs", value) end,
								},
							},
						},
						FilterGroup = {
							type = "group", order = 40, name = L["Filter List"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								BlackList = {
									type = "toggle", order = 10, name = L["Black List"],
									desc = L["If checked, don't display any buffs that are in the filter list."],
									get = function(info) return GetBarGroupField("filterBuff") end,
									set = function(info, v) SetBarGroupField("filterBuff", v); if v then SetBarGroupField("showBuff", false) end end,
								},
								WhiteList = {
									type = "toggle", order = 11, name = L["White List"],
									desc = L["If checked, only display buffs that are in the filter list."],
									get = function(info) return GetBarGroupField("showBuff") end,
									set = function(info, v) SetBarGroupField("showBuff", v); if v then SetBarGroupField("filterBuff", false) end  end,
								},
								Space0 = { type = "description", name = "", order = 14 },
								SpellList1 = {
									type = "toggle", order = 16, name = L["Spell List #1"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupField("filterBuffSpells") end,
									set = function(info, value) SetBarGroupField("filterBuffSpells", value) end,
								},
								SelectSpellList1 = {
									type = "select", order = 18, name = L["Spell List #1"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) or not GetBarGroupField("filterBuffSpells") end,
									get = function(info) local k, t = GetBarGroupField("filterBuffTable"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterBuffTable", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterBuffTable", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterBuffTable", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1a = { type = "description", name = "", order = 20 },
								SpellList2 = {
									type = "toggle", order = 22, name = L["Spell List #2"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupField("filterBuffSpells2") end,
									set = function(info, value) SetBarGroupField("filterBuffSpells2", value) end,
								},
								SelectSpellList2 = {
									type = "select", order = 24, name = L["Spell List #2"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) or not GetBarGroupField("filterBuffSpells2") end,
									get = function(info) local k, t = GetBarGroupField("filterBuffTable2"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterBuffTable2", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterBuffTable2", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterBuffTable2", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1b = { type = "description", name = "", order = 25 },
								SpellList3 = {
									type = "toggle", order = 26, name = L["Spell List #3"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupField("filterBuffSpells3") end,
									set = function(info, value) SetBarGroupField("filterBuffSpells3", value) end,
								},
								SelectSpellList3 = {
									type = "select", order = 28, name = L["Spell List #3"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) or not GetBarGroupField("filterBuffSpells3") end,
									get = function(info) local k, t = GetBarGroupField("filterBuffTable3"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterBuffTable3", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterBuffTable3", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterBuffTable3", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1c = { type = "description", name = "", order = 30 },
								SpellList4 = {
									type = "toggle", order = 32, name = L["Spell List #4"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupField("filterBuffSpells4") end,
									set = function(info, value) SetBarGroupField("filterBuffSpells4", value) end,
								},
								SelectSpellList4 = {
									type = "select", order = 34, name = L["Spell List #4"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) or not GetBarGroupField("filterBuffSpells4") end,
									get = function(info) local k, t = GetBarGroupField("filterBuffTable4"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterBuffTable4", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterBuffTable4", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterBuffTable4", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1d = { type = "description", name = "", order = 40 },
								SpellList5 = {
									type = "toggle", order = 42, name = L["Spell List #5"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupField("filterBuffSpells5") end,
									set = function(info, value) SetBarGroupField("filterBuffSpells5", value) end,
								},
								SelectSpellList5 = {
									type = "select", order = 44, name = L["Spell List #5"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) or not GetBarGroupField("filterBuffSpells5") end,
									get = function(info) local k, t = GetBarGroupField("filterBuffTable5"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterBuffTable5", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterBuffTable5", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterBuffTable5", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space2 = { type = "description", name = "", order = 50 },
								AddFilter = {
									type = "input", order = 55, name = L["Enter Buff"],
									desc = L["Enter a spell name (or numeric identifier, optionally preceded by # for a specific spell id) for a buff to be added to the filter list."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return nil end,
									set = function(info, value) value = ValidateSpellName(value); AddBarGroupFilter("Buff", value) end,
								},
								SelectFilter = {
									type = "select", order = 60, name = L["Filter List"],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupFilterSelection("Buff") end,
									set = function(info, value) SetBarGroupField("filterBuffSelection", value) end,
									values = function(info) return GetBarGroupFilter("Buff") end,
									style = "dropdown",
								},
								DeleteFilter = {
									type = "execute", order = 65, name = L["Delete"], width = "half",
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									desc = L["Delete the selected buff from the filter list."],
									func = function(info) DeleteBarGroupFilter("Buff", GetBarGroupField("filterBuffSelection")) end,
								},
								ResetFilter = {
									type = "execute", order = 70, name = L["Reset"], width = "half",
									desc = L["Reset the buff filter list."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									confirm = function(info) return L['RESET\nAre you sure you want to reset the buff filter list?'] end,
									func = function(info) ResetBarGroupFilter("Buff") end,
								},
								LinkFilters = {
									type = "toggle", order = 75, name = L["Link"],
									desc = L["If checked, the filter list is shared with bar groups in other profiles with the same name."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not (GetBarGroupField("filterBuff") or GetBarGroupField("showBuff")) end,
									get = function(info) return GetBarGroupField("filterBuffLink") end,
									set = function(info, value) SetBarGroupField("filterBuffLink", value) end,
								},
							},
						},
						FilterBarGroup = {
							type = "group", order = 50, name = L["Filter Bar Group"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectBuffs") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Filter buff bar group string"],
									get = function(info) return GetBarGroupField("filterBuffBars") end,
									set = function(info, v) SetBarGroupField("filterBuffBars", v) end,
								},
								SelectBarGroup = {
									type = "select", order = 20, name = L["Bar Group"],
									desc = L["Select filter bar group."],
									disabled = function(info) return not GetBarGroupField("detectBuffs") or not GetBarGroupField("filterBuffBars") end,
									get = function(info) local t = GetBarGroupList(); for k, v in pairs(t) do if v == GetBarGroupField("filterBuffBarGroup") then return k end end end,
									set = function(info, value) SetBarGroupField("filterBuffBarGroup", GetBarGroupList()[value]) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
							},
						},
					},
				},
				DetectDebuffsTab = {
					type = "group", order = 25, name = L["Debuffs"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() or not GetBarGroupField("auto") end,
					args = {
						EnableGroup = {
							type = "group", order = 1, name = L["Enable"], inline = true,
							args = {
								DetectEnable = {
									type = "toggle", order = 1, name = L["Auto Debuffs"],
									desc = L['Enable automatically displaying bars for debuffs that match these settings.'],
									get = function(info) return GetBarGroupField("detectDebuffs") end,
									set = function(info, value) SetBarGroupField("detectDebuffs", value) end,
								},
								AnyCastByPlayer = {
									type = "toggle", order = 5, name = L["All Cast By Player"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
									desc = L['Include all debuffs cast by player on others.'],
									get = function(info) return GetBarGroupField("detectAllDebuffs") end,
									set = function(info, value) SetBarGroupField("detectAllDebuffs", value) end,
								},
							},
						},
						MonitorUnitGroup = {
							type = "group", order = 10, name = L["Action On"], inline = true,
							hidden = function(info) return GetBarGroupField("detectAllDebuffs") end,
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								PlayerBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, only add bars for debuffs if they are on the player."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "player" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "player") end,
								},
								PetBuff = {
									type = "toggle", order = 15, name = L["Pet"],
									desc = L["If checked, only add bars for debuffs if they are on the player's pet."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "pet" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "pet") end,
								},
								TargetBuff = {
									type = "toggle", order = 20, name = L["Target"],
									desc = L["If checked, only add bars for debuffs if they are on the target."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "target" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "target") end,
								},
								FocusBuff = {
									type = "toggle", order = 30, name = L["Focus"],
									desc = L["If checked, only add bars for debuffs if they are on the focus."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "focus" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "focus") end,
								},
								Space1 = { type = "description", name = "", order = 35 },
								MouseoverDebuff = {
									type = "toggle", order = 40, name = L["Mouseover"],
									desc = L["If checked, only add bars for debuffs if they are on the mouseover unit."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "mouseover" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "mouseover") end,
								},
								PetTargetDebuff = {
									type = "toggle", order = 45, name = L["Pet's Target"],
									desc = L["If checked, only add bars for debuffs if they are on the pet's target."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "pettarget" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "pettarget") end,
								},
								TargetTargetDebuff = {
									type = "toggle", order = 50, name = L["Target's Target"],
									desc = L["If checked, only add bars for debuffs if they are on the target's target."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "targettarget" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "targettarget") end,
								},
								FocusTargetDebuff = {
									type = "toggle", order = 60, name = L["Focus's Target"],
									desc = L["If checked, only add bars for debuffs if they are on the focus's target."],
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "focustarget" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "focustarget") end,
								},
								Space2 = { type = "description", name = "", order = 65, hidden = function(info) return not MOD.db.global.IncludePartyUnits end },
								Party1Buff = {
									type = "toggle", order = 66, name = L["Party1"],
									desc = L["If checked, only add bars for debuffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "party1" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "party1") end,
								},
								Party2Buff = {
									type = "toggle", order = 67, name = L["Party2"],
									desc = L["If checked, only add bars for debuffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "party2" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "party2") end,
								},
								Party3Buff = {
									type = "toggle", order = 68, name = L["Party3"],
									desc = L["If checked, only add bars for debuffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "party3" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "party3") end,
								},
								Party4Buff = {
									type = "toggle", order = 69, name = L["Party4"],
									desc = L["If checked, only add bars for debuffs if they are on the specified party unit."],
									hidden = function(info) return not MOD.db.global.IncludePartyUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "party4" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "party4") end,
								},
								Space3 = { type = "description", name = "", order = 70, hidden = function(info) return not MOD.db.global.IncludeBossUnits end },
								Boss1Buff = {
									type = "toggle", order = 71, name = L["Boss1"],
									desc = L["If checked, only add bars for debuffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "boss1" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "boss1") end,
								},
								Boss2Buff = {
									type = "toggle", order = 72, name = L["Boss2"],
									desc = L["If checked, only add bars for debuffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "boss2" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "boss2") end,
								},
								Boss3Buff = {
									type = "toggle", order = 73, name = L["Boss3"],
									desc = L["If checked, only add bars for debuffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "boss3" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "boss3") end,
								},
								Boss4Buff = {
									type = "toggle", order = 74, name = L["Boss4"],
									desc = L["If checked, only add bars for debuffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "boss4" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "boss4") end,
								},
								Boss5Buff = {
									type = "toggle", order = 75, name = L["Boss5"], width = "half",
									desc = L["If checked, only add bars for debuffs if they are on the specified boss unit."],
									hidden = function(info) return not MOD.db.global.IncludeBossUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "boss5" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "boss5") end,
								},
								Space4 = { type = "description", name = "", order = 80, hidden = function(info) return not MOD.db.global.IncludeArenaUnits end },
								Arena1Buff = {
									type = "toggle", order = 81, name = L["Arena1"],
									desc = L["If checked, only add bars for debuffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "arena1" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "arena1") end,
								},
								Arena2Buff = {
									type = "toggle", order = 82, name = L["Arena2"],
									desc = L["If checked, only add bars for debuffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "arena2" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "arena2") end,
								},
								Arena3Buff = {
									type = "toggle", order = 83, name = L["Arena3"],
									desc = L["If checked, only add bars for debuffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "arena3" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "arena3") end,
								},
								Arena4Buff = {
									type = "toggle", order = 84, name = L["Arena4"],
									desc = L["If checked, only add bars for debuffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "arena4" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "arena4") end,
								},
								Arena5Buff = {
									type = "toggle", order = 85, name = L["Arena5"], width = "half",
									desc = L["If checked, only add bars for debuffs if they are on the specified arena unit."],
									hidden = function(info) return not MOD.db.global.IncludeArenaUnits end,
									get = function(info) return GetBarGroupField("detectDebuffsMonitor") == "arena5" end,
									set = function(info, value) SetBarGroupField("detectDebuffsMonitor", "arena5") end,
								},
							},
						},
						ExcludeUnitGroup = {
							type = "group", order = 15, name = L["Exclude On"], inline = true,
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								PlayerBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, exclude debuffs if they are on the player."],
									get = function(info) return GetBarGroupField("noPlayerDebuffs") end,
									set = function(info, value) SetBarGroupField("noPlayerDebuffs", value) end,
								},
								PetBuff = {
									type = "toggle", order = 15, name = L["Pet"],
									desc = L["If checked, exclude debuffs if they are on the player's pet."],
									get = function(info) return GetBarGroupField("noPetDebuffs") end,
									set = function(info, value) SetBarGroupField("noPetDebuffs", value) end,
								},
								TargetBuff = {
									type = "toggle", order = 20, name = L["Target"],
									desc = L["If checked, exclude debuffs if they are on the target."],
									get = function(info) return GetBarGroupField("noTargetDebuffs") end,
									set = function(info, value) SetBarGroupField("noTargetDebuffs", value) end,
								},
								FocusBuff = {
									type = "toggle", order = 30, name = L["Focus"],
									desc = L["If checked, exclude debuffs if they are on the focus."],
									get = function(info) return GetBarGroupField("noFocusDebuffs") end,
									set = function(info, value) SetBarGroupField("noFocusDebuffs", value) end,
								},
							},
						},
						CastUnitGroup = {
							type = "group", order = 20, name = L["Cast By"], inline = true,
							hidden = function(info) return GetBarGroupField("detectAllDebuffs") end,
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								MyBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, only add bars for debuffs if cast by the player."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "player" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "player") end,
								},
								PetBuff = {
									type = "toggle", order = 15, name = L["Pet"],
									desc = L["If checked, only add bars for debuffs if cast by the player's pet."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "pet" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "pet") end,
								},
								TargetBuff = {
									type = "toggle", order = 20, name = L["Target"],
									desc = L["If checked, only add bars for debuffs if cast by the target."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "target" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "target") end,
								},
								FocusBuff = {
									type = "toggle", order = 25, name = L["Focus"],
									desc = L["If checked, only add bars for debuffs if cast by the focus."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "focus" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "focus") end,
								},
								OurBuff = {
									type = "toggle", order = 27, name = L["Player Or Pet"],
									desc = L["If checked, only add bars for debuffs if cast by player or pet."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "ours" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "ours") end,
								},
								YourBuff = {
									type = "toggle", order = 30, name = L["Other"],
									desc = L["If checked, only add bars for debuffs if cast by anyone other than the player or pet."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "other" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "other") end,
								},
								AnyBuff = {
									type = "toggle", order = 35, name = L["Anyone"],
									desc = L["If checked, add bars for debuffs if cast by anyone, including player."],
									get = function(info) return GetBarGroupField("detectDebuffsCastBy") == "anyone" end,
									set = function(info, value) SetBarGroupField("detectDebuffsCastBy", "anyone") end,
								},
							},
						},
						IncludeByType = {
							type = "group", order = 30, name = L["Include By Type"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Include debuff types string"],
									get = function(info) return GetBarGroupField("filterDebuffTypes") end,
									set = function(info, v) SetBarGroupField("filterDebuffTypes", v) end,
								},
								Castable = {
									type = "toggle", order = 15, name = L["Castable"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include debuffs that the player can cast.'],
									get = function(info) return GetBarGroupField("detectInflictable") end,
									set = function(info, value) SetBarGroupField("detectInflictable", value) end,
								},
								Dispellable = {
									type = "toggle", order = 20, name = L["Dispellable"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include debuffs that the player can dispel.'],
									get = function(info) return GetBarGroupField("detectDispellable") end,
									set = function(info, value) SetBarGroupField("detectDispellable", value) end,
								},
								Effects = {
									type = "toggle", order = 25, name = L["Effect Timers"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L["Include debuffs from effect timers triggered by a spell cast."],
									get = function(info) return GetBarGroupField("detectEffectDebuffs") end,
									set = function(info, value) SetBarGroupField("detectEffectDebuffs", value) end,
								},
								Alerts = {
									type = "toggle", order = 27, name = L["Spell Alerts"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L["Include debuffs from spell alerts."],
									get = function(info) return GetBarGroupField("detectAlertDebuffs") end,
									set = function(info, value) SetBarGroupField("detectAlertDebuffs", value) end,
								},
								Poison = {
									type = "toggle", order = 35, name = L["Poison"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include poison debuffs.'],
									get = function(info) return GetBarGroupField("detectPoison") end,
									set = function(info, value) SetBarGroupField("detectPoison", value) end,
								},
								Curse = {
									type = "toggle", order = 40, name = L["Curse"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include curse debuffs.'],
									get = function(info) return GetBarGroupField("detectCurse") end,
									set = function(info, value) SetBarGroupField("detectCurse", value) end,
								},
								Magic = {
									type = "toggle", order = 45, name = L["Magic"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include magic debuffs.'],
									get = function(info) return GetBarGroupField("detectMagic") end,
									set = function(info, value) SetBarGroupField("detectMagic", value) end,
								},
								Disease = {
									type = "toggle", order = 50, name = L["Disease"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include disease debuffs.'],
									get = function(info) return GetBarGroupField("detectDisease") end,
									set = function(info, value) SetBarGroupField("detectDisease", value) end,
								},
								CastByNPC = {
									type = "toggle", order = 60, name = L["NPC"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include debuffs cast by an NPC (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("detectNPCDebuffs") end,
									set = function(info, value) SetBarGroupField("detectNPCDebuffs", value) end,
								},
								CastByVehicle = {
									type = "toggle", order = 65, name = L["Vehicle"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include debuffs cast by a vehicle (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("detectVehicleDebuffs") end,
									set = function(info, value) SetBarGroupField("detectVehicleDebuffs", value) end,
								},
								Boss = {
									type = "toggle", order = 70, name = L["Boss"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include debuffs cast by boss.'],
									get = function(info) return GetBarGroupField("detectBossDebuffs") end,
									set = function(info, value) SetBarGroupField("detectBossDebuffs", value) end,
								},
								Other = {
									type = "toggle", order = 80, name = L["Other"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Include other debuffs not selected with filter types.'],
									get = function(info) return GetBarGroupField("detectOtherDebuffs") end,
									set = function(info, value) SetBarGroupField("detectOtherDebuffs", value) end,
								},
							},
						},
						ExcludeByType = {
							type = "group", order = 35, name = L["Exclude By Type"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Exclude debuff types string"],
									get = function(info) return GetBarGroupField("excludeDebuffTypes") end,
									set = function(info, v) SetBarGroupField("excludeDebuffTypes", v) end,
								},
								Castable = {
									type = "toggle", order = 15, name = L["Castable"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude debuffs that the player can cast.'],
									get = function(info) return GetBarGroupField("excludeInflictable") end,
									set = function(info, value) SetBarGroupField("excludeInflictable", value) end,
								},
								Dispellable = {
									type = "toggle", order = 20, name = L["Dispellable"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude debuffs that the player can dispel.'],
									get = function(info) return GetBarGroupField("excludeDispellable") end,
									set = function(info, value) SetBarGroupField("excludeDispellable", value) end,
								},
								Effects = {
									type = "toggle", order = 25, name = L["Effect Timers"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L["Exclude debuffs from effect timers triggered by a spell cast."],
									get = function(info) return GetBarGroupField("excludeEffectDebuffs") end,
									set = function(info, value) SetBarGroupField("excludeEffectDebuffs", value) end,
								},
								Alerts = {
									type = "toggle", order = 27, name = L["Spell Alerts"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L["Exclude debuffs from spell alerts."],
									get = function(info) return GetBarGroupField("excludeAlertDebuffs") end,
									set = function(info, value) SetBarGroupField("excludeAlertDebuffs", value) end,
								},
								Poison = {
									type = "toggle", order = 35, name = L["Poison"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude poison debuffs.'],
									get = function(info) return GetBarGroupField("excludePoison") end,
									set = function(info, value) SetBarGroupField("excludePoison", value) end,
								},
								Curse = {
									type = "toggle", order = 40, name = L["Curse"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude curse debuffs.'],
									get = function(info) return GetBarGroupField("excludeCurse") end,
									set = function(info, value) SetBarGroupField("excludeCurse", value) end,
								},
								Magic = {
									type = "toggle", order = 45, name = L["Magic"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude magic debuffs.'],
									get = function(info) return GetBarGroupField("excludeMagic") end,
									set = function(info, value) SetBarGroupField("excludeMagic", value) end,
								},
								Disease = {
									type = "toggle", order = 50, name = L["Disease"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude disease debuffs.'],
									get = function(info) return GetBarGroupField("excludeDisease") end,
									set = function(info, value) SetBarGroupField("excludeDisease", value) end,
								},
								CastByNPC = {
									type = "toggle", order = 60, name = L["NPC"],
									disabled = function(info) return not GetBarGroupField("excludeDebuffTypes") end,
									desc = L['Exclude debuffs cast by an NPC (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("excludeNPCDebuffs") end,
									set = function(info, value) SetBarGroupField("excludeNPCDebuffs", value) end,
								},
								CastByVehicle = {
									type = "toggle", order = 65, name = L["Vehicle"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Exclude debuffs cast by a vehicle (note: only valid while caster is selected, such as when checking target of target).'],
									get = function(info) return GetBarGroupField("excludeVehicleDebuffs") end,
									set = function(info, value) SetBarGroupField("excludeVehicleDebuffs", value) end,
								},
								Boss = {
									type = "toggle", order = 70, name = L["Boss"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Exclude debuffs cast by boss.'],
									get = function(info) return GetBarGroupField("excludeBossDebuffs") end,
									set = function(info, value) SetBarGroupField("excludeBossDebuffs", value) end,
								},
								Other = {
									type = "toggle", order = 80, name = L["Other"],
									disabled = function(info) return not GetBarGroupField("filterDebuffTypes") end,
									desc = L['Exclude other debuffs not selected with filter types.'],
									get = function(info) return GetBarGroupField("excludeOtherDebuffs") end,
									set = function(info, value) SetBarGroupField("excludeOtherDebuffs", value) end,
								},
							},
						},
						FilterGroup = {
							type = "group", order = 40, name = L["Filter List"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								BlackList = {
									type = "toggle", order = 10, name = L["Black List"],
									desc = L["If checked, don't display any debuffs that are in the filter list."],
									get = function(info) return GetBarGroupField("filterDebuff") end,
									set = function(info, v) SetBarGroupField("filterDebuff", v); if v then SetBarGroupField("showDebuff", false) end end,
								},
								WhiteList = {
									type = "toggle", order = 11, name = L["White List"],
									desc = L["If checked, only display debuffs that are in the filter list."],
									get = function(info) return GetBarGroupField("showDebuff") end,
									set = function(info, v) SetBarGroupField("showDebuff", v); if v then SetBarGroupField("filterDebuff", false) end  end,
								},
								Space0 = { type = "description", name = "", order = 14 },
								SpellList1 = {
									type = "toggle", order = 16, name = L["Spell List #1"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffSpells") end,
									set = function(info, value) SetBarGroupField("filterDebuffSpells", value) end,
								},
								SelectSpellList1 = {
									type = "select", order = 18, name = L["Spell List #1"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) or not GetBarGroupField("filterDebuffSpells") end,
									get = function(info) local k, t = GetBarGroupField("filterDebuffTable"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterDebuffTable", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterDebuffTable", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterDebuffTable", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1a = { type = "description", name = "", order = 20 },
								SpellList2 = {
									type = "toggle", order = 22, name = L["Spell List #2"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffSpells2") end,
									set = function(info, value) SetBarGroupField("filterDebuffSpells2", value) end,
								},
								SelectSpellList2 = {
									type = "select", order = 24, name = L["Spell List #2"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) or not GetBarGroupField("filterDebuffSpells2") end,
									get = function(info) local k, t = GetBarGroupField("filterDebuffTable2"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterDebuffTable2", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterDebuffTable2", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterDebuffTable2", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1b = { type = "description", name = "", order = 25 },
								SpellList3 = {
									type = "toggle", order = 26, name = L["Spell List #3"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffSpells3") end,
									set = function(info, value) SetBarGroupField("filterDebuffSpells3", value) end,
								},
								SelectSpellList3 = {
									type = "select", order = 28, name = L["Spell List #3"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) or not GetBarGroupField("filterDebuffSpells3") end,
									get = function(info) local k, t = GetBarGroupField("filterDebuffTable3"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterDebuffTable3", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterDebuffTable3", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterDebuffTable3", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1c = { type = "description", name = "", order = 30 },
								SpellList4 = {
									type = "toggle", order = 32, name = L["Spell List #4"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffSpells4") end,
									set = function(info, value) SetBarGroupField("filterDebuffSpells4", value) end,
								},
								SelectSpellList4 = {
									type = "select", order = 34, name = L["Spell List #4"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) or not GetBarGroupField("filterDebuffSpells4") end,
									get = function(info) local k, t = GetBarGroupField("filterDebuffTable4"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterDebuffTable4", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterDebuffTable4", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterDebuffTable4", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1d = { type = "description", name = "", order = 40 },
								SpellList5 = {
									type = "toggle", order = 42, name = L["Spell List #5"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffSpells5") end,
									set = function(info, value) SetBarGroupField("filterDebuffSpells5", value) end,
								},
								SelectSpellList5 = {
									type = "select", order = 44, name = L["Spell List #5"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) or not GetBarGroupField("filterDebuffSpells5") end,
									get = function(info) local k, t = GetBarGroupField("filterDebuffTable5"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterDebuffTable5", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterDebuffTable5", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterDebuffTable5", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space2 = { type = "description", name = "", order = 50 },
								AddFilter = {
									type = "input", order = 55, name = L["Enter Debuff"],
									desc = L["Enter a spell name (or numeric identifier, optionally preceded by # for a specific spell id) for a debuff to be added to the filter list."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return nil end,
									set = function(info, value) value = ValidateSpellName(value); AddBarGroupFilter("Debuff", value) end,
								},
								SelectFilter = {
									type = "select", order = 60, name = L["Filter List"],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffSelection") end,
									set = function(info, value) SetBarGroupField("filterDebuffSelection", value) end,
									values = function(info) return GetBarGroupFilter("Debuff") end,
									style = "dropdown",
								},
								DeleteFilter = {
									type = "execute", order = 65, name = L["Delete"], width = "half",
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									desc = L["Delete the selected debuff from the filter list."],
									func = function(info) DeleteBarGroupFilter("Debuff", GetBarGroupField("filterDebuffSelection")) end,
								},
								ResetFilter = {
									type = "execute", order = 70, name = L["Reset"], width = "half",
									desc = L["Reset the debuff filter list."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									confirm = function(info) return L['RESET\nAre you sure you want to reset the debuff filter list?'] end,
									func = function(info) ResetBarGroupFilter("Debuff") end,
								},
								LinkFilters = {
									type = "toggle", order = 75, name = L["Link"],
									desc = L["If checked, the filter list is shared with bar groups in other profiles with the same name."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not (GetBarGroupField("filterDebuff") or GetBarGroupField("showDebuff")) end,
									get = function(info) return GetBarGroupField("filterDebuffLink") end,
									set = function(info, value) SetBarGroupField("filterDebuffLink", value) end,
								},
							},
						},
						FilterBarGroup = {
							type = "group", order = 50, name = L["Filter Bar Group"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectDebuffs") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Filter debuff bar group string"],
									get = function(info) return GetBarGroupField("filterDebuffBars") end,
									set = function(info, v) SetBarGroupField("filterDebuffBars", v) end,
								},
								SelectBarGroup = {
									type = "select", order = 20, name = L["Bar Group"],
									desc = L["Select filter bar group."],
									disabled = function(info) return not GetBarGroupField("detectDebuffs") or not GetBarGroupField("filterDebuffBars") end,
									get = function(info) local t = GetBarGroupList(); for k, v in pairs(t) do if v == GetBarGroupField("filterDebuffBarGroup") then return k end end end,
									set = function(info, value) SetBarGroupField("filterDebuffBarGroup", GetBarGroupList()[value]) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
							},
						},
					},
				},
				DetectCooldownsTab = {
					type = "group", order = 30, name = L["Cooldowns"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() or not GetBarGroupField("auto") end,
					args = {
						EnableGroup = {
							type = "group", order = 1, name = L["Enable"], inline = true,
							args = {
								DetectEnable = {
									type = "toggle", order = 1, name = L["Auto Cooldowns"],
									desc = L['Enable automatically displaying bars for cooldowns that match these settings.'],
									get = function(info) return GetBarGroupField("detectCooldowns") end,
									set = function(info, value) SetBarGroupField("detectCooldowns", value) end,
								},
							},
						},
						ActionUnitGroup = {
							type = "group", order = 20, name = L["Action By"], inline = true,
							disabled = function(info) return not GetBarGroupField("detectCooldowns") end,
							args = {
								MyBuff = {
									type = "toggle", order = 10, name = L["Player"],
									desc = L["If checked, only add bars for cooldowns associated with the player."],
									get = function(info) return GetBarGroupField("detectCooldownsBy") == "player" end,
									set = function(info, value) SetBarGroupField("detectCooldownsBy", "player") end,
								},
								PetBuff = {
									type = "toggle", order = 20, name = L["Pet"],
									desc = L["If checked, only add bars for cooldowns associated with the player's pet."],
									get = function(info) return GetBarGroupField("detectCooldownsBy") == "pet" end,
									set = function(info, value) SetBarGroupField("detectCooldownsBy", "pet") end,
								},
								AnyBuff = {
									type = "toggle", order = 30, name = L["Anyone"],
									desc = L["If checked, add bars for cooldowns cast by either player or player's pet."],
									get = function(info) return GetBarGroupField("detectCooldownsBy") == "anyone" end,
									set = function(info, value) SetBarGroupField("detectCooldownsBy", "anyone") end,
								},
							},
						},
						SharedCooldownGroup = {
							type = "group", order = 25, name = L["Shared Cooldowns"], inline = true,
							disabled = function(info) return not GetBarGroupField("detectCooldowns") end,
							args = {
								GrimoireCooldowns = {
									type = "toggle", order = 10, name = L["Grimoire of Service"],
									desc = L["If checked, only show one cooldown for warlock Grimoire of Service."],
									get = function(info) return GetBarGroupField("detectSharedGrimoires") end,
									set = function(info, value) SetBarGroupField("detectSharedGrimoires", value) end,
								},
								InfernalCooldowns = {
									type = "toggle", order = 20, name = L["Summon Infernals"],
									desc = L["If checked, only show one cooldown for warlock infernal and doomguard."],
									get = function(info) return GetBarGroupField("detectSharedInfernals") end,
									set = function(info, value) SetBarGroupField("detectSharedInfernals", value) end,
								},
							},
						},
						CooldownTypeGroup = {
							type = "group", order = 30, name = L["Cooldown Types"], inline = true,
							disabled = function(info) return not GetBarGroupField("detectCooldowns") end,
							args = {
								SpellCooldowns = {
									type = "toggle", order = 10, name = L["Spells"],
									desc = L["Include spell cooldowns."],
									get = function(info) return GetBarGroupField("detectSpellCooldowns") end,
									set = function(info, value) SetBarGroupField("detectSpellCooldowns", value) end,
								},
								TrinketCooldowns = {
									type = "toggle", order = 20, name = L["Trinkets"],
									desc = L["Include cooldowns for equipped trinkets."],
									get = function(info) return GetBarGroupField("detectTrinketCooldowns") end,
									set = function(info, value) SetBarGroupField("detectTrinketCooldowns", value) end,
								},
								InternalCooldowns = {
									type = "toggle", order = 25, name = L["Internal Cooldowns"],
									desc = L["Include internal cooldowns triggered by a buff or debuff."],
									get = function(info) return GetBarGroupField("detectInternalCooldowns") end,
									set = function(info, value) SetBarGroupField("detectInternalCooldowns", value) end,
								},
								SpellEffectCooldowns = {
									type = "toggle", order = 30, name = L["Effect Timers"],
									desc = L["Include effect timers triggered by a spell cast."],
									get = function(info) return GetBarGroupField("detectSpellEffectCooldowns") end,
									set = function(info, value) SetBarGroupField("detectSpellEffectCooldowns", value) end,
								},
								SpellAlertCooldowns = {
									type = "toggle", order = 32, name = L["Spell Alerts"],
									desc = L["Include spell alerts."],
									get = function(info) return GetBarGroupField("detectSpellAlertCooldowns") end,
									set = function(info, value) SetBarGroupField("detectSpellAlertCooldowns", value) end,
								},
								PotionCooldowns = {
									type = "toggle", order = 35, name = L["Potions/Elixirs"],
									desc = L["Include shared potion/elixir cooldowns (an item subject to the shared cooldown must be in your bags in order for the cooldown to be detected)."],
									get = function(info) return GetBarGroupField("detectPotionCooldowns") end,
									set = function(info, value) SetBarGroupField("detectPotionCooldowns", value) end,
								},
								OtherCooldowns = {
									type = "toggle", order = 40, name = L["Other"],
									desc = L["Include cooldowns not selected by other types."],
									get = function(info) return GetBarGroupField("detectOtherCooldowns") end,
									set = function(info, value) SetBarGroupField("detectOtherCooldowns", value) end,
								},
							},
						},
						FilterGroup = {
							type = "group", order = 40, name = L["Filter List"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectCooldowns") end,
							args = {
								BlackList = {
									type = "toggle", order = 10, name = L["Black List"],
									desc = L["If checked, don't display any cooldowns that are in the filter list."],
									get = function(info) return GetBarGroupField("filterCooldown") end,
									set = function(info, v) SetBarGroupField("filterCooldown", v); if v then SetBarGroupField("showCooldown", false) end end,
								},
								WhiteList = {
									type = "toggle", order = 11, name = L["White List"],
									desc = L["If checked, only display cooldowns that are in the filter list."],
									get = function(info) return GetBarGroupField("showCooldown") end,
									set = function(info, v) SetBarGroupField("showCooldown", v); if v then SetBarGroupField("filterCooldown", false) end  end,
								},
								Space0 = { type = "description", name = "", order = 14 },
								SpellList1 = {
									type = "toggle", order = 16, name = L["Spell List #1"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) end,
									get = function(info) return GetBarGroupField("filterCooldownSpells") end,
									set = function(info, value) SetBarGroupField("filterCooldownSpells", value) end,
								},
								SelectSpellList1 = {
									type = "select", order = 18, name = L["Spell List #1"],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) or not GetBarGroupField("filterCooldownSpells") end,
									get = function(info) local k, t = GetBarGroupField("filterCooldownTable"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterCooldownTable", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterCooldownTable", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterCooldownTable", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1a = { type = "description", name = "", order = 20 },
								SpellList2 = {
									type = "toggle", order = 22, name = L["Spell List #2"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) end,
									get = function(info) return GetBarGroupField("filterCooldownSpells2") end,
									set = function(info, value) SetBarGroupField("filterCooldownSpells2", value) end,
								},
								SelectSpellList2 = {
									type = "select", order = 24, name = L["Spell List #2"],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) or not GetBarGroupField("filterCooldownSpells2") end,
									get = function(info) local k, t = GetBarGroupField("filterCooldownTable2"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterCooldownTable2", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterCooldownTable2", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterCooldownTable2", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1b = { type = "description", name = "", order = 25 },
								SpellList3 = {
									type = "toggle", order = 26, name = L["Spell List #3"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) end,
									get = function(info) return GetBarGroupField("filterCooldownSpells3") end,
									set = function(info, value) SetBarGroupField("filterCooldownSpells3", value) end,
								},
								SelectSpellList3 = {
									type = "select", order = 28, name = L["Spell List #3"],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) or not GetBarGroupField("filterCooldownSpells3") end,
									get = function(info) local k, t = GetBarGroupField("filterCooldownTable3"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterCooldownTable3", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterCooldownTable3", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterCooldownTable3", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1c = { type = "description", name = "", order = 30 },
								SpellList4 = {
									type = "toggle", order = 32, name = L["Spell List #4"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) end,
									get = function(info) return GetBarGroupField("filterCooldownSpells4") end,
									set = function(info, value) SetBarGroupField("filterCooldownSpells4", value) end,
								},
								SelectSpellList4 = {
									type = "select", order = 34, name = L["Spell List #4"],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) or not GetBarGroupField("filterCooldownSpells4") end,
									get = function(info) local k, t = GetBarGroupField("filterCooldownTable4"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterCooldownTable4", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterCooldownTable4", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterCooldownTable4", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space1d = { type = "description", name = "", order = 40 },
								SpellList5 = {
									type = "toggle", order = 42, name = L["Spell List #5"],
									desc = L["If checked, filter list includes spells in specified spell list (these are set up on the Spells tab)."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) end,
									get = function(info) return GetBarGroupField("filterCooldownSpells5") end,
									set = function(info, value) SetBarGroupField("filterCooldownSpells5", value) end,
								},
								SelectSpellList5 = {
									type = "select", order = 44, name = L["Spell List #5"],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown")) or not GetBarGroupField("filterCooldownSpells5") end,
									get = function(info) local k, t = GetBarGroupField("filterCooldownTable5"), GetSpellList()
										if k and not MOD.db.global.SpellLists[k] then k = nil; SetBarGroupField("filterCooldownTable5", k) end
										if not k and next(t) then k = t[1]; SetBarGroupField("filterCooldownTable5", k) end
										return GetSpellListEntry(k) end,
									set = function(info, value) local k = GetSpellList()[value]; SetBarGroupField("filterCooldownTable5", k) end,
									values = function(info) return GetSpellList() end,
									style = "dropdown",
								},
								Space2 = { type = "description", name = "", order = 50 },
								AddFilter = {
									type = "input", order = 60, name = L["Enter Cooldown"],
									desc = L["Enter a spell name (or numeric identifier, optionally preceded by # for a specific spell id) for a cooldown to be added to the filter list."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown"))end,
									get = function(info) return nil end,
									set = function(info, value) AddBarGroupFilter("Cooldown", value) end, -- don't validate spell names for cooldowns
								},
								SelectFilter = {
									type = "select", order = 65, name = L["Filter List"],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown"))end,
									get = function(info) return GetBarGroupField("filterCooldownSelection") end,
									set = function(info, value) SetBarGroupField("filterCooldownSelection", value) end,
									values = function(info) return GetBarGroupFilter("Cooldown") end,
									style = "dropdown",
								},
								DeleteFilter = {
									type = "execute", order = 70, name = L["Delete"], width = "half",
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown"))end,
									desc = L["Delete the selected cooldown from the filter list."],
									func = function(info) DeleteBarGroupFilter("Cooldown", GetBarGroupField("filterCooldownSelection")) end,
								},
								ResetFilter = {
									type = "execute", order = 75, name = L["Reset"], width = "half",
									desc = L["Reset the cooldown filter list."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown"))end,
									confirm = function(info) return 'RESET\nAre you sure you want to reset the cooldown filter list?' end,
									func = function(info) ResetBarGroupFilter("Cooldown") end,
								},
								LinkFilters = {
									type = "toggle", order = 80, name = L["Link"],
									desc = L["If checked, the filter list is shared with bar groups in other profiles with the same name."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not (GetBarGroupField("filterCooldown") or GetBarGroupField("showCooldown"))end,
									get = function(info) return GetBarGroupField("filterCooldownLink") end,
									set = function(info, value) SetBarGroupField("filterCooldownLink", value) end,
								},
							},
						},
						FilterBarGroup = {
							type = "group", order = 50, name = L["Filter Bar Group"], inline = true, width = "full",
							disabled = function(info) return not GetBarGroupField("detectCooldowns") end,
							args = {
								Enable = {
									type = "toggle", order = 10, name = L["Enable"],
									desc = L["Filter cooldown bar group string"],
									get = function(info) return GetBarGroupField("filterCooldownBars") end,
									set = function(info, v) SetBarGroupField("filterCooldownBars", v) end,
								},
								SelectBarGroup = {
									type = "select", order = 20, name = L["Bar Group"],
									desc = L["Select filter bar group."],
									disabled = function(info) return not GetBarGroupField("detectCooldowns") or not GetBarGroupField("filterCooldownBars") end,
									get = function(info) local t = GetBarGroupList(); for k, v in pairs(t) do if v == GetBarGroupField("filterCooldownBarGroup") then return k end end end,
									set = function(info, value) SetBarGroupField("filterCooldownBarGroup", GetBarGroupList()[value]) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
							},
						},
					},
				},
				LayoutTab = {
					type = "group", order = 40, name = L["Layout"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() or GetBarGroupField("merged") end,
					args = {
						ConfigurationGroup = {
							type = "group", order = 10, name = L["Configuration"], inline = true,
							args = {
								BarConfiguration = {
									type = "toggle", order = 10, name = L["Bar Configuration"],
									desc = L["If checked, use a bar-oriented configuration."],
									get = function(info)
										local config = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										return not config.iconOnly
									end,
									set = function(info, value)
										local config = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										if config.iconOnly then SetBarGroupField("configuration", 1) end
									end,
								},
								IconConfiguration = {
									type = "toggle", order = 15, name = L["Icon Configuration"], width = "double",
									desc = L["If checked, use an icon-oriented configuration."],
									get = function(info)
										local config = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										return config.iconOnly
									end,
									set = function(info, value)
										local config = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										if not config.iconOnly then SetBarGroupField("configuration", 9) end
									end,
								},
								CopyLayoutGroup = {
									type = "select", order = 20, name = L["Copy Layout From"],
									desc = L["Select bar group to copy all layout settings from."],
									get = function(info) return nil end,
									set = function(info, value) CopyBarGroupConfiguration(GetBarGroupList()[value]) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
								Space0 = { type = "description", name = "", order = 25 },
								Configuration = {
									type = "select", order = 30, name = L["Options"], width = "double",
									desc = L["Select a configuration option for bars or icons."],
									get = function(info) return GetBarGroupField("configuration") end,
									set = function(info, value) SetBarGroupField("configuration", value) end,
									values = function(info)
										local config = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										return GetOrientationList(config.iconOnly)
									end,
									style = "dropdown",
								},
								ReverseGrowthGroup = {
									type = "toggle", order = 35, name = L["Direction"], width = "half",
									desc = function()
										local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										if t.bars == "stripe" then return L["If checked, stripe is above the anchor, otherwise it is below the anchor."] end
										return L["If checked, grow up or to the right, otherwise grow down or to the left."]
									end,
									get = function(info) return GetBarGroupField("growDirection") end,
									set = function(info, value) SetBarGroupField("growDirection", value) end,
								},
								SnapCenter = {
									type = "toggle", order = 40, name = L["Center"], width = "half",
									desc = L["If checked and the bar group is locked, snap to center at the anchor position."],
									disabled = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return not t.iconOnly or t.bars == "stripe" end,
									get = function(info) return GetBarGroupField("snapCenter") end,
									set = function(info, value) SetBarGroupField("snapCenter", value) end,
								},
								Segments = {
									type = "toggle", order = 41, name = L["Segment"], width = "half",
									desc = L["If checked then bars are shown in segments (additional options are displayed when enabled)."],
									disabled = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return t.iconOnly end,
									get = function(info) return GetBarGroupField("segmentBars") end,
									set = function(info, value) SetBarGroupField("segmentBars", value) end,
								},
								FillBars = {
									type = "toggle", order = 42, name = L["Fill"], width = "half",
									desc = L["If checked then timer bars fill up, otherwise they empty."],
									get = function(info) return GetBarGroupField("fillBars") end,
									set = function(info, value) SetBarGroupField("fillBars", value) end,
								},
								Space1 = { type = "description", name = "", order = 45 },
								MaxBars = {
									type = "range", order = 50, name = L["Bar/Icon Limit"], min = 0, max = 100, step = 1,
									desc = L["Set the maximum number of bars/icons to display (the ones that sort closest to the anchor have priority). If this is set to 0 then the number is not limited."],
									disabled = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return t.bars == "stripe" end,
									get = function(info) return GetBarGroupField("maxBars") end,
									set = function(info, value) SetBarGroupField("maxBars", value) end,
								},
								Wrap = {
									type = "range", order = 55, name = L["Wrap"], min = 0, max = 50, step = 1,
									desc = L["Set how many bars/icons to display before wrapping to next row or column. If this is set to 0 then wrapping is disabled."],
									disabled = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return t.bars == "stripe" end,
									get = function(info) return GetBarGroupField("wrap") end,
									set = function(info, value) SetBarGroupField("wrap", value) end,
								},
								WrapDirection = {
									type = "toggle", order = 60, name = L["Wrap Direction"],
									desc = L["If checked, wrap up when arranged in rows or to the right when arranged in columns, otherwise wrap down or to the left."],
									disabled = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return t.bars == "stripe" end,
									get = function(info) return GetBarGroupField("wrapDirection") end,
									set = function(info, value) SetBarGroupField("wrapDirection", value) end,
								},
								SegmentGroup = {
									type = "group", order = 90, name = L["Segment Options"], inline = true,
									hidden = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]
										return t.iconOnly or not GetBarGroupField("segmentBars") end,
									args = {
										NumberSegments = {
											type = "range", order = 5, name = L["Number Of Segments"], min = 1, max = 10, step = 1,
											desc = L["Set the number of segments to display for the bar."],
											get = function(info) return GetBarGroupField("segmentCount") or 10 end,
											set = function(info, value) SetBarGroupField("segmentCount", value) end,
										},
										SegmentSpacing = {
											type = "range", order = 10, name = L["Segment Spacing"], min = 0, max = 100, step = 1,
											desc = L["Set spacing between segments."],
											get = function(info) return GetBarGroupField("segmentSpacing") or 1 end,
											set = function(info, value) SetBarGroupField("segmentSpacing", value) end,
										},
										AutoNumber = {
											type = "toggle", order = 15, name = L["Allow Override"],
											desc = L["If checked, segment options may be overridden by a custom bar's settings."],
											hidden = function() return GetBarGroupField("auto") end,
											get = function(info) return GetBarGroupField("segmentOverride") end,
											set = function(info, value) SetBarGroupField("segmentOverride", value) end,
										},
										AdvancedSettings = {
											type = "toggle", order = 20, name = L["Advanced Settings"],
											desc = L["Enable advanced settings to experiment with unusual segment arrangements."],
											get = function(info) return GetBarGroupField("segmentAdvanced") end,
											set = function(info, value) SetBarGroupField("segmentAdvanced", value) end,
										},
										Space1 = {
											type = "description", name = "", order = 25,
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
										},
										SegmentCurvature = {
											type = "range", order = 40, name = L["Curvature"], min = -180, max = 180, step = 1,
											desc = L["Adjust curvature of segment arrangement."],
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
											get = function(info) return GetBarGroupField("segmentCurve") or 0 end,
											set = function(info, value) SetBarGroupField("segmentCurve", value) end,
										},
										SegmentRotation = {
											type = "range", order = 45, name = L["Rotation"], min = -180, max = 180, step = 1,
											desc = L["Adjust rotation of segment arrangement."],
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
											get = function(info) return GetBarGroupField("segmentRotate") or 0 end,
											set = function(info, value) SetBarGroupField("segmentRotate", value) end,
										},
										Space11 = { type = "description", name = "", order = 49 },
										Circles = {
											type = "toggle", order = 50, name = L["Circles"], width = "half",
											desc = L["If checked, circles are shown instead of rectangular segments."],
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
											get = function(info) return GetBarGroupField("segmentTexture") == "circle" end,
											set = function(info, value) if value then SetBarGroupField("segmentTexture", "circle") else SetBarGroupField("segmentTexture", nil) end end,
										},
										Diamonds = {
											type = "toggle", order = 55, name = L["Diamonds"], width = "half",
											desc = L["If checked, diamonds are shown instead of rectangular segments."],
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
											get = function(info) return GetBarGroupField("segmentTexture") == "diamond" end,
											set = function(info, value) if value then SetBarGroupField("segmentTexture", "diamond") else SetBarGroupField("segmentTexture", nil) end end,
										},
										Triangles = {
											type = "toggle", order = 60, name = L["Triangles"], width = "half",
											desc = L["If checked, triangles are shown instead of rectangular segments."],
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
											get = function(info) return GetBarGroupField("segmentTexture") == "triangle" end,
											set = function(info, value) if value then SetBarGroupField("segmentTexture", "triangle") else SetBarGroupField("segmentTexture", nil) end end,
										},
										Trapezoids = {
											type = "toggle", order = 65, name = L["Trapezoids"],
											desc = L["If checked, trapezoids are shown instead of rectangular segments."],
											hidden = function() return not GetBarGroupField("segmentAdvanced") end,
											get = function(info) return GetBarGroupField("segmentTexture") == "trapezoid" end,
											set = function(info, value) if value then SetBarGroupField("segmentTexture", "trapezoid") else SetBarGroupField("segmentTexture", nil) end end,
										},
										Space12 = { type = "description", name = "", order = 120 },
										HideEmptySegments = {
											type = "toggle", order = 125, name = L["Hide Empty Segments"],
											desc = L["If checked, empty segments are hidden."],
											get = function(info) return GetBarGroupField("segmentHideEmpty") end,
											set = function(info, value) SetBarGroupField("segmentHideEmpty", value) end,
										},
										FadePartialSegments = {
											type = "toggle", order = 130, name = L["Fade Partial Segments"],
											desc = L["If checked, fade the foreground color for partial segments to indicate how much is left."],
											get = function(info) return GetBarGroupField("segmentFadePartial") end,
											set = function(info, value) SetBarGroupField("segmentFadePartial", value) end,
										},
										ShrinkPartialWidth = {
											type = "toggle", order = 135, name = L["Shrink Partial Width"],
											desc = L["If checked, shrink the width of the foreground for partial segments to indicate how much is left."],
											get = function(info) return GetBarGroupField("segmentShrinkWidth") end,
											set = function(info, value) SetBarGroupField("segmentShrinkWidth", value) end,
										},
										ShrinkPartialHeight = {
											type = "toggle", order = 136, name = L["Shrink Partial Height"],
											desc = L["If checked, shrink the height of the foreground for partial segments to indicate how much is left."],
											get = function(info) return GetBarGroupField("segmentShrinkHeight") end,
											set = function(info, value) SetBarGroupField("segmentShrinkHeight", value) end,
										},
										Space13 = { type = "description", name = "", order = 140 },
										GradientColors = {
											type = "toggle", order = 145, name = L["Color Gradient"],
											desc = L["If checked and there are at least two segments, segments are customized with a color gradient, otherwise they use the bar's foreground color."],
											get = function(info) return GetBarGroupField("segmentGradient") end,
											set = function(info, value) SetBarGroupField("segmentGradient", value) end,
										},
										GradientAll = {
											type = "toggle", order = 146, name = L["Color All Together"],
											desc = L["Apply gradient to all segments based on how many are showing, otherwise color each segment individually."],
											disabled = function(info) return not GetBarGroupField("segmentGradient") end,
											get = function(info) return GetBarGroupField("segmentGradientAll") end,
											set = function(info, value) SetBarGroupField("segmentGradientAll", value) end,
										},
										StartColor = {
											type = "color", order = 150, name = L["Start"], hasAlpha = false, width = "half",
											desc = L["Set start color for the gradient."],
											disabled = function(info) return not GetBarGroupField("segmentGradient") end,
											get = function(info)
												local t = GetBarGroupField("segmentGradientStartColor"); if t then return t.r, t.g, t.b else return 0, 1, 0 end
											end,
											set = function(info, r, g, b)
												local t = GetBarGroupField("segmentGradientStartColor"); if t then t.r = r; t.g = g; t.b = b else
													t = { r = r, g = g, b = b }; SetBarGroupField("segmentGradientStartColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										EndColor = {
											type = "color", order = 155, name = L["End"], hasAlpha = false, width = "half",
											desc = L["Set end color for the gradient."],
											disabled = function(info) return not GetBarGroupField("segmentGradient") end,
											get = function(info)
												local t = GetBarGroupField("segmentGradientEndColor"); if t then return t.r, t.g, t.b else return 1, 0, 0 end
											end,
											set = function(info, r, g, b)
												local t = GetBarGroupField("segmentGradientEndColor"); if t then t.r = r; t.g = g; t.b = b else
													t = { r = r, g = g, b = b }; SetBarGroupField("segmentGradientEndColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										BackdropColor = {
											type = "color", order = 160, name = L["Border Color"], hasAlpha = true,
											desc = L["Set color, including opacity, of the border around each segment."],
											get = function(info)
												local t = GetBarGroupField("segmentBorderColor"); if t then return t.r, t.g, t.b, t.a else return 0, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("segmentBorderColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("segmentBorderColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
									},
								},
								TestGroup = {
									type = "group", order = 95, name = L["Test Mode"], inline = true,
									args = {
										StaticBars = {
											type = "range", order = 10, name = L["Unlimited Duration"], min = 0, max = 100, step = 1,
											desc = L["Set the number of unlimited duration bars/icons to generate in test mode."],
											get = function(info) return GetBarGroupField("testStatic") end,
											set = function(info, value) SetBarGroupField("testStatic", value) end,
										},
										TimerBars = {
											type = "range", order = 20, name = L["Timers"], min = 0, max = 100, step = 1,
											desc = L["Set the number of timer bars/icons to generate in test mode."],
											get = function(info) return GetBarGroupField("testTimers") end,
											set = function(info, value) SetBarGroupField("testTimers", value) end,
										},
										LoopTimers = {
											type = "toggle", order = 30, name = L["Refresh Timers"],
											desc = L["If checked, timers are refreshed when they expire, otherwise they disappear."],
											get = function(info) return GetBarGroupField("testLoop") end,
											set = function(info, value) SetBarGroupField("testLoop", value) end,
										},
										TestToggle = {
											type = "execute", order = 40, name = L["Toggle Test Mode"],
											desc = L["Toggle display of test bars/icons."],
											func = function(info) MOD:TestBarGroup(GetBarGroupEntry()); MOD:UpdateAllBarGroups() end,
										},
									},
								},
								TimelineGroup = {
									type = "group", order = 100, name = L["Timeline Options"], inline = true,
									hidden = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return t.bars ~= "timeline" end,
									args = {
										BarWidth = {
											type = "range", order = 1, name = L["Width"], min = 5, max = 4000, step = 1,
											desc = L["Set width of the timeline."],
											get = function(info) return GetBarGroupField("timelineWidth") end,
											set = function(info, value) SetBarGroupField("timelineWidth", value) end,
										},
										BarHeight = {
											type = "range", order = 5, name = L["Height"], min = 5, max = 200, step = 1,
											desc = L["Set height of the timeline."],
											get = function(info) return GetBarGroupField("timelineHeight") end,
											set = function(info, value) SetBarGroupField("timelineHeight", value) end,
										},
										MaxSeconds = {
											type = "range", order = 10, name = L["Duration"], min = 5, max = 600, step = 1,
											desc = L["Set maximum duration represented on the timeline in seconds."],
											get = function(info) return GetBarGroupField("timelineDuration") end,
											set = function(info, value) SetBarGroupField("timelineDuration", value) end,
										},
										Exponent = {
											type = "range", order = 15, name = L["Exponent"], min = 1, max = 10, step = 0.25,
											desc = L["Set exponent factor for timeline to adjust time scale."],
											get = function(info) return GetBarGroupField("timelineExp") end,
											set = function(info, value) SetBarGroupField("timelineExp", value) end,
										},
										Texture = {
											type = "select", order = 20, name = L["Texture"],
											desc = L["Select texture for the timeline."],
											dialogControl = 'LSM30_Statusbar',
											values = AceGUIWidgetLSMlists.statusbar,
											get = function(info) return GetBarGroupField("timelineTexture") end,
											set = function(info, value) SetBarGroupField("timelineTexture", value) end,
										},
										Alpha = {
											type = "range", order = 25, name = L["Opacity"], min = 0, max = 1, step = 0.05,
											desc = L["Set opacity for the timeline."],
											get = function(info) return GetBarGroupField("timelineAlpha") end,
											set = function(info, value) SetBarGroupField("timelineAlpha", value) end,
										},
										Color = {
											type = "color", order = 27, name = L["Timeline Color"], hasAlpha = true,
											desc = L["Set color for the timeline."],
											get = function(info)
												local t = GetBarGroupField("timelineColor"); if t then return t.r, t.g, t.b, t.a else return 0.5, 0.5, 0.5, 0.5 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("timelineColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("timelineColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										HideEmpty = {
											type = "toggle", order = 28, name = L["Hide Empty"],
											desc = L["If checked, hide the timeline when there are no active icons."],
											get = function(info) return GetBarGroupField("timelineHide") end,
											set = function(info, value) SetBarGroupField("timelineHide", value) end,
										},
										Space1 = { type = "description", name = "", order = 30 },
										BorderTexture = {
											type = "select", order = 31, name = L["Timeline Border"],
											desc = L["Select border for the timeline (select None to disable border)."],
											dialogControl = 'LSM30_Border',
											values = AceGUIWidgetLSMlists.border,
											get = function(info) return GetBarGroupField("timelineBorderTexture") end,
											set = function(info, value) SetBarGroupField("timelineBorderTexture", value) end,
										},
										BorderWidth = {
											type = "range", order = 32, name = L["Edge Size"], min = 0, max = 32, step = 0.01,
											desc = L["Adjust size of the border's edge."],
											get = function(info) return GetBarGroupField("timelineBorderWidth") end,
											set = function(info, value) SetBarGroupField("timelineBorderWidth", value) end,
										},
										BorderOffset = {
											type = "range", order = 33, name = L["Offset"], min = -16, max = 16, step = 0.01,
											desc = L["Adjust offset to the border from the bar."],
											get = function(info) return GetBarGroupField("timelineBorderOffset") end,
											set = function(info, value) SetBarGroupField("timelineBorderOffset", value) end,
										},
										BorderColor = {
											type = "color", order = 34, name = L["Border Color"], hasAlpha = true,
											desc = L["Set color for the border."],
											get = function(info)
												local t = GetBarGroupField("timelineBorderColor")
												if t then return t.r, t.g, t.b, t.a else return 0, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("timelineBorderColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("timelineBorderColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										Space2 = { type = "description", name = "", order = 40 },
										SplashEffect = {
											type = "toggle", order = 45, name = L["Splash Effect"],
											desc = L["If checked, show a splash effect when icons expire."],
											get = function(info) return GetBarGroupField("timelineSplash") end,
											set = function(info, value) SetBarGroupField("timelineSplash", value) end,
										},
										SplashOffsetX = {
											type = "range", order = 47, name = L["Offset X"], min = -1000, max = 1000, step = 1,
											desc = L["Set horizontal offset for splash effect."],
											get = function(info) return GetBarGroupField("timelineSplashX") end,
											set = function(info, value) SetBarGroupField("timelineSplashX", value) end,
										},
										SplashOffsetY = {
											type = "range", order = 49, name = L["Offset Y"], min = -1000, max = 1000, step = 1,
											desc = L["Set vertical offset for splash effect."],
											get = function(info) return GetBarGroupField("timelineSplashY") end,
											set = function(info, value) SetBarGroupField("timelineSplashY", value) end,
										},
										Space3 = { type = "description", name = "", order = 50 },
										IconOffset = {
											type = "range", order = 55, name = L["Icon Offset"], min = -100, max = 100, step = 1,
											desc = L["Set vertical offset from center of timeline for icons."],
											get = function(info) return GetBarGroupField("timelineOffset") end,
											set = function(info, value) SetBarGroupField("timelineOffset", value) end,
										},
										OverlapPercent = {
											type = "range", order = 57, name = L["Overlap Percent"], min = 1, max = 100, step = 1,
											desc = L["Set percent overlap that triggers extra offset and switching icons."],
											get = function(info) return GetBarGroupField("timelinePercent") end,
											set = function(info, value) SetBarGroupField("timelinePercent", value) end,
										},
										OverlapOffset = {
											type = "range", order = 60, name = L["Overlap Offset"], min = -100, max = 100, step = 1,
											desc = L["Set additional vertical offset for overlapping icons."],
											get = function(info) return GetBarGroupField("timelineDelta") end,
											set = function(info, value) SetBarGroupField("timelineDelta", value) end,
										},
										Space4 = { type = "description", name = "", order = 65 },
										Switcher = {
											type = "toggle", order = 70, name = L["Overlap Switch"],
											desc = L["If checked, when icons overlap, switch which is shown on top (otherwise always show icon with shortest time remaining on top)."],
											get = function(info) return GetBarGroupField("timelineAlternate") end,
											set = function(info, value) SetBarGroupField("timelineAlternate", value) end,
										},
										SwitchTime = {
											type = "range", order = 75, name = L["Switch Time"], min = 0.5, max = 10, step = 0.5,
											desc = L["Set time between switching overlapping icons."],
											disabled = function(info) return not GetBarGroupField("timelineAlternate") end,
											get = function(info) return GetBarGroupField("timelineSwitch") or 2 end,
											set = function(info, value) SetBarGroupField("timelineSwitch", value or 2) end,
										},
										Space5 = { type = "description", name = "", order = 85 },
										LabelList = {
											type = "input", order = 100, name = L["Label List"], width = "double",
											desc = L['Enter comma-separated list of times to show as labels on the timeline (times are in seconds unless you include "m", which is included in the label, or "M", which is hidden, for minutes).'],
											get = function(info) return GetListString(GetBarGroupField("timelineLabels") or MOD:GetTimelineLabels()) end,
											set = function(info, v) SetBarGroupField("timelineLabels", GetListTable(v, "strings")) end,
										},
									},
								},
								StripeGroup = {
									type = "group", order = 110, name = L["Horizontal Stripe Options"], inline = true,
									hidden = function() local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")]; return t.bars ~= "stripe" end,
									args = {
										FullWidth = {
											type = "toggle", order = 5, name = L["Full Width"], width = "half",
											desc = L["If checked, horizontal stripe will be the full width of the display and will automatically adjust to fit."],
											get = function(info) return GetBarGroupField("stripeFullWidth") end,
											set = function(info, value) SetBarGroupField("stripeFullWidth", value) end,
										},
										BarWidth = {
											type = "range", order = 10, name = L["Width"], min = 5, max = 4000, step = 1,
											desc = L["Set width of the stripe."],
											disabled = function(info) return GetBarGroupField("stripeFullWidth") end,
											get = function(info) return GetBarGroupField("stripeWidth") end,
											set = function(info, value) SetBarGroupField("stripeWidth", value) end,
										},
										BarHeight = {
											type = "range", order = 15, name = L["Height"], min = 5, max = 200, step = 1,
											desc = L["Set height of the stripe."],
											get = function(info) return GetBarGroupField("stripeHeight") end,
											set = function(info, value) SetBarGroupField("stripeHeight", value) end,
										},
										Space1 = { type = "description", name = "", order = 16 },
										StripeInset = {
											type = "range", order = 20, name = L["Stripe Inset"], min = -1000, max = 1000, step = 1,
											desc = L["Set horizontal offset from anchor for the stripe. This can be affected by bar group direction and dimensions."],
											disabled = function(info) return GetBarGroupField("stripeFullWidth") end,
											get = function(info) return GetBarGroupField("stripeInset") end,
											set = function(info, value) SetBarGroupField("stripeInset", value) end,
										},
										StripeOffset = {
											type = "range", order = 25, name = L["Stripe Offset"], min = -1000, max = 1000, step = 1,
											desc = L["Set vertical offset from anchor for the stripe. This can be affected by bar group direction and dimensions."],
											get = function(info) return GetBarGroupField("stripeOffset") end,
											set = function(info, value) SetBarGroupField("stripeOffset", value) end,
										},
										BarInset = {
											type = "range", order = 30, name = L["Bar Inset"], min = 0, max = 100, step = 1,
											desc = L["Set horizontal offset from ends of stripe for bars."],
											get = function(info) return GetBarGroupField("stripeBarInset") end,
											set = function(info, value) SetBarGroupField("stripeBarInset", value) end,
										},
										BarOffset = {
											type = "range", order = 35, name = L["Bar Offset"], min = -100, max = 100, step = 1,
											desc = L["Set vertical offset from center of stripe for bars."],
											get = function(info) return GetBarGroupField("stripeBarOffset") end,
											set = function(info, value) SetBarGroupField("stripeBarOffset", value) end,
										},
										Space2 = { type = "description", name = "", order = 40 },
										Texture = {
											type = "select", order = 45, name = L["Texture"],
											desc = L["Select texture for the stripe."],
											dialogControl = 'LSM30_Statusbar',
											values = AceGUIWidgetLSMlists.statusbar,
											get = function(info) return GetBarGroupField("stripeTexture") end,
											set = function(info, value) SetBarGroupField("stripeTexture", value) end,
										},
										Color = {
											type = "color", order = 50, name = L["Color"], hasAlpha = true, width = "half",
											desc = L["Color for the stripe."],
											get = function(info)
												local t = GetBarGroupField("stripeColor"); if t then return t.r, t.g, t.b, t.a else return 0.5, 0.5, 0.5, 0.5 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("stripeColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("stripeColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										AltColor = {
											type = "color", order = 55, name = L["Alt Color"], hasAlpha = true, width = "half",
											desc = L["Alternative color for the stripe that is used if color condition is true."],
											get = function(info)
												local t = GetBarGroupField("stripeAltColor"); if t then return t.r, t.g, t.b, t.a else return 0.5, 0.5, 0.5, 0.5 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("stripeAltColor"); if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("stripeAltColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										AltCheckCondition = {
											type = "toggle", order = 60, name = L["Condition Is True"],
											desc = L["If checked, alternative color is used when the selected condition is true."],
											get = function(info) return GetBarGroupField("stripeCheckCondition") end,
											set = function(info, value) SetBarGroupField("stripeCheckCondition", value) end,
										},
										AltCondition = {
											type = "select", order = 65, name = L["Color Condition"],
											desc = L["Condition tested for alternative color."],
											disabled = function(info) return not GetBarGroupField("stripeCheckCondition") end,
											get = function(info) return GetBarGroupAltCondition(GetSelectConditionList()) end,
											set = function(info, value) SetBarGroupField("stripeCondition", GetSelectConditionList()[value]) end,
											values = function(info) return GetSelectConditionList() end,
											style = "dropdown",
										},
										Space3 = { type = "description", name = "", order = 66 },
										BorderTexture = {
											type = "select", order = 70, name = L["Stripe Border"],
											desc = L["Select border for the stripe (select None to disable border)."],
											dialogControl = 'LSM30_Border',
											values = AceGUIWidgetLSMlists.border,
											get = function(info) return GetBarGroupField("stripeBorderTexture") end,
											set = function(info, value) SetBarGroupField("stripeBorderTexture", value) end,
										},
										BorderWidth = {
											type = "range", order = 75, name = L["Edge Size"], min = 0, max = 32, step = 0.01,
											desc = L["Adjust size of the border's edge."],
											get = function(info) return GetBarGroupField("stripeBorderWidth") end,
											set = function(info, value) SetBarGroupField("stripeBorderWidth", value) end,
										},
										BorderOffset = {
											type = "range", order = 80, name = L["Offset"], min = -16, max = 16, step = 0.01,
											desc = L["Adjust offset to the border from the bar."],
											get = function(info) return GetBarGroupField("stripeBorderOffset") end,
											set = function(info, value) SetBarGroupField("stripeBorderOffset", value) end,
										},
										BorderColor = {
											type = "color", order = 85, name = L["Border Color"], hasAlpha = true,
											desc = L["Set color for the border."],
											get = function(info)
												local t = GetBarGroupField("stripeBorderColor")
												if t then return t.r, t.g, t.b, t.a else return 0, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("stripeBorderColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("stripeBorderColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
									},
								},
							},
						},
						DimensionGroup = {
							type = "group", order = 20, name = L["Format"], inline = true,
							args = {
								UseDefaultsGroup = {
									type = "toggle", order = 1, name = L["Use Defaults"],
									desc = L["If checked, format options are set to default values."],
									get = function(info) return GetBarGroupField("useDefaultDimensions") end,
									set = function(info, value) SetBarGroupField("useDefaultDimensions", value) end,
								},
								RestoreDefaults = {
									type = "execute", order = 5, name = L["Restore Defaults"],
									desc = L["Reset format for this bar group back to the current defaults."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									func = function(info) MOD:CopyDimensions(MOD.db.global.Defaults, GetBarGroupEntry()); MOD:UpdateAllBarGroups() end,
								},
								Space1 = { type = "description", name = "", order = 10 },
								BarWidth = {
									type = "range", order = 20, name = L["Bar Width"], min = 5, max = 500, step = 1,
									desc = L["Set width of bars."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("barWidth") end,
									set = function(info, value) SetBarGroupField("barWidth", value) end,
								},
								BarHeight = {
									type = "range", order = 25, name = L["Bar Height"], min = 1, max = 100, step = 1,
									desc = L["Set height of bars."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("barHeight") end,
									set = function(info, value) SetBarGroupField("barHeight", value) end,
								},
								IconSize = {
									type = "range", order = 30, name = L["Icon Size"], min = 5, max = 100, step = 1,
									desc = L["Set width/height for icons."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("iconSize") end,
									set = function(info, value) SetBarGroupField("iconSize", value) end,
								},
								Scale = {
									type = "range", order = 35, name = L["Scale"], min = 0.1, max = 2, step = 0.05,
									desc = L["Set scale factor for bars and icons."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("scale") end,
									set = function(info, value) SetBarGroupField("scale", value) end,
								},
								Space2 = { type = "description", name = "", order = 40 },
								HorizontalSpacing = {
									type = "range", order = 60, name = L["Horizontal Spacing"], min = -100, max = 100, step = 1,
									desc = L["Adjust horizontal spacing between bars."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("spacingX") end,
									set = function(info, value) SetBarGroupField("spacingX", value) end,
								},
								VerticalSpacing = {
									type = "range", order = 65, name = L["Vertical Spacing"], min = -100, max = 100, step = 1,
									desc = L["Adjust vertical spacing between bars."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("spacingY") end,
									set = function(info, value) SetBarGroupField("spacingY", value) end,
								},
								IconOffsetX = {
									type = "range", order = 70, name = L["Icon Inset"], min = -200, max = 200, step = 1,
									desc = L["Set icon's horizontal inset from bar."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("iconOffsetX") end,
									set = function(info, value) SetBarGroupField("iconOffsetX", value) end,
								},
								IconOffsetY = {
									type = "range", order = 75, name = L["Icon Offset"], min = -200, max = 200, step = 1,
									desc = L["Set vertical offset between icon and bar."],
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									get = function(info) return GetBarGroupField("iconOffsetY") end,
									set = function(info, value) SetBarGroupField("iconOffsetY", value) end,
								},
								Space2 = { type = "description", name = "", order = 80 },
								BarFormatGroup = {
									type = "group", order = 90, name = "", inline = true,
									disabled = function(info) return GetBarGroupField("useDefaultDimensions") end,
									args = {
										HideIconGroup = {
											type = "toggle", order = 30, name = L["Icon"], width = "half",
											desc = L["Show icon string"],
											get = function(info) return not GetBarGroupField("hideIcon") end,
											set = function(info, value) SetBarGroupField("hideIcon", not value) end,
										},
										HideClockGroup = {
											type = "toggle", order = 31, name = L["Clock"], width = "half",
											desc = L["Show clock animation on icons for timer bars."],
											disabled = function(info) local t = MOD.Nest_SupportedConfigurations[GetBarGroupField("configuration")];
												return GetBarGroupField("useDefaultDimensions") or t.bars == "timeline" end,
											get = function(info) return not GetBarGroupField("hideClock") end,
											set = function(info, value) SetBarGroupField("hideClock", not value) end,
										},
										HideBarGroup = {
											type = "toggle", order = 32, name = L["Bar"], width = "half",
											desc = L["Show colored bar and background."],
											get = function(info) return not GetBarGroupField("hideBar") end,
											set = function(info, value) SetBarGroupField("hideBar", not value) end,
										},
										HideSparkGroup = {
											type = "toggle", order = 33, name = L["Spark"], width = "half",
											desc = L["Show spark that moves across bars to indicate remaining time."],
											disabled = function(info) return GetBarGroupField("useDefaultDimensions") or GetBarGroupField("hideBar") end,
											get = function(info) return not GetBarGroupField("hideSpark") end,
											set = function(info, value) SetBarGroupField("hideSpark", not value) end,
										},
										HideLabelGroup = {
											type = "toggle", order = 34, name = L["Label"], width = "half",
											desc = L["Show label text on bars."],
											get = function(info) return not GetBarGroupField("hideLabel") end,
											set = function(info, value) SetBarGroupField("hideLabel", not value) end,
										},
										HideCountGroup = {
											type = "toggle", order = 35, name = L["Count"], width = "half",
											desc = L["Show stack count in parentheses after label (it is also displayed as overlay on icon)."],
											get = function(info) return not GetBarGroupField("hideCount") end,
											set = function(info, value) SetBarGroupField("hideCount", not value) end,
										},
										HideTimerGroup = {
											type = "toggle", order = 36, name = L["Time"], width = "half",
											desc = L["Show time left on bars that have a duration."],
											get = function(info) return not GetBarGroupField("hideValue") end,
											set = function(info, value) SetBarGroupField("hideValue", not value) end,
										},
										TooltipsGroup = {
											type = "toggle", order = 37, name = L["Tooltips"], width = "half",
											desc = L["Show tooltips when the cursor is over bar/icon (may require /reload). See bar group's General tab for tooltip settings."],
											get = function(info) return GetBarGroupField("showTooltips") end,
											set = function(info, value) SetBarGroupField("showTooltips", value) end,
										},
									},
								},
							},
						},
						TextSettings = {
							type = "group", order = 30, name = L["Text Settings"], inline = true,
							args = {
								LabelInset = {
									type = "range", order = 10, name = L["Label Text Inset"], min = -200, max = 200, step = 1,
									desc = L["Set horizontal inset for label from edge of bar."],
									get = function(info) return GetBarGroupField("labelInset") end,
									set = function(info, value) SetBarGroupField("labelInset", value) end,
								},
								LabelOffset = {
									type = "range", order = 15, name = L["Label Text Offset"], min = -200, max = 200, step = 1,
									desc = L["Set vertical offset for label text from center of bar."],
									get = function(info) return GetBarGroupField("labelOffset") end,
									set = function(info, value) SetBarGroupField("labelOffset", value) end,
								},
								LabelWrapGroup = {
									type = "toggle", order = 20, name = L["Wrap"], width = "half",
									desc = L["If checked, wrap label text when it doesn't fit in the bar's width."],
									get = function(info) return GetBarGroupField("labelWrap") end,
									set = function(info, value) SetBarGroupField("labelWrap", value) end,
								},
								LabelTopGroup = {
									type = "toggle", order = 21, name = L["Top"], width = "half",
									desc = L["If checked, set \"Top\" vertical alignment for label text."],
									get = function(info) return GetBarGroupField("labelAlign") == "TOP" end,
									set = function(info, value) SetBarGroupField("labelAlign", "TOP") end,
								},
								LabelMiddleGroup = {
									type = "toggle", order = 22, name = L["Middle"], width = "half",
									desc = L["If checked, set \"Middle\" vertical alignment for label text."],
									get = function(info) return GetBarGroupField("labelAlign") == "MIDDLE" end,
									set = function(info, value) SetBarGroupField("labelAlign", "MIDDLE") end,
								},
								LabelBottomGroup = {
									type = "toggle", order = 23, name = L["Bottom"], width = "half",
									desc = L["If checked, set \"Bottom\" vertical alignment for label text."],
									get = function(info) return GetBarGroupField("labelAlign") == "BOTTOM" end,
									set = function(info, value) SetBarGroupField("labelAlign", "BOTTOM") end,
								},
								LabelCenterGroup = {
									type = "toggle", order = 24, name = L["Center"], width = "half",
									desc = L["If checked, set \"Center\" horizontal alignment for label text, otherwise align based on bar layout (only applies to bar configurations)."],
									disabled = function(info)
										local config = GetBarGroupField("configuration")
										if config then return MOD.Nest_SupportedConfigurations[config].iconOnly else return true end
									end,
									get = function(info) return GetBarGroupField("labelCenter") end,
									set = function(info, value) SetBarGroupField("labelCenter", value) end,
								},
								Space1 = { type = "description", name = "", order = 30 },
								TimeTextInset = {
									type = "range", order = 40, name = L["Time Text Inset"], min = -200, max = 200, step = 1,
									desc = L["Set horizontal inset for time text from edge of bar."],
									get = function(info) return GetBarGroupField("timeInset") end,
									set = function(info, value) SetBarGroupField("timeInset", value) end,
								},
								TimeTextOffset = {
									type = "range", order = 45, name = L["Time Text Offset"], min = -200, max = 200, step = 1,
									desc = L["Set vertical offset for time text from center of bar."],
									get = function(info) return GetBarGroupField("timeOffset") end,
									set = function(info, value) SetBarGroupField("timeOffset", value) end,
								},
								TimeNormalGroup = {
									type = "toggle", order = 46, name = L["Normal"], width = "half",
									desc = L["If checked, use normal alignment for time text, based on bar layout. Text is truncated if wider than icon or bar width, whichever is greater."],
									get = function(info) return GetBarGroupField("timeAlign") == "normal" end,
									set = function(info, value) SetBarGroupField("timeAlign", "normal") end,
								},
								TimeLeftGroup = {
									type = "toggle", order = 47, name = L["Left"], width = "half",
									desc = L["If checked, set \"Left\" alignment for time text. Text is truncated if wider than icon or bar width, whichever is greater."],
									get = function(info) return GetBarGroupField("timeAlign") == "LEFT" end,
									set = function(info, value) SetBarGroupField("timeAlign", "LEFT") end,
								},
								TimeCenterGroup = {
									type = "toggle", order = 48, name = L["Center"], width = "half",
									desc = L["If checked, set \"Center\" alignment for time text. Text is truncated if wider than icon or bar width, whichever is greater."],
									get = function(info) return GetBarGroupField("timeAlign") == "CENTER" end,
									set = function(info, value) SetBarGroupField("timeAlign", "CENTER") end,
								},
								TimeRightGroup = {
									type = "toggle", order = 49, name = L["Right"], width = "half",
									desc = L["If checked, set \"Right\" alignment for time text. Text is truncated if wider than icon or bar width, whichever is greater."],
									get = function(info) return GetBarGroupField("timeAlign") == "RIGHT" end,
									set = function(info, value) SetBarGroupField("timeAlign", "RIGHT") end,
								},
								TimeIconGroup = {
									type = "toggle", order = 50, name = L["Icon"], width = "half",
									desc = L["If checked, time text is shown on the icon instead of the bar (only applies to bar configurations)."],
									disabled = function(info)
										local config = GetBarGroupField("configuration")
										if config then return MOD.Nest_SupportedConfigurations[config].iconOnly else return true end
									end,
									get = function(info) return GetBarGroupField("timeIcon") end,
									set = function(info, value) SetBarGroupField("timeIcon", value) end,
								},
								Space2 = { type = "description", name = "", order = 55 },
								IconTextInset = {
									type = "range", order = 60, name = L["Icon Text Inset"], min = -200, max = 200, step = 1,
									desc = L["Set horizontal inset for icon text from middle of icon."],
									get = function(info) return GetBarGroupField("iconInset") end,
									set = function(info, value) SetBarGroupField("iconInset", value) end,
								},
								IconTextOffset = {
									type = "range", order = 65, name = L["Icon Text Offset"], min = -200, max = 200, step = 1,
									desc = L["Set vertical offset for icon text from center of icon."],
									get = function(info) return GetBarGroupField("iconOffset") end,
									set = function(info, value) SetBarGroupField("iconOffset", value) end,
								},
								IconTextHide = {
									type = "toggle", order = 66, name = L["Hide"], width = "half",
									desc = L["If checked, hide count overlay text on icon."],
									get = function(info) return GetBarGroupField("iconHide") end,
									set = function(info, value) SetBarGroupField("iconHide", value) end,
								},
								IconTextLeft = {
									type = "toggle", order = 67, name = L["Left"], width = "half",
									desc = L["If checked, set \"Left\" alignment for icon text."],
									get = function(info) return GetBarGroupField("iconAlign") == "LEFT" end,
									set = function(info, value) SetBarGroupField("iconAlign", "LEFT") end,
								},
								IconTextCenter = {
									type = "toggle", order = 68, name = L["Center"], width = "half",
									desc = L["If checked, set \"Center\" alignment for icon text."],
									get = function(info) return GetBarGroupField("iconAlign") == "CENTER" end,
									set = function(info, value) SetBarGroupField("iconAlign", "CENTER") end,
								},
								IconTextRight = {
									type = "toggle", order = 69, name = L["Right"], width = "half",
									desc = L["If checked, set \"Right\" alignment for icon text."],
									get = function(info) return GetBarGroupField("iconAlign") == "RIGHT" end,
									set = function(info, value) SetBarGroupField("iconAlign", "RIGHT") end,
								},
								Space3 = { type = "description", name = "", order = 80 },
								AdjustLabelWidth = {
									type = "toggle", order = 81, name = L["Adjust Label Width"],
									desc = L["If checked, adjust the label width (only applies to bar configurations and required for word wrap)."],
									hidden = function(info)
										local config = GetBarGroupField("configuration")
										if config and MOD.Nest_SupportedConfigurations[config].iconOnly then return true end
										return false
									end,
									get = function(info) return GetBarGroupField("labelAdjust") end,
									set = function(info, value) SetBarGroupField("labelAdjust", value) end,
								},
								AutoLabelWidth = {
									type = "toggle", order = 82, name = L["Auto Adjust"],
									desc = L["If checked, automatically adjust label width to not overlap horizontally with time value."],
									hidden = function(info)
										local config = GetBarGroupField("configuration")
										if config and MOD.Nest_SupportedConfigurations[config].iconOnly then return true end
										return false
									end,
									disabled = function(info) return not GetBarGroupField("labelAdjust") end,
									get = function(info) return GetBarGroupField("labelAuto") end,
									set = function(info, value) SetBarGroupField("labelAuto", value) end,
								},
								SetLabelWidth = {
									type = "range", order = 85, name = L["Label Width"], min = 1, max = 100, step = 1,
									desc = L["Set label width as percentage of bar width."],
									hidden = function(info)
										local config = GetBarGroupField("configuration")
										if config and MOD.Nest_SupportedConfigurations[config].iconOnly then return true end
										return false
									end,
									disabled = function(info) return not GetBarGroupField("labelAdjust") or GetBarGroupField("labelAuto") end,
									get = function(info) return GetBarGroupField("labelWidth") end,
									set = function(info, value) SetBarGroupField("labelWidth", value) end,
								},
							},
						},
						AnchorGroup = {
							type = "group", order = 40, name = L["Attachment"], inline = true,
							args = {
								ParentFrame = {
									type = "input", order = 5, name = L["Parent Frame"],
									desc = L["Enter name of parent frame for this bar group (leave blank to use default)."],
									validate = function(info, n) if not n or (n == "") or GetClickFrame(n) then return true end end,
									get = function(info) return GetBarGroupField("parentFrame") end,
									set = function(info, value) if value == "" then value = nil end; SetBarGroupField("parentFrame", value) end,
								},
								AnchorFrame = {
									type = "input", order = 10, name = L["Anchor Frame"],
									desc = L["Enter name of anchor frame to attach to (leave blank to enable bar group attachment)."],
									validate = function(info, n) if not n or (n == "") or GetClickFrame(n) then return true end end,
									get = function(info) return GetBarGroupField("anchorFrame") end,
									set = function(info, value) if value == "" then value = nil end; SetBarGroupField("anchorFrame", value) end,
								},
								AnchorPoint = {
									type = "select", order = 20, name = L["Anchor Point"],
									desc = L["Select point on anchor frame to attach to."],
									disabled = function(info) return not GetBarGroupField("anchorFrame") end,
									get = function(info) return GetBarGroupField("anchorPoint") or "CENTER" end,
									set = function(info, value) SetBarGroupField("anchorPoint", value) end,
									values = function(info) return anchorPoints end,
									style = "dropdown",
								},
								FrameStack = {
									type = "execute", order = 22, name = L["Frame Stack"],
									desc = L["Toggle showing Blizzard's frame stack tooltips."],
									func = function(info) UIParentLoadAddOn("Blizzard_DebugTools"); FrameStackTooltip_Toggle() end,
								},
								Space1 = { type = "description", name = "", order = 25 },
								Anchor = {
									type = "select", order = 30, name = L["Bar Group"],
									desc = L["Select a bar group to attach to (for independent position, attach to self)."],
									disabled = function(info) return GetBarGroupField("anchorFrame") end,
									get = function(info) return GetBarGroupAnchor() end,
									set = function(info, value) SetBarGroupAnchor(value) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
								Empty = {
									type = "toggle", order = 40, name = L["Empty"], width = "half",
									desc = L["If checked, offsets are not applied if the selected bar group is empty."],
									disabled = function(info) return not GetBarGroupField("anchor") end,
									get = function(info) return GetBarGroupField("anchorEmpty") end,
									set = function(info, value) SetBarGroupField("anchorEmpty", value) end,
								},
								Relative = {
									type = "toggle", order = 42, name = L["Last Bar"], width = "half",
									desc = L["If checked, position is relative to last bar/icon in the selected bar group."],
									disabled = function() return not GetBarGroupField("anchor") end,
									get = function(info) return GetBarGroupField("anchorLastBar") end,
									set = function(info, value) SetBarGroupField("anchorLastBar", value) end,
								},
								WrapRow = {
									type = "toggle", order = 45, name = L["By Row"], width = "half",
									desc = L["When wrap is enabled in the selected bar group, position is relative to last bar/icon in row closest to the anchor."],
									disabled = function() return not GetBarGroupField("anchor") or not GetBarGroupField("anchorLastBar") end,
									get = function(info) return GetBarGroupField("anchorRow") end,
									set = function(info, value) SetBarGroupField("anchorRow", value); SetBarGroupField("anchorColumn", not value) end,
								},
								WrapColumn = {
									type = "toggle", order = 50, name = L["By Column"],
									desc = L["When wrap is enabled in the selected bar group, position is relative to last bar/icon in column closest to the anchor."],
									disabled = function() return not GetBarGroupField("anchor") or not GetBarGroupField("anchorLastBar") end,
									get = function(info) return GetBarGroupField("anchorColumn") end,
									set = function(info, value) SetBarGroupField("anchorColumn", value); SetBarGroupField("anchorRow", not value) end,
								},
								Space2 = { type = "description", name = "", order = 60 },
								OffsetX = {
									type = "range", order = 70, name = L["Offset X"], min = -1000, max = 1000, step = 0.01,
									desc = L["Set horizontal offset from the selected bar group."],
									disabled = function(info) return not GetBarGroupField("anchor") and not GetBarGroupField("anchorFrame") end,
									get = function(info) return GetBarGroupField("anchorX") end,
									set = function(info, value) SetBarGroupField("anchorX", value) end,
								},
								OffsetY = {
									type = "range", order = 80, name = L["Offset Y"], min = -1000, max = 1000, step = 0.01,
									desc = L["Set vertical offset from the selected bar group."],
									disabled = function(info) return not GetBarGroupField("anchor") and not GetBarGroupField("anchorFrame") end,
									get = function(info) return GetBarGroupField("anchorY") end,
									set = function(info, value) SetBarGroupField("anchorY", value) end,
								},
								ResetAnchor = {
									type = "execute", order = 90, name = L["Reset"], width = "half",
									desc = L["Reset attachment options."],
									func = function(info) SetBarGroupAnchor(nil) end,
								},
							},
						},
						PositionGroup = {
							type = "group", order = 50, name = L["Display Position"], inline = true,
							disabled = function(info) return GetBarGroupField("anchor") or GetBarGroupField("anchorFrame") end,
							args = {
								Horizontal = {
									type = "range", order = 10, name = L["Horizontal"], min = 0, max = 100, step = 0.01,
									desc = L["Set horizontal position as percentage of overall width (cannot move beyond edge of display)."],
									get = function(info) return GetBarGroupField("pointX") * 100 end,
									set = function(info, value) SetBarGroupField("pointXR", nil); SetBarGroupField("pointX", value / 100) end, -- order important!
								},
								Vertical = {
									type = "range", order = 20, name = L["Vertical"], min = 0, max = 100, step = 0.01,
									desc = L["Set vertical position as percentage of overall height (cannot move beyond edge of display)."],
									get = function(info) return GetBarGroupField("pointY") * 100 end,
									set = function(info, value) SetBarGroupField("pointYT", nil); SetBarGroupField("pointY", value / 100) end, -- order important!
								},
							},
						},
					},
				},
				AppearanceTab = {
					type = "group", order = 45, name = L["Appearance"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() or GetBarGroupField("merged") end,
					args = {
						FontsGroup = {
							type = "group", order = 20, name = L["Fonts and Textures"], inline = true,
							args = {
								UseDefaultsGroup = {
									type = "toggle", order = 1, name = L["Use Defaults"],
									desc = L["If checked, fonts and textures use the default values."],
									get = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
									set = function(info, value) SetBarGroupField("useDefaultFontsAndTextures", value) end,
								},
								RestoreDefaults = {
									type = "execute", order = 3, name = L["Restore Defaults"],
									desc = L["Reset fonts and textures for this bar group back to the current defaults."],
									disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
									func = function(info) MOD:CopyFontsAndTextures(MOD.db.global.Defaults, GetBarGroupEntry()); MOD:UpdateAllBarGroups() end,
								},
								CopyFromGroup = {
									type = "select", order = 4, name = L["Copy From"],
									desc = L["Select bar group to copy font and texture settings from."],
									disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
									get = function(info) return nil end,
									set = function(info, value) CopyBarGroupFontsAndTextures(GetBarGroupList()[value]) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
								LabelText = {
									type = "group", order = 21, name = L["Label Text"], inline = true,
									args = {
										LabelFont = {
											type = "select", order = 10, name = L["Font"],
											desc = L["Select font."],
											dialogControl = 'LSM30_Font',
											values = AceGUIWidgetLSMlists.font,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											validate = ValidateFontChange,
											get = function(info) return GetBarGroupField("labelFont") end,
											set = function(info, value) SetBarGroupField("labelFont", value) end,
										},
										LabelFontSize = {
											type = "range", order = 15, name = L["Font Size"], min = 5, max = 50, step = 1,
											desc = L["Set font size."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelFSize") end,
											set = function(info, value) SetBarGroupField("labelFSize", value) end,
										},
										LabelAlpha = {
											type = "range", order = 20, name = L["Opacity"], min = 0, max = 1, step = 0.05,
											desc = L["Set text opacity."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelAlpha") end,
											set = function(info, value) SetBarGroupField("labelAlpha", value) end,
										},
										LabelColor = {
											type = "color", order = 25, name = L["Color"], hasAlpha = false, width = "half",
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info)
												local t = GetBarGroupField("labelColor")
												if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("labelColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("labelColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										Space = { type = "description", name = "", order = 30 },
										LabelOutline = {
											type = "toggle", order = 35, name = L["Outline"], width = "half",
											desc = L["Add black outline."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelOutline") end,
											set = function(info, value) SetBarGroupField("labelOutline", value) end,
										},
										LabelThick = {
											type = "toggle", order = 40, name = L["Thick"], width = "half",
											desc = L["Add thick black outline."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelThick") end,
											set = function(info, value) SetBarGroupField("labelThick", value) end,
										},
										LabelMono = {
											type = "toggle", order = 45, name = L["Mono"], width = "half",
											desc = L["Render font without antialiasing."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelMono") end,
											set = function(info, value) SetBarGroupField("labelMono", value) end,
										},
										LabelShadow = {
											type = "toggle", order = 50, name = L["Shadow"], width = "half",
											desc = L["Show shadow with text."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelShadow") end,
											set = function(info, value) SetBarGroupField("labelShadow", value) end,
										},
										LabelSpecial = {
											type = "toggle", order = 55, name = L["Border"], width = "half",
											desc = L["Use icon border color for text."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("labelSpecial") end,
											set = function(info, value) SetBarGroupField("labelSpecial", value) end,
										},
									},
								},
								TimeText = {
									type = "group", order = 31, name = L["Time Text"], inline = true,
									args = {
										TimeFont = {
											type = "select", order = 10, name = L["Font"],
											desc = L["Select font."],
											dialogControl = 'LSM30_Font',
											values = AceGUIWidgetLSMlists.font,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											validate = ValidateFontChange,
											get = function(info) return GetBarGroupField("timeFont") end,
											set = function(info, value) SetBarGroupField("timeFont", value) end,
										},
										TimeFontSize = {
											type = "range", order = 15, name = L["Font Size"], min = 5, max = 50, step = 1,
											desc = L["Set font size."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeFSize") end,
											set = function(info, value) SetBarGroupField("timeFSize", value) end,
										},
										TimeAlpha = {
											type = "range", order = 20, name = L["Opacity"], min = 0, max = 1, step = 0.05,
											desc = L["Set text opacity."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeAlpha") end,
											set = function(info, value) SetBarGroupField("timeAlpha", value) end,
										},
										TimeColor = {
											type = "color", order = 25, name = L["Color"], hasAlpha = false, width = "half",
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info)
												local t = GetBarGroupField("timeColor")
												if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("timeColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("timeColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										Space = { type = "description", name = "", order = 30 },
										TimeOutline = {
											type = "toggle", order = 35, name = L["Outline"], width = "half",
											desc = L["Add black outline."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeOutline") end,
											set = function(info, value) SetBarGroupField("timeOutline", value) end,
										},
										TimeThick = {
											type = "toggle", order = 40, name = L["Thick"], width = "half",
											desc = L["Add thick black outline."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeThick") end,
											set = function(info, value) SetBarGroupField("timeThick", value) end,
										},
										TimeMono = {
											type = "toggle", order = 45, name = L["Mono"], width = "half",
											desc = L["Render font without antialiasing."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeMono") end,
											set = function(info, value) SetBarGroupField("timeMono", value) end,
										},
										TimeShadow = {
											type = "toggle", order = 50, name = L["Shadow"], width = "half",
											desc = L["Show shadow with text."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeShadow") end,
											set = function(info, value) SetBarGroupField("timeShadow", value) end,
										},
										TimeSpecial = {
											type = "toggle", order = 55, name = L["Border"], width = "half",
											desc = L["Use icon border color for text."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("timeSpecial") end,
											set = function(info, value) SetBarGroupField("timeSpecial", value) end,
										},
									},
								},
								IconText = {
									type = "group", order = 41, name = L["Icon Text"], inline = true,
									args = {
										IconFont = {
											type = "select", order = 10, name = L["Font"],
											desc = L["Select font."],
											dialogControl = 'LSM30_Font',
											values = AceGUIWidgetLSMlists.font,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											validate = ValidateFontChange,
											get = function(info) return GetBarGroupField("iconFont") end,
											set = function(info, value) SetBarGroupField("iconFont", value) end,
										},
										IconFontSize = {
											type = "range", order = 15, name = L["Font Size"], min = 5, max = 50, step = 1,
											desc = L["Set font size."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconFSize") end,
											set = function(info, value) SetBarGroupField("iconFSize", value) end,
										},
										IconAlpha = {
											type = "range", order = 20, name = L["Opacity"], min = 0, max = 1, step = 0.05,
											desc = L["Set text opacity."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconAlpha") end,
											set = function(info, value) SetBarGroupField("iconAlpha", value) end,
										},
										IconColor = {
											type = "color", order = 25, name = L["Color"], hasAlpha = false, width = "half",
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info)
												local t = GetBarGroupField("iconColor")
												if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("iconColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("iconColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										Space = { type = "description", name = "", order = 30 },
										IconOutline = {
											type = "toggle", order = 35, name = L["Outline"], width = "half",
											desc = L["Add black outline."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconOutline") end,
											set = function(info, value) SetBarGroupField("iconOutline", value) end,
										},
										IconThick = {
											type = "toggle", order = 40, name = L["Thick"], width = "half",
											desc = L["Add thick black outline."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconThick") end,
											set = function(info, value) SetBarGroupField("iconThick", value) end,
										},
										IconMono = {
											type = "toggle", order = 45, name = L["Mono"], width = "half",
											desc = L["Render font without antialiasing."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconMono") end,
											set = function(info, value) SetBarGroupField("iconMono", value) end,
										},
										IconShadow = {
											type = "toggle", order = 50, name = L["Shadow"], width = "half",
											desc = L["Show shadow with text."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconShadow") end,
											set = function(info, value) SetBarGroupField("iconShadow", value) end,
										},
										IconSpecial = {
											type = "toggle", order = 55, name = L["Border"], width = "half",
											desc = L["Use icon border color for text."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("iconSpecial") end,
											set = function(info, value) SetBarGroupField("iconSpecial", value) end,
										},
									},
								},
								PanelsBorders = {
									type = "group", order = 51, name = L["Panels and Borders"], inline = true,
									args = {
										EnablePanel = {
											type = "toggle", order = 10, name = L["Background Panel"],
											desc = L["Enable display of a background panel behind bar group."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("backdropEnable") end,
											set = function(info, value) SetBarGroupField("backdropEnable", value) end,
										},
										PanelTexture = {
											type = "select", order = 15, name = L["Panel Texture"],
											desc = L["Select texture to display in panel behind bar group."],
											dialogControl = 'LSM30_Background',
											values = AceGUIWidgetLSMlists.background,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("backdropPanel") end,
											set = function(info, value) SetBarGroupField("backdropPanel", value) end,
										},
										PanelPadding = {
											type = "range", order = 20, name = L["Padding"], min = 0, max = 32, step = 0.1,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Adjust padding between bar group and the background panel and border."],
											get = function(info) return GetBarGroupField("backdropPadding") end,
											set = function(info, value) SetBarGroupField("backdropPadding", value) end,
										},
										PanelColor = {
											type = "color", order = 25, name = L["Panel Color"], hasAlpha = true,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Set fill color for the panel."],
											get = function(info)
												local t = GetBarGroupField("backdropFill")
												if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("backdropFill")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("backdropFill", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										Space1 = { type = "description", name = "", order = 30 },
										BackdropOffsetX = {
											type = "range", order = 31, name = L["Offset X"], min = -50, max = 50, step = 1,
											desc = L["Adjust horizontal position of the panel."],
											get = function(info) return GetBarGroupField("backdropOffsetX") end,
											set = function(info, value) SetBarGroupField("backdropOffsetX", value) end,
										},
										BackdropOffsetY = {
											type = "range", order = 32, name = L["Offset Y"], min = -50, max = 50, step = 1,
											desc = L["Adjust vertical position of the panel."],
											get = function(info) return GetBarGroupField("backdropOffsetY") end,
											set = function(info, value) SetBarGroupField("backdropOffsetY", value) end,
										},
										BackdropPadW = {
											type = "range", order = 33, name = L["Extra Width"], min = 0, max = 50, step = 1,
											desc = L["Adjust width of the panel."],
											get = function(info) return GetBarGroupField("backdropPadW") end,
											set = function(info, value) SetBarGroupField("backdropPadW", value) end,
										},
										BackdropPadH = {
											type = "range", order = 34, name = L["Extra Height"], min = 0, max = 50, step = 1,
											desc = L["Adjust height of the panel."],
											get = function(info) return GetBarGroupField("backdropPadH") end,
											set = function(info, value) SetBarGroupField("backdropPadH", value) end,
										},
										Space2 = { type = "description", name = "", order = 40 },
										BackdropTexture = {
											type = "select", order = 41, name = L["Background Border"],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Select border to display behind bar group (select None to disable border)."],
											dialogControl = 'LSM30_Border',
											values = AceGUIWidgetLSMlists.border,
											get = function(info) return GetBarGroupField("backdropTexture") end,
											set = function(info, value) SetBarGroupField("backdropTexture", value) end,
										},
										BackdropWidth = {
											type = "range", order = 42, name = L["Edge Size"], min = 0, max = 32, step = 0.01,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Adjust size of the border's edge."],
											get = function(info) return GetBarGroupField("backdropWidth") end,
											set = function(info, value) SetBarGroupField("backdropWidth", value) end,
										},
										BackdropInset = {
											type = "range", order = 45, name = L["Inset"], min = -16, max = 16, step = 0.01,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Adjust inset from the border to background panel's fill color."],
											get = function(info) return GetBarGroupField("backdropInset") end,
											set = function(info, value) SetBarGroupField("backdropInset", value) end,
										},
										BackdropColor = {
											type = "color", order = 50, name = L["Border Color"], hasAlpha = true,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Set color for the border."],
											get = function(info)
												local t = GetBarGroupField("backdropColor")
												if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("backdropColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("backdropColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
										Space2 = { type = "description", name = "", order = 55 },
										BorderTexture = {
											type = "select", order = 60, name = L["Bar Border"],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Select border for bars in the bar group (select None to disable border)."],
											dialogControl = 'LSM30_Border',
											values = AceGUIWidgetLSMlists.border,
											get = function(info) return GetBarGroupField("borderTexture") end,
											set = function(info, value) SetBarGroupField("borderTexture", value) end,
										},
										BorderWidth = {
											type = "range", order = 65, name = L["Edge Size"], min = 0, max = 32, step = 0.01,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Adjust size of the border's edge."],
											get = function(info) return GetBarGroupField("borderWidth") end,
											set = function(info, value) SetBarGroupField("borderWidth", value) end,
										},
										BorderOffset = {
											type = "range", order = 70, name = L["Offset"], min = -16, max = 16, step = 0.01,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Adjust offset to the border from the bar."],
											get = function(info) return GetBarGroupField("borderOffset") end,
											set = function(info, value) SetBarGroupField("borderOffset", value) end,
										},
										BorderColor = {
											type = "color", order = 75, name = L["Border Color"], hasAlpha = true,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											desc = L["Set color for the border."],
											get = function(info)
												local t = GetBarGroupField("borderColor")
												if t then return t.r, t.g, t.b, t.a else return 0, 0, 0, 1 end
											end,
											set = function(info, r, g, b, a)
												local t = GetBarGroupField("borderColor")
												if t then t.r = r; t.g = g; t.b = b; t.a = a else
													t = { r = r, g = g, b = b, a = a }; SetBarGroupField("borderColor", t) end
												MOD:UpdateAllBarGroups()
											end,
										},
									},
								},
								Bars = {
									type = "group", order = 61, name = L["Bars and Icons"], inline = true,
									args = {
										ForegroundTexture = {
											type = "select", order = 10, name = L["Bar Foreground Texture"],
											desc = L["Select foreground texture for bars."],
											dialogControl = 'LSM30_Statusbar',
											values = AceGUIWidgetLSMlists.statusbar,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("texture") end,
											set = function(info, value) SetBarGroupField("texture", value) end,
										},
										ForegroundAlpha = {
											type = "range", order = 15, name = L["Foreground Opacity"], min = 0, max = 1, step = 0.05,
											desc = L["Set foreground opacity for bars."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("fgAlpha") end,
											set = function(info, value) SetBarGroupField("fgAlpha", value) end,
										},
										ForegroundSaturation = {
											type = "range", order = 20, name = L["Foreground Saturation"], min = -1, max = 1, step = 0.05,
											desc = L["Set saturation for foreground colors."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("fgSaturation") end,
											set = function(info, value) SetBarGroupField("fgSaturation", value) end,
										},
										ForegroundBrightness = {
											type = "range", order = 25, name = L["Foreground Brightness"], min = -1, max = 1, step = 0.05,
											desc = L["Set brightness for foreground colors."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("fgBrightness") end,
											set = function(info, value) SetBarGroupField("fgBrightness", value) end,
										},
										Space1 = { type = "description", name = "", order = 30 },
										BackgroundTexture = {
											type = "select", order = 35, name = L["Bar Background Texture"],
											desc = L["Select background texture for bars."],
											dialogControl = 'LSM30_Statusbar',
											values = AceGUIWidgetLSMlists.statusbar,
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("bgtexture") end,
											set = function(info, value) SetBarGroupField("bgtexture", value) end,
										},
										Background = {
											type = "range", order = 40, name = L["Background Opacity"], min = 0, max = 1, step = 0.05,
											desc = L["Set background opacity for bars."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("bgAlpha") end,
											set = function(info, value) SetBarGroupField("bgAlpha", value) end,
										},
										BackgroundSaturation = {
											type = "range", order = 45, name = L["Background Saturation"], min = -1, max = 1, step = 0.05,
											desc = L["Set saturation for foreground colors."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("bgSaturation") end,
											set = function(info, value) SetBarGroupField("bgSaturation", value) end,
										},
										BackgroundBrightness = {
											type = "range", order = 50, name = L["Background Brightness"], min = -1, max = 1, step = 0.05,
											desc = L["Set brightness for foreground colors."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("bgBrightness") end,
											set = function(info, value) SetBarGroupField("bgBrightness", value) end,
										},
										Space2 = { type = "description", name = "", order = 55 },
										NormalAlpha = {
											type = "range", order = 60, name = L["Opacity (Not Combat)"], min = 0, max = 1, step = 0.05,
											desc = L["Set opacity for bars/icons when not in combat."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("alpha") end,
											set = function(info, value) SetBarGroupField("alpha", value) end,
										},
										CombatAlpha = {
											type = "range", order = 65, name = L["Opacity (In Combat)"], min = 0, max = 1, step = 0.05,
											desc = L["Set opacity for bars/icons when in combat."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("combatAlpha") end,
											set = function(info, value) SetBarGroupField("combatAlpha", value) end,
										},
										IconBorderSaturation = {
											type = "range", order = 70, name = L["Icon Border Saturation"], min = -1, max = 1, step = 0.05,
											desc = L["Set saturation for icon border colors."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("borderSaturation") end,
											set = function(info, value) SetBarGroupField("borderSaturation", value) end,
										},
										IconBorderBrightness = {
											type = "range", order = 75, name = L["Icon Border Brightness"], min = -1, max = 1, step = 0.05,
											desc = L["Set brightness for icon border colors."],
											disabled = function(info) return GetBarGroupField("useDefaultFontsAndTextures") end,
											get = function(info) return GetBarGroupField("borderBrightness") end,
											set = function(info, value) SetBarGroupField("borderBrightness", value) end,
										},
									},
								},
							},
						},
						ColorsGroup = {
							type = "group", order = 30, name = L["Standard Colors"], inline = true,
							args = {
								UseDefaultsGroup = {
									type = "toggle", order = 1, name = L["Use Defaults"],
									desc = L["If checked, colors use the default values."],
									get = function(info) return GetBarGroupField("useDefaultColors") end,
									set = function(info, value) SetBarGroupField("useDefaultColors", value) end,
								},
								RestoreDefaults = {
									type = "execute", order = 3, name = L["Restore Defaults"],
									desc = L["Reset standard colors for this bar group back to the current defaults."],
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									func = function(info) local bg = GetBarGroupEntry()
										bg.buffColor = nil; bg.debuffColor = nil; bg.cooldownColor = nil
										bg.notificationColor = nil; bg.brokerColor = nil; bg.valueColor = nil
										bg.poisonColor = nil; bg.curseColor = nil; bg.magicColor = nil
										bg.diseaseColor = nil; bg.stealColor = nil; bg.enrageColor = nil
										MOD:UpdateAllBarGroups()
									end,
								},
								CopyFromGroup = {
									type = "select", order = 4, name = L["Copy From"],
									desc = L["Select bar group to copy standard colors from."],
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) return nil end,
									set = function(info, value) CopyBarGroupStandardColors(GetBarGroupList()[value]) end,
									values = function(info) return GetBarGroupList() end,
									style = "dropdown",
								},
								Space0 = { type = "description", name = "", order = 5 },
								ColorText = { type = "description", name = L["Bar Colors:"], order = 7, width = "half" },
								NotificationColor = {
									type = "color", order = 13, name = L["Notify"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("notificationColor") or MOD.db.global.DefaultNotificationColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("notificationColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("notificationColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								BrokerColor = {
									type = "color", order = 14, name = L["Broker"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("brokerColor") or MOD.db.global.DefaultBrokerColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("brokerColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("brokerColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								ValueColor = {
									type = "color", order = 15, name = L["Value"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("valueColor") or MOD.db.global.DefaultValueColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("valueColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("valueColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								BuffColor = {
									type = "color", order = 16, name = L["Buff"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("buffColor") or MOD.db.global.DefaultBuffColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("buffColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("buffColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								DebuffColor = {
									type = "color", order = 17, name = L["Debuff"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("debuffColor") or MOD.db.global.DefaultDebuffColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("debuffColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("debuffColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								CooldownColor = {
									type = "color", order = 18, name = L["Cooldown"], hasAlpha = false,
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("cooldownColor") or MOD.db.global.DefaultCooldownColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("cooldownColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("cooldownColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								Space1 = { type = "description", name = "", order = 20 },
								DebuffText = { type = "description", name = L["Special Colors:"], order = 25, width = "half" },
								PoisonColor = {
									type = "color", order = 30, name = L["Poison"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("poisonColor") or MOD.db.global.DefaultPoisonColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("poisonColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("poisonColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								CurseColor = {
									type = "color", order = 31, name = L["Curse"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("curseColor") or MOD.db.global.DefaultCurseColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("curseColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("curseColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								MagicColor = {
									type = "color", order = 32, name = L["Magic"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("magicColor") or MOD.db.global.DefaultMagicColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("magicColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("magicColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								DiseaseColor = {
									type = "color", order = 33, name = L["Disease"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("diseaseColor") or MOD.db.global.DefaultDiseaseColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("diseaseColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("diseaseColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								EnrageColor = {
									type = "color", order = 34, name = L["Enrage"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("enrageColor") or MOD.db.global.DefaultEnrageColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("enrageColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("enrageColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								StealColor = {
									type = "color", order = 35, name = L["Stealable"], hasAlpha = false,
									disabled = function(info) return GetBarGroupField("useDefaultColors") end,
									get = function(info) local t = GetBarGroupField("stealColor") or MOD.db.global.DefaultStealColor
										return t.r, t.g, t.b, t.a end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("stealColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("stealColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
							},
						},
						BarColorGroup = {
							type = "group", order = 40, name = L["Bar Color Scheme"], inline = true,
							args = {
								ForegroundText = { type = "description", name = L["Foreground:"], order = 1, width = "half" },
								StandardColors = {
									type = "toggle", order = 10, name = "Standard Colors",
									desc = L["Show bars in default colors for their type, including special debuff colors when applicable."],
									get = function(info) return GetBarGroupField("barColors") == "Standard" end,
									set = function(info, value) SetBarGroupField("barColors", "Standard") end,
								},
								CustomForeground = {
									type = "toggle", order = 15, name = L["Custom"], width = "half",
									desc = L["Color the bars with a custom color."],
									get = function(info) return GetBarGroupField("barColors") == "Custom" end,
									set = function(info, value) SetBarGroupField("barColors", "Custom") end,
								},
								ForegroundColor = {
									type = "color", order = 16, name = L["Color"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("barColors") ~= "Custom" end,
									get = function(info)
										local t = GetBarGroupField("fgColor")
										if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
									end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("fgColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("fgColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								SpellColors = {
									type = "toggle", order = 30, name = L["Spell"], width = "half",
									desc = L["Show bars using spell colors when possible, otherwise use default bar colors."],
									get = function(info) return GetBarGroupField("barColors") == "Spell" end,
									set = function(info, value) SetBarGroupField("barColors", "Spell") end,
								},
								ClassColors = {
									type = "toggle", order = 31, name = L["Class"], width = "half",
									desc = L["Show bars using the player's class color."],
									get = function(info) return GetBarGroupField("barColors") == "Class" end,
									set = function(info, value) SetBarGroupField("barColors", "Class") end,
								},
								spacer1 = { type = "description", name = "", order = 40 },
								BackgroundText = { type = "description", name = L["Background:"], order = 41, width = "half" },
								NormalBackground = {
									type = "toggle", order = 50, name = L["Same as Foreground"],
									desc = L["Color the background the same as the foreground."],
									get = function(info) return GetBarGroupField("bgColors") == "Normal" end,
									set = function(info, value) SetBarGroupField("bgColors", "Normal") end,
								},
								CustomBackground = {
									type = "toggle", order = 60, name = L["Custom"], width = "half",
									desc = L["Color the background with a custom color."],
									get = function(info) return GetBarGroupField("bgColors") == "Custom" end,
									set = function(info, value) SetBarGroupField("bgColors", "Custom") end,
								},
								BackgroundColor = {
									type = "color", order = 70, name = L["Color"], hasAlpha = false, width = "half",
									disabled = function(info) return GetBarGroupField("bgColors") ~= "Custom" end,
									get = function(info)
										local t = GetBarGroupField("bgColor")
										if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
									end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("bgColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("bgColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								spacer2 = { type = "description", name = "", order = 80 },
								IconBorderText = { type = "description", name = L["Icon Border:"], order = 81, width = "half" },
								NormalIcon = {
									type = "toggle", order = 85, name = L["Same as Foreground"],
									desc = L["Color the icon border the same as the bar foreground."],
									get = function(info) return GetBarGroupField("iconColors") == "Normal" end,
									set = function(info, value) SetBarGroupField("iconColors", "Normal") end,
								},
								CustomIcon = {
									type = "toggle", order = 86, name = L["Custom"], width = "half",
									desc = L["Color the icon border with a custom color."],
									get = function(info) return GetBarGroupField("iconColors") == "Custom" end,
									set = function(info, value) SetBarGroupField("iconColors", "Custom") end,
								},
								IconBorderColor = {
									type = "color", order = 87, name = L["Color"], hasAlpha = true, width = "half",
									disabled = function(info) return GetBarGroupField("iconColors") ~= "Custom" end,
									get = function(info)
										local t = GetBarGroupField("iconBorderColor")
										if t then return t.r, t.g, t.b, t.a else return 1, 1, 1, 1 end
									end,
									set = function(info, r, g, b, a)
										local t = GetBarGroupField("iconBorderColor")
										if t then t.r = r; t.g = g; t.b = b; t.a = a else
											t = { r = r, g = g, b = b, a = a }; SetBarGroupField("iconBorderColor", t) end
										MOD:UpdateAllBarGroups()
									end,
								},
								SpecialIcon = {
									type = "toggle", order = 90, name = L["Special"], width = "half",
									desc = L["Color the icon border special string"],
									get = function(info) return GetBarGroupField("iconColors") == "Debuffs" end,
									set = function(info, value) SetBarGroupField("iconColors", "Debuffs") end,
								},
								PlayerIcon = {
									type = "toggle", order = 91, name = L["Player"], width = "half",
									desc = L["Color icon border same as bar foreground for spells cast by players, color same as bar background for non-player spells."],
									get = function(info) return GetBarGroupField("iconColors") == "Player" end,
									set = function(info, value) SetBarGroupField("iconColors", "Player") end,
								},
								NoneIcon = {
									type = "toggle", order = 95, name = L["None"], width = "half",
									desc = L["Do not color the icon border."],
									get = function(info) return GetBarGroupField("iconColors") == "None" end,
									set = function(info, value) SetBarGroupField("iconColors", "None") end,
								},
								spacer3 = { type = "description", name = "", order = 100 },
								IconColorText = { type = "description", name = L["Icon Color:"], order = 101, width = "half" },
								Desaturate = {
									type = "toggle", order = 105, name = L["Desaturate Non-Player"],
									desc = L["Desaturate if action not cast by player."],
									get = function(info) return GetBarGroupField("desaturate") end,
									set = function(info, value) SetBarGroupField("desaturate", value) end,
								},
								DesaturateFriend = {
									type = "toggle", order = 105, name = L["Only Friendly Target"],
									desc = L["Desaturate only if the current target is a friend."],
									disabled = function(info) return not GetBarGroupField("desaturate") end,
									get = function(info) return GetBarGroupField("desaturateFriend") end,
									set = function(info, value) SetBarGroupField("desaturateFriend", value) end,
								},
							},
						},
					},
				},
				TimerOptionsTab = {
					type = "group", order = 50, name = L["Timer Options"],
					disabled = function(info) return InMode("Bar") end,
					hidden = function(info) return NoBarGroup() end,
					args = {
						DurationMaxGroup = {
							type = "group", order = 10, name = L["Show With Uniform Duration"], inline = true,
							args = {
								DurationCheck = {
									type = "toggle", order = 1, name = L["Enable"], width = "half",
									desc = L["Show timer bars scaled with a uniform duration (text still shows actual time left)."],
									get = function(info) return GetBarGroupField("setDuration") end,
									set = function(info, value) SetBarGroupField("setDuration", value) end,
								},
								LongDuration = {
									type = "toggle", order = 3, name = L["Only If Longer"],
									desc = L["Only scale bars if actual duration is greater than the specified uniform duration."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("setDuration") end,
									get = function(info) return GetBarGroupField("setOnlyLongDuration") end,
									set = function(info, value) SetBarGroupField("setOnlyLongDuration", value) end,
								},
								DurationMinutes = {
									type = "range", order = 5, name = L["Minutes"], min = 0, max = 120, step = 1,
									desc = L["Enter minutes in the uniform duration."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("setDuration") end,
									get = function(info) local d = GetBarGroupField("uniformDuration"); return math.floor(d / 60) end,
									set = function(info, value) local d = GetBarGroupField("uniformDuration"); SetBarGroupField("uniformDuration", (value * 60) + (d % 60)) end,
								},
								DurationSeconds = {
									type = "range", order = 7, name = L["Seconds"], min = 0, max = 59, step = 1,
									desc = L["Enter seconds in the uniform duration."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("setDuration") end,
									get = function(info) local d = GetBarGroupField("uniformDuration"); return d % 60 end,
									set = function(info, value) local d = GetBarGroupField("uniformDuration"); SetBarGroupField("uniformDuration", value + (60 * math.floor(d / 60))) end,
								},
								DurationRange = {
									type = "description", order = 9,
									disabled = function(info) return not GetBarGroupField("setDuration") end, width = "half",
									name = function(info) local d = GetBarGroupField("uniformDuration"); return string.format("      %0d:%02d", math.floor(d / 60), d % 60) end,
								},
							},
						},
						DurationLimitGroup = {
							type = "group", order = 20, name = L["Show If Unlimited Duration"], inline = true,
							args = {
								LongDurationCheck = {
									type = "toggle", order = 1, name = L["Enable"], width = "half",
									desc = L["Show bars for actions with unlimited duration (e.g., buffs that don't expire)."],
									get = function(info) return GetBarGroupField("showNoDuration") end,
									set = function(info, value) SetBarGroupField("showNoDuration", value) end,
								},
								LongDurationLimit = {
									type = "toggle", order = 10, name = L["Only Show Unlimited"],
									desc = L["Show bars for actions only if they have unlimited duration."],
									disabled = function(info) return not GetBarGroupField("showNoDuration") end,
									get = function(info) return GetBarGroupField("showOnlyNoDuration") end,
									set = function(info, value) SetBarGroupField("showOnlyNoDuration", value) end,
								},
								NoDurationFirst = {
									type = "toggle", order = 15, name = L["Unlimited As Zero"],
									desc = L["If checked, bars with unlimited duration sort as zero duration, otherwise as very long duration."],
									disabled = function(info) return not GetBarGroupField("showNoDuration") end,
									get = function(info) return GetBarGroupField("noDurationFirst") end,
									set = function(info, value) SetBarGroupField("noDurationFirst", value) end,
								},
								ForegroundBackground = {
									type = "toggle", order = 20, name = L["Show As Full Bars"],
									desc = L["If checked, bars with unlimited duration show as full bars, otherwise they show as empty bars."],
									disabled = function(info) return not GetBarGroupField("showNoDuration") end,
									get = function(info) return not GetBarGroupField("showNoDurationBackground") end,
									set = function(info, value) SetBarGroupField("showNoDurationBackground", not value) end,
								},
								ReadyReverse = {
									type = "toggle", order = 70, name = L["Ready Reverse"],
									desc = L["If checked, ready bars show with reverse of Full Bars setting."],
									hidden = function(info) return GetBarGroupField("auto") end,
									disabled = function(info) return not GetBarGroupField("showNoDuration") end,
									get = function(info) return GetBarGroupField("readyReverse") end,
									set = function(info, value) SetBarGroupField("readyReverse", value); MOD:UpdateAllBarGroups() end,
								},
							},
						},
						DurationGroup = {
							type = "group", order = 30, name = L["Check Overall Duration"], inline = true,
							args = {
								DurationCheck = {
									type = "toggle", order = 3, name = L["Enable"], width = "half",
									desc = L["Only include timer bars with a specified minimum (or maximum) duration."],
									get = function(info) return GetBarGroupField("checkDuration") end,
									set = function(info, value) SetBarGroupField("checkDuration", value) end,
								},
								DurationMinutes = {
									type = "range", order = 4, name = L["Minutes"], min = 0, max = 120, step = 1,
									desc = L["Enter minutes for overall duration check."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("checkDuration") end,
									get = function(info) local d = GetBarGroupField("filterDuration"); return math.floor(d / 60) end,
									set = function(info, value) local d = GetBarGroupField("filterDuration"); SetBarGroupField("filterDuration", (value * 60) + (d % 60)) end,
								},
								DurationSeconds = {
									type = "range", order = 5, name = L["Seconds"], min = 0, max = 59, step = 1,
									desc = L["Enter seconds for overall duration check."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("checkDuration") end,
									get = function(info) local d = GetBarGroupField("filterDuration"); return d % 60 end,
									set = function(info, value) local d = GetBarGroupField("filterDuration"); SetBarGroupField("filterDuration", value + (60 * math.floor(d / 60))) end,
								},
								DurationMinMax = {
									type = "select", order = 6, name = L["Duration"],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("checkDuration") end,
									get = function(info) if GetBarGroupField("minimumDuration") then return 1 else return 2 end end,
									set = function(info, value) if value == 1 then SetBarGroupField("minimumDuration", true) else SetBarGroupField("minimumDuration", false) end end,
									values = function(info)
										local d = GetBarGroupField("filterDuration")
										local ds = string.format("%0d:%02d", math.floor(d / 60), d % 60)
										return { "Show if " .. ds .. " or more", "Show if less than " .. ds }
									end,
									style = "dropdown",
								},
							},
						},
						TimeLeftGroup = {
							type = "group", order = 40, name = L["Check Time Left"], inline = true,
							disabled = function(info) return GetBarGroupField("showOnlyNoDuration") end,
							args = {
								TimeLeftCheck = {
									type = "toggle", order = 3, name = L["Enable"], width = "half",
									desc = L["Only show timer bars with a specified minimum (or maximum) time left."],
									get = function(info) return GetBarGroupField("checkTimeLeft") end,
									set = function(info, value) SetBarGroupField("checkTimeLeft", value) end,
								},
								TimeLeftMinutes= {
									type = "range", order = 4, name = L["Minutes"], min = 0, max = 120, step = 1,
									desc = L["Enter minutes for time left check."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("checkTimeLeft") end,
									get = function(info) local d = GetBarGroupField("filterTimeLeft"); return math.floor(d / 60) end,
									set = function(info, value) local d = GetBarGroupField("filterTimeLeft"); SetBarGroupField("filterTimeLeft", (value * 60) + (d % 60)) end,
								},
								TimeLeftSeconds = {
									type = "range", order = 5, name = L["Seconds"], min = 0, max = 59.9, step = 0.1,
									desc = L["Enter seconds for time left check."],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("checkTimeLeft") end,
									get = function(info) local d = GetBarGroupField("filterTimeLeft"); return d % 60 end,
									set = function(info, value) local d = GetBarGroupField("filterTimeLeft"); SetBarGroupField("filterTimeLeft", value + (60 * math.floor(d / 60))) end,
								},
								TimeLeftMinMax = {
									type = "select", order = 6, name = L["Time Left"],
									disabled = function(info) return NoBarGroup() or not GetBarGroupField("checkTimeLeft") end,
									get = function(info) if GetBarGroupField("minimumTimeLeft") then return 1 else return 2 end end,
									set = function(info, value) if value == 1 then SetBarGroupField("minimumTimeLeft", true) else SetBarGroupField("minimumTimeLeft", false) end end,
									values = function(info)
										local d = GetBarGroupField("filterTimeLeft")
										local ds = string.format("%0d:%02.1f", math.floor(d / 60), d % 60)
										return { "Show if " .. ds .. " or more", "Show if less than " .. ds }
									end,
									style = "dropdown",
								},
							},
						},
						TimeFormatGroup = {
							type = "group", order = 50, name = L["Time Format"],  inline = true,
							args = {
								UseDefaultsGroup = {
									type = "toggle", order = 1, name = L["Use Defaults"],
									desc = L["If checked, time format options are set to default values."],
									get = function(info) return GetBarGroupField("useDefaultTimeFormat") end,
									set = function(info, value) SetBarGroupField("useDefaultTimeFormat", value) end,
								},
								RestoreDefaults = {
									type = "execute", order = 2, name = L["Restore Defaults"],
									desc = L["Reset time format for this bar group back to the current defaults."],
									disabled = function(info) return GetBarGroupField("useDefaultTimeFormat") end,
									func = function(info) MOD:CopyTimeFormat(MOD.db.global.Defaults, GetBarGroupEntry()); MOD:UpdateAllBarGroups() end,
								},
								Space1 = { type = "description", name = "", order = 3 },
								TimeFormat = {
									type = "select", order = 10, name = L["Options"], width = "double",
									desc = L["Time format string"],
									disabled = function(info) return GetBarGroupField("useDefaultTimeFormat") end,
									get = function(info) return GetBarGroupField("timeFormat") end,
									set = function(info, value) SetBarGroupField("timeFormat", value) end,
									values = function(info)
										local bg = GetBarGroupEntry()
										local s, c = bg.timeSpaces, bg.timeCase
										return GetTimeFormatList(s, c)
									end,
									style = "dropdown",
								},
								Space2 = { type = "description", name = "", order = 15, width = "half" },
								Spaces = {
									type = "toggle", order = 20, name = L["Spaces"], width = "half",
									desc = L["Include spaces between values in time format."],
									disabled = function(info) return GetBarGroupField("useDefaultTimeFormat") end,
									get = function(info) return GetBarGroupField("timeSpaces") end,
									set = function(info, value) SetBarGroupField("timeSpaces", value) end,
								},
								Capitals = {
									type = "toggle", order = 30, name = L["Uppercase"],
									desc = L["If checked, use uppercase H, M and S in time format, otherwise use lowercase."],
									disabled = function(info) return GetBarGroupField("useDefaultTimeFormat") end,
									get = function(info) return GetBarGroupField("timeCase") end,
									set = function(info, value) SetBarGroupField("timeCase", value) end,
								},
							},
						},
					},
				},
			},
		},
]]--
	},
}
