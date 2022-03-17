require([[/script/multiplayer/bot.data]])

-- If something is wrong in here, feel free to tell me about it.

function clearTable(t)
	for k, v in pairs(t) do
		t[k]=nil
	end
end

--=====================================TeamApi=======================================

TeamApi={
    Count=nil
}

function TeamApi:createClassTables()
    self.Instances={}
    self.Units={}
    self.Flags={}
end

function TeamApi:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    o:createClassTables()
    return o
end

function TeamApi:calculateTeamSize()
    local n=#self.Instances
    self.Count=n
    return n
end

function TeamApi:receiveUnitInfo()
	clearTable(self.Units)
    for k, instance in pairs(self.Instances) do
    	instance.File:seek("set", 0)
        for line in instance.File:lines() do
            local properties, i = {}, 1
            for p in string.gmatch(line, "([^%s]+)") do
                properties[i]=p
                i=i+1
            end
            table.insert(self.Units, {id=properties[1], class=properties[2], name=properties[3], cost=properties[4], wait_at_quant=properties[5], flag=properties[6]})
        end
    end
end

function haveUnit(units, property, count, ...)				-- Yeah, i know it's ugly and it violates the encapsulation policy, but this solution is better than duplication of that function.
    local arg={...}
    if property=="class" or property=="name" then
    	for i, unit in pairs(units) do
        	for j, parameter in pairs(arg) do
            	if unit[property]:find(parameter) then
            		count=count-1
            		if count==0 then
            			return true
            		end
            	end
        	end
    	end
    else
    	for i, unit in pairs(units) do
        	for j, parameter in pairs(arg) do
            	if unit[property]>=parameter then
            		count=count-1
            		if count==0 then
            			return true
            		end
            	end
        	end
    	end
	end
    return false
end

function TeamApi:closeFiles()
	for i, player in pairs(self.Instances) do
		player.File:close()
	end
end

EnemyTeam={}
MyTeam={}
setmetatable(EnemyTeam, {__index = TeamApi}) 
setmetatable(MyTeam, {__index = TeamApi})

function EnemyTeam:getFlagUnits(flags)
	for i, unit in pairs(self.Units) do
		if unit.flag~="n" then
			--table.insert(flags[unit.flag].squads_enemy.units, unit)		-- You can enable these lines to get units on flags to use them in "factors" (see below), or whatever you want. Lines are disabled here because of not utilising their potential.
			flags[unit.flag].squads_enemy.count=flags[unit.flag].squads_enemy.count+1
		end
	end
end

function MyTeam:getFlagUnits(flags, units)
	for i, unit in pairs(units) do
		if unit.flag~="n" then
			--table.insert(flags[unit.flag].squads_team.units, unit)
			flags[unit.flag].squads_team.count=flags[unit.flag].squads_team.count+1
		end
	end
end

--=====================================ContextApi=======================================

Context={
    Instance={File=nil, Id=nil, Army=nil},
    Purchases={},
	SpawnInfo=nil,
	SpawnBuffer={units={}, count=0, pointer=1},
	TimedUnits={},
	SceneUnits={},
	Flags={points={}, captured=nil, enemy=nil, neutral=nil, count=0, total_rate=1},
	Utility={FilePath=nil}
}

function Context:addSceneUnit(id, unit)
	if unit==nil then
		return false
	end
	self.SceneUnits[id]={class=unit.class, name=unit.name, cost=unit.cost, wait_at_quant=unit.wait_at_quant, flag=unit.flag, timer=unit.timer} -- self.SceneUnits[id]=unit creates unit's member values as references!
	return true
end

function Context:sendSceneUnits()
	self.Instance.File:close()
	self.Instance.File=io.open(self.Utility.FilePath, "w")
	self.Instance.File:setvbuf("no")

	for id, unit in pairs(self.SceneUnits) do
		if BotApi.Scene:IsSquadExists(id) then
			self.Instance.File:write(id, " ", unit.class, " ", unit.name, " ", unit.cost, " ", unit.wait_at_quant, " ", unit.flag, "\n")
		else
			if unit.timer then
				BotApi.Events:KillQuantTimer(unit.timer)
			end
			self.SceneUnits[id]=nil
		end
	end
