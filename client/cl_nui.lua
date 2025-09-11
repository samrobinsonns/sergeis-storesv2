local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false

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
  openUI('manage', { storeId = storeId, allowedTabs = { 'stock', 'manage', 'fleet', 'employees', 'banking' } })
end)

RegisterNetEvent('sergeis-stores:client:openStock', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStock', function(payload)
    print('DEBUG client openStock: storeId =', storeId)
    print('DEBUG client openStock: payload =', json.encode(payload or {}))
    print('DEBUG client openStock: allowedItems =', json.encode(payload.allowedItems or {}))
    openUI('stock', { storeId = storeId, items = payload.items or {}, allowedItems = payload.allowedItems or {}, allowedTabs = { 'stock', 'manage', 'fleet', 'employees', 'banking' } })
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
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getVehicles', function(vehicles)
    openUI('fleet', { storeId = storeId, vehicles = vehicles, allowedTabs = { 'stock', 'manage', 'fleet', 'employees', 'banking' } })
  end, storeId)
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

RegisterNUICallback('updateEmployeePermission', function(data, cb)
  local storeId = data.storeId
  local citizenid = data.citizenid
  local permission = tonumber(data.permission) or 1
  if storeId and citizenid then
    TriggerServerEvent('sergeis-stores:server:updateEmployeePermission', storeId, citizenid, permission)
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


