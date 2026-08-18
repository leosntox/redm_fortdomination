Config.Forts = {
    FortWallace = {
        name = 'Forte Wallace',

        -- ÁREA QUE INICIA O COMBATE
        area = {
            center = vector3(355.80, 1487.82, 179.62),
            activationRadius = 85.0, -- Distância para o iniciador ativar o combate
            combatRadius = 150.0,    -- Área usada para localizar outros jogadores como alvos
            safetyRadius = 200.0,    -- Limite máximo que o iniciador pode se afastar durante o combate
            returnTimeLimit = 30,    -- Segundos disponíveis para retornar à área de segurança
        },

        -- MARCADOR TEMPORÁRIO EXIBIDO APÓS ACEITAR A MISSÃO
        blip = {
            enabled = true,
            sprite = -1489164512, -- Ícone nativo de líder de gangue
            colorModifier = 'BLIP_MODIFIER_MP_ENEMY_HOLDING', -- Cor de inimigo: vermelha e chamativa
            name = 'Invasão: Forte Wallace',
        },

        -- ONDAS: a quantidade de blocos abaixo determina o total de ondas.
        waves = {
            [1] = {
                enemyAmount = 32,
                spawnInterval = 1000, -- Um novo inimigo surge a cada 1 segundo

                -- Primeiro o ponto é sorteado; depois, uma arma da lista daquele ponto.
                spawnLocations = {
                    {
                        coords = vector4(364.2484, 1473.1879, 184.6309, 181.8621), -- Torre esquerda
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(347.2203, 1460.2563, 185.6095, 229.6502), -- Torre direita
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(346.3862, 1461.8904, 183.7109, 313.0509), -- Externo torre direita
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(363.8618, 1475.7831, 180.2207, 185.3640), -- Térreo torre esquerda
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(369.9953, 1491.9843, 182.4888, 199.9629), -- Lateral esquerda do forte
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(361.7403, 1513.3970, 184.8678, 210.8838), -- Torre 2 esquerda
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(321.8452, 1508.8970, 186.8380, 154.8236), -- Torre 2 direita
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                    {
                        coords = vector4(352.5056, 1490.5137, 179.5824, 183.6319), -- Centro do forte
                        weapons = { 'WEAPON_PISTOL_VOLCANIC', 'WEAPON_REPEATER_WINCHESTER' },
                    },
                },
            },
        },

        -- ARMÁRIO DE POSSE DO FORTE
        completion = {
            -- Posição do armário que já existe no mapa; nenhum objeto será criado aqui.
            chestLocation = vector4(367.6183, 1490.6833, 180.6784, 295.3758),
            chestPromptDistance = 2.0, -- Distância para visualizar o prompt do armário
            chestServerDistance = 4.0, -- Distância máxima validada pelo servidor ao tentar abrir
            chestPromptKey = 0xCEFD9220, -- Tecla E; basta apertar uma vez para abrir

            -- Ponto separado usado somente para administrar os membros do forte.
            managementLocation = vector4(337.2020, 1504.5496, 181.8742, 33.4485),

            -- Ao ultrapassar esta distância com o armário aberto, ele fecha automaticamente.
            chestCloseDistance = 4.0,

            -- Capacidade nativa do vorp_inventory medida em unidades, não em quilogramas.
            storage = {
                id = 'fort_domination_fort_wallace', -- Não altere após começar a usar ou criará outro armazenamento
                name = 'Armário do Forte Wallace',
                capacity = 2000,
                acceptWeapons = true,
            },

            -- Reservado para a futura bancada de fabricação.
            craftingLocation = vector3(352.90, 1490.20, 179.62),
        },

        -- RECOMPENSAS: uma das opções abaixo é sorteada a cada nova conquista.
        rewards = {
            enabled = true,
            options = {
                { type = 'money', amount = 50, label = '$50' },
                {
                    type = 'items',
                    label = '10 munições de repetidora',
                    fallbackMoney = 50, -- Recebido em dinheiro se os itens não couberem no armário
                    items = {
                        { name = 'ammorepeaternormal', amount = 10 },
                    },
                },
                {
                    type = 'items',
                    label = '10 munições de pistola',
                    fallbackMoney = 25,
                    items = {
                        { name = 'ammopistolnormal', amount = 10 },
                    },
                },
                {
                    type = 'items',
                    label = '5 pães e 5 águas',
                    fallbackMoney = 12,
                    items = {
                        { name = 'bread', amount = 5 },
                        { name = 'water', amount = 5 },
                    },
                },
                { type = 'money', amount = 1000, label = '$1000' },
            },
        },
    },
}
