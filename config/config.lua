Config = Config or {}

-- CONFIGURAÇÕES GERAIS
Config.Debug = false                 -- true: mostra informações de teste no console
Config.GlobalCooldownSeconds = 7200  -- Cooldown do forte para todos: 7200 segundos = 2 horas
Config.ArrivalTimeLimit = 1800       -- Tempo máximo para chegar ao forte: 30 minutos
Config.StarterPromptDistance = 2.0   -- Distância para visualizar o prompt do NPC
Config.StarterNpcRenderDistance = 80.0
Config.StarterServerDistance = 4.0   -- Distância máxima do informante validada pelo servidor
Config.InteractionKey = 0xCEFD9220   -- Tecla E
Config.InteractionHoldTime = 800     -- Tempo segurando a tecla para iniciar
Config.DefaultFort = 'FortWallace'   -- Forte entregue pelo NPC nesta primeira versão

-- ADMINISTRAÇÃO DO FORTE
Config.MemberManagement = {
    maxMembers = 10,          -- Quantidade máxima de membros por forte
    addDistance = 5.0,        -- Distância máxima entre Dominador e jogador ao adicionar
    menuServerDistance = 4.0, -- Distância máxima do ponto do menu validada pelo servidor
    menuPromptDistance = 2.0, -- Distância para visualizar o prompt do menu
    menuCloseDistance = 4.0,  -- Ao ultrapassar esta distância, o menu fecha
}

-- NPC QUE ENTREGA A MISSÃO
Config.MissionStarter = {
    randomLocation = false, -- true: sorteia um local quando o recurso inicia; false: usa fixedLocation
    relocateIntervalSeconds = 3600, -- Troca local e modelo a cada 1 hora; use 0 para trocar somente ao reiniciar
    scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',
    departureRemoveDistance = 60.0, -- Só desaparece quando nenhum jogador estiver dentro deste raio
    departureCheckInterval = 1000,  -- Verifica a distância dos jogadores a cada 1 segundo

    -- Três homens e duas mulheres com aparência de criminosos/bandidos.
    models = {
        'G_M_M_UNIBANDITOS_01',
        'G_M_M_UNICRIMINALS_01',
        'G_M_M_UNIDUSTER_01',
        'G_F_M_UNIDUSTER_01',
        'A_F_M_SKPPRISONONLINE_01',
    },

    fixedLocation = vector4(-246.2347, 766.6339, 121.0271, 17.2001),

    randomLocations = {
        vector4(-274.17, 805.03, 119.38, 100.0), -- Valentine
        vector4(1231.62, -1298.76, 76.90, 140.0), -- Rhodes
        vector4(-875.10, -1334.62, 43.96, 90.0), -- Blackwater
    }
}

-- MODELOS SORTEADOS INDIVIDUALMENTE PARA CADA INIMIGO
Config.EnemyModels = {
    'G_M_M_UNIBANDITOS_01',
    'G_M_M_UNICRIMINALS_01',
    'G_M_M_UNIDUSTER_01',
    'G_M_M_UNIMOUNTAINMEN_01',
    'G_M_M_UNIINBRED_01',
}

-- COMPORTAMENTO PADRÃO DOS INIMIGOS
Config.EnemyDefaults = {
    health = 100,
    accuracy = 50,             -- Precisão de 0 a 100
    weaponAmmo = 999,
    combatRange = 2,           -- 0: perto; 1: médio; 2: longe
    combatAbility = 2,         -- 0: fraco; 1: normal; 2: profissional
    combatMovement = 2,        -- 0: parado; 1: defensivo; 2: ofensivo; 3: versátil
    spawnSpread = 2.5,         -- Deslocamento aleatório ao redor de cada ponto
    spawnInterval = 1000,      -- Intervalo entre cada NPC: 1000 ms = 1 segundo
    nextWaveDelay = 5000,      -- Intervalo após eliminar uma onda
    corpseCleanupDelay = 60000, -- Remove cadáveres da missão após 60 segundos
    failedRetargetInterval = 3000, -- Atualiza os alvos sobreviventes após uma derrota
}

-- CONTROLE DOS NPCS NATIVOS DENTRO DO FORTE
Config.NativePopulation = {
    enabled = true,          -- true: remove os NPCs ambientes durante a missão
    onlyHumanPeds = true,    -- true: preserva cavalos e outros animais nativos
    checkInterval = 2000,    -- Intervalo entre verificações da área
    extraRadius = 10.0,      -- Margem adicionada ao raio de combate do forte
    preserveMissionEntities = true, -- Não remove NPCs controlados por outros recursos
}

-- SEGURANÇA E SINCRONIZAÇÃO
Config.ServerValidation = {
    fortArrivalTolerance = 10.0, -- Margem adicional para validar a chegada ao forte
    enemyValidationRadius = 30.0, -- Margem além do raio de combate para validar inimigos
    disconnectCleanupDelay = 10000, -- Remove inimigos abandonados 10 s após desconexão do iniciador
}
