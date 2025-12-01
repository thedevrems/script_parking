fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ThatYousuf'
description 'Parking Creator'
version '1.0.0'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua'
}

client_scripts {
    'client/zoneCreator/*.lua',
    'client/main.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}