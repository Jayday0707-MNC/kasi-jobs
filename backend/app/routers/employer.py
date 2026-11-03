import os

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Employer, EmployerDocument, User
from ..security import require_role
from ..verification import REQUIRED_DOCS, doc_out, verification_status

router = APIRouter(prefix="/employer", tags=["employer"])
employer_only = require_role("employer")

MAX_BYTES = 5 * 1024 * 1024  # 5 MB


def get_employer(user: User, db: Session) -> Employer:
    employer = db.scalar(select(Employer).where(Employer.user_id == user.id))
    if not employer:
        raise HTTPException(400, "Employer profile not found")
    return employer


def docs_of(db: Session, employer_id: int) -> list[EmployerDocument]:
    q = (
        select(EmployerDocument)
        .where(EmployerDocument.employer_id == employer_id)
        .order_by(EmployerDocument.id)
    )
    return list(db.scalars(q).all())


def sniff(data: bytes) -> str | None:
    """Work out the real file type from its first bytes, not from its name."""
    if data.startswith(b"%PDF-"):
        return "application/pdf"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    return None


@router.get("/me")
def my_status(user: User = Depends(employer_only), db: Session = Depends(get_db)):
    employer = get_employer(user, db)
    docs = docs_of(db, employer.id)
    return {
        "business_name": employer.business_name,
        "verified": employer.verified,
        "status": verification_status(employer, docs),
        "required": [{"type": k, "label": v} for k, v in REQUIRED_DOCS.items()],
        "documents": [doc_out(d) for d in docs],
    }


@router.post("/documents", status_code=201)
def upload_document(
    doc_type: str = Form(...),
    file: UploadFile = File(...),
    user: User = Depends(employer_only),
    db: Session = Depends(get_db),
):
    employer = get_employer(user, db)
    if employer.verified:
        raise HTTPException(400, "Your business is already verified")
    if doc_type not in REQUIRED_DOCS:
        raise HTTPException(400, "Unknown document type")

    data = file.file.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise HTTPException(413, "That file is too large (maximum 5 MB)")
    if not data:
        raise HTTPException(400, "That file is empty")
    content_type = sniff(data)
    if not content_type:
        raise HTTPException(400, "Only PDF, JPG or PNG files are allowed")

    # A new upload replaces any earlier waiting or rejected file of the same type.
    old = db.scalars(
        select(EmployerDocument).where(
            EmployerDocument.employer_id == employer.id,
            EmployerDocument.doc_type == doc_type,
            EmployerDocument.status.in_(["pending", "rejected"]),
        )
    ).all()
    for o in old:
        db.delete(o)

    doc = EmployerDocument(
        employer_id=employer.id,
        doc_type=doc_type,
        filename=os.path.basename(file.filename or "document")[:200],
        content_type=content_type,
        data=data,
        status="pending",
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)
    return doc_out(doc)


@router.delete("/documents/{doc_id}")
def delete_document(
    doc_id: int,
    user: User = Depends(employer_only),
    db: Session = Depends(get_db),
):
    employer = get_employer(user, db)
    doc = db.get(EmployerDocument, doc_id)
    if not doc or doc.employer_id != employer.id:
        raise HTTPException(404, "Document not found")
    if doc.status == "approved":
        raise HTTPException(400, "Approved documents cannot be removed")
    db.delete(doc)
    db.commit()
    return {"deleted": doc_id}