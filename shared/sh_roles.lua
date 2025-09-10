StorePermission = {
  EMPLOYEE = 1,
  MANAGER = 2,
  OWNER = 3
}

StorePermissionName = {
  [1] = 'employee',
  [2] = 'manager',
  [3] = 'owner'
}

function HasStorePermission(currentLevel, requiredLevel)
  currentLevel = currentLevel or 0
  requiredLevel = requiredLevel or 0
  return currentLevel >= requiredLevel
end


