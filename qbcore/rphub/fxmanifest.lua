fx_version 'cerulean'
game 'gta5'
author 'D3ad'

lua54 'yes'

author 'RPHub'
description 'RPHub FiveM Integration'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}