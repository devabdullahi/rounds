"""Item endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.item import ItemCreate, ItemOut
from app.services import item_service

router = APIRouter(prefix="/items", tags=["items"])


@router.get("/", response_model=list[ItemOut])
def list_items(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return item_service.list_items(db, skip=skip, limit=limit)


@router.post("/", response_model=ItemOut, status_code=status.HTTP_201_CREATED)
def create_item(item: ItemCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return item_service.create_item(db, item, owner_id=user.id)


@router.get("/{item_id}", response_model=ItemOut)
def read_item(item_id: int, db: Session = Depends(get_db)):
    item = item_service.get_item(db, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item
