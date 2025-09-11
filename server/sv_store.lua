local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

QBCore.Functions.CreateCallback('sergeis-stores:server:getStock', function(source, cb, storeId)
  local items = DB.GetStock(storeId)
  local store = StoresCache[storeId]
  local allowed = {}
  
  -- Debug logging
  print('DEBUG getStock: storeId =', storeId)
  print('DEBUG getStock: store =', json.encode(store or {}))
  
  if store and store.location_code then
    local loc = Config.Locations[store.location_code]
    print('DEBUG getStock: location_code =', store.location_code)
    print('DEBUG getStock: location config =', json.encode(loc or {}))
    if loc and loc.allowedItems then 
      allowed = loc.allowedItems
      print('DEBUG getStock: allowedItems =', json.encode(allowed))
    end
  else
    print('DEBUG getStock: No location_code found for store')
  end
  
  cb({ items = items, allowedItems = allowed })
end)

QBCore.Functions.CreateCallback('sergeis-stores:server:getUnownedStock', function(source, cb, locationCode)
  local loc = Config.Locations[locationCode]
  if not loc or not loc.allowedItems then
    cb({ items = {} })
    return
  end
  
  -- Generate stock for unowned stores with reasonable default values
  local items = {}
  for _, item in ipairs(loc.allowedItems) do
    local sharedItem = QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item]
    local label = (sharedItem and sharedItem.label) or item
    local price = (sharedItem and sharedItem.price) or 10 -- Default price
    table.insert(items, {
      item = item,
      label = label,
      price = price,
      stock = 999 -- Unlimited stock for unowned stores
    })
  end
  cb({ items = items })
end)

QBCore.Functions.CreateCallback('sergeis-stores:server:getVehicles', function(source, cb, storeId)
  cb(DB.GetVehicles(storeId))
end)

QBCore.Functions.CreateCallback('sergeis-stores:server:getMyStorePerms', function(source, cb)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then cb({}) return end
  local cid = Player.PlayerData.citizenid
  local map = {}
  -- Employees table
  local rows = DB.GetPermissionsForCitizen(cid)
  for _, r in ipairs(rows) do
    map[tonumber(r.store_id)] = tonumber(r.permission) or 0
  end
  -- Owners implicitly OWNER level
  for id, s in pairs(StoresCache) do
    if s.owner_cid == cid then
      map[tonumber(id)] = StorePermission.OWNER
    end
  end
  cb(map)
end)

RegisterNetEvent('sergeis-stores:server:addEmployee', function(storeId, targetCid, perm)
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
  DB.AddEmployee(storeId, targetCid, perm)
  TriggerClientEvent('QBCore:Notify', src, 'Employee added', 'success')
end)

RegisterNetEvent('sergeis-stores:server:upsertStock', function(storeId, item, label, price, stock)
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
  DB.UpsertStockItem(storeId, item, label, price, stock)
  TriggerClientEvent('QBCore:Notify', src, 'Stock updated', 'success')
end)

RegisterNetEvent('sergeis-stores:server:checkout', function(storeId, cart, payType)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end

  local total = 0
  for _, entry in ipairs(cart or {}) do
    total = total + (tonumber(entry.price) or 0) * (tonumber(entry.qty) or 0)
  end
  payType = payType or Config.DefaultPayment

  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end

  local function removeMoney(type_, amount)
    if type_ == 'cash' then
      return Player.Functions.RemoveMoney('cash', amount)
    else
      return Player.Functions.RemoveMoney('bank', amount)
    end
  end

  if total <= 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Cart is empty', 'error')
    return
  end

  -- Verify stock availability BEFORE taking money
  local current = {}
  for _, row in ipairs(DB.GetStock(storeId)) do current[row.item] = tonumber(row.stock) or 0 end
  for _, entry in ipairs(cart or {}) do
    local want = math.abs(tonumber(entry.qty) or 0)
    if want <= 0 then
      TriggerClientEvent('QBCore:Notify', src, 'Invalid quantity in cart', 'error')
      return
    end
    if (current[entry.item] or 0) < want then
      TriggerClientEvent('QBCore:Notify', src, ('Not enough stock for %s'):format(entry.item), 'error')
      return
    end
  end

  -- Only take money AFTER stock validation passes
  if not removeMoney(payType, total) then
    TriggerClientEvent('QBCore:Notify', src, 'Not enough money', 'error')
    return
  end

  for _, entry in ipairs(cart or {}) do
    DB.AdjustStock(storeId, entry.item, -math.abs(tonumber(entry.qty) or 0))
    Inv.AddItem(src, entry.item, tonumber(entry.qty) or 0)
  end

  -- Add the purchase amount to the store's account balance
  print(('Adding $%d revenue to store %d'):format(total, storeId))
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance + ? WHERE id = ?', { total, storeId })
  
  -- Update the cache
  if StoresCache[storeId] then
    local oldBalance = StoresCache[storeId].account_balance or 0
    StoresCache[storeId].account_balance = oldBalance + total
    print(('Store %d balance updated: $%d -> $%d'):format(storeId, oldBalance, StoresCache[storeId].account_balance))
  end

  DB.RecordTransaction(storeId, cid, total, { type = 'purchase', cart = cart, payType = payType, description = 'Customer purchase' })
  TriggerClientEvent('QBCore:Notify', src, ('Purchased for $%d'):format(total), 'success')
  
  -- Notify store owner if online
  local store = StoresCache[storeId]
  if store and store.owner_cid then
    local ownerPlayer = QBCore.Functions.GetPlayerByCitizenId(store.owner_cid)
    if ownerPlayer then
      TriggerClientEvent('QBCore:Notify', ownerPlayer.PlayerData.source, ('Your store earned $%d from a customer purchase'):format(total), 'success')
    end
  end
  
  TriggerClientEvent('sergeis-stores:client:refresh', src)
end)

