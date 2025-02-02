local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local seeker_queue = {}

local game_status = 0

local seeker
local hiders = {}
local painters = {}

local TIMER = {
	PRE_GAME = 10,
	HIDING = 30,
	SEEKING = 180,
	VOTING = 5,
	WINNER = 10,
	ALERT = 5
}

local DESTINATION = {
	ARENA = "ARENA",
	SPAWN = "SPAWN"
}

function Teleport(player, input)
	local teleport_part
	
	if input == DESTINATION["SPAWN"] then
		teleport_part = workspace.Spawnbox.Transparent.Spawn
		--destination = CFrame.new(math.random(-20,60), 67, math.random(-35,55))
	elseif input == DESTINATION["ARENA"] then
		teleport_part = workspace.Arena
		--destination = CFrame.new(math.random(20,60), 5, math.random(-20,20))
	end
	
	local spawn_x = teleport_part.Position.X
	local spawn_y = teleport_part.Position.Y + 2.5
	local spawn_z = teleport_part.Position.Z
	
	--print(spawn_x, spawn_y, spawn_z)

	local radius_x = teleport_part.Size.X/2 - 2
	local radius_z = teleport_part.Size.Z/2 - 2

	local x_low = spawn_x - radius_x
	local x_high = spawn_x + radius_x
	local z_low = spawn_z - radius_z
	local z_high = spawn_z + radius_z

	local destination = CFrame.new(math.random(x_low, x_high), spawn_y, math.random(z_low, z_high))
	
	player.Character.HumanoidRootPart.CFrame = destination
	
	--player.Character.Head.Anchored = true
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local cameraEvent = ReplicatedStorage.CanvasCameraEvent
local foundEvent = ReplicatedStorage.FoundCanvasEvent
local resetEvent = ReplicatedStorage.ResetStarsEvent

function attempt_start()
	
	while true do -- game loop. if too many players quit then we want to return to here
		while game_status == 0 do
			while game_status == 0 do
				
				for _, player in ipairs(seeker_queue) do
					if player_exists(player) then
						player.PlayerGui.DrawGui.Timer.Text = "Need at least 2 players to start the game"
					end
					
				end

				if #seeker_queue >= 2 then
					game_status = 1
					break
				end
				
				task.wait(1)
			end
			
			for timer = TIMER["PRE_GAME"], 1, -1 do
				local loop_count = 0
				for _, player in ipairs(seeker_queue) do
					if player_exists(player) then
						player.PlayerGui.DrawGui.Timer.Text = "Starting game in " .. timer .. " seconds"
					end
					if loop_count > 10 then
						break
					end
					loop_count += 1
				end
				
				if #seeker_queue < 2 then
					game_status = 0
					break
				end

				task.wait(1)
				
				-- automatically remove alerts that have been around for 5 seconds
				if timer == 5 then
					for _, player in ipairs(seeker_queue) do
						if player_exists(player) then
							player.PlayerGui.DrawGui.Alert.Visible = false
						end
					end
				end
				
			end
		end
		
		start_game()
	end
end

