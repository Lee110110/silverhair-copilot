/**
 * WebSocket connection manager for WeChat Mini Program
 */
function createWsManager(url) {
  let socketTask = null
  let listeners = []
  let reconnectTimer = null
  let heartbeatTimer = null

  function connect() {
    socketTask = wx.connectSocket({ url, success: () => {} })

    socketTask.onOpen(() => {
      console.log('[WS] Connected')
      startHeartbeat()
    })

    socketTask.onMessage((res) => {
      try {
        const msg = JSON.parse(res.data)
        listeners.forEach(cb => cb(msg))
      } catch (e) {
        console.error('[WS] Parse error:', e)
      }
    })

    socketTask.onClose(() => {
      console.log('[WS] Disconnected')
      stopHeartbeat()
      scheduleReconnect()
    })

    socketTask.onError((err) => {
      console.error('[WS] Error:', err)
    })
  }

  function send(msg) {
    if (socketTask && socketTask.readyState === 1) {
      socketTask.send({ data: JSON.stringify(msg) })
    }
  }

  function close() {
    stopHeartbeat()
    clearTimeout(reconnectTimer)
    if (socketTask) {
      socketTask.close()
      socketTask = null
    }
  }

  function onMessage(callback) {
    listeners.push(callback)
  }

  function startHeartbeat() {
    heartbeatTimer = setInterval(() => {
      send({ type: 'heartbeat.ping' })
    }, 30000)
  }

  function stopHeartbeat() {
    clearInterval(heartbeatTimer)
  }

  function scheduleReconnect() {
    clearTimeout(reconnectTimer)
    reconnectTimer = setTimeout(() => {
      console.log('[WS] Reconnecting...')
      connect()
    }, 5000)
  }

  return { connect, send, close, onMessage }
}

module.exports = { createWsManager }