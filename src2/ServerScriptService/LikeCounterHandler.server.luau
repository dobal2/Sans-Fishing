-- Handles LikeCounter countdown display.
-- Moved from workspace.LikeCounter.LeadBoardPart.Script

local function waitForLeadBoard()
	local likeCounter = workspace:WaitForChild("LikeCounter", 30)
	if not likeCounter then return end
	local part = likeCounter:WaitForChild("LeadBoardPart", 10)
	if not part then return end
	local surfaceGui = part:WaitForChild("SurfaceGui", 10)
	if not surfaceGui then return end
	local container = surfaceGui:WaitForChild("Container", 10)
	if not container then return end
	local textLabel = container:WaitForChild("Text", 10)
	if not textLabel then return end

	local TARGET_TIME = os.time({ year = 2025, month = 8, day = 30, hour = 8, min = 0, sec = 0 })

	while true do
		local timeLeft = TARGET_TIME - os.time()
		if timeLeft <= 0 then
			textLabel.Text = "Update!"
		else
			local days    = math.floor(timeLeft / 86400)
			local hours   = math.floor((timeLeft % 86400) / 3600)
			local minutes = math.floor((timeLeft % 3600) / 60)
			local seconds = timeLeft % 60
			textLabel.Text = string.format("%02d:%02d:%02d:%02d", days, hours, minutes, seconds)
		end
		task.wait(1)
	end
end

task.spawn(waitForLeadBoard)
