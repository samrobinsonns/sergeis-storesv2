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
  openUI('manage', { storeId = storeId, allowedTabs = { 'shop', 'stock', 'manage', 'fleet' } })
end)

RegisterNetEvent('sergeis-stores:client:openStock', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStock', function(payload)
    openUI('stock', { storeId = storeId, items = payload.items or {}, allowedItems = payload.allowedItems or {}, allowedTabs = { 'shop', 'stock', 'manage', 'fleet' } })
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
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(map)
      local level = (map or {})[storeId] or 0
      local allowedTabs = { 'shop' }
      if level >= StorePermission.MANAGER then
        allowedTabs = { 'shop', 'stock', 'manage', 'fleet' }
      end
      openUI('shop', { storeId = storeId, items = payload.items or {}, allowedTabs = allowedTabs })
    end)
  end, storeId)
end)

RegisterNetEvent('sergeis-stores:client:openFleet', function(storeId)
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getVehicles', function(vehicles)
    openUI('fleet', { storeId = storeId, vehicles = vehicles, allowedTabs = { 'shop', 'stock', 'manage', 'fleet' } })
  end, storeId)
end)

-- Minimal purchase NUI callback
RegisterNUICallback('checkout', function(data, cb)
  local storeId = data.storeId
  local cart = data.cart or {}
  local payType = data.payType or Config.DefaultPayment
  TriggerServerEvent('sergeis-stores:server:checkout', storeId, cart, payType)
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


