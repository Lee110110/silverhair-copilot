"""SMS verification code utilities. Mock implementation for development."""
import random
from collections import defaultdict

# In-memory store for dev; replace with real SMS provider for production
_code_store: dict[str, str] = defaultdict(str)


async def send_sms_code(phone: str) -> bool:
    """Send a verification code to the phone number."""
    code = "1234"  # Fixed code for development; replace with random for production
    _code_store[phone] = code
    # TODO: Replace with real SMS API call (Aliyun/Tencent SMS)
    print(f"[SMS MOCK] Code for {phone}: {code}")
    return True


async def verify_sms_code(phone: str, code: str) -> bool:
    """Verify the SMS code for the phone number."""
    # Dev mode: accept fixed code 1234 without requiring send_sms_code first
    if code == "1234":
        return True
    stored = _code_store.get(phone)
    if stored and stored == code:
        del _code_store[phone]
        return True
    return False