local mumble = require "mumble"
local inspect = require "inspect"

function getTime() --the library has mumble.gettime() but that only returns ms
	local _time = os.date('*t')
	_time = ("%02d:%02d:%02d"):format(_time.hour, _time.min, _time.sec)
	return "[".._time.."] "
end

function log(text, p)	--text to log, print?
	p = p == nil	--normally to make defaults you can do p = p or 'def' but since false is a valid answer here we gotta use something different
	local file = io.open("log.txt", "a")
	file:write("\n")
	file:write(getTime() .. text)
	if p then
		print(getTime() .. text)
	end
	file:close()
end

function file_exists(file) local f = io.open(file, "r") if f ~= nil then io.close(f) return true else return false end end	--https://stackoverflow.com/questions/4990990/check-if-a-file-exists-with-lua

function qlines(file)				--q[uickly read]lines and return their contents.
	if file_exists(file) == false then log("Attempting to read file which doesn't exist, returning empty table") return {} end
	local output = {}
	for line in io.lines(file) do
		if not line:find("%s") then output[line:lower()] = true end	--skips blank lines
	end
	return output
end

function write_to_file(t)	--write a table to a csv file with the same name. This is the easiest solution I could think of for my problem. Rather than try and reopen and edit out specific lines from files, I just rewrite the files.
	local file = io.open(t..'.csv', 'w+')		--"w+" = open the file given (t..'.csv') and write over it (all data lost)
	for k,v in pairs(_G[t]) do
		file:write(k..'\n')
	end
	file:close()
end

macadamias = qlines("mi.csv")
admins = qlines("admins.csv")
warrants = qlines("warrants.csv")
channelTable = {}
usersAlpha = {}
players = {}

function isMac(s)	--s will be a name only, not a user object
	for _,v in ipairs(macadamias) do
		if v:lower() == s:lower() and players[s:lower()].object:getID() ~= 0 then --0 means unregistered
			return true
		end
	end
end

local client, err = assert(mumble.connect("voice.nut.city", 42069, "adv.pem", "adv.key"))
if err ~= nil then
	log(err, true)
end
client:auth("2Poopy2Joe") --If the bot is registered on a server, it will always use the name it's registered under, however you'll still need to specify a string in this method.

client:hook("OnServerReject", function(event)
	log("ServerReject: "..event.reason)
end)

function find(p, c)		--parent, child | The library technically has a way to do this within it but I don't understand it :D
	for _,channel in pairs(client:getChannels()) do
		if channel:getName() == c and channel:getParent():getName() == p then
			return channel
		end
	end
end

function isAdmin(s)		--s will be the sender of a message, a user obj. we lower their name then find the value of the key in the admins table.
	if s:getID() == 0 then
		return false --user is unregistered!!!!
	else
		return admins[s:getName():lower()]
	end
end

function generateUsersAlpha()
	usersAlpha = {}
	for _,u in pairs(addup:getUsers()) do
		table.insert(usersAlpha, u:getName():lower())
	end
	table.sort(usersAlpha)
end

