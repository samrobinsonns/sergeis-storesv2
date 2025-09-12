DB = DB or {}

local function decodeOr(tableOrJson)
  if type(tableOrJson) == 'string' then
    local ok, res = pcall(function()
      return json.decode(tableOrJson)
    end)
    if ok then return res end
  end
  return tableOrJson or {}
end

function DB.GetStores()
  local rows = MySQL.query.await('SELECT id, name, owner_cid, account_balance, points, location_code, capacity, blip_sprite, blip_image_url FROM sergeis_stores', {})
  rows = rows or {}
  for _, row in ipairs(rows) do
    row.points = decodeOr(row.points)
  end
  return rows
end

function DB.CreateStore(name, ownerCitizenId, points, locationCode)
  local insertId = MySQL.insert.await('INSERT INTO sergeis_stores (name, owner_cid, account_balance, points, location_code) VALUES (?, ?, ?, ?, ?)', {
    name,
    ownerCitizenId,
    0,
    json.encode(points or {}),
    locationCode
  })
  return insertId
end

function DB.UpdateStorePoints(storeId, points)
  MySQL.update.await('UPDATE sergeis_stores SET points = ? WHERE id = ?', { json.encode(points or {}), storeId })
end

function DB.SetStoreCapacity(storeId, capacity)
  MySQL.update.await('UPDATE sergeis_stores SET capacity = ? WHERE id = ?', { capacity, storeId })
end

function DB.DeleteStore(storeId)
  MySQL.query.await('DELETE FROM sergeis_stores WHERE id = ?', { storeId })
end

function DB.SetStoreOwner(storeId, citizenId)
  MySQL.update.await('UPDATE sergeis_stores SET owner_cid = ? WHERE id = ?', { citizenId, storeId })
end

function DB.UpdateStoreBlip(storeId, sprite, imageUrl)
  MySQL.update.await('UPDATE sergeis_stores SET blip_sprite = ?, blip_image_url = ? WHERE id = ?', { sprite, imageUrl, storeId })
end
function DB.AddPurchasedUpgrade(storeId, tier)
  MySQL.insert.await('INSERT IGNORE INTO sergeis_store_upgrades (store_id, tier) VALUES (?, ?)', { storeId, tier })
end

function DB.GetPurchasedUpgrades(storeId)
  local rows = MySQL.query.await('SELECT tier FROM sergeis_store_upgrades WHERE store_id = ?', { storeId })
  local set = {}
  for _, r in ipairs(rows or {}) do set[tonumber(r.tier)] = true end
  return set
end

function DB.AddEmployee(storeId, citizenId, permission)
  MySQL.insert.await('INSERT INTO sergeis_store_employees (store_id, citizenid, permission) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE permission = VALUES(permission)', {
    storeId, citizenId, permission
  })
end

function DB.GetEmployeePermission(storeId, citizenId)
  local row = MySQL.single.await('SELECT permission FROM sergeis_store_employees WHERE store_id = ? AND citizenid = ?', { storeId, citizenId })
  if row and row.permission then
    return tonumber(row.permission) or 0
  end
  return 0
end

function DB.GetStock(storeId)
  local rows = MySQL.query.await('SELECT item, label, price, stock FROM sergeis_store_items WHERE store_id = ?', { storeId })
  return rows or {}
end

function DB.UpsertStockItem(storeId, item, label, price, stock)
  -- Get current stock before update
  local currentStock = MySQL.single.await('SELECT stock FROM sergeis_store_items WHERE store_id = ? AND item = ?', { storeId, item })
  local oldStock = currentStock and currentStock.stock or 0
  local newStock = tonumber(stock) or 0
  
  MySQL.insert.await('INSERT INTO sergeis_store_items (store_id, item, label, price, stock) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), price = VALUES(price), stock = VALUES(stock)', {
    storeId, item, label, price, stock
  })
  
  -- Check if stock went to 0 and notify
  if oldStock > 0 and newStock == 0 then
    TriggerEvent('sergeis-stores:server:stockEmpty', storeId, item, label)
  end
end

function DB.AdjustStock(storeId, item, delta)
  -- Get current stock before update
  local currentStock = MySQL.single.await('SELECT stock FROM sergeis_store_items WHERE store_id = ? AND item = ?', { storeId, item })
  local oldStock = currentStock and currentStock.stock or 0
  
  -- Update stock
  MySQL.update.await('UPDATE sergeis_store_items SET stock = GREATEST(0, stock + ?) WHERE store_id = ? AND item = ?', { delta, storeId, item })
  
  -- Get new stock after update
  local newStockResult = MySQL.single.await('SELECT stock, label FROM sergeis_store_items WHERE store_id = ? AND item = ?', { storeId, item })
  local newStock = newStockResult and newStockResult.stock or 0
  local itemLabel = newStockResult and newStockResult.label or item
  
  -- Check if stock went to 0 and notify
  if oldStock > 0 and newStock == 0 then
    TriggerEvent('sergeis-stores:server:stockEmpty', storeId, item, itemLabel)
  end
end

function DB.RecordTransaction(storeId, citizenId, amount, payload)
  MySQL.insert.await('INSERT INTO sergeis_store_transactions (store_id, citizenid, amount, payload) VALUES (?, ?, ?, ?)', {
    storeId, citizenId, amount, json.encode(payload or {})
  })
end

function DB.IncrementEmployeeOrders(storeId, citizenId)
  MySQL.insert.await('INSERT INTO sergeis_store_employee_stats (store_id, citizenid, orders_completed) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE orders_completed = orders_completed + 1', {
    storeId, citizenId
  })
end

function DB.GetEmployeeStats(storeId)
  local rows = MySQL.query.await('SELECT citizenid, orders_completed FROM sergeis_store_employee_stats WHERE store_id = ?', { storeId })
  return rows or {}
end

function DB.ResetEmployeeStats(storeId)
  MySQL.query.await('DELETE FROM sergeis_store_employee_stats WHERE store_id = ?', { storeId })
end

function DB.ResetEmployeeStat(storeId, citizenId)
  MySQL.query.await('DELETE FROM sergeis_store_employee_stats WHERE store_id = ? AND citizenid = ?', { storeId, citizenId })
end

function DB.GetVehicles(storeId)
  local rows = MySQL.query.await('SELECT id, model, plate, stored FROM sergeis_store_vehicles WHERE store_id = ?', { storeId })
  return rows or {}
end

function DB.AddVehicle(storeId, model, plate)
  local id = MySQL.insert.await('INSERT INTO sergeis_store_vehicles (store_id, model, plate, stored) VALUES (?, ?, ?, 1)', { storeId, model, plate })
  return id
end

function DB.GetPermissionsForCitizen(citizenId)
  local rows = MySQL.query.await('SELECT store_id, permission FROM sergeis_store_employees WHERE citizenid = ?', { citizenId })
  return rows or {}
end

function DB.SetVehicleStored(vehId, stored)
  MySQL.update.await('UPDATE sergeis_store_vehicles SET stored = ? WHERE id = ?', { stored and 1 or 0, vehId })
end

function DB.GetEmployees(storeId)
  local rows = MySQL.query.await('SELECT citizenid, permission FROM sergeis_store_employees WHERE store_id = ?', { storeId })
  return rows or {}
end