RegisterNetEvent('sergeis-stores:server:checkoutUnowned', function(locationCode, cart, payType)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  
  local loc = Config.Locations[locationCode]
  if not loc or not loc.allowedItems then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid location', 'error')
    return
  end

  local total = 0
  for _, entry in ipairs(cart or {}) do
    total = total + (tonumber(entry.price) or 0) * (tonumber(entry.qty) or 0)
  end
  payType = payType or Config.DefaultPayment

  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end

  local function removeMoney(type_, amount)
    if type_ == 'cash' then
      return Player.Functions.RemoveMoney('cash', amount)
    else
      return Player.Functions.RemoveMoney('bank', amount)
    end
  end

  if total <= 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Cart is empty', 'error')
    return
  end

  if not removeMoney(payType, total) then
    TriggerClientEvent('QBCore:Notify', src, 'Not enough money', 'error')
    return
  end

  -- Verify items are allowed for this location
  local allowedSet = {}
  for _, item in ipairs(loc.allowedItems) do allowedSet[item] = true end
  
  for _, entry in ipairs(cart or {}) do
    local want = math.abs(tonumber(entry.qty) or 0)
    if want <= 0 then
      TriggerClientEvent('QBCore:Notify', src, 'Invalid quantity in cart', 'error')
      return
    end
    if not allowedSet[entry.item] then
      TriggerClientEvent('QBCore:Notify', src, ('Item %s not available at this location'):format(entry.item), 'error')
      return
    end
  end

  -- Add items to player inventory (no stock tracking for unowned stores)
  for _, entry in ipairs(cart or {}) do
    Inv.AddItem(src, entry.item, tonumber(entry.qty) or 0)
  end

  TriggerClientEvent('QBCore:Notify', src, ('Purchased for $%d'):format(total), 'success')
end)

-- Restricted stock management: only allowed items per location
RegisterNetEvent('sergeis-stores:server:upsertStockAllowed', function(storeId, item, label, price, stock)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  local level = DB.GetEmployeePermission(storeId, cid)
  if cid == (StoresCache[storeId] and StoresCache[storeId].owner_cid) then
    level = StorePermission.OWNER
  end
  if not HasStorePermission(level, StorePermission.MANAGER) then
    TriggerClientEvent('QBCore:Notify', src, 'No store permission', 'error')
    return
  end

  local store = StoresCache[storeId]
  local locCfg = store and store.location_code and Config.Locations[store.location_code]
  if locCfg and locCfg.allowedItems then
    local ok = false
    for _, allowed in ipairs(locCfg.allowedItems) do
      if allowed == item then ok = true break end
    end
    if not ok then
      TriggerClientEvent('QBCore:Notify', src, 'Item not allowed at this store', 'error')
      return
    end
  end
  if not label or label == '' then
    local sharedItem = QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item]
    if sharedItem and sharedItem.label then label = sharedItem.label end
    if not label or label == '' then label = item end
  end
  DB.UpsertStockItem(storeId, item, label, price, stock)
  TriggerClientEvent('QBCore:Notify', src, 'Stock updated', 'success')
end)