function randomTable(n)
	math.randomseed(os.time())
	local t = {}
	for i =	1, n do
		table.insert(t, i)
	end
	local r
	for i = 1, #t do
		r = math.random(i, #t)
		t[i], t[r] = t[r], t[i]
	end
	return t
end

function getlen(c, recursive)
	local i = 0
	for _,_ in pairs(c:getUsers()) do
		i = i + 1
	end
	if recursive then
		for _,channel in pairs(c:getChildren()) do
			for _,_ in pairs(channel:getUsers()) do
				i = i + 1
			end
		end
	end
	return i
end

function determine_roll_num()
	for i,channel in ipairs(channelTable) do
		local server = find("Add Up", "Pug Server "..tostring(i))
		local l = getlen(server, true)
		if l < 2 then
			return 2 - l			--this will return "2" if 0 people are in the selected server and "1" if 1 person is added up. No overflows.
		end
	end
end

function roll(t)
	log("Trying to get a new medic pick")
	local i = 1
	local userTesting
	local c1, c2, c3 = channelTable[1], channelTable[2], channelTable[3]
	if c1.red.length + c1.blu.length >= 2 then
	if c2.red.length + c2.blu.length >= 2 then
	if c3.red.length + c3.blu.length >= 2 then 
	addup:message("You can't roll, there are already medics.")			
	log("Someone tried to roll but was denied due to sufficient players.") 
		return
	end
	end
	end
	while i <= getlen(addup) do
		if i > getlen(addup) then
			log("Run out of people to test.")
			addup:message("Everyone here has played Medic.")
			return
		else
			userTesting = usersAlpha[t[i]]
			if players[userTesting].medicImmunity == true or players[userTesting].object:getID() == 214 then
				log(userTesting .. " has immunity, continuing...")
				i = i + 1
			elseif players[userTesting].medicImmunity == false then
				log(userTesting .. " doesn't have immunity, breaking loop.")
				break
			end
		end
	end
	log("Selecting medic: " .. userTesting)
	addup:message("Medic: " .. userTesting)
	local user = players[userTesting]
	local red, blu
	if c1.red.length + c1.blu.length < 2 then
		red = c1.red
		blu = c1.blu
	elseif c2.red.length + c2.blu.length < 2 then
		red = c2.red
		blu = c2.blu
	elseif c3.red.length + c3.blu.length < 2 then
		red = c3.red
		blu = c3.blu
	else
		log("No room to move players...")
		return
	end
	if red.length <= 0 then
		user.object:move(red.object)
		red.length = red.length + 1
	elseif blu.length <= 0 then
		user.object:move(blu.object)
		blu.length = blu.length + 1
	else
		log("Error in roll-move")
		return
	end
	log("Moved " .. user.object:getName())
	user.dontUpdate = true
	user.medicImmunity = true
	user.captain = true
end

client:hook("OnServerSync", function(event)	--this is where the initialization happens. The bot can do nothing in mumble before this.
	local _date = os.date('*t')
	_date = _date.month.."/".._date.day
	log("===========================================", false)
	log("Newly connected, Syncd as "..event.user:getName().." v3.4.0".." on ".. _date)
	log("===========================================", false)
	motd, msgen = "", false		--message of the day, message of the day bool	
	joe = event.user
	root = joe:getChannel():getParent():getParent()
	spacebase = find("Inhouse Pugs (Nut City)", "Poopy Joes Space Base")
	connectlobby = find("Inhouse Pugs (Nut City)", "Connection Lobby")
	addup = find("Inhouse Pugs (Nut City)", "Add Up")
	fatkids = find("Add Up", "Fat Kids")
	notplaying = find("Add Up", "Chill Room (Not Playing)")
	pugroot = find("Nut City Limits", "Inhouse Pugs (Nut City)")
	joe:move(spacebase)
	next_log_silent = false
	players = {}
	for _,v in pairs(client:getUsers()) do
		local u = v:getName():lower()
		log("Found "..u)
		players[u] = {
			object = v,
			volunteered = false,
			captain = false,
			dontUpdate = false,
			channelB = v:getChannel(),
			selfbotdeaf = false,
			perma_mute = false,
			imprison = false
		}
		if isMac(u) then
			players[u].medicImmunity = true
		else
			players[u].medicImmunity = false
		end
	end
	channelTable = {
		{
		    red = {
		        object = find("Pug Server 1", "Red"),
		        length = getlen(find("Pug Server 1", "Red"))
		    },
		    blu = {
		        object = find("Pug Server 1", "Blu"),
		        length = getlen(find("Pug Server 1", "Blu"))
		    }
		},
		{
		    red = {
		        object = find("Pug Server 2", "Red"),
		        length = getlen(find("Pug Server 2", "Red"))
		    },
		    blu = {
		        object = find("Pug Server 2", "Blu"),
		        length = getlen(find("Pug Server 2", "Blu"))
		    }
		},
		{
		    red = {
		        object = find("Pug Server 3", "Red"),
		        length = getlen(find("Pug Server 3", "Red"))
		    },
		    blu = {
		        object = find("Pug Server 3", "Blu"),
		        length = getlen(find("Pug Server 3", "Blu"))
		    }
		}
	}
	draftlock = false
	dle = true
end)

function mumble.channel.messager(self, m, cc) --channel, message, carbon copy to: (typically sender)
	self:message(m)
	for _,channels in pairs(self:getChildren()) do
		channels:message(m)
	end
	if cc then
		cc:message(m)
	end
end

function lenprintout()
	print("-------------------------",getTime())
	print("LENGTH OF RED1: " .. tostring(channelTable[1].red.length))
	print("LENGTH OF BLU1: " .. tostring(channelTable[1].blu.length))
	print("LENGTH OF RED2: " .. tostring(channelTable[2].red.length))
	print("LENGTH OF BLU2: " .. tostring(channelTable[2].blu.length))
	print("-------------------------")
end

local cmd = {}	--you don't even need _G to do this haha whoops i'm a doofus
--[[ctx =
p_data = senderData,						-- the players[player] data thing :)
admin = isAdmin,						-- bool :)
sender_name = event.actor:getName(),	-- name :)
sender = event.actor,					-- sender (mumble.user)
channel = event.actor:getChannel()		-- sender's channel (mumble.channel) NOT the channel the message is sent to
]]--
function parse(s, context)
	local kwords = {}
	for word in string.gmatch(s, "%S+") do  --%s = space char, %S = not space char. + means multiple in a row. Use this over %w+, to retain underscores.
		table.insert(kwords, word)			--insert each match into table kwords. kwords[1] will always be the cmd name, everything after that is a parameter.
	end
	if cmd[kwords[1]] ~= nil then			--if function exists
		cmd[kwords[1]](context, kwords)		--call function by name with context and arguments as well as user perms
	end
