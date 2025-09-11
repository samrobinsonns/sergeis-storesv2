Config = {}

-- 'auto' will use ox_target if started, else qb-target if started. Can force 'qb' or 'ox'.
Config.Target = 'auto'
Config.Debug = false

-- Default interaction configuration per point type
Config.Interact = {
  Shop = { label = 'Open Store', icon = 'fas fa-shopping-basket', length = 1.6, width = 1.6, height = 1.2, distance = 2.0 },
  Manage = { label = 'Manage Store', icon = 'fas fa-briefcase', length = 1.4, width = 1.4, height = 1.2, distance = 2.0 },
  Stock = { label = 'Stock', icon = 'fas fa-boxes', length = 1.4, width = 1.4, height = 1.2, distance = 2.0 },
  Fleet = { label = 'Fleet', icon = 'fas fa-truck', length = 1.6, width = 1.6, height = 1.2, distance = 2.0 }
}

-- Default payment method when purchasing from the cart
Config.DefaultPayment = 'bank' -- 'cash' or 'bank'

-- Default dimensions for new stores created via command
Config.DefaultStorePoint = {
  heading = 0.0,
  length = 1.6,
  width = 1.6,
  height = 1.4
}

-- Fleet vehicle configurations for purchasing
Config.FleetVehicles = {
  {
    model = 'bison',
    label = 'Bison Delivery Truck',
    price = 25000,
    category = 'delivery',
    capacity = 200, -- For future stock capacity implementation
    description = 'Basic delivery truck for small loads'
  },
  {
    model = 'mule',
    label = 'Mule Transport Truck',
    price = 45000,
    category = 'delivery', 
    capacity = 500,
    description = 'Medium delivery truck for larger loads'
  },
  {
    model = 'phantom',
    label = 'Phantom Big Rig',
    price = 75000,
    category = 'heavy',
    capacity = 1000,
    description = 'Heavy duty truck for bulk deliveries'
  },
  {
    model = 'speedo',
    label = 'Speedo Van',
    price = 18000,
    category = 'light',
    capacity = 150,
    description = 'Compact van for quick deliveries'
  },
  {
    model = 'rumpo',
    label = 'Rumpo Van',
    price = 22000,
    category = 'light',
    capacity = 180,
    description = 'Reliable van for city deliveries'
  }
}

-- Capacity upgrade tiers (can be expanded)
-- Each upgrade increases the store's max capacity by `increase` for the listed `price`
Config.CapacityUpgrades = {
  { increase = 200, price = 50000 },
  { increase = 400, price = 90000 },
  { increase = 600, price = 130000 }
}

-- Predefined store locations driven by config
-- Add as many locations as you want; each can be purchased and becomes player-owned
-- Required points: purchase, order, manage, delivery
-- Optional points: fleet (vehicle spawn location for stock orders)
Config.Locations = {
  ["little_seoul_247"] = {
    label = "247 Little Seoul",
    price = 250000,
    maxCapacity = 1000,
    allowedItems = {
      water = 5,
      bread = 7,
      sandwich = 12,
      phone = 250
    },
    pickup = {
      location = vector4(-722.0473, -926.8512, 19.0170, 121.3623), -- Docks pickup location
      label = "Docks Warehouse"
    },
    points = {
      purchase = vector4(-709.17, -904.16, 19.22, 90.0),
      order    = vector4(-706.7286, -915.1316, 19.6570, 270.0733),
      manage   = vector4(-709.5926, -905.5182, 19.2156, 88.3521),
      delivery = vector4(-700.6078, -920.7957, 19.0139, 95.8714), -- Delivery point at store
      fleet    = vector4(-700.6078, -920.7957, 19.0139, 95.8714) -- Fleet vehicle spawn point
    }
  },
  ["paleto_247"] = {
    label = "247 Paleto Blvd",
    price = 225000,
    maxCapacity = 800,
    allowedItems = {
      water = 5,
      bread = 7,
      sandwich = 12
    },
    pickup = {
      location = vector4(-428.54, 6162.37, 31.48, 225.0), -- Paleto warehouse
      label = "Paleto Supply Depot"
    },
    points = {
      purchase = vector4(1730.59, 6419.00, 35.04, 335.0),
      order    = vector4(1728.72, 6415.31, 35.04, 335.0),
      manage   = vector4(1727.70, 6413.90, 35.04, 335.0),
      delivery = vector4(1730.59, 6419.00, 35.04, 335.0), -- Delivery point at store
      fleet    = vector4(1735.20, 6422.15, 35.04, 60.0) -- Fleet vehicle spawn point
    }
  }
}

-- Stock ordering configuration
Config.StockOrdering = {
  -- Base price per unit for stock items (can be overridden per item)
  basePricePerUnit = 5,
  
  -- Price multipliers for different item types
  itemPrices = {
    water = 3,
    bread = 4,
    sandwich = 8,
    phone = 25
  },
  
  -- Maximum units per order (safety limit)
  maxUnitsPerOrder = 500,
  
  -- Time limits for delivery missions (in seconds)
  pickupTimeLimit = 300, -- 5 minutes to reach pickup
  deliveryTimeLimit = 600 -- 10 minutes to deliver back to store
}


