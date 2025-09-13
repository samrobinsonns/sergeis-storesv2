local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false

local ALL_MANAGE_TABS = { 'stock', 'manage', 'fleet', 'upgrades', 'about', 'employees', 'banking' }

local function tabsForPermission(perm)
  if perm and perm >= (StorePermission and StorePermission.MANAGER or 2) then
    return ALL_MANAGE_TABS
  end
  return { 'stock' }
end

local function openUI(tab, data)
  if uiOpen then return end
  uiOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', tab = tab, data = data })
end

local function closeUI()
  if not uiOpen then return end
  uiOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
  closeUI()
  cb(1)
end)

RegisterNetEvent('sergeis-stores:client:openManage', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(map)
    local perm = map and map[storeId] or 0
    local allowed = tabsForPermission(perm)
    if #allowed == 1 and allowed[1] == 'stock' then
      -- Employees: redirect to stock view which fetches items
      TriggerEvent('sergeis-stores:client:openStock', storeId)
      return
    end
    openUI('manage', { storeId = storeId, allowedTabs = allowed })
  end)
end)

RegisterNetEvent('sergeis-stores:client:openStock', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStock', function(payload)
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(map)
      local perm = map and map[storeId] or 0
      local allowed = tabsForPermission(perm)
      openUI('stock', {
        storeId = storeId,
        items = payload.items or {},
        allowedItems = payload.allowedItems or {},
        usedCapacity = payload.usedCapacity,
        maxCapacity = payload.maxCapacity,
        allowedTabs = allowed
      })
    end)
  end, storeId)
end)

RegisterNetEvent('sergeis-stores:client:openPurchase', function(locationCode)
  openUI('purchase', { locationCode = locationCode, allowedTabs = { 'purchase' } })
end)

RegisterNUICallback('purchase', function(data, cb)
  local code = data.locationCode
  if code then
    TriggerServerEvent('sergeis-stores:server:purchaseLocation', code)
  end
  cb(1)
end)

RegisterNetEvent('sergeis-stores:client:openShop', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStock', function(payload)
    -- Open Store should ALWAYS be customer shopping mode, regardless of permissions
    openUI('shop', { storeId = storeId, items = payload.items or {}, allowedTabs = { 'shop' } })
  end, storeId)
end)

RegisterNetEvent('sergeis-stores:client:openFleet', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(map)
    local perm = map and map[storeId] or 0
    local allowed = tabsForPermission(perm)
    if #allowed == 1 and allowed[1] == 'stock' then
      -- Employees are not allowed into fleet; show stock instead
      TriggerEvent('sergeis-stores:client:openStock', storeId)
      return
    end
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getVehicles', function(vehicles)
      openUI('fleet', { storeId = storeId, vehicles = vehicles, allowedTabs = allowed })
    end, storeId)
  end)
end)
-- Upgrades
RegisterNUICallback('purchaseCapacityUpgrade', function(data, cb)
  local storeId = data.storeId
  local tier = tonumber(data.tier)
  if storeId and tier then
    TriggerServerEvent('sergeis-stores:server:purchaseCapacityUpgrade', storeId, tier)
  end
  cb(1)
end)

-- Get capacity upgrades from Config
RegisterNUICallback('getCapacityUpgrades', function(_, cb)
  cb({ upgrades = Config.CapacityUpgrades or {} })
end)

RegisterNUICallback('getPurchasedUpgrades', function(data, cb)
  local storeId = data.storeId
  if storeId then
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getPurchasedUpgrades', function(map)
      cb({ purchased = map or {} })
    end, storeId)
  else
    cb({ purchased = {} })
  end
end)

RegisterNUICallback('getStockOrderPrices', function(data, cb)
  local storeId = data.storeId
  if storeId then
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getStockOrderPrices', function(payload)
      cb(payload or { override = {}, global = {}, base = 5 })
    end, storeId)
  else
    cb({ override = {}, global = {}, base = 5 })
  end
end)

RegisterNetEvent('sergeis-stores:client:openUnownedShop', function(locationCode)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getUnownedStock', function(payload)
    openUI('shop', { locationCode = locationCode, items = payload.items or {}, allowedTabs = { 'shop' } })
  end, locationCode)
end)

-- Minimal purchase NUI callback
RegisterNUICallback('checkout', function(data, cb)
  local storeId = data.storeId
  local locationCode = data.locationCode
  local cart = data.cart or {}
  local payType = data.payType or Config.DefaultPayment
  
  if storeId then
    TriggerServerEvent('sergeis-stores:server:checkout', storeId, cart, payType)
  elseif locationCode then
    TriggerServerEvent('sergeis-stores:server:checkoutUnowned', locationCode, cart, payType)
  end
  cb(1)
end)

