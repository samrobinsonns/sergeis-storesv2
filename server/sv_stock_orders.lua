local QBCore = exports['qb-core']:GetCoreObject()

print('Loading sv_stock_orders.lua')

-- Reset all vehicles to stored state on resource restart
CreateThread(function()
  Wait(1000) -- Wait for database to be ready
  print('Resetting all fleet vehicles to stored state after restart...')
  
  local success, result = pcall(function()
    return MySQL.query.await('UPDATE sergeis_store_vehicles SET stored = 1 WHERE stored = 0', {})
  end)
  
  if success then
    print('Fleet vehicles reset to available state:', result and result.affectedRows or 0, 'vehicles updated')
  else
    print('Failed to reset fleet vehicles:', result)
  end
end)

-- Active stock orders tracking
local activeOrders = {}

local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

-- Generate unique order ID
local function generateOrderId()
  return 'order_' .. math.random(100000, 999999) .. '_' .. os.time()
end

-- Calculate order cost
local function calculateOrderCost(orderItems)
  local totalCost = 0
  for _, item in ipairs(orderItems) do
    local itemPrice = Config.StockOrdering.itemPrices[item.item] or Config.StockOrdering.basePricePerUnit
    totalCost = totalCost + (item.quantity * itemPrice)
  end
  return totalCost
end

