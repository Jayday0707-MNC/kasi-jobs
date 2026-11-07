from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Employer, EmployerDocument, Job, Notification
from ..schemas import RejectIn
from ..security import create_file_token, require_role
from ..verification import doc_out, verification_status
from .jobs import job_out
from ..notifications import EMAIL_MODE, SMS_MODE
from ..otp import OTP_REQUIRED

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_role("admin"))],
)


def _docs(db: Session, employer_id: int) -> list[EmployerDocument]:
    q = (
        select(EmployerDocument)
        .where(EmployerDocument.employer_id == employer_id)
        .order_by(EmployerDocument.id)
    )
    return list(db.scalars(q).all())


@router.get("/employers/pending")
def pending_employers(db: Session = Depends(get_db)):
    out = []
    for e in db.scalars(select(Employer).where(Employer.verified.is_(False))).all():
        docs = _docs(db, e.id)
        if verification_status(e, docs) != "in_review":
            continue
        out.append(
            {
                "id": e.id,
                "business_name": e.business_name,
                "contact_name": e.user.full_name,
                "phone": e.user.phone,
                "email": e.user.email,
                "documents": [doc_out(d) for d in docs if d.status == "pending"],
            }
        )
    return out


@router.get("/documents/{doc_id}/link")
def document_link(doc_id: int, db: Session = Depends(get_db)):
    doc = db.get(EmployerDocument, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")
    return {"path": f"/files/{doc.id}?t={create_file_token(doc.id)}"}


@router.post("/employers/{employer_id}/verify")
def verify_employer(employer_id: int, db: Session = Depends(get_db)):
    employer = db.get(Employer, employer_id)
    if not employer:
        raise HTTPException(404, "Employer not found")
    docs = _docs(db, employer.id)
    status = verification_status(employer, docs)
    if status == "verified":
        return {"id": employer.id, "business_name": employer.business_name, "verified": True}
    if status != "in_review":
        raise HTTPException(400, "This employer has not submitted all the required documents")
    for d in docs:
        if d.status == "pending":
            d.status = "approved"
            d.review_note = None
    employer.verified = True
    db.commit()
    return {"id": employer.id, "business_name": employer.business_name, "verified": True}


@router.post("/employers/{employer_id}/reject")
def reject_employer(employer_id: int, data: RejectIn, db: Session = Depends(get_db)):
    employer = db.get(Employer, employer_id)
    if not employer:
        raise HTTPException(404, "Employer not found")
    pending = [d for d in _docs(db, employer.id) if d.status == "pending"]
    if not pending:
        raise HTTPException(400, "There are no documents waiting for review")
    for d in pending:
        d.status = "rejected"
        d.review_note = data.reason
    db.commit()
    return {"id": employer.id, "status": "changes_needed"}


@router.get("/jobs/pending")
def pending_jobs(db: Session = Depends(get_db)):
    q = select(Job).where(Job.status == "pending").order_by(Job.created_at)
    return [job_out(j) for j in db.scalars(q).all()]


@router.post("/jobs/{job_id}/approve")
def approve_job(job_id: int, db: Session = Depends(get_db)):
    job = db.get(Job, job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    if not job.employer.verified:
        raise HTTPException(400, "Verify this employer before approving their jobs")
    job.status = "approved"
    db.commit()
    # Job alerts will be switched back on here later.
    return job_out(job)


@router.post("/jobs/{job_id}/reject")
def reject_job(job_id: int, db: Session = Depends(get_db)):
    job = db.get(Job, job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    job.status = "rejected"
    db.commit()
    return job_out(job)


@router.get("/notifications")
def recent_notifications(db: Session = Depends(get_db)):
    q = select(Notification).order_by(Notification.id.desc()).limit(50)
    return [
        {
            "id": n.id,
            "user_id": n.user_id,
            "job_id": n.job_id,
            "channel": n.channel,
            "status": n.status,
            "response": n.provider_response,
            "created_at": n.created_at,
        }
        for n in db.scalars(q).all()
    ]
@router.get("/delivery")
def delivery_modes():
    return {"sms": SMS_MODE, "email": EMAIL_MODE, "otp_required": OTP_REQUIRED}