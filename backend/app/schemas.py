import re
from typing import Literal
from datetime import date

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


def normalize_phone(raw: str) -> str:
    """Turn 082 123 4567 / +27821234567 / 27821234567 into +27821234567."""
    cleaned = re.sub(r"[^\d+]", "", raw)
    if cleaned.startswith("+"):
        cleaned = cleaned[1:]
    if cleaned.startswith("27"):
        national = cleaned[2:]
    elif cleaned.startswith("0"):
        national = cleaned[1:]
    else:
        raise ValueError("Enter a South African number, e.g. 082 123 4567")
    if not re.fullmatch(r"\d{9}", national):
        raise ValueError("Enter a valid South African phone number")
    return "+27" + national


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    phone: str
    email: EmailStr | None = None
    password: str = Field(min_length=8, max_length=64)
    role: Literal["seeker", "employer"] = "seeker"
    area_id: int | None = None
    business_name: str | None = Field(default=None, max_length=150)
    consent_sms: bool = False
    consent_email: bool = False
    otp_channel: Literal["sms", "email"] = "sms"

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        return normalize_phone(v)

    @model_validator(mode="after")
    def check_rules(self):
        if self.consent_email and not self.email:
            raise ValueError("An email address is required for email alerts")
        if self.role == "employer" and not self.business_name:
            raise ValueError("Business name is required for employers")
        if self.otp_channel == "email" and not self.email:
            raise ValueError("An email address is required to get the code by email")
        return self


class LoginIn(BaseModel):
    phone: str
    password: str

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        return normalize_phone(v)


class UserOut(BaseModel):
    id: int
    role: str
    full_name: str
    phone: str
    email: str | None
    area_id: int | None
    consent_sms: bool
    consent_email: bool

    model_config = {"from_attributes": True}


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
    
class JobIn(BaseModel):
    title: str = Field(min_length=3, max_length=150)
    description: str = Field(min_length=10)
    category_id: int
    area_id: int
    pay: str | None = Field(default=None, max_length=100)
    how_to_apply: str | None = None
    closing_date: date | None = None

    @field_validator("closing_date")
    @classmethod
    def not_in_past(cls, v):
        if v and v < date.today():
            raise ValueError("Closing date is in the past")
        return v
    
class SubscriptionIn(BaseModel):
    category_id: int
    area_id: int
    
class RejectIn(BaseModel):
    reason: str = Field(min_length=5, max_length=500)
    
class OtpRequestIn(BaseModel):
    phone: str
    password: str
    channel: Literal["sms", "email"] = "sms"

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        return normalize_phone(v)


class OtpVerifyIn(BaseModel):
    phone: str
    password: str
    code: str = Field(pattern=r"^\d{6}$")

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        return normalize_phone(v)