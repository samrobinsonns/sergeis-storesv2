local QBCore = exports['qb-core']:GetCoreObject()

-- Mission state
local currentMission = nil
local missionVehicle = nil
local pickupBlip = nil
local deliveryBlip = nil

-- Create blip function
local function createBlip(coords, sprite, color, label)
  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipSprite(blip, sprite)
  SetBlipColour(blip, color)
  SetBlipAsShortRange(blip, false)
  SetBlipScale(blip, 0.8)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(label)
  EndTextCommandSetBlipName(blip)
  return blip
end

-- Start stock mission
RegisterNetEvent('sergeis-stores:client:startStockMission', function(missionData)
  print('Client startStockMission event triggered')
  print('Mission data:', json.encode(missionData))
  currentMission = missionData
  
  -- Spawn the vehicle
  local vehicleModel = GetHashKey(missionData.vehicle.model)
  
  RequestModel(vehicleModel)
  while not HasModelLoaded(vehicleModel) do
    Wait(100)
  end
  
  -- Use configured spawn location
  local spawnCoords = missionData.spawnLocation
  local heading = spawnCoords.w or spawnCoords.heading or 0.0
  
  missionVehicle = CreateVehicle(vehicleModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)
  
  if DoesEntityExist(missionVehicle) then
    -- Set vehicle properties
    SetVehicleNumberPlateText(missionVehicle, missionData.vehicle.plate)
    SetEntityAsMissionEntity(missionVehicle, true, true)
    
    -- Wait a moment for vehicle to fully initialize
    Wait(500)
    
    -- Give keys using multiple methods
    local keysGiven = false
    print('Attempting to give keys for vehicle plate:', missionData.vehicle.plate)
    print('Vehicle entity ID:', missionVehicle)
    
    -- Method 1: Try qb-vehiclekeys with different approaches
    local success, error = pcall(function()
      if GetResourceState('qb-vehiclekeys') == 'started' then
        -- Try the standard method
        exports['qb-vehiclekeys']:GiveKeys(missionData.vehicle.plate)
        print('Keys given via qb-vehiclekeys:GiveKeys for plate:', missionData.vehicle.plate)
        keysGiven = true
      else
        error('qb-vehiclekeys not started')
      end
    end)
    
    if not success then
      print('qb-vehiclekeys:GiveKeys failed:', error)
      
      -- Try alternative qb-vehiclekeys method
      local success1b, error1b = pcall(function()
        if GetResourceState('qb-vehiclekeys') == 'started' then
          exports['qb-vehiclekeys']:SetVehicleKey(missionData.vehicle.plate, true)
          print('Keys given via qb-vehiclekeys:SetVehicleKey for plate:', missionData.vehicle.plate)
          keysGiven = true
        end
      end)
      
      if not success1b then
        print('qb-vehiclekeys:SetVehicleKey failed:', error1b)
      end
    end
    
    -- Method 2: Server event methods
    if not keysGiven then
      -- Try different server events
      local serverMethods = {
        'qb-vehiclekeys:server:GiveVehicleKeys',
        'vehiclekeys:server:GiveVehicleKeys',
        'qb-vehiclekeys:server:SetVehicleOwner'
      }
      
      for _, event in ipairs(serverMethods) do
        local success_srv, error_srv = pcall(function()
          TriggerServerEvent(event, missionData.vehicle.plate)
          print('Keys requested via server event:', event, 'for plate:', missionData.vehicle.plate)
          keysGiven = true
        end)
        
        if success_srv then
          break
        else
          print('Server event', event, 'failed:', error_srv)
        end
      end
    end
    
    -- Method 3: Direct vehicle natives (most reliable)
    print('Using native methods to ensure vehicle access')
    SetVehicleHasBeenOwnedByPlayer(missionVehicle, true)
    SetVehicleNeedsToBeHotwired(missionVehicle, false)
    SetVehicleAlarm(missionVehicle, false)
    SetVehicleDoorsLocked(missionVehicle, 1) -- Unlocked
    SetVehicleEngineOn(missionVehicle, false, true, false)
    
    -- Give player explicit control
    local playerPed = PlayerPedId()
    SetPedCanBeKnockedOffVehicle(playerPed, 1)
    
    print('Vehicle access configured via natives for mission vehicle')
    
    -- Wait a bit more for key systems to process
    Wait(1000)
    
    -- Teleport player to vehicle if they're far away
    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(missionVehicle)
    local distance = #(playerCoords - vehicleCoords)
    
    if distance > 10.0 then
      -- Teleport player near the vehicle
      SetEntityCoords(playerPed, vehicleCoords.x + 2.0, vehicleCoords.y, vehicleCoords.z, false, false, false, true)
      QBCore.Functions.Notify('Vehicle spawned at fleet location', 'info')
      Wait(1000) -- Wait a moment before putting in vehicle
    end
    
    -- Place player in vehicle
    TaskWarpPedIntoVehicle(playerPed, missionVehicle, -1)
    
    -- Create pickup blip
    pickupBlip = createBlip(missionData.pickupLocation, 478, 2, 'Stock Pickup: ' .. missionData.pickupLabel)
    
    QBCore.Functions.Notify('Mission started! Drive to ' .. missionData.pickupLabel .. ' to collect stock', 'success')
    
    -- Start proximity checking for pickup
    CreateThread(function()
      while currentMission and currentMission.orderId == missionData.orderId do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local pickupCoords = vector3(missionData.pickupLocation.x, missionData.pickupLocation.y, missionData.pickupLocation.z)
        local distance = #(playerCoords - pickupCoords)
        
        if distance < 5.0 and currentMission.status ~= 'delivery' then
          -- Show pickup prompt
          if IsControlJustReleased(0, 38) then -- E key
            TriggerServerEvent('sergeis-stores:server:completePickup', missionData.orderId)
          end
          
          -- Draw text
          DrawText3D(pickupCoords.x, pickupCoords.y, pickupCoords.z + 1.0, "[E] Collect Stock")
        end
        
        Wait(100)
      end
    end)
  else
    QBCore.Functions.Notify('Failed to spawn vehicle', 'error')
    currentMission = nil
  end
  
  SetModelAsNoLongerNeeded(vehicleModel)
end)

