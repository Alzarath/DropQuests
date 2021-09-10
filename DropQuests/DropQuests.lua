--[[
DropQuests
]]

----------------------
-- Library declaration
----------------------

local ACE = LibStub("AceAddon-3.0")
local ACDB = LibStub("AceDB-3.0")
local ACDI = LibStub("AceConfigDialog-3.0")
local AGUI = LibStub("AceGUI-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local ACO = LibStub("AceDBOptions-3.0")
local HBD = LibStub("HereBeDragons-2.0")
local LSM = LibStub("LibSharedMedia-3.0")
local MN = LibStub("MapNames")
local WidgetLists = AceGUIWidgetLSMlists

--------------------
-- Addon declaration
--------------------

local addonName = "DropQuests"
local addonDisplayName = "|cFFFF9933"..addonName.."|r"
DropQuests = ACE:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local DropQuests = DropQuests
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)
local DB_VERSION = 2

----------------------
-- Global localization
----------------------

local pairs, next, type = pairs, next, type
local CreateFrame = CreateFrame

-----------------------
-- Variable declaration
-----------------------

-- Constants
local MAX_QUESTS = 200
local DEFAULT_PROGRESS_BAR_WIDTH = 80
local DEFAULT_PROGRESS_BAR_HEIGHT = 16
local DEFAULT_PADDING = 4
local DEFAULT_QUEST_CONTAINER_SEPARATOR = 40
local DEFAULT_PROGRESS_BAR_TEXTURE = "Blizzard"
local BUTTON_WIDTH_SMALL = 18.5
local BUTTON_WIDTH_NORMAL = 37

-- Session variables
local questVars = {}
local containerVars = {}
local eventFrame

local screenWidth = GetScreenWidth()
local screenHeight = GetScreenHeight()

local questContainer

local MapNameIDs = MN.MapNameTable

--------------------------
-- Database initialization
--------------------------

local db
local options
local defaults = {
	profile = {
		enabled = true,
		appearance = {
			defaults = {}
		},
		questList = {},
		groupList = {},
	},
}

---------------------
-- General Functions
---------------------

function DropQuests:CountUsedIndices(checked_table)
	local count = 0
	for _ in pairs(checked_table) do count = count + 1 end
	return count
end

function DropQuests:GetEmptyIndex(checked_table, maximum_items)
	local maximum_items = maximum_items or -1
	local index = 1

	if checked_table == nil or checked_table[tostring(index)] == nil then
		return index
	end

	while index ~= maximum_items do
		index = index + 1
		if checked_table[tostring(index)] == nil then
			return index
		end
	end

	return nil
end

function DropQuests:CopyTable(obj, seen)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[DropQuests:CopyTable(k, s)] = DropQuests:CopyTable(v, s) end
	return res
end

------------------
-- Quest Functions
------------------

function DropQuests:AddQuestToSlot(slot_number)
	DropQuests:InitializeQuestSlotOptions(slot_number)
	DropQuests:InitializeDatabaseWithQuest(slot_number)
	DropQuests:InitializeQuestVars(slot_number)

	ACR:RegisterOptionsTable(addonName, options, nil)
end

function DropQuests:RemoveQuestFromSlot(slot_number)
	DropQuests:HideQuestFrame(slot_number)
	frame = DropQuests:GetFrameFromSlot(slot_number)
	options.args.quests.args[slot_number] = nil
	db.questList[slot_number] = nil
	frame:UnregisterEvent("ITEM_PUSH")
	frame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")

	ACR:RegisterOptionsTable(addonName, options, nil)
end

function DropQuests:AddZoneToFilterList(slot_number, uiMapID)
	local frame = DropQuests:GetFrameFromSlot(slot_number)
	local uiMapID = uiMapID or C_Map.GetBestMapForUnit("player")
	local zone = MN:GetZoneFromMap(uiMapID, true)

	-- Do not attempt to add a map that is not a zone
	if not zone then return nil end

	if db.questList[slot_number].filter == nil then
		db.questList[slot_number].filter = {}
	end
	if db.questList[slot_number].filter.zones == nil then
		db.questList[slot_number].filter.zones = {}
	end
	db.questList[slot_number].filter.zones[tostring(zone)] = true

	frame:UpdateVisibility(tostring(zone))

	return zone
end

function DropQuests:AddContinentToFilterList(slot_number, uiMapID)
	local frame = DropQuests:GetFrameFromSlot(slot_number)
	local uiMapID = uiMapID or C_Map.GetBestMapForUnit("player")

	local continent = MN:GetContinentFromMap(uiMapID, true)

	-- Do not attempt to add a map that is not a continent
	if not continent then return nil end

	if db.questList[slot_number].filter == nil then
		db.questList[slot_number].filter = {}
	end
	if db.questList[slot_number].filter.continents == nil then
		db.questList[slot_number].filter.continents = {}
	end
	db.questList[slot_number].filter.continents[tostring(continent)] = true

	frame:UpdateVisibility(tostring(continent))

	return continent
end

-- Initializes session-based variables for a quest
function DropQuests:InitializeQuestVars(slot_number)
	questVars[slot_number] = {}
	questVars[slot_number].frame_update_queued = false
	questVars[slot_number].complete = db.questList[slot_number].goal == nil or (GetItemCount(db.questList[slot_number].itemID) >= db.questList[slot_number].goal)
	questVars[slot_number].frame = DropQuests:CreateQuestFrame(slot_number)
	questVars[slot_number].selected = nil
end

-- Returns true if the quest should be visible
function DropQuests:QuestVisibilityCheck(slot_number, currentPlayerUiMapID)
	-- Check if the quest is disabled
	if db.questList[slot_number].enabled ~= nil and db.questList[slot_number].enabled == false then
		return false
	end

	-- Check if the quest has any filters
	if db.questList[slot_number].filter == nil then
		return true
	end

	currentPlayerUiMapID = currentPlayerUiMapID or C_Map.GetBestMapForUnit("player")

	local currentContinent = tostring(MN:GetContinentFromMap(currentPlayerUiMapID, true))
	local currentZone = tostring(MN:GetZoneFromMap(currentPlayerUiMapID, true))

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

	local frame = DropQuests:GetFrameFromSlot(slot_number)

	-- If nothing applies, keep it as-is
	return frame ~= nil and frame:IsVisible()
end

function DropQuests:SetQuestItem(slot_number, itemID)
	if itemID == nil then
		db.questList[slot_number].itemID = nil
		return
	end

	local update_quest_name = db.questList[slot_number].name == nil

	local quest_type = DropQuests:GetQuestType(slot_number)

	db.questList[slot_number].itemID = itemID
	if quest_type == "item" then
		db.questList[slot_number].itemIcon = GetItemIcon(itemID)
	end

	if update_quest_name then
		DropQuests:UpdateQuestOptionName(slot_number)
	end

	ACR:NotifyChange(addonName)
end

function DropQuests:GetQuestType(slot_number)
	return db.questList[slot_number].quest_type ~= nil and db.questList[slot_number].quest_type or "item"
end

function DropQuests:GetQuestName(slot_number)
	local returned_name = db.questList[slot_number] and db.questList[slot_number].name or nil
	if returned_name == nil and db.questList[slot_number].itemID then
		if DropQuests:GetQuestType(slot_number) == "currency" then
			local currencyInfo = C_CurrencyInfo.GetBasicCurrencyInfo(db.questList[slot_number].itemID)

			if currencyInfo then returned_name = currencyInfo.name end
		elseif db.questList[slot_number].itemID then
			returned_name = GetItemInfo(db.questList[slot_number].itemID)
		end
	end
	return returned_name
end

-- Initializes session-based variables for a container
function DropQuests:InitializeContainerVars(slot_number)
	containerVars[slot_number] = {}
	containerVars[slot_number].frame = DropQuests:CreateQuestContainer(slot_number)
end

-------------------
-- Option Functions
-------------------

function DropQuests:RefreshOptions()
	options = DropQuests:CopyTable(default_options)

	for key, value in pairs(questVars) do
		DropQuests:HideQuestFrame(key)
	end

	questVars = {}

	-- Initialize quest options from database
	for key, value in pairs(db.questList) do
		DropQuests:InitializeQuestSlotOptions(key)
		local questOptions = options.args.quests.args[key]

		DropQuests:UpdateQuestOptionName(key)
		DropQuests:InitializeQuestVars(key)
	end

	-- Get the option table for profiles
	options.args.profiles = ACO:GetOptionsTable(self.db)
	options.args.profiles.name = L["Profiles"]
end

function DropQuests:InitializeQuestSlotOptions(slot_number)
	options.args.quests.args[slot_number] = DropQuests:CopyTable(quest_template)
	DropQuests:UpdateQuestSlotOptions(slot_number)
end