end

function Context:addTimedUnit(unit)
	BotInfoApi.Players.Me.TimedUnits[unit.group]=BotApi.Events:SetQuantTimer(function() BotInfoApi.Players.Me.TimedUnits[unit.group]=nil end, unit.charge*1000)
end

function Context:isTimedUnit(group)
	if BotInfoApi.Players.Me.TimedUnits[group]~=nil then
		return true
	end
	return false
end

function Context:initFlags()
	for i, flag in pairs(BotApi.Scene.Flags) do
		self.Flags.points[flag.name]={}
		self.Flags.points[flag.name].occupant=nil
		self.Flags.points[flag.name].status=nil
		self.Flags.points[flag.name].priority=nil
		self.Flags.points[flag.name].squads_enemy={units={}, count=nil}
		self.Flags.points[flag.name].squads_team={units={}, count=nil}
		self.Flags.count=self.Flags.count+1
	end
end

function Context:updateFlagPriorities()
	local team_my=BotApi.Instance.team
	local team_enemy=BotApi.Instance.enemyTeam

	for name, flag in pairs(self.Flags.points) do 				--I think it's more performance efficient way than iterating through the same units many times.
		clearTable(flag.squads_enemy.units)
		clearTable(flag.squads_team.units)
		flag.squads_enemy.count=0
		flag.squads_team.count=0
	end

	BotInfoApi.Players.Enemy:getFlagUnits(self.Flags.points)
	BotInfoApi.Players.Team:getFlagUnits(self.Flags.points, BotInfoApi.Players.Team.Units)
	BotInfoApi.Players.Team:getFlagUnits(self.Flags.points, self.SceneUnits)
	self.Flags.total_rate=1
	self.Flags.captured=0; self.Flags.enemy=0; self.Flags.neutral=0
	for i, flag in pairs(BotApi.Scene.Flags) do
		local ratio=self.Flags.points[flag.name].squads_enemy.count-self.Flags.points[flag.name].squads_team.count
		if flag.occupant == team_my then self.Flags.captured = self.Flags.captured+1
			self.Flags.points[flag.name].priority=5
			if ratio>2 then
				self.Flags.points[flag.name].status=FlagStatus.AttackedStrong
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority+10
			elseif ratio>0 then
				self.Flags.points[flag.name].status=FlagStatus.Attacked
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority+5
			elseif ratio<0 then
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority+ratio
				self.Flags.points[flag.name].status=FlagStatus.Defended
			else
				self.Flags.points[flag.name].status=FlagStatus.Clear
			end
		elseif flag.occupant == team_enemy then self.Flags.enemy = self.Flags.enemy+1
			self.Flags.points[flag.name].priority=10
			if ratio>2 then
				self.Flags.points[flag.name].status=FlagStatus.DefendedStrong
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority-ratio
			elseif ratio>0 then
				self.Flags.points[flag.name].status=FlagStatus.Defended
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority
			elseif self.Flags.points[flag.name].squads_team.count>1 then
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority+10
				self.Flags.points[flag.name].status=FlagStatus.Attacked
			else
				self.Flags.points[flag.name].status=FlagStatus.Clear
			end
		else self.Flags.neutral = self.Flags.neutral+1
			self.Flags.points[flag.name].priority=10
			if ratio~=0 then
				self.Flags.points[flag.name].status=FlagStatus.Defended
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority-ratio*2
			else
				self.Flags.points[flag.name].status=FlagStatus.Clear
				self.Flags.points[flag.name].priority=self.Flags.points[flag.name].priority*2
			end
		end
		if self.Flags.points[flag.name].priority<1 then
			self.Flags.points[flag.name].priority=1
		end
		self.Flags.total_rate=self.Flags.total_rate+self.Flags.points[flag.name].priority
		self.Flags.points[flag.name].occupant=flag.occupant
	end
end

--=====================================BotInfoApi=======================================

BotInfoApi={
    Path="mods\\bot revised\\resource\\script\\multiplayer\\bot_info\\",
    Players={Enemy=EnemyTeam:new(nil), Team=MyTeam:new(nil), Me=Context, Count=nil}
}

