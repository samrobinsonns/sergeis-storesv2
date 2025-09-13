fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sergeis-storesv2'
author 'Sergei'
description 'QBCore Player Owned Stores with stock, employees, banking, fleet'
version '0.1.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/app.js',
  'html/styles.css',
  'html/images/*.svg'
}

shared_scripts {
  'config.lua',
  'shared/sh_roles.lua'
}

client_scripts {
  'client/target_wrapper.lua',
  'client/cl_targets.lua',
  'client/cl_nui.lua',
  'client/cl_shop.lua',
  'client/cl_fleet.lua',
  'client/cl_stock_missions.lua',
  'client/cl_main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/sv_inventory.lua',
  'server/sv_db.lua',
  'server/sv_main.lua',
  'server/sv_store.lua',
  'server/sv_fleet.lua',
  'server/sv_employees_banking.lua',
  'server/sv_stock_orders.lua',
  'server/sv_notifications.lua'
}

dependencies {
  'qb-core',
  'oxmysql',
  'qb-target',
  'ox_target',
  'qb-vehiclekeys'
}

optional_dependencies {
  'lb-phone'
}


