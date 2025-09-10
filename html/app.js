(() => {
  const app = document.getElementById('app')
  const content = document.getElementById('content')
  const closeBtn = document.getElementById('close')
  let currentTab = 'shop'
  let state = {}

  function showTabs() {
    const all = Array.from(document.querySelectorAll('.tabs button'))
    const allowed = new Set(state.allowedTabs || [])
    all.forEach(btn => {
      const tab = btn.getAttribute('data-tab')
      if (!allowed.size || allowed.has(tab)) btn.style.display = ''
      else btn.style.display = 'none'
    })
  }

  function render() {
    if (currentTab === 'shop') {
      const items = state.items || []
      const list = items.map(i => `<div class="row"><div>${i.label}</div><div>$${i.price}</div><div>Stock: ${i.stock}</div><button data-act="add" data-item="${i.item}" data-price="${i.price}">Add</button></div>`).join('')
      content.innerHTML = `<div class="panel"><h3>Shop</h3>${list}<div class="cart"><button id="checkout">Checkout</button></div></div>`
      content.querySelector('#checkout')?.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/checkout`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ storeId: state.storeId, cart: state.cart || [], payType: 'cash' }) })
      })
      content.querySelectorAll('button[data-act="add"]').forEach(btn => {
        btn.addEventListener('click', () => {
          const item = btn.getAttribute('data-item')
          const price = Number(btn.getAttribute('data-price'))
          state.cart = state.cart || []
          const found = state.cart.find(c => c.item === item)
          if (found) found.qty += 1
          else state.cart.push({ item, price, qty: 1 })
        })
      })
    }
    if (currentTab === 'purchase') {
      const code = state.locationCode
      const label = code || 'Store'
      content.innerHTML = `<div class="panel"><h3>Purchase Store</h3><div>Location: ${label}</div><button id="purchase">Purchase</button></div>`
      document.getElementById('purchase').addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/purchase`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ locationCode: state.locationCode }) })
      })
    }
    if (currentTab === 'stock') {
      const items = state.items || []
      const list = items.map(i => `<div class="row"><div>${i.label}</div><div>$${i.price}</div><div>Stock: ${i.stock}</div></div>`).join('')
      const allowed = state.allowedItems || []
      const options = allowed.map(it => `<option value="${it}">${it}</option>`).join('')
      const form = `<div class="form"><select id="item">${options}</select><input id="label" placeholder="label"/><input id="price" type="number" placeholder="price"/><input id="stock" type="number" placeholder="stock"/><button id="saveStock">Save</button></div>`
      content.innerHTML = `<div class="panel"><h3>Stock</h3>${list}${form}</div>`
      content.querySelector('#saveStock')?.addEventListener('click', () => {
        const body = {
          storeId: state.storeId,
          item: document.getElementById('item').value,
          label: document.getElementById('label').value,
          price: Number(document.getElementById('price').value || 0),
          stock: Number(document.getElementById('stock').value || 0)
        }
        fetch(`https://${GetParentResourceName()}/upsertStockAllowed`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
      })
    }
    if (currentTab === 'manage') {
      content.innerHTML = `<div class="panel"><h3>Manage</h3><div>Store ID: ${state.storeId}</div></div>`
    }
    if (currentTab === 'fleet') {
      const vehicles = state.vehicles || []
      const list = vehicles.map(v => `<div class="row"><div>${v.model}</div><div>${v.plate}</div><div>${v.stored ? 'Stored' : 'Out'}</div></div>`).join('')
      content.innerHTML = `<div class="panel"><h3>Fleet</h3>${list}</div>`
    }
  }

  function open(tab, data) {
    currentTab = tab || 'shop'
    state = data || {}
    app.classList.remove('hidden')
    showTabs(); render()
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

  document.querySelectorAll('.tabs button').forEach(btn => {
    btn.addEventListener('click', () => {
      currentTab = btn.getAttribute('data-tab')
      render()
    })
  })

  closeBtn.addEventListener('click', () => close())
})()


