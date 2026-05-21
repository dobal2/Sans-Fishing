local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")

local EVENT_ID = "2712534918105268896"
local PROMPT_DELAY = 30

local player = Players.LocalPlayer

task.wait(PROMPT_DELAY)

-- 이미 RSVP 상태인지 확인 후 프롬프트
local ok, status = pcall(function()
	return SocialService:GetEventRsvpStatusAsync(EVENT_ID)
end)

if ok and status == Enum.RsvpStatus.Going then
	return
end

pcall(function()
	SocialService:PromptRsvpToEventAsync(EVENT_ID)
end)
