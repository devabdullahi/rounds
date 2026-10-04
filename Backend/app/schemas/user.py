"""Request/response shapes for users."""

from pydantic import BaseModel, ConfigDict, EmailStr


class UserCreate(BaseModel):
    """Sign up with email."""
    name: str
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """Onboarding and Settings changes. Only sent fields are applied."""
    name: str | None = None
    training_level: str | None = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: EmailStr
    training_level: str | None
    rating: int
    streak: int
