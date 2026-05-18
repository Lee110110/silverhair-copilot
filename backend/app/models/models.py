from sqlalchemy import Column, String, Boolean, DateTime, Enum as SQLEnum, Text, UniqueConstraint, Index
from sqlalchemy.sql import func
import uuid
import random
import string
from app.core.database import Base
import enum


class UserRole(str, enum.Enum):
    elderly = "elderly"
    child = "child"


def gen_uuid():
    return str(uuid.uuid4())


def gen_invite_code():
    return "".join(random.choices(string.digits, k=6))


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint('phone', 'role', name='uq_phone_role'),
        Index('ix_users_phone_role', 'phone', 'role'),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    phone = Column(String(20), index=True, nullable=True)
    name = Column(String(100), nullable=True)
    role = Column(String(20), nullable=False)
    invite_code = Column(String(6), unique=True, index=True, nullable=True)
    wechat_openid = Column(String(100), unique=True, index=True, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class FamilyLink(Base):
    __tablename__ = "family_links"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    elderly_id = Column(String(36), nullable=False, index=True)
    child_id = Column(String(36), nullable=True, index=True)
    invite_code = Column(String(10), unique=True, index=True, nullable=True)
    status = Column(String(20), default="pending")  # pending | active | rejected
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class SosEvent(Base):
    __tablename__ = "sos_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    elderly_id = Column(String(36), nullable=False, index=True)
    child_id = Column(String(36), nullable=False, index=True)
    status = Column(String(20), default="alerting")  # alerting | accepted | cancelled | resolved
    location_lat = Column(String(20), nullable=True)
    location_lng = Column(String(20), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)


class AnnotationSession(Base):
    __tablename__ = "annotation_sessions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    elderly_id = Column(String(36), nullable=False, index=True)
    child_id = Column(String(36), nullable=False, index=True)
    status = Column(String(20), default="pending")  # pending | active | ended
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)