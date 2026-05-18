from fastapi import APIRouter
from app.api.v1 import auth, users, family_links, sos, coscreen

router = APIRouter(prefix="/api/v1")
router.include_router(auth.router)
router.include_router(users.router)
router.include_router(family_links.router)
router.include_router(sos.router)
router.include_router(coscreen.router)