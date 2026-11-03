--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function gadget:GetInfo()
	return {
		name      = "Game Start Wrecks and neutrals Modoptions",
		desc      = "Implements Game start wrecks and neutral units",
		author    = "Stiofan",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = math.huge, -- (I dont know when would be appropriate)
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---

local MAP_AREA_TO_CAMP_RATIO = 45
local MAP_AREA_TO_VALUE_RATIO = 12
local AUTO_NEUTRAL_BASE_BUDGET = -200
local WRECK_RATIO = 0.3
local NEUTRAL_MOBILE_RATIO = 0.3
local CENTER_CAMP_MULT = 2
local NEUTRAL_EDGE_OFFSET = 700

local modOptions = Spring.GetModOptions()
local GaiaTeamID = Spring.GetGaiaTeamID()
local maxStartboxcount = Spring.GetGameRulesParam("startbox_max_n") or 2 -- TODO this seems to have some issue. Startboxjutsu is not good enough
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local allCompositions = VFS.Include("LuaRules/Configs/unit_compositions.lua")
local mobileCompositions = allCompositions.mobileCompositions
local staticCompositions = allCompositions.staticCompositions
local mixedCompositions = allCompositions.mixedCompositions
local noGoZones = GG.NoGoZonesGetMexAndGeoNoGoZones()

local autoNeutrals = tonumber(modOptions.starting_auto_neutrals) or 0
local autoNeutralsMapToValue =  tonumber(modOptions.starting_auto_neutrals_map_to_value) or MAP_AREA_TO_VALUE_RATIO
local autoNeutralsMapToCount =  tonumber(modOptions.starting_auto_neutrals_map_to_count) or MAP_AREA_TO_CAMP_RATIO

local startingWreckCount = tonumber(modOptions.starting_wrecks_count) or 0
local startingWreckValue = tonumber(modOptions.starting_wrecks_value) or 1000

local startingNeutralCount = tonumber(modOptions.starting_neutral_count) or 0
local startingNeutralValue = tonumber(modOptions.starting_neutral_value) or 1000
local startingNeutralMobileRatio = tonumber(modOptions.starting_neutral_mobile) or NEUTRAL_MOBILE_RATIO
--eeeh seems to crowd things too much maybe...
local startingNeutralWreckChance = tonumber(modOptions.starting_neutral_devastation) or WRECK_RATIO


local function CheckStartboxOverlap(x,z)
	local overlaps = false
	for i = 0, maxStartboxcount, 1 do
		if GG.CheckStartbox(i,x,z) then
			--Spring.MarkerAddPoint(x, 0, z, "Overlap?")
			overlaps = true
		end
	end
	return overlaps
end

local function GetMixedComposition(staticValue,mobileValue)
	local mobileComposition = GG.UnitSpawnerGetGroupCompositionByBudgetAndType(mobileValue,mobileCompositions)
	local mobileUnitComposition = GG.UnitSpawnerCompositionBuilder(mobileValue,mobileComposition)
	local staticComposition = GG.UnitSpawnerGetGroupCompositionByBudgetAndType(staticValue,staticCompositions)
	local staticUnitComposition = GG.UnitSpawnerCompositionBuilder(staticValue,staticComposition)
	return GG.UnitSpawnerAddUnitLists({mobileUnitComposition,staticUnitComposition})
end


local function SetupUnitComposition(campValue,mobileRatio)
	local unitComposition = {}
	if mobileRatio == 1 then
		local mobileComposition = GG.UnitSpawnerGetGroupCompositionByBudgetAndType(campValue,mobileCompositions)
		unitComposition = GG.UnitSpawnerCompositionBuilder(campValue,mobileComposition)
	elseif mobileRatio == 0 then
		local staticComposition = GG.UnitSpawnerGetGroupCompositionByBudgetAndType(campValue,staticCompositions)
		unitComposition = GG.UnitSpawnerCompositionBuilder(campValue,staticComposition)
	else
		local mobileBudget = campValue*mobileRatio
		local staticBudget = campValue - mobileBudget
		unitComposition = GetMixedComposition(staticBudget,mobileBudget)
	end
	return unitComposition
end

local function SpawnNeutralCamps(campCount,campValue,mobileRatio,wreckRatio)
	local unitIDs
	local unitBudget = campValue
	local wreckBudget = 0
	if wreckRatio ~= 0 then
		wreckBudget = campValue*wreckRatio
		unitBudget = campValue - wreckBudget
	end
	
	for i = 1, campCount/2, 1 do
		
		--TODO my map and startbox jutsu is not as strong, but also not too integral to show off the underlying stuff. small startboxes get close spawns
		--we mirror for an attempt at fairness.
		local mapOffsetX, mapOffsetZ = NEUTRAL_EDGE_OFFSET, NEUTRAL_EDGE_OFFSET
		local x,z = math.random(mapOffsetX,mapSizeX-mapOffsetX),math.random(mapOffsetZ,mapSizeZ-mapOffsetZ)
		local x2,z2 = mapSizeX-x,mapSizeZ-z
		local iteration = 0
		while CheckStartboxOverlap(x,z) and CheckStartboxOverlap(x2,z2) do
			x,z = math.random(mapOffsetX,mapSizeX-mapOffsetX),math.random(mapOffsetZ,mapSizeZ-mapOffsetZ)
			x2,z2 = mapSizeX-x,mapSizeZ-z
			if iteration > 10 then
				x,z = mapSizeX/2,mapSizeZ/2
				x2,z2 = mapSizeX-x,mapSizeZ-z
				break
			end
			iteration = iteration +1
		end
		local unitComposition = SetupUnitComposition(unitBudget,mobileRatio)
		if wreckBudget < 0 then
			local wreckComposition = SetupUnitComposition(wreckBudget,mobileRatio)
			unitComposition = GG.UnitSpawnerAddUnitLists({unitComposition,wreckComposition})
		end
		--[[
		Spring.Echo("Start neutrals")
		for key, value in pairs(unitComposition) do
			Spring.Echo(value.unitDefName .." = "..value.unitCount)
		end
		]]
		unitIDs,noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,GaiaTeamID,noGoZones)
		Spring.MarkerAddPoint(x, 0, z, "Reports of Remnants")
		unitIDs,noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,x2,z2,GaiaTeamID,noGoZones)
		Spring.MarkerAddPoint(x2, 0, z2, "Reports of Remnants")
	end
	--uneven number results in big map center camp :o 
	if campCount % 2 == 1 then
		local unitComposition = SetupUnitComposition(unitBudget*CENTER_CAMP_MULT,mobileRatio)
		if wreckBudget < 0 then
			local wreckComposition = SetupUnitComposition(wreckBudget*CENTER_CAMP_MULT,mobileRatio)
			unitComposition = GG.UnitSpawnerAddUnitLists({unitComposition,wreckComposition})
		end
		unitIDs,noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,mapSizeX/2,mapSizeZ/2,GaiaTeamID,noGoZones)
		Spring.MarkerAddPoint(mapSizeX/2, 0, mapSizeZ/2, "Reports of large Remnants")
	end
