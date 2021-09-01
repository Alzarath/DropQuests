-- DropQuests
-- enUS and enGB Localization file

local L = LibStub("AceLocale-3.0"):NewLocale("DropQuests", "enUS", true)

L["DropQuests"] = true

L["QuestDefaultSettings"] = "Defaults"
L["QuestDefaultSettingsTooltip"] = "Settings affecting all quests"
L["QuestDefaultSettingsDescription"] = "These settings control the default look and feel of DropQuests"

L["EnableDropQuests"] = "Enable DropQuests"
L["EnableDropQuestsTooltip"] = "Enable or disable DropQuests"

L["Quests"] = true
L["QuestsTooltip"] = "List of items to track"
L["QuestsDescription"] = "These settings allow you to create new quests."

L["Quest"] = true
L["QuestOptionsDescription"] = "These settings allow you to modify a quest."

L["DeleteQuest"] = "Delete"
L["DeleteQuestTooltip"] = "Deletes the quest entirely. Can not be undone."
L["DeleteQuestConfirmDialog"] = "This will delete the quest. Are you sure?"

L["QuestAdd"] = "New Quest"
L["QuestAddTooltip"] = "Add a new quest"

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

L["ShowProgressBar"] = "Show Progress Bar"
L["ShowProgressBarTooltip"] = "Displays the progress bar"

L["HoverMode"] = "Hover Mode"
L["HoverModeTooltip"] = "Displays item text only while the progress bar is hovered over"

L["ShowName"] = "Show Name"
L["ShowNameTooltip"] = "Displays the item name"

L["MergeNameProgress"] = "Merge Name/Progress"
L["MergeNameProgressTooltip"] = "Display the name on the same line as the progress bar"

L["ProgressBarTexture"] = "Progress Bar Texture"
L["ProgressBarTextureTooltip"] = "Change the texture of the progress bar"

L["UseBank"] = "Use Bank"
L["UseBankTooltip"] = "Include items from the character's bank and reagent bank in the item progress"

L["UseCurrencyMaximum"] = "Use Max Currency"
L["UseCurrencyMaximumTooltip"] = "Use the Currency's maximum amount as the goal"

L["Filters"] = true
L["FiltersTooltip"] = "Conditional display settings"
L["FiltersDescription"] = "Conditionally enable/disable quests based on certain criteria."

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

L["Group"] = true
L["Grouped"] = true
L["GroupedTooltip"] = "Whether quests are grouped. Grouped quests all share the same appearance and appear as a list."
L["GroupedHint"] = "Appearance options limited while in Grouped mode."

L["QuestAppearanceSettings"] = "Appearance"
L["QuestAppearanceSettingsTooltip"] = "Settings affecting the quest frame's visuals"
L["QuestAppearanceSettingsDescription"] = "These settings control the look and feel of the quest frame."

L["General"] = true
L["Defaults"] = true
L["Frame"] = true
L["Text"] = true

L["Default"] = true
L["Numeric"] = true
L["Countdown"] = true
L["Percentage"] = true

L["ProgressWidth"] = "Width"
L["ProgressWidthTooltip"] = "The width of the progress bar in pixels.\n\n|cFFFFFF000|r hides the bar entirely and displays the quantity on the icon."

L["ResetAppearance"] = "Reset To Defaults"
L["ResetAppearanceTooltip"] = "Resets appearance values to their defaults"

L["TextDisplay"] = "Text Format"
L["TextDisplayTooltip"] = "Change how the quantity text appears"

L["QuestType"] = "Type"
L["QuestTypeTooltip"] = "Change the type of item to track"

L["XOffset"] = "X Offset"
L["XOffsetTooltip"] = "Distance from the horizontal edge of the screen"

L["YOffset"] = "Y Offset"
L["YOffsetTooltip"] = "Distance from the vertical edge of the screen"

L["Separator"] = true
L["SeparatorTooltip"] = "How vertically far apart quests are from eachother in the list"

L["ShowIcon"] = "Show Icon"
L["ShowIconTooltip"] = "Toggle the visibility of the quest icon"

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
