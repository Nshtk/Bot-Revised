MaxSquadSize = 8
OrderRotationPeriod = 120000 -- 2 min; 1000 tic == 1 sec
FlagPriority = {Captured = 1, Enemy = 2, Neutral = 3}
SpecialPoints = 10

-- Work it harder, make it better!

UnitClass = {
	Infantry = "Infantry",
	Vehicle = "Vehicle",
	Tank = "Tank",
	ATTank = "ATTank",
	ATInfantry = "ATInfantry",
	HeavyTank = "HeavyTank",
	Hero = "Hero"
}


function readAllUnits(sq,units,army)
	--local mod_folder_name = "tankspv2"				-- Mod folder name here.

	local path = "resource\\set\\multiplayer\\units\\"	-- Path to units folder. Example: "mods\\"..mod_folder_name.."\\resource\\set\\multiplayer\\units\\"
														-- SET FOLDER MUST NOT BE ARCHIVED! EXTRACT IT TO RESOURCE FOLDER! Maybe this requirment will be removed soon.
	local army = BotApi.Instance.army
	--print(" parsing units for " .. army)

	local sq = path .. "squads.set"	
	readUnitsRaw(sq,units,army)
	local sq = path .. "soldiers.set"
	readUnitsRaw(sq,units,army)	  
	local sq = path .. "vehicles.set"
	readUnitsRaw(sq,units,army)
	local sq = path .. "vehicles_" .. army .. ".set"
	readUnitsRaw(sq,units,army)
	local sq = path .. "vehicles_x.set"
	readUnitsRaw(sq,units,army)
	local sq = path .. "vehicles_xnotanks.set"
	readUnitsRaw(sq,units,army)
	
	--print("Number of units read: ", units.count)
end