end

-- duplicate of spawning neutral camps without the startbox check
local function SpawnWreckClump(campCount,campValue,spacing)-- TODO spacing for more diverse fields?
	local unitIDs
	local unitComposition
	local campValue = campValue * 2 -- to make value about equal to output wrecks, since we lose about 60%
	for i = 1, campCount/2, 1 do
		local mobileRatio = math.random()
		--we mirror for an attempt at fairness, but for wrecks we can spice things up in variety
		local x,z = math.random(0,mapSizeX),math.random(mapSizeZ)
		local x2,z2 = mapSizeX-x,mapSizeZ-z
		
		local unitComposition1 = SetupUnitComposition(campValue,mobileRatio,1)
		local unitComposition2 = SetupUnitComposition(campValue,mobileRatio,1)
		for index, value in ipairs(unitComposition1) do
			value.wreckChance = 1 -- we set 1, as to not have to deal with chances when we mirror the compositions
			value.spacing = math.random(0,128)
		end
		for index, value in ipairs(unitComposition2) do
			value.wreckChance = 1 -- we set 1, as to not have to deal with chances when we mirror the compositions
			value.spacing = math.random(0,128)
		end
		
		unitIDs,noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition1,x,z,GaiaTeamID,noGoZones)
		unitIDs,noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition2,x2,z2,GaiaTeamID,noGoZones)
	end
	--uneven number results in big map center field
	if campCount % 2 == 1 then
		local unitComposition
		campValue = campValue * CENTER_CAMP_MULT
		local unitComposition = SetupUnitComposition(campValue,0.5,1)
		unitIDs,noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,mapSizeX/2,mapSizeZ/2,GaiaTeamID,noGoZones)
	end