function start_game()
	
	-- clear paintings first
	for _, player in ipairs(seeker_queue) do
		if player_exists(player) then
			player.PlayerGui.DrawGui.MainFrame:ClearAllChildren()
		end
	end
	
	table.clear(painters)
	
	select_seeker()
	
	if game_status == 0 then
		return
	end
	
	-- leave seeker in waiting room
	-- teleport all hiders to the arena
	-- create timer for hiders to find a hiding spot for their painting
	hiding_phase()
	
	if game_status == 0 then
		return
	end
	
	-- after time expires
		-- seeker teleported and can begin seeking
		-- painters who placed a canvas can begin painting
		--their model becomes invisible and untouchable and immoveable
		-- painters who didnt place canvas will spectate seeker
		-- during spectating, player cannot move?
	
	-- after seeker finds a painting and clicks on it
		-- painting is removed
		-- hider can no longer paint
		-- hider sent back to lobby
		-- player can move, no longer be invisible, and be touchable
		-- if all painters are now found, end the timer
		-- check for player disconnects
	seeking_phase()
	
	if game_status == 0 then
		return
	end
	
	-- game is over. time to vote
		-- makes it so seeker leaving or players leaving doesnt stop the vote from occuring
	game_status = 0
	
	-- if timer expires or all painters found
		-- create a new timer for voting
		-- everyone votes on their favorite painting (cannot vote for themself)
		-- must determine how to display this for mobile users
		-- remove disconnect players from the list before it is shown
	local vote_tally = voting_phase()
	
	-- after voting, declare a winner (or tie)
		-- create timer to show winner, then after timer attempt to start another round
	winner_phase(vote_tally)
	
	-- function exits and returns to attempt_start() which has a forever while loop to try to make another game
end

function select_seeker()
	seeker = table.remove(seeker_queue, 1)
	
	-- used for when seeker clicks the canvas
		-- should be limited to one attribute and thus overwrite the previous one
	workspace:SetAttribute("seeker", seeker.Name)
	
	hiders = table.clone(seeker_queue)

	table.insert(seeker_queue, seeker)
end

function hiding_phase()
	for _, hider in ipairs(hiders) do
		if player_exists(hider) then
			-- teleport hider to arena
			Teleport(hider, DESTINATION["ARENA"])

			-- activate painting placer GUI
			hider.PlayerGui.DrawGui.PlaceCanvas.Visible = true
		end
	end
	
	for timer = TIMER["HIDING"], 1, -1 do
		for _, hider in ipairs(hiders) do
			if player_exists(hider) then
				-- update player hiding timer GUIs
				if hider.PlayerGui.DrawGui.PlaceCanvas.Visible then
					hider.PlayerGui.DrawGui.Timer.Text = "You have " .. timer .. " seconds left to hide your painting!"
				else
					hider.PlayerGui.DrawGui.Timer.Text = timer .. " seconds until you can begin painting!"
				end
			end
		end
		
		-- update seeker timer gui
		if player_exists(seeker) then
			seeker.PlayerGui.DrawGui.Timer.Text = timer .. " seconds until you can begin seeking!"
		end
		
		-- abort method if seeker leaves or all hiders left
		if game_status == 0 then
			-- abort game
			return
		end
		
		task.wait(1)
	end
end

local CAMERA = {
	PLAYER = "player",
	CANVAS = "canvas",
	SEEKER = "seeker"
}