RegisterNUICallback('upsertStockAllowed', function(data, cb)
  local storeId = data.storeId
  local item = data.item
  local label = data.label
  local price = tonumber(data.price) or 0
  local stock = tonumber(data.stock) or 0
  TriggerServerEvent('sergeis-stores:server:upsertStockAllowed', storeId, item, label, price, stock)
  cb(1)
end)

RegisterNUICallback('getStock', function(data, cb)
  local storeId = data.storeId
  if storeId then
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getStock', function(payload)
      cb(payload)
    end, storeId)
  else
    cb({ items = {}, allowedItems = {} })
  end
end)

-- Employee Management Callbacks
RegisterNUICallback('getEmployees', function(data, cb)
  print('NUI Callback getEmployees called with data:', json.encode(data))
  
  local storeId = data.storeId
  if storeId then
    print('Triggering server callback for employees with storeId:', storeId)
    
    -- Add timeout for the callback
    local responded = false
    local function respond(employees)
      if not responded then
        responded = true
        print('Received employees response:', json.encode(employees or {}))
        cb({ employees = employees or {} })
      end
    end
    
    -- Set a timeout
    CreateThread(function()
      Wait(2000) -- 2 second timeout
      if not responded then
        print('ERROR: getEmployees server callback timed out')
        respond({})
      end
    end)
    
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getEmployees', respond, storeId)
  else
    print('No storeId provided for getEmployees')
    cb({ employees = {} })
  end
end)

RegisterNUICallback('hireEmployee', function(data, cb)
  local storeId = data.storeId
  local citizenid = data.citizenid
  local permission = data.permission or 1
  if storeId and citizenid then
    TriggerServerEvent('sergeis-stores:server:hireEmployee', storeId, citizenid, permission)
  end
  cb(1)
end)

RegisterNUICallback('fireEmployee', function(data, cb)
  local storeId = data.storeId
  local citizenid = data.citizenid
  if storeId and citizenid then
    TriggerServerEvent('sergeis-stores:server:fireEmployee', storeId, citizenid)
  end
  cb(1)
end)

-- Nearby players for hire UI
RegisterNUICallback('getNearbyPlayers', function(data, cb)
  local radius = tonumber(data.radius) or 5.0
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getNearbyPlayers', function(payload)
    cb(payload or { players = {} })
  end, radius)
end)

RegisterNUICallback('updateEmployeePermission', function(data, cb)
  local storeId = data.storeId
  local citizenid = data.citizenid
  local permission = tonumber(data.permission) or 1
  if storeId and citizenid then
    TriggerServerEvent('sergeis-stores:server:updateEmployeePermission', storeId, citizenid, permission)
  end
  cb(1)
end)

RegisterNUICallback('resetEmployeeStats', function(data, cb)
  local storeId = data.storeId
  if storeId then
    TriggerServerEvent('sergeis-stores:server:resetEmployeeStats', storeId)
  end
  cb(1)
end)

RegisterNUICallback('resetEmployeeStat', function(data, cb)
  local storeId = data.storeId
  local citizenid = data.citizenid
  if storeId and citizenid then
    TriggerServerEvent('sergeis-stores:server:resetEmployeeStat', storeId, citizenid)
  end
  cb(1)
end)

-- Fleet Management Callbacks
RegisterNUICallback('getFleetVehicles', function(data, cb)
  local storeId = data.storeId
  if storeId then
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getVehicles', function(vehicles)
      cb({ vehicles = vehicles or {}, availableVehicles = Config.FleetVehicles or {} })
    end, storeId)
  else
    cb({ vehicles = {}, availableVehicles = {} })
  end
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
  local storeId = data.storeId
  local vehicleModel = data.vehicleModel
  if storeId and vehicleModel then
    TriggerServerEvent('sergeis-stores:server:purchaseVehicle', storeId, vehicleModel)
  end
  cb(1)
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
  local vehicleId = tonumber(data.vehicleId)
  if vehicleId then
    TriggerServerEvent('sergeis-stores:server:spawnVehicle', vehicleId)
  end
  cb(1)
end)

RegisterNUICallback('sellVehicle', function(data, cb)
  local vehicleId = tonumber(data.vehicleId)
  if vehicleId then
    TriggerServerEvent('sergeis-stores:server:sellVehicle', vehicleId)
  end
  cb(1)
end)

