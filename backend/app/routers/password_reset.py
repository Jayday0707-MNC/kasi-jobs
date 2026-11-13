"""Forgot password: a 6-digit code is emailed, then the user sets a new password.

Login in Kasi Jobs is by phone number, so the user types their phone number; the code goes to the
email saved on that account. Accounts with no email cannot reset by email (SMS reset can come
later when BulkSMS is live).
"""
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from ..database import get_db
from ..email_service import code_email, send_email
from ..models import PasswordResetCode, User
from ..schemas import normalize_phone
from ..security import SECRET_KEY, hash_password

router = APIRouter(prefix="/auth", tags=["auth"])

CODE_TTL_MINUTES = 10
MAX_ATTEMPTS = 5
RESEND_COOLDOWN_SECONDS = 60
GENERIC = {"message": "If this number has an email on its account, a code has been sent to it."}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _hash(user_id: int, code: str) -> str:
    return hmac.new(SECRET_KEY.encode(), f"reset|{user_id}|{code}".encode(), hashlib.sha256).hexdigest()


def _latest(db: Session, user_id: int, only_unused: bool = True) -> PasswordResetCode | None:
    q = select(PasswordResetCode).where(PasswordResetCode.user_id == user_id)
    if only_unused:
        q = q.where(PasswordResetCode.used.is_(False))
    return db.scalar(q.order_by(PasswordResetCode.created_at.desc()).limit(1))


class ForgotIn(BaseModel):
    phone: str

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        return normalize_phone(v)


class ResetIn(BaseModel):
    phone: str
    code: str = Field(pattern=r"^\d{6}$")
    new_password: str = Field(min_length=8, max_length=64)   # same rule as RegisterIn

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        return normalize_phone(v)


@router.post("/forgot-password")
def forgot_password(data: ForgotIn, background: BackgroundTasks, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.phone == data.phone))
    if user and user.email and user.account_verified:
        last = _latest(db, user.id, only_unused=False)
        if not last or (_now() - last.created_at).total_seconds() >= RESEND_COOLDOWN_SECONDS:
            db.execute(
                update(PasswordResetCode)
                .where(PasswordResetCode.user_id == user.id, PasswordResetCode.used.is_(False))
                .values(used=True)
            )
            code = f"{secrets.randbelow(10**6):06d}"
            db.add(
                PasswordResetCode(
                    user_id=user.id,
                    code_hash=_hash(user.id, code),
                    expires_at=_now() + timedelta(minutes=CODE_TTL_MINUTES),
                )
            )
            db.commit()
            subject, html, text = code_email(code, "reset")
            background.add_task(send_email, user.email, subject, html, text)
    return GENERIC   # identical answer whether or not the number exists


@router.post("/reset-password")
def reset_password(data: ResetIn, db: Session = Depends(get_db)):
    bad = HTTPException(400, "Invalid or expired code")
    user = db.scalar(select(User).where(User.phone == data.phone))
    if not user:
        raise bad
    row = _latest(db, user.id)
    if not row or row.expires_at < _now() or row.attempts >= MAX_ATTEMPTS:
        raise bad
    row.attempts += 1
    if not hmac.compare_digest(row.code_hash, _hash(user.id, data.code.strip())):
        db.commit()
        raise bad
    row.used = True
    user.password_hash = hash_password(data.new_password)
    db.commit()
    return {"message": "Password updated. You can sign in now."}