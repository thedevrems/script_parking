fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ThatYousuf'
description 'Parking System'
version '1.0.0'

dependency {
    'ox_target',
    'ParkingCreator'
}

shared_scripts {
    'config.lua',
    
    '@ox_lib/init.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}