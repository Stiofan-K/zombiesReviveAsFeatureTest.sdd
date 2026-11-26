--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function gadget:GetInfo()
	return {
		name      = "Map Utility functions",
		desc      = "Functions that should help with map related things.",
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
local WATER_DAMAGE = (Game.waterDamage > 0)
local MAP_SIZE_UNIT = 512 --Elmo to lobby mapsize

local STARTBOX_CIRCLE_CHECK_COUNT = 15
local AREA_CHECK_UNIT_DEF_ID = UnitDefNames["energyfusion"].id


local maxStartboxcount -- filled on first occasion
local usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio -- filled on first occasion



-- TODO would this be a useful util function? maybe it already exists :o
local function CheckAnyStartboxOverlap(x,z)
	if not maxStartboxcount then
		maxStartboxcount = Spring.GetGameRulesParam("startbox_max_n")
	end
	for i = 0, maxStartboxcount, 1 do
		if GG.CheckStartbox(i,x,z) then
			--Spring.MarkerAddPoint(x, 0, z, "In startbox!")
			return true
		end
	end
	return false
end

-- TODO would this be a useful util function? maybe it already exists :o
local function CheckAnyCircularStartboxOverlap(x,z,radius,checkDensity)
	if CheckAnyStartboxOverlap(x,z) then
		Spring.MarkerAddPoint(x, 0, z, "In any startbox!")
		return true
	end
	if not checkDensity then
		checkDensity = STARTBOX_CIRCLE_CHECK_COUNT
	end
	local rx,rz
	local degreeIncrement = 360 / checkDensity
	local currentAngle = 0
	while currentAngle <= 360 do
		rx = x + radius * math.cos(currentAngle)
		rz = z - radius * math.sin(currentAngle)
		if CheckAnyStartboxOverlap(rx,rz) then
			Spring.MarkerAddPoint(rx, 0, rz, "Circle check in startbox!")
			return true
		end
		currentAngle = currentAngle + degreeIncrement
	end 
	return false
end


local function CheckLavaOrRoughTerrain(x,z,checkUnitDefID)
	if not checkUnitDefID or not UnitDefs[checkUnitDefID] then
		checkUnitDefID = AREA_CHECK_UNIT_DEF_ID
	end
	local height = Spring.GetGroundHeight(x, z)
	if (WATER_DAMAGE and height <= 0) or 
	(Spring.TestBuildOrder(checkUnitDefID, x, 0 ,z, 0) == 0 and Spring.TestBuildOrder(UnitDefNames["staticmex"].id, x, 0 ,z, 0) == 0) then
		--Spring.MarkerAddPoint(x, 0, z, "not buildable!")
		return true
	end
	return false
end

-- TODO would this be a useful util function?	
--not all map area is useable!
--> we get a ratio of usable map area
--some maps are water maps!
--> we get a ratio of how much of the usable area is water!
--some maps have pretty big startboxes!
--> if startboxes are more than half the usable map, we ignore them from neutral immunity!
local function GuesstimateUsableMapArea(resolution,checkUnitDefID) --optional Params
	if not resolution then
		resolution = 256-- biglag, is there an easier way to do this?
	end
	local mapStepX = mapSizeX/resolution
	local mapStepZ = mapSizeZ/resolution
	local totalArea = mapStepX * mapStepZ
	local usableArea = 0
	local waterArea = 0
	local startBoxArea = 0
	for xMapUnit = 0.5, mapStepX, 1 do
		local x = xMapUnit * resolution
		for zMapUnit = 0.5, mapStepZ, 1 do
			local z = zMapUnit * resolution
			--Spring.MarkerAddPoint(x, 0, z, "buildCheck")
			if CheckLavaOrRoughTerrain(x,z,checkUnitDefID) then
				--Spring.MarkerAddPoint(x, 0, z, "can't build here mylord")
			else
				usableArea = usableArea +1
				local height = Spring.GetGroundHeight(x, z)
				if height <= 0 then
					waterArea = waterArea + 1
				end
				if CheckAnyStartboxOverlap(x,z) then
					startBoxArea = startBoxArea +1
				end
			end
		end
	end
	local waterAreaRatio = waterArea/usableArea
	local startBoxAreaRatio = startBoxArea/usableArea
	local usableMapRatio = usableArea/totalArea
	local usableMapArea = (mapSizeX/MAP_SIZE_UNIT * mapSizeZ/MAP_SIZE_UNIT)*usableMapRatio
	-- maybe there would be a way to determin "hillyness" to filter for spiderness
	return usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio
end

local function GetMapArea()
	if not usableMapArea then
		usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio = GuesstimateUsableMapArea()
		--Spring.Echo(usableMapArea)
	end
	return usableMapArea,usableMapRatio,waterAreaRatio,startBoxAreaRatio
	
end

GG.MapUtilityCheckAnyStartboxOverlap = CheckAnyStartboxOverlap
GG.MapUtilityCheckAnyCircularStartboxOverlap = CheckAnyCircularStartboxOverlap
GG.MapUtilityCheckLavaOrRoughTerrain = CheckLavaOrRoughTerrain
GG.MapUtilityGetMapArea = GetMapArea
GG.MapUtilityGetMapAreaFresh = GuesstimateUsableMapArea