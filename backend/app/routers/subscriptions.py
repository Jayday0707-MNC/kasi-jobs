from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Area, Category, Subscription, User
from ..schemas import SubscriptionIn
from ..security import require_role

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])
seeker_only = require_role("seeker", "admin")


def sub_out(db: Session, s: Subscription) -> dict:
    return {
        "id": s.id,
        "category_id": s.category_id,
        "category": db.get(Category, s.category_id).name,
        "area_id": s.area_id,
        "area": db.get(Area, s.area_id).name,
    }


@router.post("", status_code=201)
def subscribe(
    data: SubscriptionIn,
    user: User = Depends(seeker_only),
    db: Session = Depends(get_db),
):
    if not db.get(Category, data.category_id):
        raise HTTPException(400, "Unknown category")
    if not db.get(Area, data.area_id):
        raise HTTPException(400, "Unknown area")
    exists = db.scalar(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.category_id == data.category_id,
            Subscription.area_id == data.area_id,
        )
    )
    if exists:
        raise HTTPException(409, "You are already subscribed to this")
    sub = Subscription(user_id=user.id, **data.model_dump())
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub_out(db, sub)


@router.get("")
def my_subscriptions(
    user: User = Depends(seeker_only),
    db: Session = Depends(get_db),
):
    rows = db.scalars(select(Subscription).where(Subscription.user_id == user.id)).all()
    return [sub_out(db, s) for s in rows]


@router.delete("/{sub_id}")
def unsubscribe(
    sub_id: int,
    user: User = Depends(seeker_only),
    db: Session = Depends(get_db),
):
    sub = db.get(Subscription, sub_id)
    if not sub or sub.user_id != user.id:
        raise HTTPException(404, "Subscription not found")
    db.delete(sub)
    db.commit()
    return {"deleted": sub_id}