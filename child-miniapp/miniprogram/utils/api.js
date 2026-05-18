/**
 * HTTP API wrapper for WeChat Mini Program
 */
const app = getApp()

function request(options) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${app.globalData.baseUrl}${options.path}`,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${app.globalData.token}`,
        ...options.header
      },
      success: (resp) => {
        if (resp.statusCode === 401) {
          // Token expired, re-login
          app.login()
          reject(new Error('Unauthorized'))
          return
        }
        resolve(resp.data)
      },
      fail: reject
    })
  })
}

module.exports = { request }