function DropQuests:UpdateQuestSlotOptions(slot_number)
	options.args.quests.args[slot_number].args.appearance_options.args.x_offset.softMax = math.floor(screenWidth + 0.5)
	options.args.quests.args[slot_number].args.appearance_options.args.y_offset.softMax = math.floor(screenHeight + 0.5)
	ACR:NotifyChange(addonName)
end

function DropQuests:UpdateQuestOptionName(slot_number)
	local name = DropQuests:GetQuestName(slot_number)
	if name == nil then
		local quest_type = DropQuests:GetQuestType(slot_number)
		if quest_type == "item" and tonumber(db.questList[slot_number].itemID) then
			local item = Item:CreateFromItemID(db.questList[slot_number].itemID)

			item:ContinueOnItemLoad(function()
				options.args.quests.args[slot_number].name = DropQuests:GetQuestName(slot_number) or "Invalid"

				ACR:NotifyChange(addonName)
			end)
		else
			options.args.quests.args[slot_number].name = "New Quest"
			ACR:NotifyChange(addonName)
		end
	else
		options.args.quests.args[slot_number].name = name
		ACR:NotifyChange(addonName)
	end
end

---------------------
-- Database Functions
---------------------

function DropQuests:MigrateDB(migrate_version)
	print(addonDisplayName..":", "Migrating database from DB", "v"..migrate_version, "to", "v"..DB_VERSION)

	-- Migrate database version 1 to version 2
	if migrate_version <= 1 then
		if db.defaults ~= nil then
			if db.appearance == nil then
				db.appearance = {}
			end
			if db.appearance.defaults == nil then
				db.appearance.defaults = {}
			end
			for key, value in pairs(db.defaults) do
				if db.appearance.defaults == nil or db.appearance.defaults[key] == nil then
					db.appearance.defaults[key] = DropQuests:CopyTable(db.defaults[key])
				end
			end
			db.defaults = nil
		end
		for key, value in pairs(db.questList) do
			if db.questList[key].text_hover_mode ~= nil then
				if db.questList[key].appearance == nil then
					db.questList[key].appearance = {}
				end
				db.questList[key].appearance.text_hover_mode = db.questList[key].appearance.text_hover_mode or db.questList[key].text_hover_mode
				db.questList[key].text_hover_mode = nil
			end
		end

		db.version = 2
	end
end

function DropQuests:InitializeDatabaseWithQuest(slot_number)
	if not db.questList[slot_number] then
		db.questList[slot_number] = {}
	end
	db.questList[slot_number].disabled = false
end

------------------
-- Frame Functions
------------------

