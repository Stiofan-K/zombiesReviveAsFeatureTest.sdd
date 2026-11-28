-- compositions defined for the compositionbuilder,
-- bundled in a config file for ease of access and cross gadget sharing


--TODO Compositions for neutrals or anything else really should come with a certain weakness to exploit

-- Lets try another approach

-- cost ranges innate to a group, maybe even a name!
-- class tag and cost tags that describe a compositions function, then I wouldnt need to structure them like this :>
-- types: static, mobile, prefab.
--> we can mix the different types for different results! prefab air base with extra defence, for example
--> could be customisable again, but it may be best to have them just be structured
-- cost brackets: tiny, low, med, high, ludicrous
--> lets instead use hard  metal values?
--> also can be customisable


--TODO GUUUUUUUUH!
local namedAndTaggedCompositions = {
    {compositionType = {"static"}, costBrackets = {"tiny","low"}, composition = {turretLight = 1, ecoLight = 1}},
    {compositionType = {"static"}, costBrackets = {"tiny","low"}, composition = {turretRiot = 1,turretLight = 0.5, ecoLight = 0.5}},
    {compositionType = {"static"}, costBrackets = {"tiny","low"}, composition = {turretAALight = 1,turretLight = 1, ecoLight = 0.5}},
    {factoryPlate = 1, turretLight =1},
    {factoryPlate = 1, turretLight =1, ecoLight = 0.5},
    {turretLight =1, ecoLight = 0.5, ecoSupport = 0.5},
    
    
}


-- Basic idea, point of interest + static + mobile -> one camp.
--> mobiles contain all sort of units.
--> statics contain economy and turrets.
---> what if I.. just pile all turrets and such into a category?
--> the ratio of each can be adjusted on the fly, but the point of interest should be the vocal point, likely half the budget or more.
--> prefabs are akin to points of interest that come with a predefined camp composition surrounding them.

--> I should completely avoid using direct assignments, so that the compositions can be reused for chickens for

--> I will likely need help in making a good system. I do just want to finish this for now.
--> So i will just hardcode some points of interests for cost brackets and make individual static and mobile comps more foilable.

--> good poi are, radars -> storage/pylon/caretaker -> shields/jammers -> factories/heavyTurret? -> staticStrategic
--> PW has some structures that fit nicely/could be an upscale of the lower tier PoI
--> it seems fair to have a 4 cluster of PW buildings being relatively weakly guarded.
--> chickens becomes an issue if I hardcode it however... Maybe adjusting cost is a smart idea?


