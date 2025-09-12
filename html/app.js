(() => {
  const app = document.getElementById('app')
  const content = document.getElementById('content')
  const closeBtn = document.getElementById('close')
  let currentTab = 'shop'
  let state = {}

  // Confirmation dialog function
  function showConfirmDialog(title, message, onConfirm, onCancel = null) {
    // Create overlay
    const overlay = document.createElement('div')
    overlay.className = 'confirm-overlay'
    
    // Create dialog
    const dialog = document.createElement('div')
    dialog.className = 'confirm-dialog'
    
    dialog.innerHTML = `
      <div class="confirm-header">
        <h3>${title}</h3>
      </div>
      <div class="confirm-body">
        <p>${message}</p>
      </div>
      <div class="confirm-actions">
        <button class="confirm-btn confirm-cancel">Cancel</button>
        <button class="confirm-btn confirm-yes">Confirm</button>
      </div>
    `
    
    overlay.appendChild(dialog)
    const container = document.querySelector('.ui-container') || document.body
    container.appendChild(overlay)
    
    // Add event listeners
    const cancelBtn = dialog.querySelector('.confirm-cancel')
    const confirmBtn = dialog.querySelector('.confirm-yes')
    
    const cleanup = () => {
      if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay)
    }
    
    cancelBtn.addEventListener('click', () => {
      cleanup()
      if (onCancel) onCancel()
    })
    
    confirmBtn.addEventListener('click', () => {
      cleanup()
      onConfirm()
    })
    
    // Close on overlay click
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) {
        cleanup()
        if (onCancel) onCancel()
      }
    })
    
    // Focus on confirm button
    setTimeout(() => confirmBtn.focus(), 100)
  }

  // Order Stock Dialog
  function showOrderStockDialog() {
    console.log('Opening order stock dialog')
    
    // First fetch available vehicles
    const resourceName = GetParentResourceName()
    fetch(`https://${resourceName}/getFleetVehicles`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ storeId: state.storeId })
    })
    .then(response => response.json())
    .then(data => {
      const vehicles = (data.vehicles || []).filter(v => v.stored) // Only stored vehicles
      const allowedItems = state.allowedItems || []
      
      if (vehicles.length === 0) {
        showConfirmDialog(
          'No Vehicles Available',
          'You need to have stored vehicles in your fleet to order stock. Please purchase and store a vehicle first.',
          () => {}
        )
        return
      }
      
      // Create order dialog
      const overlay = document.createElement('div')
      overlay.className = 'order-overlay'
      
      const dialog = document.createElement('div')
      dialog.className = 'order-dialog'
      
      // Vehicle options with capacity info
      const vehicleOptions = vehicles.map(vehicle => {
        const vehicleConfig = getVehicleConfig(vehicle.model)
        const capacity = vehicleConfig ? vehicleConfig.capacity : 100
        return `<option value="${vehicle.id}" data-capacity="${capacity}">${vehicle.model} (${vehicle.plate}) - Capacity: ${capacity}</option>`
      }).join('')
      
      // Item selection with quantity inputs
      const itemInputs = allowedItems.map(item => {
        return `
          <div class="order-item">
            <div class="order-item-header">
              <label class="order-item-label">
                <input type="checkbox" class="order-item-checkbox" data-item="${item}">
                <span>${item}</span>
              </label>
            </div>
            <div class="order-item-controls">
              <label>Quantity:</label>
              <input type="number" class="order-item-quantity" data-item="${item}" min="1" max="100" value="1" disabled>
            </div>
          </div>
        `
      }).join('')
      
      dialog.innerHTML = `
        <div class="order-header card-header">
          <h3><i class="icon fas fa-truck-loading"></i>Order Stock</h3>
          <button class="close-order-btn" id="closeOrderBtn">
            <i class="fas fa-times"></i>
          </button>
        </div>
        <div class="order-body">
          <div class="order-section">
            <h4><i class="icon fas fa-car"></i>Select Vehicle</h4>
            <select id="orderVehicleSelect" class="order-vehicle-select">
              <option value="">Choose a vehicle...</option>
              ${vehicleOptions}
            </select>
            <div class="capacity-info" id="capacityInfo" style="display: none;">
              <span class="capacity-text">Capacity: <span id="vehicleCapacity">0</span> units</span>
            </div>
          </div>
          
          <div class="order-section">
            <h4><i class="icon fas fa-boxes"></i>Select Items to Order</h4>
            <div class="order-items-container">
              ${itemInputs}
            </div>
          </div>
          
          <div class="order-section">
            <h4><i class="icon fas fa-receipt"></i>Order Summary</h4>
            <div class="order-summary" id="orderSummary" style="display: none;">
              <div class="summary-row">
                <span>Total Units:</span>
                <span id="totalUnits">0</span>
              </div>
              <div class="summary-row">
                <span>Vehicle Capacity:</span>
                <span id="summaryCapacity">0</span>
              </div>
              <div class="summary-row">
                <span>Estimated Cost:</span>
                <span id="estimatedCost">$0</span>
              </div>
            </div>
          </div>
        </div>
        <div class="order-actions">
          <button class="order-btn order-cancel" id="cancelOrderBtn"><i class="fas fa-times"></i> Cancel</button>
          <button class="order-btn order-confirm" id="confirmOrderBtn" disabled><i class="fas fa-play"></i> Start Delivery Mission</button>
        </div>
      `
      
      overlay.appendChild(dialog)
      const container = document.querySelector('.ui-container') || document.body
      container.appendChild(overlay)
      
      // Add event listeners for the order dialog
      addOrderDialogListeners(overlay, vehicles)
    })
    .catch(error => {
      console.error('Error fetching vehicles for order:', error)
      showConfirmDialog('Error', 'Failed to load vehicles. Please try again.', () => {})
    })
  }
  
  function getVehicleConfig(model) {
    // This should match Config.FleetVehicles - for now using defaults
    const vehicleConfigs = {
      'speedo': { capacity: 150 },
      'rumpo': { capacity: 180 },
      'bison': { capacity: 200 },
      'mule': { capacity: 500 },
      'phantom': { capacity: 1000 }
    }
    return vehicleConfigs[model] || { capacity: 100 }
  }
  
  function addOrderDialogListeners(overlay, vehicles) {
    const vehicleSelect = overlay.querySelector('#orderVehicleSelect')
    const capacityInfo = overlay.querySelector('#capacityInfo')
    const vehicleCapacitySpan = overlay.querySelector('#vehicleCapacity')
    const orderSummary = overlay.querySelector('#orderSummary')
    const totalUnitsSpan = overlay.querySelector('#totalUnits')
    const summaryCapacitySpan = overlay.querySelector('#summaryCapacity')
    const estimatedCostSpan = overlay.querySelector('#estimatedCost')
    const confirmBtn = overlay.querySelector('#confirmOrderBtn')
    const closeBtn = overlay.querySelector('#closeOrderBtn')
    const cancelBtn = overlay.querySelector('#cancelOrderBtn')
    
    let selectedCapacity = 0
    
    // Vehicle selection
    vehicleSelect.addEventListener('change', function() {
      const selectedOption = this.options[this.selectedIndex]
      if (selectedOption.value) {
        selectedCapacity = parseInt(selectedOption.getAttribute('data-capacity')) || 100
        vehicleCapacitySpan.textContent = selectedCapacity
        capacityInfo.style.display = 'block'
        summaryCapacitySpan.textContent = selectedCapacity
      } else {
        selectedCapacity = 0
        capacityInfo.style.display = 'none'
      }
      updateOrderSummary()
    })
    
    // Item checkbox and quantity changes
    overlay.querySelectorAll('.order-item-checkbox').forEach(checkbox => {
      checkbox.addEventListener('change', function() {
        const item = this.getAttribute('data-item')
        const quantityInput = overlay.querySelector(`.order-item-quantity[data-item="${item}"]`)
        
        if (quantityInput && quantityInput.classList.contains('order-item-quantity')) {
          quantityInput.disabled = !this.checked
          
          if (!this.checked) {
            quantityInput.value = 1
          } else if (quantityInput.value == 0 || quantityInput.value == '') {
            quantityInput.value = 1
          }
        }
        updateOrderSummary()
      })
    })
    
    overlay.querySelectorAll('.order-item-quantity').forEach(input => {
      input.addEventListener('input', updateOrderSummary)
    })
    
    // Initial update of order summary
    updateOrderSummary()
    
    function updateOrderSummary() {
      const checkedItems = overlay.querySelectorAll('.order-item-checkbox:checked')
      let totalUnits = 0
      let totalCost = 0
      
      checkedItems.forEach(checkbox => {
        const item = checkbox.getAttribute('data-item')
        const quantityInput = overlay.querySelector(`.order-item-quantity[data-item="${item}"]`)
        const quantity = parseInt(quantityInput.value) || 0
        totalUnits += quantity
        
        // Calculate cost (simplified pricing)
        const itemPrice = getItemPrice(item)
        totalCost += quantity * itemPrice
      })
      
      // Update the summary display elements
      if (totalUnitsSpan) {
        totalUnitsSpan.textContent = totalUnits
      }
      
      if (estimatedCostSpan) {
        estimatedCostSpan.textContent = '$' + totalCost
      }
      
      if (summaryCapacitySpan) {
        summaryCapacitySpan.textContent = selectedCapacity > 0 ? selectedCapacity : 'Not Selected'
      }
      
      // Show/hide summary and enable/disable confirm button
      if (totalUnits > 0) {
        if (orderSummary) {
          orderSummary.style.display = 'block'
        }
        
        // Check if order fits in vehicle and vehicle is selected
        if (selectedCapacity > 0 && totalUnits <= selectedCapacity && vehicleSelect.value) {
          confirmBtn.disabled = false
          confirmBtn.textContent = 'Start Delivery Mission'
          confirmBtn.className = 'order-btn order-confirm'
        } else if (selectedCapacity > 0 && totalUnits > selectedCapacity) {
          confirmBtn.disabled = true
          confirmBtn.textContent = 'Exceeds Vehicle Capacity'
          confirmBtn.className = 'order-btn order-confirm disabled'
        } else {
          confirmBtn.disabled = true
          confirmBtn.textContent = 'Select Vehicle'
          confirmBtn.className = 'order-btn order-confirm disabled'
        }
      } else {
        if (orderSummary) {
          orderSummary.style.display = 'none'
        }
        confirmBtn.disabled = true
        confirmBtn.textContent = 'Start Delivery Mission'
        confirmBtn.className = 'order-btn order-confirm disabled'
      }
    }
    
    function getItemPrice(item) {
      const prices = {
        water: 3,
        bread: 4,
        sandwich: 8,
        phone: 25
      }
      return prices[item] || 5
    }
    
    // Close dialog events
    const cleanup = () => {
      document.body.removeChild(overlay)
    }
    
    closeBtn.addEventListener('click', cleanup)
    cancelBtn.addEventListener('click', cleanup)
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) cleanup()
    })
    
    // Confirm order
    confirmBtn.addEventListener('click', () => {
      if (confirmBtn.disabled) return
      
      const selectedVehicleId = vehicleSelect.value
      const checkedItems = overlay.querySelectorAll('.order-item-checkbox:checked')
      const orderItems = []
      
      checkedItems.forEach(checkbox => {
        const item = checkbox.getAttribute('data-item')
        const quantityInput = overlay.querySelector(`.order-item-quantity[data-item="${item}"]`)
        const quantity = parseInt(quantityInput.value) || 0
        if (quantity > 0) {
          orderItems.push({ item, quantity })
        }
      })
      
      if (orderItems.length > 0 && selectedVehicleId) {
        // Start the delivery mission
        startDeliveryMission(selectedVehicleId, orderItems)
        cleanup()
      }
    })
  }
  
  function startDeliveryMission(vehicleId, orderItems) {
    console.log('Starting delivery mission with:', { vehicleId, orderItems, storeId: state.storeId })
    const resourceName = GetParentResourceName()
    fetch(`https://${resourceName}/startStockOrder`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        storeId: state.storeId, 
        vehicleId: parseInt(vehicleId),
        orderItems: orderItems
      })
    })
    .then(response => {
      console.log('Stock order response:', response)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log('Stock order success:', data)
    })
    .catch(error => {
      console.error('Stock order error:', error)
    })
    .then(() => {
      console.log('Stock order mission started')
    })
    .catch(error => {
      console.error('Error starting stock order:', error)
    })
  }

  function showTabs() {
    const all = Array.from(document.querySelectorAll('.nav-item'))
    const allowed = new Set(state.allowedTabs || [])
    all.forEach(btn => {
      const tab = btn.getAttribute('data-tab')
      if (!allowed.size || allowed.has(tab)) btn.style.display = 'flex'
      else btn.style.display = 'none'
    })
  }

  function setActiveTab(tabName) {
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.classList.remove('active')
      if (btn.getAttribute('data-tab') === tabName) {
        btn.classList.add('active')
      }
    })
  }

  function render() {
    console.log('Rendering tab:', currentTab)
    console.log('State:', state)
    
    if (currentTab === 'about') {
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-circle-info"></i>About This Store</h3>
          </div>
          <div class="about-container">
            <div class="about-hero">
              <div class="about-hero-text">
                <h2>Run a Successful Shop</h2>
                <p>Everything you need to know to manage stock, employees, banking, and fleet operations.</p>
              </div>
            </div>

            <div class="about-grid">
              <div class="about-card">
                <div class="about-card-header">
                  <i class="fas fa-boxes"></i>
                  <h4>Stock & Ordering</h4>
                </div>
                <div class="about-card-body">
                  <ul class="about-list">
                    <li>Use the <strong>Stock</strong> tab to add or edit item price and stock.</li>
                    <li>Click <strong>Order Stock</strong> to start a delivery mission using a fleet vehicle.</li>
                    <li>Choose items and quantities; keep within vehicle capacity to enable the mission.</li>
                    <li>Complete the pickup and deliver back to your store <em>delivery point</em> to receive items.</li>
                  </ul>
                </div>
              </div>

              <div class="about-card">
                <div class="about-card-header">
                  <i class="fas fa-users"></i>
                  <h4>Employees & Roles</h4>
                </div>
                <div class="about-card-body">
                  <ul class="about-list">
                    <li>Manage staff in the <strong>Employees</strong> tab.</li>
                    <li>Roles: <strong>Employee</strong> (1), <strong>Manager</strong> (2), <strong>Owner</strong> (3).</li>
                    <li>Only Managers and Owners can edit stock, banking, and fleet.</li>
                    <li>Owners always have full permissions.</li>
                  </ul>
                </div>
              </div>

              <div class="about-card">
                <div class="about-card-header">
                  <i class="fas fa-university"></i>
                  <h4>Banking & Revenue</h4>
                </div>
                <div class="about-card-body">
                  <ul class="about-list">
                    <li>View store balance and transactions in <strong>Banking</strong>.</li>
                    <li>Customer purchases add revenue to the store account automatically.</li>
                    <li>Deposit/withdraw funds with your preferred payment type.</li>
                  </ul>
                </div>
              </div>

              <div class="about-card">
                <div class="about-card-header">
                  <i class="fas fa-truck"></i>
                  <h4>Fleet & Deliveries</h4>
                </div>
                <div class="about-card-body">
                  <ul class="about-list">
                    <li>Buy vehicles in the <strong>Fleet</strong> tab for delivery missions.</li>
                    <li>Vehicles must be <strong>stored</strong> to be available for ordering runs.</li>
                    <li>Heavier trucks carry more stock but cost more.</li>
                  </ul>
                </div>
              </div>
            </div>

            <div class="about-faq">
              <div class="about-faq-header">
                <i class="fas fa-question-circle"></i>
                <h4>FAQ</h4>
              </div>
              <div class="about-faq-body">
                <div class="faq-item">
                  <div class="faq-q">How do unowned store prices work?</div>
                  <div class="faq-a">Unowned shops use config-driven prices per location. Owners can override price and stock once purchased.</div>
                </div>
                <div class="faq-item">
                  <div class="faq-q">Why can't I order stock?</div>
                  <div class="faq-a">You need a stored fleet vehicle and selected items within its capacity.</div>
                </div>
                <div class="faq-item">
                  <div class="faq-q">Who can edit stock?</div>
                  <div class="faq-a">Managers and Owners. Employees have limited access.</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      `
    }

    if (currentTab === 'shop') {
      const rawItems = state.items || []
      const cart = state.cart || []
      const searchTerm = (state.shopSearchTerm || '').toLowerCase()
      const sortMode = state.shopSort || 'name-asc'
      
      // Filter
      let items = rawItems.filter(i => {
        if (!searchTerm) return true
        const label = (i.label || i.item || '').toLowerCase()
        return label.includes(searchTerm)
      })
      // Sort
      const sorters = {
        'name-asc': (a, b) => (a.label || a.item || '').localeCompare(b.label || b.item || ''),
        'name-desc': (a, b) => (b.label || b.item || '').localeCompare(a.label || a.item || ''),
        'price-asc': (a, b) => (a.price || 0) - (b.price || 0),
        'price-desc': (a, b) => (b.price || 0) - (a.price || 0),
      }
      items.sort(sorters[sortMode] || sorters['name-asc'])
      
      console.log('Items:', items)
      console.log('Cart:', cart)
      
      // Check if this is a shop-only view (no other tabs allowed)
      const isShopOnly = state.allowedTabs && state.allowedTabs.length === 1 && state.allowedTabs[0] === 'shop'
      console.log('Is shop only in render:', isShopOnly, 'CurrentTab:', currentTab, 'AllowedTabs:', state.allowedTabs)
      
      // Build item cards
        const itemCards = items.length > 0 ? items.map(i => `
          <div class="item-card">
            <div class="item-header">
              <h4 class="item-name">${i.label}</h4>
              <div class="item-price">$${i.price}</div>
            </div>
            <div class="item-details">
              <div class="item-stock">Stock: ${i.stock}</div>
            </div>
            <button class="add-to-cart-btn" data-act="add" data-item="${i.item}" data-price="${i.price}" data-label="${i.label}" data-stock="${i.stock}" ${i.stock <= 0 ? 'disabled' : ''}>
              <i class="fas fa-plus"></i> ${i.stock <= 0 ? 'Out of Stock' : 'Add to Cart'}
            </button>
          </div>
        `).join('') : '<div class="no-items">No items available in this store</div>'
        
      // Build cart
        const cartItems = cart.map(c => `
          <div class="cart-item">
            <div class="cart-item-info">
              <div class="cart-item-name">${c.label || c.item}</div>
              <div class="cart-item-price">$${c.price} x ${c.qty}</div>
            </div>
            <div class="cart-item-controls">
              <button class="cart-btn-minus" data-item="${c.item}">-</button>
              <span class="cart-qty">${c.qty}</span>
              <button class="cart-btn-plus" data-item="${c.item}">+</button>
            </div>
            <div class="cart-item-total">$${(c.price * c.qty).toFixed(2)}</div>
          </div>
        `).join('')
        
        const cartTotal = cart.reduce((sum, c) => sum + (c.price * c.qty), 0).toFixed(2)
        
      // Unified layout with toolbar
        content.innerHTML = `
          <div class="shop-layout">
            <div class="items-section">
              <div class="section-header">
                <h3><i class="icon fas fa-shopping-basket"></i>Available Items</h3>
              </div>
            <div class="shop-toolbar">
              <div class="search-group">
                <i class="fas fa-search"></i>
                <input id="shop-search" class="search-input" type="text" placeholder="Search items..." value="${state.shopSearchTerm || ''}" />
              </div>
              <select id="shop-sort" class="sort-select">
                <option value="name-asc" ${sortMode === 'name-asc' ? 'selected' : ''}>Name (A–Z)</option>
                <option value="name-desc" ${sortMode === 'name-desc' ? 'selected' : ''}>Name (Z–A)</option>
                <option value="price-asc" ${sortMode === 'price-asc' ? 'selected' : ''}>Price (Low–High)</option>
                <option value="price-desc" ${sortMode === 'price-desc' ? 'selected' : ''}>Price (High–Low)</option>
              </select>
            </div>
              <div class="items-grid">
                ${itemCards}
              </div>
            </div>
            <div class="cart-section">
              <div class="section-header">
                <h3><i class="icon fas fa-shopping-cart"></i>Shopping Cart</h3>
              </div>
              <div class="cart-items">
                ${cartItems || '<div class="empty-cart">Cart is empty</div>'}
              </div>
              <div class="cart-footer">
                <div class="cart-total">Total: $${cartTotal}</div>
              <div class="checkout-actions">
                <button id="checkout-cash" class="checkout-btn" ${cart.length === 0 ? 'disabled' : ''}>
                  <i class="fas fa-money-bill"></i> Cash
                </button>
                <button id="checkout-card" class="checkout-btn" ${cart.length === 0 ? 'disabled' : ''}>
                  <i class="fas fa-credit-card"></i> Card
                </button>
              </div>
              </div>
            </div>
          </div>
        `
      const doCheckout = (payType) => {
        const payload = { cart: state.cart || [], payType }
        if (state.storeId) payload.storeId = state.storeId
        if (state.locationCode) payload.locationCode = state.locationCode
        fetch(`https://${GetParentResourceName()}/checkout`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
      }
      content.querySelector('#checkout-cash')?.addEventListener('click', () => doCheckout('cash'))
      content.querySelector('#checkout-card')?.addEventListener('click', () => doCheckout('bank'))

      // Search and sort events
      const searchEl = content.querySelector('#shop-search')
      if (searchEl) {
        searchEl.addEventListener('input', (e) => {
          state.shopSearchTerm = e.target.value || ''
          render()
        })
      }
      const sortEl = content.querySelector('#shop-sort')
      if (sortEl) {
        sortEl.addEventListener('change', (e) => {
          state.shopSort = e.target.value
          render()
        })
      }
      content.querySelectorAll('button[data-act="add"]').forEach(btn => {
        btn.addEventListener('click', () => {
          const item = btn.getAttribute('data-item')
          const price = Number(btn.getAttribute('data-price'))
          const label = btn.getAttribute('data-label') || item
          const maxStock = Number(btn.getAttribute('data-stock') || 0)
          
          state.cart = state.cart || []
          const found = state.cart.find(c => c.item === item)
          const currentCartQty = found ? found.qty : 0
          
          // Check if we can add more of this item
          if (currentCartQty >= maxStock) {
            console.warn('Cannot add more items - not enough stock')
            // Could show a notification here if needed
            return
          }
          
          if (found) {
            found.qty += 1
          } else {
            state.cart.push({ item, label, price, qty: 1 })
          }
          // Re-render to update cart display
          render()
        })
      })
      
      // Add event listeners for cart quantity controls
      content.querySelectorAll('.cart-btn-plus').forEach(btn => {
        btn.addEventListener('click', () => {
          const item = btn.getAttribute('data-item')
          const cartItem = state.cart.find(c => c.item === item)
          if (cartItem) {
            // Find the original item to check stock limit
            const originalItem = items.find(i => i.item === item)
            const maxStock = originalItem ? originalItem.stock : 0
            
            if (cartItem.qty >= maxStock) {
              console.warn('Cannot increase quantity - not enough stock')
              return
            }
            
            cartItem.qty += 1
            render()
          }
        })
      })
      
      content.querySelectorAll('.cart-btn-minus').forEach(btn => {
        btn.addEventListener('click', () => {
          const item = btn.getAttribute('data-item')
          const cartItem = state.cart.find(c => c.item === item)
          if (cartItem) {
            cartItem.qty -= 1
            if (cartItem.qty <= 0) {
              // Remove item from cart if quantity reaches 0
              state.cart = state.cart.filter(c => c.item !== item)
            }
            render()
          }
        })
      })
    }
    if (currentTab === 'purchase') {
      const code = state.locationCode
      const label = code || 'Store'
      // Fetch full location info (label + price) and render a full-page card
      fetch(`https://${GetParentResourceName()}/getLocationInfo`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ locationCode: state.locationCode })
      }).then(r => r.json()).then(info => {
        const name = (info && info.label) || label
        const price = (info && typeof info.price === 'number') ? info.price : 0
        const titleEl = document.querySelector('.company-name')
        if (titleEl) titleEl.textContent = name
        content.innerHTML = `
          <div class="purchase-hero">
            <div class="purchase-header">
              <div class="purchase-title">
                <i class="fas fa-store"></i>
                <h2>${name}</h2>
              </div>
              <div class="purchase-price">
                <span class="price-label">Price</span>
                <span class="price-value">$${price.toLocaleString()}</span>
              </div>
            </div>
            <div class="purchase-body">
              <div class="purchase-feature-grid">
                <div class="feature-item"><i class="fas fa-box"></i><span>Manage stock & prices</span></div>
                <div class="feature-item"><i class="fas fa-users"></i><span>Hire employees</span></div>
                <div class="feature-item"><i class="fas fa-university"></i><span>Store banking</span></div>
                <div class="feature-item"><i class="fas fa-truck"></i><span>Fleet & deliveries</span></div>
              </div>
              <button id="purchase" class="purchase-btn"><i class="fas fa-credit-card"></i> Buy Store</button>
            </div>
          </div>
        `
        document.getElementById('purchase').addEventListener('click', () => {
          fetch(`https://${GetParentResourceName()}/purchase`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ locationCode: state.locationCode }) })
        })
      }).catch(() => {
        content.innerHTML = `<div class="panel"><div class="card-header"><h3><i class="icon fas fa-credit-card"></i>Purchase Store</h3></div><div>Location: ${label}</div><button id="purchase">Purchase</button></div>`
        document.getElementById('purchase')?.addEventListener('click', () => {
          fetch(`https://${GetParentResourceName()}/purchase`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ locationCode: state.locationCode }) })
        })
      })
    }
    if (currentTab === 'stock') {
      const items = state.items || []
      const allowed = state.allowedItems || []
      console.log('Stock tab - allowedItems:', allowed)
      console.log('Stock tab - state:', state)
      
      // Capacity summary (if provided by server via state)
      const usedCapacity = state.usedCapacity || items.reduce((sum, it) => sum + (it.stock || 0), 0)
      const maxCapacity = state.maxCapacity || null

      // Create a comprehensive list of all allowed items (existing + available to add)
      const allItems = [...allowed].map(itemCode => {
        const existing = items.find(i => i.item === itemCode)
        return existing || {
          item: itemCode,
          label: itemCode, // Default label
          price: 0,
          stock: 0,
          isNew: true
        }
      })
      
      const itemList = allItems.map(item => {
        const isEditing = state.editingItem === item.item
        
        if (isEditing) {
          // Edit mode - show input fields
          return `
            <div class="stock-item editing" data-item="${item.item}">
              <div class="stock-item-header">
                <input type="text" class="edit-label" value="${item.label}" placeholder="Item Label">
                <div class="stock-item-actions">
                  <button class="save-btn" data-item="${item.item}">
                    <i class="fas fa-check"></i> Save
                  </button>
                  <button class="cancel-btn" data-item="${item.item}">
                    <i class="fas fa-times"></i> Cancel
                  </button>
                </div>
              </div>
              <div class="stock-item-details">
                <div class="stock-field">
                  <label>Price:</label>
                  <input type="number" class="edit-price" value="${item.price}" placeholder="0.00" step="0.01" min="0">
                </div>
              </div>
            </div>
          `
        } else {
          // View mode - show item info
          return `
            <div class="stock-item" data-item="${item.item}">
              <div class="stock-item-header">
                <div class="stock-item-info">
                  <h4 class="stock-item-name">${item.label}</h4>
                  <span class="stock-item-code">${item.item}</span>
                </div>
                <div class="stock-item-actions">
                  <button class="edit-btn" data-item="${item.item}">
                    <i class="fas fa-edit"></i> Edit
                  </button>
                </div>
              </div>
              <div class="stock-item-details">
                <div class="stock-detail">
                  <span class="stock-label">Price:</span>
                  <span class="stock-value price">$${item.price}</span>
                </div>
                <div class="stock-detail">
                  <span class="stock-label">Stock:</span>
                  <span class="stock-value stock ${item.stock <= 0 ? 'out-of-stock' : ''}">${item.stock}</span>
                </div>
                ${item.isNew ? '<div class="new-item-badge">New Item</div>' : ''}
              </div>
            </div>
          `
        }
      }).join('')
      
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-boxes"></i>Stock Management</h3>
            <div class="header-actions">
              <div class="stock-summary">
                <span>${items.length} items configured</span>
                ${maxCapacity ? `<span style="margin-left:12px;">Capacity: <strong>${usedCapacity}</strong> / <strong>${maxCapacity}</strong></span>` : ''}
              </div>
              <button class="order-stock-btn" id="orderStockBtn">
                <i class="fas fa-truck-loading"></i> Order Stock
              </button>
            </div>
          </div>
          <div class="stock-items-container">
            ${itemList || '<div class="no-items">No items available for this store</div>'}
          </div>
        </div>
      `
      
      // Add event listeners for edit/save/cancel/delete buttons
      addStockEventListeners()
    }
    if (currentTab === 'manage') {
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-briefcase"></i>Store Management</h3>
            <button class="add-employee-btn" id="renameStoreBtn">
              <i class="fas fa-pen"></i> Rename Store
            </button>
          </div>
          <div class="manage-content">
            <div class="manage-card">
              <div class="manage-card-header">
                <i class="fas fa-store"></i>
                <h4>Store Information</h4>
              </div>
              <div class="manage-card-body">
                <div class="info-item">
                  <span class="info-label">Store ID:</span>
                  <span class="info-value">${state.storeId}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Owner:</span>
                  <span class="info-value">You</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Status:</span>
                  <span class="info-value status-active">Active</span>
                </div>
              </div>
            </div>
            <div class="manage-card">
              <div class="manage-card-header">
                <i class="fas fa-chart-line"></i>
                <h4>Quick Stats</h4>
              </div>
              <div class="manage-card-body">
                <div class="stats-grid">
                  <div class="stat-item">
                    <div class="stat-number">${(state.items || []).length}</div>
                    <div class="stat-label">Items</div>
                  </div>
                  <div class="stat-item">
                    <div class="stat-number">${(state.employees || []).length}</div>
                    <div class="stat-label">Employees</div>
                  </div>
                  <div class="stat-item">
                    <div class="stat-number">${(state.vehicles || []).length}</div>
                    <div class="stat-label">Vehicles</div>
                  </div>
                </div>
                <div class="manage-actions">
                  <div class="action-card">
                    <div class="action-header">
                      <i class="fas fa-dollar-sign"></i>
                      <h4>Sell Store</h4>
              </div>
                    <div class="action-body">
                      <p>Return this store to unowned status for a 75% refund.</p>
                      <button class="sell-store-btn" id="sellStoreBtn">
                        <i class="fas fa-dollar-sign"></i> Sell Store
                      </button>
                    </div>
                  </div>
                  <div class="action-card">
                    <div class="action-header">
                      <i class="fas fa-share"></i>
                      <h4>Transfer Store</h4>
                    </div>
                    <div class="action-body">
                      <div class="transfer-row">
                        <select id="transferPlayersSelect">
                          <option value="">Select player to transfer...</option>
                        </select>
                        <button class="refresh-nearby-btn small" id="refreshTransferNearby" title="Refresh">
                          <i class="fas fa-sync"></i>
                        </button>
                        <button class="add-employee-btn" id="transferStoreBtn">
                          <i class="fas fa-share"></i> Transfer Store
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      `

      // Rename store button handler
      document.getElementById('renameStoreBtn')?.addEventListener('click', () => {
        // Fetch current name for placeholder
        fetch(`https://${GetParentResourceName()}/getStoreInfo`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId })
        }).then(r => r.json()).then(info => {
          const currentName = (info && info.name) || 'Store'
          // Build themed prompt inside iPad
          const overlay = document.createElement('div')
          overlay.className = 'confirm-overlay'
          const dialog = document.createElement('div')
          dialog.className = 'confirm-dialog'
          dialog.innerHTML = `
            <div class="confirm-header"><h3>Rename Store</h3></div>
            <div class="confirm-body">
              <p>Enter a new store name and choose a map icon:</p>
              <input id="newStoreNameInput" type="text" value="${currentName}" style="width:100%;margin-top:10px;background: var(--input-bg); border: 1px solid var(--border-color); border-radius: 6px; padding: 10px; color: var(--text-primary);">
              <div style="margin-top:12px;">
                <label style="display:block;margin-bottom:6px;color:rgba(255,255,255,.85);font-size:.9rem;">Blip Sprite (ID)</label>
                <input id="newBlipSpriteInput" type="number" placeholder="e.g. 52" min="1" style="width:100%;background: var(--input-bg); border: 1px solid var(--border-color); border-radius: 6px; padding: 10px; color: var(--text-primary);">
              </div>
            </div>
            <div class="confirm-actions">
              <button class="confirm-btn confirm-cancel">Cancel</button>
              <button class="confirm-btn confirm-yes">Save</button>
            </div>
          `
          overlay.appendChild(dialog)
          const container = document.querySelector('.ui-container') || document.body
          container.appendChild(overlay)

          const cleanup = () => { if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay) }
          dialog.querySelector('.confirm-cancel').addEventListener('click', cleanup)
          overlay.addEventListener('click', (e) => { if (e.target === overlay) cleanup() })
          dialog.querySelector('.confirm-yes').addEventListener('click', () => {
            const newName = dialog.querySelector('#newStoreNameInput').value.trim()
            if (!newName) return
            fetch(`https://${GetParentResourceName()}/updateStoreName`, {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ storeId: state.storeId, newName })
            }).then(() => {
              // Update top-left title immediately
              const title = document.querySelector('.company-name')
              if (title) title.textContent = newName
              // Save blip sprite (optional)
              const spriteVal = dialog.querySelector('#newBlipSpriteInput').value
              if (spriteVal && spriteVal !== '') {
                const payload = { storeId: state.storeId, spriteId: parseInt(spriteVal) }
                fetch(`https://${GetParentResourceName()}/updateStoreBlip`, {
                  method: 'POST', headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(payload)
                }).finally(() => cleanup())
              } else { cleanup() }
            })
          })
        })
      })

      // Sell store
      document.getElementById('sellStoreBtn')?.addEventListener('click', () => {
        showConfirmDialog('Sell Store', 'Are you sure you want to sell this store? You will receive 75% of the purchase price. This cannot be undone.', () => {
          fetch(`https://${GetParentResourceName()}/sellStore`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ storeId: state.storeId })
          })
        })
      })

      // Transfer store helpers
      const refreshTransfer = () => {
        const sel = document.getElementById('transferPlayersSelect')
        if (!sel) return
        sel.innerHTML = '<option value="">Scanning...</option>'
        fetch(`https://${GetParentResourceName()}/getNearbyPlayers`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ radius: 8.0 })
        }).then(r => r.json()).then(data => {
          const players = (data && data.players) || []
          if (players.length === 0) {
            sel.innerHTML = '<option value="">No players nearby</option>'
            return
          }
          const opts = ['<option value="">Select player to transfer...</option>'].concat(players.map(p => {
            const name = (p.name && p.name.trim().length > 0) ? p.name : (p.citizenid || ('ID ' + p.serverId))
            return `<option value="${p.citizenid}">${name}</option>`
          }))
          sel.innerHTML = opts.join('')
        }).catch(() => {
          sel.innerHTML = '<option value="">Failed to load players</option>'
        })
      }
      document.getElementById('refreshTransferNearby')?.addEventListener('click', (e) => { e.preventDefault(); refreshTransfer() })
      refreshTransfer()
      document.getElementById('transferStoreBtn')?.addEventListener('click', () => {
        const sel = document.getElementById('transferPlayersSelect')
        const cid = sel && sel.value
        if (!cid) return
        showConfirmDialog('Transfer Store', 'Transfer ownership to the selected player?', () => {
          fetch(`https://${GetParentResourceName()}/transferStore`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ storeId: state.storeId, citizenid: cid })
          })
        })
      })
    }
    if (currentTab === 'employees') {
      // Employees content is handled by renderEmployees() function
      console.log('employees tab - should be handled by renderEmployees()')
    }
    if (currentTab === 'banking') {
      // Banking content is handled by renderBanking() function  
      console.log('banking tab - should be handled by renderBanking()')
    }
    if (currentTab === 'fleet') {
      // Fleet content is handled by renderFleet() function
      console.log('fleet tab - should be handled by renderFleet()')
    }
  }

  function addStockEventListeners() {
    // Order Stock button
    const orderStockBtn = document.getElementById('orderStockBtn')
    if (orderStockBtn) {
      orderStockBtn.addEventListener('click', () => {
        currentTab = 'orderStock'
        renderOrderStock()
      })
    }
    
    // Edit button - enter edit mode
    content.querySelectorAll('.edit-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const item = btn.getAttribute('data-item')
        state.editingItem = item
        render()
      })
    })
    
    // Save button - save changes (price/label only, keep stock unchanged)
    content.querySelectorAll('.save-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const item = btn.getAttribute('data-item')
        const itemContainer = content.querySelector(`[data-item="${item}"]`)
        
        const label = itemContainer.querySelector('.edit-label').value
        const price = Number(itemContainer.querySelector('.edit-price').value || 0)
        // Keep existing stock value to avoid changing quantities from UI
        const existing = (state.items || []).find(i => i.item === item)
        const stock = existing ? Number(existing.stock || 0) : 0
        
        if (!label.trim()) {
          console.warn('Item label cannot be empty')
          return
        }
        
        // Send update to server
        const body = {
          storeId: state.storeId,
          item: item,
          label: label,
          price: price,
          stock: stock
        }
        
        fetch(`https://${GetParentResourceName()}/upsertStockAllowed`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body)
        })
        .then(() => {
          // Exit edit mode and refresh stock data
          state.editingItem = null
          refreshStockData()
        })
        .catch(error => {
          console.error('Error saving stock:', error)
        })
      })
    })
    
    // Cancel button - exit edit mode
    content.querySelectorAll('.cancel-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        state.editingItem = null
        render()
      })
    })
    
    // Delete button removed: items are no longer deleted from this UI
  }
  
  function refreshStockData() {
    if (state.storeId && currentTab === 'stock') {
      fetch(`https://${GetParentResourceName()}/getStock`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ storeId: state.storeId })
      })
      .then(response => response.json())
      .then(data => {
        state.items = data.items || []
        state.allowedItems = data.allowedItems || []
        render()
        })
        .catch(error => {
        console.error('Error refreshing stock data:', error)
        render()
      })
    }
  }

  function refreshManageStats() {
    if (!state.storeId) return
    const resource = GetParentResourceName()
    Promise.all([
      fetch(`https://${resource}/getStock`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ storeId: state.storeId }) }).then(r => r.json()).catch(() => ({})),
      fetch(`https://${resource}/getEmployees`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ storeId: state.storeId }) }).then(r => r.json()).catch(() => ({})),
      fetch(`https://${resource}/getFleetVehicles`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ storeId: state.storeId }) }).then(r => r.json()).catch(() => ({}))
    ]).then(([stock, employees, fleet]) => {
      state.items = stock.items || state.items || []
      state.allowedItems = stock.allowedItems || state.allowedItems || []
      state.employees = employees.employees || state.employees || []
      state.vehicles = fleet.vehicles || state.vehicles || []
      if (currentTab === 'manage') render()
    })
  }

  function renderOrderStock() {
    const allowedItems = state.allowedItems || []
    content.innerHTML = `
      <div class="panel">
        <div class="card-header">
          <h3><i class="icon fas fa-truck-loading"></i>Order Stock</h3>
          <div class="header-actions">
            <button class="order-back-btn" id="backToStock">
              <i class="fas fa-arrow-left"></i> Back to Stock
            </button>
          </div>
        </div>
        <div class="loading">Loading vehicles...</div>
      </div>
    `

    const resourceName = GetParentResourceName()
    fetch(`https://${resourceName}/getFleetVehicles`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ storeId: state.storeId })
      })
    .then(r => r.json())
      .then(data => {
      const vehicles = (data.vehicles || []).filter(v => v.stored)

      // Back handler
      const attachBack = () => {
        const backBtn = document.getElementById('backToStock')
        if (backBtn) backBtn.addEventListener('click', () => {
          currentTab = 'stock'
          // Re-fetch stock so we have latest allowedItems/items
          if (state.storeId) {
            fetch(`https://${GetParentResourceName()}/getStock`, {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ storeId: state.storeId })
            }).then(resp => resp.json()).then(s => {
              state.items = s.items || []
              state.allowedItems = s.allowedItems || []
        render()
            }).catch(() => render())
          } else {
            render()
          }
        })
      }

      if (vehicles.length === 0) {
        content.innerHTML = `
          <div class="panel">
            <div class="card-header">
              <h3><i class="icon fas fa-truck-loading"></i>Order Stock</h3>
              <div class="header-actions">
                <button class="order-back-btn" id="backToStock">
                  <i class="fas fa-arrow-left"></i> Back to Stock
                </button>
              </div>
            </div>
            <div class="order-empty">
              <div class="empty-title">No Vehicles Available</div>
              <div class="empty-subtitle">Purchase and store a vehicle in your fleet to order stock.</div>
            </div>
          </div>
        `
        attachBack()
        return
      }

      const vehicleOptions = vehicles.map(vehicle => {
        const cfg = getVehicleConfig(vehicle.model)
        const cap = cfg ? cfg.capacity : 100
        return `<option value="${vehicle.id}" data-capacity="${cap}">${vehicle.model} (${vehicle.plate}) - Capacity: ${cap}</option>`
      }).join('')

      // Fetch per-store wholesale prices before rendering
      fetch(`https://${GetParentResourceName()}/getStockOrderPrices`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ storeId: state.storeId })
      }).then(r => r.json()).then(priceData => {
        state.orderPrices = (priceData && priceData.override) || {}
        const itemInputs = allowedItems.map(item => {
          const unit = state.orderPrices[item] != null ? Number(state.orderPrices[item]) : 0
          return `
            <div class="order-item">
              <div class="order-item-header">
                <label class="order-item-label">
                  <input type="checkbox" class="order-item-checkbox" data-item="${item}">
                  <span>${item}</span>
                </label>
                <span class="unit-price">$${unit}</span>
              </div>
              <div class="order-item-controls">
                <label>Quantity:</label>
                <input type="number" class="order-item-quantity" data-item="${item}" min="1" max="100" value="1" disabled>
              </div>
            </div>
          `
        }).join('')

        content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-truck-loading"></i>Order Stock</h3>
            <div class="header-actions">
              <button class="order-back-btn" id="backToStock">
                <i class="fas fa-arrow-left"></i> Back to Stock
              </button>
            </div>
          </div>
          <div class="order-body">
            <div class="order-section">
              <h4><i class="icon fas fa-car"></i>Select Vehicle</h4>
              <select id="orderVehicleSelect" class="order-vehicle-select">
                <option value="">Choose a vehicle...</option>
                ${vehicleOptions}
              </select>
              <div class="capacity-info" id="capacityInfo" style="display: none;">
                <span class="capacity-text">Capacity: <span id="vehicleCapacity">0</span> units</span>
              </div>
            </div>

            <div class="order-section">
              <h4><i class="icon fas fa-boxes"></i>Select Items to Order</h4>
              <div class="order-items-container">
                ${itemInputs || '<div class="no-items">No allowed items configured for this store</div>'}
              </div>
            </div>

            <div class="order-section">
              <h4><i class="icon fas fa-receipt"></i>Order Summary</h4>
              <div class="order-summary" id="orderSummary" style="display: none;">
                <div class="summary-row">
                  <span>Total Units:</span>
                  <span id="totalUnits">0</span>
                </div>
                <div class="summary-row">
                  <span>Vehicle Capacity:</span>
                  <span id="summaryCapacity">0</span>
                </div>
                <div class="summary-row">
                  <span>Estimated Cost:</span>
                  <span id="estimatedCost">$0</span>
                </div>
              </div>
            </div>
          </div>
          <div class="order-actions">
            <button class="order-btn order-cancel" id="backToStock2"><i class="fas fa-times"></i> Cancel</button>
            <button class="order-btn order-confirm" id="confirmOrderBtn" disabled><i class="fas fa-play"></i> Start Delivery Mission</button>
          </div>
        </div>
      `

        attachBack()
        const back2 = document.getElementById('backToStock2')
        if (back2) back2.addEventListener('click', () => document.getElementById('backToStock')?.click())

        addOrderPageListeners(vehicles)
      })
    })
    .catch(err => {
      console.error('Error fetching vehicles for order:', err)
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-truck-loading"></i>Order Stock</h3>
            <div class="header-actions">
              <button class="order-back-btn" id="backToStock">
                <i class="fas fa-arrow-left"></i> Back to Stock
              </button>
            </div>
          </div>
          <div class="error-message">Failed to load vehicles. Please try again.</div>
        </div>
      `
      const backBtn = document.getElementById('backToStock')
      if (backBtn) backBtn.addEventListener('click', () => { currentTab = 'stock'; render() })
    })
  }

  function addOrderPageListeners(vehicles) {
    const vehicleSelect = content.querySelector('#orderVehicleSelect')
    const capacityInfo = content.querySelector('#capacityInfo')
    const vehicleCapacitySpan = content.querySelector('#vehicleCapacity')
    const orderSummary = content.querySelector('#orderSummary')
    const totalUnitsSpan = content.querySelector('#totalUnits')
    const summaryCapacitySpan = content.querySelector('#summaryCapacity')
    const estimatedCostSpan = content.querySelector('#estimatedCost')
    const confirmBtn = content.querySelector('#confirmOrderBtn')

    let selectedCapacity = 0

    if (vehicleSelect) {
      vehicleSelect.addEventListener('change', function() {
        const selectedOption = this.options[this.selectedIndex]
        if (selectedOption && selectedOption.value) {
          selectedCapacity = parseInt(selectedOption.getAttribute('data-capacity')) || 100
          if (vehicleCapacitySpan) vehicleCapacitySpan.textContent = selectedCapacity
          if (capacityInfo) capacityInfo.style.display = 'block'
          if (summaryCapacitySpan) summaryCapacitySpan.textContent = selectedCapacity
        } else {
          selectedCapacity = 0
          if (capacityInfo) capacityInfo.style.display = 'none'
        }
        updateOrderSummary()
      })
    }

    content.querySelectorAll('.order-item-checkbox').forEach(checkbox => {
      checkbox.addEventListener('change', function() {
        const item = this.getAttribute('data-item')
        const quantityInput = content.querySelector(`.order-item-quantity[data-item="${item}"]`)
        if (quantityInput && quantityInput.classList.contains('order-item-quantity')) {
          quantityInput.disabled = !this.checked
          if (!this.checked) {
            quantityInput.value = 1
          } else if (quantityInput.value == 0 || quantityInput.value == '') {
            quantityInput.value = 1
          }
        }
        updateOrderSummary()
      })
    })

    content.querySelectorAll('.order-item-quantity').forEach(input => {
      input.addEventListener('input', updateOrderSummary)
    })

    updateOrderSummary()

    function updateOrderSummary() {
      const checkedItems = content.querySelectorAll('.order-item-checkbox:checked')
      let totalUnits = 0
      let totalCost = 0

      checkedItems.forEach(checkbox => {
        const item = checkbox.getAttribute('data-item')
        const quantityInput = content.querySelector(`.order-item-quantity[data-item="${item}"]`)
        const quantity = parseInt(quantityInput.value) || 0
        totalUnits += quantity
        const itemPrice = getItemPrice(item)
        totalCost += quantity * itemPrice
      })

      if (totalUnitsSpan) totalUnitsSpan.textContent = totalUnits
      if (estimatedCostSpan) estimatedCostSpan.textContent = '$' + totalCost
      if (summaryCapacitySpan) summaryCapacitySpan.textContent = selectedCapacity > 0 ? selectedCapacity : 'Not Selected'

      if (totalUnits > 0) {
        if (orderSummary) orderSummary.style.display = 'block'
        if (selectedCapacity > 0 && totalUnits <= selectedCapacity && vehicleSelect && vehicleSelect.value) {
          if (confirmBtn) {
            confirmBtn.disabled = false
            confirmBtn.textContent = 'Start Delivery Mission'
            confirmBtn.className = 'order-btn order-confirm'
          }
        } else if (selectedCapacity > 0 && totalUnits > selectedCapacity) {
          if (confirmBtn) {
            confirmBtn.disabled = true
            confirmBtn.textContent = 'Exceeds Vehicle Capacity'
            confirmBtn.className = 'order-btn order-confirm disabled'
          }
        } else {
          if (confirmBtn) {
            confirmBtn.disabled = true
            confirmBtn.textContent = 'Select Vehicle'
            confirmBtn.className = 'order-btn order-confirm disabled'
          }
        }
      } else {
        if (orderSummary) orderSummary.style.display = 'none'
        if (confirmBtn) {
          confirmBtn.disabled = true
          confirmBtn.textContent = 'Start Delivery Mission'
          confirmBtn.className = 'order-btn order-confirm disabled'
        }
      }
    }

    function getItemPrice(item) {
      const prices = state.orderPrices || {}
      const val = prices[item]
      return (typeof val === 'number') ? val : Number(val) || 0
    }

    // Load per-store wholesale prices and refresh summary
    fetch(`https://${GetParentResourceName()}/getStockOrderPrices`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ storeId: state.storeId })
    }).then(r => r.json()).then(data => {
      state.orderPrices = (data && data.override) || {}
      // Recompute once prices are loaded
      try { updateOrderSummary() } catch (e) {}
    }).catch(() => {})

    if (confirmBtn) {
      confirmBtn.addEventListener('click', () => {
        if (confirmBtn.disabled) return
        const selectedVehicleId = vehicleSelect ? vehicleSelect.value : null
        const checkedItems = content.querySelectorAll('.order-item-checkbox:checked')
        const orderItems = []
        checkedItems.forEach(checkbox => {
          const item = checkbox.getAttribute('data-item')
          const quantityInput = content.querySelector(`.order-item-quantity[data-item="${item}"]`)
          const quantity = parseInt(quantityInput.value) || 0
          if (quantity > 0) orderItems.push({ item, quantity })
        })
        if (orderItems.length > 0 && selectedVehicleId) {
          startDeliveryMission(parseInt(selectedVehicleId), orderItems)
          // Return to stock after starting
          currentTab = 'stock'
        render()
        }
      })
    }
  }

  function renderEmployees() {
    console.log('renderEmployees() called, storeId:', state.storeId)
    
    // Show loading state immediately
    content.innerHTML = `
      <div class="panel">
        <div class="card-header">
          <h3><i class="icon fas fa-users"></i>Employee Management</h3>
        </div>
        <div class="loading">Loading employees...</div>
      </div>
    `
    
    // Fetch employee data
    const resourceName = GetParentResourceName()
    console.log('Resource name for employees fetch:', resourceName)
    fetch(`https://${resourceName}/getEmployees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ storeId: state.storeId })
    })
    .then(response => {
      console.log('Employee fetch response status:', response.status)
      console.log('Employee fetch response ok:', response.ok)
      console.log('Employee fetch response headers:', response.headers)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log('Employee data received:', data)
      const employees = data.employees || []
      state.employees = employees
      
      const employeeList = employees.map(emp => {
        const permissionName = emp.permission === 3 ? 'Owner' : emp.permission === 2 ? 'Manager' : 'Employee'
        const statusClass = emp.online ? 'online' : 'offline'
        
        return `
          <div class="employee-item">
            <div class="employee-header">
              <div class="employee-info">
                <h4 class="employee-name">${emp.name}</h4>
                <span class="employee-id">${emp.citizenid}</span>
              </div>
              <div class="employee-status ${statusClass}">
                <i class="fas fa-circle"></i>
                ${emp.online ? 'Online' : 'Offline'}
              </div>
            </div>
            <div class="employee-details">
              <div class="employee-permission">
                <span class="permission-label">Role:</span>
                <select class="permission-select" data-citizenid="${emp.citizenid}" ${emp.permission === 3 ? 'disabled' : ''}>
                  <option value="1" ${emp.permission === 1 ? 'selected' : ''}>Employee</option>
                  <option value="2" ${emp.permission === 2 ? 'selected' : ''}>Manager</option>
                  <option value="3" ${emp.permission === 3 ? 'selected' : ''}>Owner</option>
                </select>
              </div>
              <div class="employee-stats">
                <span class="permission-label">Orders Completed:</span>
                <span class="stat-value">${emp.orders_completed || 0}</span>
                <button class="refresh-nearby-btn small" data-act="reset-stat" data-citizenid="${emp.citizenid}" title="Reset this employee's count">
                  <i class="fas fa-undo"></i>
                </button>
              </div>
              <div class="employee-actions">
                ${emp.permission !== 3 ? `<button class="fire-btn" data-citizenid="${emp.citizenid}">
                  <i class="fas fa-user-times"></i> Fire
                </button>` : ''}
              </div>
            </div>
          </div>
        `
      }).join('')
      
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-users"></i>Employee Management</h3>
            <div class="header-actions">
            <button class="add-employee-btn" id="addEmployeeBtn">
              <i class="fas fa-user-plus"></i> Hire Employee
            </button>
            </div>
          </div>
          <div class="employees-container">
            ${employeeList || '<div class="no-employees">No employees hired yet</div>'}
          </div>
          <div class="hire-form hidden" id="hireForm">
            <div class="hire-form-header">
              <h4>Hire New Employee</h4>
              <button class="close-form-btn" id="closeHireForm">
                <i class="fas fa-times"></i>
              </button>
            </div>
            <div class="hire-form-body">
              <div class="form-field">
                <label>Nearby Player:</label>
                <div class="nearby-row">
                  <select id="nearbyPlayersSelect">
                    <option value="">Select a player...</option>
                  </select>
                  <button class="refresh-nearby-btn small" id="refreshNearbyInForm" title="Refresh">
                    <i class="fas fa-sync"></i>
                  </button>
                </div>
              </div>
              <div class="form-field">
                <label>Role:</label>
                <select id="newEmployeePermission">
                  <option value="1">Employee</option>
                  <option value="2">Manager</option>
                </select>
              </div>
              <div class="form-actions">
                <button class="hire-confirm-btn" id="confirmHire">
                  <i class="fas fa-check"></i> Hire Employee
                </button>
              </div>
            </div>
          </div>
        </div>
      `
      
      addEmployeeEventListeners()
      document.getElementById('resetStatsBtn')?.addEventListener('click', () => {
        showConfirmDialog('Reset Employee Stats', 'Reset all employee order counts to 0?', () => {
          fetch(`https://${GetParentResourceName()}/resetEmployeeStats`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ storeId: state.storeId })
          }).then(() => renderEmployees())
        })
      })
      // Per-employee reset
      content.querySelectorAll('[data-act="reset-stat"]').forEach(btn => {
        btn.addEventListener('click', () => {
          const cid = btn.getAttribute('data-citizenid')
          if (!cid) return
          showConfirmDialog('Reset Employee Stat', 'Reset this employee\'s order count?', () => {
            fetch(`https://${GetParentResourceName()}/resetEmployeeStat`, {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ storeId: state.storeId, citizenid: cid })
            }).then(() => renderEmployees())
          })
        })
      })
    })
    .catch(error => {
      console.error('Error fetching employees:', error)
      console.log('Setting error content for employees')
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-users"></i>Employee Management</h3>
          </div>
          <div class="error-message">Error loading employees: ${error.message}</div>
        </div>
      `
    })
  }

  function renderFleet() {
    console.log('renderFleet() called, storeId:', state.storeId)
    
    // Show loading state immediately
    content.innerHTML = `
      <div class="panel">
        <div class="card-header">
          <h3><i class="icon fas fa-truck"></i>Fleet Management</h3>
        </div>
        <div class="loading">Loading fleet...</div>
      </div>
    `
    
    // Fetch fleet data
    const resourceName = GetParentResourceName()
    console.log('Resource name for fleet fetch:', resourceName)
    fetch(`https://${resourceName}/getFleetVehicles`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ storeId: state.storeId })
    })
    .then(response => {
      console.log('Fleet fetch response status:', response.status)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log('Fleet data received:', data)
      const vehicles = data.vehicles || []
      const availableVehicles = data.availableVehicles || []
      state.vehicles = vehicles
      
      // Render owned vehicles
      const vehicleList = vehicles.map(vehicle => {
        const statusClass = vehicle.stored ? 'stored' : 'active'
        const statusText = vehicle.stored ? 'Stored' : 'Active'
        
        return `
          <div class="vehicle-item">
            <div class="vehicle-header">
              <div class="vehicle-info">
                <h4 class="vehicle-model">${vehicle.model}</h4>
                <span class="vehicle-plate">${vehicle.plate}</span>
              </div>
              <div class="vehicle-status ${statusClass}">
                <i class="fas ${vehicle.stored ? 'fa-warehouse' : 'fa-road'}"></i>
                ${statusText}
              </div>
            </div>
            <div class="vehicle-actions">
              ${vehicle.stored ? `
                <button class="sell-btn" data-vehicle-id="${vehicle.id}">
                  <i class="fas fa-dollar-sign"></i> Sell
                </button>
              ` : ''}
            </div>
          </div>
        `
      }).join('')
      
      // Render available vehicles for purchase
      const availableList = availableVehicles.map(vehicle => {
        return `
          <div class="available-vehicle-item">
            <div class="available-vehicle-info">
              <h4 class="available-vehicle-name">${vehicle.label}</h4>
              <p class="available-vehicle-description">${vehicle.description}</p>
              <div class="available-vehicle-specs">
                <span class="spec-item">
                  <i class="fas fa-tag"></i>
                  <strong>$${vehicle.price.toLocaleString()}</strong>
                </span>
                <span class="spec-item">
                  <i class="fas fa-box"></i>
                  Capacity: ${vehicle.capacity}
                </span>
                <span class="spec-item category-${vehicle.category}">
                  <i class="fas fa-truck"></i>
                  ${vehicle.category}
                </span>
              </div>
            </div>
            <div class="available-vehicle-actions">
              <button class="purchase-btn" data-vehicle-model="${vehicle.model}" data-vehicle-price="${vehicle.price}">
                <i class="fas fa-shopping-cart"></i>
                Purchase
              </button>
            </div>
          </div>
        `
      }).join('')
      
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-truck"></i>Fleet Management</h3>
          </div>
          
          <div class="fleet-sections">
            <!-- Owned Vehicles Section -->
            <div class="fleet-section">
              <div class="section-header">
                <h4><i class="fas fa-car"></i> Your Fleet (${vehicles.length})</h4>
              </div>
              <div class="vehicles-container">
                ${vehicleList || '<div class="no-vehicles">No vehicles owned yet</div>'}
              </div>
            </div>
            
            <!-- Purchase Vehicles Section -->
            <div class="fleet-section">
              <div class="section-header">
                <h4><i class="fas fa-shopping-cart"></i> Purchase Vehicles</h4>
              </div>
              <div class="available-vehicles-container">
                ${availableList}
              </div>
            </div>
          </div>
        </div>
      `
      
      addFleetEventListeners()
    })
    .catch(error => {
      console.error('Error fetching fleet:', error)
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-truck"></i>Fleet Management</h3>
          </div>
          <div class="error-message">Error loading fleet: ${error.message}</div>
        </div>
      `
    })
  }

  function addFleetEventListeners() {
    // Sell vehicle
    content.querySelectorAll('.sell-btn').forEach(btn => {
      btn.addEventListener('click', function() {
        const vehicleId = this.getAttribute('data-vehicle-id')
        if (vehicleId) {
          showConfirmDialog(
            'Sell Vehicle',
            'Are you sure you want to sell this vehicle? You will receive 50% of the original price.',
            () => {
              const resourceName = GetParentResourceName()
              fetch(`https://${resourceName}/sellVehicle`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ vehicleId: parseInt(vehicleId) })
              })
              .then(() => {
                // Refresh fleet display
                setTimeout(() => renderFleet(), 500)
              })
            }
          )
        }
      })
    })
    
    // Purchase vehicle
    content.querySelectorAll('.purchase-btn').forEach(btn => {
      btn.addEventListener('click', function() {
        const vehicleModel = this.getAttribute('data-vehicle-model')
        const vehiclePrice = parseInt(this.getAttribute('data-vehicle-price'))
        const vehicleLabel = this.closest('.available-vehicle-item').querySelector('.available-vehicle-name').textContent
        
        if (vehicleModel) {
          showConfirmDialog(
            'Purchase Vehicle',
            `Are you sure you want to purchase ${vehicleLabel} for $${vehiclePrice.toLocaleString()}?`,
            () => {
              const resourceName = GetParentResourceName()
              fetch(`https://${resourceName}/purchaseVehicle`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                  storeId: state.storeId, 
                  vehicleModel: vehicleModel 
                })
              })
              .then(() => {
                // Refresh fleet display
                setTimeout(() => renderFleet(), 500)
              })
            }
          )
        }
      })
    })
  }

  function renderBanking() {
    console.log('renderBanking() called, storeId:', state.storeId)
    
    // Show loading state immediately
    content.innerHTML = `
      <div class="panel">
        <div class="card-header">
          <h3><i class="icon fas fa-university"></i>Store Banking</h3>
        </div>
        <div class="loading">Loading banking information...</div>
      </div>
    `
    
    // Fetch banking data
    const resourceName = GetParentResourceName()
    console.log('Resource name for banking fetch:', resourceName)
    fetch(`https://${resourceName}/getBankingInfo`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ storeId: state.storeId })
    })
    .then(response => {
      console.log('Banking fetch response status:', response.status)
      console.log('Banking fetch response ok:', response.ok)
      console.log('Banking fetch response headers:', response.headers)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log('Banking data received:', data)
      const balance = data.balance || 0
      const transactions = data.transactions || []
      
      const transactionList = transactions.map(tx => {
        const payload = typeof tx.payload === 'string' ? JSON.parse(tx.payload) : tx.payload
        const type = payload?.type || 'unknown'
        let description = payload?.description || 'Transaction'
        if (type === 'stock_order' && Array.isArray(payload?.items)) {
          const actor = payload?.actorName || ''
          const parts = payload.items.map(it => `${it.quantity}x ${it.item}`).join(', ')
          description = actor ? `Stock order by ${actor}: ${parts}` : `Stock order: ${parts}`
        }
        const amount = tx.amount
        const date = new Date(tx.created_at).toLocaleDateString()
        const isPositive = amount > 0
        
        return `
          <div class="transaction-item ${isPositive ? 'positive' : 'negative'}">
            <div class="transaction-info">
              <div class="transaction-description">${description}</div>
              <div class="transaction-date">${date}</div>
            </div>
            <div class="transaction-amount ${isPositive ? 'positive' : 'negative'}">
              ${isPositive ? '+' : ''}$${Math.abs(amount)}
            </div>
          </div>
        `
      }).join('')
      
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-university"></i>Store Banking</h3>
          </div>
          <div class="banking-content">
            <div class="balance-card">
              <div class="balance-header">
                <i class="fas fa-wallet"></i>
                <h4>Store Balance</h4>
              </div>
              <div class="balance-amount">$${balance}</div>
            </div>
            <div class="banking-actions">
              <div class="action-card">
                <div class="action-header">
                  <i class="fas fa-plus"></i>
                  <h4>Deposit Money</h4>
                </div>
                <div class="action-body">
                  <input type="number" id="depositAmount" placeholder="Amount to deposit" min="1">
                  <div class="payment-type-selector">
                    <label>From:</label>
                    <select id="depositPayType">
                      <option value="cash">Cash</option>
                      <option value="bank">Bank Account</option>
                    </select>
                  </div>
                  <button class="action-btn deposit-btn" id="depositBtn">
                    <i class="fas fa-arrow-down"></i> Deposit
                  </button>
                </div>
              </div>
              <div class="action-card">
                <div class="action-header">
                  <i class="fas fa-minus"></i>
                  <h4>Withdraw Money</h4>
                </div>
                <div class="action-body">
                  <input type="number" id="withdrawAmount" placeholder="Amount to withdraw" min="1" max="${balance}">
                  <div class="payment-type-selector">
                    <label>To:</label>
                    <select id="withdrawPayType">
                      <option value="cash">Cash</option>
                      <option value="bank">Bank Account</option>
                    </select>
                  </div>
                  <button class="action-btn withdraw-btn" id="withdrawBtn">
                    <i class="fas fa-arrow-up"></i> Withdraw
                  </button>
                </div>
              </div>
            </div>
            <div class="transactions-section">
              <div class="transactions-header">
                <h4>Recent Transactions</h4>
              </div>
              <div class="transactions-list">
                ${transactionList || '<div class="no-transactions">No transactions yet</div>'}
              </div>
            </div>
          </div>
        </div>
      `
      
      // Set default payment types based on config
      const defaultPayment = 'bank' // This should match Config.DefaultPayment
      document.getElementById('depositPayType').value = defaultPayment
      document.getElementById('withdrawPayType').value = defaultPayment
      
      addBankingEventListeners()
    })
    .catch(error => {
      console.error('Error fetching banking info:', error)
      console.log('Setting error content for banking')
      content.innerHTML = `
        <div class="panel">
          <div class="card-header">
            <h3><i class="icon fas fa-university"></i>Store Banking</h3>
          </div>
          <div class="error-message">Error loading banking information: ${error.message}</div>
        </div>
      `
    })
  }

  function renderUpgrades() {
    console.log('renderUpgrades() called, storeId:', state.storeId)
    content.innerHTML = `
      <div class="panel">
        <div class="card-header">
          <h3><i class="icon fas fa-arrow-up"></i>Upgrades</h3>
        </div>
        <div class="loading">Loading upgrades...</div>
      </div>
    `

    const ensureCapacity = () => new Promise((resolve) => {
      if (!state.storeId) return resolve()
      fetch(`https://${GetParentResourceName()}/getStock`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ storeId: state.storeId })
      }).then(r => r.json()).then(data => {
        state.items = data.items || []
        state.allowedItems = data.allowedItems || []
        state.usedCapacity = data.usedCapacity
        state.maxCapacity = data.maxCapacity
        resolve()
      }).catch(() => resolve())
    })

    ensureCapacity().then(() => {
    const used = state.usedCapacity || 0
    const max = state.maxCapacity || 0

      fetch(`https://${GetParentResourceName()}/getPurchasedUpgrades`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ storeId: state.storeId })
      })
      .then(r => r.json())
      .then(p => {
        state.purchasedUpgrades = p.purchased || {}
        return fetch(`https://${GetParentResourceName()}/getCapacityUpgrades`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}'
        })
    })
    .then(r => r.json())
    .then(data => {
      const upgrades = data.upgrades || []
        const purchased = state.purchasedUpgrades || {}
      const tiers = upgrades.map((u, idx) => {
          const tierIndex = idx + 1
          const isPurchased = !!(purchased[tierIndex] || purchased[String(tierIndex)])
          const btn = isPurchased ? `<button class=\"upgrade-btn disabled\" disabled><i class=\"fas fa-check\"></i> Purchased</button>` : `<button class=\"upgrade-btn\" data-tier=\"${tierIndex}\"><i class=\"fas fa-arrow-up\"></i> Purchase</button>`
        return `
            <div class=\"upgrade-item\">\n              <div class=\"upgrade-info\">\n                <h4>+${u.increase} Capacity</h4>\n                <div class=\"upgrade-meta\">\n                  <span class=\"meta-chip\"><i class=\"fas fa-box\"></i> Capacity</span>\n                  <span class=\"meta-chip price\"><i class=\"fas fa-dollar-sign\"></i> $${(u.price||0).toLocaleString()}</span>\n                </div>\n              </div>\n              <div class=\"upgrade-actions\">\n                ${btn}\n              </div>\n            </div>
        `
      }).join('')

      content.innerHTML = `
          <div class=\"panel\">\n            <div class=\"card-header\">\n              <h3><i class=\"icon fas fa-arrow-up\"></i>Upgrades</h3>\n            </div>\n            <div class=\"upgrades-summary\">\n              <div class=\"summary-card\">\n                <div class=\"summary-title\">Current Capacity</div>\n                <div class=\"summary-value\">${used} / ${max}</div>\n              </div>\n            </div>\n            <div class=\"upgrades-list\">\n              ${tiers}\n            </div>\n          </div>
      `

        content.querySelectorAll('.upgrade-btn:not(.disabled)').forEach(btn => {
        btn.addEventListener('click', () => {
          const tier = parseInt(btn.getAttribute('data-tier'))
          showConfirmDialog('Purchase Upgrade', 'Confirm purchasing this capacity upgrade?', () => {
            fetch(`https://${GetParentResourceName()}/purchaseCapacityUpgrade`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ storeId: state.storeId, tier })
            }).then(() => {
                // Optimistically mark this tier as purchased in UI/state
                state.purchasedUpgrades = state.purchasedUpgrades || {}
                state.purchasedUpgrades[tier] = true
                if (btn) {
                  btn.disabled = true
                  btn.classList.add('disabled')
                  btn.innerHTML = '<i class="fas fa-check"></i> Purchased'
                }
                Promise.all([
                  fetch(`https://${GetParentResourceName()}/getStock`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ storeId: state.storeId }) }).then(r => r.json()),
                  fetch(`https://${GetParentResourceName()}/getPurchasedUpgrades`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ storeId: state.storeId }) }).then(r => r.json())
                ]).then(([stock, purchasedRes]) => {
                  state.items = stock.items || []
                  state.allowedItems = stock.allowedItems || []
                  state.usedCapacity = stock.usedCapacity
                  state.maxCapacity = stock.maxCapacity
                  state.purchasedUpgrades = purchasedRes.purchased || {}
                renderUpgrades()
                })
              })
            })
          })
        })
      })
    })
  }

  function addEmployeeEventListeners() {
    // Add employee button
    const addEmployeeBtn = document.getElementById('addEmployeeBtn')
    if (addEmployeeBtn) {
      addEmployeeBtn.addEventListener('click', () => {
        document.getElementById('hireForm').classList.remove('hidden')
        // Load nearby players immediately
        refreshNearbyPlayers()
      })
    }
    
    // Close hire form
    const closeHireForm = document.getElementById('closeHireForm')
    if (closeHireForm) {
      closeHireForm.addEventListener('click', () => {
        document.getElementById('hireForm').classList.add('hidden')
      })
    }
    
    // Confirm hire
    const confirmHire = document.getElementById('confirmHire')
    if (confirmHire) {
      confirmHire.addEventListener('click', () => {
        const citizenid = document.getElementById('nearbyPlayersSelect').value
        const permission = parseInt(document.getElementById('newEmployeePermission').value)
        
        if (!citizenid) {
          console.warn('Please select a nearby player')
          return
        }
        
        fetch(`https://${GetParentResourceName()}/hireEmployee`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId, citizenid, permission })
        })
        .then(() => {
          document.getElementById('hireForm').classList.add('hidden')
          renderEmployees() // Refresh the list
        })
      })
    }
    
    // Permission change
    content.querySelectorAll('.permission-select').forEach(select => {
      select.addEventListener('change', (e) => {
        const citizenid = e.target.getAttribute('data-citizenid')
        const permission = parseInt(e.target.value)
        
        fetch(`https://${GetParentResourceName()}/updateEmployeePermission`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId, citizenid, permission })
        })
        .then(() => {
          renderEmployees() // Refresh the list
        })
      })
    })
    
    // Fire employee
    content.querySelectorAll('.fire-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const citizenid = btn.getAttribute('data-citizenid')
        
        fetch(`https://${GetParentResourceName()}/fireEmployee`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId, citizenid })
        })
        .then(() => {
          renderEmployees() // Refresh the list
        })
      })
    })

    // Refresh nearby buttons (header + form)
    const refreshHeader = document.getElementById('refreshNearby')
    if (refreshHeader) refreshHeader.addEventListener('click', () => {
      // If form is open, refresh there; else briefly open a toast? For now, just refresh if open
      if (!document.getElementById('hireForm').classList.contains('hidden')) {
        refreshNearbyPlayers()
      }
    })
    const refreshInForm = document.getElementById('refreshNearbyInForm')
    if (refreshInForm) refreshInForm.addEventListener('click', (e) => {
      e.preventDefault()
      refreshNearbyPlayers()
    })

    function refreshNearbyPlayers() {
      const select = document.getElementById('nearbyPlayersSelect')
      if (!select) return
      // Clear and set loading
      select.innerHTML = '<option value="">Scanning...</option>'
      fetch(`https://${GetParentResourceName()}/getNearbyPlayers`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ radius: 8.0 })
      }).then(r => r.json()).then(data => {
        const players = (data && data.players) || []
        if (players.length === 0) {
          select.innerHTML = '<option value="">No players nearby</option>'
          return
        }
        const opts = ['<option value="">Select a player...</option>'].concat(players.map(p => {
          const name = (p.name && p.name.trim().length > 0) ? p.name : (p.citizenid || ('ID ' + p.serverId))
          return `<option value="${p.citizenid}">${name}</option>`
        }))
        select.innerHTML = opts.join('')
      }).catch(err => {
        console.error('Failed to fetch nearby players:', err)
        select.innerHTML = '<option value="">Failed to load nearby players</option>'
      })
    }
  }

  function addBankingEventListeners() {
    // Deposit money
    const depositBtn = document.getElementById('depositBtn')
    if (depositBtn) {
      depositBtn.addEventListener('click', () => {
        const amount = parseInt(document.getElementById('depositAmount').value)
        const payType = document.getElementById('depositPayType').value
        
        if (!amount || amount <= 0) {
          console.warn('Please enter a valid amount')
          return
        }
        
        fetch(`https://${GetParentResourceName()}/depositMoney`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId, amount, payType })
        })
        .then(() => {
          document.getElementById('depositAmount').value = ''
          // Add a small delay to ensure server processing is complete
          setTimeout(() => renderBanking(), 250) // Refresh the banking info
        })
        .catch(error => {
          console.error('Error depositing money:', error)
        })
      })
    }
    
    // Withdraw money
    const withdrawBtn = document.getElementById('withdrawBtn')
    if (withdrawBtn) {
      withdrawBtn.addEventListener('click', () => {
        const amount = parseInt(document.getElementById('withdrawAmount').value)
        const payType = document.getElementById('withdrawPayType').value
        
        if (!amount || amount <= 0) {
          console.warn('Please enter a valid amount')
          return
        }
        
        fetch(`https://${GetParentResourceName()}/withdrawMoney`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId, amount, payType })
        })
        .then(() => {
          document.getElementById('withdrawAmount').value = ''
          // Add a small delay to ensure server processing is complete
          setTimeout(() => renderBanking(), 250) // Refresh the banking info
        })
        .catch(error => {
          console.error('Error withdrawing money:', error)
        })
      })
    }
  }

  function open(tab, data) {
    currentTab = tab || 'shop'
    state = data || {}
    app.classList.remove('hidden')
    
    // Debug logging
    console.log('Opening UI with data:', data)
    console.log('Allowed tabs:', data.allowedTabs)
    
    // Check if this is a shop-only view (customer shopping, not management)
    const isShopOnly = data.allowedTabs && data.allowedTabs.length === 1 && data.allowedTabs[0] === 'shop'
    const isPurchaseOnly = data.allowedTabs && data.allowedTabs.length === 1 && data.allowedTabs[0] === 'purchase'
    console.log('Is shop only:', isShopOnly, 'Is purchase only:', isPurchaseOnly, 'Tab:', tab, 'AllowedTabs:', data.allowedTabs)
    
    const sidebar = document.querySelector('.sidebar')
    const contentArea = document.querySelector('.content-area')
    
    if (isShopOnly || isPurchaseOnly) {
      // Hide sidebar for shop-only view
      console.log('Using single-page layout')
      sidebar.style.display = 'none'
      contentArea.style.marginLeft = '0'
      contentArea.style.width = '100%'
    } else {
      // Show sidebar for management views
      console.log('Using management layout')
      sidebar.style.display = 'flex'
      contentArea.style.marginLeft = ''
      contentArea.style.width = ''
      setActiveTab(currentTab)
      showTabs()
    }
    
    // Update top-left title to the current store's name
    const nameEl = document.querySelector('.company-name')
    if (nameEl) {
      if (state.storeId) {
        fetch(`https://${GetParentResourceName()}/getStoreInfo`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId })
        }).then(r => r.json()).then(info => {
          if (info && info.name) {
            state.storeName = info.name
            nameEl.textContent = info.name
          }
        }).catch(() => {})
      } else if (state.locationCode) {
        // For unowned stores, get label from config via server
        fetch(`https://${GetParentResourceName()}/getLocationInfo`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ locationCode: state.locationCode })
        }).then(r => r.json()).then(info => {
          if (info && info.label) nameEl.textContent = info.label
        }).catch(() => { nameEl.textContent = state.locationCode || nameEl.textContent })
      }
    }

    // Preload manage stats if landing on manage
    if (currentTab === 'manage') {
      render()
      refreshManageStats()
    } else {
    render()
    }
  }

  function close() {
    app.classList.add('hidden')
    state = {}
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' })
  }

  window.addEventListener('message', (e) => {
    const msg = e.data || {}
    if (msg.action === 'open') return open(msg.tab, msg.data)
    if (msg.action === 'close') return close()
  })

  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', () => {
      const newTab = btn.getAttribute('data-tab')
      currentTab = newTab
      setActiveTab(currentTab)
      
      // Some tabs need to fetch fresh data when clicked
      if (newTab === 'stock' && state.storeId) {
        // Fetch stock data including allowedItems
        fetch(`https://${GetParentResourceName()}/getStock`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ storeId: state.storeId })
        })
        .then(response => response.json())
        .then(data => {
          console.log('Fetched stock data:', data)
          state.items = data.items || []
          state.allowedItems = data.allowedItems || []
          render()
        })
        .catch(error => {
          console.error('Error fetching stock data:', error)
          render()
        })
      } else if (newTab === 'employees') {
        console.log('Switching to employees tab')
        renderEmployees()
      } else if (newTab === 'banking') {
        console.log('Switching to banking tab')
        renderBanking()
      } else if (newTab === 'fleet') {
        console.log('Switching to fleet tab')
        renderFleet()
      } else if (newTab === 'upgrades') {
        console.log('Switching to upgrades tab')
        renderUpgrades()
      } else if (newTab === 'manage') {
        console.log('Switching to manage tab')
        render()
        refreshManageStats()
      } else if (newTab === 'about') {
        console.log('Switching to about tab')
        render()
      } else {
        render()
      }
    })
  })

  closeBtn.addEventListener('click', () => close())
})()


