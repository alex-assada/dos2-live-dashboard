-- DOS2 Script Extender - server side bootstrap
-- Collects live player/party data and posts it to http://localhost:3000/update.
--
-- Place this file in your mod's Script Extender server bootstrap path.
-- Typical location inside mod package: Mods/<YourModUUID>/Story/RawFiles/Lua/BootstrapServer.lua

local TARGET_URL = "http://localhost:3000/update"
local UPDATE_INTERVAL_SECONDS = 1.5

local function log(msg)
    if Ext and Ext.Utils and Ext.Utils.Print then
        Ext.Utils.Print("[DOS2 Dashboard] " .. tostring(msg))
    end
end

local function safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function safeGet(obj, key)
    if obj == nil then
        return nil
    end
    local ok, value = pcall(function()
        return obj[key]
    end)
    if ok then
        return value
    end
    return nil
end

local function tryGetCharacter(guid)
    if Ext and Ext.GetCharacter then
        return safeCall(Ext.GetCharacter, guid)
    end
    return nil
end

local function tryGetItem(guid)
    if Ext and Ext.GetItem then
        return safeCall(Ext.GetItem, guid)
    end
    return nil
end

local function getArrayCount(t)
    if type(t) ~= "table" then
        return 0
    end
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function getPlayers()
    local players = {}

    -- Preferred: current party membership table.
    if Osi and Osi.DB_PartyMembers then
        local dbRows = safeCall(Osi.DB_PartyMembers.Get, nil)
        if type(dbRows) == "table" then
            for _, row in ipairs(dbRows) do
                if row and row[1] then
                    players[row[1]] = true
                end
            end
        end
    end

    -- Common path: Osiris DB with current players
    if Osi and Osi.DB_IsPlayer then
        local dbRows = safeCall(Osi.DB_IsPlayer.Get, nil)
        if type(dbRows) == "table" then
            for _, row in ipairs(dbRows) do
                if row and row[1] then
                    players[row[1]] = true
                end
            end
        end
    end

    -- Last-resort fallback: enumerate characters and keep strict player flags only.
    if next(players) == nil and Ext and Ext.Entity and Ext.Entity.GetAllCharacterGuids then
        local chars = safeCall(Ext.Entity.GetAllCharacterGuids)
        if type(chars) == "table" then
            for _, guid in ipairs(chars) do
                local c = tryGetCharacter(guid)
                if c and safeGet(c, "IsPlayer") == true then
                    players[guid] = true
                end
            end
        end
    end

    local out = {}
    for guid in pairs(players) do
        out[#out + 1] = guid
    end
    return out
end

local function readAttributes(character)
    local stats = character and character.Stats
    if not stats then
        return {}
    end

    -- Attribute names used by DOS2 stats object.
    return {
        Strength = stats.Strength,
        Finesse = stats.Finesse,
        Intelligence = stats.Intelligence,
        Constitution = stats.Constitution,
        Memory = stats.Memory,
        Wits = stats.Wits,
    }
end

local function readVitals(character)
    local stats = character and character.Stats
    if not stats then
        return {}
    end

    return {
        current_hp = safeGet(stats, "CurrentVitality") or safeGet(stats, "CurrentHitpoints"),
        max_hp = safeGet(stats, "MaxVitality") or safeGet(stats, "MaxHitpoints"),
        physical_armor = safeGet(stats, "CurrentArmor") or safeGet(stats, "Armor"),
        magical_armor = safeGet(stats, "CurrentMagicArmor") or safeGet(stats, "MagicArmor"),
    }
end

local function readStatuses(character)
    local statuses = {}
    local statusManager = character and character.StatusMachine
    if not statusManager or not statusManager.Statuses then
        return statuses
    end

    for _, status in pairs(statusManager.Statuses) do
        local statusId = safeGet(status, "StatusId") or safeGet(status, "StatusType") or "UNKNOWN"
        statuses[#statuses + 1] = {
            id = statusId,
            name = safeGet(status, "DisplayName") or statusId,
            turns = safeGet(status, "CurrentLifeTime") or safeGet(status, "LifeTime"),
        }
    end
    return statuses
end

local function readEquipment(character)
    local equipment = {}
    local inventory = character and character.InventoryHandle and safeCall(Ext.GetInventory, character.InventoryHandle)
    if not inventory or not inventory.Equipment then
        return equipment
    end

    for slot, itemGuid in pairs(inventory.Equipment) do
        if itemGuid then
            local item = tryGetItem(itemGuid)
            equipment[#equipment + 1] = {
                slot = tostring(slot),
                guid = itemGuid,
                template = item and item.RootTemplate and item.RootTemplate.Id or nil,
                name = item and (item.DisplayName or item.OriginalDisplayName) or nil,
                stats_id = item and item.StatsId or nil,
            }
        end
    end
    return equipment
end

local function readInventory(character)
    local entries = {}
    local inventory = character and character.InventoryHandle and safeCall(Ext.GetInventory, character.InventoryHandle)
    if not inventory or not inventory.Items then
        return entries
    end

    local stackByTemplate = {}
    for _, itemGuid in pairs(inventory.Items) do
        local item = tryGetItem(itemGuid)
        if item then
            local templateId = item.RootTemplate and item.RootTemplate.Id or "UNKNOWN_TEMPLATE"
            local amount = item.Amount or 1
            if not stackByTemplate[templateId] then
                stackByTemplate[templateId] = {
                    template = templateId,
                    count = 0,
                    items = {}
                }
            end
            stackByTemplate[templateId].count = stackByTemplate[templateId].count + amount
            stackByTemplate[templateId].items[#stackByTemplate[templateId].items + 1] = {
                guid = itemGuid,
                name = item.DisplayName or item.OriginalDisplayName,
                stats_id = item.StatsId,
                amount = amount,
            }
        end
    end

    for _, row in pairs(stackByTemplate) do
        entries[#entries + 1] = row
    end
    return entries
end

local function buildPartySnapshot()
    local party = {}
    local playerGuids = getPlayers()

    for _, guid in ipairs(playerGuids) do
        local character = tryGetCharacter(guid)
        if character then
            party[#party + 1] = {
                guid = guid,
                name = character.DisplayName or character.Name or guid,
                attributes = readAttributes(character),
                vitals = readVitals(character),
                status_effects = readStatuses(character),
                equipment = readEquipment(character),
                inventory = readInventory(character),
            }
        end
    end

    local updatedAt = safeGet(Ext, "MonotonicTime")
    if type(updatedAt) == "function" then
        updatedAt = safeCall(updatedAt)
    else
        updatedAt = nil
    end

    return {
        updated_at = updatedAt,
        party_count = getArrayCount(party),
        party = party
    }
end

local function postJson(payload)
    if not Ext or not Ext.Json then
        log("Ext.Json is not available; cannot serialize payload.")
        return
    end

    local body = Ext.Json.Stringify(payload)

    -- Preferred path if HTTP helper is available in your Script Extender build.
    if Ext.Net and Ext.Net.HttpRequest then
        safeCall(Ext.Net.HttpRequest, {
            Url = TARGET_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = body,
        })
        return
    end

    -- Fallback: write latest payload to disk so another local process can forward it.
    if Ext.IO and Ext.IO.SaveFile then
        safeCall(Ext.IO.SaveFile, "DOS2Dashboard/latest_snapshot.json", body)
        log("HTTP API unavailable; wrote fallback snapshot to DOS2Dashboard/latest_snapshot.json")
        return
    end

    log("No available outbound transport (Ext.Net.HttpRequest / Ext.IO.SaveFile missing).")
end

local elapsed = 0
local function onTick(deltaSeconds)
    elapsed = elapsed + (deltaSeconds or 0)
    if elapsed < UPDATE_INTERVAL_SECONDS then
        return
    end
    elapsed = 0

    local payload = buildPartySnapshot()
    postJson(payload)
end

local function registerTick()
    if Ext and Ext.Events and Ext.Events.Tick and Ext.Events.Tick.Subscribe then
        Ext.Events.Tick:Subscribe(function(e)
            onTick(e and e.Time and e.Time.DeltaTime or 0.1)
        end)
        log("Registered ticker with Ext.Events.Tick")
        return true
    end

    if Ext and Ext.RegisterListener then
        safeCall(Ext.RegisterListener, "Tick", function(delta)
            onTick(delta or 0.1)
        end)
        log("Registered ticker with Ext.RegisterListener('Tick')")
        return true
    end

    log("Could not register tick listener.")
    return false
end

registerTick()
log("Live dashboard exporter initialized. Target: " .. TARGET_URL)