end

--it will be hard to do anything definitive without some startbox jutsu
local function GuesstimateCampsAndWreckByMapSize(mapSizeX,mapSizeZ)
	-- 512 is the size of a mapsize "unit"
	local mapUnitsX = mapSizeX/512
	local mapUnitsY = mapSizeZ/512
	local mapUnitArea = mapUnitsX * mapUnitsY
	--LETS START GUESSTIMATING!!!
	--get arbitrary values from mapsize!
	
	-- count...
	-- smallest maps are 8x8 so area 64 -- count can be 1-2, uneven camps are bigger and centered
	-- some medium small maps are 10x12 so 120 -could stomach 2-3?
	-- lets go with 45 area per camp base? with how maps work I would need a function to do it well..
	-- but this estimation is okay
	local campCount = math.floor(mapUnitArea/autoNeutralsMapToCount)
	
	-- value...
	-- 8x8 -> 64 so 64 * 100 -> 640m ?
	-- seems a lil much since 
	-- 10x12 -> 120 so 120 *100 -> 1200m for 2-3 camps?
	-- we ball, trial and error
	local campValue = mapUnitArea * autoNeutralsMapToValue + AUTO_NEUTRAL_BASE_BUDGET
	
	--Neutrals
	--randomly add 1 to camp count or spread a camps value to all camps?
	if 0.5 > math.random() then
		local neutralCount = campCount + 1
		SpawnNeutralCamps(neutralCount,campValue,0.3,startingNeutralWreckChance)
	else
		local neutralValue = campValue + math.ceil(campValue/campCount)
		SpawnNeutralCamps(campCount,neutralValue,0.3,startingNeutralWreckChance)
	end
	
	--Wreckfields do the same for now...
	campCount = campCount * 2
	if 0.5 > math.random() then
		local neutralCount = campCount + 1
		SpawnWreckClump(neutralCount,campValue)
	else
		local neutralValue = campValue + math.ceil(campValue/(campCount/2))
		SpawnWreckClump(campCount,neutralValue)
	end
end



function gadget:Initialize()

end

function gadget:GameStart()
	
	maxStartboxcount = Spring.GetGameRulesParam("startbox_max_n")

	if autoNeutrals ~= 0 then
		GuesstimateCampsAndWreckByMapSize(mapSizeX,mapSizeZ)
	end
	if startingNeutralCount and startingNeutralValue and startingNeutralCount >= 0 and startingNeutralValue >= 0 then
		SpawnNeutralCamps(startingNeutralCount,startingNeutralValue,startingNeutralMobileRatio,startingNeutralWreckChance)
	end
	if startingWreckCount and startingWreckValue and startingWreckCount >= 0 and startingWreckValue >= 0 then
		SpawnWreckClump(startingWreckCount,startingWreckValue)
	end
end