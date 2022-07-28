ModFolderName = "1992 a dying world 1.01a"		-- Mod's folder name you want to use this AI with. This folder must contain .set files with faction's units.

-- Work it harder, make it better! Read comments in bot.lua to properly implement mod's features.

FlagStatus = {
	Clear="clear",
	Defended="def",
	DefendedStrong="def_strong",
	Attacked="atk",
	AttackedStrong="atk_strong"
}

function readAllUnits(army)
	local priority_default	= function(priority, results) return priority end
	local order_default		= function(id) orderCaptureFlag(id, getPriorityFlag(BotInfoApi.Players.Me.Flags.points, BotInfoApi.Players.Me.Flags.total_rate), 120000) end -- 2 mins to take flag, 1000 tic == 1 sec
	local purchases={	-- Feel free to add more (or replace) unit classes or flag statuses for your mod and fully customise units behavior.
		-- Generic infantry
		inf_gen 	= {units={}, priority=10,	["getCurrentPriority"]=	function(priority, results)
																			if not results["me_have_enough_inf"] then
																				priority=priority*20
																			end
																			return priority
																		end,
												-- Orders are written in a bit complicated way but there is nothing to be afraid of: just insert e.g. this line [FlagStatus.Clear]={flags={}, total_rate=0} which finds all flags with status "Clear" after comma (see order for Artillery "veh_art") to add flags with status "Clear" to flags to be found. Order of adding statuses matters.
												["setOrder"]=function(id) orderCaptureFlag(id, getSpecialFlag(BotApi.Instance.enemyTeam, {[FlagStatus.Clear]={flags={}, total_rate=0}}), 150000) end},
		-- Anti-tank infantry
		inf_a_tank 	= {units={}, priority=3,	["getCurrentPriority"]=	function(priority, results)
																			if not results["enemy_has_gen_tanks"] then
																				priority=priority+2
																			end
																			return priority
																		end,
												["setOrder"]=order_default},
		-- Generic vehicles
		veh_gen 	= {units={}, priority=3,	["getCurrentPriority"]=	function(priority, results)
																			if BotInfoApi.Players.Me.Flags.neutral>0 then
																				priority=priority+2
																			end
																			return priority
																		end,
												["setOrder"]=function(id) orderCaptureFlag(id, getSpecialFlag(nil, {[FlagStatus.Clear]={flags={}, total_rate=0}}), 80000) end},
		-- Artillery
		veh_art 	= {units={}, priority=2,	["getCurrentPriority"]=priority_default,
												-- Use orderSpecial(id, 3600000) (uncomment function in bot.lua) if you have special artillery (or other special unit class which is handled by special ai scripts) behavior in your mod.
												["setOrder"]=function(id) orderCaptureFlag(id, getSpecialFlag(BotApi.Instance.team, {[FlagStatus.Defended]={flags={}, total_rate=0}, [FlagStatus.Clear]={flags={}, total_rate=0}}), 240000) end}, 
		-- Generic tank
		tank_gen 	= {units={}, priority=3,	["getCurrentPriority"]=priority_default,
												["setOrder"]=order_default},
		-- Tank destroyer
		tank_a_tank	= {units={}, priority=0,	["getCurrentPriority"]=	function(priority, results)
																			if results["enemy_has_gen_tanks"] then
																				priority=priority+3
																			end
																			return priority
																		end,
												["setOrder"]=order_default},
		-- Heavy tank
		tank_heavy 	= {units={}, priority=3,	["getCurrentPriority"]=	function(priority, results)
																			if BotInfoApi.Players.Me.Flags.enemy==0 then
																				priority=priority-2
																			elseif BotInfoApi.Players.Me.Flags.captured<BotInfoApi.Players.Me.Flags.enemy then
																				priority=priority+2
																			end
																			return priority
	 																	end,
												["setOrder"]=function(id) orderCaptureFlag(id, getSpecialFlag(BotApi.Instance.enemyTeam, {[FlagStatus.DefendedStrong]={flags={}, total_rate=0}, [FlagStatus.Defended]={flags={}, total_rate=0}}), 120000) end},
		-- Special point units.
		hero 		= {units={}, priority=5,	["getCurrentPriority"]=priority_default,
												["setOrder"]=order_default}
	}
	
	print("Reading units for: ", army)
	local path="mods\\"..ModFolderName.."\\resource\\set\\multiplayer\\units\\"	-- Path to folder containing files with unit definitions. This folder can be stored directly in Bot Revised directory or in other mod's directory.
	readSetFile(path.."squads.set", 			 purchases, army)				-- THIS FOLDER MUST NOT BE ARCHIVED TO MAKE .SET FILES READABLE!
	readSetFile(path.."vehicles_"..army..".set", purchases, army)

	return purchases
end