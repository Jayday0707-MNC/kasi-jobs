from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Area, Category, Employer, Job, User
from ..schemas import JobIn
from ..security import get_optional_user, require_role

router = APIRouter(prefix="/jobs", tags=["jobs"])


def job_out(j: Job) -> dict:
    return {
        "id": j.id,
        "title": j.title,
        "description": j.description,
        "category_id": j.category_id,
        "category": j.category.name,
        "area_id": j.area_id,
        "area": j.area.name,
        "employer": j.employer.business_name,
        "pay": j.pay,
        "how_to_apply": j.how_to_apply,
        "closing_date": j.closing_date,
        "status": j.status,
        "created_at": j.created_at,
    }


def block_employers(viewer: User | None) -> None:
    if viewer and viewer.role == "employer":
        raise HTTPException(403, "Employers can only see their own jobs")


@router.post("", status_code=201)
def create_job(
    data: JobIn,
    user: User = Depends(require_role("employer")),
    db: Session = Depends(get_db),
):
    employer = db.scalar(select(Employer).where(Employer.user_id == user.id))
    if not employer:
        raise HTTPException(400, "Employer profile not found")
    if not employer.verified:
        raise HTTPException(403, "Your business must be verified before you can post jobs")
    if not db.get(Category, data.category_id):
        raise HTTPException(400, "Unknown category")
    if not db.get(Area, data.area_id):
        raise HTTPException(400, "Unknown area")

    job = Job(employer_id=employer.id, status="pending", **data.model_dump())
    db.add(job)
    db.commit()
    db.refresh(job)
    return job_out(job)


@router.get("")
def list_jobs(
    area_id: int | None = None,
    category_id: int | None = None,
    viewer: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    block_employers(viewer)
    q = select(Job).where(
        Job.status == "approved",
        or_(Job.closing_date.is_(None), Job.closing_date >= date.today()),
    )
    if area_id:
        q = q.where(Job.area_id == area_id)
    if category_id:
        q = q.where(Job.category_id == category_id)
    q = q.order_by(Job.created_at.desc())
    return [job_out(j) for j in db.scalars(q).all()]


@router.get("/mine")
def my_jobs(
    user: User = Depends(require_role("employer")),
    db: Session = Depends(get_db),
):
    employer = db.scalar(select(Employer).where(Employer.user_id == user.id))
    q = select(Job).where(Job.employer_id == employer.id).order_by(Job.created_at.desc())
    return [job_out(j) for j in db.scalars(q).all()]


@router.get("/{job_id}")
def get_job(
    job_id: int,
    viewer: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    block_employers(viewer)
    job = db.get(Job, job_id)
    if not job or job.status != "approved":
        raise HTTPException(404, "Job not found")
    return job_out(job)