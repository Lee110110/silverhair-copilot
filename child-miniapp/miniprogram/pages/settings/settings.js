const app = getApp()

Page({
  data: {
    userInfo: null
  },

  onShow() {
    this.setData({ userInfo: app.globalData.userInfo })
  },

  onLogout() {
    wx.showModal({
      title: '退出登录',
      content: '确定要退出登录吗？',
      success: (res) => {
        if (res.confirm) {
          wx.clearStorageSync()
          app.globalData.token = null
          app.globalData.userInfo = null
          app.login()
        }
      }
    })
  }
})