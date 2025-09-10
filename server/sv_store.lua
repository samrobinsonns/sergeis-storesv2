local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

QBCore.Functions.CreateCallback('sergeis-stores:server:getStock', function(source, cb, storeId)
  local items = DB.GetStock(storeId)
  local store = StoresCache[storeId]
  local allowed = {}
  if store and store.location_code then
    local loc = Config.Locations[store.location_code]
    if loc and loc.allowedItems then allowed = loc.allowedItems end
  end
  cb({ items = items, allowedItems = allowed })
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

  if not removeMoney(payType, total) then
    TriggerClientEvent('QBCore:Notify', src, 'Not enough money', 'error')
    return
  end

  -- Verify stock availability before adjusting
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

  for _, entry in ipairs(cart or {}) do
    DB.AdjustStock(storeId, entry.item, -math.abs(tonumber(entry.qty) or 0))
    Inv.AddItem(src, entry.item, tonumber(entry.qty) or 0)
  end

  DB.RecordTransaction(storeId, cid, total, { cart = cart, payType = payType })
  TriggerClientEvent('QBCore:Notify', src, ('Purchased for $%d'):format(total), 'success')
  TriggerClientEvent('sergeis-stores:client:refresh', src)
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


