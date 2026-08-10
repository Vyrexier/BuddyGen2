local function Guard(Name, URL, RequireCallback)
	local Success, Result = pcall(function()
		return loadstring(game:HttpGet(URL, true))()
	end)

	if Success and Result then
		return Result
	end

	local RequireSuccess, RequireResult = pcall(RequireCallback)

	if RequireSuccess and RequireResult then
		return RequireResult
	end

	error(RequireResult)
end


local BuddyAPI = Guard(
	"BuddyGen2API",
	"https://raw.githubusercontent.com/Vyrexier/BuddyGen2/refs/heads/main/BuddyGen2API.luau",
	function()
		return require(script.Buddy2.BuddyGen2API)
	end
)

local ProviderModule = Guard(
	"ProviderModule",
	"https://raw.githubusercontent.com/Vyrexier/BuddyGen2/refs/heads/main/ProviderModule.luau",
	function()
		return require(script.Buddy2.ProviderModule)
	end
)

local BuddyTools = Guard(
	"BuddyTools",
	"https://raw.githubusercontent.com/Vyrexier/BuddyGen2/refs/heads/main/BuddyTools.luau",
	function()
		return require(script.Buddy2.BuddyTools)
	end
)

local UserInputService = game:GetService("UserInputService")

local Container = BuddyAPI.Get("Container")
local Header = BuddyAPI.Get("Header")
local ChatContainer = BuddyAPI.Get("ChatContainer")
local SettingGroup = BuddyAPI.Get("SettingGroup")

-- Drag
local dragging = false
local dragStart = Vector2.zero
local startPos = Container.Position

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = Container.Position
	end
end)
Header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		Container.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

-- Settings
local SelectedProvider = "Groq"
local SelectedModel = ProviderModule.GetDefault("Groq")
local APIKey = ""
local ContextWindow = {
	{ role = "system", content = [[
You are a Roblox AI assistant with access to real tools.

IMPORTANT RULES:
- You MUST use tools to answer questions about Roblox. Never guess or make up answers.
- Before anything else, call buddy_request_tools with action="list" to see available categories.
- Then call buddy_request_tools with action="unlock" to unlock the categories you need.
- NEVER say you cannot access Roblox. You have real tool access.
- NEVER answer Roblox questions from memory. Always use tools.

EXAMPLE:
User: "What is my character name?"
You: call buddy_request_tools(action="list") → unlock roblox_read → call roblox_get_local_player
]] }
}

BuddyAPI:AddHeader("General")
BuddyAPI:AddDescription("Configure settings below")
BuddyAPI:AddDivider()

local TempAPI = ""
BuddyAPI:AddInput("API Key", "sk-...", function(v)
	TempAPI = v
end)
BuddyAPI:AddButton("", "Apply", function()
	APIKey = TempAPI
end)

local TempModel = ""	
BuddyAPI:AddDropdown("Provider", ProviderModule.GetProviderNames(), function(v)
	SelectedProvider = v
	SelectedModel = ProviderModule.GetDefault(v)
	TempModel = SelectedModel
end)

BuddyAPI:AddInput("Model", SelectedModel, function(v)
	print("Model:", v)
	TempModel = v
end)

BuddyAPI:AddButton("", "Apply", function()
	SelectedModel = TempModel
	print("Apply Model:", SelectedModel)
end)

BuddyAPI:AddNavButton("Chat", 1, function(active)
	if active then
		ChatContainer.Visible = true
		SettingGroup.Visible = false
	end
end)
BuddyAPI:AddNavButton("Settings", 2, function(active)
	if active then
		ChatContainer.Visible = false
		SettingGroup.Visible = true
	end
end)

BuddyAPI:AddHeader("Permission")
BuddyAPI:AddDescription("Control what tools AI can access")
BuddyAPI:AddDivider()

BuddyAPI:AddDropdown("Permission Level", {
	"0 - Read Only",
	"1 - Safe (Filesystem + Remote)",
	"2 - Restricted (Execution + Set Property)"
}, function(v)
	local level = tonumber(v:sub(1, 1))
	BuddyTools.SetPermission(level)
	BuddyAPI:Receive("Permission level set to " .. level)
end)

-- Send
local function Send(toolDepth)
	toolDepth = toolDepth or 0
	if toolDepth >= 10 then
		BuddyAPI:Receive("Tool call limit reached")
		return
	end

	local tools = BuddyTools.GetToolList()

	ProviderModule.Send(SelectedProvider, SelectedModel, APIKey, ContextWindow, tools, function(ok, message)
		if not ok then
			warn("[Buddy] Provider Error:", message)
			BuddyAPI:Receive("Error: " .. tostring(message))
			return
		end

		if message.tool_calls then
			table.insert(ContextWindow, {
				role = "assistant",
				content = message.content,
				tool_calls = message.tool_calls
			})

			for _, toolCall in message.tool_calls do
				local success, result = BuddyTools.HandleToolCall(toolCall)

				table.insert(ContextWindow, {
					role = "tool",
					tool_call_id = toolCall.id,
					name = toolCall["function"].name,
					content = tostring(result)
				})
				
				print("[ToolCall]", toolCall["function"].name, result)
			end

			Send(toolDepth + 1)
		else
			table.insert(ContextWindow, {
				role = "assistant",
				content = message.content
			})
			BuddyAPI:Receive(message.content)
			print("[Receive]",message.content)
		end
	end)
end

BuddyAPI:AttachOnSend(function(msg)
	if APIKey == "" and SelectedProvider ~= "Local" then
		BuddyAPI:Receive("Please set API Key first")
		return
	end
	
	local content = msg
	if SelectedProvider == "Local" then
		content = msg .. " /no_think"
	end
	
	table.insert(ContextWindow, {
		role = "user",
		content = msg
	})
	
	print("[Selected Models",SelectedModel)
	print("[User]", msg)

	Send()
end)

BuddyTools.StartHooks()