function DropQuests:CreateQuestFrame(slot_number)
	local frame = CreateFrame("Frame", "questframe_"..slot_number, UIParent, "StatusTrackingBarTemplate")
	local padding = DEFAULT_PADDING

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

		db.questList[slot_number].appearance.x = horizontal_anchor == "RIGHT" and screenWidth - frame:GetRight() or frame:GetLeft()
		db.questList[slot_number].appearance.y = vertical_anchor == "TOP" and screenHeight - frame:GetTop() or frame:GetBottom()

		frame:UpdateFramePosition()
		ACR:NotifyChange(addonName)
	end

	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", startMoving)
	frame:SetScript("OnDragStop", stopMoving)
	local quest_type = DropQuests:GetQuestType(slot_number)
	local event_type = quest_type ~= nil and quest_type == "currency" and "CURRENCY_DISPLAY_UPDATE" or "ITEM_PUSH"
	frame:RegisterEvent(event_type)
	frame:SetClampedToScreen(db.questList[slot_number].appearance and db.questList[slot_number].appearance.clamped_to_screen or true)

	frame.button = CreateFrame("ItemButton", "questframe_"..slot_number.."_button", frame)
	frame.button:SetPoint("BOTTOMLEFT", padding, padding)
	frame.button:SetMouseClickEnabled(true)
	frame.button:RegisterForDrag("LeftButton")
	frame.button:SetScript("OnDragStart", startMoving)
	frame.button:SetScript("OnDragStop", stopMoving)

	local button_width = frame.button:GetWidth()
	local progress_offset = padding * 2 + button_width
	local vertical_height = progress_offset

	frame:SetSize(128, vertical_height)

	frame.name = frame:CreateFontString()
	frame.name:SetSize(DEFAULT_PROGRESS_BAR_WIDTH, DEFAULT_PROGRESS_BAR_HEIGHT)
	frame.name:SetPoint("BOTTOMLEFT", progress_offset, padding * 2 + DEFAULT_PROGRESS_BAR_HEIGHT)
	frame.name:SetFontObject("GameFontNormal")
	frame.name:SetJustifyH("LEFT")
	frame.name:SetWordWrap(false)
	frame.name:SetNonSpaceWrap(false)

	frame.progress_text_frame = CreateFrame("Frame", "questframe_"..slot_number.."_progresstext", frame)
	frame.progress_text_frame:SetSize(frame:GetWidth(), frame:GetHeight())
	frame.progress_text_frame:SetPoint("BOTTOMLEFT")
	frame.progress_text = frame.progress_text_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.progress_text:SetPoint("BOTTOMLEFT", progress_offset, padding)
	frame.progress_text:SetSize(DEFAULT_PROGRESS_BAR_WIDTH, DEFAULT_PROGRESS_BAR_HEIGHT)
	frame.progress_text:SetJustifyH("RIGHT")
	frame.progress_text:SetJustifyV("MIDDLE")
	frame.progress_text:SetMaxLines(1)
	frame.progress_text:SetTextColor(1.0, 1.0, 1.0)

	frame.StatusBar:SetPoint("BOTTOMLEFT", progress_offset, padding)
	frame.StatusBar:SetSize(DEFAULT_PROGRESS_BAR_WIDTH, DEFAULT_PROGRESS_BAR_HEIGHT)
	frame.StatusBar:SetStatusBarColor(0.75, 0.75, 0.75)

	frame.button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		if DropQuests:GetQuestType(slot_number) == "currency" then
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
		ACDI:SelectGroup(addonName, "quests", slot_number)
	end)

	local function itemPickupEvent(self, event, ...)
		if (event == "ITEM_PUSH") then
			local bag_slot, item_icon_id = ...
			if db.questList[slot_number].itemIcon == item_icon_id then
				questVars[slot_number].frame_update_queued = true
				if db.questList[slot_number].filter ~= nil then
					if db.questList[slot_number].filter.auto_filter_continent ~= nil and db.questList[slot_number].filter.auto_filter_continent then
						DropQuests:AddContinentToFilterList(slot_number)
					end
					if db.questList[slot_number].filter.auto_filter_zone ~= nil and db.questList[slot_number].filter.auto_filter_zone then
						DropQuests:AddZoneToFilterList(slot_number)
					end
				end
			end
		elseif (event == "CURRENCY_DISPLAY_UPDATE") then
			local currency_id, _, _, _, _ = ...
			if db.questList[slot_number].itemID == currency_id then
				if db.questList[slot_number].filter ~= nil then
					if db.questList[slot_number].filter.auto_filter_continent ~= nil and db.questList[slot_number].filter.auto_filter_continent then
						DropQuests:AddContinentToFilterList(slot_number)
					end
					if db.questList[slot_number].filter.auto_filter_zone ~= nil and db.questList[slot_number].filter.auto_filter_zone then
						DropQuests:AddZoneToFilterList(slot_number)
					end
				end
				frame:UpdateQuestProgress()
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
		if db.appearance == nil or not db.appearance.grouped then
			frame:UpdateFramePosition()
		end
		frame:UpdateFrameSize()
		frame:UpdateQuestProgressFrame()

		return true
	end

	function frame:UpdateItem()
		if db.questList[slot_number].itemID == nil then
			return nil
		end

		local quest_type = DropQuests:GetQuestType(slot_number)

		if quest_type == "currency" then
			local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(db.questList[slot_number].itemID)
			frame.button:Reset()
			if currencyInfo then SetItemButtonTexture(frame.button, currencyInfo.iconFileID) end
		elseif quest_type == "item" then
			frame.button:SetItem(db.questList[slot_number].itemID)
		end

		if db.questList[slot_number].name == nil then
			frame:UpdateName()
		end

		frame:UpdateQuestProgress()

		return db.questList[slot_number].itemID
	end

	function frame:UpdateName()
		local quest_type = DropQuests:GetQuestType(slot_number)
		local new_name = DropQuests:GetQuestName(slot_number) or ""

		if quest_type == "item" and new_name == "" and tonumber(db.questList[slot_number].itemID) then
			local item = Item:CreateFromItemID(db.questList[slot_number].itemID)

			item:ContinueOnItemLoad(function()
				frame.name:SetText(DropQuests:GetQuestName(slot_number) or "")
			end)
		else
			frame.name:SetText(new_name)
		end

		return new_name
	end

	function frame:UpdateFrameSize()
		local show_name = true
		local show_icon = true
		local show_value = true
		local show_progress_bar = true
		local merge_name_progress = false
		local progress_bar_width = DEFAULT_PROGRESS_BAR_WIDTH
		local icon_scale = 1.0
		if db.appearance == nil or db.appearance.grouped then
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_name ~= nil then
				show_name = db.appearance.defaults.show_name
			end
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_icon ~= nil then
				show_icon = db.appearance.defaults.show_icon
			end
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_value ~= nil then
				show_value = db.appearance.defaults.show_value
			end
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_progress_bar ~= nil then
				show_progress_bar = db.appearance.defaults.show_progress_bar
			end
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.merge_name_progress ~= nil then
				merge_name_progress = db.appearance.defaults.merge_name_progress
			end
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.progress_width ~= nil then
				progress_bar_width = db.appearance.defaults.progress_width
			end
		else
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_name ~= nil then
				show_name = db.questList[slot_number].appearance.show_name
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_name ~= nil then
				show_name = db.appearance.defaults.show_name
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_value ~= nil then
				show_value = db.questList[slot_number].appearance.show_value
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_value ~= nil then
				show_value = db.appearance.defaults.show_value
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_icon ~= nil then
				show_icon = db.questList[slot_number].appearance.show_icon
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_icon ~= nil then
				show_icon = db.appearance.defaults.show_icon
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_progress_bar ~= nil then
				show_progress_bar = db.questList[slot_number].appearance.show_progress_bar
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_progress_bar ~= nil then
				show_progress_bar = db.appearance.defaults.show_progress_bar
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.merge_name_progress ~= nil then
				merge_name_progress = db.questList[slot_number].appearance.merge_name_progress
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.merge_name_progress ~= nil then
				merge_name_progress = db.appearance.defaults.merge_name_progress
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.progress_width ~= nil then
				progress_bar_width = db.questList[slot_number].appearance.progress_width
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.progress_width ~= nil then
				progress_bar_width = db.appearance.defaults.progress_width
			end
		end

		-- Minify the icon if either the progress bar or name are not shown to save space
		if merge_name_progress or not show_name or not show_progress_bar and not show_value then
			icon_scale = 0.5
		end

		frame.button:SetScale(icon_scale)
		button_width = frame.button:GetWidth() * icon_scale
		vertical_height = padding * 2 + button_width
		if show_icon then
			progress_offset = vertical_height
		else
			button_width = 0
			progress_offset = padding
		end

		local text_width = progress_bar_width
		if progress_bar_width > 0 then
			frame:SetSize(progress_offset + progress_bar_width + padding, vertical_height)
			frame.StatusBar:SetShown(show_progress_bar)
			frame.name:SetShown(show_name)
			frame.StatusBar:SetSize(progress_bar_width, frame.StatusBar:GetHeight())

			frame.progress_text:SetPoint("BOTTOMLEFT", progress_offset, padding)
			frame.progress_text:SetMaxLines(1)
			frame.progress_text:SetJustifyV("MIDDLE")
		elseif show_icon then
			frame:SetSize(progress_offset, vertical_height)
			frame.StatusBar:Hide()
			frame.name:Hide()

			text_width = max(1, button_width - padding)
			frame.progress_text:SetPoint("BOTTOMLEFT", padding + padding / 2, padding + padding / 2)
			frame.progress_text:SetMaxLines(2)
			frame.progress_text:SetJustifyV("BOTTOM")
		end

		-- Show/hide the frame if it would be 0-width anyways
		if progress_bar_width > 0 then
			if not frame:IsVisible() and DropQuests:QuestVisibilityCheck(slot_number) then
				frame:Show()
			end
		else
			if frame:IsVisible() and not show_icon then
				frame:Hide()
			end
		end

		if merge_name_progress or not show_progress_bar and not show_value and show_name then
			frame.name:SetPoint("BOTTOMLEFT", progress_offset, padding)
		else
			frame.name:SetPoint("BOTTOMLEFT", progress_offset, padding * 2 + DEFAULT_PROGRESS_BAR_HEIGHT)
		end

		if show_progress_bar then
			frame.StatusBar:SetPoint("BOTTOMLEFT", progress_offset, padding)
		end
		if show_name then
			frame.name:SetSize(text_width, frame.name:GetHeight())
		end
		frame.button:SetShown(show_icon)
		frame.progress_text_frame:SetSize(frame:GetWidth(), frame:GetHeight())
		frame.progress_text:SetSize(text_width, DEFAULT_PROGRESS_BAR_HEIGHT)

		frame:UpdateQuestProgressFrame()
	end

	function frame:UpdateFramePosition(x, y)
		frame:ClearAllPoints()

		if (db.questList[slot_number].appearance == nil or db.questList[slot_number].appearance.x == nil or db.questList[slot_number].appearance.y == nil) and (x == nil or y == nil) then
			frame:SetPoint("CENTER")
			return
		end

		local anchor = db.questList[slot_number].appearance and db.questList[slot_number].appearance.anchor or "BOTTOMLEFT"

		local horizontal_anchor = string.sub(anchor, -5, -1) == "RIGHT" and "RIGHT" or "LEFT"
		local vertical_anchor = string.sub(anchor, 1, 3) == "TOP" and "TOP" or "BOTTOM"

		local x_offset = x or db.questList[slot_number].appearance.x
		local y_offset = y or db.questList[slot_number].appearance.y

		if horizontal_anchor == "RIGHT" then
			x_offset = -1 * x_offset
		end

		if vertical_anchor == "TOP" then
			y_offset = -1 * y_offset
		end

		frame:SetPoint(anchor, x_offset, y_offset)
	end

	function frame:UpdateQuestProgress(value)
		local use_bank = db.questList[slot_number].use_bank ~= nil and db.questList[slot_number].use_bank or true
		local show_value = true
		local show_maximum = true
		local show_icon = true
		local use_currency_maximum = false

		if db.appearance == nil or db.appearance.grouped then
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_value ~= nil then
				show_value = db.appearance.defaults.show_value
			end
			if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_icon ~= nil then
				show_icon = db.appearance.defaults.show_icon
			end
		else
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_value ~= nil then
				show_value = db.questList[slot_number].appearance.show_value
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_value ~= nil then
				show_value = db.appearance.defaults.show_value
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_icon ~= nil then
				show_icon = db.questList[slot_number].appearance.show_icon
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_icon ~= nil then
				show_icon = db.appearance.defaults.show_icon
			end
		end

		if db.questList[slot_number].use_currency_maximum ~= nil then
			use_currency_maximum = db.questList[slot_number].use_currency_maximum
		end

		if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_maximum ~= nil then
			show_maximum = db.questList[slot_number].appearance.show_maximum
		elseif (db.questList[slot_number].goal == nil or db.questList[slot_number].goal == 0) and not use_currency_maximum then
			show_maximum = false
		elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_maximum ~= nil then
			show_maximum = db.appearance.defaults.show_maximum
		end

		local itemCount = value or 0
		local itemGoal = db.questList[slot_number].goal or 0

		if db.questList[slot_number].itemID ~= nil then
			if value == nil then
				if DropQuests:GetQuestType(slot_number) == "currency" then
					local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(db.questList[slot_number].itemID)
					if currencyInfo then itemCount = currencyInfo.quantity end
				else
					itemCount = GetItemCount(db.questList[slot_number].itemID, use_bank, false, use_bank) or 0
				end
			end
			if use_currency_maximum then
				local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(db.questList[slot_number].itemID)
				itemGoal = currencyInfo.maxQuantity or itemGoal
			end
		end

		frame.StatusBar:SetMinMaxValues(0, itemGoal)
		frame.StatusBar:SetValue(math.min(itemCount, itemGoal))

		if show_value then
			local textOutput = tostring(itemCount)
			local text_display = (db.questList[slot_number].appearance and db.questList[slot_number].appearance.text_display) or (db.appearance and db.appearance.defaults and db.appearance.defaults.text_display) or "numeric"

			if text_display == "numeric" then
				if show_maximum then
					textOutput = textOutput .. "/" .. itemGoal
				end
			elseif text_display == "countdown" then
				textOutput = tostring(itemCount - itemGoal)
			elseif text_display == "percentage" then
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

		questVars[slot_number].complete = itemCount >= itemGoal

		-- Adjust color depending on completion.
		if (questVars[slot_number].complete == true) then
			frame.StatusBar:SetStatusBarColor(0.0, 1.0, 0.0)
		else
			local itemRatio = itemCount / max(itemGoal, 1)

			frame.StatusBar:SetStatusBarColor(0.5 + (itemRatio * 0.5), 0.5 + (itemRatio * 0.5), 0.5 - (itemRatio * 0.5))
		end
	end

	function frame:UpdateQuestProgressFrame()
		local show_value = true
		local hover_mode = false
		local progress_bar_texture = DEFAULT_PROGRESS_BAR_TEXTURE

		if db.appearance ~= nil and db.appearance.grouped then
			if db.appearance.defaults ~= nil then
				if db.appearance.defaults.show_value ~= nil then
					show_value = db.appearance.defaults.show_value
				end
				if db.appearance.defaults.text_hover_mode ~= nil then
					hover_mode = db.appearance.defaults.text_hover_mode
				end
				if db.appearance.defaults.progress_bar_texture ~= nil then
					progress_bar_texture = db.appearance.defaults.progress_bar_texture
				end
			end
		else
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.show_value ~= nil then
				show_value = db.questList[slot_number].appearance.show_value
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_value ~= nil then
				show_value = db.appearance.defaults.show_value
			end
			if db.questList[slot_number].appearance ~= nil and db.questList[slot_number].appearance.text_hover_mode ~= nil then
				hover_mode = db.questList[slot_number].appearance.text_hover_mode
			elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.text_hover_mode ~= nil then
				hover_mode = db.appearance.defaults.text_hover_mode
			end
		end

		frame.progress_text:SetShown(show_value)
		if show_value then
			frame.progress_text_frame:EnableMouse(hover_mode)
			frame.progress_text:SetDrawLayer(hover_mode and "HIGHLIGHT" or "OVERLAY")
		end

		frame.StatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", progress_bar_texture))

		--frame.name:SetShown(show_name)
		--frame.StatusBar:SetSize(frame.StatusBar:GetWidth(), show_name and 16 or 16 * 2 + padding)

		frame:UpdateQuestProgress()
	end

	function frame:UpdateVisibility(uiMapID)
		local wasVisible = frame:IsVisible()
		local isVisible = false

		if DropQuests:QuestVisibilityCheck(slot_number, uiMapID) then
			isVisible = DropQuests:ShowQuestFrame(slot_number)
		else
			isVisible = DropQuests:HideQuestFrame(slot_number)
		end

		if db.appearance and db.appearance.grouped then
			moveQuestsToContainer()
		end

		return frame:IsVisible()
	end

	return frame
