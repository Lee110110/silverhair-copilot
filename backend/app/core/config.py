import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./silverhair.db")
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours
REFRESH_TOKEN_EXPIRE_DAYS = 30

SMS_PROVIDER = os.getenv("SMS_PROVIDER", "mock")  # mock | aliyun | tencent
SMS_API_KEY = os.getenv("SMS_API_KEY", "")
SMS_API_SECRET = os.getenv("SMS_API_SECRET", "")
SMS_SIGN_NAME = os.getenv("SMS_SIGN_NAME", "银发陪驾")
SMS_TEMPLATE_CODE = os.getenv("SMS_TEMPLATE_CODE", "")

WECHAT_APP_ID = os.getenv("WECHAT_APP_ID", "")
WECHAT_APP_SECRET = os.getenv("WECHAT_APP_SECRET", "")

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")