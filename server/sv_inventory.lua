Inv = Inv or {}

local invType = nil

local function detect()
  if GetResourceState('ox_inventory') == 'started' then return 'ox' end
  if GetResourceState('qb-inventory') == 'started' then return 'qb' end
  return 'qb'
end

CreateThread(function()
  invType = detect()
end)

function Inv.AddItem(src, item, amount, metadata)
  amount = tonumber(amount) or 1
  if invType == 'ox' then
    return exports.ox_inventory:AddItem(src, item, amount, metadata)
  else
    local Player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.AddItem(item, amount, false, metadata)
  end
end


