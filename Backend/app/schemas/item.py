"""Request/response shapes for items."""

from pydantic import BaseModel, ConfigDict


class ItemCreate(BaseModel):
    title: str
    description: str | None = None


class ItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    owner_id: int
