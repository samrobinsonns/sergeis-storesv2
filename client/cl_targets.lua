-- Use global StoreTarget from target_wrapper.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Helper function to count table entries
local function tableCount(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

-- Register the broadcast event immediately
RegisterNetEvent('sergeis-stores:client:storeLocationsUpdate')

local zones = {}
local stores = {}
local purchasedLocations = {}
local myPermissions = {}
local isRefreshing = false
local lastRefreshTime = 0
local blips = {}

-- Define helper functions early
local function hasPerm(storeId, required)
  local level = myPermissions[storeId] or 0
  return level >= required
end

local function buildPublicTargets()

  -- Rebuild map blips first
  local function removeAllBlips()
    for id, blip in pairs(blips) do
      if DoesBlipExist(blip) then RemoveBlip(blip) end
      blips[id] = nil
    end
  end
  removeAllBlips()

  -- Remove only public zones (shopping, purchase, order)
  for id, zoneId in pairs(zones) do
    if string.match(id, '_shop$') or string.match(id, '_purchase$') or string.match(id, '_order$') then
      StoreTarget.RemoveZone(zoneId)
      zones[id] = nil
    end
  end

  -- Build shopping targets for all stores (public access)
  for _, s in ipairs(stores) do
    -- Use config coordinates if this store has a location_code, otherwise use database coordinates
    local points = s.points or {}
    if s.location_code and Config.Locations[s.location_code] and Config.Locations[s.location_code].points then
      points = Config.Locations[s.location_code].points
    end

    -- Shopping targets - always available to everyone
    local orderPoint = points.shop or points.order
    if orderPoint then
      -- Create a blip at the order/shop point with the store's name
      local bc = orderPoint
      if type(orderPoint) == 'vector4' or orderPoint.w then bc = { x = orderPoint.x, y = orderPoint.y, z = orderPoint.z } end
      local blip = AddBlipForCoord(bc.x + 0.0, bc.y + 0.0, bc.z + 0.0)
      local sprite = (s.blip_sprite and tonumber(s.blip_sprite)) or 52
      SetBlipSprite(blip, sprite)
      SetBlipScale(blip, 0.8)
      SetBlipColour(blip, 1)
      SetBlipAsShortRange(blip, true)
      BeginTextCommandSetBlipName('STRING')
      local label = s.name
      if (not label or label == '') and s.location_code and Config.Locations[s.location_code] then
        label = Config.Locations[s.location_code].label or s.location_code
      end
      AddTextComponentString(label or 'Store')
      EndTextCommandSetBlipName(blip)
      blips[s.id] = blip

      local pid = ('store_%d_shop'):format(s.id)
      local shop = orderPoint
      local coords = shop
      if type(shop) == 'vector4' or shop.w then coords = { x = shop.x, y = shop.y, z = shop.z, heading = shop.w } end
      local shopLength = (type(shop) == 'table' and shop.length) or Config.Interact.Shop.length
      local shopWidth = (type(shop) == 'table' and shop.width) or Config.Interact.Shop.width
      local shopHeight = (type(shop) == 'table' and shop.height) or Config.Interact.Shop.height
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, shopLength, shopWidth, {
        heading = coords.heading,
        height = shopHeight,
        distance = Config.Interact.Shop.distance,
        targets = {
          {
            name = pid,
            icon = Config.Interact.Shop.icon,
            label = Config.Interact.Shop.label,
            onSelect = function()
              TriggerEvent('sergeis-stores:client:openShop', s.id)
            end
          }
        }
      })
    end
  end
  
      -- Add purchase/order points from config for not-yet-owned locations (public access)
  if not (Config and Config.Locations) then
    return
  end

  for code, loc in pairs(Config.Locations) do
    if not purchasedLocations[code] then
      if loc.points and loc.points.purchase then
        local pid = ('loc_%s_purchase'):format(code)
        local p = loc.points.purchase
        local coords = p
        if type(p) == 'vector4' or p.w then coords = { x = p.x, y = p.y, z = p.z, heading = p.w } end
        local purchaseLength = (type(p) == 'table' and p.length) or 1.2
        local purchaseWidth = (type(p) == 'table' and p.width) or 1.2
        local purchaseHeight = (type(p) == 'table' and p.height) or 1.2
        zones[pid] = StoreTarget.AddBoxZone(pid, coords, purchaseLength, purchaseWidth, {
          heading = coords.heading,
          height = purchaseHeight,
          distance = 2.0,
          targets = {
            {
              name = pid,
              icon = 'fas fa-store',
              label = ('Purchase Store ($%s)'):format(loc.price or 0),
              onSelect = function()
                TriggerEvent('sergeis-stores:client:openPurchase', code)
              end
            }
          }
        })
      end

      -- Use order point for shopping targets (this becomes shop point when purchased)
      local orderPoint = loc.points and (loc.points.order or loc.points.shop)
      if orderPoint then
        local pid = ('loc_%s_order'):format(code)
        local coords = orderPoint
        if type(orderPoint) == 'vector4' or orderPoint.w then coords = { x = orderPoint.x, y = orderPoint.y, z = orderPoint.z, heading = orderPoint.w } end
        local orderLength = (type(orderPoint) == 'table' and orderPoint.length) or 1.6
        local orderWidth = (type(orderPoint) == 'table' and orderPoint.width) or 1.6
        local orderHeight = (type(orderPoint) == 'table' and orderPoint.height) or 1.2

        -- Create map blip for unowned store at order point using config label
        local blipId = ('loc_%s'):format(code)
        local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
        local sprite = 52 -- config/unowned default
        SetBlipSprite(blip, sprite)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 1)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.label or code)
        EndTextCommandSetBlipName(blip)
        blips[blipId] = blip

        zones[pid] = StoreTarget.AddBoxZone(pid, coords, orderLength, orderWidth, {
          heading = coords.heading,
          height = orderHeight,
          distance = 2.0,
          targets = {
            {
              name = pid,
              icon = 'fas fa-shopping-basket',
              label = 'Order Items',
              onSelect = function()
                -- Open shop for unowned location with config items
                TriggerEvent('sergeis-stores:client:openUnownedShop', code)
              end
            }
          }
        })
      end
    end
  end
