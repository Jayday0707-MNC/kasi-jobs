from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, or_, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Area, Employer, OtpCode, User
from ..otp import OTP_REQUIRED, check_code, issue_code
from ..schemas import LoginIn, OtpRequestIn, OtpVerifyIn, RegisterIn, TokenOut, UserOut
from ..security import create_token, get_current_user, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def purge_unverified(db: Session, phone: str, email: str | None) -> None:
    """An unverified sign-up has no access, so a new sign-up may replace it."""
    conditions = [User.phone == phone]
    if email:
        conditions.append(User.email == email)
    old = db.scalars(
        select(User).where(or_(*conditions), User.account_verified.is_(False))
    ).all()
    for u in old:
        db.execute(delete(OtpCode).where(OtpCode.user_id == u.id))
        db.execute(delete(Employer).where(Employer.user_id == u.id))
        db.delete(u)
    db.flush()


def user_with_password(db: Session, phone: str, password: str) -> User:
    user = db.scalar(select(User).where(User.phone == phone))
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(401, "Wrong phone number or password")
    return user


@router.post("/register", status_code=201)
def register(data: RegisterIn, db: Session = Depends(get_db)):
    purge_unverified(db, data.phone, data.email)
    if db.scalar(select(User).where(User.phone == data.phone)):
        raise HTTPException(409, "This phone number is already registered")
    if data.email and db.scalar(select(User).where(User.email == data.email)):
        raise HTTPException(409, "This email is already registered")
    if data.area_id is not None and not db.get(Area, data.area_id):
        raise HTTPException(400, "Unknown area")

    user = User(
        role=data.role,
        full_name=data.full_name,
        phone=data.phone,
        email=data.email,
        password_hash=hash_password(data.password),
        area_id=data.area_id,
        consent_sms=data.consent_sms,
        consent_email=data.consent_email,
        account_verified=not OTP_REQUIRED,
    )
    db.add(user)
    db.flush()

    if data.role == "employer":
        db.add(Employer(user_id=user.id, business_name=data.business_name, verified=False))

    db.commit()
    db.refresh(user)

    if not OTP_REQUIRED:
        return TokenOut(access_token=create_token(user.id), user=user)

    issue_code(db, user, data.otp_channel)
    return {"needs_verification": True, "phone": user.phone, "channel": data.otp_channel}


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    user = user_with_password(db, data.phone, data.password)
    if not user.account_verified:
        raise HTTPException(403, "phone_not_verified")
    return TokenOut(access_token=create_token(user.id), user=user)


@router.post("/otp/send")
def otp_send(data: OtpRequestIn, db: Session = Depends(get_db)):
    user = user_with_password(db, data.phone, data.password)
    if user.account_verified:
        raise HTTPException(400, "This account is already verified")
    if data.channel == "email" and not user.email:
        raise HTTPException(400, "There is no email address on this account")
    issue_code(db, user, data.channel)
    return {"sent": True, "channel": data.channel}


@router.post("/otp/verify", response_model=TokenOut)
def otp_verify(data: OtpVerifyIn, db: Session = Depends(get_db)):
    user = user_with_password(db, data.phone, data.password)
    if not user.account_verified:
        check_code(db, user, data.code)
        db.refresh(user)
    return TokenOut(access_token=create_token(user.id), user=user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user