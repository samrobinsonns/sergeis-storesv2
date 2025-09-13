StoreTarget = StoreTarget or {}

local targetType = nil

local function detectTarget()
  if Config.Target == 'qb' then return 'qb' end
  if Config.Target == 'ox' then return 'ox' end
  if GetResourceState('ox_target') == 'started' then return 'ox' end
  if GetResourceState('qb-target') == 'started' then return 'qb' end
  return 'qb'
end

CreateThread(function()
  targetType = detectTarget()
end)

function StoreTarget.AddBoxZone(id, coords, length, width, options)
  print(('^3[SERGEI STORES TARGET] Creating zone %s at (%.2f, %.2f, %.2f) using %s'):format(id, coords.x, coords.y, coords.z, targetType))

  options = options or {}
  local heading = options.heading or (coords and (coords.heading or coords.w)) or 0.0
  local targets = options.targets or {}

  if targetType == 'ox' then
    print('^3[SERGEI STORES TARGET] Using ox_target')
    local success, zoneId = pcall(function()
      return exports.ox_target:addBoxZone({
        coords = vec3(coords.x, coords.y, coords.z),
        size = vec3(length, width, options.height or 1.2),
        rotation = heading,
        debug = Config.Debug,
        options = targets
      })
    end)
    if success then
      print(('^2[SERGEI STORES TARGET] Successfully created ox_target zone: %s'):format(zoneId))
      return zoneId
    else
      print(('^1[SERGEI STORES TARGET] ERROR creating ox_target zone: %s'):format(zoneId))
      return nil
    end
  else
    print('^3[SERGEI STORES TARGET] Using qb-target')
    local qbTargets = {}
    for i = 1, #targets do
      local t = targets[i]
      qbTargets[#qbTargets + 1] = {
        name = t.name,
        icon = t.icon,
        label = t.label,
        action = t.onSelect,
      }
    end
    local success, result = pcall(function()
      exports['qb-target']:AddBoxZone(id, vec3(coords.x, coords.y, coords.z), length, width, {
        name = id,
        heading = heading,
        debugPoly = Config.Debug,
        minZ = (coords.z - ((options.height or 1.2)/2)),
        maxZ = (coords.z + ((options.height or 1.2)/2))
      }, {
        options = qbTargets,
        distance = options.distance or 2.0
      })
      return id
    end)
    if success then
      print(('^2[SERGEI STORES TARGET] Successfully created qb-target zone: %s'):format(id))
      return id
    else
      print(('^1[SERGEI STORES TARGET] ERROR creating qb-target zone: %s'):format(result))
      return nil
    end
  end
end

function StoreTarget.RemoveZone(id)
  if targetType == 'ox' then
    exports.ox_target:removeZone(id)
  else
    exports['qb-target']:RemoveZone(id)
  end
end



