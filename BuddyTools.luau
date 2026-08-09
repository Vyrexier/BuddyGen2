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

local function GetTimeStamp()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

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
		"roblox_query",
		"roblox_get_local_player",
		"roblox_get_timestamp",
		"roblox_set_checkpoint",
		"roblox_get_checkpoint",
		"roblox_get_players",
		"roblox_get_property",
		"roblox_get_attribute",
		"roblox_get_attributes",
		"roblox_get_tags"
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

Tools["roblox_get_checkpoint"] = {
	Category = "roblox_read",

	Description = "Get the current search checkpoint.",

	Parameters = {
		type = "object",

		properties = {
			_placeholder = {
				type = "string",
				description = "Unused placeholder parameter"
			}
		},

		required = {}
	},

	Function = function()
		if not CurrentCheckpoint then
			return "Checkpoint is not set"
		end

		return HttpService:JSONEncode({
			Checkpoint = CurrentCheckpoint:GetFullName(),
			Name = CurrentCheckpoint.Name,
			ClassName = CurrentCheckpoint.ClassName
		})
	end
}

Tools["roblox_get_property"] = {
	Category = "roblox_read",

	Description = "Get a specific property value from a Roblox Instance.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the Instance, e.g. game.Workspace.Baseplate"
			},

			property = {
				type = "string",
				description = "Property name to read, e.g. Size, Position, Transparency"
			}
		},

		required = {
			"path",
			"property"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		local success, value = pcall(function()
			return instance[args.property]
		end)

		if not success then
			return "Unable to read property: " .. tostring(args.property)
		end

		return HttpService:JSONEncode({
			Path = instance:GetFullName(),
			Property = args.property,
			Value = tostring(value),
			Type = typeof(value)
		})
	end
}


Tools["roblox_get_attribute"] = {
	Category = "roblox_read",

	Description = "Get a specific Attribute from a Roblox Instance.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the Instance"
			},

			name = {
				type = "string",
				description = "Attribute name to read"
			}
		},

		required = {
			"path",
			"name"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		local value = instance:GetAttribute(args.name)

		if value == nil then
			return "Attribute not found: " .. tostring(args.name)
		end

		return HttpService:JSONEncode({
			Path = instance:GetFullName(),
			Name = args.name,
			Value = tostring(value),
			Type = typeof(value)
		})
	end
}


Tools["roblox_get_attributes"] = {
	Category = "roblox_read",

	Description = "Get all Attributes from a Roblox Instance.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the Instance"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		local attributes = instance:GetAttributes()

		return HttpService:JSONEncode({
			Path = instance:GetFullName(),
			Attributes = attributes
		})
	end
}


Tools["roblox_get_tags"] = {
	Category = "roblox_read",

	Description = "Get all CollectionService tags assigned to a Roblox Instance.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the Instance"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		local tags = CollectionService:GetTags(instance)

		return HttpService:JSONEncode({
			Path = instance:GetFullName(),
			Tags = tags
		})
	end
}

Tools["roblox_get_players"] = {
	Category = "roblox_read",

	Description = "Get information about all players currently in the game. Optionally include Character information.",

	Parameters = {
		type = "object",

		properties = {
			include_character = {
				type = "boolean",
				description = "Include Character information such as path and position"
			}
		},

		required = {}
	},

	Function = function(args)
		local results = {}

		for _, player in Players:GetPlayers() do
			local data = {
				Name = player.Name,
				DisplayName = player.DisplayName,
				UserId = player.UserId,
				AccountAge = player.AccountAge,
			}

			if args.include_character then
				local character = player.Character

				if character then
					data.Character = {
						Name = character.Name,
						Path = character:GetFullName(),
						ClassName = character.ClassName,
					}

					local humanoid = character:FindFirstChildOfClass("Humanoid")
					local root = character:FindFirstChild("HumanoidRootPart")

					if humanoid then
						data.Character.Humanoid = {
							Health = humanoid.Health,
							MaxHealth = humanoid.MaxHealth,
						}
					end

					if root then
						data.Character.Position = {
							X = math.round(root.Position.X * 100) / 100,
							Y = math.round(root.Position.Y * 100) / 100,
							Z = math.round(root.Position.Z * 100) / 100,
						}
					end
				end
			end

			table.insert(results, data)
		end

		return HttpService:JSONEncode(results)
	end
}