end

function DropQuests:CreateQuestContainer(slot_number)
	local frame = CreateFrame("Frame", "questframe_container_default", UIParent)

	frame:SetPoint("CENTER")
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetScript("OnDragStart", function() startMovingQuestContainer() end)
	frame:SetScript("OnDragStop", function() stopMovingQuestContainer() end)

	function frame:UpdateFrameWidth()
		local width = db.containerList[slot_number].appearance and db.containerList[slot_number].appearance.width
				   or db.appearance and db.appearance.defaults and db.appearance.defaults.progress_width
				   or DEFAULT_PROGRESS_BAR_WIDTH
		width = width + DEFAULT_PADDING * 4

		if db.appearance == nil or db.appearance.defaults == nil or db.appearance.defaults.show_icon == nil or db.appearance.defaults.show_icon then
			if db.appearance == nil or db.appearance.defaults == nil or (db.appearance.defaults.merge_name_progress == nil or (db.appearance.defaults.show_progress_bar == nil or db.appearance.defaults.show_progress_bar or db.appearance.defaults.show_value == nil or db.appearance.defaults.show_value) and db.appearance.defaults.show_name == nil or db.appearance.defaults.show_name) then
				width = width + BUTTON_WIDTH_NORMAL + DEFAULT_PADDING
			else
				width = width + BUTTON_WIDTH_SMALL + DEFAULT_PADDING
			end
		end

		frame:SetWidth(questContainerWidth)

		return questContainerWidth
	end

	function frame:UpdateFramePosition(x, y)
		frame:ClearAllPoints()

		-- TODO: Quest -> Container
		if (db.containerList[slot_number].appearance == nil or db.containerList[slot_number].appearance.x == nil or db.containerList[slot_number].appearance.y == nil) and (x == nil or y == nil) then
			frame:SetPoint("CENTER")
			return
		end

		-- TODO: Quest -> Container
		local anchor = db.containerList[slot_number].appearance and db.containerList[slot_number].appearance.anchor or "BOTTOMLEFT"

		local horizontal_anchor = string.sub(anchor, -5, -1) == "RIGHT" and "RIGHT" or "LEFT"
		local vertical_anchor = string.sub(anchor, 1, 3) == "TOP" and "TOP" or "BOTTOM"

		-- TODO: Quest -> Container
		local x_offset = x or db.containerList[slot_number].appearance.x
		local y_offset = y or db.containerList[slot_number].appearance.y

		if horizontal_anchor == "RIGHT" then
			x_offset = -1 * x_offset
		end

		if vertical_anchor == "TOP" then
			y_offset = -1 * y_offset
		end

		frame:SetPoint(anchor, x_offset, y_offset)
	end

	return frame
end

function DropQuests:ShowQuestFrame(slot_number)
	local frame = DropQuests:GetFrameFromSlot(slot_number)

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

function DropQuests:HideQuestFrame(slot_number)
	local frame = DropQuests:GetFrameFromSlot(slot_number)

	if frame ~= nil then
		frame:UnregisterEvent("BAG_UPDATE_DELAYED")

		frame:Hide()
		return frame:IsVisible()
	end

	return false
end

function DropQuests:GetFrameFromSlot(slot_number)
	return questVars[slot_number].frame
end

-- Refresh the visibility of all quest frames assuming the designated map ID
function DropQuests:RefreshQuestFrameVisibility(uiMapID)
	uiMapID = uiMapID or MN:GetZoneFromMap(nil, true)
	if uiMapID == nil then return false end

	for key, quest in pairs(db.questList) do
		local frame = DropQuests:GetFrameFromSlot(key)
		frame:UpdateVisibility(uiMapID)
	end

	return true
end

----------------------------
-- Quest Container Functions
----------------------------

function attachFramesToContainer()
	setQuestContainerWidth()
	setQuestContainerPosition()
	moveQuestsToContainer()

	questContainer:Show()
end

function detachFramesFromContainer()
	for key, _ in pairs(db.questList) do
		local frame = DropQuests:GetFrameFromSlot(key)

		frame:SetParent(UIParent)
		frame:UpdateFramePosition()

		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame.button:RegisterForDrag("LeftButton")
	end
	questContainer:Hide()
end

function setQuestContainerPosition()
	questContainer:ClearAllPoints()
	if db.appearance and db.appearance.group and (db.appearance.group.x_offset or db.appearance.group.y_offset) then
		questContainer:SetPoint("BOTTOMLEFT", db.appearance.group.x_offset, db.appearance.group.y_offset)
	else
		questContainer:SetPoint("CENTER")
	end
end

function setQuestContainerWidth()
	local questContainerWidth = db.appearance and db.appearance.defaults and db.appearance.defaults.progress_width or DEFAULT_PROGRESS_BAR_WIDTH
	questContainerWidth = questContainerWidth + DEFAULT_PADDING * 4

	if db.appearance == nil or db.appearance.defaults == nil or db.appearance.defaults.show_icon == nil or db.appearance.defaults.show_icon then
		if db.appearance == nil or db.appearance.defaults == nil or (db.appearance.defaults.merge_name_progress == nil or (db.appearance.defaults.show_progress_bar == nil or db.appearance.defaults.show_progress_bar or db.appearance.defaults.show_value == nil or db.appearance.defaults.show_value) and db.appearance.defaults.show_name == nil or db.appearance.defaults.show_name) then
			questContainerWidth = questContainerWidth + BUTTON_WIDTH_NORMAL + DEFAULT_PADDING
		else
			questContainerWidth = questContainerWidth + BUTTON_WIDTH_SMALL + DEFAULT_PADDING
		end
	end

	questContainer:SetWidth(questContainerWidth)

	return questContainerWidth
end

function moveQuestsToContainer()
	local heightOffset = DEFAULT_PADDING
	local lastFrameHeight = 0
	local separator = db.appearance and db.appearance.group and db.appearance.group.separator or DEFAULT_QUEST_CONTAINER_SEPARATOR

	for key, _ in pairs(db.questList) do
		local frame = DropQuests:GetFrameFromSlot(key)

		frame:SetParent(questContainer)
		frame:EnableMouse(false)
		frame:RegisterForDrag()
		frame.button:RegisterForDrag()

		if DropQuests:QuestVisibilityCheck(key) then
			lastFrameHeight = frame:GetHeight()
			frame:ClearAllPoints()
			frame:SetPoint("BOTTOMLEFT", DEFAULT_PADDING, heightOffset)
			heightOffset = heightOffset + separator
		end
	end
	questContainer:SetHeight(heightOffset - separator + lastFrameHeight + DEFAULT_PADDING)
end