-- Update mission status
RegisterNetEvent('sergeis-stores:client:updateMissionStatus', function(status, deliveryLocation)
  if not currentMission then return end
  
  currentMission.status = status
  
  if status == 'delivery' then
    -- Remove pickup blip
    if pickupBlip then
      RemoveBlip(pickupBlip)
      pickupBlip = nil
    end
    
    -- Create delivery blip
    deliveryBlip = createBlip(deliveryLocation, 478, 3, 'Store Delivery')
    
    QBCore.Functions.Notify('Stock loaded! Return to store to complete delivery', 'success')
    
    -- Start proximity checking for delivery
    CreateThread(function()
      while currentMission and currentMission.status == 'delivery' do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local deliveryCoords = vector3(deliveryLocation.x, deliveryLocation.y, deliveryLocation.z)
        local distance = #(playerCoords - deliveryCoords)
        
        if distance < 5.0 then
          -- Show delivery prompt
          if IsControlJustReleased(0, 38) then -- E key
            TriggerServerEvent('sergeis-stores:server:completeDelivery', currentMission.orderId)
          end
          
          -- Draw text
          DrawText3D(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z + 1.0, "[E] Deliver Stock")
        end
        
        Wait(100)
      end
    end)
  end
end)

-- End mission
RegisterNetEvent('sergeis-stores:client:endStockMission', function()
  -- Remove blips
  if pickupBlip then
    RemoveBlip(pickupBlip)
    pickupBlip = nil
  end
  
  if deliveryBlip then
    RemoveBlip(deliveryBlip)
    deliveryBlip = nil
  end
  
  -- Store vehicle (let server handle the database)
  if missionVehicle and DoesEntityExist(missionVehicle) then
    DeleteEntity(missionVehicle)
    missionVehicle = nil
  end
  
  currentMission = nil
  QBCore.Functions.Notify('Mission completed', 'success')
end)

-- Draw 3D text function
function DrawText3D(x, y, z, text)
  local onScreen, _x, _y = World3dToScreen2d(x, y, z)
  local px, py, pz = table.unpack(GetGameplayCamCoords())
  
  SetTextScale(0.35, 0.35)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(255, 255, 255, 215)
  SetTextEntry("STRING")
  SetTextCentre(1)
  AddTextComponentString(text)
  DrawText(_x, _y)
  
  local factor = (string.len(text)) / 370
  DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

-- Cancel current mission command
RegisterCommand('cancelorder', function()
  if currentMission then
    TriggerServerEvent('sergeis-stores:server:cancelStockOrder', currentMission.orderId)
  else
    QBCore.Functions.Notify('No active stock order', 'error')
  end
end, false)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if resourceName == GetCurrentResourceName() then
    if pickupBlip then RemoveBlip(pickupBlip) end
    if deliveryBlip then RemoveBlip(deliveryBlip) end
    if missionVehicle and DoesEntityExist(missionVehicle) then
      DeleteEntity(missionVehicle)
    end
  end
end)

print('Stock mission system loaded')
