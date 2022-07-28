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
    local o=o or {}
    setmetatable(o, self)
    self.__index = self
    o:createClassTables()
    return o
end

function TeamApi:receiveUnitInfo()
	clearTable(self.Units)
    for k=1, self.Count do
    	local file=self.Instances[k].File
    	file:seek("set", 0)
        for line in file:lines() do
            local properties, i={}, 1
            for p in string.gmatch(line, "([^%s]+)") do
                properties[i]=p
                i=i+1
            end
            self.Units[#self.Units+1]={id=properties[1], class=properties[2], name=properties[3], cost=properties[4], flag=properties[5]}
        end
    end
end

function haveUnit(units, property, count, ...)		-- Yeah, i know it's ugly and it violates the encapsulation policy, but this solution is better than duplication of that function.
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
	for i=1, #self.Instances do
		self.Instances[i].File:close()
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
    Instance={File=nil, Id=nil, Army=nil, SpecialPoints=10, MaxSquadSize=10},
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
	self.SceneUnits[id]={class=unit.class, name=unit.name, cost=unit.cost, flag=unit.flag, timer=unit.timer} -- self.SceneUnits[id]=unit creates unit's member values as references!
	return true
end

function Context:sendSceneUnits()
	self.Instance.File:close()
	self.Instance.File=io.open(self.Utility.FilePath, "w")
	self.Instance.File:setvbuf("no")

	for id, unit in pairs(self.SceneUnits) do
		if BotApi.Scene:IsSquadExists(id) then
			self.Instance.File:write(id, " ", unit.class, " ", unit.name, " ", unit.cost, " ", unit.flag, "\n")
		else
			if unit.timer then
				BotApi.Events:KillQuantTimer(unit.timer)
			end
			self.SceneUnits[id]=nil
		end
	end
end

function Context:setGroupTimer(group, wait_time)
	BotInfoApi.Players.Me.TimedUnits[group]=BotApi.Events:SetQuantTimer(function() BotInfoApi.Players.Me.TimedUnits[group]=nil end, wait_time*1000)
end

function Context:checkGroupTimer(group)
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
    Path="mods\\bot revised v2\\resource\\script\\multiplayer\\bot_info\\",
    Players={Enemy=EnemyTeam:new(nil), Team=MyTeam:new(nil), Me=Context, Count=nil}
}

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
    		self.Players.Enemy.Instances[#self.Players.Enemy.Instances+1]={File=io.open(path..filename, "r"), Id=id_tmp, Army=filename:match(army_pattern)}
    	elseif filename:match(team_my) then
			self.Players.Team.Instances[#self.Players.Team.Instances+1]={File=io.open(path..filename, "r"), Id=id_tmp, Army=filename:match(army_pattern)}
    	end
	end
	dir_content:close()
	self.Players.Enemy.Count=#self.Players.Enemy.Instances
	self.Players.Team.Count=#self.Players.Team.Instances
	self.Players.Count=self.Players.Enemy.Count+self.Players.Team.Count+1
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
            local line=file:read("*l")
            if line==nil then break end

            line=line:gsub(";.*",""):gsub("\t",""):gsub("^%s*(.-)%s*$", "%1")
            local class=nil
            if line:lower():find("[(]"..army.."[)]") and line:len()>0
            and line:find("ammo")==nil 		-- no ammo suppliers.
			and line:find("support")==nil   -- no cannons, miners, support and artys.
			and line:find("flamer")==nil   	-- no flamers.
			and line:find("radioman")==nil  -- no radiomen.
			and line:find("oficer")==nil 	-- no oficer. Yes, one 'f'.
			and line:find("cannon")==nil 	and line:find("how")==nil 		-- no cannons, miners, support and artys (all carried weapons don't work).
			and line:find("miner")==nil 	and line:find("engineer")==nil
			and line:find("sapper")==nil 	and line:find("supply")==nil
			and line:find("zis5")==nil 		and line:find("gmc")==nil		-- no robz supply trucks.
			and line:find("blitz")==nil 	and line:find("bedford")==nil	-- no robz supply trucks.
			and line:find("_eng")==nil 		and line:find("_art")==nil		-- no red rising supply trucks.
			and line:find("sdkfz303")==nil 	and line:find("np_sdkfz8")==nil -- no goliath and transport.
			and ((line:find("hero")==nil 	and line:find("tankman")==nil) or (line:find("hero")  and line:find("tankman") and line:find("[(]\"v[0-9]")))
			and line:find("b[(]v22[)]")==nil and line:find("b[(]special[)]")==nil -- no things for the support menu (all carried weapons don't work).
            then
                local name=line:gsub( ".*name[(]", ""):gsub( "[)].*", "")
                if name:len()>0 then
                	local group  = line:match(" g[(]([^)]*)[)]")
                	local charge = tonumber(line:match("%s+c[(]([^)]*)[)]"))
                	local cost	 = line:gsub( ".*[{]cost ", ""):gsub( ".*cost[(]", ""):gsub( "[})].*", ""); cost=tonumber(cost); if cost==nil then cost=200 end
                	local fore 	 = 1
                    if not name:match("{") then
                    	if line:find("bazookers") or line:find("stormtroopers2") then 
                    		class="inf_a_tank"
                    	else
                    		class="inf_gen"
                    	end
                    	fore=fore-tonumber(line:match(" f[(]([^)]*)[)]"))
                    	count=count+1
						purchases[class].units[count]={name=name.."("..army..")", cost=cost, charge=charge, group=group}
						if BotInfoApi.Players.Me.TimedUnits[group]==nil then
                            BotInfoApi.Players.Me:setGroupTimer(group, charge*fore)
                        end
                    else
                    	if line:find("hero") 		   then
                            class="hero"
                        elseif line:find("b[(]v2[)]")  then
                            class="veh_art"
                        elseif line:find("b[(]v5[)]")  then
                            class="tank_a_tank"
                        elseif line:find("heavy") 	   then
                            class="tank_heavy"
                        elseif line:find("b[(]v4[)]")  then
                            class="tank_gen"
                        else
                            class="veh_gen"
                        end
                        name=line:gsub( "{\"", ""):gsub( "\".*", "")
                        if not name:match("mp/") then
                        	fore=fore-tonumber(line:match("[{]fore ([^)]*)[}}][}}]"))
                        	count=count+1
							purchases[class].units[count]={name=name, cost=cost, charge=charge, group=group}
							if BotInfoApi.Players.Me.TimedUnits[group]==nil then
                            	BotInfoApi.Players.Me:setGroupTimer(group, charge*fore)
                        	end
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

--[[function orderSpecial(id, delay)			-- Special order to use with special ai scripts, see Artillery order comment in bot.data.lua for details.
	BotInfoApi.Players.Me.SceneUnits[id].flag="n"
	BotInfoApi.Players.Me.SceneUnits[id].timer=BotApi.Events:SetQuantTimer(function() BotInfoApi.Players.Me.SceneUnits[id].timer=nil end, delay)
end--]]

function orderCaptureFlag(id, flag, delay)
	BotApi.Commands:CaptureFlag(id, flag)
	BotInfoApi.Players.Me.SceneUnits[id].flag=flag
	BotInfoApi.Players.Me.SceneUnits[id].timer=BotApi.Events:SetQuantTimer(function() BotInfoApi.Players.Me.SceneUnits[id].timer=nil end, delay)
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

local Results={						-- Avoiding constructing the same table every time (see usage in function below).
	me_have_enough_inf=nil,

	enemy_has_gen_tanks=nil
}
function getUnitToSpawn(purchases)
	BotInfoApi.Players.Enemy:receiveUnitInfo()
	BotInfoApi.Players.Team:receiveUnitInfo()

	Results["me_have_enough_inf"]  = haveUnit(BotInfoApi.Players.Me.SceneUnits, "class", 4, "inf_")	-- Some examples of "factors" here. Available criterias: class, name, cost.

	Results["enemy_has_gen_tanks"] = haveUnit(BotInfoApi.Players.Enemy.Units,   "class", 1, "tank_gen")
	--Results["enemy_has_ainf"]  	  	  = haveUnit(BotInfoApi.Players.Enemy.Units, "class", 4, "inf_a_inf", "sup_a_Inf", "veh_a_inf") 
	--Results["enemy_has_tanks"]	 	  = haveUnit(BotInfoApi.Players.Enemy.Units, "class", 1, inf_a_tank)
	--Results["enemy_has_hellhound"] 	  = haveUnit(BotInfoApi.Players.Enemy.Units, "name", 1, "hellhound")

	--Results["team_has_dreadnought"] 	  = haveUnit(BotInfoApi.Players.Team.Units, "name", 2, "dreadnought")
	--Results["team_has_expensive_unit"]  = haveUnit(BotInfoApi.Players.Team.Units, "cost", 1, 1000)		-- Finds units in this instance's team with cost >= 1000

	local team_size, income=BotApi.Instance.teamSize, BotApi.Commands:Income(BotApi.Instance.playerId) 		-- Some optimisation here.
	local formula=(374*income-31.3*income*income+1.1*income*income*income-1.3)+(354.5*team_size-23*team_size*team_size-342)	-- Formula to lock or unlock more powerful units for purchase witch according to income. You may reconsider it's values for your mod.
	local total_class_rate, available_class_count, available_units=1, 0, {}

	for class, content in pairs(purchases) do
		local unit_count=0
		local current_class={units={}, rate=0, count=0}
		for k, unit in pairs(content.units) do
			if formula>=unit.cost and not (BotInfoApi.Players.Me:checkGroupTimer(unit.group) or (unit.cost<11 and unit.cost>BotInfoApi.Players.Me.Instance.SpecialPoints)) then
				unit_count=unit_count+1
				current_class.units[unit_count]=unit
			end
		end

		if #current_class.units>0 then
			available_class_count=available_class_count+1
			available_units[class]=current_class
			available_units[class].rate=content["getCurrentPriority"](content.priority, Results)
			total_class_rate=total_class_rate+available_units[class].rate
		end
	end

	if available_class_count==0 then
		return nil
	end

	local selected_unit=selectRandomUnit(available_units, total_class_rate)
	if selected_unit.charge>80 then		-- Timers for units are set only if unit's charge value is more than 80.
		BotInfoApi.Players.Me:setGroupTimer(selected_unit.group, selected_unit.charge)
	end
	if selected_unit.class=="hero" then	-- Or selected_unit.cost<11
		BotInfoApi.Players.Me.Instance.SpecialPoints=BotInfoApi.Players.Me.Instance.SpecialPoints-selected_unit.cost
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
	BotInfoApi.Players.Me.Purchases=readAllUnits(army)

	--[[local marker={class="tank_gen", name="bot_marker("..army..")", cost=1, flag=nil, timer=nil}	-- Marker for ai scripts (used in WH40K). Enable these lines only if your mod comtains special ai scripts.
	BotInfoApi.Players.Me.SpawnInfo=marker
	BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.count]=marker]]--
end

function onGameQuant()
	Quants=Quants+1
	if Quants%150==0 then
		BotInfoApi.Players.Me:updateFlagPriorities()
		for i, id in pairs(BotApi.Scene.Squads) do
			if BotInfoApi.Players.Me.SceneUnits[id]==nil then 	-- Code for handling unknown units (which appear on battlefield dynamically, like marines after paradrop in WH40K).
				BotInfoApi.Players.Me.SceneUnits[id]={class="inf_gen", name="sq_unknown", cost=100, flag=nil, timer=nil}
			end
			if BotInfoApi.Players.Me.SceneUnits[id].timer==nil then
				BotInfoApi.Players.Me.Purchases[BotInfoApi.Players.Me.SceneUnits[id].class]["setOrder"](id)
			end
		end
		BotInfoApi.Players.Me:sendSceneUnits()
	end

	if BotInfoApi.Players.Me.SpawnInfo==nil or BotApi.Commands:Spawn(BotInfoApi.Players.Me.SpawnInfo.name, BotInfoApi.Players.Me.Instance.MaxSquadSize) then
		BotInfoApi.Players.Me.SpawnInfo=getUnitToSpawn(BotInfoApi.Players.Me.Purchases)
	end
end

function onGameSpawn(args)
	if BotInfoApi.Players.Me:addSceneUnit(args.squadId, BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.pointer]) then
		BotInfoApi.Players.Me.SpawnBuffer.units[BotInfoApi.Players.Me.SpawnBuffer.pointer]=nil
		BotInfoApi.Players.Me.SpawnBuffer.pointer=BotInfoApi.Players.Me.SpawnBuffer.pointer+1
		BotInfoApi.Players.Me.Purchases[BotInfoApi.Players.Me.SceneUnits[args.squadId].class]["setOrder"](args.squadId)
	end
end

function onGameEnd()
	local phrases={on_victory={"gg", "ez", "We won!", "Enemy team sucks!", "Rock 'N Stone, Brothers!", "Haha, losers."},
	 			   on_defeat={"This sucks.", "My teammates are noobs.", "Freeman you fool!", "...", "I'm out."}}
	
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
BotApi.Events:Subscribe(BotApi.Events.GameStart, onGameStart)
BotApi.Events:Subscribe(BotApi.Events.Quant, onGameQuant)
BotApi.Events:Subscribe(BotApi.Events.GameSpawn, onGameSpawn)
BotApi.Events:Subscribe(BotApi.Events.GameEnd, onGameEnd)
BotApi.Events:Subscribe(BotApi.Events.Done, onScriptDone)

-- New system of unit parsing that utilises unit's "tag" property to get unit's class. You need to manually set unit classes in .set files inside their "tag" property. See ASV WH40K .set files for examples.

--[[function readSetFile(fname, purchases, army)
	local file=io.open(fname, "r")
	local count=0

    if file~=nil then
        while true do
            local line=file:read("*l")
            if line==nil then break end

            line=line:gsub(";.*",""):gsub("^%s*(.-)%s*$", "%1")
            local class=line:match("t[(].+%s([%a%_]+)[)]")
            if line:lower():find("[(]"..army.."[)]") and line:len()>0 and class~="non" then
                local name=line:gsub( ".*name[(]", ""):gsub( "[)].*", "")
                if name:len()>0 then
                	local group  =line:match(" g[(]([^)]*)[)]")
                	local charge =tonumber(line:match("%s+c[(]([^)]*)[)]"))
                	local cost	 =line:gsub( ".*[{]cost ", ""):gsub( ".*cost[(]", ""):gsub( "[})].*", ""); cost=tonumber(cost); if cost==nil then cost=200 end
                	local fore 	 =1
                    if not name:match("{") then
                    	fore=fore-tonumber(line:match(" f[(]([^)]*)[)]"))
                    	count=count+1
						purchases[class].units[count]={name=name.."("..army..")", cost=cost, charge=charge, group=group}
						if BotInfoApi.Players.Me.TimedUnits[group]==nil then
                            BotInfoApi.Players.Me:setGroupTimer(group, charge*fore)
                        end
                    else
                        name=line:gsub( "{\"", ""):gsub( "\".*", "")
                        if not name:match("mp/") then
                        	fore=fore-tonumber(line:match("[{]fore ([^)]*)[}}][}}]"))
                        	count=count+1
							purchases[class].units[count]={name=name, cost=cost, charge=charge, group=group}
							if BotInfoApi.Players.Me.TimedUnits[group]==nil then
                            	BotInfoApi.Players.Me:setGroupTimer(group, charge*fore)
                        	end
                        end
                    end
                end
            end
        end
        print("Units read in", fname, ": ", count)
        io.close(file)
    end
end--]]