function startMovingQuestContainer()
	local frame = questContainer
	frame:StartMoving()
end

function stopMovingQuestContainer()
	local frame = questContainer
	frame:StopMovingOrSizing()
	local anchor = "BOTTOMLEFT"

	local horizontal_anchor = string.sub(anchor, -5, -1) == "RIGHT" and "RIGHT" or "LEFT"
	local vertical_anchor = string.sub(anchor, 1, 3) == "TOP" and "TOP" or "BOTTOM"

	if db.appearance == nil then
		db.appearance = {}
	end
	if db.appearance.group == nil then
		db.appearance.group = {}
	end

	db.appearance.group.x_offset = horizontal_anchor == "RIGHT" and screenWidth - frame:GetRight() or frame:GetLeft()
	db.appearance.group.y_offset = vertical_anchor == "TOP" and screenHeight - frame:GetTop() or frame:GetBottom()

	frame:ClearAllPoints()
	frame:SetPoint(anchor, db.appearance.group.x_offset, db.appearance.group.y_offset)
	ACR:NotifyChange(addonName)
end

----------------
-- Options table
----------------

options = {}

default_options = {
	name = L[addonName],
	desc = L[addonName],
	type = "group",
	childGroups = "tab",
	args = {
		enabled = {
			name = L["EnableDropQuests"],
			desc = L["EnableDropQuestsTooltip"],
			type = "toggle",
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
				local quest_slot = tostring(DropQuests:GetEmptyIndex(db.questList))
				DropQuests:AddQuestToSlot(quest_slot)
				ACDI:SelectGroup(addonName, "quests", quest_slot)
			end,
		},
		quests = {
			name = L["Quests"],
			desc = L["QuestsTooltip"],
			type = "group",
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
			name = L["QuestDefaultSettings"],
			desc = L["QuestDefaultSettingsTooltip"],
			type = "group",
			order = 40,
			disabled = function() return not db.enabled end,
			args = {
				desc = {
					name = L["QuestDefaultSettingsDescription"],
					type = "description",
					order = 0,
				},
				general_title = {
					name = L["General"],
					type = "header",
					order = 10,
				},
				grouped = {
					name = L["Grouped"],
					desc = L["GroupedTooltip"],
					type = "toggle",
					order = 20,
					get = function(info)
						if db.appearance ~= nil and db.appearance.grouped ~= nil then
							return db.appearance.grouped
						end
						return true
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end

						db.appearance.grouped = v
						if v then
							attachFramesToContainer()
						else
							detachFramesFromContainer()
						end
					end,
				},
				group_title = {
					name = L["Group"],
					type = "header",
					order = 100,
					hidden = function(info) return db.appearance ~= nil and db.appearance.grouped ~= nil and not db.appearance.grouped end,
				},
				x_offset = {
					name = L["XOffset"],
					desc = L["XOffsetTooltip"],
					type = "range",
					softMin = 0,
					softMax = 1280,
					order = 110,
					step = 1,
					hidden = function(info) return db.appearance ~= nil and db.appearance.grouped ~= nil and not db.appearance.grouped end,
					get = function(info) return db.appearance and db.appearance.group and db.appearance.group.x_offset or questContainer:GetLeft() end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.group then
							db.appearance.group = {}
						end

						db.appearance.group.x_offset = v
						setQuestContainerPosition()
					end,
				},
				y_offset = {
					name = L["YOffset"],
					desc = L["YOffsetTooltip"],
					type = "range",
					softMin = 0,
					softMax = 720,
					order = 120,
					step = 1,
					hidden = function(info) return db.appearance ~= nil and db.appearance.grouped ~= nil and not db.appearance.grouped end,
					get = function(info) return db.appearance and db.appearance.group and db.appearance.group.y_offset or questContainer:GetBottom() end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.group then
							db.appearance.group = {}
						end

						db.appearance.group.y_offset = v
						setQuestContainerPosition()
					end,
				},
				separator = {
					name = L["Separator"],
					desc = L["SeparatorTooltip"],
					type = "range",
					softMin = 0,
					softMax = 100,
					order = 130,
					step = 1,
					hidden = function(info) return db.appearance ~= nil and db.appearance.grouped ~= nil and not db.appearance.grouped end,
					get = function(info) return db.appearance and db.appearance.group and db.appearance.group.separator or DEFAULT_QUEST_CONTAINER_SEPARATOR end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.group then
							db.appearance.group = {}
						end

						db.appearance.group.separator = v
						moveQuestsToContainer()
					end,
				},
				defaults_title = {
					name = L["Defaults"],
					type = "header",
					order = 200,
				},
				show_name = {
					name = L["ShowName"],
					desc = L["ShowNameTooltip"],
					width = "full",
					type = "toggle",
					order = 210,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_name ~= nil then
							return db.appearance.defaults.show_name
						end
						return true
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.show_name = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateFrameSize() end

						if db.appearance.grouped then
							setQuestContainerWidth()
						end
					end,
				},
				text_display = {
					name = L["TextDisplay"],
					desc = L["TextDisplayTooltip"],
					type = "select",
					order = 220,
					values = {
						["numeric"] = L["Numeric"],
						["countdown"] = L["Countdown"],
						["percentage"] = L["Percentage"],
					},
					get = function(info) return db.appearance and db.appearance.defaults and db.appearance.defaults.text_display or "numeric" end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.text_display = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateQuestProgress() end
					end,
				},
				show_value = {
					name = L["ShowValue"],
					desc = L["ShowValueTooltip"],
					width = 0.75,
					type = "toggle",
					order = 230,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_value ~= nil then
							return db.appearance.defaults.show_value
						end
						return true
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.show_value = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateFrameSize() end

						if db.appearance.grouped then
							setQuestContainerWidth()
						end
					end,
				},
				show_maximum = {
					name = L["ShowMax"],
					desc = L["ShowMaxTooltip"],
					width = 0.75,
					type = "toggle",
					order = 240,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_maximum ~= nil then
							return db.appearance.defaults.show_maximum
						end
						return true
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.show_maximum = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateQuestProgressFrame() end
					end,
				},
				hover_mode = {
					name = L["HoverMode"],
					desc = L["HoverModeTooltip"],
					width = 0.75,
					type = "toggle",
					order = 250,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil then
							return db.appearance.defaults.text_hover_mode
						end
						return false
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.text_hover_mode = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateQuestProgressFrame() end
					end,
				},
				show_icon = {
					name = L["ShowIcon"],
					desc = L["ShowIconTooltip"],
					width = "full",
					type = "toggle",
					order = 260,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil then
							return db.appearance.defaults.show_icon
						end
						return true
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.show_icon = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateFrameSize() end

						if db.appearance.grouped then
							setQuestContainerWidth()
						end
					end,
				},
				progress_width = {
					type = "range",
					name = L["ProgressWidth"],
					desc = L["ProgressWidthTooltip"],
					min = 0,
					softMax = 200,
					order = 270,
					step = 1,
					get = function(info) return db.appearance and db.appearance.defaults and db.appearance.defaults.progress_width or DEFAULT_PROGRESS_BAR_WIDTH end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.progress_width = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateFrameSize() end

						if db.appearance.grouped then
							setQuestContainerWidth()
						end
					end,
				},
				show_progress_bar = {
					name = L["ShowProgressBar"],
					desc = L["ShowProgressBarTooltip"],
					type = "toggle",
					order = 280,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_progress_bar ~= nil then
							return db.appearance.defaults.show_progress_bar
						end
						return true
					end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.show_progress_bar = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateFrameSize() end

						if db.appearance.grouped then
							setQuestContainerWidth()
						end
					end,
				},
				progress_bar_texture = {
					name = L["ProgressBarTexture"],
					desc = L["ProgressBarTextureTooltip"],
					type = "select",
					order = 290,
					dialogControl = "LSM30_Statusbar",
					values = WidgetLists.statusbar,
					get = function(info) return db.appearance and db.appearance.defaults and db.appearance.defaults.progress_bar_texture or DEFAULT_PROGRESS_BAR_TEXTURE end,
					set = function(info, v)
						if not db.appearance then
							db.appearance = {}
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.progress_bar_texture = v

						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateQuestProgressFrame() end
					end,
				},
				merge_name_progress = {
					name = L["MergeNameProgress"],
					desc = L["MergeNameProgressTooltip"],
					type = "toggle",
					order = 390,
					get = function(info, v)
						if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.merge_name_progress ~= nil then
							return db.appearance.defaults.merge_name_progress
						end
						return false
					end,
					set = function(info, v)
						if not db.appearance then
							-- Do something
						end
						if not db.appearance.defaults then
							db.appearance.defaults = {}
						end

						db.appearance.defaults.merge_name_progress = v
						for key, _ in pairs(db.questList) do DropQuests:GetFrameFromSlot(key):UpdateFrameSize() end

						if db.appearance.grouped then
							setQuestContainerWidth()
						end
					end,
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
				enabled = {
					name = L["EnableQuest"],
					desc = L["EnableQuestTooltip"],
					width = "half",
					type = "toggle",
					order = 10,
					get = function(info, v)
						if db.questList[info[2]].enabled ~= nil then
							return db.questList[info[2]].enabled
						else
							return true
						end
					end,
					set = function(info, v)
						db.questList[info[2]].enabled = v

						DropQuests:GetFrameFromSlot(info[2]):UpdateVisibility()

						if db.appearance and db.appearance.grouped then
							moveQuestsToContainer()
						end
					end,
				},
				del_quest = {
					name = L["DeleteQuest"],
					desc = L["DeleteQuestTooltip"],
					type = "execute",
					order = 20,
					confirm = function() return not IsShiftKeyDown() end,
					confirmText = L["DeleteQuestConfirmDialog"],
					func = function(info, v) DropQuests:RemoveQuestFromSlot(info[2]) end,
				},
				name = {
					name = L["QuestName"],
					desc = L["QuestNameTooltip"],
					width = "full",
					type = "input",
					order = 30,
					get = function(info, v)
						return DropQuests:GetQuestName(info[2]) or ""
					end,
					set = function(info, v)
						v = v:gsub("||", "|")
						db.questList[info[2]].name = v ~= "" and v or nil
						DropQuests:UpdateQuestOptionName(info[2])
						DropQuests:GetFrameFromSlot(info[2]):UpdateName()
					end,
				},
				action_item = {
					name = "",
					desc = L["QuestItemTooltip"],
					width = 0.25,
					type = "input",
					control = "ActionSlot",
					--disabled = function(info) return DropQuests:GetQuestType(info[2]) ~= "item" end,
					order = 40,
					get = function(info)
						local id = db.questList[info[2]].itemID or 0
						return DropQuests:GetQuestType(info[2])..":"..id
					end,
					set = function(info, v)
						if v == "" then
							DropQuests:SetQuestItem(info[2])
							return
						end

						local frame = DropQuests:GetFrameFromSlot(info[2])

						DropQuests:SetQuestItem(info[2], v)

						frame:UpdateVisibility()
						frame:UpdateItem()
					end,
				},
				item = {
					name = L["QuestItem"],
					desc = L["QuestItemTooltip"],
					type = "input",
					order = 45,
					get = function(info)
						if db.questList[info[2]].itemID ~= nil then
							if DropQuests:GetQuestType(info[2]) == "currency" then
								local currencyInfo = C_CurrencyInfo.GetBasicCurrencyInfo(db.questList[info[2]].itemID)
								if currencyInfo == nil then return tostring(db.questList[info[2]].itemID) end

								local _, _, _, hexColor = GetItemQualityColor(currencyInfo.quality)

								return currencyInfo and "|c" .. hexColor .. "|Hcurrency:" .. db.questList[info[2]].itemID .. ":::::::::::::::::|h[" .. currencyInfo.name .. "]|h|r"
							else
								local itemName = GetItemInfo(db.questList[info[2]].itemID)
								if itemName == nil then return tostring(db.questList[info[2]].itemID) end

								local _, _, _, hexColor = GetItemQualityColor(C_Item.GetItemQualityByID(db.questList[info[2]].itemID))

								return itemName and "|c" .. hexColor .. "|Hitem:" .. db.questList[info[2]].itemID .. ":::::::::::::::::|h[" .. itemName .. "]|h|r"
							end
						end
						return ""
					end,
					set = function(info, v)
						if v == "" then
							DropQuests:SetQuestItem(info[2])
							return
						end

						local inputID = tonumber(v)
						local frame = DropQuests:GetFrameFromSlot(info[2])

						if inputID == nil then
							if DropQuests:GetQuestType(info[2]) == "currency" then
								--local hasPreString, preString, linkString, postString = ExtractHyperlinkString(v)
								local linkType, linkOptions, _ = LinkUtil.ExtractLink(v)
								local linkID
								if linkOptions then
									linkID, amount = ExtractLinkData(linkOptions)
								else
									return
								end
								if linkType == "currency" then
									inputID = tonumber(linkID)
								end
							else
								inputID = GetItemInfoInstant(v)
							end

							if inputID == nil then
								return
							end
						end

						DropQuests:SetQuestItem(info[2], inputID)

						frame:UpdateVisibility()
						frame:UpdateItem()
					end,
				},
				quest_type = {
					name = L["QuestType"],
					desc = L["QuestTypeTooltip"],
					width = 0.75,
					type = "select",
					order = 50,
					values = {
						["item"] = L["QuestItem"],
						["currency"] = L["QuestCurrency"],
					},
					get = function(info) return DropQuests:GetQuestType(info[2]) end,
					set = function(info, v)
						db.questList[info[2]].quest_type = v
						local frame = DropQuests:GetFrameFromSlot(info[2])

						frame:UnregisterEvent("ITEM_PUSH")
						frame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
						if v == "currency" then
							frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
						else
							frame:RegisterEvent("ITEM_PUSH")
						end
						frame:UpdateQuestProgress()
					end,
				},
				goal = {
					name = L["QuestGoal"],
					desc = L["QuestGoalTooltip"],
					type = "input",
					order = 60,
					disabled = function(info) return db.questList[info[2]].use_currency_maximum ~= nil and db.questList[info[2]].use_currency_maximum end,
					validate = function(info, v)
						if tonumber(v) == nil then
							return "|cffff0000Error:|r Must be a number"
						end
						return true
					end,
					get = function(info)
						return db.questList[info[2]].goal and tostring(db.questList[info[2]].goal) or "0"
					end,
					set = function(info, v)
						db.questList[info[2]].goal = tonumber(v)
						DropQuests:GetFrameFromSlot(info[2]):UpdateQuestProgressFrame()
					end,
				},
				use_bank = {
					name = L["UseBank"],
					desc = L["UseBankTooltip"],
					type = "toggle",
					hidden = function(info) return DropQuests:GetQuestType(info[2]) ~= "item" end,
					order = 70,
					get = function(info)
						if db.questList[info[2]].use_bank ~= nil then
							return db.questList[info[2]].use_bank
						else
							return true
						end
					end,
					set = function(info, v)
						db.questList[info[2]].use_bank = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateQuestProgressFrame()
					end,
				},
				use_currency_maximum = {
					name = L["UseCurrencyMaximum"],
					desc = L["UseCurrencyMaximumTooltip"],
					type = "toggle",
					hidden = function(info) return DropQuests:GetQuestType(info[2]) ~= "currency" end,
					order = 80,
					get = function(info)
						if db.questList[info[2]].use_currency_maximum ~= nil then
							return db.questList[info[2]].use_currency_maximum
						else
							return false
						end
					end,
					set = function(info, v)
						db.questList[info[2]].use_currency_maximum = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateQuestProgressFrame()
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
				reset_appearance = {
					name = L["ResetAppearance"],
					desc = L["ResetAppearanceTooltip"],
					type = "execute",
					order = 10,
					disabled = function(info)
						return db.questList[info[2]].appearance == nil
					end,
					func = function(info, v)
						db.questList[info[2]].appearance = nil
						DropQuests:GetFrameFromSlot(info[2]):FullRefresh()
					end,
				},
				general_title = {
					name = L["General"],
					type = "header",
					order = 20,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
				},
				x_offset = {
					name = L["XOffset"],
					desc = L["XOffsetTooltip"],
					type = "range",
					softMin = 0,
					softMax = 1280,
					order = 30,
					step = 1,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info) return db.questList[info[2]].appearance and db.questList[info[2]].appearance.x or DropQuests:GetFrameFromSlot(info[2]):GetLeft() end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.x = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFramePosition()
					end,
				},
				y_offset = {
					name = L["YOffset"],
					desc = L["YOffsetTooltip"],
					type = "range",
					softMin = 0,
					softMax = 720,
					order = 40,
					step = 1,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info) return db.questList[info[2]].appearance and db.questList[info[2]].appearance.y or DropQuests:GetFrameFromSlot(info[2]):GetBottom() end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.y = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFramePosition()
					end,
				},
				progress_width = {
					name = L["ProgressWidth"],
					desc = L["ProgressWidthTooltip"],
					type = "range",
					min = 0,
					softMax = 200,
					order = 50,
					step = 1,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info) return db.questList[info[2]].appearance and db.questList[info[2]].appearance.progress_width or db.appearance and db.appearance.defaults and db.appearance.defaults.progress_width or DEFAULT_PROGRESS_BAR_WIDTH end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.progress_width = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFrameSize()
					end,
				},
				anchor = {
					name = L["Anchor"],
					desc = L["AnchorTooltip"],
					type = "select",
					order = 60,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					values = {
						["TOPLEFT"] = L["TopLeft"],
						["TOPRIGHT"] = L["TopRight"],
						["BOTTOMLEFT"] = L["BottomLeft"],
						["BOTTOMRIGHT"] = L["BottomRight"],
					},
					get = function(info) return db.questList[info[2]].appearance and db.questList[info[2]].appearance.anchor or "BOTTOMLEFT" end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.anchor = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFramePosition()
					end,
				},
				clamped = {
					name = L["Clamped"],
					desc = L["ClampedTooltip"],
					width = "half",
					type = "toggle",
					order = 70,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info, v)
						return db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.clamped_to_screen ~= nil and db.questList[info[2]].appearance.clamped_to_screen or true
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.clamped_to_screen = v
						DropQuests:GetFrameFromSlot(info[2]):SetClampedToScreen(v)
					end,
				},
				text_title = {
					name = L["Text"],
					type = "header",
					order = 100,
				},
				show_name = {
					name = L["ShowName"],
					desc = L["ShowNameTooltip"],
					width = 0.75,
					type = "toggle",
					order = 120,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.show_name ~= nil then
							return db.questList[info[2]].appearance.show_name
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_name ~= nil then
							return db.appearance.defaults.show_name
						end
						return true
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.show_name = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFrameSize()
					end,
				},
				text_display = {
					name = L["TextDisplay"],
					desc = L["TextDisplayTooltip"],
					type = "select",
					order = 110,
					values = {
						["default"] = L["Default"],
						["numeric"] = L["Numeric"],
						["countdown"] = L["Countdown"],
						["percentage"] = L["Percentage"],
					},
					get = function(info) return db.questList[info[2]].appearance and db.questList[info[2]].appearance.text_display or "default" end,
					set = function(info, v)
						local frame = DropQuests:GetFrameFromSlot(info[2])
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						if v == "default" and db.questList[info[2]].appearance.text_display ~= nil then
							db.questList[info[2]].appearance.text_display = nil
						else
							db.questList[info[2]].appearance.text_display = v
						end
						frame:UpdateItem()
					end,
				},
				show_value = {
					name = L["ShowValue"],
					desc = L["ShowValueTooltip"],
					width = 0.75,
					type = "toggle",
					order = 120,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.show_value ~= nil then
							return db.questList[info[2]].appearance.show_value
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_maximum ~= nil then
							 return db.appearance.defaults.show_value
						end
						return true
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.show_value = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFrameSize()
					end,
				},
				show_maximum = {
					name = L["ShowMax"],
					desc = L["ShowMaxTooltip"],
					width = 0.75,
					type = "toggle",
					order = 130,
					disabled = function(info)
						if db.questList[info[2]].appearance ~= nil then
							if db.questList[info[2]].appearance.show_value ~= nil and not db.questList[info[2]].appearance.show_value then
								return true
							end
							if db.questList[info[2]].appearance.text_display ~= nil then
								return db.questList[info[2]].appearance.text_display ~= "numeric"
							end
						end
						if db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.text_display ~= nil then
							return db.appearance.defaults.text_display ~= "numeric"
						end
						return false
					end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.show_maximum ~= nil then
							return db.questList[info[2]].appearance.show_maximum
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_maximum ~= nil then
							return db.appearance.defaults.show_maximum
						end
						return true
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.show_maximum = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateQuestProgressFrame()
					end,
				},
				show_progress_bar = {
					name = L["ShowProgressBar"],
					desc = L["ShowProgressBarTooltip"],
					width = 0.75,
					type = "toggle",
					order = 140,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.show_progress_bar ~= nil then
							return db.questList[info[2]].appearance.show_progress_bar
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_progress_bar ~= nil then
							 return db.appearance.defaults.show_progress_bar
						end
						return true
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.show_progress_bar = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFrameSize()
					end,
				},
				progress_bar_texture = {
					name = L["ProgressBarTexture"],
					desc = L["ProgressBarTextureTooltip"],
					type = "select",
					order = 150,
					dialogControl = "LSM30_Statusbar",
					values = WidgetLists.statusbar,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.progress_bar_texture ~= nil then
							return db.questList[info[2]].appearance.progress_bar_texture
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.progress_bar_texture ~= nil then
							 return db.appearance.defaults.progress_bar_texture
						end
						return DEFAULT_PROGRESS_BAR_TEXTURE
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.progress_bar_texture = v

						DropQuests:GetFrameFromSlot(info[2]):UpdateQuestProgressFrame()
					end,
				},
				merge_name_progress = {
					name = L["MergeNameProgress"],
					desc = L["MergeNameProgressTooltip"],
					type = "toggle",
					order = 160,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.merge_name_progress ~= nil then
							return db.questList[info[2]].appearance.merge_name_progress
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.merge_name_progress ~= nil then
							 return db.appearance.defaults.merge_name_progress
						end
						return false
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.merge_name_progress = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFrameSize()
					end,
				},
				hover_mode = {
					name = L["HoverMode"],
					desc = L["HoverModeTooltip"],
					width = 0.75,
					type = "toggle",
					order = 170,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					disabled = function(info)
						return db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.show_value ~= nil and not db.questList[info[2]].appearance.show_value or false end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.text_hover_mode ~= nil then
							return db.questList[info[2]].appearance.text_hover_mode
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.text_hover_mode ~= nil then
							return db.appearance.defaults.text_hover_mode
						end
						return false
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.text_hover_mode = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateQuestProgressFrame()
					end,
				},
				show_icon = {
					name = L["ShowIcon"],
					desc = L["ShowIconTooltip"],
					width = 0.75,
					type = "toggle",
					order = 180,
					hidden = function() return db.appearance == nil or db.appearance.grouped end,
					get = function(info, v)
						if db.questList[info[2]].appearance ~= nil and db.questList[info[2]].appearance.show_icon ~= nil then
							return db.questList[info[2]].appearance.show_icon
						elseif db.appearance ~= nil and db.appearance.defaults ~= nil and db.appearance.defaults.show_icon ~= nil then
							return db.appearance.defaults.show_icon
						end
						return true
					end,
					set = function(info, v)
						if not db.questList[info[2]].appearance then
							db.questList[info[2]].appearance = {}
						end

						db.questList[info[2]].appearance.show_icon = v
						DropQuests:GetFrameFromSlot(info[2]):UpdateFrameSize()
					end,
				},
				grouped_hint = {
					name = "|cFFFFFF00"..L["GroupedHint"].."|r",
					type = "description",
					order = 900,
					hidden = function() return db.appearance ~= nil and not db.appearance.grouped end,
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
					name = L["Continents"],
					type = "group",
					width = "half",
					order = 10,
					args = {
						auto_filter = {
							name = L["AutoFilterContinent"],
							desc = L["AutoFilterContinentTooltip"],
							width = "full",
							type = "toggle",
							order = 10,
							get = function(info)
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.auto_filter_continent ~= nil then
									return db.questList[info[2]].filter.auto_filter_continent
								end
								return false
							end,
							set = function(info, v)
								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								db.questList[info[2]].filter.auto_filter_continent = v
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
						continent_list = {
							name = L["Continents"],
							width = "full",
							type = "select",
							control = "MultiSelect",
							order = 30,
							values = function(info)
								local output = {}
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.continents ~= nil then
									for mapId, isFiltered in pairs(db.questList[info[2]].filter.continents) do
										if isFiltered then output[mapId] = MN:GetMapInfo(mapId).name end
									end
								end
								return output
							end,
							get = function(info)
								return questVars[info[2]].selected
							end,
							set = function(info, v)
								questVars[info[2]].selected = questVars[info[2]].selected == v and nil or v
							end,
						},
						continent_input = {
							name = L["Continent"],
							desc = L["FilterContinentInputTooltip"],
							type = "input",
							order = 40,
							get = function(info, v) return "" end,
							set = function(info, v)
								if v == "" then
									return
								end

								local matches = MN:GetMatchingMapsFromName(v, Enum.UIMapType.Continent,
																					  Enum.UIMapType.World,
																					  Enum.UIMapType.Cosmic)

								-- Do not assign a value if there are no matches
								if matches == nil then
									return
								end

								-- Assume the first match is the right one
								local zoneName = matches[1]
								local mapId = MapNameIDs[Enum.UIMapType.Continent][zoneName]

								DropQuests:AddContinentToFilterList(info[2], mapId)
							end,
						},
						add_continent = {
							name = L["FilterContinentAdd"],
							desc = L["FilterContinentAddTooltip"],
							width = "half",
							type = "execute",
							order = 50,
							disabled = function(info) -- Disabled if the current continent is already in the list
								return db.questList[info[2]].filter
										and db.questList[info[2]].filter.continents
										and db.questList[info[2]].filter.continents[tostring(MN:GetContinentFromMap(nil, true))]
							end,
							func = function(info, v)
								DropQuests:AddContinentToFilterList(info[2])
							end,
						},
						del_continent = {
							name = L["FilterContinentRemove"],
							desc = function(info) -- Displays the selected or current tooltip depending if a continent is selected
								return questVars[info[2]].selected
										and db.questList[info[2]].filter
										and db.questList[info[2]].filter.continents
										and db.questList[info[2]].filter.continents[tostring(questVars[info[2]].selected)]
										and L["FilterContinentRemoveSelectedTooltip"]
										or L["FilterContinentRemoveTooltip"]
							end,
							width = "half",
							type = "execute",
							order = 60,
							disabled = function(info) -- Disabled if the current continent is not in the list and there is no selected continent
								return (db.questList[info[2]].filter == nil
										or db.questList[info[2]].filter.continents == nil
										or db.questList[info[2]].filter.continents[tostring(MN:GetContinentFromMap(nil, true))] ~= true)
										and not (questVars[info[2]].selected
											and db.questList[info[2]].filter.continents
											and db.questList[info[2]].filter.continents[tostring(questVars[info[2]].selected)])
							end,
							func = function(info, v)
								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.continents == nil then
									db.questList[info[2]].filter.continents = {}
								end

								local targetContinent = (questVars[info[2]].selected and 
														db.questList[info[2]].filter and 
														db.questList[info[2]].filter.continents and 
														db.questList[info[2]].filter.continents[tostring(questVars[info[2]].selected)]) and 
														questVars[info[2]].selected or 
														MN:GetContinentFromMap(nil, true)

								if targetContinent then
									local frame = DropQuests:GetFrameFromSlot(info[2])
									questVars[info[2]].selected = nil
									db.questList[info[2]].filter.continents[tostring(targetContinent)] = nil
									frame:UpdateVisibility()
								end
							end,
						},
					},
				},
				filter_zone = {
					name = L["Zones"],
					type = "group",
					order = 20,
					args = {
						auto_filter = {
							name = L["AutoFilterZone"],
							desc = L["AutoFilterZoneTooltip"],
							width = "full",
							type = "toggle",
							order = 10,
							get = function(info)
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.auto_filter_zone ~= nil then
									return db.questList[info[2]].filter.auto_filter_zone
								end
								return false
							end,
							set = function(info, v)
								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								db.questList[info[2]].filter.auto_filter_zone = v
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
						zone_list = {
							name = L["Zones"],
							width = "full",
							type = "select",
							control = "MultiSelect",
							order = 30,
							values = function(info)
								local output = {}
								if db.questList[info[2]].filter ~= nil and db.questList[info[2]].filter.zones ~= nil then
									for mapId, isFiltered in pairs(db.questList[info[2]].filter.zones) do
										if isFiltered then output[mapId] = MN:GetMapInfo(mapId).name end
									end
								end
								return output
							end,
							get = function(info)
								return questVars[info[2]].selected
							end,
							set = function(info, v)
								questVars[info[2]].selected = questVars[info[2]].selected == v and nil or v
							end,
						},
						zone_input = {
							name = L["Zone"],
							desc = L["FilterZoneInputTooltip"],
							type = "input",
							order = 40,
							get = function(info, v) return "" end,
							set = function(info, v)
								if v == "" then
									return
								end

								local matches = MN:GetMatchingMapsFromName(v, Enum.UIMapType.Zone,
																					  Enum.UIMapType.Dungeon,
																					  Enum.UIMapType.Micro,
																					  Enum.UIMapType.Orphan)

								-- Do not assign a value if there are no matches
								if matches == nil then
									return
								end

								-- Assume the first match is the right one
								local mapId
								for i, _ in pairs(matches) do
									mapId = i
									break
								end

								DropQuests:AddZoneToFilterList(info[2], mapId)
							end,
						},
						add_zone = {
							name = L["FilterZoneAdd"],
							desc = L["FilterZoneAddTooltip"],
							width = "half",
							type = "execute",
							order = 50,
							disabled = function(info) -- Disabled if the current zone is already in the list
								return db.questList[info[2]].filter
										and db.questList[info[2]].filter.zones
										and db.questList[info[2]].filter.zones[tostring(MN:GetZoneFromMap(nil, true))]
							end,
							func = function(info)
								DropQuests:AddZoneToFilterList(info[2])
							end,
						},
						del_zone = {
							name = L["FilterZoneRemove"],
							desc = function(info) -- Displays the "selected" or "current" tooltip depending if a zone is selected
								return questVars[info[2]].selected
										and db.questList[info[2]].filter
										and db.questList[info[2]].filter.zones
										and db.questList[info[2]].filter.zones[tostring(questVars[info[2]].selected)]
										and L["FilterZoneRemoveSelectedTooltip"]
										or L["FilterZoneRemoveTooltip"] end,
							width = "half",
							type = "execute",
							order = 60,
							disabled = function(info) -- Disabled if the current zone is not in the list and there is no selected zone
								return (db.questList[info[2]].filter == nil
										or db.questList[info[2]].filter.zones == nil
										or db.questList[info[2]].filter.zones[tostring(MN:GetZoneFromMap(nil, true))] ~= true)
										and not (questVars[info[2]].selected
											and db.questList[info[2]].filter
											and db.questList[info[2]].filter.zones
											and db.questList[info[2]].filter.zones[tostring(questVars[info[2]].selected)])
							end,
							func = function(info)
								if db.questList[info[2]].filter == nil then
									db.questList[info[2]].filter = {}
								end
								if db.questList[info[2]].filter.zones == nil then
									db.questList[info[2]].filter.zones = {}
								end

								local targetZone = (questVars[info[2]].selected
													and db.questList[info[2]].filter
													and db.questList[info[2]].filter.zones
													and db.questList[info[2]].filter.zones[tostring(questVars[info[2]].selected)])
													and questVars[info[2]].selected
													or MN:GetZoneFromMap(nil, true)

								if targetZone then
									local frame = DropQuests:GetFrameFromSlot(info[2])
									questVars[info[2]].selected = nil
									db.questList[info[2]].filter.zones[tostring(targetZone)] = nil
									frame:UpdateVisibility()
								end
							end,
						},
					},
				},
			},
		},
	},
}

