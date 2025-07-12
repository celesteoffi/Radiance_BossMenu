fx_version 'cerulean'
game 'gta5'

author 'VotreNom'
description 'Boss Menu F6 dynamique – ESX (legacy & 1.9) + oxmysql'
version '2.0.0'

shared_scripts {
  'config.lua',
  '@es_extended/imports.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

client_scripts {
  'client/main.lua'
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}
