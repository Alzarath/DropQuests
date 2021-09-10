--[[----------------------------------
--  MultiSelect widget for AceGUI-3.0
--  Written by Shirokuma
--  Edited by Alzarath
--]]----------------------------------


--[[-----------------
-- AceGUI
--]]-----------------
local AceGUI = LibStub("AceGUI-3.0")

--[[-----------------
-- Lua APIs
--]]-----------------
local format, pairs, tostring = string.format, pairs, tostring

--[[-----------------
-- WoW APIs
--]]-----------------
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------
-- Frame Elements
--]]-----------------
local FrameBackdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}


--[[-----------------
-- Widget Info
--]]-----------------
local widgetType = "MultiSelect"
local widgetVersion = 1


--[[-----------------
-- Event Code
--]]-----------------
local function Label_OnEnter(label)
	local self = label.obj
	local value = label
	self:Fire("OnLabelEnter", value)
end

local function Label_OnLeave(label)
	local self = label.obj
	local value = label
	self:Fire("OnLabelEnter", value)
end

local function Label_OnClick(label)
	local self = label.obj
	local value = label
	self:Fire("OnLabelClick", value)
	AceGUI:ClearFocus()
end

local function GetItemCount(list)
	local count = 0
	for _ in pairs(list) do count = count + 1 end
	return count
end


