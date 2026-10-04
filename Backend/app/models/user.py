"""User: the student. Backs Sign up, Onboarding, Profile and Settings."""

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    name: Mapped[str] = mapped_column(String)
    password_hash: Mapped[str | None] = mapped_column(String, nullable=True)  # null for Apple/Google sign-in
    auth_provider: Mapped[str] = mapped_column(String, default="email")       # email | apple | google
    training_level: Mapped[str | None] = mapped_column(String, nullable=True)  # ms12 | ms3 | ms4 | img | res
    rating: Mapped[int] = mapped_column(Integer, default=1200)
    streak: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
