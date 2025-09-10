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
Config.DefaultPayment = 'cash' -- 'cash' or 'bank'

-- Default dimensions for new stores created via command
Config.DefaultStorePoint = {
  heading = 0.0,
  length = 1.6,
  width = 1.6,
  height = 1.4
}

-- Predefined store locations driven by config
-- Add as many locations as you want; each can be purchased and becomes player-owned
Config.Locations = {
  ["little_seoul_247"] = {
    label = "247 Little Seoul",
    price = 250000,
    allowedItems = { 'water', 'bread', 'sandwich', 'phone' },
    points = {
      purchase = vector4(-709.17, -904.16, 19.22, 90.0),
      order    = vector4(-707.53, -914.80, 19.22, 0.0),
      manage   = vector4(-706.40, -913.80, 19.22, 0.0)
    }
  },
  ["paleto_247"] = {
    label = "247 Paleto Blvd",
    price = 225000,
    allowedItems = { 'water', 'bread', 'sandwich' },
    points = {
      purchase = vector4(1730.59, 6419.00, 35.04, 335.0),
      order    = vector4(1728.72, 6415.31, 35.04, 335.0),
      manage   = vector4(1727.70, 6413.90, 35.04, 335.0)
    }
  }
}


