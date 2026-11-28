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
		layer     = 1, -- using 0 causes issues with units not animating among other things
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local WRECK_TO_UNIT_COST_MULT = 2.5 -- mult to get from wreck -> unit cost


-- Parameters for usable area guestimation Params
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local MAP_SIZE_UNIT = 512 --Elmo to lobby mapsize

local STARTBOX_CIRCLE_CHECK_RADIUS = 700

local PLACEMENT_CHECK_ID = UnitDefNames["staticrearm"].id -- a lil bigger, but should be placable often

-- Parameters and Modoptions factored into generation of units
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local AUTO_MAP_CAMP_BASE_MULT = 0.01
local AUTO_MAP_VALUE_BASE_MULT = 0.6 -- flattening the value curve
local AUTO_MAP_VALUE_OFFSET = -200

local AUTO_MIN_CAMP_COUNT_MULT = 0.3

local WeWantSpice = true

local NEUTRAL_ADDITIONAL_WRECK_RATIO = 0.6
local NEUTRAL_MOBILE_MIN = 30
local NEUTRAL_MOBILE_MAX = 50
local NEUTRAL_EDGE_OFFSET = 500

local NEUTRAL_CHICKEN_CHANCE = 0 --TODO theres some figuring out to be done but I'll keep this open

local AUTO_WRECK_COUNT_MULT = 1.5
local AUTO_WRECK_VALUE_MULT = 0.7

local MEX_SEARCH_RADIUS = MAP_SIZE_UNIT * 1200 --guesstimation

local modOptions = Spring.GetModOptions()
local autoNeutrals = tonumber(modOptions.starting_auto_neutrals) or 0
local autoWrecks = tonumber(modOptions.starting_auto_wrecks) or 0

local autoNeutralsCountPercentMult =  tonumber(modOptions.starting_auto_neutrals_count_percent) or 100
local autoNeutralsValuePercentMult =  tonumber(modOptions.starting_auto_neutrals_value_percent) or 100

local startingNeutralCount = tonumber(modOptions.starting_neutral_count) or 0
local startingNeutralValue = tonumber(modOptions.starting_neutral_value) or 0

local startingWreckCount = tonumber(modOptions.starting_wrecks_count) or 0
local startingWreckValue = tonumber(modOptions.starting_wrecks_value) or 0

--local startingNeutralMobileRatio = tonumber(modOptions.starting_neutral_mobile) or NEUTRAL_MOBILE_RATIO -- I prefer it being variable :O
local startingNeutralChickenChance = tonumber(modOptions.starting_neutral_chicken_chance) or NEUTRAL_CHICKEN_CHANCE
local startingNeutralWreckRatio = tonumber(modOptions.starting_neutral_wrecks_ratio) or NEUTRAL_ADDITIONAL_WRECK_RATIO

-- Compositions and nogozones setup
local allCompositions = VFS.Include("LuaRules/Configs/unit_compositions.lua")
local mobileCompositions = allCompositions.neutralCamps.mobileCompositions
local staticCompositions = allCompositions.neutralCamps.staticCompositions
local pointsOfInterestCompositions = allCompositions.neutralCamps.pointsOfInterest
local mexAndGeoNoGoZones = GG.NoGoZonesGetMexAndGeoNoGoZones()
local localNoGoZones = mexAndGeoNoGoZones

local CHICKEN_SECTION_GROUPS = {"chickens","extraChickens"}


