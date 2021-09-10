--[[
MapNames
]]

local MAJOR, MINOR = "MapNames", 1
local MapNames, oldVersion = LibStub:NewLibrary(MAJOR, MINOR)

local HBD = LibStub("HereBeDragons-2.0")
assert(HBD, MAJOR .. " requires HereBeDragons")

local MapOverrides = {
	[1670] = { ["name"] = "Ring of Fates (Oribos)", },
	[1671] = { ["name"] = "Ring of Transference (Oribos)", },
	[1672] = { ["name"] = "The Broker's Den (Oribos)", },
	[1673] = { ["name"] = "The Crucible (Oribos)", },
}

MapNames.MapNameTable = {}
local MapNameTable = MapNames.MapNameTable

local function StripNonAlphaNumeric(string)
	return string:gsub("[^%a%d]", "")
end

function MapNames:GenerateMapNameTables()
	local mapNameTable = {}

	for mapType=Enum.UIMapType.Cosmic, Enum.UIMapType.Orphan do
		mapNameTable[mapType] = {}
	end

	for mapID, mapData in pairs(HBD.mapData) do
		local mapType = mapData.mapType
		local mapName = mapData.name

		if mapName and mapNameTable[mapType] and mapNameTable[mapType][mapName] then
			if type(mapNameTable[mapType][mapName]) ~= "table" then
				mapNameTable[mapType][mapName] = {mapNameTable[mapType][mapName]}
			end
			table.insert(mapNameTable[mapType][mapName], mapID)
		else
			mapNameTable[mapType][mapName] = mapID
		end
		mapNameTable[mapType]["#" .. mapID] = mapID
	end

	local newEntries = {}
	for mapType=Enum.UIMapType.Cosmic, Enum.UIMapType.Orphan do
		newEntries[mapType] = {}
	end
	for _, typeTable in pairs(mapNameTable) do
		for mapName, mapID in pairs(typeTable) do
			if type(mapID) == "table" then
				typeTable[mapName] = nil
				for idx, mapId in pairs(mapID) do
					local parent = HBD.mapData[mapId].parent
					local parentName = (parent and (parent > 0) and HBD.mapData[parent].name)
					if parentName then
						-- We rely on the implicit acending order of mapID's so the lowest one wins
						if not newEntries[HBD.mapData[mapId].mapType][mapName .. ":" .. parentName] then
							newEntries[HBD.mapData[mapId].mapType][mapName .. ":" .. parentName] = mapId
						else
							newEntries[HBD.mapData[mapId].mapType][mapName .. ":" .. tostring(mapId)] = mapId
						end
					end
				end
			end
		end
	end

	-- Add the de-duplicated entries
	for mapType, mapName in pairs(newEntries) do
		for _, mapId in pairs(mapName) do
			mapNameTable[mapType][mapName] = mapID
		end
	end

	for mapID, mapData in pairs(MapOverrides) do
		if mapData.name or mapData.mapType then
			local mapInfo = MapNames:GetMapInfo(mapID)
			mapNameTable[mapInfo.mapType][mapInfo.name] = mapID
		end
	end

	return mapNameTable
end

--- Wrapper for the standard C_Map.GetMapInfo to allow for value overrides
-- @param uiMapID Map ID to fetch information about.
-- @return A table with the given map's information, overridden.
function MapNames:GetMapInfo(uiMapID)
	local uiMapID = tonumber(uiMapID)
	local mapInfo = C_Map.GetMapInfo(uiMapID)

	if MapOverrides[uiMapID] ~= nil then
		for key, value in pairs(MapOverrides[uiMapID]) do
			mapInfo[key] = value
		end
	end

	return mapInfo
end

