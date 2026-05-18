const app = getApp()

Page({
  data: {
    elderlyList: [],
    loading: true,
    hasLinked: false,
    hasSosAlert: false,
    sosEvent: null
  },

  _sosTimer: null,

  onShow() {
    this.loadData()
    this.startSosPolling()
  },

  onHide() {
    this.stopSosPolling()
  },

  onUnload() {
    this.stopSosPolling()
  },

  loadData() {
    const linked = app.globalData.linkedElderly
    this.setData({
      elderlyList: linked,
      hasLinked: linked.length > 0,
      loading: false
    })
  },

  startSosPolling() {
    this.checkSos()
    this._sosTimer = setInterval(() => this.checkSos(), 5000)
  },

  stopSosPolling() {
    if (this._sosTimer) {
      clearInterval(this._sosTimer)
      this._sosTimer = null
    }
  },

  checkSos() {
    if (!app.globalData.token) return
    wx.request({
      url: `${app.globalData.baseUrl}/sos/history?limit=1`,
      header: { 'Authorization': `Bearer ${app.globalData.token}` },
      success: (resp) => {
        if (resp.statusCode === 200 && resp.data.length > 0) {
          const latest = resp.data[0]
          if (latest.status === 'alerting') {
            this.setData({ hasSosAlert: true, sosEvent: latest })
          } else {
            this.setData({ hasSosAlert: false, sosEvent: null })
          }
        }
      }
    })
  },

  onBindElderly() {
    wx.showModal({
      title: '绑定老人',
      editable: true,
      placeholderText: '请输入老人手机上的邀请码',
      success: (res) => {
        if (res.confirm && res.content) {
          this.bindWithCode(res.content.trim())
        }
      }
    })
  },

  bindWithCode(code) {
    wx.request({
      url: `${app.globalData.baseUrl}/family-links/request`,
      method: 'POST',
      header: { 'Authorization': `Bearer ${app.globalData.token}` },
      data: { invite_code: code },
      success: (resp) => {
        if (resp.statusCode === 200) {
          wx.showToast({ title: '绑定成功', icon: 'success' })
          app.fetchLinkedElderly()
          setTimeout(() => this.loadData(), 500)
        } else {
          wx.showToast({ title: '邀请码无效', icon: 'none' })
        }
      }
    })
  },

  onStartCoScreen(e) {
    const elderlyId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: `/pages/coscreen/coscreen?elderlyId=${elderlyId}`
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
          this.setData({ hasSosAlert: false, sosEvent: null })
          wx.showToast({ title: '已接受求助', icon: 'success' })
        }
      }
    })
  },

  onCallElderly() {
    wx.makePhoneCall({ phoneNumber: '13800000001' })
  }
})