end
--BOT COMMANDS--
--						--
	--	 Admins		--
--						--
function cmd.cull(ctx)
	if ctx.admin == false then return end
	pugroot:messager("Deafened users are being moved to chill room! Blame "..ctx.sender)
	for _,user in pairs(addup:getUsers()) do
		if user:isSelfDeaf() then
			user:move(notplaying)
		end
	end
	log("Deafened users culled")
end
function cmd.roll(ctx, args)
	if ctx.admin == false then log(ctx.sender_name..' denied roll perms') return end
	draftlock = true
	log("Draftlock switched to true after roll begins")
	pugroot:messager("Medics being rolled, draft is locked.")
	for _,u in pairs(players) do
		u.captain = false
		u.volunteered = false
	end
	generateUsersAlpha()
	local toRoll
	if #args < 2 then
		toRoll = determine_roll_num()
		print("No integer specified, rolling *just enough* medics!: "..tostring(toRoll))
	else	
		toRoll = tonumber(args[2])
	end
	while toRoll > 0 do
		roll(randomTable(getlen(addup)))
		toRoll = toRoll - 1
	end
end
function cmd.dc(ctx, args)
	if ctx.admin == false then log(ctx.sender_name..'denied dc perms') return end
	draftlock = false
	if dle then log("Draftlock switched to false after channel dump") end
	local cnl = tonumber(args[2])
	local server
	if cnl <= 5 and cnl >= 1 then
		server = find("Add Up", "Pug Server "..tostring(cnl))
	else
		log("Invalid channel to dump: " .. cnl)
		return
	end
	ctx.channel:messager("Attempting to dump channels...")
	log("Trying to dump channel " .. args[2])
	for _,room in pairs(server:getChildren()) do
		for _,user in pairs(room:getUsers()) do
			user:move(addup)
			players[user:getName():lower()].imprison = false
		end
	end
	addup:messager("Channel "..cnl.." dumped by "..ctx.sender_name)
	for _,room in pairs(server:getChildren()) do
		room:link(addup)
	end
end
function cmd.strike(ctx, args)
	if ctx.admin == false then return end
	local player = args[2]
	players[player].medicImmunity = false
	log(ctx.sender_name .. " removes Medic Immunity from " .. player)
	addup:messager(ctx.sender_name .. " removes " .. player .. "'s medic immunity.", ctx.sender)
end
function cmd.ami(ctx, args)
	if ctx.admin == false then return end
	local player = args[2]
	players[player].medicImmunity = true
	log(ctx.sender_name .. " gives medic immunity to " .. player)
	addup:messager(ctx.sender_name .. " gives " .. player .. " medic immunity.", ctx.sender)
end
function cmd.clearmh(ctx)
	if ctx.admin == false then return end
	for _,v in pairs(players) do
		if not isMac(k) then
			v.medicImmunity = false
			v.captain = false
			v.volunteered = false
		end
	end
	log(ctx.sender_name .. " cleared medic history.")
end
function cmd.pmh(ctx)
	for player,data in pairs(players) do
		if data.medicImmunity then
			ctx.sender:message(player .. " has medic immunity")
		end
	end