--- Search for all map IDs that match a supplied name.
-- @paramsig mapName [, ...]
-- @param mapName The name of the map that is searched for.
-- @param ... The zone types that should be checked. Defaults to all of them.
-- @return A table containing all matching map names and their IDs.
function MapNames:GetMatchingMapsFromName(mapName, ...)
	local typesToCheck = { ... }
	if #typesToCheck == 0 then
		typesToCheck = { Enum.UIMapType.Cosmic,
						 Enum.UIMapType.World,
						 Enum.UIMapType.Continent,
						 Enum.UIMapType.Zone,
						 Enum.UIMapType.Dungeon,
						 Enum.UIMapType.Micro,
						 Enum.UIMapType.Orphan
					   }
	end

	local matches = {}
	local desiredName = StripNonAlphaNumeric(mapName:lower())

	for _, mapType in pairs(typesToCheck) do
		for checkedMapName, mapId in pairs(MapNameTable[mapType]) do
			local name = StripNonAlphaNumeric(checkedMapName:lower())
			if name == desiredName then
				return { [mapId] = checkedMapName }
			elseif name:match(desiredName) then
				matches[mapId] = checkedMapName
			end
		end
	end

	for _ in pairs(matches) do
		return matches
	end

	return nil
end

--- Fetches the first map of the map's parents that matches the type.
-- @paramsig mapType [, uiMapID][, forceParentsHaveType]
-- @param mapType The type of map to find (See: Enum.UIMapType)
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetMapOfTypeFromMap(mapType, uiMapID, forceParentsHaveType)
	-- Return the given map ID if there is no checked map type
	if mapType == nil then return uiMapID end

	-- Declare argument variables
	local uiMapID = uiMapID
	local forceParentsHaveType = forceParentsHaveType

	-- Assign defaults
	if uiMapID == nil then uiMapID = C_Map.GetBestMapForUnit("player") else uiMapID = tonumber(uiMapID) end
	if forceParentsHaveType == nil then forceParentsHaveType = false end

	-- Return nil if the map ID does not exist or is not a number
	if uiMapID == nil then return nil end

	local mapInfo = MapNames:GetMapInfo(uiMapID)

	-- Supplied map type is the desired type
	if mapInfo.mapType == mapType then return uiMapID end
	-- Map does not contain parents of the type
	if mapInfo.mapType < Enum.UIMapType.Zone then return nil end

	-- Track old map information so we can assume zone-less maps are zones themselves
	local oldMapID
	local oldMapInfo

	while mapInfo.mapType > mapType do
		oldMapID = uiMapID
		oldMapInfo = mapInfo
		uiMapID = mapInfo.parentMapID
		mapInfo = MapNames:GetMapInfo(uiMapID)

		-- Desired parent map type found
		if mapInfo.mapType == mapType then
			return uiMapID
		-- Assume maps without a parent zone are themselves a zone
		elseif forceParentsHaveType and mapInfo.mapType < mapType then
			return oldMapID
		end
	end

	-- Map does not contain a parent with the desired type
	return nil
end

--- GetMapOfTypeFromMap wrapper for Cosmic map types. For completeness.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetCosmicFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.Cosmic, uiMapID, forceParentsHaveType)
end

--- GetMapOfTypeFromMap wrapper for World map types.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetWorldFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.World, uiMapID, forceParentsHaveType)
end

--- GetMapOfTypeFromMap wrapper for Continent map types.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetContinentFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.Continent, uiMapID, forceParentsHaveType)
end

--- GetMapOfTypeFromMap wrapper for Zone map types.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetZoneFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.Zone, uiMapID, forceParentsHaveType)
end

--- GetMapOfTypeFromMap wrapper for Dungeon map types.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetDungeonFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.Dungeon, uiMapID, forceParentsHaveType)
end

--- GetMapOfTypeFromMap wrapper for Micro map types.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetMicroFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.Micro, uiMapID, forceParentsHaveType)
end

--- GetMapOfTypeFromMap wrapper for Orphan map types.
-- @paramsig [, uiMapID][, forceParentsHaveType]
-- @param uiMapID Map ID to compare the (parents) type for.
-- @param forceParentsHaveType Determines if the function should return the highest
--                             parent of the map if there ais no parent map with the
--                             desired type
-- @return The map ID for the map that matches the type or nil.
function MapNames:GetOrphanFromMap(uiMapID, forceParentsHaveType)
	return MapNames:GetMapOfTypeFromMap(Enum.UIMapType.Orphan, uiMapID, forceParentsHaveType)
end
