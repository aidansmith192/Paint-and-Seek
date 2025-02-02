local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- incoming from client
local removeEvent = ReplicatedStorage.RemoveCanvasEvent
local finishEvent = ReplicatedStorage.FinishCanvasEvent
local placeEvent = ReplicatedStorage.PlaceCanvasEvent

-- outgoing to client
local alertEvent = ReplicatedStorage.AlertEvent
local cameraEvent = ReplicatedStorage.CanvasCameraEvent


local canvas_template = workspace.MainCanvas

local Players = game:GetService("Players")

local CAMERA = {
	PLAYER = "player",
	CANVAS = "canvas",
	SEEKER = "seeker"
}



function is_player_too_far(player, mouse_position, camera_position)
	local pos

	local vector_dist_diff

	if true then
		-- based on avatar
		pos = CFrame.lookAt(mouse_position, player.Character.HumanoidRootPart.Position)

		vector_dist_diff = player.Character.HumanoidRootPart.Position - mouse_position
	else
		-- based on camera
		pos = CFrame.lookAt(mouse_position, camera_position)

		vector_dist_diff = camera_position - mouse_position
	end

	local dist = math.sqrt(math.pow(vector_dist_diff.X, 2) + math.pow(vector_dist_diff.Y, 2) + math.pow(vector_dist_diff.Z, 2))
	if dist > 30 then
		alertEvent:FireClient(player, "Too far away!")
		return true
	end
	return false
end

function ray_cast(player, camera_position, mouse_position)
	local player_character_list = {}
	for _, p in ipairs(Players:GetChildren()) do
		if not player then
			continue
		end
		table.insert(player_character_list, p.Character)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = player_character_list
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayOrigin = camera_position
	local ray_direction = CFrame.lookAt(camera_position, mouse_position)

	local raycastResult = workspace:Raycast(rayOrigin, ray_direction.LookVector * 1000, raycastParams)

	if raycastResult then
		-- Print all properties of the RaycastResult if it exists
		--print(`Ray intersected with: {raycastResult.Instance:GetFullName()}`)
		--print(`Intersection position: {raycastResult.Position}`)
		--print(`Distance between ray origin and result: {raycastResult.Distance}`)
		--print(`The normal vector of the intersected face: {raycastResult.Normal}`)
		--print(`Material hit: {raycastResult.Material.Name}\n`)

		--block.CFrame = CFrame.new(target_part.Position, target_part.Position + raycastResult.Normal)
		--block.CFrame = CFrame.lookAt(mouse_position, mouse_position + raycastResult.Normal)

		--block.Orientation = raycastResult.Normal
		--block.Rotation = raycastResult.Normal
		--block.CFrame = block.CFrame.Position * raycastResult.Normal

	else
		--print("Nothing was hit")
		alertEvent:FireClient(player, "Too far away!")
	end
	return raycastResult
end

placeEvent.OnServerEvent:Connect(function(player, mouse_position, camera_position)
	
	if workspace:FindFirstChild("canvas"..player.Name) then
		workspace:FindFirstChild("canvas"..player.Name):Destroy()
	end
	
	-- check if player is too far
	if is_player_too_far(player, mouse_position, camera_position) then
		return
	end
	
	-- we need the vector normal to the surface, so we use raycast to get it
	local raycastResult = ray_cast(player, camera_position, mouse_position)
	if not raycastResult then -- if ray cast is over 1000 studs away
		return
	end
	
	local another = canvas_template:Clone()
	another.Parent = workspace
	another.Name = "canvas" .. player.Name 

	local touch_test = canvas_template:Clone()
	touch_test.Parent = workspace
	touch_test.Name = "test"


	-- first we take the normal vector, which is a unit vector (distance of 1)
	-- then we need to mask this to our canvas Z size, so that we push it to be flush with the surface
	-- finally we need the "look_at_position" which is the position plus the normal vector, to get the new position it should face!
	local unit_vector_normal = raycastResult.Normal
	local half_size = another.Size.Z / 2
	local adjusted_normal_vector = half_size * unit_vector_normal
	
	local canvas_position = mouse_position + adjusted_normal_vector
	local look_at_position = mouse_position + raycastResult.Normal
	
	another.CFrame = CFrame.lookAt(canvas_position, look_at_position)
	
	
	
	-- check if canvas placed on spawn or any part we dont want to allow!
	local touching_bad = touch_test:GetTouchingParts()
	if #touching_bad ~= 0 then
		for _, v in touching_bad do
			if (v.Name == "bad") or string.match(v.Name, "canvas") then
				--print("touching!!!")
				another:Destroy()
				touch_test:Destroy()
				
				if v.Name == "bad" then
					alertEvent:FireClient(player, "Cannot place canvas on spawn!")
				else
					alertEvent:FireClient(player, "Cannot place canvas on another canvas!")
				end
				return
			end
		end
	end
	
	-- check if anything touches canvas (bad)
	local touching_canvas = another:GetTouchingParts()
	if #touching_canvas ~= 0 then
		--print("touching!!!")
		another:Destroy()
		touch_test:Destroy()

		alertEvent:FireClient(player, "Canvas needs more room!")
		return
	end
	
	player.PlayerGui.DrawGui.PlaceCanvas.Visible = false
	player.PlayerGui.DrawGui.ReplaceCanvas.Visible = true
	
	touch_test:Destroy()
	
	player.Character.Humanoid.WalkSpeed = 0
	player.Character.Humanoid.JumpPower = 0
	--player.Character.Head.Anchored = true
	cameraEvent:FireClient(player, CAMERA["CANVAS"])
end)

removeEvent.OnServerEvent:Connect(function(player)
	if workspace:FindFirstChild("canvas"..player.Name) then
		workspace:FindFirstChild("canvas"..player.Name):Destroy()
	end
	player.PlayerGui.DrawGui.PlaceCanvas.Visible = true
	player.PlayerGui.DrawGui.ReplaceCanvas.Visible = false
	
	player.Character.Humanoid.WalkSpeed = 16
	player.Character.Humanoid.JumpPower = 50
	player.Character.Head.Anchored = false
	cameraEvent:FireClient(player, CAMERA["PLAYER"])
end)

finishEvent.OnServerEvent:Connect(function(player)
	local frame = player.PlayerGui.DrawGui.MainFrame:Clone()
	frame.Position = UDim2.new(.5,0,.5,0) -- fixes offset produced by mainframe
	frame.Visible = true
	
	if workspace:FindFirstChild("canvas" .. player.Name) then
		if workspace:FindFirstChild("canvas" .. player.Name).SurfaceGui:FindFirstChild("MainFrame") then
			workspace:FindFirstChild("canvas" .. player.Name).SurfaceGui:FindFirstChild("MainFrame"):Destroy()
		end
	end
	
	frame.Parent = workspace:FindFirstChild("canvas" .. player.Name).SurfaceGui
end)