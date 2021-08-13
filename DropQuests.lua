--[[
DropQuests
]]

---------------------------------------------------------
-- Library declaration
local ACE = LibStub("AceAddon-3.0")
local ACDB = LibStub("AceDB-3.0")
local ACDI = LibStub("MSA-AceConfigDialog-3.0")
local AGUI = LibStub("AceGUI-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local ACO = LibStub("AceDBOptions-3.0")
local HBD = LibStub("HereBeDragons-2.0")

---------------------------------------------------------
-- Addon declaration
local addonName = "DropQuests"
DropQuests = ACE:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local DropQuests = DropQuests
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)

---------------------------------------------------------
-- Variable declaration

local MAX_QUESTS = 200
local selectedQuest
local previousPlayerUiMapID

local questFrame

---------------------------------------------------------
-- Our db upvalue and db defaults
local db
local options
local defaults = {
	profile = {
		enabled	   = true,
		icon_scale	= 1.0,
		icon_alpha	= 1.0,
		icon_scale_minimap = 1.0,
		icon_alpha_minimap = 1.0,
		enabledPlugins = {
			['*'] = true,
		},
		questList = {},
	},
}


---------------------------------------------------------
-- Localize some globals
local pairs, next, type = pairs, next, type
local CreateFrame = CreateFrame

---------------------------------------------------------
-- Public functions

local function countQuests()
	local count = 0
	for _ in pairs(db.questList) do count = count + 1 end
	return count
end

function getInactiveQuestSlot()
	if db.questList == nil then
		return 1
	end
	for i = 1, MAX_QUESTS, 1 do
		if db.questList[tostring(i)] == nil then
			return i
		end
	end
end

local function addQuestToSlot(slot_number)
	print(slot_number)
	options.args.quests.args[tostring(slot_number)] = copy(quest_template)
	initializeDatabaseWithQuest(slot_number)

	ACR:RegisterOptionsTable(addonName, options, nil)
end

local function getContinentFromMap(mapID)
	local map = mapID or C_Map.GetBestMapForUnit("player")
	local mapInfo = C_Map.GetMapInfo(map)

	while mapInfo.mapType >= Enum.UIMapType.Continent do
		if mapInfo.mapType == Enum.UIMapType.Continent then
			return map
		end
		map = mapInfo.parentMapID
		mapInfo = C_Map.GetMapInfo(map)
	end

	return nil
end

local function getZoneFromMap(mapID)
	local map = mapID or C_Map.GetBestMapForUnit("player")
	local mapInfo = C_Map.GetMapInfo(map)

	while mapInfo.mapType >= Enum.UIMapType.Zone do
		if mapInfo.mapType == Enum.UIMapType.Zone then
			return map
		end
		map = mapInfo.parentMapID
		mapInfo = C_Map.GetMapInfo(map)
	end

	return nil
end

local function showHideQuest(showHide, slot_number)
	local text = showHide and "Showing" or "Hiding"
	print(text, db.questList[slot_number] and db.questList[slot_number].name and db.questList[slot_number].name or "nil", "...")
end

function initializeDatabaseWithQuest(slot_number)
	if not db.questList[tostring(slot_number)] then
		db.questList[tostring(slot_number)] = {}
	end
	db.questList[tostring(slot_number)].disabled = false
end

local function getOptionTable(slot_number)
	return options.args.quests[tostring(slot_number)]
end

function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end

---------------------------------------------------------
-- Core functions

function createQuestFrame(slot_number)
	local frame = CreateFrame("Frame", "questframe_"..slot_number, UIParent, "StatusTrackingBarTemplate")
	frame:SetPoint("CENTER")
	frame:SetSize(128, 40)
	frame:Show()
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	frame.button = CreateFrame("ItemButton", nil, frame)
	frame.button:SetPoint("LEFT", 4, 0)
	frame.button:SetItem(db.questList[slot_number].itemID)
	--frame.button:SetSize(32, 32)

	frame.StatusBar:SetMinMaxValues(0, 200)
	frame.StatusBar:SetPoint("LEFT", 44, 0)
	frame.StatusBar:SetSize(80, 16)
	frame.StatusBar:SetValue(120)
	frame.StatusBar:SetStatusBarColor(0.75, 0.75, 0.75)

	for key, value in pairs(frame.button) do
		print(key, value)
	end

	return frame
end

---------------------------------------------------------
-- Our options table

