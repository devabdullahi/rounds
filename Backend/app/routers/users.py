"""User endpoints: sign up, profile, settings."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserOut, UserUpdate
from app.services import user_service

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    """Sign up with email."""
    return user_service.create_user(db, user)


@router.get("/me", response_model=UserOut)
def read_me(current_user: User = Depends(get_current_user)):
    """Profile."""
    return current_user


@router.patch("/me", response_model=UserOut)
def update_me(changes: UserUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Onboarding (training level) and Settings."""
    return user_service.update_user(db, current_user, changes)


@router.get("/{user_id}", response_model=UserOut)
def read_user(user_id: int, db: Session = Depends(get_db)):
    user = user_service.get_user(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user
