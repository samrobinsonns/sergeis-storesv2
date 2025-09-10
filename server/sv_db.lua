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
  local rows = MySQL.query.await('SELECT id, name, owner_cid, account_balance, points, location_code FROM sergeis_stores', {})
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
  MySQL.insert.await('INSERT INTO sergeis_store_items (store_id, item, label, price, stock) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), price = VALUES(price), stock = VALUES(stock)', {
    storeId, item, label, price, stock
  })
end

function DB.AdjustStock(storeId, item, delta)
  MySQL.update.await('UPDATE sergeis_store_items SET stock = GREATEST(0, stock + ?) WHERE store_id = ? AND item = ?', { delta, storeId, item })
end

function DB.RecordTransaction(storeId, citizenId, amount, payload)
  MySQL.insert.await('INSERT INTO sergeis_store_transactions (store_id, citizenid, amount, payload) VALUES (?, ?, ?, ?)', {
    storeId, citizenId, amount, json.encode(payload or {})
  })
end

function DB.GetVehicles(storeId)
  local rows = MySQL.query.await('SELECT id, model, plate, stored FROM sergeis_store_vehicles WHERE store_id = ?', { storeId })
  return rows or {}
end

function DB.AddVehicle(storeId, model, plate)
  local id = MySQL.insert.await('INSERT INTO sergeis_store_vehicles (store_id, model, plate, stored) VALUES (?, ?, ?, 1)', { storeId, model, plate })
  return id
end

function DB.SetVehicleStored(vehId, stored)
  MySQL.update.await('UPDATE sergeis_store_vehicles SET stored = ? WHERE id = ?', { stored and 1 or 0, vehId })
end


