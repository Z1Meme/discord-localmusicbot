local discordia = require("discordia");--load discordia library
local client = discordia.Client();--define discordia client object
local json = require("json");--load json library
discordia.extensions() -- load all helpful extensions
local status = "!!help";
local prefix = "!!";

function log(stuff)
	local time = os.date("*t");
	local month, day, hour, min, sec = time.month, time.day, time.hour, time.min, time.sec;
	if #tostring(time.month) ~=2 then month = "0"..month end;
	if #tostring(time.day) ~=2 then day = "0"..day end;
	if #tostring(time.hour) ~=2 then hour = "0"..hour end;
	if #tostring(time.min) ~=2 then min = "0"..min end;
	if #tostring(time.sec) ~=2 then sec = "0"..sec end;
	local currentTime = time.year.."-"..month.."-"..day.." "..hour..":"..min..":"..sec;
	print(currentTime.." "..stuff);
end

client:on("ready", function()
	log("Bot started");
	client:setGame(status)
	log("Set prefix to: '"..prefix.."'");
	log("Set status to 'Playing "..status.."'");
end)

local File = {
	DirExists = function(filename)--checks if a directory exists
		local ok, err, code = os.rename(filename)
   		if not ok then
      		if code == 13 then
        		-- Permission denied, but it exists
        		return true
      		end
   		end
   		return ok, err
	end,
	Exists = function(filename)--checks if a file exists
		local f=io.open(filename,"r")
   		if f~=nil then io.close(f) return true else return false end
   	end,
	Read = function(filename)--reads json files
		local file = io.open (filename..".json", "r");
		return json.decode(file);--returns json file as lua table
	end,
	Write = function(filename, data)--writes json files
		local file = io.open (filename..".json", "w");
		if not file then log("Can't write to file"); else
			file:write(json.encode(data,{indent=true}));
			file:close();
		end
	end,
};

function FYShuffle(tInput)--shuffles an array
	--**I did not make this function, it was taken from https://stackoverflow.com/questions/35572435/how-do-you-do-the-fisher-yates-shuffle-in-lua
	math.randomseed(os.time())
    local tReturn = {}
    for i = #tInput, 1, -1 do
        local j = math.random(i)
        tInput[i], tInput[j] = tInput[j], tInput[i]
        table.insert(tReturn, tInput[i])
    end
    return tReturn
end

local queue = {};--queue of all songs to play
local musicpath = "music/"
local play = false;
local state = "disconnected" --states: disconnected, idle, paused, playing

local Reply = function(m, t, d, c, del)--message, title, description, color, self-destruct (bot message)
	local r = m:reply{
		embed={
			author={
				name=m.author.tag,
				icon_url=m.author.avatarURL
			},
			color=c,
			title=t,
			description=d,
		},
	};
	if del then
		coroutine.wrap(function()--"timer" is locally blocking so wrapping it in a coroutine fixes that
			require("timer").sleep(6000)
			r:delete()
		end)()
	end
	return r;
end

local concatParams = function(param)
	local params = "";
	if param then
		for i=1, #param do
			if i==1 then
				params = param[i]
			else
				params = params.." "..param[i]
			end
		end
	end
	return params;
end

local GetVoiceChannel = function(msg, t)--returns voice channel of author of msg or of client
	for voice in msg.guild.voiceChannels:iter() do
		for user in voice.connectedMembers:iter() do
			if t == "user" then
				if user.id == msg.author.id then
					return voice;
				end
			elseif t == "client" then
				if user.id == client.user.id then
					return voice;
				end
			end
		end
	end
end

local joinChannel = function(message)--bot will join the channel that the current user is in
	local channel = client:getChannel(GetVoiceChannel(message, "user").id);
	connection = channel:join();
	state = "idle";
end

local playSong = function(message)--plays a specified song defined by queue
	coroutine.wrap(function()
		while queue[1] and play do
			if queue[2] then
				Reply(message, [[Now playing: "]]..queue[1]..[["]], [[Next up: "]]..queue[2]..[["]], 255);
			else
				Reply(message, [[Now playing: "]]..queue[1]..[["]], "Next up: N/A", 255);
			end
			log("Playing: "..queue[1]);
			state = "playing";
			connection:playFFmpeg("music/"..queue[1]..".mp3");
			log("Song over");
			state = "idle";
			table.remove(queue, 1);
		end
	end)()
end

local pickSong = function(message, songs)
	--gives user a prompt to pick which song if there are conflicts
	--uses a "page" system to list each conflicting song
	--click an arrow emoji to change page
end

local commands = {
	{name="help",desc="Help command"}, 
	{name="list",desc="Lists all songs in music directory"},
	{name="play",desc="Plays a specified song"},
	{name="pause",desc="Pauses a song if one is playing"},
	{name="resume",desc="Resumes a paused song"},
	{name="stop",desc="Stops a song if one is playing"},
	{name="leave",desc="Disconnects the bot from a voice channel"},
	{name="shuffle",desc="Plays songs in a random order"},
	{name="skip",desc="Skips the currently playing song"},
	{name="request",desc="Sends a specified mp3 file through text chat"}
};