local allCompositions = {
    
    neutralCamps = {
        -- core
        pointsOfInterest = {
            tinyCost = { -- less than 500 cost
               {{classGroup = "radar", budgetFraction = 0, minUnits = 1},ecoSupport = 2, factoryPlate = 0.2,ecoLight = 1},
               --{factoryPlate = 1,{classGroup = "staticRadar", budgetFraction = 0, minUnits = 1}}
            },
            lowCost = { -- less than 1000 cost
                {{classGroup = "striderDemi", budgetFraction = 0, minUnits = 1, wreckChance = 1},factory = 3,ecoSupport = 1, ecoLight = 1},
                {{classGroup = "striderMedium", budgetFraction = 0, minUnits = 1, wreckChance = 1},staticSupport = 1,ecoSupport = 1, ecoLight = 1}
            },
            mediumCost = { --less than 3000 cost
                {{classGroup = "ecoSupport",sectionGroups = {"planetWars"}, spacing = 0, multiRandomise = false},factory = 1,ecoSupport = 1, ecoLight = 0.5},
                {{classGroup = "staticSupport",sectionGroups = {"planetWars"},budgetFraction = 0.5,},factory = 1,ecoSupport = 1,ecoLight = 0.5},
                {{classGroup = "staticSupport",sectionGroups = {"planetWars"},},{classGroup = "ecoSupport",sectionGroups = {"planetWars"},spacing = 0,},factory = 1,ecoSupport = 1, ecoLight = 0.5},
                {ecoHeavy = 1 ,factory = 1,ecoSupport = 0.5,ecoLight = 0.5},
                {{classGroup = "ecoSupport",sectionGroups = {"planetWars"}, spacing = 0, multiRandomise = false}, turretaaheavy = 3,ecoSupport = 1, ecoLight = 0.5},
                {{classGroup = "factoryplane", minUnits = 1},pw_bomberfac = 1, {classGroup = "staticrearm",budgetFraction = 2, spacing = 0},bomberLight = 3, ecoLight = 0.5},
                {staticStrategic = 1,ecoHeavy = 1 ,{classGroup = "ecoSupport",sectionGroups = {"planetWars"}},factory = 1,turretsHeavy = 1,ecoSupport = 0.5, ecoLight = 0.5},
            },
            highCost = { -- less than 7500 cost
                {{classGroup = "ecoSupport",sectionGroups = {"planetWars"}, spacing = 0,},ecoHeavy = 1 ,factory = 1,turretsHeavy = 1,ecoSupport = 0.5,},
                {staticStrategic = 1,{classGroup = "staticSupport",sectionGroups = {"planetWars"}},ecoHeavy = 1 ,factory = 1,turretsHeavy = 1,ecoSupport = 0.5,},
                {staticStrategic = 1,{classGroup = "ecoSupport",sectionGroups = {"planetWars"}},ecoHeavy = 1 ,factory = 1,turretsHeavy = 1,ecoSupport = 0.5,},
                {ecoHeavy = 1 ,factory = 1,turretsHeavy = 2,ecoSupport = 0.5,ecoLight = 0.5},
            },
            ludicrousCost = {-- 7500 or more
                {{classGroup = "ecoSupport",sectionGroups = {"planetWars"}},ecoHeavy = 1 ,factory = 1,turretsHeavy = 1,ecoSupport = 0.5,},
                {{classGroup = "staticSupport",sectionGroups = {"planetWars"}},ecoHeavy = 1 ,factory = 1,turretsHeavy = 1,ecoSupport = 0.5,},
                {staticStrategic = 1,{classGroup = "ecoSupport",sectionGroups = {"planetWars"}},ecoHeavy = 1 ,factory = 1,turretsHeavy = 1,ecoSupport = 0.5,},
                {ecoHeavy = 1 ,factory = 1,turretsHeavy = 2,ecoSupport = 0.5,ecoLight = 0.5},
            },
        }, 
        -- only statics
        staticCompositions = {
            tinyCost = { -- less than 500 cost, a few light defences and eco structures
                {turretLight = 1, ecoLight = 1},
                {turretRiot = 1,turretLight = 1, ecoLight = 0.5},
                {turretLight = 1},
                {turretLight = 1, ecoLight = 0.5},
                {turretLight = 1, ecoLight = 0.5, ecoSupport = 0.5},
            },
            lowCost = { -- less than 1000 cost, riot turrets, maybe a factory, no skirmsher turrets yet, light aa
                {turretRiot = 1,turretLight = 1, ecoLight = 1,},
                {turretLight =3, ecoLight = 3, ecoSupport = 1},
                {turretRiot = 1,turretLight = 3, ecoLight = 1, staticSupprt = 1},
                {turretRiot = 1,turretLight = 3, ecoLight = 2, ecoSupport = 1},
                {turretRiot = 1,turretLight = 3, ecoLight = 2, turretAALight = 1},
                {turretLight = 3, ecoLight = 2, turretAALight = 1}
            },
            mediumCost = { --less than 3000 cost, turrets skirm may struggle with, maybe a fusion or so tossed in
                {turretLight =1,ecoLight =1, turretAALight = 1, ecoSupport = 1, turretRiot = 1,},
                {ecoHeavy = 1,turretLight =1, ecoSupport = 3,  turretRiot = 1, turretAALight = 1,{classGroup = "staticSupport", budgetFraction = 0, minUnits = 1,}},
                {turretSkirm = 1, ecoLight =2, ecoSupport = 1, turretAALight = 1, factoryPlate = 0.2,},
                {turretSkirm = 1, turretLight =3, ecoLight =1, ecoSupport = 1, turretAALight = 1, factoryPlate = 0.2,},
                {turretSkirm = 1, turretRiot = 3,ecoLight =1, ecoSupport = 1, turretAALight = 1,},
                {ecoHeavy = 1, turretsHeavy = 1, ecoLight = 2, ecoSupport= 0.3,}
            },
            highCost = { -- less than 7500 cost, a relatively developed base, turrets, factory, caretakers, maybe a desolator, big AA?
                {ecoHeavy = 1,turretsHeavy = 1,turretSkirm = 1, ecoSupport = 0.5, turretLight =1, turretRiot = 1, {classGroup = "staticSupport", budgetFraction = 0, minUnits = 1,},ecoLight = 1,factory = 0.5,},
                {ecoHeavy = 1,turretsHeavy = 1,turretSkirm = 1, ecoSupport = 0.5, ecoLight = 2, factory = 0.5,turretLight =1, turretRiot = 1, {classGroup = "staticSupport", budgetFraction = 0, minUnits = 1,}, },
                {ecoHeavy = 1, staticStrategic = 1, turretRiot =1, ecoSupport = 0.5, turretSkirm =1,ecoLight = 2, factoryPlate = 0.05, factory = 0.5,}
            },
            ludicrousCost = {-- 7500 or more, anything goes! but we may want another tier
                {super = 1, turretsHeavy = 1, ecoHeavy = 1, staticStrategic = 1, turretRiot =1, turretSkirm =1,ecoLight = 0.5, factoryPlate = 0.05, factory = 0.1, ecoSupport = 0.3,energypylon = 0.1}
            }
        },
        --Only Mobiles
        mobileCompositions = {
            tinyCost = { -- less than 500 cost, small groups or single units
                {scout = 1},
                {raider = 1},
                {riot = 1},
                {skirm = 1},
                {bomb = 1},
                {assault = 1},
                {drone = 0.1,raider = 1},--unsure about drone...
                {scout = 1,raider = 1}
            },
            lowCost = { -- less than 1000 cost, light compositions, raider riot skirms and assault, and maybe support tools
                {raider = 1,skirm = 1},
                {raider = 1,riot = 1},
                {riot = 1,skirm = 1},
                {riot = 1,assault = 1},
                {assault = 1,raider = 1},
                {assault = 1,skirm = 1,},
                {assault = 1,bomb = 0.2,},
                {transport = 0.3,raider = 1},
                {drone = 0.3,riot = 1}, --unsure about drone...
            },
            mediumCost = { --less than 3000 cost, start for demis aswell as larger compositions with some support tools
                {constructor = 0.1,assault = 1,skirm = 1,},
                {assault = 1, riot = 1,},
                {assault = 1,artillery = 1,scout = 0.1,},
                {raider = 1,artillery = 1,},
                {antiSub = 1, artillery = 1,raider = 1},
                {gunship = 1,skirm = 1},
                {bomberLight = 1,raider = 1,assault = 1},
                {striderDemi = 1,antiAir = 0.5,raider=0.5},
                {riot = 1, transport = 0.5,},
                {antiHeavy = 1,raider = 1},
                {aerialAA = 1, raider = 0.5, riot = 1}
            },
            highCost = { -- less than 7500 cost, demis and some light striders and big army comps
                {assault = 1,artillery = 1,raider = 0.5,},
                {striderDemi = 1,raider = 0.2,aerialAA = 1,},
                {striderDemi = 1,antiSub = 0.5,riot = 1},
                {aerialAA = 1,bomberLight = 1, assault = 1},
                {bomberHeavy = 1,striderDemi = 1,antiSub = 0.5,},
                {striderMedium = 1,skirm =1,{classGroup = "support", budgetFraction = 0, minUnits = 1,},},
                {striderDemi = 1,assault = 1,skirm =1,},
                {antiHeavy = 1,assault = 1,artillery = 1,raider = 0.5,}
            },
            ludicrousCost = {-- 7500 or more, anything goes! but we may want another tier
                {antiHeavy = 1,assault = 1,artillery = 1,raider = 0.5,constructor = 0.1,skirm = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
                {stirderDemi = 1,assault = 1,artillery = 1,raider = 0.5,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
                {striderDemi = 1,bomberHeavy = 1,aerialAA = 1,constructor = 0.1,assault = 1,skirm = 1,},
                {striderMedium = 3,assault = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
                {striderMedium = 1,striderDemi = 1,antiAir = 0.5,raider=0.5,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
                {striderDemi = 1,aerialAA = 1,constructor = 0.1,assault = 1,skirm = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
                {striderHeavy = 1, striderMedium = 1,aerialAA = 1,constructor = 0.1,assault = 1,skirm = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}}
            }
        }
    },
    reinforceCompositions = {
        tinyCost = { -- less than 500 cost, small groups or single units
            {scout = 1},
            {raider = 1},
            {riot = 1},
            {skirm = 1},
            {bomb = 1},
            {assault = 1},
            {drone = 0.1,raider = 1},--unsure about drone...
            {scout = 1,raider = 1}
        },
        lowCost = { -- less than 1000 cost, light compositions, raider riot skirms and assault, and maybe support tools
            {raider = 1,skirm = 1},
            {raider = 1,riot = 1},
            {riot = 1,skirm = 1},
            {riot = 1,assault = 1},
            {assault = 1,raider = 1},
            {assault = 1,skirm = 1,},
            {assault = 1,bomb = 0.2,},
            {transport = 0.3,raider = 1},
            {drone = 0.3,riot = 1}, --unsure about drone...
        },
        mediumCost = { --less than 3000 cost, start for demis aswell as larger compositions with some support tools
            {constructor = 0.1,assault = 1,skirm = 1,},
            {assault = 1, riot = 1,},
            {assault = 1,artillery = 1,scout = 0.1,},
            {raider = 1,artillery = 1,},
            {antiSub = 1, artillery = 1,raider = 1},
            {gunship = 1,skirm = 1},
            {bomberLight = 1,raider = 1,assault = 1},
            {striderDemi = 1,antiAir = 0.5,raider=0.5},
            {riot = 1, transport = 0.5,},
            {antiHeavy = 1,raider = 1},
            {aerialAA = 1, raider = 0.5, riot = 1},
            
            --bucky comps:
            {vehsupport=15, riot=8, amphsupport=5, amphcon=2},
            {shieldassault=40, riot=20, skirm=20, aa=10, shieldshield=4},
            {arty=20, riot=8, planescout=1, planelightscout=1, constructor=2},
            {turretheavylaser=20, turretriot=10, turretlaser=5, cloakbomb=20, scout=1},
            {vehcapture=20, spideremp=20, spideraa=5, cloakcon=2}
            
        },
        highCost = { -- less than 7500 cost, demis and some light striders and big army comps
            {assault = 1,artillery = 1,raider = 0.5,},
            {striderDemi = 1,raider = 0.2,aerialAA = 1,},
            {striderDemi = 1,antiSub = 0.5,riot = 1},
            {aerialAA = 1,bomberLight = 1, assault = 1},
            {bomberHeavy = 1,striderDemi = 1,antiSub = 0.5,},
            {striderMedium = 1,skirm =1,{classGroup = "support", budgetFraction = 0, minUnits = 1,},},
            {striderDemi = 1,assault = 1,skirm =1,},
            {antiHeavy = 1,assault = 1,artillery = 1,raider = 0.5,},
            
            --bucky comps:
            {vehsupport=15, riot=8, amphsupport=5, amphcon=2},
            {shieldassault=40, riot=20, skirm=20, aa=10, shieldshield=4},
            {arty=20, riot=8, planescout=1, planelightscout=1, constructor=2},
            {turretheavylaser=20, turretriot=10, turretlaser=5, cloakbomb=20, scout=1},
            {vehcapture=20, spideremp=20, spideraa=5, cloakcon=2}
        },
        ludicrousCost = {-- 7500 or more, anything goes! but we may want another tier
            {antiHeavy = 1,assault = 1,artillery = 1,raider = 0.5,constructor = 0.1,skirm = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
            {stirderDemi = 1,assault = 1,artillery = 1,raider = 0.5,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
            {striderDemi = 1,bomberHeavy = 1,aerialAA = 1,constructor = 0.1,assault = 1,skirm = 1,},
            {striderMedium = 3,assault = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
            {striderMedium = 1,striderDemi = 1,antiAir = 0.5,raider=0.5,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
            {striderDemi = 1,aerialAA = 1,constructor = 0.1,assault = 1,skirm = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}},
            {striderHeavy = 1, striderMedium = 1,aerialAA = 1,constructor = 0.1,assault = 1,skirm = 1,{classGroup = "support", budgetFraction = 0, minUnits = 1,}}
        }
    }
}

return allCompositions
-- TODO sort these in/figure a better way of allocating to cost
--[[ --buckycomps! 
{vehsupport=15, riot=8, amphsupport=5, energysolar=4, energywind=2, amphcon=2},
{shieldassault=40, riot=20, skirm=20, aa=10, shieldshield=4, staticradar=2, energysolar=1},
{arty=20, riot=8, planescout=6, planelightscout=4, energysolar=4, constructor=2},
{turretheavylaser=20, turretriot=10, turretlaser=5, cloakbomb=20, scout=1},
{vehcapture=20, spideremp=20, spideraa=5, turretemp=4, energysolar=2, energywind=2, cloakcon=2}
{gunshipskirm=10, bomberprec=10, bomberemp=6, energysolar=6, energyfusion=4, staticrearm=3, turretlaser=2, staticcon=2, staticstorage=1},
{napalmmissile=250, empmissile=250, staticradar=10, scout=10, energysolar=5} 

{vehsupport=15, riot=8, amphsupport=5, amphcon=2},
{shieldassault=40, riot=20, skirm=20, aa=10, shieldshield=4},
{arty=20, riot=8, planescout=1, planelightscout=1, constructor=2},
{turretheavylaser=20, turretriot=10, turretlaser=5, cloakbomb=20, scout=1},
{vehcapture=20, spideremp=20, spideraa=5, cloakcon=2}
{gunshipskirm=10, bomberprec=10, bomberemp=6},
{napalmmissile=250, empmissile=250, staticradar=10, scout=10, energysolar=5} 


]]


-- some thoughts on mixed compositions
--[[
local mobileCamps = {
	{
		ecoLight = 1,
		turretRiot = 0.1,
		raider = 2,
		scout = 3,
	},
	{
		ecoLight = 1,
		turretAALight = 0.1,
		riot = 2,
		skirm = 2,
	},
	{
		ecoLight = 1,
		turretLight = 0.1,
		assault = 2,
		riot = 1,
	},
	{
		ecoLight = 1,
		turretLight = 0.1,
		assault = 1,
		gunship = 1,
	}
}

local staticCamps = {
	{
		pwSupport = 1,
		ecoLight = 0.5,
		ecoSupport = 0.5,
		turretRiot = 1,
		turretAALight = 0.5,
		turretLight = 1
	},
	{
		pwGreebles = 1,
		ecoLight = 0.5,
		ecoSupport = 0.5,
		turretRiot = 1,
		turretAALight = 0.5,
		turretLight = 1
	},
	{
		pwSupport = 1,
		pwGreebles = 1,
		ecoSupport = 0.1,
		turretRiot = 1,
		turretAALight = 0.5,
		turretLight = 1
	},
	{
		factory = 1,
		pwGreebles = 1,
		ecoSupport = 0.1,
		turretRiot = 1,
		turretAALight = 0.5,
		turretLight = 1
	}
}
local largeCamp = {
	pwSupport = 1,
	pwGreebles = 1,
	ecoSupport = 1,
	pwDefence = 1,
	turretRiot = 1,
	turretAALight = 1,
	turretLight = 1,
	artillery = 1,
}
]]