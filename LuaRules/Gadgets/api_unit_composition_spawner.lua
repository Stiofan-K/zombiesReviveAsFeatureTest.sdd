--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function gadget:GetInfo()
	return {
		name      = "Unit Composition Spawning API",
		desc      = "Implements unit spawning and composition building functions",
		author    = "Stiofan",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = 1, -- Before terraforming gadget (I dont know when would be appropriate)
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGameFrame = Spring.GetGameFrame

local modOptions = Spring.GetModOptions()
local GaiaTeamID = Spring.GetGaiaTeamID()
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local allUnitGroups = VFS.Include("LuaRules/Configs/unit_class_groupings.lua")

local UNIT_SPACING = 0
local STRUCTURE_SPACING = 128

--Utilities
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function shuffle(t) --Fisher-Yates taught me this trick! (It was actually Github)
	local tbl = {}
	for i = 1, #t do
		tbl[i] = t[i]
	end
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

-- adds 2 Unit Lists together! accounts for different "spellings"
local function AddUnitLists(tableList)
	local returnList = {}
	for index, table in ipairs(tableList) do
		for i, v in pairs(table) do
			if type(v) == "table" then
				returnList[#returnList +1] = v
			elseif type(i) =="table" then
				returnList[#returnList +1] = i
			elseif type(i) =="string"and type(v) == "number" then
				returnList[#returnList +1] = {unitDefName = i, unitCount = v}
			else
				Spring.Echo("Input of AddUnitLists unit_composition_spawner has error")
				Spring.Echo(i)
				Spring.Echo(v)
			end
		end
	end
	return returnList
end

-- failsafe for 0 cost units
local function GetCostFromUnitDefName(unitDefName)
	--Spring.Echo(unitDefName)
	local unitCost = UnitDefNames[unitDefName].metalCost or 0
	if unitCost or unitCost <= 0 then
		unitCost = UnitDefNames[unitDefName].buildTime
	end
	if not unitCost or unitCost <= 0 then
		unitCost = 200
		Spring.Echo("Unit has no cost set, defaulting to 200")
	end
	return unitCost
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetRandomUnitsFromListByCount(targetCount,unitDefNameList,multiRandomise)
	local unitDefName = unitDefNameList[math.random(#unitDefNameList)]
	if not multiRandomise then
		local returnUnitArray = {} 
		returnUnitArray[1] = {unitDefName = unitDefName, unitCount = targetCount}
		return  returnUnitArray
	end
	local unitCount = 0
	local unitDefArrayKeys = {}
	local returnUnitArray = {}
	while unitCount < targetCount do
		if not unitDefArrayKeys[unitDefName] then
			local unitArrayKey = #returnUnitArray + 1
			unitDefArrayKeys[unitDefName] = unitArrayKey
			returnUnitArray[unitArrayKey] = {unitDefName = unitDefName, unitCount = 1}
		else
			local unitArrayKey = unitDefArrayKeys[unitDefName]
			local newUnitCount = returnUnitArray[unitArrayKey].unitCount + 1
			returnUnitArray[unitArrayKey] = {unitDefName = unitDefName, unitCount = newUnitCount}
		end
		unitCount = unitCount + 1
		unitDefName = unitDefNameList[math.random(#unitDefNameList)]
	end
	return returnUnitArray
end


local function GetRandomUnitsFromListForCost(budget,unitDefNameList,multiRandomise)
	local unitDefArrayKeys = {}
	local returnUnitArray = {}
	local excess = 0
	local unitCount = 0
	local shuffledUnitDefNameList = shuffle(unitDefNameList)
	local unitDefName
	local unitCost
	local loopWithHit = true
	while loopWithHit do --while theres at least one unit that may fit into budget we continue
		loopWithHit = false
		for i = 1,  #shuffledUnitDefNameList, 1 do --we walk a shuffled list of all options instead of randomising to try and spend all budget
			unitDefName = shuffledUnitDefNameList[i]
			unitCost = GetCostFromUnitDefName(unitDefName)
			if not multiRandomise and unitCost <= budget then --we found a shuffled unit that fits and spend all budget
				unitCount = math.floor(budget/unitCost)
				returnUnitArray[1] = {unitDefName = unitDefName, unitCount = unitCount}
				excess = budget%unitCost
				return returnUnitArray,excess,unitCount
			elseif unitCost <= budget then -- we found something that fits and add it to return table before looking for another 
			-- TODO There is an argument to randomise here instead of walking the array, but it spends most budget this way
				if not unitDefArrayKeys[unitDefName] then
					local unitArrayKey = #returnUnitArray + 1
					unitDefArrayKeys[unitDefName] = unitArrayKey
					returnUnitArray[unitArrayKey] = {unitDefName = unitDefName, unitCount = 1}
				else
					local unitArrayKey = unitDefArrayKeys[unitDefName]
					local newUnitCount = returnUnitArray[unitArrayKey].unitCount + 1
					returnUnitArray[unitArrayKey] = {unitDefName = unitDefName, unitCount = newUnitCount}
				end
				budget = budget - unitCost
				loopWithHit = true
				unitCount = unitCount + 1
			end
		end
		shuffledUnitDefNameList = shuffle(shuffledUnitDefNameList)
	end
	--[[Spring.Echo(unitDefCountList)
	for key, value in pairs(unitDefCountList) do
		Spring.Echo(key)
		Spring.Echo(value)
	end--]]
	return returnUnitArray,budget,unitCount
end

--[[ 
unitTypeAndRatio should be "scouts"= 2 where 2 is the fraction of the budget allocated on the budget
 so for:{
 	scouts = 2,
	skirmishers = 1,
 } 
	2/3 of the budget goes into scouts
	1/3 goes into skirmishers
A more complex setup would be
{
	{unitGroup = scouts, budgetFraction = 2, minUnits = 1, multiRandomise = true, wreckChance = 0.5},
	{unitGroup = skirmishers, budgetFraction = 1, minUnits =2, multiRandomise = false}
}
returns something akin to 
{ unitDefName = "vehriot",count = 2,wreckChance = 0.5,spacing = 64}
]]
local function CompositionBuilder(budget,unitGroupAndParams,typeList)
	local returnComposition = {}
	local typeComposition = {}
	local budgetTotalFraction = 0
	local excessBudget = 0
	--Spring.Echo(unitTypeAndRatio)
	if not typeList then
		typeList = allUnitGroups
	end
	for index, data in pairs(unitGroupAndParams) do
		local budgetFraction = 1
		if type(data) == "table" and data.unitGroup then
			budgetFraction = data.fraction or budgetFraction
		elseif type(data) == "number" then
			budgetFraction = data or 1
		else
			Spring.Echo("Input of Compositionbuilder in unit_composition_spawner has error")
		end
		if not budgetFraction then
			budgetFraction = 1
		end
		budgetTotalFraction = budgetTotalFraction + budgetFraction
	end
	if budgetTotalFraction <= 0 then
		error("the total budgetfraction ends up 0 or negative")
	end
	--its meh that we loop twice but otherwise we can't get the total Fractions right? I suppose using % would work, but that is more math on the end user
	for index, data in pairs(unitGroupAndParams) do
		local unitGroup = nil
		local budgetFraction = 1
		local multiRandomise = false
		local minUnits = 1
		local wreckChance = 0
		local spacing = 64
		local unitCount
		if type(data) == "table" and data.unitGroup then
			unitGroup = data.unitGroup
			budgetFraction = data.budgetFraction or budgetFraction
			multiRandomise = data.multiRandomise or multiRandomise
			minUnits = data.minUnits or minUnits
			budgetFraction = data.fraction or budgetFraction
			wreckChance = data.wreckChance or wreckChance
			spacing = data.spacing or spacing
		elseif type(data) == "number" then
			unitGroup = index
			budgetFraction = data or 1
		else
			Spring.Echo("Grouping or data of spawning")
		end
		local budgetToSpend = budget*budgetFraction/budgetTotalFraction + excessBudget
		Spring.Echo(unitGroup)
		Spring.Echo(wreckChance)
		typeComposition,excessBudget,unitCount = GetRandomUnitsFromListForCost(budgetToSpend,typeList[unitGroup],multiRandomise)
		for i = 1, #typeComposition, 1 do
			typeComposition[i].wreckChance = wreckChance
		end
		returnComposition = AddUnitLists({returnComposition,typeComposition})
		if unitCount < minUnits then
			local unitsToMin = minUnits - unitCount
			typeComposition = GetRandomUnitsFromListByCount(unitsToMin,typeList[unitGroup],multiRandomise)
			returnComposition = AddUnitLists({returnComposition,typeComposition})
		end
	end
	return returnComposition
end

-- { { unitDefName = "vehriot",count = 2,wreckChance = 0.5,spacing = 64}}
-- alternate queue type {"vehriot" = 2, "cloakassault" = 3}
local function QueueListSpawn(unitDefParamTable,x,z,teamID,noGoZones) --TODO removed global deciders in favor of per unit things
	local spawnedUnits = {}
	local timeToGroundOffset = 5
	local firstSearchSuccess = true
	for index, data in pairs(unitDefParamTable) do -- { 1 ={ unitDefName = "vehriot",count = 2,wreckChance = 0.5,spacing = 64}}
		local unitDefName = nil
		local spawnCount = 1
		local spawnAsWreckChance = 0 --TODO hmm chance vs ratio... I suppose we can have wrecks, and normal units defined, but a chance covers that too
		local spacing = 10
		local dropPod = true
		local spawnPattern = "centered"
		if type(data) == "table" and data.unitDefName then
			unitDefName = data.unitDefName
			spawnCount = data.unitCount or 1
			spawnAsWreckChance = data.wreckChance or spawnAsWreckChance
			spacing = data.spacing or spacing
			dropPod = data.dropPod or dropPod
			spawnPattern = data.spawnPattern or spawnPattern
			--Spring.Echo(unitDefName)
			--Spring.Echo(spawnCount)
		elseif type(data) == "number" then -- alternate queue type {"vehriot" = 2, "cloakassault" = 3}
			unitDefName = index
			spawnCount = data
			--Spring.Echo(unitDefName)
			--Spring.Echo(spawnCount)
		else
			Spring.Echo("type set on queued unit is wrong")
		end
		for i = 1, spawnCount, 1 do
			local unitID = nil
			Spring.MarkerAddPoint(x, 0, z, "SearchStart")
			local localX,localZ,facing,sX,sZ,searchSuccess = GG.NoGoZonesGetValidSpawnPositionForUnit(UnitDefNames[unitDefName].id,{x,z},false,noGoZones)
			if spawnPattern == "centered" and firstSearchSuccess and searchSuccess then
				x,z = localX,localZ --TODO there is a different spawnpattern possible by using the following point for the next spawn start
				firstSearchSuccess = false
			end
			if searchSuccess then
				local localY = Spring.GetGroundHeight(localX, localZ) + 20 -- The offset seems in flavour
				if dropPod then
					--GG.DropUnit(unitDefName, x, y, z, facing, teamID, useSetUnitVelocity, timeToGround, fallGravity, absSpawnHeight, absBrakeHeight, dyncommID, staticDyncommLevel, dynamicCommanderOnly)
					-- TODO mess with till its neat!
					unitID = GG.DropUnit(unitDefName,localX,localY,localZ,facing,teamID,true, 100 + timeToGroundOffset)
				else
					unitID = Spring.CreateUnit(unitDefName,localX,localY,localZ,facing,teamID)
				end
			else
				Spring.Echo("Search for spawnpoint failed")
			end
			if unitID then
				spawnedUnits[unitID] = true
				timeToGroundOffset = timeToGroundOffset + 5
				noGoZones = GG.NoGoZonesAddNoGoZone(localX,localZ,math.max(sX, sZ) + spacing,noGoZones)
				if spawnAsWreckChance == 1 or spawnAsWreckChance > math.random() then
					Spring.CreateUnitWreck(unitID)
					Spring.DestroyUnit(unitID,false,true,nil,true)
				else
					spawnedUnits[unitID] = true
				end
			else
				Spring.echo("Failed to Spawn")
			end
		end
	end
	return spawnedUnits, noGoZones
end

GG.UnitSpawnerAddUnitLists = AddUnitLists
GG.UnitSpawnerGetRandomUnitsFromListForCost = GetRandomUnitsFromListForCost
GG.UnitSpawnerGetRandomUnitsFromListByCount = GetRandomUnitsFromListByCount
GG.UnitSpawnerCompositionBuilder = CompositionBuilder
GG.UnitSpawnerQueueListSpawn = QueueListSpawn