local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

-- Generate random plate for new vehicles
local function generatePlate()
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local plate = ""
  for i = 1, 8 do
    local charIndex = math.random(1, #chars)
    plate = plate .. chars:sub(charIndex, charIndex)
  end
  return plate
end

-- Check if store has enough balance for purchase
local function hasStoreFunds(storeId, amount)
  local store = StoresCache[storeId]
  if not store then return false end
  return (store.account_balance or 0) >= amount
end

-- Purchase a vehicle using store funds
RegisterNetEvent('sergeis-stores:server:purchaseVehicle', function(storeId, vehicleModel)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  -- Check permissions
  local required = StorePermission.MANAGER
  local store = StoresCache[storeId]
  if not store then
    TriggerClientEvent('QBCore:Notify', src, 'Store not found', 'error')
    return
  end
  
  local level = StorePermission.EMPLOYEE -- Default level
  
  -- Check if owner
  if cid == store.owner_cid then
    level = StorePermission.OWNER
  else
    -- Check if employee
    local employee = MySQL.single.await('SELECT permission FROM sergeis_store_employees WHERE store_id = ? AND citizenid = ?', { storeId, cid })
    if employee then
      level = employee.permission
    end
  end
  
  if not HasStorePermission(level, required) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to purchase vehicles', 'error')
    return
  end
  
  -- Find vehicle config
  local vehicleConfig = nil
  for _, veh in ipairs(Config.FleetVehicles) do
    if veh.model == vehicleModel then
      vehicleConfig = veh
      break
    end
  end
  
  if not vehicleConfig then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid vehicle model', 'error')
    return
  end
  
  -- Check if store has enough funds
  if not hasStoreFunds(storeId, vehicleConfig.price) then
    TriggerClientEvent('QBCore:Notify', src, 'Insufficient store funds', 'error')
    return
  end
  
  -- Generate unique plate
  local plate = generatePlate()
  local attempts = 0
  while attempts < 10 do
    local existing = MySQL.single.await('SELECT plate FROM sergeis_store_vehicles WHERE plate = ?', { plate })
    if not existing then break end
    plate = generatePlate()
    attempts = attempts + 1
  end
  
  if attempts >= 10 then
    TriggerClientEvent('QBCore:Notify', src, 'Could not generate unique plate', 'error')
    return
  end
  
  -- Deduct funds from store account
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance - ? WHERE id = ?', { vehicleConfig.price, storeId })
  
  -- Add vehicle to database
  DB.AddVehicle(storeId, vehicleModel, plate)
  
  -- Log transaction
  DB.RecordTransaction(storeId, cid, -vehicleConfig.price, {
    type = 'vehicle_purchase',
    vehicle_model = vehicleModel,
    vehicle_label = vehicleConfig.label,
    plate = plate,
    description = 'Vehicle purchase: ' .. vehicleConfig.label
  })
  
  -- Update cache
  if StoresCache[storeId] then
    StoresCache[storeId].account_balance = (StoresCache[storeId].account_balance or 0) - vehicleConfig.price
  end
  
  TriggerClientEvent('QBCore:Notify', src, 'Vehicle purchased: ' .. vehicleConfig.label .. ' (' .. plate .. ')', 'success')
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

-- Spawn a stored vehicle
RegisterNetEvent('sergeis-stores:server:spawnVehicle', function(vehicleId)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  -- Get vehicle info
  local vehicle = MySQL.single.await('SELECT * FROM sergeis_store_vehicles WHERE id = ?', { vehicleId })
  if not vehicle then
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle not found', 'error')
    return
  end
  
  -- Check permissions
  local required = StorePermission.EMPLOYEE
  local level = DB.GetEmployeePermission(vehicle.store_id, cid)
  if cid == (StoresCache[vehicle.store_id] and StoresCache[vehicle.store_id].owner_cid) then
    level = StorePermission.OWNER
  end
  if not HasStorePermission(level, required) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to access this vehicle', 'error')
    return
  end
  
  -- Check if vehicle is stored
  if vehicle.stored ~= 1 then
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle is already spawned', 'error')
    return
  end
  
  -- Mark as not stored and trigger client spawn
  DB.SetVehicleStored(vehicleId, false)
  TriggerClientEvent('sergeis-stores:client:spawnVehicle', src, {
    id = vehicleId,
    model = vehicle.model,
    plate = vehicle.plate,
    storeId = vehicle.store_id
  })
end)

-- Store a spawned vehicle
RegisterNetEvent('sergeis-stores:server:storeVehicle', function(vehicleId)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  -- Get vehicle info
  local vehicle = MySQL.single.await('SELECT * FROM sergeis_store_vehicles WHERE id = ?', { vehicleId })
  if not vehicle then
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle not found', 'error')
    return
  end
  
  -- Check permissions
  local required = StorePermission.EMPLOYEE
  local level = DB.GetEmployeePermission(vehicle.store_id, cid)
  if cid == (StoresCache[vehicle.store_id] and StoresCache[vehicle.store_id].owner_cid) then
    level = StorePermission.OWNER
  end
  if not HasStorePermission(level, required) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to access this vehicle', 'error')
    return
  end
  
  -- Mark as stored
  DB.SetVehicleStored(vehicleId, true)
  TriggerClientEvent('QBCore:Notify', src, 'Vehicle stored successfully', 'success')
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

-- Sell a vehicle (get 50% of original price back)
RegisterNetEvent('sergeis-stores:server:sellVehicle', function(vehicleId)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  -- Get vehicle info
  local vehicle = MySQL.single.await('SELECT * FROM sergeis_store_vehicles WHERE id = ?', { vehicleId })
  if not vehicle then
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle not found', 'error')
    return
  end
  
  -- Check permissions
  local required = StorePermission.MANAGER
  local level = DB.GetEmployeePermission(vehicle.store_id, cid)
  if cid == (StoresCache[vehicle.store_id] and StoresCache[vehicle.store_id].owner_cid) then
    level = StorePermission.OWNER
  end
  if not HasStorePermission(level, required) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to sell vehicles', 'error')
    return
  end
  
  -- Check if vehicle is stored
  if vehicle.stored ~= 1 then
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle must be stored before selling', 'error')
    return
  end
  
  -- Find vehicle config to get original price
  local vehicleConfig = nil
  for _, veh in ipairs(Config.FleetVehicles) do
    if veh.model == vehicle.model then
      vehicleConfig = veh
      break
    end
  end
  
  local sellPrice = vehicleConfig and math.floor(vehicleConfig.price * 0.5) or 10000 -- 50% of original price or default
  
  -- Add funds to store account
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance + ? WHERE id = ?', { sellPrice, vehicle.store_id })
  
  -- Remove vehicle from database
  MySQL.query.await('DELETE FROM sergeis_store_vehicles WHERE id = ?', { vehicleId })
  
  -- Log transaction
  DB.RecordTransaction(vehicle.store_id, cid, sellPrice, {
    type = 'vehicle_sale',
    vehicle_model = vehicle.model,
    vehicle_label = vehicleConfig and vehicleConfig.label or vehicle.model,
    plate = vehicle.plate,
    description = 'Vehicle sale: ' .. (vehicleConfig and vehicleConfig.label or vehicle.model)
  })
  
  -- Update cache
  if StoresCache[vehicle.store_id] then
    StoresCache[vehicle.store_id].account_balance = (StoresCache[vehicle.store_id].account_balance or 0) + sellPrice
  end
  
  TriggerClientEvent('QBCore:Notify', src, 'Vehicle sold for $' .. sellPrice, 'success')
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

-- Legacy events for compatibility
RegisterNetEvent('sergeis-stores:server:addVehicle', function(storeId, model, plate)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  local required = StorePermission.MANAGER
  local level = DB.GetEmployeePermission(storeId, cid)
  if cid == (StoresCache[storeId] and StoresCache[storeId].owner_cid) then
    level = StorePermission.OWNER
  end
  if not HasStorePermission(level, required) then
    TriggerClientEvent('QBCore:Notify', src, 'No store permission', 'error')
    return
  end
  DB.AddVehicle(storeId, model, plate)
  TriggerClientEvent('QBCore:Notify', src, 'Vehicle added', 'success')
end)

RegisterNetEvent('sergeis-stores:server:setVehicleStored', function(vehId, stored)
  DB.SetVehicleStored(vehId, stored)
end)