end

local function buildPrivateTargets()
  -- Remove only private zones (manage, stock, fleet)
  for id, zoneId in pairs(zones) do
    if string.match(id, '_manage$') or string.match(id, '_stock$') or string.match(id, '_fleet$') then
      StoreTarget.RemoveZone(zoneId)
      zones[id] = nil
    end
  end
  
  -- Build management targets only for stores the player has access to
  for _, s in ipairs(stores) do
    -- Use config coordinates if this store has a location_code, otherwise use database coordinates
    local points = s.points or {}
    if s.location_code and Config.Locations[s.location_code] and Config.Locations[s.location_code].points then
      points = Config.Locations[s.location_code].points
    end
    
    local hasPermission = hasPerm(s.id, 1) -- At least employee level

    -- Management targets - only for players with permissions
    if hasPermission and points.manage then
      local pid = ('store_%d_manage'):format(s.id)
      local mp = points.manage
      local coords = mp
      if type(mp) == 'vector4' or mp.w then coords = { x = mp.x, y = mp.y, z = mp.z, heading = mp.w } end
      local manageLength = (type(mp) == 'table' and mp.length) or Config.Interact.Manage.length
      local manageWidth = (type(mp) == 'table' and mp.width) or Config.Interact.Manage.width
      local manageHeight = (type(mp) == 'table' and mp.height) or Config.Interact.Manage.height
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, manageLength, manageWidth, {
        heading = coords.heading,
        height = manageHeight,
        distance = Config.Interact.Manage.distance,
        targets = {
          {
            name = pid,
            icon = Config.Interact.Manage.icon,
            label = Config.Interact.Manage.label,
            onSelect = function()
              TriggerEvent('sergeis-stores:client:openManage', s.id)
            end
          }
        }
      })
    end

    -- Stock targets - only for players with permissions
    if hasPermission and points.stock then
      local pid = ('store_%d_stock'):format(s.id)
      local sp = points.stock
      local coords = sp
      if type(sp) == 'vector4' or sp.w then coords = { x = sp.x, y = sp.y, z = sp.z, heading = sp.w } end
      local stockLength = (type(sp) == 'table' and sp.length) or Config.Interact.Stock.length
      local stockWidth = (type(sp) == 'table' and sp.width) or Config.Interact.Stock.width
      local stockHeight = (type(sp) == 'table' and sp.height) or Config.Interact.Stock.height
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, stockLength, stockWidth, {
        heading = coords.heading,
        height = stockHeight,
        distance = Config.Interact.Stock.distance,
        targets = {
          {
            name = pid,
            icon = Config.Interact.Stock.icon,
            label = Config.Interact.Stock.label,
            onSelect = function()
              TriggerEvent('sergeis-stores:client:openStock', s.id)
            end
          }
        }
      })
    end

    -- Fleet targets - only for players with permissions
    if hasPermission and points.fleet then
      local pid = ('store_%d_fleet'):format(s.id)
      local fp = points.fleet
      local coords = fp
      if type(fp) == 'vector4' or fp.w then coords = { x = fp.x, y = fp.y, z = fp.z, heading = fp.w } end
      local fleetLength = (type(fp) == 'table' and fp.length) or Config.Interact.Fleet.length
      local fleetWidth = (type(fp) == 'table' and fp.width) or Config.Interact.Fleet.width
      local fleetHeight = (type(fp) == 'table' and fp.height) or Config.Interact.Fleet.height
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, fleetLength, fleetWidth, {
        heading = coords.heading,
        height = fleetHeight,
        distance = Config.Interact.Fleet.distance,
        targets = {
          {
            name = pid,
            icon = Config.Interact.Fleet.icon,
            label = Config.Interact.Fleet.label,
            onSelect = function()
              TriggerEvent('sergeis-stores:client:openFleet', s.id)
            end
          }
        }
      })
    end
  end
  
  -- Add management points from config for not-yet-owned locations (private access)
  for code, loc in pairs(Config.Locations or {}) do
    if not purchasedLocations[code] then
      local managePoint = loc.points and loc.points.manage
      if managePoint then
        local pid = ('loc_%s_manage'):format(code)
        local coords = managePoint
        if type(managePoint) == 'vector4' or managePoint.w then coords = { x = managePoint.x, y = managePoint.y, z = managePoint.z, heading = managePoint.w } end
        local locManageLength = (type(managePoint) == 'table' and managePoint.length) or 1.2
        local locManageWidth = (type(managePoint) == 'table' and managePoint.width) or 1.2
        local locManageHeight = (type(managePoint) == 'table' and managePoint.height) or 1.2
        zones[pid] = StoreTarget.AddBoxZone(pid, coords, locManageLength, locManageWidth, {
          heading = coords.heading,
          height = locManageHeight,
          distance = 2.0,
          targets = {
            {
              name = pid,
              icon = 'fas fa-briefcase',
              label = 'Management (Locked)',
              onSelect = function()
                QBCore.Functions.Notify('Store not owned yet', 'error')
              end
            }
          }
        })
      end
    end
  end
