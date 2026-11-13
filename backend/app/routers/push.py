"""Firebase Cloud Messaging (push) for Kasi Jobs.

Needs `firebase-admin` in requirements.txt and the Render env var FIREBASE_CREDENTIALS_JSON
(full contents of the Firebase service-account JSON). Without it, pushes are only printed to the log.
"""
import json
import os

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import DeviceToken, Job, Subscription, User
from ..security import get_current_user

router = APIRouter(prefix="/devices", tags=["push"])
_firebase_ready = False


class TokenIn(BaseModel):
    token: str
    platform: str = "android"


@router.post("/register")
def register_device(
    data: TokenIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = db.scalar(select(DeviceToken).where(DeviceToken.token == data.token))
    if row:
        row.user_id = user.id          # the phone may now belong to a different signed-in user
        row.updated_at = func.now()
    else:
        db.add(DeviceToken(user_id=user.id, token=data.token, platform=data.platform))
    db.commit()
    return {"ok": True}


def _init_firebase() -> bool:
    global _firebase_ready
    if _firebase_ready:
        return True
    raw = os.getenv("FIREBASE_CREDENTIALS_JSON", "")
    if not raw:
        return False
    import firebase_admin
    from firebase_admin import credentials

    firebase_admin.initialize_app(credentials.Certificate(json.loads(raw)))
    _firebase_ready = True
    return True


def send_push_to_users(db: Session, user_ids: list[int], title: str, body: str, data: dict | None = None) -> int:
    """Send to every registered phone of these users. Never raises; returns how many were delivered."""
    try:
        if not user_ids:
            return 0
        if not _init_firebase():
            print(f"[PUSH console mode] users={user_ids} title={title!r} body={body!r}")
            return 0
        from firebase_admin import messaging

        tokens = list(db.scalars(select(DeviceToken.token).where(DeviceToken.user_id.in_(user_ids))).all())
        sent = 0
        for i in range(0, len(tokens), 500):                      # FCM limit: 500 per batch
            batch = tokens[i : i + 500]
            msg = messaging.MulticastMessage(
                tokens=batch,
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
            )
            resp = messaging.send_each_for_multicast(msg)
            sent += resp.success_count
            for tok, r in zip(batch, resp.responses):
                if not r.success and isinstance(r.exception, messaging.UnregisteredError):
                    db.execute(delete(DeviceToken).where(DeviceToken.token == tok))   # app was uninstalled
        db.commit()
        return sent
    except Exception as e:   # a push problem must never break approving a job
        print(f"[PUSH] failed: {e}")
        return 0


def notify_job_subscribers(db: Session, job: Job) -> int:
    """Push to everyone subscribed to this job's category AND area."""
    user_ids = db.scalars(
        select(Subscription.user_id)
        .where(Subscription.category_id == job.category_id, Subscription.area_id == job.area_id)
        .distinct()
    ).all()
    return send_push_to_users(
        db,
        list(user_ids),
        f"New job in {job.area.name}",
        job.title,
        {"job_id": job.id},
    )