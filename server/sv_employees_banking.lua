local QBCore = exports['qb-core']:GetCoreObject()


local function getCitizenId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

local function getTableKeys(t)
  local keys = {}
  if type(t) == 'table' then
    for k, _ in pairs(t) do
      table.insert(keys, k)
    end
  end
  return keys
end

function registerEmployeeCallbacks()
  print('=== Registering Employee Callbacks ===')
  
  -- Employee Management
  print('Registering getEmployees callback...')
  QBCore.Functions.CreateCallback('sergeis-stores:server:getEmployees', function(source, cb, storeId)
  print('Server callback getEmployees called with storeId:', storeId)
  
  -- Defensive programming - ensure callback always responds
  local success, result = pcall(function()
    if not storeId then
      print('ERROR: No storeId provided to getEmployees')
      return {}
    end
    
    if not DB or not DB.GetEmployees then
      print('ERROR: DB.GetEmployees not available')
      return {}
    end
    
    local employees = DB.GetEmployees(storeId)
    print('Found employees:', json.encode(employees))
    
    -- Add the store owner to the employee list
    local store = StoresCache[storeId]
    if store and store.owner_cid then
      -- Check if owner is already in the employee list (shouldn't happen, but just in case)
      local ownerAlreadyExists = false
      for _, emp in ipairs(employees) do
        if emp.citizenid == store.owner_cid then
          ownerAlreadyExists = true
          break
        end
      end
      
      -- If owner is not already in the list, add them
      if not ownerAlreadyExists then
        table.insert(employees, 1, { -- Insert at the beginning of the list
          citizenid = store.owner_cid,
          permission = StorePermission.OWNER
        })
      end
    end
    
    -- Enrich employee data with player names
    for i, emp in ipairs(employees) do
      local player = QBCore.Functions.GetPlayerByCitizenId(emp.citizenid)
      if player then
        emp.name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        emp.online = true
      else
        -- Try to get name from database
        local result = MySQL.query.await('SELECT JSON_EXTRACT(charinfo, "$.firstname") as firstname, JSON_EXTRACT(charinfo, "$.lastname") as lastname FROM players WHERE citizenid = ?', { emp.citizenid })
        if result and result[1] then
          emp.name = result[1].firstname .. ' ' .. result[1].lastname
        else
          emp.name = emp.citizenid -- Fallback
        end
        emp.online = false
      end
    end
    
    return employees
  end)
  
  if success then
    print('Sending employees response:', json.encode(result))
    cb(result)
  else
    print('ERROR in getEmployees callback:', result)
    cb({})
  end
end)

RegisterNetEvent('sergeis-stores:server:hireEmployee', function(storeId, citizenid, permission)
  local src = source
  local currentCid = getCitizenId(src)
  if not currentCid then return end
  
  local currentLevel = DB.GetEmployeePermission(storeId, currentCid)
  local store = StoresCache[storeId]
  if store and store.owner_cid == currentCid then
    currentLevel = StorePermission.OWNER
  end
  local hasPermission = HasStorePermission(currentLevel, StorePermission.OWNER)
  if not hasPermission then
    TriggerClientEvent('QBCore:Notify', src, 'Only owners can hire employees', 'error')
    return
  end
  
  -- Check if player exists
  local result = MySQL.query.await('SELECT citizenid FROM players WHERE citizenid = ?', { citizenid })
  if not result or #result == 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
    return
  end
  
  -- Check if already employed
  local existing = MySQL.query.await('SELECT citizenid FROM sergeis_store_employees WHERE store_id = ? AND citizenid = ?', { storeId, citizenid })
  if existing and #existing > 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Player is already employed at this store', 'error')
    return
  end
  
  -- Hire employee
  MySQL.insert.await('INSERT INTO sergeis_store_employees (store_id, citizenid, permission) VALUES (?, ?, ?)', { storeId, citizenid, permission })
  TriggerClientEvent('QBCore:Notify', src, 'Employee hired successfully', 'success')
  
  -- Notify the hired player if online
  local hiredPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
  if hiredPlayer then
    local store = StoresCache[storeId]
    local storeName = store and store.name or 'Unknown Store'
    TriggerClientEvent('QBCore:Notify', hiredPlayer.PlayerData.source, 'You have been hired at ' .. storeName, 'success')
  end
end)

RegisterNetEvent('sergeis-stores:server:fireEmployee', function(storeId, citizenid)
  local src = source
  local currentCid = getCitizenId(src)
  if not currentCid then return end
  
  local currentLevel = DB.GetEmployeePermission(storeId, currentCid)
  local store = StoresCache[storeId]
  if store and store.owner_cid == currentCid then
    currentLevel = StorePermission.OWNER
  end
  local hasPermission = HasStorePermission(currentLevel, StorePermission.OWNER)
  if not hasPermission then
    TriggerClientEvent('QBCore:Notify', src, 'Only owners can fire employees', 'error')
    return
  end
  
  -- Cannot fire the owner
  local store = StoresCache[storeId]
  if store and store.owner_cid == citizenid then
    TriggerClientEvent('QBCore:Notify', src, 'Cannot fire the store owner', 'error')
    return
  end
  
  -- Fire employee
  MySQL.query.await('DELETE FROM sergeis_store_employees WHERE store_id = ? AND citizenid = ?', { storeId, citizenid })
  TriggerClientEvent('QBCore:Notify', src, 'Employee fired successfully', 'success')
  
  -- Notify the fired player if online
  local firedPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
  if firedPlayer then
    local store = StoresCache[storeId]
    local storeName = store and store.name or 'Unknown Store'
    TriggerClientEvent('QBCore:Notify', firedPlayer.PlayerData.source, 'You have been fired from ' .. storeName, 'error')
  end
end)

RegisterNetEvent('sergeis-stores:server:updateEmployeePermission', function(storeId, citizenid, permission)
  local src = source
  local currentCid = getCitizenId(src)
  if not currentCid then return end
  
  local currentLevel = DB.GetEmployeePermission(storeId, currentCid)
  local store = StoresCache[storeId]
  if store and store.owner_cid == currentCid then
    currentLevel = StorePermission.OWNER
  end
  local hasPermission = HasStorePermission(currentLevel, StorePermission.OWNER)
  if not hasPermission then
    TriggerClientEvent('QBCore:Notify', src, 'Only owners can change employee permissions', 'error')
    return
  end
  
  -- Cannot change owner permission
  local store = StoresCache[storeId]
  if store and store.owner_cid == citizenid then
    TriggerClientEvent('QBCore:Notify', src, 'Cannot change owner permissions', 'error')
    return
  end
  
  -- Update permission
  MySQL.query.await('UPDATE sergeis_store_employees SET permission = ? WHERE store_id = ? AND citizenid = ?', { permission, storeId, citizenid })
  TriggerClientEvent('QBCore:Notify', src, 'Employee permission updated', 'success')
end)

  print('=== Employee callbacks registered successfully ===')
end

function registerBankingCallbacks()
  print('=== Registering Banking Callbacks (deposit/withdraw events) ===')
  
  -- Note: getBankingInfo callback is registered at file level, not here

RegisterNetEvent('sergeis-stores:server:depositMoney', function(storeId, amount, payType)
  local src = source
  local currentCid = getCitizenId(src)
  if not currentCid then return end
  
  local currentLevel = DB.GetEmployeePermission(storeId, currentCid)
  local store = StoresCache[storeId]
  if store and store.owner_cid == currentCid then
    currentLevel = StorePermission.OWNER
  end
  local hasPermission = HasStorePermission(currentLevel, StorePermission.MANAGER)
  if not hasPermission then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to manage store banking', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  -- Default to config payment type if not specified
  payType = payType or Config.DefaultPayment or 'cash'
  
  -- Check if player has enough money (cash or bank)
  local playerMoney = (payType == 'cash') and Player.PlayerData.money.cash or Player.PlayerData.money.bank
  if playerMoney < amount then
    local moneyType = (payType == 'cash') and 'cash' or 'bank account'
    TriggerClientEvent('QBCore:Notify', src, 'Not enough money in ' .. moneyType, 'error')
    return
  end
  
  -- Remove money from player and add to store
  Player.Functions.RemoveMoney(payType, amount, 'store-deposit')
  
  -- Update store balance
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance + ? WHERE id = ?', { amount, storeId })
  
  -- Log transaction
  MySQL.insert.await('INSERT INTO sergeis_store_transactions (store_id, citizenid, amount, payload) VALUES (?, ?, ?, ?)', {
    storeId,
    currentCid,
    amount,
    json.encode({ type = 'deposit', description = (payType == 'cash') and 'Cash deposit' or 'Bank deposit', payType = payType })
  })
  
  -- Update cache
  if StoresCache[storeId] then
    StoresCache[storeId].account_balance = (StoresCache[storeId].account_balance or 0) + amount
  end
  
  local moneyType = (payType == 'cash') and 'cash' or 'bank account'
  TriggerClientEvent('QBCore:Notify', src, 'Deposited $' .. amount .. ' from ' .. moneyType .. ' to store account', 'success')
  
  -- Trigger refresh to update UI
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

RegisterNetEvent('sergeis-stores:server:withdrawMoney', function(storeId, amount, payType)
  local src = source
  local currentCid = getCitizenId(src)
  if not currentCid then return end
  
  local currentLevel = DB.GetEmployeePermission(storeId, currentCid)
  local store = StoresCache[storeId]
  if store and store.owner_cid == currentCid then
    currentLevel = StorePermission.OWNER
  end
  local hasPermission = HasStorePermission(currentLevel, StorePermission.MANAGER)
  if not hasPermission then
    TriggerClientEvent('QBCore:Notify', src, 'No permission to manage store banking', 'error')
    return
  end
  
  local store = StoresCache[storeId]
  if not store or (store.account_balance or 0) < amount then
    TriggerClientEvent('QBCore:Notify', src, 'Insufficient store funds', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  -- Default to config payment type if not specified
  payType = payType or Config.DefaultPayment or 'cash'
  
  -- Remove money from store and add to player
  MySQL.query.await('UPDATE sergeis_stores SET account_balance = account_balance - ? WHERE id = ?', { amount, storeId })
  Player.Functions.AddMoney(payType, amount, 'store-withdrawal')
  
  -- Log transaction
  MySQL.insert.await('INSERT INTO sergeis_store_transactions (store_id, citizenid, amount, payload) VALUES (?, ?, ?, ?)', {
    storeId,
    currentCid,
    -amount,
    json.encode({ type = 'withdrawal', description = (payType == 'cash') and 'Cash withdrawal' or 'Bank withdrawal', payType = payType })
  })
  
  -- Update cache
  if StoresCache[storeId] then
    StoresCache[storeId].account_balance = (StoresCache[storeId].account_balance or 0) - amount
  end
  
  local moneyType = (payType == 'cash') and 'cash' or 'bank account'
  TriggerClientEvent('QBCore:Notify', src, 'Withdrew $' .. amount .. ' from store account to ' .. moneyType, 'success')
  
  -- Trigger refresh to update UI
  TriggerEvent('sergeis-stores:server:refreshClients')
end)

  -- Test callback to verify registration works
  print('Registering test callback...')
  QBCore.Functions.CreateCallback('sergeis-stores:server:testBanking', function(source, cb)
    print('TEST BANKING CALLBACK CALLED!')
    cb({ success = true, message = 'Banking test callback works!' })
  end)

  print('=== Banking callbacks registered successfully ===')
end

-- Wait for QBCore to be fully ready before registering callbacks
CreateThread(function()
  -- Wait a moment for everything to initialize
  Wait(100)
  
  -- Test that QBCore is available
  print('=== Testing QBCore availability ===')
  print('QBCore type:', type(QBCore))
  print('QBCore.Functions type:', type(QBCore.Functions))
  print('QBCore.Functions.CreateCallback type:', type(QBCore.Functions.CreateCallback))

  -- Register banking callback directly (like other server files do)
  print('=== Registering getBankingInfo callback directly ===')
  QBCore.Functions.CreateCallback('sergeis-stores:server:getBankingInfo', function(source, cb, storeId)
  print('=== BANKING CALLBACK START ===')
  print('Server callback getBankingInfo called with storeId:', storeId)
  print('StoresCache exists:', StoresCache ~= nil)
  
  -- Validate input
  if not storeId then
    print('ERROR: No storeId provided to getBankingInfo')
    cb({ balance = 0, transactions = {} })
    return
  end
  
  local storeIdNum = tonumber(storeId)
  print('Converted storeId to number:', storeIdNum)
  
  -- Try to get store data from cache first, then fallback to database
  local store = StoresCache and StoresCache[storeIdNum]
  local balance = 0
  
  print('Store from cache:', json.encode(store or {}))
  
  if store then
    balance = tonumber(store.account_balance) or 0
    print('Store balance from cache:', balance)
  else
    print('Store not in cache, querying database...')
    local success, dbResult = pcall(function()
      return MySQL.single.await('SELECT account_balance FROM sergeis_stores WHERE id = ?', { storeIdNum })
    end)
    
    print('Database query success:', success)
    print('Database result:', json.encode(dbResult or {}))
    
    if success and dbResult then
      balance = tonumber(dbResult.account_balance) or 0
      print('Store balance from database:', balance)
    else
      print('ERROR: Could not fetch store from database:', dbResult)
      cb({ balance = 0, transactions = {} })
      return
    end
  end
  
  -- Get recent transactions
  local success, transactions = pcall(function()
    return MySQL.query.await('SELECT amount, payload, created_at FROM sergeis_store_transactions WHERE store_id = ? ORDER BY created_at DESC LIMIT 20', { storeIdNum })
  end)
  
  if not success then
    print('ERROR fetching transactions:', transactions)
    transactions = {}
  else
    print('Transactions fetched successfully, count:', #(transactions or {}))
  end
  
    local result = {
      balance = balance,
      transactions = transactions or {}
    }
    
    print('Final banking response:', json.encode(result))
    print('=== BANKING CALLBACK END ===')
    cb(result)
  end)
  print('=== getBankingInfo callback registered ===')

  -- Test database connection and verify store data
  Wait(1000) -- Wait for everything to load
  print('=== Testing database connection for store ID 2 ===')
  local success, result = pcall(function()
    return MySQL.single.await('SELECT id, name, account_balance FROM sergeis_stores WHERE id = 2', {})
  end)
  
  if success and result then
    print('Store 2 data from database:', json.encode(result))
  else
    print('Failed to query store 2:', result)
  end

  -- Now register all other callbacks after functions are defined
  print('=== Registering other callbacks ===')
  registerEmployeeCallbacks()
  registerBankingCallbacks()
  print('=== Callback registration completed ===')
end)

-- Add a test command to check if callback is working 
RegisterCommand('testbank', function(source, args)
  local storeId = tonumber(args[1]) or 2
  print('=== Manual banking test for store', storeId, '===')
  
  -- Test if the callback exists by simulating what the client does
  print('Testing if getBankingInfo callback is registered...')
  
  -- Direct simulation of callback execution
  local success, result = pcall(function()
    -- Simulate the callback parameters
    local testResult = {}
    
    -- Try calling the MySQL directly to test database connection
    local dbResult = MySQL.single.await('SELECT account_balance FROM sergeis_stores WHERE id = ?', { storeId })
    if dbResult then
      testResult.balance = tonumber(dbResult.account_balance) or 0
      testResult.source = 'direct_db'
    else
      testResult.balance = 0
      testResult.source = 'db_failed'
    end
    
    return testResult
  end)
  
  if success then
    print('Direct DB test result:', json.encode(result))
    if source > 0 then
      TriggerClientEvent('QBCore:Notify', source, 'Direct DB test: Balance = $' .. (result.balance or 0) .. ' (Source: ' .. (result.source or 'unknown') .. ')', 'info')
    end
  else
    print('Direct DB test failed:', result)
    if source > 0 then
      TriggerClientEvent('QBCore:Notify', source, 'Direct DB test failed: ' .. tostring(result), 'error')
    end
  end
end)
