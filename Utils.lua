local addonName, ns = ...
local itemData = ns.itemData

local HBD = LibStub('HereBeDragons-2.0')
local sqrt = math.sqrt

local function GetDistanceSqToPoint(mapID, x, y)
	local playerMapID = ns:GetCurrentMapID()
	local position = C_Map.GetPlayerMapPosition(playerMapID, 'player')
	if not position then
		return
	end

	local playerX, playerY = position:GetXY()
	return (HBD:GetZoneDistance(playerMapID, playerX, playerY, mapID, x, y))
end

local function GetQuestDistanceWithItem(questID)
	local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
	if not questLogIndex then
		return
	end

	local itemLink, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex)
	if not itemLink then
		local fallbackItemID = itemData.questItems[questID]
		if fallbackItemID then
			itemLink = ns:GenerateItemLinkFromID(fallbackItemID)
		end
	end

	if not itemLink then
		return
	end

	local itemID = ns:GetItemID(itemLink)
	if C_QuestLog.IsComplete(questID) then
		if not itemData.completeItems[itemID] then
			return
		end

		local noCompleteItem = itemData.noCompleteItems[itemID]
		if noCompleteItem then
			if type(noCompleteItem) == 'number' then
				itemLink = ns:GenerateItemLinkFromID(noCompleteItem)
				itemID = noCompleteItem
			else
				return
			end
		end
	end

	if GetItemCount(itemLink) == 0 then
		-- no point showing items we don't have
		return
	end

	local maxDistanceYd = ns.db.profile.distanceYd
	local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
	 -- the square root of distanceSq is in yards, much easier to work with
	local distanceYd = distanceSq and sqrt(distanceSq)
	if distanceYd and distanceYd <= maxDistanceYd then
		return distanceYd, itemLink
	end

	local accurateQuestAreaData = itemData.accurateQuestAreas[questID]
	if accurateQuestAreaData then
		local distanceSq = GetDistanceSqToPoint(accurateQuestAreaData[1], accurateQuestAreaData[2], accurateQuestAreaData[3])
		if distanceSq then
			return sqrt(distanceSq), itemLink
		end
	end

	local questMapID = itemData.inaccurateQuestAreas[questID]
	if questMapID then
		if type(questMapID) == 'boolean' then
			return maxDistanceYd - 1, itemLink
		elseif type(questMapID) == 'number' then
			if questMapID == ns:GetCurrentMapID() then
				return maxDistanceYd - 2, itemLink
			end
		elseif type(questMapID) == 'table' then
			local currentMapID = ns:GetCurrentMapID()
			for _, mapID in next, questMapID do
				if mapID == currentMapID then
					return maxDistanceYd - 2, itemLink
				end
			end
		end
	end
end

-- adaptation of QuestSuperTracking_ChooseClosestQuest for quests with items
function ns:GetClosestQuestItem()
	local closestQuestItemLink
	local closestDistance = ns.db.profile.distanceYd -- yards
	local onlyInZone = ns.db.profile.zoneOnly

	for index = 1, C_QuestLog.GetNumWorldQuestWatches() do
		-- this only tracks supertracked worldquests,
		-- e.g. stuff the player has shift-clicked on the map
		local questID = C_QuestLog.GetQuestIDForWorldQuestWatchIndex(index)
		if questID and (not onlyInZone or C_QuestLog.IsOnMap(questID)) then
			local distance, itemLink = GetQuestDistanceWithItem(questID)
			if distance and distance <= closestDistance then
				closestDistance = distance
				closestQuestItemLink = itemLink
			end
		end
	end

	if not closestQuestItemLink then
		for index = 1, C_QuestLog.GetNumQuestWatches() do
			local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
			if questID and QuestHasPOIInfo(questID) and (not onlyInZone or C_QuestLog.IsOnMap(questID)) then
				local distance, itemLink = GetQuestDistanceWithItem(questID)
				if distance and distance <= closestDistance then
					closestDistance = distance
					closestQuestItemLink = itemLink
				end
			end
		end
	end

	if not closestQuestItemLink then
		local onlyIfWatched = ns.db.profile.trackingOnly

		for index = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(index)
			local questID = info.questID
			if info and not info.isHeader and QuestHasPOIInfo(questID) then
				-- world quests are always considered
				if not (onlyIfWatched or info.isHidden) or C_QuestLog.IsWorldQuest(questID) then
					if not onlyInZone or C_QuestLog.IsOnMap(questID) then
						local distance, itemLink = GetQuestDistanceWithItem(questID)
						if distance and distance <= closestDistance then
							closestDistance = distance
							closestQuestItemLink = itemLink
						end
					end
				end
			end
		end
	end

	if closestQuestItemLink then
		return closestQuestItemLink
	end
end

local NPC_ID_PATTERN = '%w+%-.-%-.-%-.-%-.-%-(.-)%-'
function ns:GetNPCID(unit)
	if unit then
		local npcGUID = UnitGUID(unit)
		if npcGUID then
			return tonumber(npcGUID:match(NPC_ID_PATTERN))
		end
	end
end

function ns:GetItemID(itemLink)
	return (GetItemInfoFromHyperlink(itemLink))
end

function ns:GenerateItemLinkFromID(itemID)
	return string.format('|Hitem:%d|h', itemID)
end

function ns:GetCurrentMapID()
	return C_Map.GetBestMapForUnit('player')
end

function ns:Print(...)
	print('|cff33ff99' .. addonName .. '|r', ...)
end
