local cloneref = cloneref or function(v) return v end
local HttpService = cloneref(game:GetService("HttpService"))

local Providers = {
	Groq = {
		URL = "https://api.groq.com/openai/v1/chat/completions",
		Default = "llama-3.3-70b-versatile",
		Headers = function(apiKey)
			return {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. apiKey
			}
		end,
		Body = function(model, messages , tools)
			return HttpService:JSONEncode({
				model = model,
				messages = messages,
				tools = tools
			})
		end,
		Parse = function(body)
			local data = HttpService:JSONDecode(body)
			if data.error then
				return false, data.error.message
			end
			return true, data.choices[1].message
		end
	},
}

local function GetHeaders(provider, apiKey)
	local config = Providers[provider]
	if not config or not config.Headers then
		return false
	end
	return config.Headers(apiKey)
end

local function GetBody(provider, model, messages , tools)
	local config = Providers[provider]
	if not config or not config.Body then
		return false
	end
	return config.Body(model, messages , tools)
end

local function ParseResponse(provider, body)
	local config = Providers[provider]
	if not config or not config.Parse then
		return false, "No parser for provider: " .. tostring(provider)
	end
	return config.Parse(body)
end

local Module = {}

function Module.GetDefault(provider)
	return Providers[provider] and Providers[provider].Default or ""
end

function Module.GetProviderNames()
	local names = {}
	for name in Providers do
		table.insert(names, name)
	end
	return names
end

function Module.Send(provider, model, apiKey, messages, tools , callback)
	local config = Providers[provider]
	if not config then
		callback(false, "Unknown provider: " .. tostring(provider))
		warn("Unknown provider: " .. tostring(provider))
		return
	end
	
	task.spawn(function()
		local ok, response = pcall(function()
			return request({
				Url = config.URL,
				Method = "POST",
				Headers = GetHeaders(provider, apiKey),
				Body = GetBody(provider, model, messages , tools)
			})
		end)

		if not ok then
			callback(false, "Request failed: " .. tostring(response))
			warn("[Provider]".."Request failed: " .. tostring(response))
			return
		end

		if not response.Success then
			callback(false, "HTTP " .. tostring(response.StatusCode).."\n" .. tostring(response.Body))
			warn("[Provider]"..tostring(response.StatusCode).."\n" .. tostring(response.Body))
			return
		end

		callback(ParseResponse(provider, response.Body))
	end)
end

return Module