options = {
	type = "group",
	name = L[addonName],
	desc = L[addonName],
	args = {
		general = {
			type = "group",
			name = L["GeneralSettings"],
			desc = L["GeneralSettingsTooltip"],
			order = 0,
			get = function(info) return db[info.arg] end,
			set = function(info, v)
				local arg = info.arg
				db[arg] = v
			end,
			disabled = function() return not db.enabled end,
			args = {
				desc = {
					name = L["GeneralSettingsDescription"],
					type = "description",
					order = 0,
				},
				enabled = {
					type = "toggle",
					name = L["EnableDropQuests"],
					desc = L["EnableDropQuestsTooltip"],
					order = 1,
					get = function(info) return db.enabled end,
					set = function(info, v)
						db.enabled = v
						if v then DropQuests:Enable() else DropQuests:Disable() end
					end,
					disabled = false,
				},
				--[[icon_scale = {
					type = "range",
					name = L["World Map Icon Scale"],
					desc = L["The overall scale of the icons on the World Map"],
					min = 0.25, max = 2, step = 0.01,
					arg = "icon_scale",
					order = 10,
				},
				icon_alpha = {
					type = "range",
					name = L["World Map Icon Alpha"],
					desc = L["The overall alpha transparency of the icons on the World Map"],
					min = 0, max = 1, step = 0.01,
					arg = "icon_alpha",
					order = 20,
				},
				icon_scale_minimap = {
					type = "range",
					name = L["Minimap Icon Scale"],
					desc = L["The overall scale of the icons on the Minimap"],
					min = 0.25, max = 2, step = 0.01,
					arg = "icon_scale_minimap",
					order = 30,
				},
				icon_alpha_minimap = {
					type = "range",
					name = L["Minimap Icon Alpha"],
					desc = L["The overall alpha transparency of the icons on the Minimap"],
					min = 0, max = 1, step = 0.01,
					arg = "icon_alpha_minimap",
					order = 40,
				},]]--
			},
		},
		quests = {
			type = "group",
			name = L["Quests"],
			desc = L["QuestsTooltip"],
			order = 10,
			disabled = function() return not db.enabled end,
			args = {
				desc = {
					name = L["QuestsDescription"],
					type = "description",
					order = 0,
				},
				add_quest = {
					name = "+",
					desc = L["QuestAddTooltip"],
					type = "execute",
					order = 10,
					func = function(info, v)
						addQuestToSlot(getInactiveQuestSlot())
					end,
				},
				remove_quest = {
					name = "-",
					desc = L["QuestRemoveTooltip"],
					type = "execute",
					order = 20,
					func = function(info, v)
						for key, value in pairs(options) do
							print(key, value)
						end
					end,
				},
				quest_info = {
					name = L["QuestInfo"],
					type = "group",
					order = 99,
					args = {
						desc = {
							name = L["QuestOptionsDescription"],
							type = "description",
							order = 0,
						},
					},
				},
			},
		},
	},
}

---------------------------------------------------------
-- Quest template

