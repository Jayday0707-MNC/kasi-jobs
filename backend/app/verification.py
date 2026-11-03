from .models import Employer, EmployerDocument

REQUIRED_DOCS = {
    "owner_id": "Owner's ID (ID card or passport)",
    "business_proof": "Proof the business exists",
    "address_proof": "Proof of address",
}


def verification_status(employer: Employer, docs: list[EmployerDocument]) -> str:
    if employer.verified:
        return "verified"
    have = {d.doc_type for d in docs if d.status != "rejected"}
    if set(REQUIRED_DOCS) <= have:
        return "in_review"
    if any(d.status == "rejected" for d in docs):
        return "changes_needed"
    return "needs_documents"


def doc_out(d: EmployerDocument) -> dict:
    return {
        "id": d.id,
        "doc_type": d.doc_type,
        "label": REQUIRED_DOCS.get(d.doc_type, d.doc_type),
        "filename": d.filename,
        "status": d.status,
        "review_note": d.review_note,
        "uploaded_at": d.uploaded_at,
    }