end

RegisterNetEvent('sergeis-stores:client:refresh', function()
  local currentTime = GetGameTimer()
  
  -- Prevent multiple refreshes within 2 seconds
  if isRefreshing or (currentTime - lastRefreshTime) < 2000 then
    return
  end
  
  isRefreshing = true
  lastRefreshTime = currentTime
  
  -- First get stores data and build public targets immediately
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStores', function(data)
    stores = data or {}
    purchasedLocations = {}
    for _, s in ipairs(stores) do
      if s.location_code then purchasedLocations[s.location_code] = true end
    end
    
    -- Build public targets immediately (shopping access for everyone)
    buildPublicTargets()
    
    -- Then get permissions and add private targets
    QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(map)
      myPermissions = map or {}
      
      -- Build private targets (management access for authorized players)
      buildPrivateTargets()
      isRefreshing = false
    end)
  end)
end)

-- Simplified refresh that just gets stores and builds all targets
RegisterNetEvent('sergeis-stores:client:refreshSimple', function()
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStores', function(data)
    if data then
      stores = data
      purchasedLocations = {}
      for _, s in ipairs(stores) do
        if s.location_code then
          purchasedLocations[s.location_code] = true
        end
      end

      -- Build shopping targets immediately (these work for everyone)
      buildPublicTargets()

      -- Get permissions in background and add management targets if applicable
      QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(perms)
        myPermissions = perms or {}
        buildPrivateTargets()
      end)
    end
  end)
