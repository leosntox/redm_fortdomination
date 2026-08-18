fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'redm_fortdomination'
description 'Missões configuráveis de domínio de fortes para VORP'
version '0.4.6'

shared_scripts {
    'config/config.lua',
    'config/forts.lua',
    'languages/pt_br.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'vorp_core',
    'vorp_inventory',
    'vorp_menu',
    'oxmysql'
}