------------------
-- Addon Functions
------------------

function DropQuests:OnInitialize()
	-- Set up our database
	self.db = ACDB:New("DropQuestsDB", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	db = self.db.profile
	local migrate_from = 0
	if db.version == nil then
		db.version = DB_VERSION
	elseif db.version < DB_VERSION then
		migrate_from = db.version
		DropQuests:MigrateDB(migrate_from)
	end

	questContainer = DropQuests:CreateQuestContainer(0)

	DropQuests:RefreshOptions()

	if db.appearance == nil or db.appearance.grouped then
		attachFramesToContainer()
	end

	self.optionsFrame = {}
	self.optionsFrame.general = ACDI:AddToBlizOptions(addonName, addonName, nil)
	self.optionsFrame.profiles = ACDI:AddToBlizOptions(addonName, options.args.profiles.name, addonName, "profiles")

	ACR:RegisterOptionsTable(addonName, options)
	self:RegisterChatCommand("dropquests", function()
		ACDI:Open(addonName)
	end)

	-- Show/Hide quests when switching between zones for filtered quests
	HBD.RegisterCallback(self, "PlayerZoneChanged", "OnZoneChanged")

	eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "DISPLAY_SIZE_CHANGED" then
			screenWidth = GetScreenWidth()
			screenHeight = GetScreenHeight()
			for key, value in pairs(db.questList) do
				DropQuests:UpdateQuestSlotOptions(key)
			end
			ACR:RegisterOptionsTable(addonName, options)
			ACR:NotifyChange(addonName)
		elseif event == "SPELLS_CHANGED" then
			DropQuests:RefreshQuestFrameVisibility()
			eventFrame:UnregisterEvent(event)
		end
	end)

	eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

	-- If there's no map, register an event that will try again on login
	if not DropQuests:RefreshQuestFrameVisibility() then
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
	DropQuests:RefreshOptions()

	if db.appearance == nil or db.appearance.grouped then
		attachFramesToContainer()
	end

	ACR:RegisterOptionsTable(addonName, options)
	ACR:NotifyChange(addonName)

	DropQuests:RefreshQuestFrameVisibility(MN:GetZoneFromMap(nil, true))

	if db.appearance and db.appearance.grouped then
		moveQuestsToContainer()
	end
end

function DropQuests:OnZoneChanged(event, currentPlayerUiMapID, currentPlayerUiMapType)
	-- Check each quest to show/hide depending on their filters
	DropQuests:RefreshQuestFrameVisibility(currentPlayerUiMapID)

	if db.appearance and db.appearance.grouped then
		moveQuestsToContainer()
	end
end
