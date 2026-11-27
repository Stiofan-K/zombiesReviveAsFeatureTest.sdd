--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function gadget:GetInfo()
	return {
		name      = "Reinforcement Drops",
		desc      = "Implements Periodic Reinforcement Drops",
		author    = "Stiofan",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local modOptions = Spring.GetModOptions()
local allCompositions = VFS.Include("LuaRules/Configs/unit_compositions.lua")
local reinforceCompositions = allCompositions.reinforceCompositions


-- Team setup
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local REINFORCE_TO_ALL_ID = 99

local GaiaTeamID     = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID, false))
local initalAllianceCount = -1 --subtract gaia
for index, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
	local teamlist = Spring.GetTeamList(allyTeamID)
	if (#teamlist) >0 then
		initalAllianceCount = initalAllianceCount +1
	end
end
local neutralAllyTeamID = nil
local startingNeutralsTeamInput = tonumber(modOptions.reinforcement_drop_team) or 0

if startingNeutralsTeamInput > 0 and startingNeutralsTeamInput <= initalAllianceCount then -- if inbetween 0 and max teamcount, we have a team to spawn on!
	neutralAllyTeamID = startingNeutralsTeamInput -1 -- -1 for offset 
	if neutralAllyTeamID == GaiaAllyTeamID then --TODO there is likely a better solution, it seems sometimes Gaia is not the last team in the list
		neutralAllyTeamID = neutralAllyTeamID + 1
	end
elseif startingNeutralsTeamInput == REINFORCE_TO_ALL_ID then-- anything else translates to no neutrals
	neutralAllyTeamID = REINFORCE_TO_ALL_ID
end

local teamSpawnPosition = {}
local gaiaReinforcements = tonumber(modOptions.reinforce_drop_gaia) or 0
local reinforceBudget =  tonumber(modOptions.reinforce_drop_base) or 0
local reinforceWaveMaxCount = tonumber(modOptions.reinforce_drop_wave_count) or 0
local reinforceBudgetGrowth = tonumber(modOptions.reinforce_drop_growth) or 0
local reinforceGaiaMult = tonumber(modOptions.reinforce_drop_gaia_mult) or 1

local autoReinforceBudget = tonumber(modOptions.reinforcement_drop_auto) or 0
local autoReinforceBudgetMult = tonumber(modOptions.reinforcement_drop_auto_wave_mult) or 4

local waveCount = 0

local AUTO_MAP_CAMP_BASE_MULT = 0.02
local AUTO_MAP_VALUE_BASE_MULT = 0.3 -- flattening the value curve
local AUTO_MAP_VALUE_OFFSET = -1000


local function GetGroupCompositionByBudgetAndType(budget,compositionType)
    if not budget then
        budget = 300
    end
    if not compositionType then
        compositionType = reinforceCompositions
    end
    if (budget < 500) then
        return compositionType.tinyCost[math.random(#compositionType.tinyCost)]
	elseif (budget < 1500) then
        return compositionType.lowCost[math.random(#compositionType.lowCost)]
    elseif (budget < 2000) then
        return compositionType.mediumCost[math.random(#compositionType.mediumCost)]
    elseif (budget < 7500) then
        return compositionType.highCost[math.random(#compositionType.highCost)]
    elseif (budget >= 7500) then
        return compositionType.ludicrousCost[math.random(#compositionType.ludicrousCost)]
    end
    return {assault = 1}
end

local function TeamReinforcements(allyTeamIDInput,budgetInput)
    
    if allyTeamIDInput == REINFORCE_TO_ALL_ID then
        for index, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
            if not allyTeamID == GaiaAllyTeamID and #Spring.GetTeamList(allyTeamID) > 0 then
                TeamReinforcements(allyTeamID,budgetInput)
            end
        end
    end
    --[[
    Spring.Echo("ReinforceCompUnits")
    for key, value in pairs(unitComposition) do
        Spring.Echo(value.unitDefName .." = "..value.unitCount)
    end
    ]]
    local teamIDs = Spring.GetTeamList(allyTeamIDInput)
    local budgetPerPlayer = budgetInput/#teamIDs
    for index, teamID in ipairs(teamIDs) do
        local position = teamSpawnPosition[teamID]
        local x,z = position[1],position[2]
        -- everyone gets their own comps! yay!
        local UnitTypeAndRatios = GetGroupCompositionByBudgetAndType(budgetPerPlayer)
        local unitComposition = GG.UnitSpawnerCompositionBuilder(budgetPerPlayer,UnitTypeAndRatios)
        
        local unitIDs = GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,teamID,nil)
        
        -- TODO queue stop command so that gs and stuff get unstuck
    end
end

--TODO improve the spawning to prefer buildings, then mid
local function GaiaReinforcements(budget)
    local unitComposition = GG.UnitSpawnerCompositionBuilder(budget,GetGroupCompositionByBudgetAndType(budget))
    --[[
    Spring.Echo("GaiaCompUnits")
    for key, value in pairs(unitComposition) do
        Spring.Echo(value.unitDefName .." = "..value.unitCount)
    end
    ]]
    local gaiaUnits = Spring.GetTeamUnits(GaiaTeamID)
    local gaiaBuildings = {}
    if gaiaUnits and #gaiaUnits > 0 then
        for index, unitID in ipairs(gaiaUnits) do
            if UnitDefs[Spring.GetUnitDefID(unitID)].isImmobile then
                gaiaBuildings[unitID] = true
            end
        end
        local unitToSpawnOn = gaiaUnits[math.random(1,#gaiaUnits)]
        if gaiaBuildings and #gaiaBuildings > 0 then -- we prefer buildings to spawn on
            unitToSpawnOn = gaiaUnits[math.random(1,#gaiaBuildings)]
            local x,y,z = Spring.GetUnitBasePosition(unitToSpawnOn)
            -- Sit and wait when spawned on allies
            GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,GaiaTeamID,nil)
            return
        end
        -- Lets not spawn on moving units
        --local x,y,z = Spring.GetUnitBasePosition(unitToSpawnOn)
        -- Sit and wait when spawned on allies
        --GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,GaiaTeamID)
        -- return
    end
    -- move on your own
    local unitIDs, noGoZones = GG.UnitSpawnerQueueListSpawn(unitComposition,mapSizeX/2,mapSizeZ/2,GaiaTeamID)
    for unitID, _ in pairs(unitIDs) do
        GG.Zombies.SetZombieBehavior(unitID)
    end
end


local function HandleReinforcements()
    waveCount = waveCount + 1
    Spring.Echo(reinforceBudget)
    if reinforceBudget > 0 then
        if neutralAllyTeamID then
            TeamReinforcements(neutralAllyTeamID,reinforceBudget)
        end
        if gaiaReinforcements ~= 0 then
            GaiaReinforcements(reinforceBudget*reinforceGaiaMult)
        end
    end
    reinforceBudget = reinforceBudget + reinforceBudgetGrowth
end

--could maybe be improved with mex analysis
local function GuesstimateCampCountAndValueByMapArea(mapArea)

	local campCount = math.ceil(AUTO_MAP_CAMP_BASE_MULT * mapArea)	
	local campValue = math.ceil(AUTO_MAP_VALUE_BASE_MULT * mapArea^2) + AUTO_MAP_VALUE_OFFSET 
	
	return campCount, campValue
end



local function SetupAutoReinforcementBudgets()
	local usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio = GG.MapUtilityGetMapArea()
    
    local count, value = GuesstimateCampCountAndValueByMapArea(usableMapArea)
    
    local waveValue = value/count
    
    reinforceBudget = (reinforceBudget or 0) + waveValue * autoReinforceBudgetMult
    
    reinforceWaveMaxCount = (reinforceWaveMaxCount or 0) + count
end

function gadget:GameFrame(f)
    
    if f == 1 then
        for _, unitID in ipairs(Spring.GetAllUnits()) do
            local teamID = Spring.GetUnitTeam(unitID)
            if teamID ~= GaiaTeamID and not teamSpawnPosition[teamID] then
                local x,y,z = Spring.GetUnitBasePosition(unitID)
                teamSpawnPosition[teamID] = {x,z}
            end
        end
	end
    
	if (f == 90 or f%1800 == 1) and waveCount < reinforceWaveMaxCount and f ~= 1 then -- after 10 sec and then every min
        --Spring.Echo("did we get here")
        HandleReinforcements() 
	end
end

function gadget:Initialize()
    if autoReinforceBudget ~= 0 then
        SetupAutoReinforcementBudgets()
    end
end