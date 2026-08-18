local Core = exports.vorp_core:GetCore()

local ActiveMissions = {}
local PlayerMission = {}
local MissionLocks = {}
local MemberLocks = {}
local StarterLocationIndex = 0
local StarterModelIndex = 0

local function notify(source, message)
    Core.NotifyRightTip(source, message, 5000)
end

local function formatRemaining(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.ceil((seconds % 3600) / 60)

    if hours > 0 then
        return ('%dh %02dmin'):format(hours, minutes)
    end
    return ('%dmin'):format(math.max(minutes, 1))
end

local function safeDisplayName(name)
    name = tostring(name or ''):match('^%s*(.-)%s*$')
    name = name:gsub('[<>&]', '')
    return name ~= '' and name or 'Sem nome'
end

local function getCharacter(source)
    local user = Core.getUser(source)
    if not user then return nil end

    local character = user.getUsedCharacter
    if not character then return nil end

    return {
        identifier = tostring(character.identifier),
        charid = tonumber(character.charIdentifier),
        name = (tostring(character.firstname or '') .. ' ' .. tostring(character.lastname or '')):match('^%s*(.-)%s*$'),
    }
end

local function getStarterCoords()
    if StarterLocationIndex == 0 then
        return Config.MissionStarter.fixedLocation
    end
    return Config.MissionStarter.randomLocations[StarterLocationIndex]
end

local function isNearStarter(source)
    local coords = getStarterCoords()
    local ped = GetPlayerPed(source)
    if not coords or ped == 0 then return false end

    local maximum = tonumber(Config.StarterServerDistance) or 4.0
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= maximum
end

local function getEnemyNetworkIds(mission)
    local ids = {}
    for _, networkId in ipairs(mission.enemyNetworkIds or {}) do
        ids[#ids + 1] = networkId
    end
    return ids
end

local function validateWaveEnemies(mission, fort, wave)
    local networkIds = mission.enemyNetworkIds or {}
    if #networkIds ~= tonumber(wave.enemyAmount) then return false end

    local allowedModels = {}
    for _, modelName in ipairs(wave.models or Config.EnemyModels) do
        allowedModels[joaat(modelName)] = true
    end

    local maximumDistance = fort.area.combatRadius
        + (tonumber(Config.ServerValidation and Config.ServerValidation.enemyValidationRadius) or 30.0)

    for _, networkId in ipairs(networkIds) do
        local entity = NetworkGetEntityFromNetworkId(networkId)
        if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return false end
        if not allowedModels[GetEntityModel(entity)] then return false end
        if #(GetEntityCoords(entity) - fort.area.center) > maximumDistance then return false end
        if GetEntityHealth(entity) > 0 then return false end
    end

    return true
end

local function getOwnership(fortId)
    return MySQL.single.await([[
        SELECT `owner_identifier`, `owner_charid`, `owner_name`, `conquered_at`, `challenge_available_at`
        FROM `fort_domination_ownership`
        WHERE `fort_id` = ?
    ]], { fortId })
end

local function characterIsOwner(character, ownership)
    return character and ownership
        and tostring(ownership.owner_identifier or '') == character.identifier
        and tonumber(ownership.owner_charid) == character.charid
end

local function getManagementCoords(fortId)
    local fort = Config.Forts[fortId]
    local completion = fort and fort.completion
    if not completion then return nil end
    return completion.managementLocation or completion.chestLocation
end

local function isNearManagementPoint(source, fortId)
    local coords = getManagementCoords(fortId)
    local ped = GetPlayerPed(source)
    if not coords or ped == 0 then return false end

    local maximum = tonumber(Config.MemberManagement.menuServerDistance) or 4.0
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= maximum
end

local function getFortMembers(fortId, ownership)
    if not ownership then return {} end

    return MySQL.query.await([[
        SELECT `id`, `member_name`, `chest_access`, `crafting_access`
        FROM `fort_domination_members`
        WHERE `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
        ORDER BY `member_name` ASC, `id` ASC
    ]], { fortId, ownership.owner_identifier, ownership.owner_charid }) or {}
end

local function getMembership(fortId, character, ownership)
    if not character or not ownership then return nil end

    return MySQL.single.await([[
        SELECT `id`, `chest_access`, `crafting_access`
        FROM `fort_domination_members`
        WHERE `fort_id` = ?
          AND `owner_identifier` = ? AND `owner_charid` = ?
          AND `member_identifier` = ? AND `member_charid` = ?
        LIMIT 1
    ]], {
        fortId,
        ownership.owner_identifier,
        ownership.owner_charid,
        character.identifier,
        character.charid,
    })
end

local function sendFortMenu(source, fortId)
    local fort = Config.Forts[fortId]
    if not fort then return notify(source, Lang.invalidFort) end
    if not isNearManagementPoint(source, fortId) then return notify(source, Lang.menuTooFar) end

    local character = getCharacter(source)
    if not character or not character.charid then return end

    local ownership = getOwnership(fortId)
    if not ownership or not ownership.owner_identifier or ownership.owner_identifier == '' then
        return notify(source, Lang.menuNoAccess)
    end

    local isOwner = characterIsOwner(character, ownership)
    if not isOwner then return notify(source, Lang.menuNoAccess) end

    local members = {}
    local nearbyPlayers = {}
    if isOwner then
        local memberRows = getFortMembers(fortId, ownership)
        local existingCharacters = {}
        for _, row in ipairs(memberRows) do
            members[#members + 1] = {
                id = tonumber(row.id),
                name = safeDisplayName(row.member_name),
                chestAccess = tonumber(row.chest_access) == 1,
                craftingAccess = tonumber(row.crafting_access) == 1,
            }
        end

        local fullRows = MySQL.query.await([[
            SELECT `member_identifier`, `member_charid`
            FROM `fort_domination_members`
            WHERE `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
        ]], { fortId, ownership.owner_identifier, ownership.owner_charid }) or {}
        for _, row in ipairs(fullRows) do
            existingCharacters[tostring(row.member_identifier) .. ':' .. tostring(row.member_charid)] = true
        end

        local ownerPed = GetPlayerPed(source)
        local ownerCoords = GetEntityCoords(ownerPed)
        local addDistance = tonumber(Config.MemberManagement.addDistance) or 5.0
        for _, playerId in ipairs(GetPlayers()) do
            local target = tonumber(playerId)
            if target and target ~= source then
                local targetPed = GetPlayerPed(target)
                if targetPed ~= 0 then
                    local distance = #(GetEntityCoords(targetPed) - ownerCoords)
                    if distance <= addDistance then
                        local targetCharacter = getCharacter(target)
                        local key = targetCharacter and (targetCharacter.identifier .. ':' .. tostring(targetCharacter.charid))
                        if targetCharacter and targetCharacter.charid and not existingCharacters[key] then
                            nearbyPlayers[#nearbyPlayers + 1] = {
                                serverId = target,
                                name = safeDisplayName(targetCharacter.name),
                                distance = math.floor(distance * 10 + 0.5) / 10,
                            }
                        end
                    end
                end
            end
        end
        table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
    end

    local remaining = math.max(0, (tonumber(ownership.challenge_available_at) or 0) - os.time())
    TriggerClientEvent('redm_fortdomination:client:openFortMenu', source, {
        fortId = fortId,
        fortName = fort.name,
        ownerName = safeDisplayName(ownership.owner_name),
        isOwner = isOwner,
        members = members,
        nearbyPlayers = nearbyPlayers,
        maxMembers = tonumber(Config.MemberManagement.maxMembers) or 10,
        addDistance = tonumber(Config.MemberManagement.addDistance) or 5.0,
        cooldownText = remaining > 0 and formatRemaining(remaining) or 'disponível',
    })
end

local function getStorageConfig(fortId)
    local fort = Config.Forts[fortId]
    local completion = fort and fort.completion
    return completion and completion.storage or nil
end

local function registerFortStorage(fortId)
    local storage = getStorageConfig(fortId)
    if not storage then return false end

    if exports.vorp_inventory:isCustomInventoryRegistered(storage.id) then
        exports.vorp_inventory:updateCustomInventorySlots(storage.id, storage.capacity)
        return true
    end

    exports.vorp_inventory:registerInventory({
        id = storage.id,
        name = storage.name,
        limit = storage.capacity,
        acceptWeapons = storage.acceptWeapons == true,
        shared = true, -- O conteúdo permanece após a troca de Dominador.
        ignoreItemStackLimit = true,
        whitelistItems = false,
        UsePermissions = false, -- A permissão é validada por este recurso antes de abrir.
        UseBlackList = false,
        whitelistWeapons = false,
    })

    return exports.vorp_inventory:isCustomInventoryRegistered(storage.id) == true
end

local function giveMoney(source, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    local user = Core.getUser(source)
    local character = user and user.getUsedCharacter
    if not character then return false end

    character.addCurrency(0, amount)
    return true
end

local function markRewardClaimed(fortId, character)
    MySQL.update.await([[
        UPDATE `fort_domination_ownership`
        SET `reward_claimed` = 1
        WHERE `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
    ]], { fortId, character.identifier, character.charid })
end

local function grantConquestReward(source, fortId, character)
    local fort = Config.Forts[fortId]
    local rewards = fort and fort.rewards
    if not rewards or rewards.enabled ~= true or not rewards.options or #rewards.options == 0 then
        markRewardClaimed(fortId, character)
        return true
    end

    local reward = rewards.options[math.random(1, #rewards.options)]
    if reward.type == 'money' then
        if not giveMoney(source, reward.amount) then
            notify(source, Lang.rewardError)
            return false
        end

        markRewardClaimed(fortId, character)
        notify(source, Lang.rewardMoney:format(reward.label or ('$' .. reward.amount)))
        return true
    end

    if reward.type == 'items' and reward.items and #reward.items > 0 then
        local storage = getStorageConfig(fortId)
        local stored = storage
            and registerFortStorage(fortId)
            and exports.vorp_inventory:addItemsToCustomInventory(
                storage.id,
                reward.items,
                character.charid,
                nil,
                character.identifier
            ) == true

        if stored then
            markRewardClaimed(fortId, character)
            notify(source, Lang.rewardStored:format(reward.label or 'itens'))
            return true
        end

        if giveMoney(source, reward.fallbackMoney) then
            markRewardClaimed(fortId, character)
            notify(source, Lang.rewardFallback:format(reward.fallbackMoney))
            return true
        end
    end

    notify(source, Lang.rewardError)
    return false
end

local function syncFortOwnership(target)
    local rows = MySQL.query.await(
        'SELECT `fort_id`, `owner_identifier` FROM `fort_domination_ownership`'
    )

    for _, row in ipairs(rows or {}) do
        TriggerClientEvent(
            'redm_fortdomination:client:setFortOwned',
            target,
            row.fort_id,
            row.owner_identifier ~= nil and row.owner_identifier ~= ''
        )
    end
end

local function registerNewDominator(source, fortId)
    local character = getCharacter(source)
    if not character or not character.charid then return false end

    local now = os.time()
    local success = MySQL.transaction.await({
        {
            query = 'DELETE FROM `fort_domination_members` WHERE `fort_id` = ?',
            values = { fortId }
        },
        {
            query = [[
                UPDATE `fort_domination_ownership`
                SET `owner_identifier` = ?,
                    `owner_charid` = ?,
                    `owner_name` = ?,
                    `conquest_id` = `conquest_id` + 1,
                    `conquered_at` = ?,
                    `reward_claimed` = 0
                WHERE `fort_id` = ?
            ]],
            values = { character.identifier, character.charid, character.name, now, fortId }
        }
    })

    if not success then return false end

    TriggerClientEvent('redm_fortdomination:client:setFortOwned', -1, fortId, true)
    return character
end

local function chooseStarterLocation()
    local locations = Config.MissionStarter.randomLocations
    if Config.MissionStarter.randomLocation and #locations > 0 then
        local previousLocation = StarterLocationIndex
        repeat
            StarterLocationIndex = math.random(1, #locations)
        until #locations == 1 or StarterLocationIndex ~= previousLocation
    else
        StarterLocationIndex = 0
    end

    local models = Config.MissionStarter.models
    local previousModel = StarterModelIndex
    repeat
        StarterModelIndex = math.random(1, #models)
    until #models == 1 or StarterModelIndex ~= previousModel
end

local function finishMission(source, fortId, result)
    local mission = ActiveMissions[fortId]
    if not mission or mission.leader ~= source then return end

    ActiveMissions[fortId] = nil
    PlayerMission[source] = nil
    TriggerClientEvent('redm_fortdomination:client:finishMission', source, result)

    local ownership = MySQL.single.await(
        'SELECT `challenge_available_at` FROM `fort_domination_ownership` WHERE `fort_id` = ?',
        { fortId }
    )
    TriggerClientEvent(
        'redm_fortdomination:client:setStarterAvailability',
        -1,
        tonumber(ownership and ownership.challenge_available_at) or 0,
        false,
        os.time()
    )
end

MySQL.ready(function()
    -- O recurso utiliza apenas as tabelas de posse e de membros.
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fort_domination_ownership` (
            `fort_id` VARCHAR(64) NOT NULL,
            `owner_identifier` VARCHAR(64) DEFAULT NULL,
            `owner_charid` INT DEFAULT NULL,
            `owner_name` VARCHAR(100) DEFAULT NULL,
            `conquest_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `conquered_at` BIGINT NOT NULL DEFAULT 0,
            `challenge_available_at` BIGINT NOT NULL DEFAULT 0,
            `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`fort_id`),
            INDEX `idx_fort_owner` (`owner_identifier`, `owner_charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Atualiza automaticamente bancos criados pela versão 0.1.5.
    MySQL.query.await([[
        ALTER TABLE `fort_domination_ownership`
        ADD COLUMN IF NOT EXISTS `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0
        AFTER `challenge_available_at`
    ]])

    MySQL.query.await([[
        ALTER TABLE `fort_domination_ownership`
        ADD COLUMN IF NOT EXISTS `owner_name` VARCHAR(100) DEFAULT NULL
        AFTER `owner_charid`
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fort_domination_members` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `fort_id` VARCHAR(64) NOT NULL,
            `owner_identifier` VARCHAR(64) NOT NULL,
            `owner_charid` INT NOT NULL,
            `member_identifier` VARCHAR(64) NOT NULL,
            `member_charid` INT NOT NULL,
            `member_name` VARCHAR(100) NOT NULL DEFAULT '',
            `chest_access` TINYINT(1) NOT NULL DEFAULT 1,
            `crafting_access` TINYINT(1) NOT NULL DEFAULT 1,
            `added_at` BIGINT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_fort_member` (`fort_id`, `member_identifier`, `member_charid`),
            INDEX `idx_fort_members_owner` (`fort_id`, `owner_identifier`, `owner_charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        ALTER TABLE `fort_domination_members`
        ADD COLUMN IF NOT EXISTS `member_name` VARCHAR(100) NOT NULL DEFAULT ''
        AFTER `member_charid`
    ]])

    -- Registra cada forte configurado sem substituir uma posse que já exista.
    for fortId in pairs(Config.Forts) do
        MySQL.query.await(
            'INSERT IGNORE INTO `fort_domination_ownership` (`fort_id`) VALUES (?)',
            { fortId }
        )
        registerFortStorage(fortId)
    end

    syncFortOwnership(-1)

    math.randomseed(os.time())
    chooseStarterLocation()
    TriggerClientEvent(
        'redm_fortdomination:client:setStarter',
        -1,
        StarterLocationIndex,
        StarterModelIndex
    )

    local interval = tonumber(Config.MissionStarter.relocateIntervalSeconds) or 0
    if interval > 0 then
        CreateThread(function()
            while true do
                Wait(interval * 1000)
                chooseStarterLocation()
                TriggerClientEvent(
                    'redm_fortdomination:client:setStarter',
                    -1,
                    StarterLocationIndex,
                    StarterModelIndex
                )
            end
        end)
    end
end)

RegisterNetEvent('redm_fortdomination:server:requestStarter', function()
    local source = source
    local fortId = Config.DefaultFort
    local ownership = MySQL.single.await(
        'SELECT `challenge_available_at` FROM `fort_domination_ownership` WHERE `fort_id` = ?',
        { fortId }
    )
    TriggerClientEvent(
        'redm_fortdomination:client:setStarter',
        source,
        StarterLocationIndex,
        StarterModelIndex,
        tonumber(ownership and ownership.challenge_available_at) or 0,
        ActiveMissions[fortId] ~= nil,
        os.time()
    )
    syncFortOwnership(source)
end)

RegisterNetEvent('redm_fortdomination:server:requestMission', function(fortId)
    local source = source
    local fort = Config.Forts[fortId]
    if not fort then return notify(source, Lang.invalidFort) end
    if not isNearStarter(source) then return notify(source, Lang.starterTooFar) end
    if PlayerMission[source] then return notify(source, Lang.alreadyActive) end
    if ActiveMissions[fortId] or MissionLocks[fortId] then return notify(source, Lang.fortBusy) end

    -- Evita que dois jogadores aceitem no mesmo instante antes da consulta terminar.
    MissionLocks[fortId] = true

    local now = os.time()
    local ownership = MySQL.single.await(
        'SELECT `challenge_available_at` FROM `fort_domination_ownership` WHERE `fort_id` = ?',
        { fortId }
    )
    local availableAt = ownership and tonumber(ownership.challenge_available_at) or 0
    if availableAt > now then
        MissionLocks[fortId] = nil
        return notify(source, Lang.cooldown:format(formatRemaining(availableAt - now)))
    end

    local character = getCharacter(source)
    if not character or not character.charid then
        MissionLocks[fortId] = nil
        return
    end

    -- Cooldown global: começa ao aceitar e vale para todos os jogadores.
    local newAvailableAt = now + Config.GlobalCooldownSeconds
    MySQL.update.await(
        'UPDATE `fort_domination_ownership` SET `challenge_available_at` = ? WHERE `fort_id` = ?',
        { newAvailableAt, fortId }
    )

    local mission = {
        leader = source,
        fortId = fortId,
        startedAt = now,
        wave = 0,
        state = 'travelling',
        enemyNetworkIds = {},
        enemyNetworkIdSet = {},
    }

    ActiveMissions[fortId] = mission
    PlayerMission[source] = fortId
    MissionLocks[fortId] = nil
    TriggerClientEvent(
        'redm_fortdomination:client:setStarterAvailability',
        -1,
        newAvailableAt,
        true,
        now
    )
    TriggerClientEvent('redm_fortdomination:client:startMission', source, fortId)

    -- Encerra a missão mesmo se o jogador nunca entrar na área do forte.
    SetTimeout(Config.ArrivalTimeLimit * 1000, function()
        local active = ActiveMissions[fortId]
        if active and active.leader == source and active.state == 'travelling' then
            finishMission(source, fortId, 'arrival_expired')
        end
    end)
end)

RegisterNetEvent('redm_fortdomination:server:registerEnemy', function(fortId, waveNumber, networkId)
    local source = source
    networkId = tonumber(networkId)
    local mission = ActiveMissions[fortId]
    local fort = Config.Forts[fortId]
    local wave = fort and fort.waves[tonumber(waveNumber)]
    if not mission or mission.leader ~= source or mission.state ~= 'combat' then return end
    if tonumber(waveNumber) ~= mission.wave or not wave or not networkId or networkId <= 0 then return end

    mission.enemyNetworkIds = mission.enemyNetworkIds or {}
    mission.enemyNetworkIdSet = mission.enemyNetworkIdSet or {}
    if mission.enemyNetworkIdSet[networkId] then return end
    if #mission.enemyNetworkIds >= tonumber(wave.enemyAmount) then return end

    mission.enemyNetworkIdSet[networkId] = true
    mission.enemyNetworkIds[#mission.enemyNetworkIds + 1] = networkId
end)

RegisterNetEvent('redm_fortdomination:server:requestFortMenu', function(fortId)
    local source = source
    if type(fortId) ~= 'string' or not Config.Forts[fortId] then return end
    sendFortMenu(source, fortId)
end)

RegisterNetEvent('redm_fortdomination:server:addMember', function(fortId, targetSource)
    local source = source
    targetSource = tonumber(targetSource)
    if type(fortId) ~= 'string' or not Config.Forts[fortId] or not targetSource or targetSource == source then
        return notify(source, Lang.memberInvalid)
    end
    if MemberLocks[fortId] then return end
    MemberLocks[fortId] = true

    local function finish()
        MemberLocks[fortId] = nil
    end

    if not isNearManagementPoint(source, fortId) then
        finish()
        return notify(source, Lang.menuTooFar)
    end

    local owner = getCharacter(source)
    local ownership = getOwnership(fortId)
    if not characterIsOwner(owner, ownership) then
        finish()
        return notify(source, Lang.menuNoAccess)
    end

    local ownerPed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetSource)
    if ownerPed == 0 or targetPed == 0 then
        finish()
        return notify(source, Lang.memberInvalid)
    end

    local addDistance = tonumber(Config.MemberManagement.addDistance) or 5.0
    local distance = #(GetEntityCoords(ownerPed) - GetEntityCoords(targetPed))
    if distance > addDistance then
        finish()
        return notify(source, Lang.memberTooFar:format(addDistance))
    end

    local target = getCharacter(targetSource)
    if not target or not target.charid then
        finish()
        return notify(source, Lang.memberInvalid)
    end

    local memberCount = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM `fort_domination_members`
        WHERE `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
    ]], { fortId, ownership.owner_identifier, ownership.owner_charid })) or 0
    local maximum = tonumber(Config.MemberManagement.maxMembers) or 10
    if memberCount >= maximum then
        finish()
        return notify(source, Lang.memberLimit:format(maximum))
    end

    local alreadyAdded = MySQL.scalar.await([[
        SELECT `id` FROM `fort_domination_members`
        WHERE `fort_id` = ? AND `member_identifier` = ? AND `member_charid` = ?
        LIMIT 1
    ]], { fortId, target.identifier, target.charid })
    if alreadyAdded then
        finish()
        return notify(source, Lang.memberAlreadyAdded)
    end

    local inserted = MySQL.insert.await([[
        INSERT INTO `fort_domination_members`
            (`fort_id`, `owner_identifier`, `owner_charid`, `member_identifier`, `member_charid`, `member_name`, `chest_access`, `crafting_access`, `added_at`)
        VALUES (?, ?, ?, ?, ?, ?, 1, 1, ?)
    ]], {
        fortId,
        ownership.owner_identifier,
        ownership.owner_charid,
        target.identifier,
        target.charid,
        target.name,
        os.time(),
    })
    finish()

    if not inserted then return notify(source, Lang.memberInvalid) end
    notify(source, Lang.memberAdded:format(safeDisplayName(target.name)))
    sendFortMenu(source, fortId)
end)

RegisterNetEvent('redm_fortdomination:server:removeMember', function(fortId, memberId)
    local source = source
    memberId = tonumber(memberId)
    if type(fortId) ~= 'string' or not Config.Forts[fortId] or not memberId then return end
    if not isNearManagementPoint(source, fortId) then return notify(source, Lang.menuTooFar) end

    local owner = getCharacter(source)
    local ownership = getOwnership(fortId)
    if not characterIsOwner(owner, ownership) then return notify(source, Lang.menuNoAccess) end

    local member = MySQL.single.await([[
        SELECT `member_name` FROM `fort_domination_members`
        WHERE `id` = ? AND `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
    ]], { memberId, fortId, ownership.owner_identifier, ownership.owner_charid })
    if not member then return notify(source, Lang.memberInvalid) end

    local changed = MySQL.update.await([[
        DELETE FROM `fort_domination_members`
        WHERE `id` = ? AND `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
    ]], { memberId, fortId, ownership.owner_identifier, ownership.owner_charid })
    if not changed or changed < 1 then return notify(source, Lang.memberInvalid) end

    notify(source, Lang.memberRemoved:format(safeDisplayName(member.member_name)))
    sendFortMenu(source, fortId)
end)

RegisterNetEvent('redm_fortdomination:server:setMemberPermission', function(fortId, memberId, permission, enabled)
    local source = source
    memberId = tonumber(memberId)
    if type(fortId) ~= 'string' or not Config.Forts[fortId] or not memberId then return end
    if permission ~= 'chest' and permission ~= 'crafting' then return end
    if type(enabled) ~= 'boolean' then return end
    if not isNearManagementPoint(source, fortId) then return notify(source, Lang.menuTooFar) end

    local owner = getCharacter(source)
    local ownership = getOwnership(fortId)
    if not characterIsOwner(owner, ownership) then return notify(source, Lang.menuNoAccess) end

    local column = permission == 'chest' and 'chest_access' or 'crafting_access'
    local member = MySQL.single.await([[
        SELECT `member_name` FROM `fort_domination_members`
        WHERE `id` = ? AND `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
    ]], { memberId, fortId, ownership.owner_identifier, ownership.owner_charid })
    if not member then return notify(source, Lang.memberInvalid) end

    local changed = MySQL.update.await(([[
        UPDATE `fort_domination_members` SET `%s` = ?
        WHERE `id` = ? AND `fort_id` = ? AND `owner_identifier` = ? AND `owner_charid` = ?
    ]]):format(column), {
        enabled and 1 or 0,
        memberId,
        fortId,
        ownership.owner_identifier,
        ownership.owner_charid,
    })
    if not changed or changed < 1 then return notify(source, Lang.memberInvalid) end

    notify(source, Lang.memberPermissionUpdated:format(safeDisplayName(member.member_name)))
    sendFortMenu(source, fortId)
end)

RegisterNetEvent('redm_fortdomination:server:openChest', function(fortId)
    local source = source
    local fort = Config.Forts[fortId]
    local completion = fort and fort.completion
    local storage = completion and completion.storage
    if not storage then return notify(source, Lang.chestUnavailable) end

    -- Validação de distância feita no servidor para impedir abertura remota por evento.
    local playerPed = GetPlayerPed(source)
    if playerPed == 0 then return end

    local playerCoords = GetEntityCoords(playerPed)
    local chestCoords = completion.chestLocation
    local distance = #(playerCoords - vector3(chestCoords.x, chestCoords.y, chestCoords.z))
    if distance > (completion.chestServerDistance or 4.0) then
        return notify(source, Lang.chestTooFar)
    end

    local character = getCharacter(source)
    if not character or not character.charid then return end

    local ownership = getOwnership(fortId)
    local isOwner = characterIsOwner(character, ownership)
    local membership = isOwner and nil or getMembership(fortId, character, ownership)
    local canOpen = isOwner or tonumber(membership and membership.chest_access) == 1
    if not canOpen then return notify(source, Lang.chestNoAccess) end

    if not registerFortStorage(fortId) then
        return notify(source, Lang.chestUnavailable)
    end

    TriggerClientEvent('redm_fortdomination:client:trackOpenChest', source, fortId)
    exports.vorp_inventory:openInventory(source, storage.id)
end)

RegisterNetEvent('redm_fortdomination:server:fortReached', function(fortId)
    local source = source
    local mission = ActiveMissions[fortId]
    if not mission or mission.leader ~= source or mission.state ~= 'travelling' then return end

    local fort = Config.Forts[fortId]
    local playerPed = GetPlayerPed(source)
    local tolerance = tonumber(Config.ServerValidation and Config.ServerValidation.fortArrivalTolerance) or 10.0
    if playerPed == 0
        or #(GetEntityCoords(playerPed) - fort.area.center) > (fort.area.activationRadius + tolerance) then
        return notify(source, Lang.fortNotReached)
    end

    if os.time() - mission.startedAt > Config.ArrivalTimeLimit then
        return finishMission(source, fortId, 'arrival_expired')
    end

    mission.state = 'combat'
    mission.wave = 1
    mission.outsideSince = nil
    TriggerClientEvent('redm_fortdomination:client:startWave', source, fortId, mission.wave)

    -- O servidor confirma continuamente se o iniciador permanece na área permitida.
    CreateThread(function()
        while true do
            Wait(1000)

            local active = ActiveMissions[fortId]
            if not active or active ~= mission or active.state ~= 'combat' then return end

            local playerPed = GetPlayerPed(source)
            if playerPed ~= 0 then
                local fort = Config.Forts[fortId]
                local safetyRadius = fort.area.safetyRadius or fort.area.combatRadius
                local distance = #(GetEntityCoords(playerPed) - fort.area.center)

                if distance > safetyRadius then
                    active.outsideSince = active.outsideSince or os.time()
                    if os.time() - active.outsideSince >= (fort.area.returnTimeLimit or 30) then
                        finishMission(source, fortId, 'area_abandoned')
                        return
                    end
                else
                    active.outsideSince = nil
                end
            end
        end
    end)
end)

RegisterNetEvent('redm_fortdomination:server:waveCleared', function(fortId, wave)
    local source = source
    local mission = ActiveMissions[fortId]
    if not mission or mission.leader ~= source or mission.state ~= 'combat' then return end
    if tonumber(wave) ~= mission.wave then return end

    local fort = Config.Forts[fortId]
    local waveConfig = fort and fort.waves[mission.wave]
    if not waveConfig or not validateWaveEnemies(mission, fort, waveConfig) then
        return notify(source, Lang.waveValidationFailed)
    end

    local clearedEnemyIds = getEnemyNetworkIds(mission)
    TriggerClientEvent(
        'redm_fortdomination:client:cleanupEnemies',
        source,
        clearedEnemyIds,
        false,
        Config.EnemyDefaults.corpseCleanupDelay
    )

    local totalWaves = #Config.Forts[fortId].waves
    if mission.wave >= totalWaves then
        mission.state = 'completing'

        local newDominator = registerNewDominator(source, fortId)
        if not newDominator then
            notify(source, Lang.ownershipError)
            return finishMission(source, fortId, 'ownership_failed')
        end

        grantConquestReward(source, fortId, newDominator)

        mission.state = 'completed'
        return finishMission(source, fortId, 'completed')
    end

    mission.wave = mission.wave + 1
    mission.enemyNetworkIds = {}
    mission.enemyNetworkIdSet = {}
    TriggerClientEvent('redm_fortdomination:client:startWave', source, fortId, mission.wave)
end)

RegisterNetEvent('redm_fortdomination:server:leaderDied', function(fortId)
    finishMission(source, fortId, 'leader_died')
end)

RegisterNetEvent('redm_fortdomination:server:leaderLeftArea', function(fortId)
    local source = source
    local mission = ActiveMissions[fortId]
    if not mission or mission.leader ~= source or mission.state ~= 'combat' then return end

    local fort = Config.Forts[fortId]
    local outsideTime = mission.outsideSince and (os.time() - mission.outsideSince) or 0
    if outsideTime < (fort.area.returnTimeLimit or 30) then return end

    finishMission(source, fortId, 'area_abandoned')
end)

AddEventHandler('playerDropped', function()
    local source = source
    local fortId = PlayerMission[source]
    if not fortId then return end

    local mission = ActiveMissions[fortId]
    local enemyNetworkIds = mission and getEnemyNetworkIds(mission) or {}
    ActiveMissions[fortId] = nil
    PlayerMission[source] = nil

    if #enemyNetworkIds > 0 then
        TriggerClientEvent(
            'redm_fortdomination:client:cleanupEnemies',
            -1,
            enemyNetworkIds,
            true,
            tonumber(Config.ServerValidation and Config.ServerValidation.disconnectCleanupDelay) or 10000
        )
    end

    local ownership = MySQL.single.await(
        'SELECT `challenge_available_at` FROM `fort_domination_ownership` WHERE `fort_id` = ?',
        { fortId }
    )
    TriggerClientEvent(
        'redm_fortdomination:client:setStarterAvailability',
        -1,
        tonumber(ownership and ownership.challenge_available_at) or 0,
        false,
        os.time()
    )
end)
