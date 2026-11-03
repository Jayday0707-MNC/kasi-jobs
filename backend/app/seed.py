from sqlalchemy import select, delete
from .models import Area, Category

AREAS = [
    "Piet Retief Town",
    "Maphepheni",
    "Harmony Park",
    "Group 10",
    "Ajax",
    "Rustplass",
    "Malayinin",
    "Thandukukhanya: Eziphunzini",
    "Thandukukhanya: Kwantombazane",
    "Thandukukhanya: Ezinkomeni",
    "Other (nearby)",
]

CATEGORIES = [
    "Farming & Agriculture",
    "Forestry & Sawmill",
    "Retail & Hospitality",
    "Construction & Trades",
    "Driving & Transport",
    "Domestic & Cleaning",
    "Security",
    "Admin & Office",
    "Learnerships & Bursaries",
    "Other",
]

# One-time cleanup of the placeholder areas from the first version.
# Safe now because no users or jobs exist yet. Delete this list and the
# delete block below after you've run the server once.
OLD_PLACEHOLDERS = [
    "Mkhondo Townships",
    "Mkhondo Villages and Farms",
]


def seed_reference_data(db):
    db.execute(delete(Area).where(Area.name.in_(OLD_PLACEHOLDERS)))
    for name in AREAS:
        if not db.scalar(select(Area).where(Area.name == name)):
            db.add(Area(name=name))
    for name in CATEGORIES:
        if not db.scalar(select(Category).where(Category.name == name)):
            db.add(Category(name=name))
    db.commit()