quest_template = {
	name = "New Quest",
	type = "group",
	childGroups = "tab",
	order = 100,
	set = function(info, k) print(info) end,
	args = {
		quest_options = {
			name = L["Quest"],
			type = "group",
			order = 0,
			args = {
				desc = {
					name = L["QuestOptionsDescription"],
					type = "description",
					order = 0,
				},
				name = {
					name = L["QuestName"],
					desc = L["QuestNameTooltip"],
					type = "input",
					order = 10,
					get = function(info, v)
						return db.questList[info[2]].name or ""
					end,
					set = function(info, v)
						db.questList[info[2]].name = v
						options.args.quests.args[info[2]].name = v
					end,
				},
				enabled = {
					name = L["EnableQuest"],
					desc = L["EnableQuestTooltip"],
					type = "toggle",
					order = 20,
					get = function(info, v)
						return db.questList[info[2]].enabled or true
					end,
					set = function(info, v)
						db.questList[info[2]].enabled = v
					end,
				},
				item = {
					name = L["QuestItem"],
					desc = L["QuestItemTooltip"],
					width = "full",
					type = "input",
					order = 30,
					get = function(info, v)
						if db.questList[info[2]].itemID then
							return GetItemInfo(db.questList[info[2]].itemID)
						end
					end,
					set = function(info, v)
						local inputID = GetItemInfoInstant(v)
						if inputID == nil then
							return
						end

						db.questList[info[2]].itemID = inputID

						if db.questList[info[2]].name == nil then
							local newName = GetItemInfo(inputID)
							db.questList[info[2]].name = newName
							options.args.quests.args[info[2]].name = newName
							options.args.quests.args[info[2]].args.name.value = newName
						end

						createQuestFrame(info[2])
					end,
				},
				goal = {
					name = L["QuestGoal"],
					desc = L["QuestGoalTooltip"],
					width = "half",
					type = "input",
					order = 40,
					validate = function(info, v)
						if tonumber(v) == nil then
							return "|cffff0000Error:|r Must be a number"
						end
						return true
					end,
					get = function(info, v)
						return db.questList[info[2]].goal and tostring(db.questList[info[2]].goal) or "0"
					end,
					set = function(info, v)
						db.questList[info[2]].goal = tonumber(v)
					end,
				},
			},
		},
		filter_options = {
			name = L["Filters"],
			type = "group",
			order = 10,
			args = {
				desc = {
					name = L["FiltersDescription"],
					type = "description",
					order = 0,
				},
				filter_continent = {
					name = L["FilterContinent"],
					type = "group",
					inline = true,
					order = 10,
					args = {
						continent = {
							name = L["FilterContinent"],
							width = "full",
							type = "input",
							order = 10,
							multiline = 10,
							disabled = true,
							get = function(info, v)
								local output = ""
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.continents ~= nil then
									for key, continent in pairs(db.questList[info[2]].filter.continents) do
										if continent then output = output .. C_Map.GetMapInfo(key).name .. "\n" end
									end
								end
								return output
							end,
						},
						continent_filter_type = {
							name = L["FilterType"],
							desc = L["FilterTypeTooltip"],
							type = "select",
							order = 20,
							style = "dropdown",
							set = function(info, v)
								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.types == nil then
									db.questList[info[2]].filter.types = {}
								end
								db.questList[info[2]].filter.types.continent = v
							end,
							get = function(info, v)
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.types ~= nil then
									return db.questList[info[2]].filter.types.continent or "blacklist"
								end
								return "blacklist"
							end,
							values = {
								["blacklist"] = L["Blacklist"],
								["whitelist"] = L["Whitelist"],
							},
						},
						add_continent = {
							name = "+",
							desc = L["FilterContinentAddTooltip"],
							width = 0.25,
							type = "execute",
							order = 30,
							func = function(info, v)
								local currentMap = getContinentFromMap(C_Map.GetBestMapForUnit("player"))

								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.continents == nil then
									db.questList[info[2]].filter.continents = {}
								end
								db.questList[info[2]].filter.continents[tostring(currentMap)] = true

								DropQuests:OnZoneChanged(_, currentMap)
							end,
						},
						del_continent = {
							name = "-",
							desc = L["FilterContinentRemoveTooltip"],
							width = 0.25,
							type = "execute",
							order = 40,
							func = function(info, v)
								local currentMap = getContinentFromMap(C_Map.GetBestMapForUnit("player"))

								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.continents == nil then
									db.questList[info[2]].filter.continents = {}
								end
								db.questList[info[2]].filter.continents[tostring(currentMap)] = false

								DropQuests:OnZoneChanged(_, currentMap)
							end,
						},
					},
				},
				filter_zone = {
					name = L["FilterZone"],
					type = "group",
					inline = true,
					order = 20,
					args = {
						zone = {
							name = L["FilterZone"],
							width = "full",
							type = "input",
							order = 10,
							multiline = 10,
							disabled = true,
							get = function(info, v)
								local output = ""
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.zones ~= nil then
									for key, zone in pairs(db.questList[info[2]].filter.zones) do
										if zone then output = output .. C_Map.GetMapInfo(key).name .. "\n" end
									end
								end
								return output
							end,
						},
						zone_filter_type = {
							name = L["FilterType"],
							desc = L["FilterTypeTooltip"],
							type = "select",
							order = 20,
							style = "dropdown",
							set = function(info, v)
								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.types == nil then
									db.questList[info[2]].filter.types = {}
								end
								db.questList[info[2]].filter.types.zone = v
							end,
							get = function(info, v)
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.types ~= nil then
									return db.questList[info[2]].filter.types.zone or "blacklist"
								end
								return "blacklist"
							end,
							values = {
								["blacklist"] = L["Blacklist"],
								["whitelist"] = L["Whitelist"],
							},
						},
						add_zone = {
							name = "+",
							desc = L["FilterZoneAddTooltip"],
							width = 0.25,
							type = "execute",
							order = 30,
							func = function(info, v)
								local currentMap = getZoneFromMap(C_Map.GetBestMapForUnit("player"))

								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.zones == nil then
									db.questList[info[2]].filter.zones = {}
								end
								db.questList[info[2]].filter.zones[tostring(currentMap)] = true

								DropQuests:OnZoneChanged(_, currentMap)
							end,
						},
						del_zone = {
							name = "+",
							desc = L["FilterZoneRemoveTooltip"],
							width = 0.25,
							type = "execute",
							order = 40,
							func = function(info, v)
								local currentMap = getZoneFromMap(C_Map.GetBestMapForUnit("player"))

								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.zones == nil then
									db.questList[info[2]].filter.zones = {}
								end
								db.questList[info[2]].filter.zones[tostring(currentMap)] = false

								DropQuests:OnZoneChanged(_, currentMap)
							end,
						},
					},
				},
			},
		},
	},
}

