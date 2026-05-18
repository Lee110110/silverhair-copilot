App({
  globalData: {
    baseUrl: 'http://localhost:8000/api/v1',
    token: null,
    userInfo: null,
    linkedElderly: [],
    wsManager: null
  },

  onLaunch() {
    // Try to restore saved token
    const token = wx.getStorageSync('access_token');
    const user = wx.getStorageSync('user');
    if (token && user) {
      this.globalData.token = token;
      this.globalData.userInfo = JSON.parse(user);
      this.fetchLinkedElderly();
    } else {
      this.login();
    }
  },

  login() {
    wx.login({
      success: (res) => {
        if (res.code) {
          wx.request({
            url: `${this.globalData.baseUrl}/auth/login/wechat`,
            method: 'POST',
            data: { code: res.code },
            success: (resp) => {
              if (resp.statusCode === 200) {
                const data = resp.data;
                this.globalData.token = data.access_token;
                this.globalData.userInfo = data.user;
                wx.setStorageSync('access_token', data.access_token);
                wx.setStorageSync('refresh_token', data.refresh_token);
                wx.setStorageSync('user', JSON.stringify(data.user));
                this.fetchLinkedElderly();
              }
            }
          });
        }
      }
    });
  },

  fetchLinkedElderly() {
    if (!this.globalData.token) return;
    wx.request({
      url: `${this.globalData.baseUrl}/family-links`,
      header: { 'Authorization': `Bearer ${this.globalData.token}` },
      success: (resp) => {
        if (resp.statusCode === 200) {
          this.globalData.linkedElderly = resp.data;
        }
      }
    });
  }
});