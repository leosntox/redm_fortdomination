local Core = exports.vorp_core:GetCore()
local MenuData = exports.vorp_menu:GetMenuData()

local StarterNpc = 0
local StarterPrompt = nil
local ChestPrompt = nil
local ManagementPrompt = nil
local StarterCoords = nil
local StarterModel = nil
local StarterAvailableGameTimer = 0
local StarterMissionActive = false
local StarterDeparting = false
local MissionBlip = nil
local Mission = nil
local CurrentEnemies = {}
local AllMissionEnemies = {}
local EnemyGroup = joaat('FORT_DOMINATION_ENEMIES')
local AreaControl = nil
local OwnedForts = {}
local CurrentFortMenu = nil
local OpenFortChest = nil

local function notify(message)
    Core.NotifyRightTip(message, 5000)
end

local function notifyCountdown(message)
    Core.NotifyRightTip(message, 1100)
end

local function closeFortMenus()
    MenuData.CloseAll(false, false, false)
end

local openMainFortMenu
local openMembersMenu
local openMemberDetailsMenu
local openNearbyPlayersMenu

local function menuSettings(title, subtext, elements)
    return {
        title = title,
        subtext = subtext,
        align = 'top-left',
        elements = elements,
        hideRadar = false,
        soundOpen = true,
        maxVisibleItems = 8,
    }
end

openMemberDetailsMenu = function(member)
    local payload = CurrentFortMenu
    if not payload or not member then return end

    local chestLabel = member.chestAccess and 'Armário: permitido' or 'Armário: bloqueado'
    local craftingLabel = member.craftingAccess and 'Bancada: permitida' or 'Bancada: bloqueada'
    local elements = {
        { label = chestLabel, value = 'toggle_chest', desc = 'Ativa ou bloqueia o acesso desse membro ao armário.' },
        { label = craftingLabel, value = 'toggle_crafting', desc = 'Permissão reservada para a futura bancada de fabricação.' },
        { label = 'Remover membro', value = 'remove', desc = 'Remove este personagem do grupo do forte.' },
    }

    MenuData.Open('default', 'redm_fortdomination', 'member_details',
        menuSettings(member.name, 'Permissões do membro', elements),
        function(data, menu)
            local action = data.current and data.current.value
            if action == 'toggle_chest' then
                closeFortMenus()
                TriggerServerEvent('redm_fortdomination:server:setMemberPermission', payload.fortId, member.id, 'chest', not member.chestAccess)
            elseif action == 'toggle_crafting' then
                closeFortMenus()
                TriggerServerEvent('redm_fortdomination:server:setMemberPermission', payload.fortId, member.id, 'crafting', not member.craftingAccess)
            elseif action == 'remove' then
                closeFortMenus()
                TriggerServerEvent('redm_fortdomination:server:removeMember', payload.fortId, member.id)
            end
        end,
        function(_, menu)
            menu.close(false, true, false)
            openMembersMenu()
        end)
end