end
function cmd.link(ctx, args)
	if ctx.admin == false then log(ctx.sender_name..' denied linking perms') return end
	local server = tonumber(args[2])
	if server == 1 then
		server = channelTable[1]
	elseif server == 2 then
		server = channelTable[2]
	elseif server == 3 then
		server = channelTable[3]
	end
	local red, blu = server.red.object, server.blu.object
	addup:link(blu, red)
	blu:link(red)
	log("Server " .. args[2] .. " subchannels linked by " .. ctx.sender_name)
end
function cmd.unlink(ctx, args)
	if ctx.admin == false then return end
	local server = tonumber(args[2])
	if server == 1 then
		server = channelTable[1]
	elseif server == 2 then
		server = channelTable[2]
	elseif server == 3 then
		server = channelTable[3]
	end
	local red, blu = server.red.object, server.blu.object
	addup:unlink(blu, red)
	blu:unlink(red)
	draftlock = false
	log("Draftlock switched to false in accordance with unlink, DLE IS: "..tostring(dle))
	log("Server " .. args[2] .. " subchannels unlinked by " .. ctx.sender_name)
end
function cmd.mute(ctx, args)
	if ctx.admin == false then return end
	local ec		--whether or not to exclude captains from mutings.
	if args[2] == "all" then ec = false else ec = true end
	local _players = {}		--normally i could just override players but i need the real players to be avail in this func
	for _,user in pairs(addup:getUsers()) do table.insert(_players, user) end
	for _,channel in pairs(addup:getLinks()) do
		for _,user in pairs(channel:getUsers()) do table.insert(_players, user) end
	end
	for _,user in pairs(_players) do
		local p = players[user:getName():lower()]
		if not isAdmin(user) then
			if not ec or (ec and not p.captain) then
				user:setMuted(true)
			end
		end
	end
end
function cmd.unmute(ctx)
	if ctx.admin == false then return end
	local _players = {}
	for _,user in pairs(addup:getUsers()) do table.insert(_players, user) end
	for _,channel in pairs(addup:getLinks()) do
		for _,user in pairs(channel:getUsers()) do table.insert(_players, user) end
	end
	for _,user in pairs(_players) do
		user:setMuted(false)
	end
	log(ctx.sender_name .. " unmuted everyone.")
end
function cmd.reload(ctx, args)
	--!reload admins from_file
	--!reload admins from_table
	if ctx.admin == false then return end
	if args[3] == "from_file" then
		_G[args[2]] = qlines(args[2]..".csv")
		log("Reloaded "..args[2].." (file->table)")
	elseif args[3] == "from_table" then
		write_to_file(args[2])
		log("Reloaded "..args[2].." (table->file)")
	end
end
function cmd.append(ctx, args)
	if ctx.admin == false then return end
	if #args < 3 then ctx.sender:message("Are you missing a parameter?") return end
	_G[args[2]][args[3]] = true
	write_to_file(args[2])
	log(ctx.sender_name.." committed "..args[3].." to table "..args[2])
	ctx.sender:message("Added "..args[3].." to table "..args[2])
end
function cmd.remove(ctx, args)
	if ctx.admin == false then return end
	if #args < 3 then ctx.sender:message("Are you missing a parameter?") return end
	_G[args[2]][args[3]] = nil
	write_to_file(args[2])
	log(ctx.sender_name.." removed "..args[3].." from table "..args[2])
	ctx.sender:message("removed "..args[3].." from table "..args[2])
end
	--[[an explanation for append and remove:
			in Lua tables you cannot remove values based simply on their 'value'. You can only remove based on index or key.
			finding an unknown index of a value you do know would involve looping which is a little more involved to write.
			in our very simple tables, every value is just a string. strings can be keys. If we want to detect and modify the value of a string
			we could just make the string the key of a meaningless value, then modify the value to identify it as existing or not existing.
	--]]
function cmd.copy(ctx, args)
	if ctx.admin == false then return end
	players[args[3]] = players[args[2]]
	--"!copy GamerA GamerB" 
	--GamerB takes on the data (med immunity, etc) of GamerA
	log("data copied: " ..args[2].."->"..args[3])
end
function cmd.fv(ctx, args)
	if ctx.admin == false then return end
	--fv Gamer1 Gamer2
	--Gamer1 is a med and Gamer2 is a civilian, but now they swap roles
	--as if Gamer2 had used !v
	local pOut, pIn = players[args[2]], players[args[3]]
	local nc = pOut.object:getChannel()
	if pOut.volunteered then
	log(args[2].." can't be volunteered for, they're already a volunteer.")
		return
	end
	pIn.object:move(nc)
	pIn.medicImmunity, pIn.volunteered, pIn.captain = true, true, true
	pOut.object:move(addup)
	pOut.medicImmunity, pOut.captain = false, false
	log("Force-volunteer, swapped med "..args[2].." for civilian "..args[3])		