function BotInfoApi:calculatePlayerCount()
    self.Players.Count=self.Players.Team:calculateTeamSize()+self.Players.Enemy:calculateTeamSize()+1
end

function BotInfoApi:initialize()
	local team_my=BotApi.Instance.team
	local team_enemy=BotApi.Instance.enemyTeam
	local id_my=BotApi.Instance.playerId
	local army_my=BotApi.Instance.army

	local path = self.Path
	local dir_content = io.popen("dir \""..path.."\" /b")

	self.Players.Me.Utility.FilePath=path..team_my..tostring(id_my)..army_my
	self.Players.Me.Instance.File=io.open(self.Players.Me.Utility.FilePath, "w")
	self.Players.Me.Instance.Id=id_my
	self.Players.Me.Instance.Army=BotApi.Instance.army
	self.Players.Me:initFlags()
	self.Players.Me:updateFlagPriorities()

	local id_tmp
	local id_pattern="%d+"
	local army_pattern="%a%a%w+"
	team_my=team_my..id_pattern
	team_enemy=team_enemy..id_pattern
	for filename in dir_content:lines() do
		id_tmp=tonumber(filename:match(id_pattern))
    	if id_tmp==id_my then
    	-- Do nothing.
    	elseif filename:match(team_enemy) then
    		table.insert(self.Players.Enemy.Instances, {File=io.open(path..filename, "r"), Id=id_tmp, Army=filename:match(army_pattern)})
    	elseif filename:match(team_my) then
			table.insert(self.Players.Team.Instances, {File=io.open(path..filename, "r"), Id=id_tmp, Army=filename:match(army_pattern)})
    	end
	end
	dir_content:close()
end

function BotInfoApi:terminate()
	self.Players.Me.Instance.File:close()
	self.Players.Team:closeFiles()
	self.Players.Enemy:closeFiles()
end

--======================================================================================

function onScriptInit()
	local path=BotInfoApi.Path

	os.execute("del \""..path.."\"* /s /q")
	io.open(path..BotApi.Instance.team..tostring(BotApi.Instance.playerId)..BotApi.Instance.army, "w+"):close()
end

function onScriptDone()
	BotInfoApi:terminate()
	collectgarbage("collect")
end

