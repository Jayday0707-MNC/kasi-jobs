from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Area, Employer, User
from ..schemas import LoginIn, RegisterIn, TokenOut, UserOut
from ..security import create_token, get_current_user, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut, status_code=201)
def register(data: RegisterIn, db: Session = Depends(get_db)):
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
    )
    db.add(user)
    db.flush()  # gives the user an id before we create the employer row

    if data.role == "employer":
        db.add(Employer(user_id=user.id, business_name=data.business_name, verified=False))

    db.commit()
    db.refresh(user)
    return TokenOut(access_token=create_token(user.id), user=user)


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.phone == data.phone))
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(401, "Wrong phone number or password")
    return TokenOut(access_token=create_token(user.id), user=user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user