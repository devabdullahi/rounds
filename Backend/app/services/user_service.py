"""Business logic for users, kept out of the route handlers."""

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


def create_user(db: Session, user: UserCreate) -> User:
    db_user = User(name=user.name, email=user.email, password_hash=hash_password(user.password))
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def get_user(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def update_user(db: Session, user: User, changes: UserUpdate) -> User:
    for field, value in changes.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user
