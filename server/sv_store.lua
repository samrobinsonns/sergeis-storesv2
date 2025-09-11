local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

-- Normalize Config.Locations[code].allowedItems into
-- 1) a flat array of item codes, and
-- 2) a map of per-item price overrides, and
-- 3) a map of per-item label overrides
-- Supported config shapes:
-- - { 'water', 'bread' }
-- - { { item = 'water', price = 5, label = 'Water' }, { item = 'bread', price = 7 } }
-- - { water = 5, bread = 7 }
-- - { water = { price = 5, label = 'Water' }, bread = { price = 7 } }
local function normalizeAllowedItems(input)
  local items, prices, labels = {}, {}, {}
  if type(input) ~= 'table' then return items, prices, labels end

  local hasStringKeys = false
  for k, _ in pairs(input) do
    if type(k) ~= 'number' then hasStringKeys = true break end
  end

  if hasStringKeys then
    for item, v in pairs(input) do
      if type(item) == 'string' then
        items[#items + 1] = item
        if type(v) == 'number' then
          prices[item] = v
        elseif type(v) == 'table' then
          if v.price then prices[item] = tonumber(v.price) end
          if v.label then labels[item] = v.label end
        end
      end
    end
  else
    for _, v in ipairs(input) do
      if type(v) == 'string' then
        items[#items + 1] = v
      elseif type(v) == 'table' then
        local code = v.item or v[1]
        if code then
          items[#items + 1] = code
          if v.price then prices[code] = tonumber(v.price) end
          if v.label then labels[code] = v.label end
        end
      end
    end
  end

  return items, prices, labels
end

QBCore.Functions.CreateCallback('sergeis-stores:server:getStock', function(source, cb, storeId)
  local items = DB.GetStock(storeId)
  local store = StoresCache[storeId]
  local allowed = {}
  local usedCapacity = 0
  for _, row in ipairs(items) do usedCapacity = usedCapacity + (tonumber(row.stock) or 0) end
  local maxCapacity
  
  -- Debug logging
  print('DEBUG getStock: storeId =', storeId)
  print('DEBUG getStock: store =', json.encode(store or {}))
  
  if store and store.location_code then
    local loc = Config.Locations[store.location_code]
    print('DEBUG getStock: location_code =', store.location_code)
    print('DEBUG getStock: location config =', json.encode(loc or {}))
    if loc and loc.allowedItems then 
      local allowedList = normalizeAllowedItems(loc.allowedItems)
      allowed = allowedList
      print('DEBUG getStock: allowedItems =', json.encode(allowed))
    end
    if loc then
      local baseMax = tonumber(loc.maxCapacity) or 0
      local upgraded = tonumber(store.capacity) or 0
      maxCapacity = baseMax + upgraded
    end
  else
    print('DEBUG getStock: No location_code found for store')
  end
  
  cb({ items = items, allowedItems = allowed, usedCapacity = usedCapacity, maxCapacity = maxCapacity })
end)

-- Purchase capacity upgrade
RegisterNetEvent('sergeis-stores:server:purchaseCapacityUpgrade', function(storeId, tier)
  local src = source
  local cid = getCitizenId(src)
  if not cid then return end
  tier = tonumber(tier)
  if not tier or not Config.CapacityUpgrades or not Config.CapacityUpgrades[tier] then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid upgrade tier', 'error')
    return
  end
  local store = StoresCache[storeId]
  if not store then
    TriggerClientEvent('QBCore:Notify', src, 'Store not found', 'error')
    return
  end
  -- Permission: Managers and Owners
  local level = DB.GetEmployeePermission(storeId, cid)
  if cid == store.owner_cid then level = StorePermission.OWNER end
  if not HasStorePermission(level, StorePermission.MANAGER) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
    return
  end
  local upgrade = Config.CapacityUpgrades[tier]
  local price = tonumber(upgrade.price) or 0
  local increase = tonumber(upgrade.increase) or 0
  if price <= 0 or increase <= 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid upgrade configuration', 'error')
    return
  end
  -- Check store funds
  if (store.account_balance or 0) < price then
    TriggerClientEvent('QBCore:Notify', src, 'Insufficient store funds', 'error')
    return
  end
  -- Deduct and persist
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance - ?, capacity = COALESCE(capacity, 0) + ? WHERE id = ?', { price, increase, storeId })
  -- Update cache
  store.account_balance = (store.account_balance or 0) - price
  store.capacity = (store.capacity or 0) + increase
  -- Record transaction
  DB.RecordTransaction(storeId, cid, -price, { type = 'capacity_upgrade', tier = tier, increase = increase, description = 'Capacity upgrade' })
  TriggerClientEvent('QBCore:Notify', src, ('Capacity increased by %d'):format(increase), 'success')
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

QBCore.Functions.CreateCallback('sergeis-stores:server:getUnownedStock', function(source, cb, locationCode)
  local loc = Config.Locations[locationCode]
  if not loc or not loc.allowedItems then
    cb({ items = {} })
    return
  end
  
  -- Generate stock for unowned stores with reasonable default values
  local items = {}
  local allowedList, priceOverrides, labelOverrides = normalizeAllowedItems(loc.allowedItems)
  for _, item in ipairs(allowedList) do
    local sharedItem = QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item]
    local label = labelOverrides[item] or (sharedItem and sharedItem.label) or item
    local price = priceOverrides[item] or (sharedItem and sharedItem.price) or 10 -- Default price
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
  -- Enforce store capacity if configured
  local storeRow = StoresCache[storeId]
  local locCfg = storeRow and storeRow.location_code and Config.Locations[storeRow.location_code]
  local baseMax = locCfg and tonumber(locCfg.maxCapacity) or 0
  local upgraded = storeRow and tonumber(storeRow.capacity) or 0
  local maxCapacity = (baseMax + upgraded) > 0 and (baseMax + upgraded) or nil
  if maxCapacity then
    local currentTotal = 0
    for _, row in ipairs(DB.GetStock(storeId)) do
      currentTotal = currentTotal + (tonumber(row.stock) or 0)
    end
    local newStock = math.max(0, tonumber(stock) or 0)
    -- Find existing stock for this item to calculate delta impact
    local existing = 0
    for _, row in ipairs(DB.GetStock(storeId)) do
      if row.item == item then
        existing = tonumber(row.stock) or 0
        break
      end
    end
    local projected = currentTotal - existing + newStock
    if projected > maxCapacity then
      TriggerClientEvent('QBCore:Notify', src, ('Store capacity exceeded (%d/%d)'):format(projected, maxCapacity), 'error')
      return
    end
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
  local allowedList = normalizeAllowedItems(loc.allowedItems)
  for _, item in ipairs(allowedList) do allowedSet[item] = true end
  
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
    local allowedList = normalizeAllowedItems(locCfg.allowedItems)
    for _, allowed in ipairs(allowedList) do
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
  -- Enforce store capacity if configured
  local storeRow = StoresCache[storeId]
  local locCfg = storeRow and storeRow.location_code and Config.Locations[storeRow.location_code]
  local baseMax = locCfg and tonumber(locCfg.maxCapacity) or 0
  local upgraded = storeRow and tonumber(storeRow.capacity) or 0
  local maxCapacity = (baseMax + upgraded) > 0 and (baseMax + upgraded) or nil
  if maxCapacity then
    local currentTotal = 0
    for _, row in ipairs(DB.GetStock(storeId)) do
      currentTotal = currentTotal + (tonumber(row.stock) or 0)
    end
    local newStock = math.max(0, tonumber(stock) or 0)
    -- Find existing stock for this item to calculate delta impact
    local existing = 0
    for _, row in ipairs(DB.GetStock(storeId)) do
      if row.item == item then
        existing = tonumber(row.stock) or 0
        break
      end
    end
    local projected = currentTotal - existing + newStock
    if projected > maxCapacity then
      TriggerClientEvent('QBCore:Notify', src, ('Store capacity exceeded (%d/%d)'):format(projected, maxCapacity), 'error')
      return
    end
  end
  DB.UpsertStockItem(storeId, item, label, price, stock)
  TriggerClientEvent('QBCore:Notify', src, 'Stock updated', 'success')
end)