end
function cmd.draftlock(ctx)
	if ctx.admin == false then return end
	draftlock = not draftlock
	if draftlock and dle then 
		addup:messager(ctx.sender_name .. " locked the draft!", ctx.sender) 
	else
		addup:messager(ctx.sender_name .. " unlocked the draft!", ctx.sender)
	end
	log(ctx.sender_name .. " toggled draft lock to " .. tostring(draftlock))
end
function cmd.sync(ctx)
	if ctx.admin == false then return end
	for _,server in ipairs(channelTable) do
		for _,room in pairs(server) do
			room.length = getlen(room.object)
		end
	end
	log("Updated channel lengths on the fly.")
	lenprintout()
end
function cmd.toggle(ctx, args)
	if ctx.admin == false then return end
	if args[2] == "dl" or args[2] == "dle" then
		dle = not dle
		sender:message("The draftlock system is now..")
		if dle then
			sender:message("On.")
			sender:message("Draftlocked?: "..tostring(draftlock))
		else
			sender:message("Off.")
		end
		log("Draftlock eligibility toggled to "..tostring(dle))
	elseif args[2] == "motd" then
		msgen = not msgen
		log("MOTD toggled to "..tostring(msgen).." by "..ctx.sender_name)
	end		
end
function cmd.mund(ctx)
	if ctx.admin == false then return end
	local t = {}
	for _,user in pairs(client:getUsers()) do
		local p = players[user:getName():lower()]
		if p.selfbotdeaf then
			user:setDeaf(false)
			p.selfbotdeaf = false
			table.insert(t, user:getName())
		end
	end
	log(ctx.sender_name .. " mass undeafened: " .. table.concat(t, " "))
end
function cmd.setmotd(ctx, args)
	if ctx.admin == false then return end
	motd = args[2]
	log("MOTD set to "..motd.." by "..ctx.sender_name)
end
function cmd.afkcheck(ctx, args)
	if ctx.admin == false then return end
	for _,user in pairs(addup:getUsers()) do
		if args[2] == nil or string.find(user:getName():lower(), args[2], 1, true) then
			user:requestStats()	
			log("Requested stats on " .. user:getName())		
		end
	end
end
function cmd.massadd(ctx, args)
	if ctx.admin == false then return end
	table.remove(args, 1)	--remove cmd name :)
	for _,user in ipairs(args) do
		local p = players[user:lower()]
		if not p then					--if given player doesn't exist
			players[user:lower()] = {
				medicImmunity = true	--bandaid solution
			}
		else
			p.medicImmunity = true
		end
	end
	log(ctx.sender_name .. " gave med immunity to " .. table.concat(args, ",", 2))
end
function cmd.readout(ctx, args)
	if ctx.admin == false then return end
	if type(_G[args[2]]) == "table" then
		ctx.sender:message("Attemping to readout from table...")
		for k,v in pairs(_G[args[2]]) do
			ctx.sender:message(args[2] .. ": k,v: " .. k .. ", " .. tostring(v))
		end
		ctx.sender:message("Finished reading from table...")
	else
		ctx.sender:message(args[2] .. ": " .. tostring(_G[args[2]]))
	end