Tools["roblox_get_local_player"] = {
	Category = "roblox_read",

	Description = "Get information about the local player. Optionally include Character information.",

	Parameters = {
		type = "object",

		properties = {
			include_character = {
				type = "boolean",
				description = "Include Character information"
			}
		},

		required = {}
	},

	Function = function(args)
		local player = Players.LocalPlayer

		if not player then
			return "LocalPlayer is not available"
		end

		local result = {
			Name = player.Name,
			DisplayName = player.DisplayName,
			UserId = player.UserId,
			AccountAge = player.AccountAge
		}

		if args.include_character then
			local character = player.Character

			result.Character = character and {
				Name = character.Name,
				Path = character:GetFullName(),
				ClassName = character.ClassName
			} or nil
		end

		return HttpService:JSONEncode(result)
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
			Instance = cloneref(inst),
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

Tools["roblox_get_cached"] = {
	Category = "roblox_cache",

	Description = "Get a cached instance by key",

	Parameters = {
		type = "object",

		properties = {
			key = {
				type = "string",
				description = "Key to retrieve"
			}
		},

		required = {
			"key"
		}
	},

	Function = function(args)
		local data = InstanceCache[args.key]

		if not data then
			return "Cache key not found: " .. tostring(args.key)
		end

		local instance = data.Instance

		if not instance then
			return "Cached instance is no longer available: " .. tostring(args.key)
		end

		local alive = instance.Parent ~= nil

		return HttpService:JSONEncode({
			Key = args.key,
			Path = data.Path,
			Description = data.Description,
			Name = instance.Name,
			ClassName = instance.ClassName,
			Alive = alive
		})
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
		local root = args.root and ResolvePath(args.root) or CurrentCheckpoint
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

Tools["roblox_list_children"] = {
	Category = "roblox_read",

	Description = "List the direct children of an instance by path",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the instance, e.g. game.Workspace"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		local children = instance:GetChildren()

		if #children == 0 then
			return "No children found: " .. instance:GetFullName()
		end

		local results = {}

		for _, child in children do
			table.insert(results, {
				Name = child.Name,
				ClassName = child.ClassName,
				Path = child:GetFullName()
			})
		end

		return HttpService:JSONEncode(results)
	end
}

Tools["roblox_get_timestamp"] = {
	Category = "roblox_read",

	Description = "Get the current UTC timestamp in ISO 8601 format",

	Parameters = {
		type = "object",

		properties = {
			_placeholder = {
				type = "string",
				description = "Unused placeholder parameter"
			}
		},

		required = {}
	},

	Function = function()
		return GetTimeStamp()
	end
}

Tools["roblox_set_checkpoint"] = {
	Category = "roblox_read",

	Description = "Set the current search checkpoint to a Roblox Instance path. Future queries without a root will search from this checkpoint.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Instance path to use as the new search checkpoint. Example: game.Workspace"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		CurrentCheckpoint = instance

		return HttpService:JSONEncode({
			Checkpoint = instance:GetFullName(),
			Name = instance.Name,
			ClassName = instance.ClassName
		})
	end
}

Tools["roblox_fire_click_detector"] = {
	Category = "roblox_interaction",

	Description = "Simulate a ClickDetector click.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the ClickDetector"
			},

			distance = {
				type = "number",
				description = "Optional click distance"
			},

			event = {
				type = "string",
				description = "Optional ClickDetector event name"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		if not instance:IsA("ClickDetector") then
			return "Instance is not a ClickDetector: " .. instance:GetFullName()
		end

		local success, err = pcall(function()
			fireclickdetector(
				instance,
				args.distance,
				args.event
			)
		end)

		if not success then
			return "Failed to fire ClickDetector: " .. tostring(err)
		end

		return HttpService:JSONEncode({
			Path = instance:GetFullName(),
			Success = true
		})
	end
}

Tools["roblox_fire_proximity_prompt"] = {
	Category = "roblox_interaction",

	Description = "Simulate triggering a ProximityPrompt.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the ProximityPrompt"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		if not instance:IsA("ProximityPrompt") then
			return "Instance is not a ProximityPrompt: " .. instance:GetFullName()
		end

		local success, err = pcall(function()
			fireproximityprompt(instance)
		end)

		if not success then
			return "Failed to fire ProximityPrompt: " .. tostring(err)
		end

		return HttpService:JSONEncode({
			Path = instance:GetFullName(),
			Success = true
		})
	end
}

Tools["roblox_fire_touch_interest"] = {
	Category = "roblox_interaction",

	Description = "Simulate a touch event between two BaseParts.",

	Parameters = {
		type = "object",

		properties = {
			part1 = {
				type = "string",
				description = "Path to the first BasePart"
			},

			part2 = {
				type = "string",
				description = "Path to the second BasePart"
			},

			toggle = {
				type = "number",
				description = "Touch state: 0 = begin touch, 1 = end touch"
			}
		},

		required = {
			"part1",
			"part2",
			"toggle"
		}
	},

	Function = function(args)
		local part1 = ResolvePath(args.part1)
		local part2 = ResolvePath(args.part2)

		if not part1 then
			return "Instance not found: " .. tostring(args.part1)
		end

		if not part2 then
			return "Instance not found: " .. tostring(args.part2)
		end

		if not part1:IsA("BasePart") then
			return "part1 is not a BasePart: " .. part1:GetFullName()
		end

		if not part2:IsA("BasePart") then
			return "part2 is not a BasePart: " .. part2:GetFullName()
		end

		if args.toggle ~= 0 and args.toggle ~= 1 then
			return "toggle must be 0 or 1"
		end

		local success, err = pcall(function()
			firetouchinterest(
				part1,
				part2,
				args.toggle
			)
		end)

		if not success then
			return "Failed to fire TouchInterest: " .. tostring(err)
		end

		return HttpService:JSONEncode({
			Part1 = part1:GetFullName(),
			Part2 = part2:GetFullName(),
			Toggle = args.toggle,
			Success = true
		})
	end
}

Tools["roblox_execute_code"] = {
	Category = "roblox_execution",

	Description = "Execute Luau code locally in Roblox and return the result.",

	Parameters = {
		type = "object",

		properties = {
			code = {
				type = "string",
				description = "Luau code to execute"
			}
		},

		required = {
			"code"
		}
	},

	Function = function(args)
		if type(args.code) ~= "string" or args.code == "" then
			return "Code is required"
		end

		local fn, compileError = loadstring(args.code)

		if not fn then
			return "Syntax Error: " .. tostring(compileError)
		end

		local success, result = pcall(fn)

		if not success then
			return "Runtime Error: " .. tostring(result)
		end

		return tostring(result)
	end
}

Tools["roblox_decompile_script"] = {
	Category = "roblox_execution",

	Description = "Decompile a Roblox Script, LocalScript, or ModuleScript and return its source code.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the Script, LocalScript, or ModuleScript"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		local instance = ResolvePath(args.path)

		if not instance then
			return "Instance not found: " .. tostring(args.path)
		end

		if not (
			instance:IsA("Script")
				or instance:IsA("LocalScript")
				or instance:IsA("ModuleScript")
			) then
			return "Instance is not a script: " .. instance:GetFullName()
		end

		local success, result = pcall(function()
			return decompile(instance)
		end)

		if not success then
			return "Failed to decompile script: " .. tostring(result)
		end

		return tostring(result)
	end
}

--// Filesystem
local function CheckFilesystemFunction(name)
	local fn = getgenv and getgenv()[name] or _G[name]

	if type(fn) ~= "function" then
		return nil, name .. " is not available"
	end

	return fn
end

Tools["fs_read_file"] = {
	Category = "filesystem",

	Description = "Read the contents of a file from the executor filesystem.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the file"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "File path is required"
		end

		local fn, err = CheckFilesystemFunction("readfile")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to read file: " .. tostring(result)
		end

		return tostring(result)
	end
}


Tools["fs_write_file"] = {
	Category = "filesystem",

	Description = "Write content to a file in the executor filesystem.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the file"
			},

			content = {
				type = "string",
				description = "Content to write"
			}
		},

		required = {
			"path",
			"content"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "File path is required"
		end

		if type(args.content) ~= "string" then
			return "Content must be a string"
		end

		local fn, err = CheckFilesystemFunction("writefile")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path, args.content)

		if not success then
			return "Failed to write file: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			Success = true
		})
	end
}


