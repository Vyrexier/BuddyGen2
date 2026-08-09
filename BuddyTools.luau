local cloneref = cloneref or function(i:Instance) return i end
local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local CollectionService = cloneref(game:GetService("CollectionService"))

local ToolModule = {}
local InstanceCache = {}

-- Session state
local UnlockedCategories = {}
local InstanceCache = {}
local CurrentCheckpoint = game

local function ResolvePath(path)
	if path == "game" then return game end

	local current = game
	for name in string.gmatch(path, "[^%.]+") do
		if name ~= "game" then
			current = current:FindFirstChild(name)
			if not current then return nil end
		end
	end
	return current
end

-- Categories และ description สั้นๆ
local CategoryInfo = {
	roblox_read = "Find, search, list instances, get player info",
	roblox_cache = "Cache and retrieve instances for later use",
	roblox_interaction = "Fire click detectors, proximity prompts, touch events",
	roblox_execution = "Execute Luau code, decompile scripts",
	filesystem = "Read, write, delete files and folders"
}

local Categories = {
	roblox_read = {
		"roblox_list_children",
		"roblox_find_instance",
		"roblox_search_instances",
		"roblox_get_local_player",
		"roblox_get_timestamp",
		"roblox_set_checkpoint",
		"roblox_get_instances_in_radius"
	},
	roblox_cache = {
		"roblox_cache_instance",
		"roblox_get_cached",
		"roblox_list_cache",
		"roblox_clear_cache"
	},
	roblox_interaction = {
		"roblox_fire_click_detector",
		"roblox_fire_proximity_prompt",
		"roblox_fire_touch_interest"
	},
	roblox_execution = {
		"roblox_execute_code",
		"roblox_decompile_script"
	},
	filesystem = {
		"fs_read_file",
		"fs_write_file",
		"fs_append_file",
		"fs_delete_file",
		"fs_list_files",
		"fs_make_folder",
		"fs_delete_folder",
		"fs_is_file",
		"fs_is_folder",
		"fs_load_file"
	}
}

local Tools = {}

Tools["buddy_request_tools"] = {
	Description = "List available tool categories or unlock them. Call list first, then unlock what you need.",
	Parameters = {
		type = "object",
		properties = {
			action = {
				type = "string",
				enum = {"list", "unlock"},
				description = "list = show categories, unlock = request access"
			},
			categories = {
				type = "array",
				items = { type = "string" },
				description = "Categories to unlock (only for unlock action)"
			}
		},
		required = {"action"}
	},
	Function = function(args)
		if args.action == "list" then
			local result = {}
			for name, desc in CategoryInfo do
				table.insert(result, name .. ": " .. desc)
			end
			return table.concat(result, "\n")

		elseif args.action == "unlock" then
			local unlocked = {}
			for _, cat in args.categories do
				if CategoryInfo[cat] then
					UnlockedCategories[cat] = true
					table.insert(unlocked, cat)
				end
			end
			return "Unlocked: " .. table.concat(unlocked, ", ")
		end
	end
}

Tools["roblox_cache_instance"] = {
	Category = "roblox_cache",
	Description = "Cache an instance by path for later use",
	Parameters = {
		type = "object",
		properties = {
			path = { type = "string", description = "Instance path to cache" },
			key = { type = "string", description = "Key to store under" },
			description = { type = "string", description = "Note about what this instance is" }
		},
		required = {"path", "key"}
	},
	Function = function(args)
		local inst = ResolvePath(args.path)
		if not inst then return "Not found: " .. args.path end
		InstanceCache[args.key] = {
			Instance = inst,
			Path = inst:GetFullName(),
			Description = args.description or ""
		}
		return "Cached: " .. args.key .. " : " .. inst:GetFullName()
	end
}

Tools["roblox_list_cache"] = {
	Category = "roblox_cache",
	Description = "List all cached instances",
	Parameters = {
		type = "object"
	},
	Function = function(args)
		local entries = {}
		for key, data in InstanceCache do
			local alive = data.Instance and data.Instance.Parent ~= nil
			table.insert(entries, {
				Key = key,
				Path = data.Path,
				Description = data.Description,
				Alive = alive
			})
		end
		if #entries == 0 then return "Cache is empty" end
		return HttpService:JSONEncode(entries)
	end
}

Tools["roblox_clear_cache"] = {
	Category = "roblox_cache",
	Description = "Clear a specific key or all cache",
	Parameters = {
		type = "object",
		properties = {
			key = { type = "string", description = "Key to clear. Leave empty to clear all" }
		},
		required = {}
	},
	Function = function(args)
		if args.key and args.key ~= "" then
			if not InstanceCache[args.key] then
				return "Key not found: " .. args.key
			end
			InstanceCache[args.key] = nil
			return "Cleared: " .. args.key
		end
		local count = 0
		for _ in InstanceCache do count += 1 end
		InstanceCache = {}
		return "Cleared all cache (" .. count .. " entries)"
	end
}