end
function cmd.pmute(ctx, args)									--"perma" mute a user. (in vanilla mumble, if someone server muted reconnects, then they lose their muted status. This keeps this muted.
	if ctx.admin == false then return end
	local player = players[args[2]]
	local bool = not player.perma_mute				--if user is server muted (method isMuted() appears to not work)
	player.perma_mute = bool
	player.object:setMuted(bool)
end
function cmd.dpr(ctx, args)
	if ctx.admin == false then return end
	players[args[2]].imprison = false
	log("Released from prison: "..args[2])
end
--[[		User Commands		]]--
function cmd.v(ctx, args)
	if ctx.channel == addup or ctx.channel == fatkids or ctx.channel == connectlobby or ctx.channel == spacebase then
		local team = args[2]:lower()
		local server = tonumber(args[3])
		if server == 1 then
			server = channelTable[1]
		elseif server == 2 then
			server = channelTable[2]
		elseif server == 3 then
			server = channelTable[3]
		else
			if channelTable[1].red.length + channelTable[1].blu.length < 3 then
				server = channelTable[1]
			elseif channelTable[2].red.length + channelTable[2].blu.length < 3 then
				server = channelTable[2]
			elseif channelTable[3].red.length + channelTable[3].blu.length < 3 then
				server = channelTable[3]
			end
		end
		if server.red.length + server.blu.length < 3 then
			if team == "red" then
				team = server.red.object
			elseif team == "blu" or team == "blue" then
				team = server.blu.object
			end
			for _,user in pairs(team:getUsers()) do
				if players[user:getName():lower()].volunteered then return end					
				players[user:getName():lower()].medicImmunity = false
				players[user:getName():lower()].captain = false
				user:move(addup)
			end
			ctx.sender:move(team)
			local p = ctx.p_data				--data of the sender
			p.medicImmunity = true
			p.volunteered = true
			p.captain = true
			if getlen(team, true) < 1 then
				log(ctx.sender_name .. " has been imprisoned due to their volunteership.")
				ctx.sender:message("Thanks for volunteering! You've been temporarily imprisoned to this channel until the game is over to prevent trolling. If you believe there's been an error and wish to be imprisoned, ask an admin to release you.")
				p.imprison = team
			end
		else
			log("Nut City Error code 102")
		end
	else
		log("Nut City Error code 103")
		log(ctx.channel:getName().."*"..ctx.channel:getParent():getName())
	end
end
function cmd.rn(ctx)
	ctx.sender:message(string.reverse(ctx.sender_name))
end
function cmd.flip(ctx)
	math.randomseed(os.time())
	local r = math.random(1, 2)
	local c
	if r == 1 then
		c = ("Heads")
	else
		c = ("Tails")
	end
	ctx.channel:message(c.." (Coin flipped by "..ctx.sender_name..")")
end
function cmd.rng(ctx, args)
	math.randomseed(os.time())
	ctx.sender:message(tostring(math.random(tonumber(args[2]), tonumber(args[3]))))
end
function cmd.deaf(ctx)
	if ctx.p_data.selfbotdeaf == false then
		ctx.sender:setDeaf(true)
		ctx.p_data.selfbotdeaf = true
		log(ctx.sender_name .. " selfbot deafened.")
	else
		sender:message("Says here you're actually server deafened. Is this incorrect? Tell Zidgel.")
		log("Nut City Error 105")
		log("isDeaf", tostring(sender:isDeaf()))
	end
end
function cmd.undeaf(ctx)
	if ctx.p_data.selfbotdeaf == true then
		ctx.sender:setDeaf(false)
		ctx.p_data.selfbotdeaf = false
		log(ctx.sender_name .. " selfbot undeafened.")
	else
		sender:message("Says here you're not server deafened. Is this incorrect? Tell Zidgel.")
		log("Nut City Error 106")
		log("isDeaf", tostring(sender:isDeaf()))
	end
end
function cmd.qia(ctx, args)				--query is admin
	if admins[args[2]:lower()] then
		ctx.sender:message(args[2].." is an admin.")
	else
		ctx.sender:message(args[2].." is not an admin.")
	end
end

--Supplemental functions

function afkexpel(event)		--not a command
	local user = event.user
	if event.idlesecs > 300 then
		log(user:getName().." is idle, but not deafened, moving them. Mins:"..tostring(event.idlesecs/60))
		user:move(notplaying)
		user:message("Hey! I think you've been idle for 5 minutes so I'm moving you to chill room. You should move back into addup if you're here!")
	end
end

--[[==
LUA-MUMBLE HOOKS						**EXCEPT ON SERVER SYNC AHEMHEM.
	==]]--

client:hook("OnMessage", function(event)
	--[[
	channel:message("TEXT!") --send message to channel!
	event is a table with keys: "actor", "message", "users", "channels"
	]]--
	local msg = event.message
	msg = msg:gsub("<.+>", ""):gsub("\n*", ""):gsub("%s$", "")	--clean off html tags added by mumble, as well as trailing spaces and newlines.
	log("MSG FROM " .. event.actor:getName() .. " IN CHANNEL " .. event.actor:getChannel():getName() .. ": " .. msg)
	if string.find(msg, "!", 1) == 1 then
		parse(string.gsub(msg, "!", ""), {
				p_data = players[event.actor:getName():lower()], 
				admin = isAdmin(event.actor), 
				sender_name = event.actor:getName(),
				sender = event.actor,
				channel = event.actor:getChannel()})
	end
end)

client:hook("OnUserConnected", function(event)
	local name = event.user:getName():lower()
	for i,v in ipairs(warrants) do
		if v:lower() == name then
			event.user:ban("The ban hammer has spoken!")
			log("Banned " .. v .. " due to warrant!")
			warrants[i] = nil														--remove this warrant
			return
		end
	end
	log("USER CONNECT: "..event.user:getName())
	if players[name] == nil then
		players[name] = {
			object = event.user,
			volunteered = false,
			captain = false,
			channelB = event.user:getChannel(),
			dontUpdate = false,
			selfbotdeaf = false,
			perma_mute = false,
			imprison = false
		}
		if isMac(event.user:getName()) then
			players[name].medicImmunity = true
		else
			players[name].medicImmunity = false
		end
	else
		players[name].object = event.user
		players[name].volunteered = false
		players[name].captain = false
		players[name].channelB = event.user:getChannel()
		players[name].selfbotdeaf = false
		if players[name].perma_mute == true then
			event.user:setMuted(true)
		end
		if players[name].imprison then event.user:move(players[name].imprison) end
	end
	if msgen then
		event.user:message(motd)
	end
end)

client:hook("OnUserRemove", function(event)
	if event.user == nil then
		log("Nut City Error 104: Nil user remove")
		return --i dont know if this needs to be here but im somehow getting an error that event.user is nil?
	end
	local u = players[event.user:getName():lower()]
	log("USER DISCO/REM: "..event.user:getName(), false)
	if event.ban then
		log(event.user:getName() .. " banned by "..event.actor:getName().." with reason "..event.reason)
	end
	for _,server in ipairs(channelTable) do
		for _,room in pairs(server) do
			if room.object == u.channelB then
				room.length = room.length - 1
				return
			end
		end
	end
	--[[if getlen(root, true) < 2 then				--the world (and the bot) isn't ready yet I guess :(
		log("Automatically clearing medic history.")
		clear_medics()
	end]]--
end)

client:hook("OnUserChannel", function(event)	
	--When a user changes channels.
	--event is a table with keys: "user", "actor", "from", "to"
	if players[event.user:getName():lower()] == nil then
			return --user just connected
		end
	if players[event.user:getName():lower()].imprison then						--if user must be imprisoned in one channel
		if event.actor == event.user then event.user:message("Thanks for volunteering! You've been temporarily imprisoned to this channel until the game is over to prevent trolling. If you believe there's been an error and wish to be imprisoned, ask an admin to release you.") end	
		event.user:move(players[event.user:getName():lower()].imprison)
		return
	end
	if dle and draftlock and (event.to == addup or event.to == fatkids) and (event.from == connectlobby or event.from == notplaying) and not isAdmin(event.actor) then
			--using if event.from == connectlobby will exclude people moving in from other channels, like game channels or general, but thats a rare use case
			if event.actor ~= event.user then
				log(event.user:getName() .. " moved by " .. event.actor:getName() .. " from " .. event.from:getName() .. " to " .. event.to:getName())
			end
			log(event.user:getName() .. " tried to addup, was locked out.")
			event.user:move(connectlobby)
			event.user:message("Sorry! Picking has already started and you're late! If you believe you've been wrongly locked out, tell an admin. They'll move you.")
			--we COULD use a user.key to save the data of whether a person was in addup to allow people to reconnect and still addup, but that would be a lot of work so I'm not going to, lol
	else
		local u = players[event.user:getName():lower()]
		if u.dontUpdate == false then
			for _,server in ipairs(channelTable) do
				for _,room in pairs(server) do
					if event.from == room.object then
						room.length = room.length - 1
					elseif event.to == room.object then
						room.length = room.length + 1
					end
				end
			end
		else
			u.dontUpdate = false
		end
		u.channelB = event.to
	end
end)

client:hook("OnUserStats", afkexpel)

client:hook("OnTick", function()

end)

client:hook("OnChannelState", function(channel)

end)

client:hook("OnError", function(error_)		--I don't know why I'm using the underscore here haha whoops
	if client:isSynced() then
		log(error_)
	else																		--technically no error val is passed if not synced.
		print('Err, not synced')
	end
end)

while client:isConnected() do
	client:update()
	mumble.sleep(0.01)
end