openMembersMenu = function()
    local payload = CurrentFortMenu
    if not payload then return end

    local elements = {}
    for _, member in ipairs(payload.members or {}) do
        elements[#elements + 1] = {
            label = member.name,
            value = 'member',
            member = member,
            desc = ('Armário: %s | Bancada: %s'):format(
                member.chestAccess and 'sim' or 'não',
                member.craftingAccess and 'sim' or 'não'
            ),
        }
    end

    if #elements == 0 then
        elements[1] = { label = 'Nenhum membro cadastrado', value = 'empty', isDisabled = true }
    end

    MenuData.Open('default', 'redm_fortdomination', 'members',
        menuSettings('Membros do forte', ('%d/%d cadastrados'):format(#(payload.members or {}), payload.maxMembers or 0), elements),
        function(data, menu)
            local selected = data.current
            if selected and selected.value == 'member' then
                menu.close(false, false, false)
                openMemberDetailsMenu(selected.member)
            end
        end,
        function(_, menu)
            menu.close(false, true, false)
            openMainFortMenu()
        end)
end

openNearbyPlayersMenu = function()
    local payload = CurrentFortMenu
    if not payload then return end

    local elements = {}
    for _, player in ipairs(payload.nearbyPlayers or {}) do
        elements[#elements + 1] = {
            label = player.name,
            value = 'add',
            serverId = player.serverId,
            desc = ('Distância: %.1f m'):format(player.distance or 0.0),
        }
    end

    if #elements == 0 then
        elements[1] = {
            label = 'Nenhum jogador disponível por perto',
            value = 'empty',
            isDisabled = true,
            desc = ('O jogador precisa estar a até %.1f metros.'):format(payload.addDistance or 5.0),
        }
    end

    MenuData.Open('default', 'redm_fortdomination', 'nearby_players',
        menuSettings('Adicionar membro', ('Jogadores em até %.1f m'):format(payload.addDistance or 5.0), elements),
        function(data)
            local selected = data.current
            if selected and selected.value == 'add' then
                closeFortMenus()
                TriggerServerEvent('redm_fortdomination:server:addMember', payload.fortId, selected.serverId)
            end
        end,
        function(_, menu)
            menu.close(false, true, false)
            openMainFortMenu()
        end)
end

openMainFortMenu = function()
    local payload = CurrentFortMenu
    if not payload then return end

    local elements = {}
    if payload.isOwner then
        elements[#elements + 1] = { label = 'Adicionar jogador próximo', value = 'add_member', desc = ('Adiciona um jogador que esteja a até %.1f metros.'):format(payload.addDistance or 5.0) }
        elements[#elements + 1] = { label = 'Gerenciar membros', value = 'members', desc = ('Membros cadastrados: %d/%d'):format(#(payload.members or {}), payload.maxMembers or 0) }
    end

    MenuData.Open('default', 'redm_fortdomination', 'fort_main',
        menuSettings(payload.fortName or 'Forte', payload.isOwner and 'Menu do Dominador' or 'Menu do membro', elements),
        function(data, menu)
            local action = data.current and data.current.value
            if action == 'add_member' then
                menu.close(false, false, false)
                openNearbyPlayersMenu()
            elseif action == 'members' then
                menu.close(false, false, false)
                openMembersMenu()
            end
        end,
        function(_, menu)
            menu.close(false, true, false)
            CurrentFortMenu = nil
        end)
end

local function loadModel(modelName)
    local model = joaat(modelName)
    if not IsModelValid(model) then return nil end

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return nil end
        Wait(20)
    end
    return model
end

local function removeStarterNpc()
    if StarterNpc ~= 0 and DoesEntityExist(StarterNpc) then
        DeleteEntity(StarterNpc)
    end
    StarterNpc = 0
    StarterDeparting = false
end

local function isAnyPlayerNearEntity(entity, radius)
    if not DoesEntityExist(entity) then return false end

    local entityCoords = GetEntityCoords(entity)
    for _, player in ipairs(GetActivePlayers()) do
        local playerPed = GetPlayerPed(player)
        if DoesEntityExist(playerPed) and #(GetEntityCoords(playerPed) - entityCoords) <= radius then
            return true
        end
    end
    return false
end

local function dismissStarterNpc()
    if StarterDeparting or StarterNpc == 0 or not DoesEntityExist(StarterNpc) then return end

    StarterDeparting = true
    local ped = StarterNpc

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    Citizen.InvokeNative(0x8E06A6FE76C9EFF4, ped, true) -- SetPedPathCanUseClimbovers
    Citizen.InvokeNative(0x77A5B103C87F476E, ped, true) -- SetPedPathCanUseLadders

    -- Usa a malha de navegação do jogo para seguir ruas, escadas e passagens normais.
    Citizen.InvokeNative(0xBB9CE077274F6A1B, ped, 10.0, 10) -- TaskWanderStandard

    CreateThread(function()
        while StarterDeparting and StarterNpc == ped and DoesEntityExist(ped) do
            if not isAnyPlayerNearEntity(ped, Config.MissionStarter.departureRemoveDistance) then
                removeStarterNpc()
                return
            end
            Wait(Config.MissionStarter.departureCheckInterval)
        end
    end)
end

local function createStarterPrompt()
    if StarterPrompt then return end

    StarterPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(StarterPrompt, Config.InteractionKey)
    UiPromptSetText(StarterPrompt, CreateVarString(10, 'LITERAL_STRING', Lang.starterPrompt))
    UiPromptSetEnabled(StarterPrompt, true)
    UiPromptSetVisible(StarterPrompt, true)
    UiPromptSetHoldMode(StarterPrompt, Config.InteractionHoldTime)
    UiPromptSetGroup(StarterPrompt, joaat('FORT_DOMINATION_STARTER'), 0)
    UiPromptRegisterEnd(StarterPrompt)
end

local function createChestPrompt()
    if ChestPrompt then return end

    local defaultFort = Config.Forts[Config.DefaultFort]
    local completion = defaultFort and defaultFort.completion

    ChestPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(ChestPrompt, (completion and completion.chestPromptKey) or Config.InteractionKey)
    UiPromptSetText(ChestPrompt, CreateVarString(10, 'LITERAL_STRING', Lang.chestPrompt))
    UiPromptSetEnabled(ChestPrompt, true)
    UiPromptSetVisible(ChestPrompt, true)
    UiPromptSetStandardMode(ChestPrompt, true) -- Um toque abre o armário; não é necessário segurar.
    UiPromptSetGroup(ChestPrompt, joaat('FORT_DOMINATION_CHEST'), 0)
    UiPromptRegisterEnd(ChestPrompt)
end

local function createManagementPrompt()
    if ManagementPrompt then return end

    ManagementPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(ManagementPrompt, Config.InteractionKey)
    UiPromptSetText(ManagementPrompt, CreateVarString(10, 'LITERAL_STRING', Lang.managementPrompt))
    UiPromptSetEnabled(ManagementPrompt, true)
    UiPromptSetVisible(ManagementPrompt, true)
    UiPromptSetStandardMode(ManagementPrompt, true)
    UiPromptSetGroup(ManagementPrompt, joaat('FORT_DOMINATION_MANAGEMENT'), 0)
    UiPromptRegisterEnd(ManagementPrompt)
end

local function spawnStarterNpc()
    if not StarterCoords or (StarterNpc ~= 0 and DoesEntityExist(StarterNpc)) then return end

    local model = loadModel(StarterModel)
    if not model then return end

    StarterNpc = CreatePed(model, StarterCoords.x, StarterCoords.y, StarterCoords.z - 1.0, StarterCoords.w, false, true, true, true)
    Citizen.InvokeNative(0x283978A15512B2FE, StarterNpc, true) -- Roupa aleatória compatível com o modelo
    SetEntityCanBeDamaged(StarterNpc, false)
    SetEntityInvincible(StarterNpc, true)
    FreezeEntityPosition(StarterNpc, true)
    SetBlockingOfNonTemporaryEvents(StarterNpc, true)

    if Config.MissionStarter.scenario then
        TaskStartScenarioInPlace(StarterNpc, joaat(Config.MissionStarter.scenario), -1, true)
    end

    SetModelAsNoLongerNeeded(model)
end

local function setMissionBlip(fort)
    if MissionBlip then RemoveBlip(MissionBlip) end
    if not fort.blip.enabled then return end

    MissionBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, fort.area.center)
    SetBlipSprite(MissionBlip, fort.blip.sprite, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, MissionBlip, fort.blip.name)
    if fort.blip.colorModifier then
        Citizen.InvokeNative(0x662D364ABF16DE2F, MissionBlip, joaat(fort.blip.colorModifier))
    end
end

local function removeMissionBlip()
    if MissionBlip then
        RemoveBlip(MissionBlip)
        MissionBlip = nil
    end
end

local function isMissionEnemy(ped)
    for _, enemy in ipairs(CurrentEnemies) do
        if enemy == ped then return true end
    end
    return false
end

local function clearNativePeds(fort)
    if not Config.NativePopulation.enabled then return end

    local radius = fort.area.combatRadius + Config.NativePopulation.extraRadius
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped)
            and not IsPedAPlayer(ped)
            and not isMissionEnemy(ped)
            and (not Config.NativePopulation.preserveMissionEntities or not IsEntityAMissionEntity(ped))
            and (not Config.NativePopulation.onlyHumanPeds or IsPedHuman(ped)) then
            local distance = #(GetEntityCoords(ped) - fort.area.center)
            if distance <= radius then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end
    end
end

local function startAreaControl(fortId)
    AreaControl = { fortId = fortId }
    local control = AreaControl

    CreateThread(function()
        while AreaControl == control do
            local fort = Config.Forts[fortId]
            if fort then clearNativePeds(fort) end
            Wait(Config.NativePopulation.checkInterval)
        end
    end)
end

local redirectRemainingEnemies

local function stopAreaControlAfterEnemies()
    local control = AreaControl
    if not control then return end

    CreateThread(function()
        while AreaControl == control do
            local fort = Config.Forts[control.fortId]
            if fort then redirectRemainingEnemies(fort) end

            local alive = 0
            for _, ped in ipairs(CurrentEnemies) do
                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    alive = alive + 1
                end
            end

            if alive == 0 then
                local networkIds = {}
                for _, ped in ipairs(CurrentEnemies) do
                    if DoesEntityExist(ped) then
                        local networkId = NetworkGetNetworkIdFromEntity(ped)
                        if networkId and networkId ~= 0 then networkIds[#networkIds + 1] = networkId end
                    end
                end
                TriggerEvent(
                    'redm_fortdomination:client:cleanupEnemies',
                    networkIds,
                    false,
                    Config.EnemyDefaults.corpseCleanupDelay
                )
                if AreaControl == control then AreaControl = nil end
                return
            end
            Wait(Config.EnemyDefaults.failedRetargetInterval or 3000)
        end
    end)
end

local function getAlivePlayersInArea(fort, excludeLeader)
    local players = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if (not excludeLeader or player ~= PlayerId()) and DoesEntityExist(ped) and not IsEntityDead(ped) then
            local distance = #(GetEntityCoords(ped) - fort.area.center)
            if distance <= fort.area.combatRadius then
                players[#players + 1] = ped
            end
        end
    end
    return players
end

local function chooseCombatTarget(index, enemyAmount, fort)
    local leader = PlayerPedId()

    -- Primeira metade sempre foca quem iniciou a missão.
    if index <= math.ceil(enemyAmount / 2) and not IsEntityDead(leader) then
        return leader
    end

    local players = getAlivePlayersInArea(fort, true)
    if #players == 0 then return leader end
    return players[math.random(1, #players)]
end

local function spawnEnemy(wave, index, fort)
    local models = wave.models or Config.EnemyModels
    local modelName = models[math.random(1, #models)]
    local spawnConfig = wave.spawnLocations[math.random(1, #wave.spawnLocations)]
    local configuredPoint = type(spawnConfig) == 'table'
    local spawn = configuredPoint and spawnConfig.coords or spawnConfig -- Compatibilidade com vector4 direto.
    local weapons = (configuredPoint and spawnConfig.weapons) or wave.weapons or { wave.weapon }
    local weaponName = weapons[math.random(1, #weapons)]
    local spread = wave.spawnSpread or Config.EnemyDefaults.spawnSpread
    local x = spawn.x + (math.random() * spread * 2.0 - spread)
    local y = spawn.y + (math.random() * spread * 2.0 - spread)
    local model = loadModel(modelName)
    if not model then return nil end

    local ped = CreatePed(model, x, y, spawn.z, spawn.w, true, true, true, true)
    if not DoesEntityExist(ped) then return nil end

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityHealth(ped, wave.health or Config.EnemyDefaults.health)
    SetPedAccuracy(ped, wave.accuracy or Config.EnemyDefaults.accuracy)
    SetPedCombatRange(ped, wave.combatRange or Config.EnemyDefaults.combatRange)
    SetPedCombatAbility(ped, wave.combatAbility or Config.EnemyDefaults.combatAbility)
    SetPedCombatMovement(ped, wave.combatMovement or Config.EnemyDefaults.combatMovement)
    SetPedRelationshipGroupHash(ped, EnemyGroup)
    SetBlockingOfNonTemporaryEvents(ped, true)

    GiveWeaponToPed(
        ped,
        joaat(weaponName),
        wave.weaponAmmo or Config.EnemyDefaults.weaponAmmo,
        false, true, 0, false, 0.5, 1.0, 0, false, 0.0, false
    )
    -- As armas dos inimigos são apenas de combate e não viram saque ao morrer.
    SetPedDropsWeaponsWhenDead(ped, false)

    local target = chooseCombatTarget(index, wave.enemyAmount, fort)
    TaskCombatPed(ped, target, 0, 16)
    AllMissionEnemies[#AllMissionEnemies + 1] = ped

    local networkId = NetworkGetNetworkIdFromEntity(ped)
    local networkTimeout = GetGameTimer() + 2000
    while (not networkId or networkId == 0) and GetGameTimer() < networkTimeout do
        Wait(50)
        networkId = NetworkGetNetworkIdFromEntity(ped)
    end
    if networkId and networkId ~= 0 then
        TriggerServerEvent('redm_fortdomination:server:registerEnemy', Mission.fortId, Mission.wave, networkId)
    end

    SetModelAsNoLongerNeeded(model)
    return ped
end

redirectRemainingEnemies = function(fort)
    local targets = getAlivePlayersInArea(fort, false)
    if #targets == 0 then return end

    for _, ped in ipairs(CurrentEnemies) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            TaskCombatPed(ped, targets[math.random(1, #targets)], 0, 16)
        end
    end
end

local function monitorWave(fortId, waveNumber)
    CreateThread(function()
        while Mission and Mission.active and Mission.wave == waveNumber do
            Wait(1000)

            local alive = 0
            for _, ped in ipairs(CurrentEnemies) do
                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    alive = alive + 1
                end
            end

            if alive == 0 then
                Wait(Config.Forts[fortId].waves[waveNumber].nextWaveDelay or Config.EnemyDefaults.nextWaveDelay)
                if not Mission or not Mission.active then return end
                TriggerServerEvent('redm_fortdomination:server:waveCleared', fortId, waveNumber)
                return
            end
        end
    end)
end

RegisterNetEvent('redm_fortdomination:client:setStarter', function(index, modelIndex, availableAt, missionActive, serverNow)
    if StarterNpc ~= 0 and DoesEntityExist(StarterNpc) then
        dismissStarterNpc()
    else
        removeStarterNpc()
    end
    StarterModel = Config.MissionStarter.models[modelIndex] or Config.MissionStarter.models[1]
    if availableAt ~= nil then
        local remainingSeconds = math.max(0, (tonumber(availableAt) or 0) - (tonumber(serverNow) or 0))
        StarterAvailableGameTimer = GetGameTimer() + (remainingSeconds * 1000)
    end
    if missionActive ~= nil then
        StarterMissionActive = missionActive == true
    end
    if index == 0 then
        StarterCoords = Config.MissionStarter.fixedLocation
    else
        StarterCoords = Config.MissionStarter.randomLocations[index]
    end
end)

RegisterNetEvent('redm_fortdomination:client:setStarterAvailability', function(availableAt, missionActive, serverNow)
    local remainingSeconds = math.max(0, (tonumber(availableAt) or 0) - (tonumber(serverNow) or 0))
    StarterAvailableGameTimer = GetGameTimer() + (remainingSeconds * 1000)
    StarterMissionActive = missionActive == true
    if StarterMissionActive then
        dismissStarterNpc()
    elseif not StarterDeparting then
        removeStarterNpc()
    end
end)

RegisterNetEvent('redm_fortdomination:client:setFortOwned', function(fortId, isOwned)
    if not Config.Forts[fortId] then return end

    OwnedForts[fortId] = isOwned == true
end)

RegisterNetEvent('redm_fortdomination:client:openFortMenu', function(payload)
    if type(payload) ~= 'table' or not payload.fortId then return end

    CurrentFortMenu = payload
    closeFortMenus()
    openMainFortMenu()
end)

RegisterNetEvent('redm_fortdomination:client:trackOpenChest', function(fortId)
    if not Config.Forts[fortId] then return end
    OpenFortChest = fortId
end)

RegisterNetEvent('redm_fortdomination:client:cleanupEnemies', function(networkIds, forceCleanup, delay)
    if type(networkIds) ~= 'table' then return end

    CreateThread(function()
        Wait(math.max(0, tonumber(delay) or Config.EnemyDefaults.corpseCleanupDelay or 60000))

        for _, networkId in ipairs(networkIds) do
            networkId = tonumber(networkId)
            if networkId and NetworkDoesNetworkIdExist(networkId) then
                local ped = NetworkGetEntityFromNetworkId(networkId)
                if ped ~= 0 and DoesEntityExist(ped) and (forceCleanup or IsEntityDead(ped)) then
                    local timeout = GetGameTimer() + 2000
                    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < timeout do
                        NetworkRequestControlOfEntity(ped)
                        Wait(50)
                    end
                    if DoesEntityExist(ped) then DeleteEntity(ped) end
                end
            end
        end
    end)
end)

AddEventHandler('syn:closeinv', function()
    OpenFortChest = nil
end)

RegisterNetEvent('redm_fortdomination:client:startMission', function(fortId)
    local fort = Config.Forts[fortId]
    if not fort then return end

    Mission = {
        active = true,
        failed = false,
        fortId = fortId,
        wave = 0,
        reachedFort = false,
        returnDeadline = nil,
    }

    setMissionBlip(fort)
    notify(Lang.missionAccepted:format(fort.name))
end)

RegisterNetEvent('redm_fortdomination:client:startWave', function(fortId, waveNumber)
    if not Mission or not Mission.active or Mission.fortId ~= fortId then return end

    local fort = Config.Forts[fortId]
    local wave = fort.waves[waveNumber]
    if not wave then return end

    Mission.wave = waveNumber
    Mission.spawning = true
    CurrentEnemies = {}
    if waveNumber == 1 and not AreaControl then
        startAreaControl(fortId)
    end
    notify(Lang.waveStarted:format(waveNumber, #fort.waves))

    for index = 1, wave.enemyAmount do
        -- O primeiro NPC também respeita o intervalo: 15 NPCs levam 15 segundos.
        Wait(wave.spawnInterval or Config.EnemyDefaults.spawnInterval)
        if not Mission or not Mission.active or Mission.wave ~= waveNumber then
            Mission = nil
            return
        end

        local enemy = spawnEnemy(wave, index, fort)
        if enemy then CurrentEnemies[#CurrentEnemies + 1] = enemy end
    end

    Mission.spawning = false
    monitorWave(fortId, waveNumber)
end)

RegisterNetEvent('redm_fortdomination:client:finishMission', function(result)
    removeMissionBlip()

    if result == 'completed' then
        AreaControl = nil
        notify(Lang.missionCompleted)
        if Mission and Config.Forts[Mission.fortId] then
            notify(Lang.newDominator:format(Config.Forts[Mission.fortId].name))
        end
    elseif result == 'arrival_expired' then
        AreaControl = nil
        notify(Lang.arrivalExpired)
    elseif result == 'area_abandoned' then
        stopAreaControlAfterEnemies()
        notify(Lang.areaAbandoned)
    else
        -- Após a derrota, mantém a área limpa até morrer o último inimigo da onda.
        stopAreaControlAfterEnemies()
        notify(Lang.missionFailed)
    end

    -- Em caso de derrota, os inimigos existentes permanecem vivos.
    if Mission then
        Mission.active = false
        Mission.failed = result ~= 'completed'
    end
    Mission = nil
end)

CreateThread(function()
    AddRelationshipGroup('FORT_DOMINATION_ENEMIES')
    SetRelationshipBetweenGroups(5, EnemyGroup, joaat('PLAYER'))
    SetRelationshipBetweenGroups(5, joaat('PLAYER'), EnemyGroup)
    createStarterPrompt()
    createChestPrompt()
    createManagementPrompt()
    TriggerServerEvent('redm_fortdomination:server:requestStarter')

    while true do
        local wait = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        if StarterCoords then
            local distance = #(playerCoords - vector3(StarterCoords.x, StarterCoords.y, StarterCoords.z))
            local starterIsAvailable = not StarterMissionActive and GetGameTimer() >= StarterAvailableGameTimer

            if starterIsAvailable and not StarterDeparting and distance <= Config.StarterNpcRenderDistance then
                spawnStarterNpc()
            elseif not StarterDeparting then
                removeStarterNpc()
            end

            if starterIsAvailable and distance <= Config.StarterPromptDistance and not Mission then
                wait = 0
                local groupLabel = CreateVarString(10, 'LITERAL_STRING', Lang.starterName)
                UiPromptSetActiveGroupThisFrame(joaat('FORT_DOMINATION_STARTER'), groupLabel, 1, 0, 0, 0)

                if UiPromptHasHoldModeCompleted(StarterPrompt) then
                    TriggerServerEvent('redm_fortdomination:server:requestMission', Config.DefaultFort)
                    Wait(1000)
                end
            end
        end

        if Mission and Mission.active and not Mission.reachedFort then
            local fort = Config.Forts[Mission.fortId]
            if #(playerCoords - fort.area.center) <= fort.area.activationRadius then
                Mission.reachedFort = true
                removeMissionBlip()
                TriggerServerEvent('redm_fortdomination:server:fortReached', Mission.fortId)
            end
        end

        -- Depois que o combate começa, o iniciador deve permanecer na área de segurança.
        if Mission and Mission.active and Mission.reachedFort then
            local fort = Config.Forts[Mission.fortId]
            local safetyRadius = fort.area.safetyRadius or fort.area.combatRadius
            local distanceFromFort = #(playerCoords - fort.area.center)

            if distanceFromFort > safetyRadius then
                if not Mission.returnDeadline then
                    Mission.returnDeadline = GetGameTimer() + ((fort.area.returnTimeLimit or 30) * 1000)
                    notify(Lang.leaveAreaWarning)
                else
                    local remaining = math.max(0, math.ceil((Mission.returnDeadline - GetGameTimer()) / 1000))
                    if remaining > 0 then
                        notifyCountdown(Lang.leaveAreaCountdown:format(remaining))
                    else
                        local fortId = Mission.fortId
                        Mission.active = false
                        Mission.failed = true
                        redirectRemainingEnemies(fort)
                        TriggerServerEvent('redm_fortdomination:server:leaderLeftArea', fortId)
                    end
                end
            elseif Mission.returnDeadline then
                Mission.returnDeadline = nil
                notify(Lang.returnedToArea)
            end
        end

        -- O armário e o menu administrativo possuem posições e prompts independentes.
        for fortId, isOwned in pairs(OwnedForts) do
            local fort = Config.Forts[fortId]
            local completion = fort and fort.completion
            if isOwned and completion and completion.storage then
                local chestCoords = completion.chestLocation
                local chestDistance = #(playerCoords - vector3(chestCoords.x, chestCoords.y, chestCoords.z))
                if chestDistance <= (completion.chestPromptDistance or 2.0) then
                    wait = 0
                    local groupLabel = CreateVarString(10, 'LITERAL_STRING', Lang.chestName)
                    UiPromptSetActiveGroupThisFrame(joaat('FORT_DOMINATION_CHEST'), groupLabel, 1, 0, 0, 0)

                    if UiPromptHasStandardModeCompleted(ChestPrompt, 0) then
                        TriggerServerEvent('redm_fortdomination:server:openChest', fortId)
                        Wait(1000)
                    end
                end

                local managementCoords = completion.managementLocation
                if managementCoords then
                    local managementDistance = #(playerCoords - vector3(managementCoords.x, managementCoords.y, managementCoords.z))
                    if managementDistance <= (Config.MemberManagement.menuPromptDistance or 2.0) then
                        wait = 0
                        local groupLabel = CreateVarString(10, 'LITERAL_STRING', Lang.managementName)
                        UiPromptSetActiveGroupThisFrame(joaat('FORT_DOMINATION_MANAGEMENT'), groupLabel, 1, 0, 0, 0)

                        if UiPromptHasStandardModeCompleted(ManagementPrompt, 0) then
                            TriggerServerEvent('redm_fortdomination:server:requestFortMenu', fortId)
                            Wait(1000)
                        end
                    end
                end
            end
        end

        if CurrentFortMenu then
            wait = math.min(wait, 250)
            local fort = Config.Forts[CurrentFortMenu.fortId]
            local location = fort and fort.completion and fort.completion.managementLocation
            if not location or #(playerCoords - vector3(location.x, location.y, location.z)) > (Config.MemberManagement.menuCloseDistance or 4.0) then
                closeFortMenus()
                CurrentFortMenu = nil
            end
        end

        if OpenFortChest then
            wait = math.min(wait, 250)
            local fort = Config.Forts[OpenFortChest]
            local completion = fort and fort.completion
            local location = completion and completion.chestLocation
            if not location or #(playerCoords - vector3(location.x, location.y, location.z)) > (completion.chestCloseDistance or 4.0) then
                exports.vorp_inventory:closeInventory()
                OpenFortChest = nil
            end
        end

        -- A morte do iniciador encerra a missão em qualquer etapa.
        -- Inimigos já criados permanecem e passam a perseguir os sobreviventes da área.
        if Mission and Mission.active and IsEntityDead(playerPed) then
            local fortId = Mission.fortId
            Mission.active = false
            Mission.failed = true
            redirectRemainingEnemies(Config.Forts[fortId])
            TriggerServerEvent('redm_fortdomination:server:leaderDied', fortId)
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    removeStarterNpc()
    removeMissionBlip()
    AreaControl = nil
    if StarterPrompt then UiPromptDelete(StarterPrompt) end
    if ChestPrompt then UiPromptDelete(ChestPrompt) end
    if ManagementPrompt then UiPromptDelete(ManagementPrompt) end

    -- Somente ao parar o recurso os NPCs de missão são limpos.
    for _, ped in ipairs(AllMissionEnemies) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