-- Team setup
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GaiaTeamID     = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID, false))
local initalAllianceCount = -1 --subtract gaia
for index, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
	local teamlist = Spring.GetTeamList(allyTeamID)
	if (#teamlist) >0 then
		initalAllianceCount = initalAllianceCount +1
	end
end
local neutralAllyTeamID = GaiaAllyTeamID
local startingNeutralsTeamInput = tonumber(modOptions.starting_neutrals_team) or 0

if startingNeutralsTeamInput > 0 and startingNeutralsTeamInput <= initalAllianceCount then -- if inbetween 0 and max teamcount, we have a team to spawn on!
	neutralAllyTeamID = startingNeutralsTeamInput -1 -- -1 for offset 
	if neutralAllyTeamID == GaiaAllyTeamID then --TODO there is likely a better solution, it seems sometimes Gaia is not the last team in the list
		neutralAllyTeamID = neutralAllyTeamID + 1
	end
else -- anything else translates to gaia neutrals
	neutralAllyTeamID = GaiaAllyTeamID
end


local neutralUnitIds = {}

--Utility
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- TODO would this be a useful util function? maybe it already exists :o
local function GetRandomTeamIDFromAllyTeam(allyTeamID)
	local allyTeamList = Spring.GetTeamList(allyTeamID) or GaiaAllyTeamID
	local teamMateCount = 0
	local teamToSpawnOn
	if allyTeamID == GaiaAllyTeamID then
		return GaiaTeamID
	end
	
	for _,_ in ipairs(allyTeamList) do
		teamMateCount = teamMateCount + 1 
	end
	teamToSpawnOn = allyTeamList[math.random(1,teamMateCount)] or nil
	return teamToSpawnOn
end

--Stars and Bars thingy. This is half googlesearch vibed
local function split_integer(totalBudget, splitCount, min_val)
    min_val = min_val or 0
	splitCount = splitCount or 1
	
	if splitCount == 1 then
        return { totalBudget }
    end
	
    local remaining = totalBudget - (splitCount * min_val)
	if remaining <= 0 then
		Spring.Echo("Total V is too small for N items with the given min_val")
		remaining = splitCount * min_val
	end


    -- 1. Generate N - 1 random cut-points between 0 and remaining
    local cuts = {}
    for i = 1, splitCount - 1 do
        cuts[i] = math.random(0, remaining)
    end

    -- 2. Sort the cut-points in ascending order
    table.sort(cuts)
	
    -- 3. Calculate differences between adjacent cut-points and add min_val
    local result = {}
    local prev = 0
    for i = 1, splitCount - 1 do
        result[i] = (cuts[i] - prev) + min_val
        prev = cuts[i]
    end
    result[splitCount] = (remaining - prev) + min_val
	
    return result
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetGroupCompositionByBudgetAndType(budget,compositionType)
    if not budget then
        budget = 300
    end
    if not compositionType then
        compositionType = allCompositions.mobileCompositions
    end
    if (budget < 500) then
        return compositionType.tinyCost[math.random(#compositionType.tinyCost)]
	elseif (budget < 1500) then
        return compositionType.lowCost[math.random(#compositionType.lowCost)]
    elseif (budget < 3000) then
        return compositionType.mediumCost[math.random(#compositionType.mediumCost)]
    elseif (budget < 7500) then
        return compositionType.highCost[math.random(#compositionType.highCost)]
    elseif (budget >= 7500) then
        return compositionType.ludicrousCost[math.random(#compositionType.ludicrousCost)]
    end
    return {assault = 1}
end

local function GetMixedComposition(staticValue,mobileValue,sectionGroups,moveGroups)
	local mobileComposition = GetGroupCompositionByBudgetAndType(mobileValue,mobileCompositions)
	local mobileUnitComposition = GG.UnitSpawnerCompositionBuilder(mobileValue,mobileComposition,sectionGroups,moveGroups)
	local staticComposition = GetGroupCompositionByBudgetAndType(staticValue,staticCompositions)
	local staticUnitComposition = GG.UnitSpawnerCompositionBuilder(staticValue,staticComposition,sectionGroups,moveGroups)
	return GG.UnitSpawnerAddCompositionLists({staticUnitComposition,mobileUnitComposition})
end


local function SetupUnitComposition(campValue,mobileRatio,sectionGroups,moveGroups)
	local unitComposition = {}
	-- 1/6 budget goes to POI!
	local poiBudget = campValue * 0.6
	local remainingValue = campValue - campValue  * 0.6
	
	local poiGroupComposition = GetGroupCompositionByBudgetAndType(poiBudget,pointsOfInterestCompositions)
	poiGroupComposition = GG.UnitSpawnerCompositionBuilder(poiBudget,poiGroupComposition,sectionGroups,moveGroups)
	
	
	if mobileRatio == 1 then
		local mobileComposition = GetGroupCompositionByBudgetAndType(remainingValue,mobileCompositions)
		unitComposition = GG.UnitSpawnerCompositionBuilder(remainingValue,mobileComposition,sectionGroups,moveGroups)
	elseif mobileRatio == 0 then
		local staticComposition = GetGroupCompositionByBudgetAndType(remainingValue,staticCompositions)
		unitComposition = GG.UnitSpawnerCompositionBuilder(remainingValue,staticComposition,sectionGroups,moveGroups)
	else
		local mobileBudget = remainingValue * mobileRatio
		local staticBudget = remainingValue - mobileBudget
		unitComposition = GetMixedComposition(staticBudget,mobileBudget,sectionGroups,moveGroups)
	end
	local returnComposition = GG.UnitSpawnerAddCompositionLists({poiGroupComposition,unitComposition})
	return returnComposition
end

local function HandleCampUnits(x,z,unitIDs)
	for unitID, _ in pairs(unitIDs) do
		
		--TODO? adding all neutrals here since all neutrals do want to patrol
		neutralUnitIds[unitID] = unitID
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitDef = UnitDefs[unitDefID]
		local unitTeam = Spring.GetUnitTeam(unitID)
		
		-- factories
		if unitDef.isFactory and neutralAllyTeamID == GaiaAllyTeamID then
			--TODO check if silo does things correctly. aka if the missiles are on freefire
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, 2, 0) -- we set units to roam and attack nearby enemies!
			GG.Zombies.SetRandomFactoryOrders(unitID, unitDefID) -- random queued units!
		-- bombs that dont want to move
		elseif unitDef.name == "cloakbomb" or unitDef.name == "shieldbomb" then
			
		-- all other units
		else
			Spring.GiveOrderToUnit(unitID,CMD.PATROL,{x + math.random(-100,100),0,z + math.random(-100,100)}) 
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, 1, 0) -- roam is a bit too spicy it seems
		end
	end
end

local function GetCampSpawnPairPositions(ignoreStartbox)
	local mapOffsetX, mapOffsetZ = NEUTRAL_EDGE_OFFSET, NEUTRAL_EDGE_OFFSET
	local x,z = math.random(mapOffsetX,mapSizeX-mapOffsetX),math.random(mapOffsetZ,mapSizeZ-mapOffsetZ)
	local x2,z2
	local iteration = 0
	x,z = GG.NoGoZonesGetValidSpawnPositionForUnit(PLACEMENT_CHECK_ID,{x,z},true,localNoGoZones)
	x2,z2 = mapSizeX-x,mapSizeZ-z
	-- My startbox jutsu has improved!! 
	while 
	(GG.MapUtilityCheckAnyCircularStartboxOverlap(x,z,STARTBOX_CIRCLE_CHECK_RADIUS) and not ignoreStartbox) or 
	(GG.MapUtilityCheckAnyCircularStartboxOverlap(x2,z2,STARTBOX_CIRCLE_CHECK_RADIUS) and not ignoreStartbox) or 
	GG.MapUtilityCheckLavaOrRoughTerrain(x,z) or 
	GG.MapUtilityCheckLavaOrRoughTerrain(x2,z2) do
		x,z = math.random(mapOffsetX,mapSizeX-mapOffsetX),math.random(mapOffsetZ,mapSizeZ-mapOffsetZ)
		x,z = GG.NoGoZonesGetValidSpawnPositionForUnit(PLACEMENT_CHECK_ID,{x,z},true,localNoGoZones)
		x2,z2 = mapSizeX-x,mapSizeZ-z
		if iteration > 10 then
			x,z = mapSizeX/2,mapSizeZ/2
			x2,z2 = mapSizeX-x,mapSizeZ-z
			break
		end
		iteration = iteration +1
	end
	return x,z,x2,z2
end

local function SpawnCampPair(campBudget,sectionGroups,mobileRatio,additionalWreckRatio)
	--we mirror for an attempt at fairness.
	local x,z,x2,z2 = GetCampSpawnPairPositions()
	local heighPos1, heighPos2 = Spring.GetGroundHeight(x,z),Spring.GetGroundHeight(x2,z2)
	
	local moveGroups = nil
	
	if heighPos1 < -25 and heighPos2 < -25 then -- we do ship things if both camps are in water
		moveGroups = {"amph","hover","sea"}
	elseif heighPos1 < -25 or heighPos2 < -25 then -- we do amphibious things when only one is!
		moveGroups = {"amph","hover"}
	end
	
	local wreckBudget = 0
	if additionalWreckRatio ~= 0 then
		wreckBudget = campBudget * additionalWreckRatio * WRECK_TO_UNIT_COST_MULT
	end
	
	local unitComposition = SetupUnitComposition(campBudget,mobileRatio,sectionGroups,moveGroups)
	if wreckBudget > 0 then
		local wreckComposition = SetupUnitComposition(wreckBudget,mobileRatio)
		for index, value in ipairs(wreckComposition) do
			value.wreckChance = 1
			value.spacing = math.random(32,64)
		end
		unitComposition = GG.UnitSpawnerAddCompositionLists({unitComposition,wreckComposition})
	end
	--Spring.Echo("Start neutrals")
	--Spring.Utilities.TableEcho(unitComposition)
	local unitIDs1Pod = nil
	local unitIDs2Pod = nil
	local teamID = GetRandomTeamIDFromAllyTeam(neutralAllyTeamID)
	unitIDs1Pod,localNoGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,teamID,localNoGoZones)
	HandleCampUnits(x,z,unitIDs1Pod)
	if sectionGroups ~= CHICKEN_SECTION_GROUPS then
		GG.UnitSpawnerBuildMexInRadius(x,z,MEX_SEARCH_RADIUS,teamID)
		GG.UnitSpawnerBuildGeosInRadius(x,z,MEX_SEARCH_RADIUS,teamID,(math.random()>0.5))
	end
	Spring.MarkerAddPoint(x, 0, z, "Reports of Remnants") -- important as they arent visible globaly
	
	
	teamID = GetRandomTeamIDFromAllyTeam(neutralAllyTeamID)
	unitIDs2Pod,localNoGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,x2,z2,teamID,localNoGoZones)
	HandleCampUnits(x2,z2,unitIDs2Pod)
	if sectionGroups ~= CHICKEN_SECTION_GROUPS then -- nogozones make the order of opperations not matter for spawning these later, so thats neat!
		GG.UnitSpawnerBuildMexInRadius(x2,z2,MEX_SEARCH_RADIUS,teamID)
		GG.UnitSpawnerBuildGeosInRadius(x2,z2,MEX_SEARCH_RADIUS,teamID,(math.random()>0.5))
	end
	Spring.MarkerAddPoint(x2, 0, z2, "Reports of Remnants")
end

local function SpawnNeutralCamps(inputCampCount,totalCampBudget,mapWaterRatio,additionalWreckRatio)
	local unitIDs
	local teamID = GaiaTeamID
	local thereBeChickens = false
	local thereBeUnevenCamps = false
	local unitIDs
	
	local maxCamps = inputCampCount
	local minCamps = math.floor(inputCampCount * AUTO_MIN_CAMP_COUNT_MULT)
	
	if minCamps < 1 then 
		minCamps = 1 
	end
	
	local campsToSpawn = math.random(minCamps,maxCamps)
	
	if campsToSpawn % 2 == 1 then
		thereBeUnevenCamps = true
		campsToSpawn = campsToSpawn + 1
	end
	
	local budgetSplits = split_integer(totalCampBudget,campsToSpawn,500)
	table.sort(budgetSplits)
	
	if thereBeUnevenCamps then
		
		
		local campBudget = table.remove(budgetSplits,#budgetSplits)
		local sectionGroups = nil
		local thisMobileRatio = math.random(NEUTRAL_MOBILE_MIN,NEUTRAL_MOBILE_MAX)/100
		if math.random() < startingNeutralChickenChance then
			sectionGroups = CHICKEN_SECTION_GROUPS
			thisMobileRatio = 0.8
			thereBeChickens = true
		end
		local height = Spring.GetGroundHeight(mapSizeX/2,mapSizeZ/2)
		--if the middle is too rough, or a pond on an otherwise non water map, we make 2 camps instead
		if GG.MapUtilityCheckLavaOrRoughTerrain(mapSizeX/2,mapSizeZ/2) or (height < 0 and mapWaterRatio < 0.3) then			
			unitIDs = SpawnCampPair(campBudget/2,sectionGroups,thisMobileRatio,additionalWreckRatio)
		else
			local moveGroups = nil
			if height < -25  and mapWaterRatio > 0.3 then -- we do ship things if both camps are in water
				moveGroups = {"amph","hover","sea"}
			elseif height < -25 then -- we do amphibious things when theres not too much water
				moveGroups = {"amph","hover"}
			end
			local unitComposition = SetupUnitComposition(campBudget,thisMobileRatio,sectionGroups,moveGroups)
			--Spring.Utilities.TableEcho(unitComposition)
			local wreckBudget = 0
			if additionalWreckRatio ~= 0 then
				wreckBudget = campBudget * additionalWreckRatio * WRECK_TO_UNIT_COST_MULT
			end
			if wreckBudget > 0 then
				local wreckComposition = SetupUnitComposition(wreckBudget,math.random())
				for index, value in ipairs(wreckComposition) do
					value.wreckChance = 1
					value.spacing = math.random(32,64)
				end
				unitComposition = GG.UnitSpawnerAddCompositionLists({unitComposition,wreckComposition})
			end
				teamID = GetRandomTeamIDFromAllyTeam(neutralAllyTeamID)
				unitIDs,localNoGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,mapSizeX/2,mapSizeZ/2,teamID,localNoGoZones)
				HandleCampUnits(mapSizeX/2,mapSizeZ/2,unitIDs)
				if not thereBeChickens then
					GG.UnitSpawnerBuildMexInRadius(mapSizeX/2,mapSizeZ/2,MEX_SEARCH_RADIUS*1.3,teamID)
					GG.UnitSpawnerBuildGeosInRadius(mapSizeX/2,mapSizeZ/2,MEX_SEARCH_RADIUS*1.3,teamID,(math.random()>0.5))
				end
			Spring.MarkerAddPoint(mapSizeX/2, 0, mapSizeZ/2, "Reports of Remnants")
		end
	end
	
	for index, budget in ipairs(budgetSplits) do
		local sectionGroups = nil
		local thisMobileRatio = math.random(NEUTRAL_MOBILE_MIN,NEUTRAL_MOBILE_MAX)/100
		--Spring.Echo(thisMobileRatio)
		if math.random() < startingNeutralChickenChance then
			sectionGroups = CHICKEN_SECTION_GROUPS
			thisMobileRatio = 0.8
		end
		local theseUnitIDs = SpawnCampPair(budget,sectionGroups,thisMobileRatio,additionalWreckRatio)
	end
end

-- duplicate of spawning neutral camps without the startbox check
local function SpawnWreckClump(wreckFieldCount,wreckFieldValue)
	local unitIDs
	local unitComposition
	local unitValue = wreckFieldValue * WRECK_TO_UNIT_COST_MULT
	for i = 1, wreckFieldCount/2, 1 do
		local mobileRatio = math.random()
		--we mirror for an attempt at fairness
		local x,z = math.random(0,mapSizeX),math.random(mapSizeZ)
		local x2,z2 = mapSizeX-x,mapSizeZ-z
		
		local unitComposition = SetupUnitComposition(unitValue,mobileRatio)
		for index, value in ipairs(unitComposition) do
			value.wreckChance = 1
			--value.spacing = math.random(0,64)
		end
		
		unitIDs,localNoGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,GaiaTeamID,localNoGoZones)
		Spring.MarkerAddPoint(x, 0, z, "Wreckfield") --people have eyes... but it may still be good to ping
		unitIDs,localNoGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,x2,z2,GaiaTeamID,localNoGoZones)
		Spring.MarkerAddPoint(x2, 0, z2, "Wreckfield")
	end
	--uneven number results in big map center field
	if wreckFieldCount % 2 == 1 then
		unitValue = unitValue * CENTER_CAMP_MULT
		local unitComposition = SetupUnitComposition(unitValue,0.5,1)
		for index, value in ipairs(unitComposition) do
			value.wreckChance = 1
			--value.spacing = math.random(0,64)
		end
		unitIDs,localNoGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,mapSizeX/2,mapSizeZ/2,GaiaTeamID,localNoGoZones)
	end
end

--could maybe be improved with mex analysis
local function GuesstimateCampCountAndValueByMapArea(mapArea)
	--LETS START GUESSTIMATING!!!
	
	--TODO this system could use improvement
	-- Log scale assements, maybe mex income additionals
	-- only value, then should randomise into what sort of split of camps works. Large medium small, massive etcetc.
	
	-- count...
	-- smallest maps are 8x8 so area 64 -- count can be 1-2, uneven camps are bigger and centered
	-- some medium small maps are 10x12 so 120 -could stomach 2-3?
	-- lets go with 45 area per camp base? with how maps work I would need a function to do it well..
	-- but this estimation is okay
	local campCount = math.ceil(autoNeutralsCountPercentMult/100 * AUTO_MAP_CAMP_BASE_MULT * mapArea)
	
	
	-- value...
	-- 8x8 -> 64 so 64 * 100 -> 640m ?
	-- seems a lil much since 
	-- 10x12 -> 120 so 120 *100 -> 1200m for 2-3 camps?
	-- we ball, trial and error
	-- it may be smart to revamp things into a entire map budget split between the amount of camps rather than the inverse
	-- though this scales the neutrals nicely Imo
	--local campValue = mapArea * autoNeutralsMapToValue + AUTO_MAP_VALUE_OFFSET
	
	--> this was per camp budget, lets instead try budgeting for all camps
	
	local campValue = math.ceil(autoNeutralsValuePercentMult/100 * AUTO_MAP_VALUE_BASE_MULT * mapArea^2) + AUTO_MAP_VALUE_OFFSET 
	
	return campCount, campValue
end

---> input for count and value. Value is all camps now 
---> we add if desired, the generated count to that
---> 
local function SetupNeutralAndWreckSpawn()
	
	-- modoptions act as offsets to generated values if the automatic generation is enabled
	local neutralCount,neutralValue = startingNeutralCount,startingNeutralValue
	local wreckCount,wreckValue = startingWreckCount, startingWreckValue
	
	local usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio = GG.MapUtilityGetMapArea()
	local count,value = GuesstimateCampCountAndValueByMapArea(usableMapArea)
	
	if autoNeutrals ~= 0 then
		neutralCount,neutralValue = neutralCount + count, neutralValue + value
	end
	if neutralCount > 0 and neutralValue > 0 then
		SpawnNeutralCamps(neutralCount,neutralValue,waterAreaRatio,startingNeutralWreckRatio)
	end
	
	if autoWrecks ~= 0 then
		wreckCount,wreckValue = wreckCount + count*AUTO_WRECK_COUNT_MULT, wreckValue + value*AUTO_WRECK_VALUE_MULT
	end
	if wreckCount > 0 and wreckValue > 0 then
		SpawnWreckClump(wreckCount,wreckValue)
	end
	
	-- todo modoption to show on init
	for unitID, _ in pairs(neutralUnitIds) do
		Spring.SetUnitAlwaysVisible(unitID, true)
		local allyTeamList = Spring.GetAllyTeamList()
		for i = 1, #allyTeamList do
			local allyTeamID = allyTeamList[i]
			Spring.SetUnitLosState(unitID, allyTeamID, 15)
		end
	end
end
	
function gadget:Initialize()
	SetupNeutralAndWreckSpawn()
end

function gadget:GameStart()
	
	for unitID, _ in pairs(neutralUnitIds) do
		
		local unitDefId = Spring.GetUnitDefID(unitID)
		local unitDef = UnitDefs[unitDefId]
		local unitTeam = Spring.GetUnitTeam(unitID)
		
		-- TODO put this in spawner api
		--manually add storage since it seems to break
		if unitDef.metalStorage > 0 then
			local _, storage = Spring.GetTeamResources(unitTeam,"metal")
			storage = storage + unitDef.metalStorage
			Spring.SetTeamResource(unitTeam,"ms",storage)
		end
		if unitDef.energyStorage > 0 then
			local _, storage = Spring.GetTeamResources(unitTeam,"energy")
			storage = storage + storage
			Spring.SetTeamResource(unitTeam,"es",storage)
		end
		
		--todo modoption to hide on gamestart
		Spring.SetUnitAlwaysVisible(unitID, false)
		local allyTeamList = Spring.GetAllyTeamList()
		for i = 1, #allyTeamList do
			local allyTeamID = allyTeamList[i]
			if allyTeamID ~= neutralAllyTeamID and allyTeamID ~= GaiaAllyTeamID then
				Spring.SetUnitLosState(unitID, allyTeamID, 0)
			end
		end
	end

	
	
	local usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio = GG.MapUtilityGetMapArea()
	Spring.Echo("Area Guestimation")
	Spring.Echo(usableMapArea)
	Spring.Echo(usableMapRatio)
	Spring.Echo(waterAreaRatio)
	Spring.Echo(startBoxAreaRatio)
	
	local count,value = GuesstimateCampCountAndValueByMapArea(usableMapArea)
	Spring.Echo("Value and count Guestimation")
	Spring.Echo(value)
	Spring.Echo(count)
	

	
	--[[
	local usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio = GG.MapUtilityGetMapArea()
	Spring.Echo("usableArea = "..usableMapArea)

		Spring.Echo("UTIL TEST!")
		]]
end