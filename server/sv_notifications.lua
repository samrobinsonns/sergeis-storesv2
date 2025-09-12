local QBCore = exports['qb-core']:GetCoreObject()

-- Helper function to get player source by citizen ID
local function getPlayerSourceByCitizenId(citizenId)
  local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
  return Player and Player.PlayerData.source or nil
end

-- Helper function to send lb-phone text message
local function sendLBPhoneMessage(source, storeName, message)
  if not source then return end
  
  -- Use store name as sender, with fallback to generic alert
  local senderName = storeName or 'Store Alert'
  
  -- Try different lb-phone methods for sending text messages
  local methods = {
    -- Method 1: Try SendMessage export (most common)
    function()
      exports['lb-phone']:SendMessage(source, senderName, message)
      return true
    end,
    
    -- Method 2: Try SendMessage with table parameter
    function()
      exports['lb-phone']:SendMessage(source, {
        sender = senderName,
        message = message,
        anonymous = false
      })
      return true
    end,
    
    -- Method 3: Try SendMessage with full parameters
    function()
      exports['lb-phone']:SendMessage(source, {
        number = senderName,
        message = message,
        name = senderName,
        time = os.date('%H:%M')
      })
      return true
    end,
    
    -- Method 4: Try CreateMessage export 
    function()
      exports['lb-phone']:CreateMessage(source, {
        sender = senderName,
        message = message,
        subject = '📦 Stock Alert',
        timestamp = os.time()
      })
      return true
    end,
    
    -- Method 5: Try client event method
    function()
      TriggerClientEvent('lb-phone:receiveMessage', source, {
        number = senderName,
        message = message,
        name = senderName,
        time = os.date('%H:%M')
      })
      return true
    end,
    
    -- Method 6: Try phone:receiveMessage event 
    function()
      TriggerClientEvent('phone:receiveMessage', source, {
        sender = senderName,
        message = message,
        time = os.date('%H:%M'),
        anonymous = false
      })
      return true
    end
  }
  
  -- Try each method until one works
  local messagesSent = false
  if GetResourceState('lb-phone') == 'started' then
    for i, method in ipairs(methods) do
      local success = pcall(method)
      if success then
        print(string.format('[Sergeis Stores] Text message sent via lb-phone method %d to source %d', i, source))
        messagesSent = true
        break
      end
    end
  end
  
  -- Fallback to QBCore notification if lb-phone methods fail
  if not messagesSent then
    TriggerClientEvent('QBCore:Notify', source, senderName .. ': ' .. message, 'error', 5000)
    print(string.format('[Sergeis Stores] Fallback notification sent to source %d (lb-phone unavailable)', source))
  end
end

-- Event handler for when stock goes empty
RegisterServerEvent('sergeis-stores:server:stockEmpty', function(storeId, item, itemLabel)
  -- Get store information
  local store = StoresCache[storeId]
  if not store then return end
  
  local storeName = store.name or 'Store #' .. storeId
  
  -- Prepare notification details
  local message = string.format('📦 STOCK ALERT: %s is out of stock!', itemLabel)
  
  -- Notify store owner
  if store.owner_cid then
    local ownerSource = getPlayerSourceByCitizenId(store.owner_cid)
    if ownerSource then
      sendLBPhoneMessage(ownerSource, storeName, message)
    end
  end
  
  -- Notify all employees
  local employees = DB.GetEmployees(storeId)
  for _, employee in ipairs(employees) do
    local employeeSource = getPlayerSourceByCitizenId(employee.citizenid)
    if employeeSource and employee.citizenid ~= store.owner_cid then -- Don't double-notify owner
      sendLBPhoneMessage(employeeSource, storeName, message)
    end
  end
  
  print(string.format('[Sergeis Stores] Stock empty notification sent for %s at %s (Store ID: %d)', itemLabel, storeName, storeId))
end)

-- Export for external use
exports('NotifyStockEmpty', function(storeId, item, itemLabel)
  TriggerEvent('sergeis-stores:server:stockEmpty', storeId, item, itemLabel)
end)

-- Export for custom lb-phone text message (for advanced users)
exports('SendStoreMessage', function(citizenId, storeName, message)
  local source = getPlayerSourceByCitizenId(citizenId)
  if source then
    sendLBPhoneMessage(source, storeName, message)
  end
end)
