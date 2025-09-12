local QBCore = exports['qb-core']:GetCoreObject()

StoresCache = StoresCache or {}
ClientStores = ClientStores or {}

local function buildClientStores()
  ClientStores = {}
  for _, s in pairs(StoresCache) do
    ClientStores[#ClientStores + 1] = {
      id = s.id,
      name = s.name,
      points = s.points or {},
      location_code = s.location_code,
      blip_sprite = s.blip_sprite,
      blip_image_url = s.blip_image_url
    }
  end
end

function LoadStores()
  StoresCache = {}
  local rows = DB.GetStores()
  for _, row in ipairs(rows) do
    StoresCache[row.id] = row
  end
  buildClientStores()
end

-- Initial load with dependency checking
CreateThread(function()
  -- Wait for database to be ready
  local attempts = 0
  while attempts < 50 do -- 10 second timeout
    attempts = attempts + 1
    local success, result = pcall(function()
      return MySQL.query.await('SELECT 1 as test', {})
    end)
    
    if success then
      LoadStores()
      return
    end
    
    Wait(200)
  end
  
  -- Load anyway as fallback
  LoadStores()
end)

-- Callback to fetch stores
QBCore.Functions.CreateCallback('sergeis-stores:server:getStores', function(source, cb)
  cb(ClientStores)
end)

RegisterNetEvent('sergeis-stores:server:refreshClients', function()
  buildClientStores()
  TriggerClientEvent('sergeis-stores:client:refresh', -1)
end)

-- Broadcast store locations to all clients when server is ready
CreateThread(function()
  Wait(5000) -- Wait 5 seconds after server start
  buildClientStores()
  TriggerClientEvent('sergeis-stores:client:storeLocationsUpdate', -1, ClientStores)
end)

-- Also broadcast to individual players when they join
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
  local src = Player.PlayerData.source
  
  CreateThread(function()
    Wait(2000) -- Wait for client to be ready
    buildClientStores()
    TriggerClientEvent('sergeis-stores:client:storeLocationsUpdate', src, ClientStores)
  end)
end)

local function isAdmin(src)
  if src == 0 then return true end
  local has = QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
  return has
end

RegisterCommand('createstore', function(src, args)
  if not isAdmin(src) then
    TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
    return
  end
  local name = table.concat(args or {}, ' ')
  if name == nil or name == '' then name = ('Store #%d'):format(math.random(1000, 9999)) end
  local ped = GetPlayerPed(src)
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  local point = {
    x = coords.x,
    y = coords.y,
    z = coords.z,
    heading = heading,
    length = Config.DefaultStorePoint.length,
    width = Config.DefaultStorePoint.width,
    height = Config.DefaultStorePoint.height
  }
  local points = { shop = point }

  local Player = QBCore.Functions.GetPlayer(src)
  local ownerCid = 'unknown'
  if Player and Player.PlayerData then
    local idField = (Config and Config.IdentifierField) or 'citizenid'
    ownerCid = Player.PlayerData[idField] or Player.PlayerData.citizenid or Player.PlayerData.stateid or 'unknown'
  end
  local id = DB.CreateStore(name, ownerCid, points, nil)
  if id then
    LoadStores()
    TriggerClientEvent('QBCore:Notify', src, ('Created store "%s" (ID %d)'):format(name, id), 'success')
    TriggerEvent('sergeis-stores:server:refreshClients')
  else
    TriggerClientEvent('QBCore:Notify', src, 'Failed to create store', 'error')
  end
end, false)

-- Purchase a config location store
RegisterNetEvent('sergeis-stores:server:purchaseLocation', function(locationCode)
  local src = source
  local loc = Config.Locations[locationCode]
  if not loc then return end
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end

  -- Check if already owned
  for _, s in pairs(StoresCache) do
    if s.location_code == locationCode then
      TriggerClientEvent('QBCore:Notify', src, 'This location is already owned', 'error')
      return
    end
  end

  -- Enforce single-store ownership per player
  local idField = (Config and Config.IdentifierField) or 'citizenid'
  local cid = Player.PlayerData[idField] or Player.PlayerData.citizenid or Player.PlayerData.stateid
  for _, s in pairs(StoresCache) do
    if s.owner_cid == cid then
      TriggerClientEvent('QBCore:Notify', src, 'You already own a store', 'error')
      return
    end
  end

  local price = tonumber(loc.price) or 0
  if price > 0 then
    if not Player.Functions.RemoveMoney('bank', price) then
      TriggerClientEvent('QBCore:Notify', src, 'Not enough bank balance', 'error')
      return
    end
  end

  local points = loc.points or {}
  -- Normalize vector points into serializable tables with heading
  local function normalizePoint(p, fallback)
    if type(p) == 'vector4' or (type(p) == 'table' and p.w) then
      return { x = p.x, y = p.y, z = p.z, heading = p.w, length = fallback.length, width = fallback.width, height = fallback.height }
    elseif type(p) == 'vector3' then
      return { x = p.x, y = p.y, z = p.z, heading = 0.0, length = fallback.length, width = fallback.width, height = fallback.height }
    elseif type(p) == 'table' then
      return p
    end
    return nil
  end
  if points.purchase then points.purchase = normalizePoint(points.purchase, { length = 1.2, width = 1.2, height = 1.2 }) end
  if points.order then 
    points.shop = normalizePoint(points.order, { length = 1.6, width = 1.6, height = 1.2 })
    points.order = nil -- Remove order point since we're using shop instead
  end
  if points.manage then points.manage = normalizePoint(points.manage, { length = 1.2, width = 1.2, height = 1.2 }) end
  local id = DB.CreateStore(loc.label, cid, points, locationCode)
  if id then
    LoadStores()
    TriggerClientEvent('QBCore:Notify', src, ('Purchased %s'):format(loc.label), 'success')
    TriggerEvent('sergeis-stores:server:refreshClients')
  else
    TriggerClientEvent('QBCore:Notify', src, 'Purchase failed', 'error')
  end
end)


