--[[
DropQuests
]]

---------------------------------------------------------
-- Library declaration
local ACE = LibStub("AceAddon-3.0")
local ACDB = LibStub("AceDB-3.0")
local ACDI = LibStub("AceConfigDialog-3.0")
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

-- Constants
local MAX_QUESTS = 200
local DEFAULT_PROGRESS_BAR_WIDTH = 80

local previousPlayerUiMapID
local questVars = {}
local eventFrame

local screenWidth = GetScreenWidth()
local screenHeight = GetScreenHeight()

---------------------------------------------------------
-- Our db upvalue and db defaults
local db
local options
local defaults = {
	profile = {
		enabled = true,
		icon_scale = 1.0,
		icon_alpha = 1.0,
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
		local slotString = tostring(i)
		if db.questList[slotString] == nil then
			return slotString
		end
	end
end

local function addQuestToSlot(slot_number)
	initializeQuestSlotOptions(slot_number)
	initializeDatabaseWithQuest(slot_number)
	initializeQuestVars(slot_number)

	ACR:RegisterOptionsTable(addonName, options, nil)
end

function initializeQuestSlotOptions(slot_number)
	options.args.general.args.quests.args[slot_number] = copy(quest_template)
	updateQuestSlotOptions(slot_number)
end

function updateQuestSlotOptions(slot_number)
	options.args.general.args.quests.args[slot_number].args.appearance_options.args.x_offset.softMax = math.floor(screenWidth + 0.5)
	options.args.general.args.quests.args[slot_number].args.appearance_options.args.y_offset.softMax = math.floor(screenHeight + 0.5)
end

local function removeQuestFromSlot(slot_number)
	hideQuestFrame(slot_number)
	frame = getFrameFromSlot(slot_number)
	options.args.general.args.quests.args[slot_number] = nil
	db.questList[slot_number] = nil
	frame:UnregisterEvent("ITEM_PUSH")
	frame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")

	ACR:RegisterOptionsTable(addonName, options, nil)
end

local function getContinentFromMap(uiMapID)
	local mapID = uiMapID or C_Map.GetBestMapForUnit("player")
	if mapID == nil then return nil end
	local mapInfo = C_Map.GetMapInfo(mapID)

	if mapInfo.mapType == Enum.UIMapType.Continent then
		return mapID
	end

	-- Track old map information so we can assume continent-less maps are continents themselves
	local oldMapID
	local oldMapInfo

	while mapInfo.mapType > Enum.UIMapType.Continent do
		oldMapID = mapID
		oldMapInfo = mapInfo
		mapID = mapInfo.parentMapID
		mapInfo = C_Map.GetMapInfo(mapID)

		if mapInfo.mapType == Enum.UIMapType.Continent then
			return mapID
		-- Assume maps without a parent continent are themselves a continent
		elseif mapInfo.mapType < Enum.UIMapType.Continent then
			return oldMapID
		end
	end

	-- Map is too abstract. Can't do anything with it.
	return nil
end

local function getZoneFromMap(uiMapID)
	local mapID = uiMapID or C_Map.GetBestMapForUnit("player")
	if mapID == nil then return nil end
	local mapInfo = C_Map.GetMapInfo(mapID)

	if mapInfo.mapType == Enum.UIMapType.Zone then
		return mapID
	end

	-- Track old map information so we can assume zone-less maps are zones themselves
	local oldMapID
	local oldMapInfo

	while mapInfo.mapType > Enum.UIMapType.Zone do
		oldMapID = mapID
		oldMapInfo = mapInfo
		mapID = mapInfo.parentMapID
		mapInfo = C_Map.GetMapInfo(mapID)

		if mapInfo.mapType == Enum.UIMapType.Zone then
			return mapID
		-- Assume maps without a parent zone are themselves a zone
		elseif mapInfo.mapType < Enum.UIMapType.Zone then
			return oldMapID
		end
	end

	-- Map is too abstract. Can't do anything with it.
	return nil
end

function initializeDatabaseWithQuest(slot_number)
	if not db.questList[slot_number] then
		db.questList[slot_number] = {}
	end
	db.questList[slot_number].disabled = false
end

local function getOptionTable(slot_number)
	return options.args.general.args.quests[slot_number]
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

local function setQuestItem(slot_number, itemID)
	if itemID == nil then
		return
	end

	local frame = questVars[slot_number].frame
	local quest_type = getQuestType(slot_number)

	db.questList[slot_number].itemID = itemID
	if quest_type == "item" then
		db.questList[slot_number].itemIcon = GetItemIcon(itemID)
	end

	if db.questList[slot_number].name == nil then
		local item_name = getQuestName(slot_number)

		if item_name == nil then
			if quest_type == "item" then
				local item = Item:CreateFromItemID(itemID)

				item:ContinueOnItemLoad(function()
					item_name = item:GetItemName()
					db.questList[slot_number].name = item_name
					options.args.general.args.quests.args[slot_number].name = item_name
					ACR:NotifyChange(addonName)
				end)
			end
		else
			db.questList[slot_number].name = item_name
			options.args.general.args.quests.args[slot_number].name = item_name
			ACR:NotifyChange(addonName)
		end
	end
end

---------------------------------------------------------
-- Core functions

function createQuestFrame(slot_number)
	local frame = CreateFrame("Frame", "questframe_"..slot_number, UIParent, "StatusTrackingBarTemplate")
	local padding = 4

	local startMoving = function(self)
		frame:StartMoving()
	end

	local stopMoving = function(self)
		frame:StopMovingOrSizing()
		local anchor = db.questList[slot_number].appearance and db.questList[slot_number].appearance.anchor or "BOTTOMLEFT"

		local horizontal_anchor = string.sub(anchor, -5, -1) == "RIGHT" and "RIGHT" or "LEFT"
		local vertical_anchor = string.sub(anchor, 1, 3) == "TOP" and "TOP" or "BOTTOM"

		if db.questList[slot_number].appearance == nil then
			db.questList[slot_number].appearance = {}
		end

		db.questList[slot_number].appearance.x = horizontal_anchor == "LEFT" and frame:GetLeft() or screenWidth - frame:GetRight()
		db.questList[slot_number].appearance.y = vertical_anchor == "BOTTOM" and frame:GetBottom() or screenHeight - frame:GetTop()
		ACR:NotifyChange(addonName)
	end

	frame:Show()
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", startMoving)
	frame:SetScript("OnDragStop", stopMoving)
	frame:RegisterEvent(db.questList[slot_number].quest_type ~= nil and db.questList[slot_number].quest_type == "currency" and "CURRENCY_DISPLAY_UPDATE" or "ITEM_PUSH")
	frame:SetClampedToScreen(db.questList[slot_number].appearance and db.questList[slot_number].appearance.clamped_to_screen or true)

	frame.button = CreateFrame("ItemButton", "questframe_"..slot_number.."_button", frame)
	frame.button:SetPoint("BOTTOMLEFT", padding, padding)
	frame.button:SetMouseClickEnabled(true)
	frame.button:RegisterForDrag("LeftButton")
	frame.button:SetScript("OnDragStart", startMoving)
	frame.button:SetScript("OnDragStop", stopMoving)

	local button_width = frame.button:GetWidth()
	local after_button_offset = padding * 2 + button_width

	frame:SetSize(128, after_button_offset)

	frame.name = frame:CreateFontString()
	frame.name:SetSize(DEFAULT_PROGRESS_BAR_WIDTH, 16)
	frame.name:SetPoint("BOTTOMLEFT", after_button_offset, 24)
	frame.name:SetFontObject("GameFontNormal")
	frame.name:SetJustifyH("LEFT")
	frame.name:SetWordWrap(false)
	frame.name:SetNonSpaceWrap(false)

	frame.progress_text_frame = CreateFrame("Frame", "questframe_"..slot_number.."_progresstext", frame)
	frame.progress_text_frame:SetSize(frame:GetWidth(), frame:GetHeight())
	frame.progress_text_frame:SetPoint("BOTTOMLEFT", 0, 0)
	frame.progress_text = frame.progress_text_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.progress_text:SetPoint("BOTTOMLEFT", after_button_offset, padding)
	frame.progress_text:SetJustifyH("RIGHT")
	frame.progress_text:SetJustifyV("BOTTOM")
	frame.progress_text:SetMaxLines(1)
	frame.progress_text:SetTextColor(1.0, 1.0, 1.0)

	frame.StatusBar:SetPoint("BOTTOMLEFT", after_button_offset, padding)
	frame.StatusBar:SetSize(DEFAULT_PROGRESS_BAR_WIDTH, 16)
	frame.StatusBar:SetStatusBarColor(0.75, 0.75, 0.75)

	frame.button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		if getQuestType(slot_number) == "currency" then
			GameTooltip:SetHyperlink("currency:" .. db.questList[slot_number].itemID)
		else
			GameTooltip:SetHyperlink("item:" .. db.questList[slot_number].itemID)
		end
		GameTooltip:Show()
	end)

	frame.button:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	frame.button:SetScript("OnMouseUp", function(self)
		ACDI:Open(addonName)
		ACDI:SelectGroup(addonName, "general", "quests", slot_number)
	end)

	local function itemPickupEvent(self, event, ...)
		if (event == "ITEM_PUSH") then
			local bag_slot, item_icon_id = ...
			if db.questList[slot_number].itemIcon == item_icon_id then
				questVars[slot_number].frame_update_queued = true
				if db.questList[slot_number].filter ~= nil then
					if db.questList[slot_number].filter.auto_filter_continent ~= nil and db.questList[slot_number].filter.auto_filter_continent then
						addContinentToFilterList(slot_number)
					end
					if db.questList[slot_number].filter.auto_filter_zone ~= nil and db.questList[slot_number].filter.auto_filter_zone then
						addZoneToFilterList(slot_number)
					end
				end
			end
		elseif (event == "CURRENCY_DISPLAY_UPDATE") then
			local currency_id = ...
			if db.questList[slot_number].itemID == currency_id then
				questVars[slot_number].frame_update_queued = true
				if db.questList[slot_number].filter ~= nil then
					if db.questList[slot_number].filter.auto_filter_continent ~= nil and db.questList[slot_number].filter.auto_filter_continent then
						addContinentToFilterList(slot_number)
					end
					if db.questList[slot_number].filter.auto_filter_zone ~= nil and db.questList[slot_number].filter.auto_filter_zone then
						addZoneToFilterList(slot_number)
					end
				end
			end
		elseif (event == "BAG_UPDATE_DELAYED" and questVars[slot_number].frame_update_queued) then
			frame:UpdateQuestProgress()
			questVars[slot_number].frame_update_queued = false
		end
	end

	frame:SetScript("OnEvent", itemPickupEvent)

	-- Function definitions
	function frame:FullRefresh()
		frame:UpdateItem()
		frame:UpdateName()
		frame:UpdateFramePosition()
		frame:UpdateFrameSize()
		frame:UpdateQuestProgressFrame()

		return true
	end

	 function frame:UpdateItem()
		if db.questList[slot_number].itemID == nil then
			return nil
		end


		if getQuestType(slot_number) == "currency" then
			local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(db.questList[slot_number].itemID)
			frame.button:Reset()
			if currencyInfo then SetItemButtonTexture(frame.button, currencyInfo.iconFileID) end
		else
			frame.button:SetItem(db.questList[slot_number].itemID)
		end

		return db.questList[slot_number].itemID
	end

	function frame:UpdateName()
		local new_name = getQuestName(slot_number) or ""

		frame.name:SetText(new_name)

		return new_name
	end

	function frame:UpdateFrameSize()
		local show_name = db.questList[slot_number].show_name == nil or db.questList[slot_number].show_name
		local progress_bar_width = (db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.progress_width ~= nil and db.questList[slot_number].appearance.progress_width) or (db.defaults ~= nil and db.defaults.progress_width ~= nil and db.defaults.progress_width) or DEFAULT_PROGRESS_BAR_WIDTH

		local text_width = progress_bar_width
		if progress_bar_width > 0 then
			frame:SetSize(after_button_offset + progress_bar_width + padding, after_button_offset)
			frame.StatusBar:Show()
			frame.name:SetShown(show_name)
			frame.StatusBar:SetSize(progress_bar_width, frame.StatusBar:GetHeight())

			frame.progress_text:SetPoint("BOTTOMLEFT", after_button_offset, padding)
			frame.progress_text:SetMaxLines(1)
		else
			frame:SetSize(after_button_offset, after_button_offset)
			frame.StatusBar:Hide()
			frame.name:Hide()

			text_width = max(1, button_width - padding)
			frame.progress_text:SetPoint("BOTTOMLEFT", padding + padding / 2, padding + padding / 2)
			frame.progress_text:SetMaxLines(2)
		end
		frame.progress_text_frame:SetSize(frame:GetWidth(), frame:GetHeight())
		frame.progress_text:SetSize(text_width, text_width)
		frame.name:SetSize(text_width, frame.name:GetHeight())
	end

	function frame:UpdateFramePosition()
		frame:ClearAllPoints()
		if db.questList[slot_number].appearance == nil or db.questList[slot_number].appearance.x == nil or db.questList[slot_number].appearance.y == nil then
			frame:SetPoint("CENTER")
			return
		end

		local anchor = db.questList[slot_number].appearance and db.questList[slot_number].appearance.anchor or "BOTTOMLEFT"

		local horizontal_anchor = string.sub(anchor, -5, -1) == "RIGHT" and "RIGHT" or "LEFT"
		local vertical_anchor = string.sub(anchor, 1, 3) == "TOP" and "TOP" or "BOTTOM"

		local x_offset = db.questList[slot_number].appearance.x
		local y_offset = db.questList[slot_number].appearance.y

		if horizontal_anchor == "RIGHT" then
			x_offset = -1 * x_offset
		end

		if vertical_anchor == "TOP" then
			y_offset = -1 * y_offset
		end

		frame:SetPoint(db.questList[slot_number].appearance and db.questList[slot_number].appearance.anchor or "BOTTOMLEFT", x_offset, y_offset)
	end

	function frame:UpdateQuestProgress()
		local use_bank = db.questList[slot_number].use_bank == nil or db.questList[slot_number].use_bank
		local show_value = db.questList[slot_number].appearance == nil or db.questList[slot_number].appearance.show_value == nil or db.questList[slot_number].appearance.show_value
		local show_maximum = db.questList[slot_number].appearance == nil or db.questList[slot_number].appearance.show_maximum == nil or db.questList[slot_number].appearance.show_maximum

		local itemCount = 0
		local itemGoal = db.questList[slot_number].goal or 0

		if db.questList[slot_number].itemID ~= nil then
			if getQuestType(slot_number) == "currency" then
				local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(db.questList[slot_number].itemID)
				if currencyInfo then itemCount = currencyInfo.quantity end
			else
				itemCount = GetItemCount(db.questList[slot_number].itemID, use_bank, false, use_bank) or 0
			end
		end

		frame.StatusBar:SetValue(math.min(itemCount, itemGoal))

		if show_value then
			local textOutput = tostring(itemCount)
			local display_type = (db.questList[slot_number].appearance and db.questList[slot_number].appearance.display_type) or (db.defaults and db.defaults.display_type) or "numeric"

			if display_type == "numeric" then
				if show_maximum then
					textOutput = textOutput .. "/" .. itemGoal
				end
			elseif display_type == "countdown" then
				textOutput = tostring(itemCount - itemGoal)
			elseif display_type == "percentage" then
				if itemGoal ~= 0 then
					textOutput = string.format("%.1f", math.min(1, itemCount / itemGoal) * 100)
				elseif itemCount ~= 0 then
					textOutput = tostring(100)
				else
					textOutput = tostring(0)
				end
				textOutput = textOutput .. "%"
			end
			frame.progress_text:SetText(textOutput)
		end

		-- Adjust color depending on completion.
		if (questVars[slot_number].complete == false) then
			if itemCount >= itemGoal then
				questVars[slot_number].complete = true
				frame.StatusBar:SetStatusBarColor(0.0, 1.0, 0.0)
			else
				local itemRatio = itemCount / max(itemGoal, 1)
				frame.StatusBar:SetStatusBarColor(0.5 + (itemRatio * 0.5), 0.5 + (itemRatio * 0.5), 0.5 - (itemRatio * 0.5))
			end
		elseif (questVars[slot_number].complete == true and itemCount < itemGoal) then
			local itemRatio = itemCount / max(itemGoal, 1)

			frame.StatusBar:SetStatusBarColor(0.5 + (itemRatio * 0.5), 0.5 + (itemRatio * 0.5), 0.5 - (itemRatio * 0.5))
			questVars[slot_number].complete = false
		end
	end

	function frame:UpdateQuestProgressFrame()
		--local show_name = db.questList[slot_number].show_name == nil or db.questList[slot_number].show_name
		local show_value = db.questList[slot_number].show_value == nil or db.questList[slot_number].show_value
		local hover_mode = db.questList[slot_number].text_hover_mode ~= nil and db.questList[slot_number].text_hover_mode

		frame.progress_text:SetShown(show_value)
		if show_value then
			frame.progress_text_frame:EnableMouse(hover_mode)
			frame.progress_text:SetDrawLayer(hover_mode and "HIGHLIGHT" or "OVERLAY")
		end

		frame.StatusBar:SetMinMaxValues(0, db.questList[slot_number].goal or 1)

		--frame.name:SetShown(show_name)
		--frame.StatusBar:SetSize(frame.StatusBar:GetWidth(), show_name and 16 or 16 * 2 + padding)

		frame:UpdateQuestProgress()
	end

	frame:Hide()

	return frame
end

function showQuestFrame(slot_number)
	local frame = questVars[slot_number].frame

	if db.questList[slot_number].itemID == nil then
		return nil
	end
	if frame ~= nil then
		frame:Show()
	end

	frame:RegisterEvent("BAG_UPDATE_DELAYED")

	frame:FullRefresh()
	return frame:IsVisible()
end

function hideQuestFrame(slot_number)
	local frame = questVars[slot_number].frame

	if frame ~= nil then
		frame:UnregisterEvent("BAG_UPDATE_DELAYED")

		frame:Hide()
		return not frame:IsVisible()
	end

	return true
end

function addZoneToFilterList(slot_number, uiMapID)
	uiMapID = uiMapID or C_Map.GetBestMapForUnit("player")

	local zone = getZoneFromMap(uiMapID)

	if db.questList[slot_number].filter == nil then
		db.questList[slot_number].filter = {}
	end
	if db.questList[slot_number].filter.zones == nil then
		db.questList[slot_number].filter.zones = {}
	end
	db.questList[slot_number].filter.zones[tostring(zone)] = true

	refreshQuestFrameVisibility(tostring(zone))

	return zone
end

function addContinentToFilterList(slot_number, uiMapID)
	uiMapID = uiMapID or C_Map.GetBestMapForUnit("player")

	local continent = getContinentFromMap(uiMapID)

	if db.questList[slot_number].filter == nil then
		db.questList[slot_number].filter = {}
	end
	if db.questList[slot_number].filter.continents == nil then
		db.questList[slot_number].filter.continents = {}
	end
	db.questList[slot_number].filter.continents[tostring(continent)] = true

	refreshQuestFrameVisibility(tostring(continent))

	return continent
end

function getQuestType(slot_number)
	return db.questList[slot_number].quest_type ~= nil and db.questList[slot_number].quest_type or "item"
end

function getQuestName(slot_number)
	local returned_name = db.questList[slot_number].name
	if returned_name == nil and db.questList[slot_number].itemID then
		if getQuestType(slot_number) == "currency" then
			local currencyInfo = C_CurrencyInfo.GetBasicCurrencyInfo(db.questList[slot_number].itemID)

			if currencyInfo then returned_name = currencyInfo.name end
		elseif db.questList[slot_number].itemID then
			returned_name = GetItemInfo(db.questList[slot_number].itemID)
		end
	end
	return returned_name
end

function getFrameFromSlot(slot_number)
	return questVars[slot_number].frame
end

-- Initializes session-based variables for a quest
function initializeQuestVars(slot_number)
	questVars[slot_number] = {}
	questVars[slot_number].frame_update_queued = false
	questVars[slot_number].complete = db.questList[slot_number].goal == nil or (GetItemCount(db.questList[slot_number].itemID) >= db.questList[slot_number].goal)
	questVars[slot_number].frame = createQuestFrame(slot_number)
end

-- Returns true if the quest should be visible
function questVisibilityCheck(slot_number, currentPlayerUiMapID)
	-- Check if the quest is disabled
	if db.questList[slot_number].enabled ~= nil and db.questList[slot_number].enabled == false then
		return false
	end

	-- Check if the quest has any filters
	if db.questList[slot_number].filter == nil then
		return true
	end

	currentPlayerUiMapID = currentPlayerUiMapID or C_Map.GetBestMapForUnit("player")

	local currentContinent = tostring(getContinentFromMap(currentPlayerUiMapID))
	local currentZone = tostring(getZoneFromMap(currentPlayerUiMapID))

	local quest = db.questList[slot_number]

	local zoneIsWhitelist = quest.filter.types ~= nil and quest.filter.types.zone ~= nil and quest.filter.types.zone == "whitelist"
	local continentIsWhitelist = quest.filter.types ~= nil and quest.filter.types.continent ~= nil and quest.filter.types.continent == "whitelist"

	local filterHasCurrentZone = quest.filter.zones ~= nil and quest.filter.zones[currentZone] ~= nil and quest.filter.zones[currentZone] == true
	local filterHasCurrentContinent = quest.filter.continents ~= nil and quest.filter.continents[currentContinent] ~= nil and quest.filter.continents[currentContinent] == true

	if zoneIsWhitelist and not filterHasCurrentZone then
		return false
	end

	if continentIsWhitelist and not filterHasCurrentContinent then
		return false
	end

	if not zoneIsWhitelist and filterHasCurrentZone then
		return false
	end

	if not continentIsWhitelist and filterHasCurrentContinent then
		return false
	end

	if zoneIsWhitelist and filterHasCurrentZone then
		return true
	end

	if continentIsWhitelist and filterHasCurrentContinent then
		return true
	end

	if not zoneIsWhitelist and not filterHasCurrentZone then
		return true
	end

	if not continentIsWhitelist and not filterHasCurrentContinent then
		return true
	end

	-- If nothing applies, keep it as-is
	return questVars[slot_number].frame ~= nil and questVars[slot_number].frame:IsVisible()
end

-- Refresh the visibility of all quest frames assuming the designated map ID
function refreshQuestFrameVisibility(uiMapID)
	uiMapID = uiMapID or getZoneFromMap()
	if uiMapID == nil then return false end

	for key, quest in pairs(db.questList) do
		getFrameFromSlot(key):FullRefresh()
		if questVisibilityCheck(key, uiMapID) then
			showQuestFrame(key)
		else
			hideQuestFrame(key)
		end
	end

	return true
end

---------------------------------------------------------
-- Options table

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
					order = 5,
					get = function(info) return db.enabled end,
					set = function(info, v)
						db.enabled = v
						if v then DropQuests:Enable() else DropQuests:Disable() end
					end,
					disabled = false,
				},
				add_quest = {
					name = L["QuestAdd"],
					desc = L["QuestAddTooltip"],
					type = "execute",
					order = 10,
					func = function(info, v)
						addQuestToSlot(getInactiveQuestSlot())
					end,
				},
				quests = {
					type = "group",
					name = L["Quests"],
					desc = L["QuestsTooltip"],
					order = 30,
					disabled = function() return not db.enabled end,
					args = {
						desc = {
							name = L["QuestsDescription"],
							type = "description",
							order = 0,
						},
					},
				},
				appearance = {
					type = "group",
					name = L["AppearanceSettings"],
					desc = L["AppearanceSettingsTooltip"],
					order = 40,
					disabled = function() return not db.enabled end,
					args = {
						desc = {
							name = L["AppearanceSettingsDescription"],
							type = "description",
							order = 0,
						},
						progress_width = {
							type = "range",
							name = L["ProgressWidth"],
							desc = L["ProgressWidthTooltip"],
							min = 0,
							softMax = 200,
							order = 10,
							step = 1,
							get = function(info) return db.defaults and db.defaults.progress_width or DEFAULT_PROGRESS_BAR_WIDTH end,
							set = function(info, v)
								if not db.defaults then
									db.defaults = {}
								end

								db.defaults.progress_width = v
								for key, _ in pairs(db.questList) do getFrameFromSlot(key):UpdateFrameSize() end
							end,
						},
						display_type = {
							name = L["DisplayType"],
							desc = L["DisplayTypeTooltip"],
							type = "select",
							order = 20,
							values = {
								["numeric"] = L["Numeric"],
								["countdown"] = L["Countdown"],
								["percentage"] = L["Percentage"],
							},
							get = function(info) return db.defaults and db.defaults.display_type or "numeric" end,
							set = function(info, v)
								if not db.defaults then
									db.defaults = {}
								end

								db.defaults.display_type = v
								for key, _ in pairs(db.questList) do getFrameFromSlot(key):UpdateQuestProgress() end
							end,
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
	args = {
		enabled = {
			name = L["EnableQuest"],
			desc = L["EnableQuestTooltip"],
			width = "half",
			type = "toggle",
			order = 20,
			get = function(info, v)
				if db.questList[info[3]].enabled ~= nil then
					return db.questList[info[3]].enabled
				else
					return true
				end
			end,
			set = function(info, v)
				db.questList[info[3]].enabled = v
				if questVisibilityCheck(info[3]) then
					showQuestFrame(info[3])
				else
					hideQuestFrame(info[3])
				end
			end,
		},
		del_quest = {
			name = L["DeleteQuest"],
			desc = L["DeleteQuestTooltip"],
			type = "execute",
			order = 40,
			confirm = function() return true end,
			confirmText = L["DeleteQuestConfirmDialog"],
			func = function(info, v) removeQuestFromSlot(info[3]) end,
		},
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
					width = "full",
					type = "input",
					order = 10,
					get = function(info, v)
						local new_name = getQuestName(info[3])

						options.args.general.args.quests.args[info[3]].name = new_name or "New Quest"
						return new_name or ""
					end,
					set = function(info, v)
						db.questList[info[3]].name = v ~= "" and v or nil
						if v ~= "" then
							options.args.general.args.quests.args[info[3]].name = v
						end
						getFrameFromSlot(info[3]):UpdateName()
					end,
				},
				item = {
					name = L["QuestItem"],
					desc = L["QuestItemTooltip"],
					type = "input",
					order = 20,
					get = function(info, v)
						if db.questList[info[3]].itemID ~= nil then
							if getQuestType(info[3]) == "currency" then
								local currencyInfo = C_CurrencyInfo.GetBasicCurrencyInfo(db.questList[info[3]].itemID)
								if currencyInfo == nil then return tostring(db.questList[info[3]].itemID) end

								local _, _, _, hexColor = GetItemQualityColor(currencyInfo.quality)

								return currencyInfo and "|c" .. hexColor .. "|Hcurrency:" .. db.questList[info[3]].itemID .. ":::::::::::::::::|h[" .. currencyInfo.name .. "]|h|r"
							else
								local itemName = GetItemInfo(db.questList[info[3]].itemID)
								if itemName == nil then return tostring(db.questList[info[3]].itemID) end

								local _, _, _, hexColor = GetItemQualityColor(C_Item.GetItemQualityByID(db.questList[info[3]].itemID))

								return itemName and "|c" .. hexColor .. "|Hitem:" .. db.questList[info[3]].itemID .. ":::::::::::::::::|h[" .. itemName .. "]|h|r"
							end
						end
						return ""
					end,
					set = function(info, v)
						local inputID = v
						local frame = getFrameFromSlot(info[3])

						if tonumber(inputID) == nil then
							if getQuestType(info[3]) == "currency" then
								inputID = C_CurrencyInfo.GetCurrencyIDFromLink(inputID)
							else
								inputID = GetItemInfoInstant(v)
							end

							if tonumber(inputID) == nil then
								return
							end
						end

						setQuestItem(info[3], inputID)

						if questVisibilityCheck(info[3]) then
							showQuestFrame(info[3])
						end
						frame:UpdateItem()
					end,
				},
				quest_type = {
					name = L["DisplayType"],
					desc = L["DisplayTypeTooltip"],
					type = "select",
					order = 30,
					values = {
						["item"] = L["QuestItem"],
						["currency"] = L["QuestCurrency"],
					},
					get = function(info) return db.questList[info[3]].quest_type or "item" end,
					set = function(info, v)
						db.questList[info[3]].quest_type = v
						local frame = getFrameFromSlot(info[3])

						frame:UnregisterEvent("ITEM_PUSH")
						frame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
						if v == "currency" then
							frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
						else
							frame:UnregisterEvent("ITEM_PUSH")
						end
						frame:UpdateQuestProgress()
					end,
				},
				goal = {
					name = L["QuestGoal"],
					desc = L["QuestGoalTooltip"],
					type = "input",
					order = 50,
					validate = function(info, v)
						if tonumber(v) == nil then
							return "|cffff0000Error:|r Must be a number"
						end
						return true
					end,
					get = function(info, v)
						return db.questList[info[3]].goal and tostring(db.questList[info[3]].goal) or "0"
					end,
					set = function(info, v)
						db.questList[info[3]].goal = tonumber(v)
						getFrameFromSlot(info[3]):UpdateQuestProgressFrame()
					end,
				},
				use_bank = {
					name = L["UseBank"],
					desc = L["UseBankTooltip"],
					type = "toggle",
					order = 60,
					get = function(info, v)
						if db.questList[info[3]].use_bank ~= nil then
							return db.questList[info[3]].use_bank
						else
							return true
						end
					end,
					set = function(info, v)
						db.questList[info[3]].use_bank = v
						getFrameFromSlot(info[3]):UpdateQuestProgressFrame()
					end,
				},
			},
		},
		appearance_options = {
			name = L["QuestAppearanceSettings"],
			desc = L["QuestAppearanceSettingsTooltip"],
			type = "group",
			order = 20,
			args = {
				desc = {
					name = L["QuestAppearanceSettingsDescription"],
					type = "description",
					order = 0,
				},
				general_title = {
					name = L["General"],
					type = "header",
					order = 10,
				},
				progress_width = {
					name = L["ProgressWidth"],
					desc = L["ProgressWidthTooltip"],
					type = "range",
					min = 0,
					softMax = 200,
					order = 20,
					step = 1,
					get = function(info) return db.questList[info[3]].appearance and db.questList[info[3]].appearance.progress_width or db.defaults and db.defaults.progress_width or DEFAULT_PROGRESS_BAR_WIDTH end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.progress_width = v
						getFrameFromSlot(info[3]):UpdateFrameSize()
					end,
				},
				reset_progress_width = {
					name = L["ResetProgressWidth"],
					desc = L["ResetProgressWidthTooltip"],
					width = "half",
					type = "execute",
					order = 30,
					disabled = function(info)
						return db.questList[info[3]].appearance and db.questList[info[3]].appearance.progress_width == nil
					end,
					func = function(info, v)
						if db.questList[info[3]].appearance then
							db.questList[info[3]].appearance.progress_width = nil
						end
						getFrameFromSlot(info[3]):UpdateFrameSize()
					end,
				},
				display_type = {
					name = L["DisplayType"],
					desc = L["DisplayTypeTooltip"],
					type = "select",
					order = 40,
					values = {
						["default"] = L["Default"],
						["numeric"] = L["Numeric"],
						["countdown"] = L["Countdown"],
						["percentage"] = L["Percentage"],
					},
					get = function(info) return db.questList[info[3]].appearance and db.questList[info[3]].appearance.display_type or "default" end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						if v == "default" and db.questList[info[3]].appearance.display_type ~= nil then
							db.questList[info[3]].appearance.display_type = nil
						else
							db.questList[info[3]].appearance.display_type = v
						end
						getFrameFromSlot(info[3]):UpdateQuestProgress()
					end,
				},
				x_offset = {
					name = L["XOffset"],
					desc = L["XOffsetTooltip"],
					type = "range",
					softMin = 0,
					softMax = 1280,
					order = 50,
					step = 1,
					get = function(info) return db.questList[info[3]].appearance and db.questList[info[3]].appearance.x or getFrameFromSlot(info[3]):GetLeft() end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.x = v
						getFrameFromSlot(info[3]):UpdateFramePosition()
					end,
				},
				y_offset = {
					name = L["YOffset"],
					desc = L["YOffsetTooltip"],
					type = "range",
					softMin = 0,
					softMax = 720,
					order = 60,
					step = 1,
					get = function(info) return db.questList[info[3]].appearance and db.questList[info[3]].appearance.y or getFrameFromSlot(info[3]):GetBottom() end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.y = v
						getFrameFromSlot(info[3]):UpdateFramePosition()
					end,
				},
				anchor = {
					name = L["Anchor"],
					desc = L["AnchorTooltip"],
					type = "select",
					order = 70,
					values = {
						["TOPLEFT"] = L["TopLeft"],
						["TOPRIGHT"] = L["TopRight"],
						["BOTTOMLEFT"] = L["BottomLeft"],
						["BOTTOMRIGHT"] = L["BottomRight"],
					},
					get = function(info) return db.questList[info[3]].appearance and db.questList[info[3]].appearance.anchor or "BOTTOMLEFT" end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.anchor = v
						getFrameFromSlot(info[3]):UpdateFramePosition()
					end,
				},
				clamped = {
					name = L["Clamped"],
					desc = L["ClampedTooltip"],
					width = "half",
					type = "toggle",
					order = 80,
					get = function(info, v)
						return db.questList[info[3]].appearance ~= nil and db.questList[info[3]].appearance.clamped_to_screen ~= nil and db.questList[info[3]].appearance.clamped_to_screen or true
					end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.clamped_to_screen = v
						getFrameFromSlot(info[3]):SetClampedToScreen(v)
					end,
				},
				text_title = {
					name = L["Text"],
					type = "header",
					order = 100,
				},
				show_value = {
					name = L["ShowValue"],
					desc = L["ShowValueTooltip"],
					width = 0.75,
					type = "toggle",
					order = 110,
					get = function(info, v)
						if db.questList[info[3]].appearance ~= nil and db.questList[info[3]].appearance.show_value ~= nil then
							return db.questList[info[3]].appearance.show_value
						else
							return true
						end
					end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.show_value = v
						getFrameFromSlot(info[3]):UpdateQuestProgressFrame()
					end,
				},
				show_maximum = {
					name = L["ShowMax"],
					desc = L["ShowMaxTooltip"],
					width = 0.75,
					type = "toggle",
					order = 120,
					disabled = function(info)
						if db.questList[info[3]].appearance ~= nil then
							if db.questList[info[3]].appearance.show_value ~= nil and not db.questList[info[3]].appearance.show_value then
								return true
							end
							if db.questList[info[3]].appearance.display_type ~= nil then
								return db.questList[info[3]].appearance.display_type ~= "numeric"
							end
						end
						if db.defaults ~= nil and db.defaults.display_type ~= nil then
							return db.defaults.display_type ~= "numeric"
						end
						return false
					end,
					get = function(info, v)
						if db.questList[info[3]].appearance ~= nil and db.questList[info[3]].appearance.show_maximum ~= nil then
							return db.questList[info[3]].appearance.show_maximum
						else
							return true
						end
					end,
					set = function(info, v)
						if not db.questList[info[3]].appearance then
							db.questList[info[3]].appearance = {}
						end

						db.questList[info[3]].appearance.show_maximum = v
						getFrameFromSlot(info[3]):UpdateQuestProgressFrame()
					end,
				},
				hover_mode = {
					name = L["HoverMode"],
					desc = L["HoverModeTooltip"],
					width = 0.75,
					type = "toggle",
					order = 130,
					disabled = function(info) return db.questList[info[3]].appearance ~= nil and db.questList[info[3]].appearance.show_value ~= nil and not db.questList[info[3]].appearance.show_value or false end,
					get = function(info, v)
						if db.questList[info[3]].text_hover_mode ~= nil then
							return db.questList[info[3]].text_hover_mode
						else
							return false
						end
					end,
					set = function(info, v)
						db.questList[info[3]].text_hover_mode = v
						getFrameFromSlot(info[3]):UpdateQuestProgressFrame()
					end,
				},
				--[=[show_name = {
					name = L["ShowName"],
					desc = L["ShowNameTooltip"],
					width = 0.75,
					type = "toggle",
					order = 80,
					get = function(info, v)
						if db.questList[info[3]].show_name ~= nil then
							return db.questList[info[3]].show_name
						else
							return true
						end
					end,
					set = function(info, v)
						db.questList[info[3]].show_name = v
						getFrameFromSlot(info[3]):UpdateQuestProgressFrame()
					end,
				},]=]--
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
						auto_filter = {
							name = L["AutoFilterContinent"],
							desc = L["AutoFilterContinentTooltip"],
							width = "full",
							type = "toggle",
							order = 10,
							get = function(info)
								if db.questList[info[3]].filter ~= nil and db.questList[info[3]].filter.auto_filter_continent ~= nil then
									return db.questList[info[3]].filter.auto_filter_continent
								end
								return false
							end,
							set = function(info, v)
								if db.questList[info[3]].filter == nil then
									db.questList[info[3]].filter = {}
								end
								db.questList[info[3]].filter.auto_filter_continent = v
							end,
						},
						continent = {
							name = L["FilterContinent"],
							width = "full",
							type = "input",
							order = 10,
							multiline = 10,
							disabled = true,
							get = function(info, v)
								local output = ""
								if db.questList[info[3]].filter ~= nil and db.questList[info[3]].filter.continents ~= nil then
									for key, continent in pairs(db.questList[info[3]].filter.continents) do
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
								if db.questList[info[3]].filter == nil then
									db.questList[info[3]].filter = {}
								end
								if db.questList[info[3]].filter.types == nil then
									db.questList[info[3]].filter.types = {}
								end
								db.questList[info[3]].filter.types.continent = v
							end,
							get = function(info, v)
								if db.questList[info[3]].filter ~= nil and db.questList[info[3]].filter.types ~= nil then
									return db.questList[info[3]].filter.types.continent or "blacklist"
								end
								return "blacklist"
							end,
							values = {
								["blacklist"] = L["Blacklist"],
								["whitelist"] = L["Whitelist"],
							},
						},
						add_continent = {
							name = L["FilterContinentAdd"],
							desc = L["FilterContinentAddTooltip"],
							width = "half",
							type = "execute",
							order = 30,
							disabled = function(info) return db.questList[info[3]].filter and db.questList[info[3]].filter.continents and db.questList[info[3]].filter.continents[tostring(getContinentFromMap())] end,
							func = function(info, v)
								addContinentToFilterList(info[3])
							end,
						},
						del_continent = {
							name = L["FilterContinentRemove"],
							desc = L["FilterContinentRemoveTooltip"],
							width = "half",
							type = "execute",
							order = 40,
							disabled = function(info) return db.questList[info[3]].filter == nil or db.questList[info[3]].filter.continents == nil or db.questList[info[3]].filter.continents[tostring(getContinentFromMap())] ~= true end,
							func = function(info, v)
								local currentMap = getContinentFromMap()

								if db.questList[info[3]].filter == nil then
									return
								end
								if db.questList[info[3]].filter.continents == nil then
									return
								end

								db.questList[info[3]].filter.continents[tostring(currentMap)] = nil

								refreshQuestFrameVisibility(currentMap)
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
						auto_filter = {
							name = L["AutoFilterZone"],
							desc = L["AutoFilterZoneTooltip"],
							width = "full",
							type = "toggle",
							order = 10,
							get = function(info)
								if db.questList[info[3]].filter ~= nil and db.questList[info[3]].filter.auto_filter_zone ~= nil then
									return db.questList[info[3]].filter.auto_filter_zone
								end
								return false
							end,
							set = function(info, v)
								if db.questList[info[3]].filter == nil then
									db.questList[info[3]].filter = {}
								end
								db.questList[info[3]].filter.auto_filter_zone = v
							end,
						},
						zone = {
							name = L["FilterZone"],
							width = "full",
							type = "input",
							order = 10,
							multiline = 10,
							disabled = true,
							get = function(info, v)
								local output = ""
								if db.questList[info[3]].filter ~= nil and db.questList[info[3]].filter.zones ~= nil then
									for key, zone in pairs(db.questList[info[3]].filter.zones) do
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
								if db.questList[info[3]].filter == nil then
									db.questList[info[3]].filter = {}
								end
								if db.questList[info[3]].filter.types == nil then
									db.questList[info[3]].filter.types = {}
								end
								db.questList[info[3]].filter.types.zone = v
							end,
							get = function(info, v)
								if db.questList[info[3]].filter ~= nil and db.questList[info[3]].filter.types ~= nil then
									return db.questList[info[3]].filter.types.zone or "blacklist"
								end
								return "blacklist"
							end,
							values = {
								["blacklist"] = L["Blacklist"],
								["whitelist"] = L["Whitelist"],
							},
						},
						add_zone = {
							name = L["FilterZoneAdd"],
							desc = L["FilterZoneAddTooltip"],
							width = "half",
							type = "execute",
							order = 30,
							disabled = function(info) return db.questList[info[3]].filter and db.questList[info[3]].filter.zones and db.questList[info[3]].filter.zones[tostring(getZoneFromMap())] end,
							func = function(info)
								addZoneToFilterList(info[3])
							end,
						},
						del_zone = {
							name = L["FilterZoneRemove"],
							desc = L["FilterZoneRemoveTooltip"],
							width = "half",
							type = "execute",
							order = 40,
							disabled = function(info) return db.questList[info[3]].filter == nil or db.questList[info[3]].filter.zones == nil or db.questList[info[3]].filter.zones[tostring(getZoneFromMap())] ~= true end,
							func = function(info)
								local currentMap = getZoneFromMap()

								if db.questList[info[3]].filter == nil then
									db.questList[info[3]].filter = {}
								end
								if db.questList[info[3]].filter.zones == nil then
									db.questList[info[3]].filter.zones = {}
								end
								db.questList[info[3]].filter.zones[tostring(currentMap)] = nil

								refreshQuestFrameVisibility(currentMap)
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

	-- Get the option table for profiles
	options.args.profiles = ACO:GetOptionsTable(self.db)
	options.args.profiles.name = L["Profiles"]

	ACR:RegisterOptionsTable(addonName, options)
	self:RegisterChatCommand("dropquests", function() ACDI:Open(addonName) end)

	self.optionsFrame = {}
	self.optionsFrame.general = ACDI:AddToBlizOptions(addonName, addonName, nil, "general")
	--self.optionsFrame.quests = ACDI:AddToBlizOptions(addonName, options.args.quests.name, addonName, "quests")
	self.optionsFrame.profiles = ACDI:AddToBlizOptions(addonName, options.args.profiles.name, addonName, "profiles")

	-- Show/Hide quests when switching between zones for filtered quests
	HBD.RegisterCallback(self, "PlayerZoneChanged", "OnZoneChanged")

	-- Initialize options from database
	for key, value in pairs(db.questList) do
		initializeQuestSlotOptions(key)
		local questOptions = options.args.general.args.quests.args[key]

		questOptions.name = getQuestName(key) or "New Quest"
		initializeQuestVars(key)
	end

	eventFrame = CreateFrame("Frame")

	eventFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "DISPLAY_SIZE_CHANGED" then
			screenWidth = GetScreenWidth()
			screenHeight = GetScreenHeight()
			for key, value in pairs(db.questList) do
				updateQuestSlotOptions(key)
			end
			ACR:RegisterOptionsTable(addonName, options)
			ACR:NotifyChange(addonName)
		elseif event == "SPELLS_CHANGED" then
			refreshQuestFrameVisibility()
			eventFrame:UnregisterEvent(event)
		end
	end)

	eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

	-- If there's no map, register an event that will try again on login
	if not refreshQuestFrameVisibility() then
		eventFrame:RegisterEvent("SPELLS_CHANGED")
	end

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

	-- Check each quest to show/hide depending on their filters
	refreshQuestFrameVisibility(currentPlayerUiMapID)

	previousPlayerUiMapID = currentPlayerUiMapID
end