-- seeker/painting phase
function seeking_phase()
	-- teleport seeker to arena
	if player_exists(seeker) then
		Teleport(seeker, DESTINATION["ARENA"])
	end	
	
	for _, hider in ipairs(hiders) do
		print(hider.Name .. " being sent to spawn!")
		if player_exists(hider) then			
			-- send hider to spawn
			--hider.Character.Head.Anchored = false
			Teleport(hider, DESTINATION["SPAWN"])
				
			-- and freeze them. force them to spectate their painting
			hider.Character.Humanoid.WalkSpeed = 0
			hider.Character.Humanoid.JumpPower = 0
			--hider.Character.Head.Anchored = true
			
			-- if hider placed a painting, they are a hider and a painter
			if workspace:FindFirstChild("canvas".. hider.Name) then
				print(hider.Name .. " has a canvas?")

				--cameraEvent:FireClient(hider, CAMERA["CANVAS"])
				table.insert(painters, hider)
				
				-- activate painting GUI
				hider.PlayerGui.DrawGui.CanvasFrame.Visible = true
				--hider.PlayerGui.DrawGui.Options.Visible = true
				
				hider.PlayerGui.DrawGui.ReplaceCanvas.Visible = false
				
			-- player didnt place a painting. not a hider nor a painter
			else
				-- deactivate painting placer GUI
				hider.PlayerGui.DrawGui.PlaceCanvas.Visible = false
				
				hider.PlayerGui.DrawGui.Spectating.Visible = true
				hider.PlayerGui.DrawGui.Timer.Text = "Waiting for current game to end!"
				
				cameraEvent:FireClient(hider, CAMERA["SEEKER"])
				table.remove(hiders, table.find(hiders, hider))
			end
		end
	end
	
	for timer = TIMER["SEEKING"], 1, -1 do
		-- update painter GUI
		for _, painter in ipairs(painters) do
			if player_exists(painter) then
				-- GUI for painter still hiding
				if table.find(hiders, painter) then
					painter.PlayerGui.DrawGui.Timer.Text = "You have " .. timer .. " seconds left to finish your painting!"
					
				-- GUI for painter caught
				else
					painter.PlayerGui.DrawGui.Timer.Text = timer .. " seconds left for the seeker to find the other painters!"
				end
			end
		end
		
		-- update seeker timer gui
		if player_exists(seeker) then
			seeker.PlayerGui.DrawGui.Timer.Text = "You have " .. timer .. " seconds left to find everyone's painting!"
		end

		-- abort method if seeker leaves or all hiders left
		if game_status == 0 then
			-- abort game
			return
		end
		
		print("# hiders: " .. #hiders)
		
		-- if seeker has found every painting
		if #hiders == 0 then
			-- add alert "The seeker has won by finding everyone! The painting with the most votes will also get a win!"
			
			
			
			
			-- add seeker win
			seeker.leaderstats:FindFirstChild("Seeker Wins").Value += 1
			
			-- task.wait(5)
			return
		end
		
		task.wait(1)
	end
	
	-- time is up
		-- add alert "Time is up! The seeker didn't find everyone, undiscovered hiders get a win. The painting with the most votes will also get a win!"
		
	-- add hider win to those not found
	for _, hider in ipairs(hiders) do
		if player_exists(hider) then
			hider.leaderstats:FindFirstChild("Hider Wins").Value += 1
			
			-- remove painting as time is up
			hider.PlayerGui.DrawGui.MainFrame.Visible = false
			hider.PlayerGui.DrawGui.Options.Visible = false
		end
	end
		-- task.wait(5)
end


function voting_phase()
	-- allow all hiders to move again?
	-- teleport all hiders to the spawn
	for _, hider in ipairs(hiders) do
		if player_exists(hider) then
			Teleport(hider, DESTINATION["SPAWN"])
			
			hider.Character.Humanoid.WalkSpeed = 16
			hider.Character.Humanoid.JumpPower = 50
			--hider.Character.Head.Anchored = false
		end
	end
	
	-- teleport seeker to the spawn
	if player_exists(seeker) then
		Teleport(seeker, DESTINATION["SPAWN"])
	end
	
	-- show all players to vote for from painters table (will only contain those with paintings)
	for _, player in ipairs(Players:GetChildren()) do
		if player_exists(player) then
			-- disable spectating GUI
			player.PlayerGui.DrawGui.Spectating.Visible = false
			
			-- enable other player painting frame
			--player.PlayerGui.DrawGui.VoteFrame.Visible = true
			
			cameraEvent:FireClient(player, CAMERA["PLAYER"])
		end
	end
	
-- vote all at once:
	--for timer = TIMER["VOTING"], 0, -1 do
	--	for _, player in ipairs(Players:GetChildren()) do
	--		if player_exists(player) then
	--			-- update timer
	--			player.PlayerGui.DrawGui.Timer.Text = "You have " .. timer .. " seconds left to vote for your favorite painting!"


	--		end
	--	end
		
	--	-- if everyone has voted, skip remaining timer
		
	--	task.wait(1)
	--end
	
	local vote_tally = {}
	
-- vote one at a time:	
	for _, painter in ipairs(painters) do
		local current_tally = 0
		
		-- allow players to vote
		if player_exists(painter) then
			for _, player in ipairs(Players:GetChildren()) do
				if player_exists(player) then
					-- set voting GUI to painter
					local vote_painting = painter.PlayerGui.DrawGui.MainFrame:Clone()
					vote_painting.Parent = player.PlayerGui.DrawGui
					vote_painting.Visible = true
					
					local template = player.PlayerGui.DrawGui.TemplateFrame
					vote_painting.Position = template.Position
					
					Debris:AddItem(vote_painting, TIMER["VOTING"])
					
					if player == painter then -- player cannot vote for themself
						-- disable voting GUI
						player.PlayerGui.DrawGui.StarFrame.Visible = false

						---- set voting GUI to painter
						--local painting = painter.PlayerGui.DrawGui.MainFrame
						--player.PlayerGui.DrawGui.VoteFrame = painting:Clone()
						
					else -- player is voting for someone that isnt themself
						-- reset voting stars
						resetEvent:FireClient(player)
						
						-- enable voting GUI
						player.PlayerGui.DrawGui.StarFrame.Visible = true
					end
				end
			end
			
			-- timer
			for timer = TIMER["VOTING"], 1, -1 do
				for _, player in ipairs(Players:GetChildren()) do
					if player_exists(player) then
						if player == painter then -- player cannot vote for themself
							-- update timer
							player.PlayerGui.DrawGui.Timer.Text = "Waiting " .. timer .. " seconds for other players to vote for you"
						else -- player is voting for someone that isnt themself
							-- update timer
							player.PlayerGui.DrawGui.Timer.Text = "You have " .. timer .. " seconds left to vote for " .. painter.Name
						end
					end
				end
				
				task.wait(1)
			end
			
			-- keep tally of votes
			for _, player in ipairs(Players:GetChildren()) do
				if player_exists(player) then
					if player ~= painter then
						current_tally += player:GetAttribute("score")
					end
				end
			end
		end
		
		table.insert(vote_tally, current_tally)
	end
	
	-- disable voting GUI
	for _, player in ipairs(Players:GetChildren()) do
		if player_exists(player) then
			-- disable frame GUI
			--player.PlayerGui.DrawGui.VoteFrame.Visible = false
			
			-- disable voting GUI
			player.PlayerGui.DrawGui.StarFrame.Visible = false
		end
	end
	
	return vote_tally
end


function winner_phase(vote_tally)
	-- determine painting winner
	local max_val = 0
	local max_player = {nil}
	
	for i, painter in ipairs(painters) do
		if max_val < vote_tally[i] then
			max_val = vote_tally[i]
			max_player = {painter}
		elseif max_val == vote_tally[i] then
			table.insert(max_player, painter)
		end
	end
	
	print(max_player)
	print(max_val)
	
	-- give winner a painting win
	-- max_player table has the list of winners, 1 or many.
	for _, winners in ipairs(max_player) do
		if player_exists(winners) then
			winners.leaderstats:FindFirstChild("Painting Wins").Value += 1
		end
	end
	
	-- show winning painting
	for _, player in ipairs(Players:GetChildren()) do
		if player_exists(max_player[1]) and player_exists(player) then
			-- set painting GUI to winner
			local winner_painting = max_player[1].PlayerGui.DrawGui.MainFrame:Clone()
			winner_painting.Parent = player.PlayerGui.DrawGui
			winner_painting.Visible = true

			local template = player.PlayerGui.DrawGui.TemplateFrame
			winner_painting.Position = template.Position

			Debris:AddItem(winner_painting, TIMER["WINNER"])
			
			--local painting = max_player[1].PlayerGui.DrawGui.MainFrame:Clone()
			--player.PlayerGui.DrawGui.VoteFrame = painting:Clone()
		end
	end
	
	-- possibly remove and just show winner during pre-game timer
	for timer = TIMER["WINNER"], 1, -1 do
		for _, player in ipairs(Players:GetChildren()) do
			if player_exists(player) then
				-- update timer
				player.PlayerGui.DrawGui.Timer.Text = timer .. " seconds left until the next game"


			end
		end
		task.wait(1)
	end
end

Players.PlayerAdded:Connect(function(player)
	workspace:WaitForChild(player.Name)
	
	task.wait(0.5)
	
	table.insert(seeker_queue, player)
	
	if game_status == 1 then
		player.PlayerGui.DrawGui.Spectating.Visible = true
		player.PlayerGui.DrawGui.Timer.Text = "Waiting for current game to end!"
		cameraEvent:FireClient(player, CAMERA["SEEKER"])
	end
end)

Players.PlayerRemoving:Connect(function(player)
	table.remove(seeker_queue, table.find(seeker_queue, player))
	
	if game_status == 1 then
		if seeker == player then
			-- abort game (seeker left)
			game_status = 0
			
			for _, player in ipairs(Players:GetChildren()) do
				if player_exists(player) then
					player.PlayerGui.DrawGui.Alert.Visible = true
					player.PlayerGui.DrawGui.Alert.Text = "The seeker has left the game!"
				end
			end
			
			-- removed after 5 seconds by attempt_start()
			
		elseif table.find(hiders, player) then -- player is hider
			table.remove(hiders, table.find(hiders, player))
			-- perhaps another check if we are in the painting phase and he is last painter?
			if table.find(painters, player) then
				table.remove(painters, table.find(painters, player))
			end
			
		elseif table.find(painters, player) then -- player is painter who is no longer hiding
			table.remove(painters, table.find(painters, player))
		else
			-- player is not hider or seeker, so not of consequence to the game
		end
	end
end)

function player_exists(player)
	return player and player:FindFirstChild("PlayerGui")
end

--[[
function alert(specific_player, alert_text, timer_text)
	if specific_player then
		if player_exists(specific_player) then
			specific_player.PlayerGui.DrawGui.Alert.Visible = true
			specific_player.PlayerGui.DrawGui.Alert.Text = alert_text
		end
		
		task.wait(TIMER["ALERT"])
		
		if player_exists(specific_player) then
			specific_player.PlayerGui.DrawGui.Alert.Visible = false
		end
		
		-- no timer, since it is just player specific, like being caught. not timer specific
		
	else -- not a specific player, so for all players
		
		for _, player in ipairs(Players:GetChildren()) do
			if player_exists(player) then
				player.PlayerGui.DrawGui.Alert.Visible = true
				player.PlayerGui.DrawGui.Alert.Text = alert_text
			end
		end

		for timer = TIMER["ALERT"], 0, -1 do
			for _, player in ipairs(Players:GetChildren()) do
				if player_exists(player) then
					-- update timer
					player.PlayerGui.DrawGui.Timer.Text = timer_text
				end
			end

			task.wait(1)
		end

		for _, player in ipairs(Players:GetChildren()) do
			if player_exists(player) then
				player.PlayerGui.DrawGui.Alert.Visible = false
			end
		end
		
	end
end
]]

-- seeker found a canvas, delete it and make hider caught
foundEvent.OnServerEvent:Connect(function(_, target)
	print("found event!")
	local hider_name = string.gsub(target.Name, "canvas", "", 1)

	target:Destroy()

	local hider = Players:FindFirstChild(hider_name)
	print(hider)

	-- hider will be unfrozen?
	hider.Character.Humanoid.WalkSpeed = 16
	hider.Character.Humanoid.JumpPower = 50
	
	-- hider can choose to spectate seeker?
	hider.PlayerGui.DrawGui.Spectating.Visible = true
	cameraEvent:FireClient(hider, CAMERA["SEEKER"])

	--stop hider from painting
	hider.PlayerGui.DrawGui.MainFrame.Visible = false
	hider.PlayerGui.DrawGui.Options.Visible = false

	-- remove player from hiding
	table.remove(hiders, table.find(hiders, hider))
end)

-- attempt to start game
attempt_start()



