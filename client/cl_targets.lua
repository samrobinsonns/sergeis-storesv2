-- Use global StoreTarget from target_wrapper.lua

local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local stores = {}
local purchasedLocations = {}

local function buildTargets()
  for id, zoneId in pairs(zones) do
    StoreTarget.RemoveZone(zoneId)
    zones[id] = nil
  end

  for _, s in ipairs(stores) do
    local points = s.points or {}

    local orderPoint = points.shop or points.order
    if orderPoint then
      local pid = ('store_%d_shop'):format(s.id)
      local shop = orderPoint
      local coords = shop
      if type(shop) == 'vector4' or shop.w then coords = { x = shop.x, y = shop.y, z = shop.z, heading = shop.w } end
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, shop.length or Config.Interact.Shop.length, shop.width or Config.Interact.Shop.width, {
        heading = coords.heading,
        height = points.shop.height or Config.Interact.Shop.height,
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

    if points.manage then
      local pid = ('store_%d_manage'):format(s.id)
      local mp = points.manage
      local coords = mp
      if type(mp) == 'vector4' or mp.w then coords = { x = mp.x, y = mp.y, z = mp.z, heading = mp.w } end
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, mp.length or Config.Interact.Manage.length, mp.width or Config.Interact.Manage.width, {
        heading = coords.heading,
        height = points.manage.height or Config.Interact.Manage.height,
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

    if points.stock then
      local pid = ('store_%d_stock'):format(s.id)
      local sp = points.stock
      local coords = sp
      if type(sp) == 'vector4' or sp.w then coords = { x = sp.x, y = sp.y, z = sp.z, heading = sp.w } end
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, sp.length or Config.Interact.Stock.length, sp.width or Config.Interact.Stock.width, {
        heading = coords.heading,
        height = points.stock.height or Config.Interact.Stock.height,
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

    if points.fleet then
      local pid = ('store_%d_fleet'):format(s.id)
      local fp = points.fleet
      local coords = fp
      if type(fp) == 'vector4' or fp.w then coords = { x = fp.x, y = fp.y, z = fp.z, heading = fp.w } end
      zones[pid] = StoreTarget.AddBoxZone(pid, coords, fp.length or Config.Interact.Fleet.length, fp.width or Config.Interact.Fleet.width, {
        heading = coords.heading,
        height = points.fleet.height or Config.Interact.Fleet.height,
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

  -- Add purchase/order/manage points from config for not-yet-owned locations
  for code, loc in pairs(Config.Locations or {}) do
    if not purchasedLocations[code] then
      if loc.points and loc.points.purchase then
        local pid = ('loc_%s_purchase'):format(code)
        local p = loc.points.purchase
        local coords = p
        if type(p) == 'vector4' or p.w then coords = { x = p.x, y = p.y, z = p.z, heading = p.w } end
        zones[pid] = StoreTarget.AddBoxZone(pid, coords, p.length or 1.2, p.width or 1.2, {
          heading = coords.heading,
          height = loc.points.purchase.height or 1.2,
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
      if loc.points and loc.points.order then
        local pid = ('loc_%s_order'):format(code)
        local o = loc.points.order
        local coords = o
        if type(o) == 'vector4' or o.w then coords = { x = o.x, y = o.y, z = o.z, heading = o.w } end
        zones[pid] = StoreTarget.AddBoxZone(pid, coords, o.length or 1.6, o.width or 1.6, {
          heading = coords.heading,
          height = loc.points.order.height or 1.2,
          distance = 2.0,
          targets = {
            {
              name = pid,
              icon = 'fas fa-shopping-basket',
              label = 'Order Items',
              onSelect = function()
                -- If unowned, just inform player
                QBCore.Functions.Notify('Store not owned yet', 'error')
              end
            }
          }
        })
      end
      if loc.points and loc.points.manage then
        local pid = ('loc_%s_manage'):format(code)
        local m = loc.points.manage
        local coords = m
        if type(m) == 'vector4' or m.w then coords = { x = m.x, y = m.y, z = m.z, heading = m.w } end
        zones[pid] = StoreTarget.AddBoxZone(pid, coords, m.length or 1.2, m.width or 1.2, {
          heading = coords.heading,
          height = loc.points.manage.height or 1.2,
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
  QBCore.Functions.TriggerCallback('sergeis-stores:server:getStores', function(data)
    stores = data or {}
    purchasedLocations = {}
    for _, s in ipairs(stores) do
      if s.location_code then purchasedLocations[s.location_code] = true end
    end
    buildTargets()
  end)
end)

AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  TriggerEvent('sergeis-stores:client:refresh')
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for id, zoneId in pairs(zones) do
    StoreTarget.RemoveZone(zoneId)
    zones[id] = nil
  end
end)