-- Start stock order mission
RegisterNetEvent('sergeis-stores:server:startStockOrder', function(storeId, vehicleId, orderItems)
  local src = source
  print('Server startStockOrder event triggered for source:', src)
  print('Parameters - storeId:', storeId, 'vehicleId:', vehicleId, 'orderItems:', json.encode(orderItems or {}))
  
  local cid = getCitizenId(src)
  if not cid then 
    print('Failed to get citizen ID for source:', src)
    return 
  end
  print('Citizen ID:', cid)
  
  -- Check permissions
  local store = StoresCache[storeId]
  if not store then
    print('Store not found in cache:', storeId)
    TriggerClientEvent('QBCore:Notify', src, 'Store not found', 'error')
    return
  end
  
  local currentLevel = StorePermission.EMPLOYEE -- Default level
  
  -- Check if owner
  if store.owner_cid == cid then
    currentLevel = StorePermission.OWNER
  else
    -- Check if employee
    local employee = MySQL.single.await('SELECT permission FROM sergeis_store_employees WHERE store_id = ? AND citizenid = ?', { storeId, cid })
    if employee then
      currentLevel = employee.permission
    else
      TriggerClientEvent('QBCore:Notify', src, 'No permission to order stock', 'error')
      return
    end
  end
  
  if not HasStorePermission(currentLevel, StorePermission.EMPLOYEE) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to order stock', 'error')
    return
  end
  
  -- Validate vehicle ownership and availability
  print('Checking vehicle - vehicleId:', vehicleId, 'storeId:', storeId)
  local vehicle = MySQL.single.await('SELECT * FROM sergeis_store_vehicles WHERE id = ? AND store_id = ? AND stored = 1', { vehicleId, storeId })
  print('Vehicle query result:', json.encode(vehicle or {}))
  if not vehicle then
    print('Vehicle not found or not available')
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle not available', 'error')
    return
  end
  
  -- Find vehicle config for capacity
  local vehicleConfig = nil
  for _, veh in ipairs(Config.FleetVehicles) do
    if veh.model == vehicle.model then
      vehicleConfig = veh
      break
    end
  end
  
  if not vehicleConfig then
    TriggerClientEvent('QBCore:Notify', src, 'Vehicle configuration not found', 'error')
    return
  end
  
  -- Validate order capacity
  local totalUnits = 0
  for _, item in ipairs(orderItems) do
    totalUnits = totalUnits + item.quantity
  end
  
  if totalUnits > vehicleConfig.capacity then
    TriggerClientEvent('QBCore:Notify', src, 'Order exceeds vehicle capacity', 'error')
    return
  end
  
  -- Calculate and check cost
  local orderCost = calculateOrderCost(orderItems)
  local store = StoresCache[storeId]
  if not store or (store.account_balance or 0) < orderCost then
    TriggerClientEvent('QBCore:Notify', src, 'Insufficient store funds', 'error')
    return
  end
  
  -- Check store location for pickup point
  local storeLocation = nil
  for code, loc in pairs(Config.Locations) do
    if store.location_code == code then
      storeLocation = loc
      break
    end
  end
  
  if not storeLocation or not storeLocation.pickup then
    TriggerClientEvent('QBCore:Notify', src, 'No pickup location configured for this store', 'error')
    return
  end
  
  -- Deduct cost from store account
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance - ? WHERE id = ?', { orderCost, storeId })
  
  -- Update cache
  if StoresCache[storeId] then
    StoresCache[storeId].account_balance = (StoresCache[storeId].account_balance or 0) - orderCost
  end
  
  -- Mark vehicle as not stored (in use)
  DB.SetVehicleStored(vehicleId, false)
  
  -- Generate order ID and store order data
  local orderId = generateOrderId()
  activeOrders[orderId] = {
    id = orderId,
    storeId = storeId,
    vehicleId = vehicleId,
    citizenId = cid,
    orderItems = orderItems,
    cost = orderCost,
    status = 'pickup', -- pickup, delivery, completed
    pickupLocation = storeLocation.pickup.location,
    pickupLabel = storeLocation.pickup.label,
    deliveryLocation = storeLocation.points.delivery,
    vehicle = vehicle,
    startTime = os.time()
  }
  
  -- Log transaction
  DB.RecordTransaction(storeId, cid, -orderCost, {
    type = 'stock_order',
    orderId = orderId,
    items = orderItems,
    description = 'Stock order - ' .. #orderItems .. ' items'
  })
  
  -- Give keys on server side (more reliable)
  local keyGiven = false
  local keyMethods = {
    function() 
      if GetResourceState('qb-vehiclekeys') == 'started' then
        exports['qb-vehiclekeys']:GiveKeys(src, vehicle.plate)
        return true
      end
      return false
    end,
    function()
      if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('qb-vehiclekeys:server:GiveVehicleKeys', src, vehicle.plate)
        return true
      end
      return false
    end
  }
  
  for i, method in ipairs(keyMethods) do
    local success, result = pcall(method)
    if success and result then
      print('Server: Keys given via method', i, 'for plate:', vehicle.plate, 'to source:', src)
      keyGiven = true
      break
    end
  end
  
  if not keyGiven then
    print('Server: All key methods failed, client will handle fallback')
  end
  
  -- Spawn vehicle and give keys
  TriggerClientEvent('sergeis-stores:client:startStockMission', src, {
    orderId = orderId,
    vehicle = vehicle,
    spawnLocation = storeLocation.points.fleet or storeLocation.points.delivery, -- Fallback to delivery if no fleet point
    pickupLocation = storeLocation.pickup.location,
    pickupLabel = storeLocation.pickup.label,
    deliveryLocation = storeLocation.points.delivery,
    orderItems = orderItems
  })
  
  TriggerClientEvent('QBCore:Notify', src, 'Stock order started! Head to ' .. storeLocation.pickup.label, 'success')
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

-- Handle pickup completion
RegisterNetEvent('sergeis-stores:server:completePickup', function(orderId)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  local order = activeOrders[orderId]
  if not order or order.citizenId ~= cid then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid order', 'error')
    return
  end
  
  if order.status ~= 'pickup' then
    TriggerClientEvent('QBCore:Notify', src, 'Order not in pickup phase', 'error')
    return
  end
  
  -- Update order status
  activeOrders[orderId].status = 'delivery'
  
  TriggerClientEvent('QBCore:Notify', src, 'Stock loaded! Return to store to complete delivery', 'success')
  TriggerClientEvent('sergeis-stores:client:updateMissionStatus', src, 'delivery', order.deliveryLocation)
end)

-- Handle delivery completion
RegisterNetEvent('sergeis-stores:server:completeDelivery', function(orderId)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  local order = activeOrders[orderId]
  if not order or order.citizenId ~= cid then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid order', 'error')
    return
  end
  
  if order.status ~= 'delivery' then
    TriggerClientEvent('QBCore:Notify', src, 'Order not in delivery phase', 'error')
    return
  end
  
  -- Before updating stock, enforce store max capacity if configured
  local storeRow = StoresCache[order.storeId]
  local locCfg = storeRow and storeRow.location_code and Config.Locations[storeRow.location_code]
  local maxCapacity = locCfg and tonumber(locCfg.maxCapacity) or nil
  if maxCapacity then
    local currentTotal = 0
    for _, row in ipairs(DB.GetStock(order.storeId)) do
      currentTotal = currentTotal + (tonumber(row.stock) or 0)
    end
    local incomingTotal = 0
    for _, item in ipairs(order.orderItems) do
      incomingTotal = incomingTotal + (tonumber(item.quantity) or 0)
    end
    if currentTotal + incomingTotal > maxCapacity then
      TriggerClientEvent('QBCore:Notify', src, ('Cannot complete delivery: capacity exceeded (%d + %d > %d)'):format(currentTotal, incomingTotal, maxCapacity), 'error')
      return
    end
  end

  -- Update stock for each item
  for _, item in ipairs(order.orderItems) do
    -- Check if item already exists
    local existingItem = MySQL.single.await('SELECT stock FROM sergeis_store_items WHERE store_id = ? AND item = ?', { order.storeId, item.item })
    
    if existingItem then
      -- Item exists, add to existing stock
      DB.AdjustStock(order.storeId, item.item, item.quantity)
      print('Added', item.quantity, 'of', item.item, 'to existing stock')
    else
      -- Item doesn't exist, create new entry
      local itemPrice = Config.StockOrdering.itemPrices[item.item] or Config.StockOrdering.basePricePerUnit
      DB.UpsertStockItem(order.storeId, item.item, item.item, itemPrice, item.quantity)
      print('Created new stock entry for', item.item, 'with quantity', item.quantity)
    end
  end
  
  -- Store vehicle back
  DB.SetVehicleStored(order.vehicleId, true)
  
  -- Mark order as completed
  activeOrders[orderId].status = 'completed'
  activeOrders[orderId].completedTime = os.time()
  
  -- Clean up order after a delay
  CreateThread(function()
    Wait(60000) -- Keep for 1 minute for debugging
    activeOrders[orderId] = nil
  end)
  
  TriggerClientEvent('QBCore:Notify', src, 'Stock delivery completed! Items added to inventory', 'success')
  TriggerClientEvent('sergeis-stores:client:endStockMission', src)
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

-- Cancel order (admin or timeout)
RegisterNetEvent('sergeis-stores:server:cancelStockOrder', function(orderId)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  local order = activeOrders[orderId]
  if not order or order.citizenId ~= cid then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid order', 'error')
    return
  end
  
  -- Refund money to store
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance + ? WHERE id = ?', { order.cost, order.storeId })
  
  -- Update cache
  if StoresCache[order.storeId] then
    StoresCache[order.storeId].account_balance = (StoresCache[order.storeId].account_balance or 0) + order.cost
  end
  
  -- Store vehicle back
  DB.SetVehicleStored(order.vehicleId, true)
  
  -- Remove order
  activeOrders[orderId] = nil
  
  TriggerClientEvent('QBCore:Notify', src, 'Stock order cancelled', 'info')
  TriggerClientEvent('sergeis-stores:client:endStockMission', src)
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

-- Get active order for player
QBCore.Functions.CreateCallback('sergeis-stores:server:getActiveOrder', function(source, cb, storeId)
  local cid = getCitizenId(source)
  if not cid then 
    cb(nil)
    return 
  end
  
  for orderId, order in pairs(activeOrders) do
    if order.citizenId == cid and order.storeId == storeId then
      cb(order)
      return
    end
  end
  
  cb(nil)
end)

-- Cleanup abandoned orders (run periodically)
CreateThread(function()
  while true do
    Wait(60000) -- Check every minute
    
    local currentTime = os.time()
    for orderId, order in pairs(activeOrders) do
      local timeElapsed = currentTime - order.startTime
      
      -- Cancel orders older than pickup + delivery time limits
      local timeLimit = Config.StockOrdering.pickupTimeLimit + Config.StockOrdering.deliveryTimeLimit
      if timeElapsed > timeLimit then
        print('Auto-cancelling abandoned stock order:', orderId)
        
        -- Refund money
        MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance + ? WHERE id = ?', { order.cost, order.storeId })
        
        -- Update cache
        if StoresCache[order.storeId] then
          StoresCache[order.storeId].account_balance = (StoresCache[order.storeId].account_balance or 0) + order.cost
        end
        
        -- Store vehicle back
        DB.SetVehicleStored(order.vehicleId, true)
        
        -- Notify player if online
        local Player = QBCore.Functions.GetPlayerByCitizenId(order.citizenId)
        if Player then
          TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'Stock order timed out and was cancelled', 'error')
          TriggerClientEvent('sergeis-stores:client:endStockMission', Player.PlayerData.source)
        end
        
        -- Remove order
        activeOrders[orderId] = nil
      end
    end
  end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if resourceName == GetCurrentResourceName() then
    print('Cleaning up stock orders on resource stop...')
    
    -- Reset all vehicles to stored state
    local success, result = pcall(function()
      return MySQL.query.await('UPDATE sergeis_store_vehicles SET stored = 1 WHERE stored = 0', {})
    end)
    
    if success then
      print('Fleet vehicles reset on stop:', result and result.affectedRows or 0, 'vehicles updated')
    else
      print('Failed to reset fleet vehicles on stop:', result)
    end
    
    -- Clear active orders
    activeOrders = {}
    print('Active stock orders cleared')
  end
end)

print('Stock ordering system loaded')
