fx_version 'cerulean'
game 'gta5'
author 'D3ad'

author 'RPHub'
description 'RPHub FiveM Integration for ESX'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}