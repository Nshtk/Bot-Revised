ModFolderName = "bot revised"			-- Mod folder name.
MaxSquadSize = 10	
SpecialPoints = 15

-- Work it harder, make it better! Read comments in bot.lua to properly implement mod's features.

UnitClass = {							-- Feel free to add more (or replace) unit classes or flag statuses for your mod and fully customise units behavior.
	InfantryGen   = "inf_gen",
	InfantryATank = "inf_a_tank",

	VehicleGen    = "veh_gen",
	VehicleArt 	  = "veh_art",

	TankGen 	  = "tank_gen",
	TankATank     = "tank_a_tank",
	TankHeavy  	  = "tank_heavy",

	Hero 	   	  = "hero"
}

FlagStatus = {
	Clear="clear",
	Defended="def",
	DefendedStrong="def_strong",
	Attacked="atk",				
	AttackedStrong="atk_strong"
}

function readAllUnits(army)
	local path=nil
	local purchases={}

	purchases[UnitClass.InfantryGen]   = {units={}, priority=10}
	purchases[UnitClass.InfantryATank] = {units={}, priority=3}

	purchases[UnitClass.VehicleGen]    = {units={}, priority=3}
	purchases[UnitClass.VehicleArt]    = {units={}, priority=2}

	purchases[UnitClass.TankGen]  	   = {units={}, priority=3}
	purchases[UnitClass.TankATank]     = {units={}, priority=0}
	purchases[UnitClass.TankHeavy]     = {units={}, priority=3}

	purchases[UnitClass.Hero] 		   = {units={}, priority=5}
	
	print("Reading units for: "..army)
	path = "mods\\"..ModFolderName.."\\resource\\set\\multiplayer\\units\\"		-- Path to "units" folder. This folder can be stored directly in Bot Revised directory or in other mod's directory.
	readSetFile(path.."squads.set", 			 purchases, army)				-- "UNITS" FOLDER MUST NOT BE ARCHIVED!
	readSetFile(path.."vehicles_"..army..".set", purchases, army)

	return purchases
end