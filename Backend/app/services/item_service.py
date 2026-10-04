"""Business logic for items, kept out of the route handlers."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.item import Item
from app.schemas.item import ItemCreate


def create_item(db: Session, item: ItemCreate, owner_id: int) -> Item:
    db_item = Item(**item.model_dump(), owner_id=owner_id)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


def list_items(db: Session, skip: int = 0, limit: int = 100) -> list[Item]:
    return list(db.scalars(select(Item).offset(skip).limit(limit)))


def get_item(db: Session, item_id: int) -> Item | None:
    return db.get(Item, item_id)
