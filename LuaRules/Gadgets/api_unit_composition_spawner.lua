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
-- adds 2 tables together!
local function AddUnitLists(tableList)
	local returnList = {}
	for index, table in ipairs(tableList) do
		for unitDefNames, value in pairs(table) do
			if returnList[unitDefNames] then
				returnList[unitDefNames] = returnList[unitDefNames]+ value
			else
				returnList[unitDefNames] = value
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



local function GetRandomUnitsFromListForCost(budget,unitDefNameList,multiRandomise)
	--Spring.Echo(unitDefNameList)
	local spentBudget = 0
	local unitDefCountList = {}
	local unitDefName = unitDefNameList[math.random(1,#unitDefNameList)]
	local unitCost = GetCostFromUnitDefName(unitDefName)
	while budget >= spentBudget do
		if unitDefCountList[unitDefName] then
			unitDefCountList[unitDefName] = unitDefCountList[unitDefName] + 1
		else
			unitDefCountList[unitDefName] = 1
		end
		
		spentBudget = spentBudget + unitCost
		if multiRandomise then
			unitDefName = unitDefNameList[math.random(1,#unitDefNameList)]
			unitCost = GetCostFromUnitDefName(unitDefName)
		end
	end
	return unitDefCountList
end

--[[ 
--TODO add count, multi random, wreckchance, Spawnpattern? and overflowspawn to the parameters
unitTypeAndRatio should be "scouts"= 2 where 2 is the fraction of the budget allocated on the budget
 so for:{
 	scouts = 2,
	skirmishers = 1,
 } 
	2/3 of the budget goes into scouts
	1/3 goes into skirmishers
]]
local function CompositionBuilder(budget,unitTypeAndRatio, multiRandomise,typeList)
	local returnComposition = {}
	local budgetTotalFraction = 0
	--Spring.Echo(unitTypeAndRatio)
	if not typeList then
		typeList = allUnitGroups
	end
	
	Spring.Echo(unitTypeAndRatio)
	for unitCatergoryList, budgetRatio in pairs(unitTypeAndRatio) do
		if not budgetRatio then
			budgetRatio = 1
		end
		budgetTotalFraction = budgetTotalFraction + budgetRatio
	end
	if budgetTotalFraction <= 0 then
		error("the total budgetfraction ends up 0 or negative")
	end
	--bleh that we loop twice but otherwise we can't get the total right?
	for unitCatergoryList, budgetRatio in pairs(unitTypeAndRatio) do
		local budgetToSpend = budget*budgetRatio/budgetTotalFraction
		returnComposition = AddUnitLists({returnComposition,GetRandomUnitsFromListForCost(budgetToSpend,typeList[unitCatergoryList],multiRandomise)})
	end
	return returnComposition
end

-- unitDefAndCount defined as {"vehriot" = 2} for example
local function QueueListSpawn(unitDefAndCount,x,z,teamID,spawnAsWreck,noDropPod,spacing,noGoZones)
	local spawnedUnits = {}
	local y = Spring.GetGroundHeight(x, z) + 20
	local facing = 1
	local noGoZones = nil
	local timeToGroundOffset = 5
	local firstSearchSuccess = true
	if not spacing then
		spacing = 0
	end
	for unitDefName, count in pairs(unitDefAndCount) do
		for i = 1, count, 1 do
			local localX,localZ,facing,sX,sZ,searchSuccess = GG.NoGoZonesGetValidSpawnPositionForUnit(UnitDefNames[unitDefName].id,{x,z},true,noGoZones)
			if firstSearchSuccess and searchSuccess then
				x,z = localX,localZ --TODO there is a different spawnpattern possible by using the following point for the next spawn start
				firstSearchSuccess = false
			end
			local localY=Spring.GetGroundHeight(localX, localZ) + 20
			local unitID = nil
			if noDropPod then
				unitID = Spring.CreateUnit(unitDefName,localX,localY,localZ,facing,teamID)
			else
				--GG.DropUnit(unitDefName, x, y, z, facing, teamID, useSetUnitVelocity, timeToGround, fallGravity, absSpawnHeight, absBrakeHeight, dyncommID, staticDyncommLevel, dynamicCommanderOnly)
				-- TODO mess with till its neat!
				unitID = GG.DropUnit(unitDefName,localX,localY,localZ,facing,teamID,true, 100 + timeToGroundOffset)
			end
			if unitID then
				spawnedUnits[unitID] = true
				timeToGroundOffset = timeToGroundOffset + 5
				noGoZones = GG.NoGoZonesAddNoGoZone(localX,localZ,math.max(sX, sZ) + spacing,noGoZones)
				if spawnAsWreck then
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
GG.UnitSpawnerCompositionBuilder = CompositionBuilder
GG.UnitSpawnerQueueListSpawn = QueueListSpawn