end)

-- Gate manage/stock zones client-side by permission (function moved to top of file)

-- Simple approach: Load targets when dependencies are ready
AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end

  CreateThread(function()
    -- Wait for basic dependencies
    while not (QBCore and QBCore.Functions and StoreTarget and StoreTarget.AddBoxZone) do
      Wait(100)
    end

    -- Load targets immediately with a simple approach
    Wait(2000) -- Give server time to be ready
    TriggerEvent('sergeis-stores:client:refreshSimple')
  end)
end)

-- Add a manual command to refresh targets
RegisterCommand('refreshtargets', function()
  TriggerEvent('sergeis-stores:client:refreshSimple')
end)

-- Add a test command to check if client is working
RegisterCommand('testclient', function()
  print('=== CLIENT TEST COMMAND ===')
  print('QBCore available:', QBCore ~= nil)
  print('StoreTarget available:', StoreTarget ~= nil)
  print('Config available:', Config ~= nil)
  print('Config.Locations available:', Config and Config.Locations ~= nil)
  if Config and Config.Locations then
    print('Config locations count:', tableCount(Config.Locations))
  end
  print('Current stores:', #stores)
end)

-- Add a command to check coordinates being used
RegisterCommand('checkcoords', function()
  print('=== COORDINATE CHECK ===')
  for _, s in ipairs(stores) do
    print('Store', s.id, 'location_code:', s.location_code)
    print('Database points:', json.encode(s.points or {}))

    if s.location_code and Config.Locations[s.location_code] then
      print('Config points:', json.encode(Config.Locations[s.location_code].points or {}))
      print('Using: CONFIG coordinates')
    else
      print('Using: DATABASE coordinates')
    end
    print('---')
  end
end)

-- Add a command to manually test purchase UI
RegisterCommand('testpurchase', function()
  print('=== TESTING PURCHASE UI ===')
  local testLocationCode = 'little_seoul_247'
  if Config and Config.Locations and Config.Locations[testLocationCode] then
    print(('Opening purchase UI for: %s'):format(testLocationCode))
    TriggerEvent('sergeis-stores:client:openPurchase', testLocationCode)
  else
    print('ERROR: Test location not found in config')
  end
end)

-- Handle player spawn/login events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  CreateThread(function()
    Wait(2000) -- Wait 2 seconds after player loads
    TriggerEvent('sergeis-stores:client:refreshSimple')
  end)
end)

-- Handle player spawn
AddEventHandler('playerSpawned', function()
  CreateThread(function()
    Wait(3000) -- Wait 3 seconds after spawn
    TriggerEvent('sergeis-stores:client:refreshSimple')
  end)
end)

-- Handle server broadcast of store locations (no callbacks needed!)
RegisterNetEvent('sergeis-stores:client:storeLocationsUpdate', function(storeData)
  if storeData and #storeData > 0 then
    stores = storeData
    purchasedLocations = {}
    for _, s in ipairs(stores) do
      if s.location_code then purchasedLocations[s.location_code] = true end
    end
    
    -- Build public shopping targets immediately (no permission needed)
    buildPublicTargets()
    
    -- Only build private targets if we don't already have them (to avoid overwriting)
    local hasPrivateTargets = false
    for id, _ in pairs(zones) do
      if string.match(id, '_manage$') or string.match(id, '_stock$') or string.match(id, '_fleet$') then
        hasPrivateTargets = true
        break
      end
    end
    
    if not hasPrivateTargets then
      -- Get permissions and build private targets if we don't have them yet
      QBCore.Functions.TriggerCallback('sergeis-stores:server:getMyStorePerms', function(perms)
        myPermissions = perms or {}
        buildPrivateTargets()
      end)
    end
  end
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for id, zoneId in pairs(zones) do
    StoreTarget.RemoveZone(zoneId)
    zones[id] = nil
  end
  for id, blip in pairs(blips) do
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    blips[id] = nil
  end
end)


