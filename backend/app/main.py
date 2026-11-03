import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text, select
from sqlalchemy.orm import Session
from .routers import auth
from .routers import admin, auth, employer, files, jobs, subscriptions

from . import models
from .database import Base, engine, SessionLocal, get_db
from .seed import seed_reference_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_reference_data(db)
    yield


app = FastAPI(title="Kasi Jobs API", lifespan=lifespan)

origins = [o.strip() for o in os.getenv("ALLOWED_ORIGINS", "*").split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)
app.include_router(jobs.router)
app.include_router(admin.router)
app.include_router(subscriptions.router)
app.include_router(employer.router)
app.include_router(files.router)

@app.get("/")
def root():
    return {"message": "Kasi Jobs API is running"}


@app.get("/health")
def health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}


@app.get("/areas")
def list_areas(db: Session = Depends(get_db)):
    rows = db.scalars(select(models.Area).order_by(models.Area.name)).all()
    return [{"id": a.id, "name": a.name} for a in rows]


@app.get("/categories")
def list_categories(db: Session = Depends(get_db)):
    rows = db.scalars(select(models.Category).order_by(models.Category.name)).all()
    return [{"id": c.id, "name": c.name} for c in rows]