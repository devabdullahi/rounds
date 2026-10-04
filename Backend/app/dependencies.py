"""Shared dependencies, like database sessions."""

from collections.abc import Generator

from sqlalchemy.orm import Session

from app.db.database import SessionLocal


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user():
    """Resolves the signed-in user from the request's token. Not implemented until auth is chosen."""
    raise NotImplementedError
