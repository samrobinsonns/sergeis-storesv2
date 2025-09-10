## Sergei's Stores V2 (QBCore)

Player-owned stores for QBCore with configurable locations, stock, employees/permissions, company bank (stub), checkout, and fleet stubs. Supports ox_target or qb-target, and ox_inventory or qb-inventory. Persistence via oxmysql.

### Features
- **Config locations**: purchase/order/manage points using vector3/vector4.
- **Ownership**: buy predefined locations; owners/managers manage stock and employees.
- **Stock & checkout**: allowed items per location; atomic stock adjust; delivers via ox_inventory or qb-inventory.
- **Employees & permissions**: employee roles (employee/manager/owner).
- **Fleet (stub)**: list/add vehicles; spawn/store extension hooks in place.
- **Target auto-detect**: ox_target preferred, else qb-target.
- **Inventory auto-detect**: ox_inventory preferred, else qb-inventory.

### Requirements
- FiveM FXServer (lua54)
- `qb-core`
- `oxmysql`
- One target resource: `ox_target` or `qb-target`
- One inventory: `ox_inventory` or `qb-inventory`

### Installation
1) Place the folder `sergeis-storesv2` in your resources.
2) Ensure dependencies start before this resource in your server.cfg.
3) Import SQL schema:
```sql
-- Run this in your DB
SOURCE /path/to/resources/[local]/sergeis-storesv2/sql/schema.sql;
```
4) Start the resource in server.cfg:
```cfg
ensure oxmysql
ensure qb-core
ensure ox_inventory    # or qb-inventory
ensure ox_target       # or qb-target
ensure sergeis-storesv2
```

### Configuration
Edit `config.lua`.

- **Target selection**:
```lua
Config.Target = 'auto' -- 'auto' | 'ox' | 'qb'
```

- **Default interaction sizes**: `Config.Interact.*` (length/width/height/distance).

- **Locations (vector3/vector4)**:
```lua
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
  }
}
```
- You may use `vector3(x,y,z)`; heading defaults to 0.0.
- On purchase, points are normalized and persisted as `{ x,y,z,heading,length,width,height }`.

### Usage
- Purchase a predefined location via its Purchase target.
- Shop/Order target opens the customer UI to add to cart and Checkout.
- Manage target opens management UI (stock/employees/fleet stubs).
- Admin command to create an ad-hoc store at your ped:
```text
/createstore <name>
```

### Inventory Integration
- Auto-detects `ox_inventory` first, else `qb-inventory`.
- Items delivered using `Inv.AddItem(src, item, amount, metadata)`.

### Target Integration
- Auto-detects `ox_target` first, else `qb-target`.
- Wrapper `StoreTarget.AddBoxZone` standardizes rotations/minZ/maxZ.

### Allowed Items per Location
- Each `Config.Locations[code].allowedItems` gates stock updates.
- Server validates in `sergeis-stores:server:upsertStockAllowed`.
- `getStock` callback returns `{ items, allowedItems }` for UI.

### Database
- Uses `@oxmysql` await APIs throughout.
- All queries in `server/sv_db.lua` only.
- Schema in `sql/schema.sql`; idempotent `CREATE TABLE IF NOT EXISTS`.

### Events & Callbacks
- Client refresh event: `sergeis-stores:client:refresh`.
- Get stores: callback `sergeis-stores:server:getStores`.
- Get stock/vehicles: callbacks `sergeis-stores:server:getStock`, `sergeis-stores:server:getVehicles`.
- Purchase location: server event `sergeis-stores:server:purchaseLocation`.
- Checkout: server event `sergeis-stores:server:checkout`.
- Upsert stock (allowed): server event `sergeis-stores:server:upsertStockAllowed`.

### NUI
- Open/close via postMessage with `action` field.
- Registered callbacks from page:
  - `close`
  - `purchase` (data: `{ locationCode }`)
  - `checkout` (data: `{ storeId, cart, payType }`)
  - `upsertStockAllowed` (data: `{ storeId, item, label, price, stock }`)

### Testing Checklist
- Purchase config location creates a store and refreshes targets.
- Shop UI lists stock and allows checkout; items delivered via inventory.
- Stock UI lists items and allows upsert for allowed items only.
- Management and Fleet UIs open without errors (stubs ok).
- Targets appear for both `ox_target` and `qb-target`.

### Notes
- Currently designed for `oxmysql`. Other MySQL resources (mysql-async/ghmattimysql) are not supported without an adapter.
- Company banking, full employee CRUD UI, and fleet spawning are sketched for future work.