---------------------------------------------------------
-- Addon initialization, enabling and disabling

function DropQuests:OnInitialize()
	-- Set up our database
	self.db = ACDB:New("DropQuestsDB", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	db = self.db.profile

	-- Register options table and slash command
	ACR:RegisterOptionsTable(addonName, options)
	self:RegisterChatCommand("dropquests", function() ACDI:Open(addonName) end)

	-- Get the option table for profiles
	options.args.profiles = ACO:GetOptionsTable(self.db)
	options.args.profiles.name = L["Profiles"]

	for key, value in pairs(db.questList) do
		options.args.quests.args[key] = copy(quest_template)
		options.args.quests.args[key].name = value["name"] or "New Quest"
	end

	ACR:RegisterOptionsTable(addonName, options, true)

	self.optionsFrame = {}
	self.optionsFrame.general = ACDI:AddToBlizOptions(addonName, addonName, nil, "general")
	self.optionsFrame.quests = ACDI:AddToBlizOptions(addonName, options.args.quests.name, addonName, "quests")
	self.optionsFrame.profiles = ACDI:AddToBlizOptions(addonName, options.args.profiles.name, addonName, "profiles")

	-- Show/Hide quests when switching between zones for filtered quests
	HBD.RegisterCallback(self, "PlayerZoneChanged", "OnZoneChanged")
end

function DropQuests:OnEnable()
	if not db.enabled then
		self:Disable()
		return
	end
end

function DropQuests:OnDisable()
	-- Do Stuff
end

function DropQuests:OnProfileChanged(event, database, newProfileKey)
	db = database.profile
end

function DropQuests:OnZoneChanged(event, currentPlayerUiMapID, currentPlayerUiMapType)
	if previousPlayerUiMapID == nil then
		previousPlayerUiMapID = currentPlayerUiMapID
		return
	end
	local previousContinent = tostring(getContinentFromMap(previousPlayerUiMapID))
	local previousZone = tostring(getZoneFromMap(previousPlayerUiMapID))
	local currentContinent = tostring(getContinentFromMap(currentPlayerUiMapID))
	local currentZone = tostring(getZoneFromMap(currentPlayerUiMapID))

	-- Check each quest to show/hide depending on their filters
	for key, quest in pairs(db.questList) do
		-- Check if the quest has any filters
		if quest.filter ~= nil then
			-- Check if the player has entered a new continent and the quest has a continent filter
			if previousContinent ~= currentContinent and quest.filter.continents ~= nil then
				-- Check if the quest has a continent filter for the current continent
				if quest.filter.continents[currentContinent] ~= nil and quest.filter.continents[currentContinent] then
					-- Check if the continent filter is using a whitelist
					if quest.filter.types ~= nil and quest.filter.types.continent ~= nil and quest.filter.types.continent == "whitelist" then
						showHideQuest(true, key)
					else
						showHideQuest(false, key)
					end
				end

				-- Check if the quest has a continent filter for the previous continent
				if quest.filter.continents[previousContinent] ~= nil and quest.filter.continents[previousContinent] then
					-- Check if the continent filter is using a whitelist
					if quest.filter.types ~= nil and quest.filter.types.continent ~= nil and quest.filter.types.continent == "whitelist" then
						showHideQuest(false, key)
					else
						showHideQuest(true, key)
					end
				end
			end

			-- Check if the player has entered a new zone and the quest has a zone filter
			if previousZone ~= currentZone and quest.filter.zones ~= nil then
				-- Check if the quest has a zone filter for the current zone
				if quest.filter.zones[currentZone] ~= nil and quest.filter.zones[currentZone] then
					-- Check if the zone filter is using a whitelist
					if quest.filter.types ~= nil and quest.filter.types.zone ~= nil and quest.filter.types.zone == "whitelist" then
						showHideQuest(true, key)
					else
						showHideQuest(false, key)
					end
				end

				-- Check if the quest has a zone filter for the previous zone
				if quest.filter.zones[previousZone] ~= nil and quest.filter.zones[previousZone] then
					-- Check if the zone filter is using a whitelist
					if quest.filter.types ~= nil and quest.filter.types.zone ~= nil and quest.filter.types.zone == "whitelist" then
						showHideQuest(false, key)
					else
						showHideQuest(true, key)
					end
				end
			end
		end
	end

	previousPlayerUiMapID = currentPlayerUiMapID
end
