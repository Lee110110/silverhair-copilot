const app = getApp()

Page({
  data: {
    sosEvent: null,
    status: 'idle' // idle | alerting | accepted
  },

  onLoad(options) {
    // Listen for SOS events via WebSocket or polling
    this.checkSosStatus(options.elderlyId)
  },

  checkSosStatus(elderlyId) {
    wx.request({
      url: `${app.globalData.baseUrl}/sos/history?limit=1`,
      header: { 'Authorization': `Bearer ${app.globalData.token}` },
      success: (resp) => {
        if (resp.statusCode === 200 && resp.data.length > 0) {
          const latest = resp.data[0]
          if (latest.status === 'alerting') {
            this.setData({ sosEvent: latest, status: 'alerting' })
          }
        }
      }
    })
  },

  onAcceptSos() {
    if (!this.data.sosEvent) return
    wx.request({
      url: `${app.globalData.baseUrl}/sos/${this.data.sosEvent.id}/accept`,
      method: 'PUT',
      header: { 'Authorization': `Bearer ${app.globalData.token}` },
      success: (resp) => {
        if (resp.statusCode === 200) {
          this.setData({ status: 'accepted' })
          // Navigate to co-screen
          wx.navigateTo({
            url: `/pages/coscreen/coscreen?elderlyId=${this.data.sosEvent.elderly_id}`
          })
        }
      }
    })
  },

  onCallElderly() {
    // Make a phone call to the elderly
    wx.makePhoneCall({ phoneNumber: '' }) // TODO: Get phone from linked data
  }
})