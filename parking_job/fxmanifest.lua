fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Job Parking System compatible with qs-advancedgarages'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql',
    'ox_target',
    'qs-advancedgarages'
}
