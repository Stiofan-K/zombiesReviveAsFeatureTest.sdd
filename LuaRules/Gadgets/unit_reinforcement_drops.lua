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
		layer     = math.huge, -- (I dont know when would be appropriate)
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local modOptions = Spring.GetModOptions()
local GaiaTeamID     = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID, false))
local allUnitGroups = VFS.Include("LuaRules/Configs/unit_class_groupings.lua")
local teamSpawnPosition = {}

local initalAllianceCount = -1 --subtract gaia
	for index, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		local teamlist = Spring.GetTeamList(allyTeamID)
		Spring.Echo(#teamlist)
		if (#teamlist) >0 then
			initalAllianceCount = initalAllianceCount +1
		end
	end
local reinforceAllyTeamID = GaiaAllyTeamID
local reinforceInput = tonumber(modOptions.reinforce_drop_team) or 0
local reinforceBudget =  tonumber(modOptions.reinforce_drop_base) or 0
local reinforceBudgetGrowth = tonumber(modOptions.reinforce_drop_growth) or 200
local gaiaReinforcements = tonumber(modOptions.reinforce_drop_gaia) or 0

if reinforceInput == 0 then -- 0 translates to no Reinforcements or only gaia reinforcements
	reinforceAllyTeamID = GaiaAllyTeamID
elseif reinforceInput > initalAllianceCount then -- larger than teamcount means all Teams receive Reinforcements 
	reinforceAllyTeamID = math.huge
else -- if inbetween 0 and max teamcount, we have a team to spawn on!
	reinforceAllyTeamID = reinforceInput -1 -- -1 for offset 
	if reinforceAllyTeamID == GaiaAllyTeamID then --TODO there is likely a better solution, it seems sometimes Gaia is not the last team in the list
		reinforceAllyTeamID = reinforceAllyTeamID + 1
	end
end

local function CallReinforcements(reinforceAllyTeamID,unitComposition)
    if reinforceAllyTeamID == math.huge then
        for index, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
            local teamlist = Spring.GetTeamList(allyTeamID)
            Spring.Echo(#teamlist)
            if (#teamlist) >0 then
                CallReinforcements(allyTeamID,unitComposition)
            end
        end
        return
    else
        local teamlist = Spring.GetTeamList(reinforceAllyTeamID)
        for teamID, position in pairs(teamSpawnPosition) do
            local x,z = position[1],position[2]
            GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,teamID)
        end
    end
    if gaiaReinforcements ~= 0 then
        local gaiaUnits = Spring.GetTeamUnits(GaiaTeamID)
        if gaiaUnits and #gaiaUnits > 0 then
            Spring.Echo(#gaiaUnits)
            local unitToSpawnOn = gaiaUnits[math.random(1,#gaiaUnits)]
            local x,y,z = Spring.GetUnitBasePosition(unitToSpawnOn)
            --TODO assign zombie behavior
            GG.UnitSpawnerQueueListSpawn(unitComposition,x,z,GaiaTeamID)
        else
            GG.UnitSpawnerQueueListSpawn(unitComposition,mapSizeX/2,mapSizeZ/2,GaiaTeamID)
        end
    end
end

function gadget:GameFrame(f)
    
    if f == 1 then
        for _, unitID in ipairs(Spring.GetAllUnits()) do
            local teamID = Spring.GetUnitTeam(unitID)
            if teamID ~= GaiaTeamID then
                local x,y,z = Spring.GetUnitBasePosition(unitID)
                teamSpawnPosition[teamID] = {x,z}
            end
        end
	end
    
	if f%1800 == 1 and f ~= 1 and reinforceBudget > 0 and reinforceAllyTeamID then
        local unitComposition = GG.UnitSpawnerCompositionBuilder(reinforceBudget,{raiders = 1})
        CallReinforcements(reinforceAllyTeamID,unitComposition)
        reinforceBudget = reinforceBudget + reinforceBudgetGrowth
	end
end