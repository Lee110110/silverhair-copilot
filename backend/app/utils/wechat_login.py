"""WeChat login utilities."""
import httpx
from app.core.config import WECHAT_APP_ID, WECHAT_APP_SECRET


async def verify_wechat_code(code: str) -> str | None:
    """Exchange WeChat login code for openid."""
    if not WECHAT_APP_ID or not WECHAT_APP_SECRET:
        # Mock mode: return a deterministic openid based on the code
        return f"mock_openid_{code}"

    url = "https://api.weixin.qq.com/sns/jscode2session"
    params = {
        "appid": WECHAT_APP_ID,
        "secret": WECHAT_APP_SECRET,
        "js_code": code,
        "grant_type": "authorization_code",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params)
        data = resp.json()
        if "openid" in data:
            return data["openid"]
        return None