Tools["roblox_query"] = {
	Category = "roblox_read",
	Description = "Query instances with flexible filters. Supports name fuzzy match, ClassName, property value, tag, and radius search. Returns full path of each result.",
	Parameters = {
		type = "object",
		properties = {
			root = { type = "string", description = "Root path to search from. Default: game" },
			name = { type = "string", description = "Fuzzy name match e.g. 'Base' matches 'Baseplate'" },
			class_name = { type = "string", description = "Exact ClassName e.g. Part, Script, RemoteEvent" },
			tag = { type = "string", description = "CollectionService tag to filter by" },
			property = {
				type = "object",
				description = "Filter by property value e.g. {name='BrickColor', value='Bright red'}",
				properties = {
					name = { type = "string" },
					value = { type = "string" }
				}
			},
			radius = {
				type = "object",
				description = "Search within radius of a position",
				properties = {
					x = { type = "number" },
					y = { type = "number" },
					z = { type = "number" },
					distance = { type = "number" }
				}
			},
			depth = { type = "number", description = "Max search depth. Default: 5" },
			limit = { type = "number", description = "Max results. Default: 20" }
		},
		required = {}
	},
	Function = function(args)
		local root = args.root and ResolvePath(args.root) or game
		if not root then return "Root not found: " .. args.root end

		local depth = args.depth or 5
		local limit = args.limit or 20
		local results = {}

		-- Fuzzy match helper
		local function fuzzyMatch(a, b)
			return a:lower():find(b:lower(), 1, true) ~= nil
		end

		-- Property match helper
		local function matchProperty(inst, prop)
			local ok, val = pcall(function()
				return tostring(inst[prop.name])
			end)
			return ok and val == prop.value
		end

		-- Radius check helper
		local function inRadius(inst, r)
			local pos = Vector3.new(r.x, r.y, r.z)
			local ok, instPos = pcall(function()
				return inst:IsA("BasePart") and inst.Position
			end)
			if not ok or not instPos then return false end
			return (instPos - pos).Magnitude <= r.distance
		end

		local function search(inst, currentDepth)
			if currentDepth <= 0 or #results >= limit then return end

			for _, child in inst:GetChildren() do
				local pass = true

				-- Name fuzzy
				if args.name and not fuzzyMatch(child.Name, args.name) then
					pass = false
				end

				-- ClassName
				if pass and args.class_name and child.ClassName ~= args.class_name then
					pass = false
				end

				-- Tag
				if pass and args.tag and not CollectionService:HasTag(child, args.tag) then
					pass = false
				end

				-- Property
				if pass and args.property and not matchProperty(child, args.property) then
					pass = false
				end

				-- Radius
				if pass and args.radius and not inRadius(child, args.radius) then
					pass = false
				end

				if pass then
					table.insert(results, {
						Name = child.Name,
						ClassName = child.ClassName,
						Path = child:GetFullName()
					})
				end

				search(child, currentDepth - 1)
			end
		end

		if args.tag and not args.name and not args.class_name and not args.property and not args.radius then
			local tagged = CollectionService:GetTagged(args.tag)
			for _, inst in tagged do
				if #results >= limit then break end
				table.insert(results, {
					Name = inst.Name,
					ClassName = inst.ClassName,
					Path = inst:GetFullName()
				})
			end
		else
			search(root, depth)
		end

		if #results == 0 then return "No instances found" end
		return HttpService:JSONEncode(results)
	end
}

function ToolModule.GetToolList()
	local list = {}

	table.insert(list, {
		type = "function",
		["function"] = {
			name = "buddy_request_tools",
			description = Tools["buddy_request_tools"].Description,
			parameters = Tools["buddy_request_tools"].Parameters
		}
	})

	for cat in UnlockedCategories do
		local catTools = Categories[cat]
		if catTools then
			for _, toolName in catTools do
				local tool = Tools[toolName]
				if tool then
					table.insert(list, {
						type = "function",
						["function"] = {
							name = toolName,
							description = tool.Description,
							parameters = tool.Parameters
						}
					})
				end
			end
		end
	end

	return list
end

function ToolModule.HandleToolCall(toolCall)
	local name = toolCall["function"].name
	local tool = Tools[name]

	if not tool then
		return false, "Unknown tool: " .. name
	end

	local ok, args = pcall(HttpService.JSONDecode, HttpService, toolCall["function"].arguments)
	if not ok then return false, "Invalid arguments" end

	local success, result = pcall(tool.Function, args)
	if not success then return false, "Error: " .. tostring(result) end

	return true, tostring(result)
end

function ToolModule.ClearSession()
	UnlockedCategories = {}
	InstanceCache = {}
	CurrentCheckpoint = game
end

return ToolModule
