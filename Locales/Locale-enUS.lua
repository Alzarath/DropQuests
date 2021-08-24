-- DropQuests
-- enUS and enGB Localization file

local L = LibStub("AceLocale-3.0"):NewLocale("DropQuests", "enUS", true)

L["DropQuests"] = true

L["EnableDropQuests"] = "Enable DropQuests"
L["EnableDropQuestsTooltip"] = "Enable or disable DropQuests"

L["GeneralSettings"] = "General Settings"
L["GeneralSettingsTooltip"] = "Settings that affect every database"
L["GeneralSettingsDescription"] = "These settings control the look and feel of DropQuests globally."

L["Quests"] = true
L["QuestsTooltip"] = "List of items to track"
L["QuestsDescription"] = "These settings allow you to create new quests."

L["Quest"] = true

L["DeleteQuest"] = "Delete"
L["DeleteQuestTooltip"] = "Deletes the quest entirely. Can not be undone."
L["DeleteQuestConfirmDialog"] = "This will delete the quest. Are you sure?"

L["QuestList"] = "Quest List"
L["QuestOptions"] = "Quest Options"
L["QuestOptionsDescription"] = "These settings allow you to modify a quest."

L["QuestAddTooltip"] = "Add Quest"
L["QuestRemoveTooltip"] = "Remove Quest"

L["QuestInfo"] = "Quest Info"

L["QuestName"] = "Name"
L["QuestNameTooltip"] = "Display name of the quest"

L["EnableQuest"] = "Enable"
L["EnableQuestTooltip"] = "Enable or disable the quest"

L["QuestItem"] = "Item"
L["QuestItemTooltip"] = "Tracked item"

L["QuestCurrency"] = "Currency"
L["QuestCurrencyTooltip"] = "Tracked currency"

L["QuestGoal"] = "Goal"
L["QuestGoalTooltip"] = "The amount of the item desired by the player"

L["ShowValue"] = "Show Value"
L["ShowValueTooltip"] = "Displays the current item quantity text"

L["ShowMax"] = "Show Max"
L["ShowMaxTooltip"] = "Displays the item goal text"

L["HoverMode"] = "Hover Mode"
L["HoverModeTooltip"] = "Displays item text only while the progress bar is hovered over"

L["ShowName"] = "Show Name"
L["ShowNameTooltip"] = "Displays the item name"

L["UseBank"] = "Use Bank"
L["UseBankTooltip"] = "Include items from the character's bank and reagent bank in the item progress"

L["Filters"] = true
L["FiltersTooltip"] = "Conditional display settings"
L["FiltersDescription"] = "Allows you to conditionally disable quests based on certain criteria."

L["AutoFilterZone"] = "Auto Filter"
L["AutoFilterZoneTooltip"] = "Automatically add the current zone to the quest's filter list when its item is picked up"

L["AutoFilterContinent"] = "Auto Filter"
L["AutoFilterContinentTooltip"] = "Automatically add the current continent to the quest's filter list when its item is picked up"

L["FilterContinent"] = "Continents"
L["FilterZone"] = "Zones"

L["FilterContinentAdd"] = "Add"
L["FilterContinentAddTooltip"] = "Add current continent to the filter list"
L["FilterContinentRemove"] = "Remove"
L["FilterContinentRemoveTooltip"] = "Remove current continent from the filter list"

L["FilterZoneAdd"] = "Add"
L["FilterZoneAddTooltip"] = "Add current zone to the filter list"
L["FilterZoneRemove"] = "Remove"
L["FilterZoneRemoveTooltip"] = "Remove current zone from the filter list"

L["FilterType"] = "Filter Type"
L["FilterTypeTooltip"] = "Determines what effect the filters have on the visibility of the quest.\n\nWhitelist: Quest is only visible while the conditions are met.\nBlacklist: Quest is not visible while the conditions are met."

L["Whitelist"] = true
L["Blacklist"] = true

L["AppearanceSettings"] = "Appearance"
L["AppearanceSettingsTooltip"] = "Settings affecting all quests' visuals"
L["AppearanceSettingsDescription"] = "These settings control the look and feel of DropQuests globally."

L["QuestAppearanceSettings"] = "Appearance"
L["QuestAppearanceSettingsTooltip"] = "Settings affecting the quest frame's visuals"
L["QuestAppearanceSettingsDescription"] = "These settings control the look and feel of the quest frame."

L["General"] = true
L["Frame"] = true
L["Text"] = true

L["Default"] = true
L["Numeric"] = true
L["Countdown"] = true
L["Percentage"] = true

L["ProgressWidth"] = "Width"
L["ProgressWidthTooltip"] = "The width of the progress bar in pixels.\n\n|cFFFFFF000|r hides the bar entirely and displays the quantity on the icon."

L["ResetProgressWidth"] = "Clear"
L["ResetProgressWidthTooltip"] = "Resets width to the default value"

L["DisplayType"] = "Display"
L["DisplayTypeTooltip"] = "Change how the quantity text appears"

L["XOffset"] = "X Offset"
L["XOffsetTooltip"] = "Distance from the horizontal edge of the screen"

L["YOffset"] = "Y Offset"
L["YOffsetTooltip"] = "Distance from the vertical edge of the screen"

L["Anchor"] = true
L["AnchorTooltip"] = "Corner that the frame is offset from"

L["TopLeft"] = "Top Left"
L["TopRight"] = "Top Right"
L["BottomLeft"] = "Bottom Left"
L["BottomRight"] = "Bottom Right"

L["Clamped"] = true
L["ClampedTooltip"] = "Clamps the frame to the screen"

L["Profiles"] = true

L["MoveHint"] = "|cFF00FF00Hint: |cffeda55fCtrl+Shift+LeftDrag|cFF00FF00 to move the pane"

-- vim: ts=4 noexpandtab
