import hashlib
import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import OtpCode, User
from .notifications import send_email, send_sms
from .security import SECRET_KEY
from sqlalchemy import func, select

OTP_REQUIRED = os.getenv("OTP_REQUIRED", "true").lower() == "true"

CODE_MINUTES = 10
MAX_ATTEMPTS = 5
RESEND_WAIT_SECONDS = 60
MAX_PER_HOUR = 5
DAILY_SMS_CAP = int(os.getenv("OTP_DAILY_SMS_CAP", "100"))

def _hash(user_id: int, code: str) -> str:
    msg = f"{user_id}:{code}".encode()
    return hmac.new(SECRET_KEY.encode(), msg, hashlib.sha256).hexdigest()


def issue_code(db: Session, user: User, channel: str) -> None:
    now = datetime.now(timezone.utc)
    recent = db.scalars(
        select(OtpCode)
        .where(OtpCode.user_id == user.id, OtpCode.created_at > now - timedelta(hours=1))
        .order_by(OtpCode.id.desc())
    ).all()
    if recent and (now - recent[0].created_at).total_seconds() < RESEND_WAIT_SECONDS:
        raise HTTPException(429, "Please wait a minute before asking for a new code")
    if len(recent) >= MAX_PER_HOUR:
        raise HTTPException(429, "Too many codes requested. Try again in an hour")

    if channel == "sms":
        sent_today = db.scalar(
            select(func.count())
            .select_from(OtpCode)
            .where(OtpCode.channel == "sms", OtpCode.created_at > now - timedelta(days=1))
        )
        if (sent_today or 0) >= DAILY_SMS_CAP:
            raise HTTPException(503, "SMS codes are unavailable right now. Please try again later")

    # Only the newest code is valid.
    for old in db.scalars(
        select(OtpCode).where(OtpCode.user_id == user.id, OtpCode.used.is_(False))
    ).all():
        old.used = True

    code = f"{secrets.randbelow(10**6):06d}"
    row = OtpCode(
        user_id=user.id,
        channel=channel,
        code_hash=_hash(user.id, code),
        expires_at=now + timedelta(minutes=CODE_MINUTES),
    )
    db.add(row)
    db.commit()

    text = f"Kasi Jobs: your PIN is {code}"
    try:
        if channel == "email":
            send_email(user.email, "Your Kasi Jobs verification code", text)
        else:
            send_sms(user.phone, text)
    except Exception as exc:
        print(f"OTP delivery failed ({channel}): {exc}")
        row.used = True
        db.commit()
        raise HTTPException(502, "We could not send the code. Please try again")

def check_code(db: Session, user: User, code: str) -> None:
    now = datetime.now(timezone.utc)
    row = db.scalar(
        select(OtpCode)
        .where(OtpCode.user_id == user.id, OtpCode.used.is_(False))
        .order_by(OtpCode.id.desc())
    )
    if not row or row.expires_at < now:
        raise HTTPException(400, "That code has expired. Ask for a new one")
    if row.attempts >= MAX_ATTEMPTS:
        raise HTTPException(429, "Too many wrong tries. Ask for a new code")

    row.attempts += 1
    if not hmac.compare_digest(row.code_hash, _hash(user.id, code)):
        db.commit()
        raise HTTPException(400, "That code is not correct")

    row.used = True
    user.account_verified = True
    db.commit()