-- Store info & renaming
RegisterNUICallback('getStoreInfo', function(data, cb)
  local storeId = data.storeId
  if storeId then
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getStoreInfo', function(info)
      cb(info or { id = storeId, name = ('Store ' .. tostring(storeId)) })
    end, storeId)
  else
    cb({ id = 0, name = 'Store' })
  end
end)

RegisterNUICallback('updateStoreName', function(data, cb)
  local storeId = data.storeId
  local newName = data.newName or ''
  if storeId and newName and newName ~= '' then
    TriggerServerEvent('sergeis-stores:server:updateStoreName', storeId, newName)
  end
  cb(1)
end)

RegisterNUICallback('updateStoreBlip', function(data, cb)
  local storeId = data.storeId
  local spriteId = tonumber(data.spriteId)
  if storeId and spriteId then
    TriggerServerEvent('sergeis-stores:server:updateStoreBlip', storeId, spriteId, nil)
  end
  cb(1)
end)

RegisterNUICallback('sellStore', function(data, cb)
  local storeId = data.storeId
  if storeId then
    TriggerServerEvent('sergeis-stores:server:sellStore', storeId)
  end
  cb(1)
end)

RegisterNUICallback('transferStore', function(data, cb)
  local storeId = data.storeId
  local targetCitizenId = data.citizenid
  if storeId and targetCitizenId and targetCitizenId ~= '' then
    TriggerServerEvent('sergeis-stores:server:transferStore', storeId, targetCitizenId)
  end
  cb(1)
end)

-- Banking Callbacks
RegisterNUICallback('getBankingInfo', function(data, cb)
  print('NUI Callback getBankingInfo called with data:', json.encode(data))
  
  -- Test the callback registration first
  print('Testing banking callback registration...')
  QBCore.Functions.TriggerCallback('sergeis-stores:server:testBanking', function(testResult)
    print('Banking test callback result:', json.encode(testResult))
  end)
  
  local storeId = data.storeId
  if storeId then
    print('Triggering server callback for banking with storeId:', storeId)
    
    -- Add timeout for the callback
    local responded = false
    local function respond(bankingData)
      if not responded then
        responded = true
        print('Received banking response:', json.encode(bankingData or {}))
        cb(bankingData or { balance = 0, transactions = {} })
      end
    end
    
    -- Set a timeout
    CreateThread(function()
      Wait(2000) -- 2 second timeout
      if not responded then
        print('ERROR: getBankingInfo server callback timed out')
        respond({ balance = 0, transactions = {} })
      end
    end)
    
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getBankingInfo', respond, storeId)
  else
    print('No storeId provided for getBankingInfo')
    cb({ balance = 0, transactions = {} })
  end
end)

RegisterNUICallback('depositMoney', function(data, cb)
  local storeId = data.storeId
  local amount = tonumber(data.amount) or 0
  local payType = data.payType or Config.DefaultPayment or 'cash'
  if storeId and amount > 0 then
    TriggerServerEvent('sergeis-stores:server:depositMoney', storeId, amount, payType)
  end
  cb(1)
end)

RegisterNUICallback('withdrawMoney', function(data, cb)
  local storeId = data.storeId
  local amount = tonumber(data.amount) or 0
  local payType = data.payType or Config.DefaultPayment or 'cash'
  if storeId and amount > 0 then
    TriggerServerEvent('sergeis-stores:server:withdrawMoney', storeId, amount, payType)
  end
  cb(1)
end)

-- Stock ordering callback
RegisterNUICallback('startStockOrder', function(data, cb)
  print('NUI startStockOrder callback triggered')
  print('Data received:', json.encode(data))
  
  local storeId = data.storeId
  local vehicleId = tonumber(data.vehicleId)
  local orderItems = data.orderItems or {}
  
  print('Parsed values - storeId:', storeId, 'vehicleId:', vehicleId, 'orderItems count:', #orderItems)
  
  if storeId and vehicleId and #orderItems > 0 then
    print('Triggering server event with:', storeId, vehicleId, json.encode(orderItems))
    TriggerServerEvent('sergeis-stores:server:startStockOrder', storeId, vehicleId, orderItems)
  else
    print('Failed validation - storeId:', storeId, 'vehicleId:', vehicleId, 'orderItems count:', #orderItems)
  end
  cb(1)
end)

RegisterNUICallback('getLocationInfo', function(data, cb)
  local code = data.locationCode
  if code then
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getLocationInfo', function(info)
      cb(info or { label = code })
    end, code)
  else
    cb({ label = '' })
  end
end)