commands.help = function(message)
	local msg = "";
	for i=1,#commands do
		if commands[i].params then
			msg = msg..prefix..commands[i].name..": "..commands[i].desc.." Parameters: "..commands[i].params[1].."\n"
		else
			msg = msg..prefix..commands[i].name..": "..commands[i].desc.."\n"
		end;
	end;
	Reply(message, "Help:", msg, 255)
end;

commands.list = function(message, param)
	local list = "";
	for file in io.popen([["dir music\" /b]]):lines() do
		if string.find(file,".mp3") then print(file) end--TODO
		list = list..string.gsub(file, ".mp3", "")
	end

	local file = io.open ("list.txt", "w");
	if not file then log("Can't write to file"); else
		file:write(list);
		file:close();
	end
	Reply(message, "All songs:", "", 255):reply{
		file = "list.txt"
	};
end;

commands.play = function(message, param)
	local params = concatParams(param);
	play = true;

	if state == "idle" or state == "disconnected" then
		if GetVoiceChannel(message, "user") ~= nil then
			local found = false;
			local matches = {};
			joinChannel(message)
			for file in io.popen([[dir "music/" /b]]):lines() do
				if string.find(file, ".mp3") and string.match(file:lower(), params:lower()) then
					found = true;
					table.insert(matches, string.sub(file, 1, -6));--adds matched song to matches array (for use when multiple matches are found, allows user to pick one to play)
				end
			end
			if not found then
				Reply(message, "Song not found", "There were no song matches to: "..params, 16711680, true);
			else
				if matches[2] then--if multiple matches found, reply to user with matches
					local m = "";--concats matches into string with line breaks
					local params = "";
					for i=1, #matches do
						if i==1 then
							m = matches[i]
						else
							m = m.."\n"..matches[i]
						end
					end
					Reply(message, "Multiple matches found:", m, 255)

				else--if only one match, play matched song
					table.insert(queue, matches[1]);
					state = "playing";
					playSong(message);
				end
			end
		else
			Reply(message, "You must be in a voice channel to use commands", "", 16711680, true);
		end
	else
		if GetVoiceChannel(message, "user") then
			if GetVoiceChannel(message, "user").id == GetVoiceChannel(message, "client").id then
				local found = false;
				for file in io.popen([[dir "music/" /b]]):lines() do
					if string.find(file, ".mp3") and string.match(file:lower(), params:lower()) then
						if found == false then
							found = true;
							print("Found match: "..file);
							table.insert(queue, string.sub(file, 1, -6));
							Reply(message, [[Queueing song: "]]..string.sub(file, 1, -6)..[["]], "Position: "..#queue, 255);
						end
					end
				end
				if found == false then
					Reply(message, "Song not found", "There were no song matches to: "..params, 16711680, true);
				end

			else
				Reply(message, "You must be in the same voice channel as the bot to use commands", "", 16711680, true);
			end
		else
			Reply(message, "You must be in a voice channel to use commands", "", 16711680, true);
		end
	end
end

commands.pause = function(message)
	if state == "paused" then
		local reply = Reply(message, "Music is already paused", "", 16711680, true);
	elseif state == "playing" then
		paused = Reply(message, "Paused", "", 255);
		state = "paused";
		connection:pauseStream();
	else
		Reply(message, "Nothing is playing", "", 16711680, true);
	end
end

commands.resume = function(message)
	if state == "paused" then
		Reply(message, "Resuming", "", 255, true);
		state = "playing";
		paused:delete();
		connection:resumeStream();
	else
		Reply(message, "Nothing is paused", "", 16711680, true);
	end
end

commands.stop = function(message)
	if state == "playing" or "paused" then
		connection:stopStream();
		state = "idle";
		play = false;
		queue = {};--clears queue
		Reply(message, "Stopping", "", 255, true);
	else
		Reply(message, "Nothing is playing", "", 16711680, true);
	end
end

commands.leave = function(message)
	if state ~= "disconnected" then
		queue = {};--clears queue
		state = "disconnected";
		play = false;--tells bot to not play more music
		connection:stopStream();
		connection:close();
		Reply(message, "Left Channel", "", 255, true);
	else
		Reply(message, "Not connected to voice channel", "", 16711680, true);
	end
end

commands.shuffle = function(message, param)
	--parameter should be in the form of a directory ex: "mymusic/favorites"
	--this would allow for songs from subfolders to be easily played
	local params = concatParams(param);
	if params ~= "" then--play music from the specified playlist
		local musicpath = musicpath..params;
		if File.Exists(musicpath) and not string.find(file,".mp3") then
			for dir in io.popen([[dir "]]..musicpath..[[" /b /ad]]):lines() do 
				if string.find(file,".mp3") then 
					song = string.sub(file, 1, -6);
					table.insert(shuffle, song);
				end
			end
		else
			Reply(message, "Specified path does not exist", "", 16711680, true);
		end
	else--play music from all playlists
		local shuffle = {};
		for file in io.popen([[dir "]]..musicpath..[[" /b]]):lines() do
			if string.find(file,".mp3") then 
				song = string.sub(file, 1, -6);
				table.insert(shuffle, song);
			end
		end
		if state == "idle" or state == "disconnected" then
			if GetVoiceChannel(message, "user") ~= nil then
				queue = FYShuffle(shuffle);--shuffles songs and adds them to queue
				state = "playing";
				play = true;
				joinChannel(message);
				playSong(message);
			else
				Reply(message, "You must be in a voice channel to use commands", "", 16711680, true, true);
			end
		else
			if GetVoiceChannel(message, "user") ~= nil then
				if GetVoiceChannel(message, "user").id == GetVoiceChannel(message, "client").id then
					local shuffled = FYShuffle(shuffle);
					for i=1, #shuffled do
						table.insert(queue, shuffled[i]);
					end
					Reply(message, "Queued "..(#queue-1).." songs", [[Next up: "]]..queue[2]..[["]], 255);
				else
					Reply(message, "You must be in the same voice channel as the bot to use commands", "", 16711680, true);
				end
			else
				Reply(message, "You must be in a voice channel to use commands", "", 16711680, true);
			end
		end

	end
end

commands.skip = function(message)
	if state == "playing" or state == "paused" then
		if GetVoiceChannel(message, "user") ~= nil then
			if GetVoiceChannel(message, "user").id == GetVoiceChannel(message, "client").id then
				Reply(message, "Skipping", "", 255, true);
				connection:stopStream();
				state = "idle";
			else
				Reply(message, "You must be in the same voice channel as the bot to use commands", "", 16711680, true);
			end
		else
			Reply(message, "You must be in a voice channel to use commands", "", 16711680, true);
		end
	else
		Reply(message, "Nothing is playing", "", 16711680, true);
	end
end

commands.request = function(message, param)--sends a specified mp3 file in chat
	--allow subfolder mp3s to be requested
	local params = concatParams(param);
	local found = false;
	for file in io.popen([[dir "music/" /b]]):lines() do
		if string.find(file, ".mp3") and string.match(file:lower(), params:lower()) then
			if found == false then
				found = true;
				print("Found match: "..file);
				local m = message;
				local r = Reply(message, "Sending file: ".."\""..string.sub(file, 1, -6)..".mp3\"", "", 255);
				r:reply{
					file = musicpath..string.sub(file, 1, -6)..".mp3"
				};
				r:setEmbed{
					author={
						name=m.author.tag,
						icon_url=m.author.avatarURL
					},
					color=255,
					title="Here is your requested file:",
				};
			end
		end
	end
	if found == false then
		Reply(message, "File does not exist", [[There were no matches to: "]]..params..[["]], 16711680, true)
	end

end

commands.send = function(message, param)
	Reply(message, "Command unavailable", [["]]..[[send" is not available yet]], 16711680, true)
	--allows a user to send an mp3 file to the bot to save to a specified playlist (TODO)
end

local function callCommand(command, message, param)
	if command == "help" then
		commands.help(message);
	elseif command == "list" then
		commands.list(message);
	elseif command == "play" then
		commands.play(message, param);
	elseif command == "pause" then
		commands.pause(message);
	elseif command == "resume" then
		commands.resume(message);
	elseif command == "stop" then
		commands.stop(message);
	elseif command == "leave" then
		commands.leave(message);
	elseif command == "shuffle" then
		commands.shuffle(message)
	elseif command == "skip" then
		commands.skip(message);
	elseif command == "request" then
		commands.request(message, param);
	elseif command == "send" then
		commands.send(message, param);
	else
		Reply(message, "Invalid command", [["]]..command..[[" is not a valid command]], 16711680, true);
	end
end

local function checkCommand(content, message, param)--checks if a valid command has been typed
	local command = content:gsub(prefix, '');
	if string.sub(content, 1, #prefix) == prefix then
		callCommand(command, message, param);
		message:delete();--deletes user's message
	end
end

client:on("messageCreate", function(message)
	--checks for commands
	if message.member.id ~= client.user.id then
		if string.find(message.content, prefix) then
			log(message.author.tag..": "..message.content);--prints commands directed at bot
		end
		local args = message.content:split(" ") -- split all arguments into a table
		local params = {};
		for i=2, #args do
			params[i-1] = args[i]--adds all args indexes to params besides [1]
		end
		checkCommand(args[1], message, params);--checks if last message was a command
	end
end)

client:run("Bot "..io.open("./login.txt"):read());