function readSetFile(fname, purchases, army)		-- Old system of unit parsing. It is recommended to use new system with native support of unit classes, first introduced in WH40K (see the end of file).
	local file=io.open(fname, "r")
	local count=0

    if file~=nil then
        while true do
            local line = file:read("*l")
            if line == nil then break end

            line = line:gsub(";.*",""):gsub("^%s*(.-)%s*$", "%1")
            local class=nil
            if line:lower():find("[(]"..army.."[)]") and line:len()>0
            and line:find("ammo")==nil 		-- no ammo suppliers.
			and line:find("support")==nil   -- no cannons, miners, support and artys.
			and line:find("flamer")==nil   	-- no flamers.
			and line:find("radioman")==nil  -- no radiomen.
			and line:find("oficer")==nil 	-- no oficer. Yes, one 'f'.
			and line:find("cannon")==nil 	and line:find("how")==nil 		-- no cannons, miners, support and artys (all carried guns don't work).
			and line:find("miner")==nil 	and line:find("engineer")==nil
			and line:find("sapper")==nil 	and line:find("supply")==nil
			and line:find("zis5")==nil 		and line:find("gmc")==nil		-- no robz supply trucks.
			and line:find("blitz")==nil 	and line:find("bedford")==nil	-- no robz supply trucks.
			and line:find("_eng")==nil 		and line:find("_art")==nil		-- no red rising supply trucks.
			and line:find("sdkfz303")==nil 	and line:find("np_sdkfz8")==nil -- no goliath and transport.
			and ((line:find("hero")==nil 	and line:find("tankman")==nil) or (line:find("hero")  and line:find("tankman") and line:find("[(]\"v[0-9]")))
			and line:find("b[(]v22[)]")==nil and line:find("b[(]special[)]")==nil -- no things for the support menu (all carried weapon don't work).
            then
                local name = line:gsub( ".*name[(]", ""):gsub( "[)].*", "")
                if name:len()>0 then
                	local group  = line:match(" g[(]([^)]*)[)]")
                	local charge = tonumber(line:match("%s+c[(]([^)]*)[)]"))
                	local cost	 = line:gsub( ".*[{]cost ", ""):gsub( ".*cost[(]", ""):gsub( "[})].*", ""); cost=tonumber(cost); if cost == nil then cost = 200 end
                	local fore 	 = 1
                    if not name:match("{") then
                    	if line:find("bazookers") or line:find("stormtroopers2") then 
                    		class=UnitClass.InfantryATank
                    	else
                    		class=UnitClass.InfantryGen
                    	end
                    	fore=fore-tonumber(line:match(" f[(]([^)]*)[)]"))
                    	count=count+1
						purchases[class].units[count] = {name = name.."("..army..")", cost = cost, charge = charge, group = group, wait_at_quant = charge*fore*40}	-- wait_at_quant value is estimated "by eye" which means that formula "charge*fore" is techically right but function OnGameQuant() is called more times than "on quant" which overincrement "Quants" variable and can lead to ai wait for unit to be unlocked. Call frequency depends on game performance (fps count). It is ridiculous but true. If game performance decreases linearly with player count, formula can be additionally divided by player count. Implementing quant timer can solve this problem but im unsure how it will affect performance.
                    else
                    	if line:find("hero") 		   then
                            class = UnitClass.Hero
                        elseif line:find("b[(]v2[)]")  then
                            class=UnitClass.VehicleArt
                        elseif line:find("b[(]v5[)]")  then	-- or line:find("b[(]vet[)]")
                            class=UnitClass.TankATank
                        elseif line:find("heavy") 	   then
                            class=UnitClass.TankHeavy
                        elseif line:find("b[(]v4[)]")  then
                            class=UnitClass.TankGen
                        else
                            class=UnitClass.VehicleGen
                        end
                        name = line:gsub( "{\"", ""):gsub( "\".*", "")
                        if not name:match("mp/") then
                        	fore=fore-tonumber(line:match("[{]fore ([^)]*)[}}][}}]"))
                        	count=count+1
							purchases[class].units[count] = {name = name, cost = cost, charge = charge, group = group, wait_at_quant = charge*fore*40}
                        end
                    end
                end
            end
        end
        print("Units read in", fname, ": ", count)
        io.close(file)
    end
end

function getPriorityFlag(flags, total_rate)
	local rnd=math.floor(math.random()*total_rate)
	local selected_flag=nil

	for name, flag in pairs(flags) do
		rnd=rnd-flag.priority
		if rnd<1 then
			return name
		end
	end
end

function getSpecialFlag(occupant, statuses)
	for name, flag in pairs(BotInfoApi.Players.Me.Flags.points) do
		if flag.occupant==occupant then
			if statuses[flag.status]~=nil then
				statuses[flag.status].total_rate=statuses[flag.status].total_rate+flag.priority
				statuses[flag.status].flags[name]=flag
			end
		end
	end
	for status, content in pairs(statuses) do
		if content.total_rate>0 then
			return getPriorityFlag(content.flags, content.total_rate)
		end
	end

	return getPriorityFlag(BotInfoApi.Players.Me.Flags.points, BotInfoApi.Players.Me.Flags.total_rate)
end

--[[function orderSpecial(id, delay)					-- Special order to use with special ai scripts, see comment below for details.
	BotInfoApi.Players.Me.SceneUnits[id].flag="n"
	BotInfoApi.Players.Me.SceneUnits[id].timer=BotApi.Events:SetQuantTimer(function() BotInfoApi.Players.Me.SceneUnits[id].timer=nil end, delay)
end--]]

function orderCaptureFlag(id, flag, delay)
	BotApi.Commands:CaptureFlag(id, flag)
	BotInfoApi.Players.Me.SceneUnits[id].flag=flag
	BotInfoApi.Players.Me.SceneUnits[id].timer=BotApi.Events:SetQuantTimer(function() BotInfoApi.Players.Me.SceneUnits[id].timer=nil end, delay)
end

function setOrder(id)
	local class=BotInfoApi.Players.Me.SceneUnits[id].class
	if class==UnitClass.InfantryGen 						then					
		orderCaptureFlag(id, getSpecialFlag(BotApi.Instance.enemyTeam, {[FlagStatus.Clear]={flags={}, total_rate=0}}), 150000)	-- These lines are written in a bit complicated way but there is nothing to be afraid of: just insert e.g. this line [FlagStatus.Clear]={flags={}, total_rate=0} after comma (see order for VehicleArt) to add flags with this status to flags to be found.
	elseif class==UnitClass.VehicleGen	 					then
		orderCaptureFlag(id, getSpecialFlag(nil, {[FlagStatus.Clear]={flags={}, total_rate=0}}), 80000)
	elseif class==UnitClass.VehicleArt 	 					then
		orderCaptureFlag(id, getSpecialFlag(BotApi.Instance.team, {[FlagStatus.Defended]={flags={}, total_rate=0}, [FlagStatus.Clear]={flags={}, total_rate=0}}), 240000)	-- Use orderSpecial(id, 3600000) if you have special artillery (or other unit class) behavior in your mod.
	elseif class==UnitClass.TankHeavy 	 					then
		orderCaptureFlag(id, getSpecialFlag(BotApi.Instance.enemyTeam, {[FlagStatus.DefendedStrong]={flags={}, total_rate=0}, [FlagStatus.Defended]={flags={}, total_rate=0}}), 120000)
	else
		orderCaptureFlag(id, getPriorityFlag(BotInfoApi.Players.Me.Flags.points, BotInfoApi.Players.Me.Flags.total_rate), 120000) -- 2 min; 1000 tic == 1 sec
	end
end

function getClassPriority(class, priority, results)		-- Using "factors" to handle unit priority. Lua's string comparison time is O(1) so don't worry about performance.
	if 	   class==UnitClass.InfantryGen 											then
		if not results["me_have_enough_inf"] 	 	  then priority=priority+Quants
		end
	elseif class==UnitClass.InfantryATank 											then
		if results["enemy_has_gen_tanks"] 	 	  	  then priority=priority+2
		end
	elseif class==UnitClass.VehicleGen												then
		if BotInfoApi.Players.Me.Flags.neutral>0 	  then priority=priority+2
		end
	elseif class==UnitClass.VehicleArt 												then

	elseif class==UnitClass.TankGen													then

	elseif class==UnitClass.TankATank												then
		if results["enemy_has_gen_tanks"] 		  	  then priority=priority+4
		end
	elseif class==UnitClass.TankHeavy												then
		if 	   BotInfoApi.Players.Me.Flags.enemy==0   then priority=priority-2
		elseif BotInfoApi.Players.Me.Flags.captured<BotInfoApi.Players.Me.Flags.enemy then priority=priority+2
		end
	elseif class==UnitClass.Hero 											then

	end

	return priority
end

function selectRandomUnit(available_units, total_rate)
	local rnd = math.floor(math.random()*total_rate)
	local selected_class=nil

	for class, content in pairs(available_units) do
		rnd=rnd-content.rate
		if rnd<1 then
			selected_class=class
			break
		end
	end

	local t=available_units[selected_class].units[math.random(#available_units[selected_class].units)]
	t.class=selected_class
	t.flag=nil
	t.timer=nil

	return t
end

function getUnitToSpawn(purchases)
	BotInfoApi.Players.Enemy:receiveUnitInfo()
	BotInfoApi.Players.Team:receiveUnitInfo()

	local results={}
	results["me_have_enough_inf"]  = haveUnit(BotInfoApi.Players.Me.SceneUnits, "class", 4, "inf")	-- Some examples of "factors" here. Available criterias: class, name, cost, wait_at_quant (initial unit's purchase timer).

	results["enemy_has_gen_tanks"] = haveUnit(BotInfoApi.Players.Enemy.Units,   "class", 1, UnitClass.TankGen)
	--results["enemy_has_ainf"]  	  	  = haveUnit(BotInfoApi.Players.Enemy.Units, "class", 4, "inf_a_inf", "sup_a_Inf", "veh_a_inf") 
	--results["enemy_has_tanks"]	 	  = haveUnit(BotInfoApi.Players.Enemy.Units, "class", 1, UnitClass.VehicleAInf)
	--results["enemy_has_hellhound"] 	  = haveUnit(BotInfoApi.Players.Enemy.Units, "name", 1, "hellhound")

	--results["team_has_dreadnought"] 	  = haveUnit(BotInfoApi.Players.Team.Units, "name", 2, "dreadnought")
	--results["team_has_expensive_unit"]  = haveUnit(BotInfoApi.Players.Team.Units, "cost", 1, 1000)				-- Finds units in this instance's team with cost >= 1000

	local total_class_rate=1
	local getCP = getClassPriority 		-- There is nothing illegal here, officer.
	local available_class_count=0
	local available_units={}

	local quants, team_size, income = Quants, BotApi.Instance.teamSize, BotApi.Commands:Income(BotApi.Instance.playerId) 		-- Some optimisation here.
	local formula=(374*income-31.3*income*income+1.1*income*income*income-1.3) + (354.5*team_size-23*team_size*team_size-342)	-- Formula to unlock more powerful units for purchase over time. You may reconsider it for your mod.

	for class, content in pairs(purchases) do
		local unit_count=0
		local current_class={units={}, rate=0, count=0}
		for k, unit in pairs(content.units) do
			if formula>=unit.cost and quants>unit.wait_at_quant then
				if unit.charge>120 then
					if BotInfoApi.Players.Me:isTimedUnit(unit.group) or (unit.cost<10 and unit.cost>SpecialPoints) then
						goto continue
					end
				end
				unit_count=unit_count+1
				current_class.units[unit_count]=unit
			end
			::continue::
		end

		if #current_class.units>0 then
			available_class_count=available_class_count+1
			available_units[class]=current_class
			available_units[class].rate=getCP(class, content.priority, results)
			total_class_rate=total_class_rate+available_units[class].rate
		end
	end

	if available_class_count==0 then
		return nil
	end

	local selected_unit=selectRandomUnit(available_units, total_class_rate)
	if selected_unit.charge>120 then										-- Timers for units are set only if unit's charge value is more than 120.
		BotInfoApi.Players.Me:addTimedUnit(selected_unit)
	end
	if selected_unit.cost<10 then
		SpecialPoints=SpecialPoints-selected_unit.cost
	end

	BotInfoApi.Players.Me.SpawnBuffer.count=BotInfoApi.Players.Me.SpawnBuffer.count+1
	BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.count]=selected_unit

	return selected_unit
end

function onGameStart()
	local army=BotApi.Instance.army
	Quants=0

	math.randomseed(os.clock()*10000000000*BotApi.Instance.playerId*BotApi.Instance.hostId)

	BotInfoApi:initialize()
	BotInfoApi:calculatePlayerCount()
	BotInfoApi.Players.Me.Purchases=readAllUnits(army)

	--[[local marker={class="t", name="bot_marker("..army..")", cost=1, wait_at_quant=1, flag=nil, timer=nil}	-- Marker for ai scripts (used in WH40K). Enable these lines only if your mod comtains special ai scripts.
	BotInfoApi.Players.Me.SpawnInfo=marker
	BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.count]=marker]]--
end

function onGameQuant()
	Quants=Quants+1
	if Quants%100==0 then
		BotInfoApi.Players.Me:updateFlagPriorities()
		for i, id in pairs(BotApi.Scene.Squads) do
			if BotInfoApi.Players.Me.SceneUnits[id]==nil then 	-- Code for handling unknown units (which appear on battlefield dynamically, like marines after paradrop in WH40K).
				BotInfoApi.Players.Me.SceneUnits[id]={class="unk", name="sq_unknown", cost=300, wait_at_quant=3000, flag=nil, timer=nil}
			end
			if BotInfoApi.Players.Me.SceneUnits[id].timer==nil then
				setOrder(id)
			end
		end
		BotInfoApi.Players.Me:sendSceneUnits()
	end
	if BotInfoApi.Players.Me.SpawnInfo==nil or BotApi.Commands:Spawn(BotInfoApi.Players.Me.SpawnInfo.name, MaxSquadSize) then
		BotInfoApi.Players.Me.SpawnInfo=getUnitToSpawn(BotInfoApi.Players.Me.Purchases)
	end
end

function onGameSpawn(args)
	if BotInfoApi.Players.Me:addSceneUnit(args.squadId, BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.pointer]) then
		BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.pointer]=nil
		BotInfoApi.Players.Me.SpawnBuffer.pointer=BotInfoApi.Players.Me.SpawnBuffer.pointer+1
		setOrder(args.squadId)
	end
end

function onGameEnd()
	local phrases={on_victory={"gg", "ez", "We won!", "Enemy team sucks!", "Rock 'N Stone, Brothers!", "Haha, losers."},
	 			   on_defeat={"This sucks.", "My teammates are noobs.", "Freeman you fool!", "..."}}
	
	if math.random(7)>4 then
		if BotInfoApi.Players.Me.Flags.captured>BotInfoApi.Players.Me.Flags.enemy then
			BotApi.Commands:SayChat(phrases.on_victory[math.random(#phrases.on_victory)])
		else
			BotApi.Commands:SayChat(phrases.on_defeat[math.random(#phrases.on_defeat)])
		end
	end

	for id, unit in pairs(BotInfoApi.Players.Me.SceneUnits) do
		if unit.timer then
			BotApi.Events:KillQuantTimer(unit.timer)
		end
	end
end

BotApi.Events:Subscribe(BotApi.Events.Init, onScriptInit)
BotApi.Events:Subscribe(BotApi.Events.Done, onScriptDone)
BotApi.Events:Subscribe(BotApi.Events.GameStart, onGameStart)
BotApi.Events:Subscribe(BotApi.Events.Quant, onGameQuant)
BotApi.Events:Subscribe(BotApi.Events.GameSpawn, onGameSpawn)
BotApi.Events:Subscribe(BotApi.Events.GameEnd, onGameEnd)

-- New system of unit parsing that utilises unit's "tag" property to get unit's class. You need to manually set unit classes in .set files inside their "tag" property. See ASV WH40K .set files for examples.

--[[function readSetFile(fname, purchases, army)
	local file=io.open(fname, "r")
	local count=0

    if file~=nil then
        while true do
            local line = file:read("*l")
            if line == nil then break end

            line = line:gsub(";.*",""):gsub("^%s*(.-)%s*$", "%1")
            local class=line:match("t[(].+%s([%a%_]+)[)]")
            if line:lower():find("[(]"..army.."[)]") and line:len() > 0 and class~="non" then
                local name = line:gsub( ".*name[(]", ""):gsub( "[)].*", "")
                if name:len()>0 then
                	local group  = line:match(" g[(]([^)]*)[)]")
                	local charge = tonumber(line:match("%s+c[(]([^)]*)[)]"))
                	local cost	 = line:gsub( ".*[{]cost ", ""):gsub( ".*cost[(]", ""):gsub( "[})].*", ""); cost=tonumber(cost); if cost == nil then cost = 200 end
                	local fore 	 = 1
                    if not name:match("{") then
                    	fore=fore-tonumber(line:match(" f[(]([^)]*)[)]"))
                    	count=count+1
                        local unit = {name = name.."("..army..")", cost = cost, charge = charge, group = group, wait_at_quant = charge*fore*40/BotApi.Instance.teamSize}
						purchases[class].units[count]=unit
                    else
                        name = line:gsub( "{\"", ""):gsub( "\".*", "")
                        if not name:match("mp/") then
                        	fore=fore-tonumber(line:match("[{]fore ([^)]*)[}}][}}]"))
                        	count=count+1
                            local unit = {name = name, cost = cost, charge = charge, group = group, wait_at_quant = charge*fore*40/BotApi.Instance.teamSize}
							purchases[class].units[count]=unit
                        end
                    end
                end
            end
        end
        print("Units read in", fname, ": ", count)
        io.close(file)
    end
end--]]