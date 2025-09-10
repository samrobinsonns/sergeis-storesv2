local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

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