--[[-----------------
-- MultiSelect Code
--]]-----------------
do
	local function OnAcquire(self)  -- set up the default size
		self:SetWidth(200)
		self:SetHeight(140)
	end
	
	local function SetWidth(self, w)  -- override the SetWidth function to include the labelframe
		self.frame:SetWidth(w)
		self.labelframe:SetWidth(w-33)
	end	
	
	local function SetLabel(self, text)  -- sets the multiselect label text
		self.label:SetText(text)
	end
	
	local function SetMultiSelect(self, value)  -- set if multiple values can be selected simultaneously
		self.multiselect = value
	end
	
	local function AddItem(self, str, id)  -- add an item (create a new item label object)
		local label = CreateFrame("Button", nil, self.labelframe)
		label.selected = false
		label.obj = self
		label.id = id
		label:SetHeight(18)
		label:SetPoint("TOPLEFT", self.labelframe, "TOPLEFT", 0, -(GetItemCount(self.labels) * 18))
		label:SetPoint("TOPRIGHT", self.labelframe, "TOPRIGHT", 0, -(GetItemCount(self.labels) * 18))
		self.labels[id] = label
		self.labelframe:SetHeight(GetItemCount(self.labels) * 18)
		
		local text = label:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		text:SetJustifyH("LEFT")
		text:SetPoint("TOPLEFT",label,"TOPLEFT",5,0)
		text:SetPoint("BOTTOMRIGHT",label,"BOTTOMRIGHT",-5,0)
		text:SetText(str)
		label.text = text
		
		local highlight = label:CreateTexture(nil, "OVERLAY")
		highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		highlight:SetBlendMode("ADD")
		highlight:SetHeight(14)
		highlight:ClearAllPoints()
		highlight:SetPoint("RIGHT",label,"RIGHT",0,0)
		highlight:SetPoint("LEFT",label,"LEFT",0,0)
		highlight:Hide()
		label.highlight = highlight
		
		label:SetScript("OnEnter", function(this)
			if not this.selected then
				this.highlight:SetDesaturated(true)
			end
			this.highlight:Show()
			Label_OnEnter(this)
		end)
		label:SetScript("OnLeave", function(this)
			this.highlight:SetDesaturated(false)
			if not this.selected then
				this.highlight:Hide()
			end
		end)
		label:SetScript("OnClick", function(this)
			self:Fire("OnValueChanged", this.id, this.selected, true)
		end)
	end
	
	local function GetKeyFromText(self, text)  -- find an object based on the text parameter
		for key, value in pairs(self.labels) do
			if value.text:GetText() == text then
				return key
			end
		end
		return nil
	end
	
	local function GetItem(self, key)  -- find an object based on the key parameter
		return self.labels[key] or nil
	end
	
	local function GetText(self, key)  -- get the text of a label object
		return self:GetItem(key).text:GetText() or nil
	end
	
	local function SetText(self, key, text)  -- set the text of a label object
		self:GetItem(key).text:SetText(text)
	end

	local function IsSelected(self, key)  -- return if the label object associated with a key is currently selected
		return self.labels[key].selected
	end
	
	local function GetSelected(self)  -- return a table of the currently selected label objects
		local selectedList = {}
		for _, item in pairs(self.labels) do
			if item.selected then
				table.insert(selectedList, item)
			end
		end
		return selectedList
	end
		
	local function SetItemList(self, list)  -- create new labels from a list of strings
		for _,item in pairs(self.labels) do
			item:Hide()
			item:ClearAllPoints()
		end
		
		self.labels = {}
		
		if list then
			for id, item in pairs(list) do
				self:AddItem(item, id)
			end
		end
	end

	local function RemoveItem(self, key)  -- delete an item
		local function RedrawFrame()
			for index,value in pairs(self.labels) do
				value:SetPoint("TOPLEFT", self.labelframe, "TOPLEFT", 0, (-(index-1) * 18))
				value:SetPoint("TOPRIGHT", self.labelframe, "TOPRIGHT", 0,(-(index-1) * 18))
			end
		end

		local item = self:GetItem(key)
		for index, value in pairs(self.labels) do
			if value == item then
				table.remove(self.labels, index)
				item:Hide()
				item:ClearAllPoints()
				RedrawFrame()
			end
		end
	end
	
	local function SetSelected(self, key, value)
		if key == nil then return nil end
		local item = self.labels[key]
		if value then
			if not self.multiselect then  -- test
				for _, value in pairs(self.labels) do
					value.selected = false
					value.highlight:Hide()
				end
			end
			self.labels[key].selected = true
			self.labels[key].highlight:Show()
		else
			self.labels[key].selected = false
			self.labels[key].highlight:Hide()
		end
	end

	local function SetValue(self, value)
		self:SetSelected(value, true)
	end

	local function GetValue(self)
		return self:GetSelected()[1]
	end
	
	local function Constructor()  -- widget constructor
		local frame = CreateFrame("Frame", nil, UIParent)
		local backdrop = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
		local self = {}
		local labels = {}
		
		self.type = widgetType
		self.frame = frame
		self.backdrop = backdrop
		self.labels = {}
		self.multiselect = false
		frame.obj = self
		
		local label = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		label:SetJustifyH("LEFT")
		label:SetPoint("TOPLEFT", 5, 0)
		label:SetPoint("TOPRIGHT", -5, 0)
		label:SetHeight(14)
		label:SetText("MultiSelect")
		self.label = label
		
		backdrop:SetBackdrop(FrameBackdrop)
		backdrop:SetBackdropColor(0, 0, 0)
		backdrop:SetBackdropBorderColor(0.4, 0.4, 0.4)
		backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -14)
		backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 0)
		
		local scrollframe = CreateFrame("ScrollFrame", format("%s@%s@%s", widgetType, "ScrollFrame", tostring(self)), frame, "UIPanelScrollFrameTemplate")
		scrollframe:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 5, -6)
		scrollframe:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -28, 6)
		scrollframe.obj = self
		self.scrollframe = scrollframe
		
		local labelframe = CreateFrame("Frame", nil, scrollframe)
		labelframe:SetAllPoints()
		labelframe.obj = self
		scrollframe:SetScrollChild(labelframe)
		self.labelframe = labelframe

		-- method listing
		self.OnAcquire = OnAcquire
		self.SetLabel = SetLabel
		self.AddItem = AddItem
		self.SetWidth  = SetWidth
		self.SetMultiSelect = SetMultiSelect
		self.SetItemList = SetItemList
		self.GetItem = GetItem
		self.GetKeyFromText = GetKeyFromText
		self.RemoveItem = RemoveItem
		self.GetText = GetText
		self.SetText = SetText
		self.SetList = SetItemList
		self.IsSelected = IsSelected
		self.GetSelected = GetSelected
		self.SetSelected = SetSelected
		self.SetValue = SetValue
		self.GetValue = GetValue
		
		AceGUI:RegisterAsWidget(self)
		return self
	end
	AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)
end