Tools["fs_append_file"] = {
	Category = "filesystem",

	Description = "Append content to an existing file.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the file"
			},

			content = {
				type = "string",
				description = "Content to append"
			}
		},

		required = {
			"path",
			"content"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "File path is required"
		end

		if type(args.content) ~= "string" then
			return "Content must be a string"
		end

		local fn, err = CheckFilesystemFunction("appendfile")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path, args.content)

		if not success then
			return "Failed to append file: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			Success = true
		})
	end
}


Tools["fs_delete_file"] = {
	Category = "filesystem",

	Description = "Delete a file from the executor filesystem.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the file"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "File path is required"
		end

		local fn, err = CheckFilesystemFunction("delfile")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to delete file: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			Success = true
		})
	end
}


Tools["fs_list_files"] = {
	Category = "filesystem",

	Description = "List files and folders inside an executor filesystem directory.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Folder path to list"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "Folder path is required"
		end

		local fn, err = CheckFilesystemFunction("listfiles")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to list files: " .. tostring(result)
		end

		if type(result) ~= "table" then
			return tostring(result)
		end

		return HttpService:JSONEncode(result)
	end
}


Tools["fs_make_folder"] = {
	Category = "filesystem",

	Description = "Create a folder in the executor filesystem.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Folder path to create"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "Folder path is required"
		end

		local fn, err = CheckFilesystemFunction("makefolder")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to create folder: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			Success = true
		})
	end
}


