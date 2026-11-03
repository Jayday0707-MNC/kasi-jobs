from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import EmployerDocument
from ..security import read_file_token

router = APIRouter(tags=["files"])

EXT = {"application/pdf": "pdf", "image/jpeg": "jpg", "image/png": "png"}


@router.get("/files/{doc_id}")
def get_file(doc_id: int, t: str, db: Session = Depends(get_db)):
    if read_file_token(t) != doc_id:
        raise HTTPException(401, "This link is not valid")
    doc = db.get(EmployerDocument, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")
    ext = EXT.get(doc.content_type, "bin")
    return Response(
        content=doc.data,
        media_type=doc.content_type,
        headers={
            "Content-Disposition": f'inline; filename="document-{doc.id}.{ext}"',
            "Cache-Control": "private, no-store",
        },
    )