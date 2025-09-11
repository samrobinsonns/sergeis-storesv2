local QBCore = exports['qb-core']:GetCoreObject()

-- Track spawned fleet vehicles
local spawnedFleetVehicles = {}

-- Spawn a fleet vehicle
RegisterNetEvent('sergeis-stores:client:spawnVehicle', function(vehicleData)
  local playerPed = PlayerPedId()
  local coords = GetEntityCoords(playerPed)
  local heading = GetEntityHeading(playerPed)
  
  -- Find a clear spawn location nearby
  local spawnCoords = coords + vector3(5.0, 0.0, 0.0) -- 5 units in front
  
  -- Load the vehicle model
  local modelHash = GetHashKey(vehicleData.model)
  if not IsValidModel(modelHash) or not IsModelAVehicle(modelHash) then
    QBCore.Functions.Notify('Invalid vehicle model', 'error')
    return
  end
  
  RequestModel(modelHash)
  while not HasModelLoaded(modelHash) do
    Wait(100)
  end
  
  -- Create the vehicle
  local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)
  if not DoesEntityExist(vehicle) then
    QBCore.Functions.Notify('Failed to spawn vehicle', 'error')
    return
  end
  
  -- Set vehicle properties
  SetVehicleNumberPlateText(vehicle, vehicleData.plate)
  SetEntityAsMissionEntity(vehicle, true, true)
  
  -- Add to tracking
  spawnedFleetVehicles[vehicleData.id] = {
    entity = vehicle,
    plate = vehicleData.plate,
    storeId = vehicleData.storeId
  }
  
  -- Place player in vehicle
  TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
  
  QBCore.Functions.Notify('Fleet vehicle spawned: ' .. vehicleData.plate, 'success')
  
  -- Set model as no longer needed
  SetModelAsNoLongerNeeded(modelHash)
end)

-- Store a fleet vehicle
RegisterNetEvent('sergeis-stores:client:storeFleetVehicle', function()
  local playerPed = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(playerPed, false)
  
  if vehicle == 0 then
    QBCore.Functions.Notify('You must be in a vehicle to store it', 'error')
    return
  end
  
  local plate = GetVehicleNumberPlateText(vehicle)
  plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") -- Trim whitespace
  
  -- Find the vehicle in our tracking
  local vehicleId = nil
  for id, data in pairs(spawnedFleetVehicles) do
    if data.plate == plate and data.entity == vehicle then
      vehicleId = id
      break
    end
  end
  
  if not vehicleId then
    QBCore.Functions.Notify('This is not a fleet vehicle', 'error')
    return
  end
  
  -- Remove from tracking and delete entity
  spawnedFleetVehicles[vehicleId] = nil
  DeleteEntity(vehicle)
  
  -- Notify server
  TriggerServerEvent('sergeis-stores:server:storeVehicle', vehicleId)
end)

-- Command to store fleet vehicle
RegisterCommand('storefleet', function()
  TriggerEvent('sergeis-stores:client:storeFleetVehicle')
end, false)

-- Clean up when resource stops
AddEventHandler('onResourceStop', function(resourceName)
  if resourceName == GetCurrentResourceName() then
    for id, data in pairs(spawnedFleetVehicles) do
      if DoesEntityExist(data.entity) then
        DeleteEntity(data.entity)
      end
    end
    spawnedFleetVehicles = {}
  end
end)

-- Export function to check if player is in a fleet vehicle
function IsPlayerInFleetVehicle()
  local playerPed = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(playerPed, false)
  
  if vehicle == 0 then return false, nil end
  
  local plate = GetVehicleNumberPlateText(vehicle)
  plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") -- Trim whitespace
  
  for id, data in pairs(spawnedFleetVehicles) do
    if data.plate == plate and data.entity == vehicle then
      return true, data.storeId
    end
  end
  
  return false, nil
end

exports('IsPlayerInFleetVehicle', IsPlayerInFleetVehicle)
