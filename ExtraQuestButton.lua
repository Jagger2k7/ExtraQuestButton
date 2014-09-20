if(select(4, GetBuildInfo()) < 6e4) then
	return
end

local Button = CreateFrame('Button', (...), UIParent, 'SecureActionButtonTemplate, SecureHandlerStateTemplate, SecureHandlerAttributeTemplate')
RegisterStateDriver(Button, 'visible', '[extrabar] hide; show')
Button:SetAttribute('_onattributechanged', [[
	if(name == 'item') then
		if(value and not self:IsShown() and not HasExtraActionBar()) then
			self:Show()
		elseif(not value) then
			self:Hide()
			self:ClearBindings()
		end
	elseif(name == 'state-visible') then
		if(value == 'show') then
			self:CallMethod('Update')
		else
			self:Hide()
			self:ClearBindings()
		end
	end

	if(self:IsShown() and (name == 'item' or name == 'binding')) then
		self:ClearBindings()

		local key = GetBindingKey('EXTRAACTIONBUTTON1')
		if(key) then
			self:SetBindingClick(1, key, self, 'LeftButton')
		end
	end
]])

Button:RegisterEvent('PLAYER_LOGIN')
Button:SetScript('OnEvent', function(self, event)
	if(event == 'BAG_UPDATE_COOLDOWN') then
		if(self:IsShown()) then
			local start, duration, enable = GetItemCooldown(self.itemID)
			if(duration > 0) then
				self.Cooldown:SetCooldown(start, duration)
				self.Cooldown:Show()
			else
				self.Cooldown:Hide()
			end
		end
	elseif(event == 'PLAYER_REGEN_ENABLED') then
		self:SetAttribute('item', self.attribute)
		self:UnregisterEvent(event)
	elseif(event == 'UPDATE_BINDINGS') then
		if(self:IsShown()) then
			self:SetItem()
			self:SetAttribute('binding', GetTime())
		end
	elseif(event == 'PLAYER_LOGIN') then
		self:SetPoint('CENTER', ExtraActionButton1)
		self:SetSize(ExtraActionButton1:GetSize())
		self:SetScale(ExtraActionButton1:GetScale())
		self:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
		self:SetPushedTexture([[Interface\Buttons\CheckButtonHilight]])
		self:GetPushedTexture():SetBlendMode('ADD')
		self:SetScript('OnLeave', GameTooltip_Hide)
		self:SetAttribute('type', 'item')
		self.updateTimer = 0
		self.rangeTimer = 0
		self:Hide()

		local Icon = self:CreateTexture('$parentIcon', 'BACKGROUND')
		Icon:SetAllPoints()
		self.Icon = Icon

		local HotKey = self:CreateFontString('$parentHotKey', nil, 'NumberFontNormal')
		HotKey:SetPoint('BOTTOMRIGHT', -5, 5)
		self.HotKey = HotKey

		local Cooldown = CreateFrame('Cooldown', '$parentCooldown', self, 'CooldownFrameTemplate')
		Cooldown:ClearAllPoints()
		Cooldown:SetPoint('TOPRIGHT', -2, -3)
		Cooldown:SetPoint('BOTTOMLEFT', 2, 1)
		Cooldown:Hide()
		self.Cooldown = Cooldown

		local Artwork = self:CreateTexture('$parentArtwork', 'OVERLAY')
		Artwork:SetPoint('CENTER', -2, 0)
		Artwork:SetSize(256, 128)
		Artwork:SetTexture([[Interface\ExtraButton\Default]])
		self.Artwork = Artwork

		self:RegisterEvent('UPDATE_BINDINGS')
		self:RegisterEvent('UPDATE_EXTRA_ACTIONBAR')
		self:RegisterEvent('BAG_UPDATE_COOLDOWN')
		self:RegisterEvent('BAG_UPDATE_DELAYED')
		self:RegisterEvent('WORLD_MAP_UPDATE')
		self:RegisterEvent('QUEST_LOG_UPDATE')
		self:RegisterEvent('QUEST_POI_UPDATE')
	else
		self:Update()
	end
end)

Button:SetScript('OnEnter', function(self)
	GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	GameTooltip:SetHyperlink(self.itemLink)
end)

Button:SetScript('OnUpdate', function(self, elapsed)
	if(self.rangeTimer > TOOLTIP_UPDATE_TIME) then
		local HotKey = self.HotKey
		local inRange = IsItemInRange(self.itemLink, 'target')
		if(HotKey:GetText() == RANGE_INDICATOR) then
			if(inRange == false) then
				HotKey:SetTextColor(1, 0.1, 0.1)
				HotKey:Show()
			elseif(inRange) then
				HotKey:SetTextColor(1, 1, 1)
				HotKey:Show()
			else
				HotKey:Hide()
			end
		else
			if(inRange == false) then
				HotKey:SetTextColor(1, 0.1, 0.1)
			else
				HotKey:SetTextColor(1, 1, 1)
			end
		end

		self.rangeTimer = 0
	else
		self.rangeTimer = self.rangeTimer + elapsed
	end

	if(self.updateTimer > 5) then
		self:Update()
		self.updateTimer = 0
	else
		self.updateTimer = self.updateTimer + elapsed
	end
end)

function Button:SetItem(itemLink, texture)
	if(itemLink) then
		if(itemLink == self.itemLink and self:IsShown()) then
			return
		end

		self.Icon:SetTexture(texture)
		self.itemID, self.itemName = string.match(itemLink, '|Hitem:(.-):.-|h%[(.+)%]|h')
		self.itemLink = itemLink
	end

	local HotKey = self.HotKey
	local key = GetBindingKey('EXTRAACTIONBUTTON1')
	if(key) then
		HotKey:SetText(GetBindingText(key, 1))
		HotKey:Show()
	elseif(ItemHasRange(self.itemLink)) then
		HotKey:SetText(RANGE_INDICATOR)
		HotKey:Show()
	else
		HotKey:Hide()
	end

	if(InCombatLockdown()) then
		self.attribute = self.itemName
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		self:SetAttribute('item', self.itemName)
	end
end

function Button:RemoveItem()
	if(InCombatLockdown()) then
		self.attribute = nil
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		self:SetAttribute('item', nil)
	end
end

function Button:Update()
	local shortestDistance = 62500 -- 250 yards²
	local closestQuestLink, closestQuestTexture

	for index = 1, GetNumQuestWatches() do
		local questID, _, questIndex, _, _, isComplete = GetQuestWatchInfo(index)
		if(questID and QuestHasPOIInfo(questID)) then
			local link, texture, _, showCompleted = GetQuestLogSpecialItemInfo(questIndex)
			if(link and (not isComplete or (isComplete and showCompleted))) then
				local distanceSq, onContinent = GetDistanceSqToQuest(questIndex)
				if(onContinent and distanceSq < shortestDistance) then
					shortestDistance = distanceSq
					closestQuestLink = link
					closestQuestTexture = texture
				end
			end
		end
	end

	if(closestQuestLink and not HasExtraActionBar()) then
		self:SetItem(closestQuestLink, closestQuestTexture)
	elseif(self:IsShown()) then
		self:RemoveItem()
	end
end
