const app = getApp()
const { createWsManager } = require('../../utils/ws-manager')

Page({
  data: {
    connected: false,
    tool: 'arrow', // arrow | circle | highlight | text
    color: '#FF0000',
    tools: [
      { id: 'arrow', name: '箭头', icon: '→' },
      { id: 'circle', name: '圆圈', icon: '○' },
      { id: 'highlight', name: '高亮', icon: '□' }
    ]
  },

  wsManager: null,
  sessionId: null,
  elderlyId: null,

  onLoad(options) {
    this.elderlyId = options.elderlyId
    this.initSession()
  },

  onUnload() {
    this.endSession()
  },

  initSession() {
    wx.request({
      url: `${app.globalData.baseUrl}/coscreen/session`,
      method: 'POST',
      header: { 'Authorization': `Bearer ${app.globalData.token}` },
      data: {
        elderly_id: this.elderlyId,
        child_id: app.globalData.userInfo.id
      },
      success: (resp) => {
        if (resp.statusCode === 200) {
          this.sessionId = resp.data.id
          this.connectWebSocket()
        }
      }
    })
  },

  connectWebSocket() {
    this.wsManager = createWsManager(
      `ws://localhost:8000/api/v1/ws/coscreen/${this.sessionId}?token=${app.globalData.token}`
    )

    this.wsManager.onMessage((msg) => {
      if (msg.type === 'session.ready') {
        this.setData({ connected: true })
      } else if (msg.type === 'frame.screen') {
        this.renderFrame(msg.payload.data)
      }
    })

    this.wsManager.connect()
  },

  renderFrame(base64Jpeg) {
    const query = wx.createSelectorQuery()
    query.select('#frameCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res[0]) return
        const canvas = res[0].node
        this.canvasWidth = res[0].width
        this.canvasHeight = res[0].height
        const ctx = canvas.getContext('2d')
        const img = canvas.createImage()
        img.onload = () => {
          ctx.clearRect(0, 0, canvas.width, canvas.height)
          ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
        }
        img.src = `data:image/jpeg;base64,${base64Jpeg}`
      })
  },

  onAnnotationStart(e) {
    this.annotationPoints = []
    const point = this.normalizeTouch(e.touches[0])
    this.annotationPoints.push(point)
    this.currentAnnotationId = `ann_${Date.now()}`

    this.wsManager.send({
      type: 'annotation.start',
      session_id: this.sessionId,
      payload: { id: this.currentAnnotationId, tool: this.data.tool, color: this.data.color }
    })
  },

  onAnnotationMove(e) {
    const point = this.normalizeTouch(e.touches[0])
    this.annotationPoints.push(point)

    this.wsManager.send({
      type: 'annotation.stroke',
      session_id: this.sessionId,
      payload: { points: [point], seq: this.annotationPoints.length }
    })

    this.drawAnnotationOnCanvas()
  },

  onAnnotationEnd() {
    this.wsManager.send({
      type: 'annotation.end',
      session_id: this.sessionId,
      payload: { id: this.currentAnnotationId || `ann_${Date.now()}` }
    })
  },

  normalizeTouch(touch) {
    const canvasW = this.canvasWidth || 375
    const canvasH = this.canvasHeight || 667
    return {
      x: touch.x / canvasW,
      y: touch.y / canvasH
    }
  },

  drawAnnotationOnCanvas() {
    // Draw annotation on local canvas for immediate feedback
    const query = wx.createSelectorQuery()
    query.select('#annotationCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res[0]) return
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        ctx.strokeStyle = this.data.color
        ctx.lineWidth = 3
        ctx.beginPath()
        this.annotationPoints.forEach((p, i) => {
          const x = p.x * canvas.width
          const y = p.y * canvas.height
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        })
        ctx.stroke()
      })
  },

  onToolChange(e) {
    this.setData({ tool: e.currentTarget.dataset.tool })
  },

  onClearAnnotations() {
    this.wsManager.send({
      type: 'annotation.clear_all',
      session_id: this.sessionId,
      payload: {}
    })
    // Clear local canvas
    const query = wx.createSelectorQuery()
    query.select('#annotationCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res[0]) return
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        ctx.clearRect(0, 0, canvas.width, canvas.height)
      })
  },

  endSession() {
    if (this.wsManager) {
      this.wsManager.send({
        type: 'session.end',
        session_id: this.sessionId,
        payload: { reason: 'user_quit' }
      })
      this.wsManager.close()
    }
  }
})