Tools["fs_delete_folder"] = {
	Category = "filesystem",

	Description = "Delete a folder from the executor filesystem.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Folder path to delete"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "Folder path is required"
		end

		local fn, err = CheckFilesystemFunction("delfolder")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to delete folder: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			Success = true
		})
	end
}


Tools["fs_is_file"] = {
	Category = "filesystem",

	Description = "Check whether a filesystem path is a file.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to check"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "Path is required"
		end

		local fn, err = CheckFilesystemFunction("isfile")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to check file: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			IsFile = result == true
		})
	end
}


Tools["fs_is_folder"] = {
	Category = "filesystem",

	Description = "Check whether a filesystem path is a folder.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to check"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "Path is required"
		end

		local fn, err = CheckFilesystemFunction("isfolder")
		if not fn then
			return err
		end

		local success, result = pcall(fn, args.path)

		if not success then
			return "Failed to check folder: " .. tostring(result)
		end

		return HttpService:JSONEncode({
			Path = args.path,
			IsFolder = result == true
		})
	end
}


Tools["fs_load_file"] = {
	Category = "filesystem",

	Description = "Load and execute a Luau file from the executor filesystem.",

	Parameters = {
		type = "object",

		properties = {
			path = {
				type = "string",
				description = "Path to the Luau file"
			}
		},

		required = {
			"path"
		}
	},

	Function = function(args)
		if type(args.path) ~= "string" or args.path == "" then
			return "File path is required"
		end

		local fn, err = CheckFilesystemFunction("loadfile")
		if not fn then
			return err
		end

		local success, loaded, loadError = pcall(fn, args.path)

		if not success then
			return "Failed to load file: " .. tostring(loaded)
		end

		if not loaded then
			return "Load Error: " .. tostring(loadError)
		end

		if type(loaded) ~= "function" then
			return HttpService:JSONEncode({
				Path = args.path,
				Success = true,
				Type = typeof(loaded)
			})
		end

		local executeSuccess, result = pcall(loaded)

		if not executeSuccess then
			return "Runtime Error: " .. tostring(result)
		end

		return tostring(result)
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

	print("[BuddyTools] Tools sent:", #list)
	for _, t in list do
		print(" -", t["function"].name)
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
