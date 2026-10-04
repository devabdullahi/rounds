"""Application entry point: creates the FastAPI app and registers routers."""

from fastapi import FastAPI

from app.core.config import settings
from app.internal import admin
from app.routers import items, users

app = FastAPI(title=settings.APP_NAME)

app.include_router(users.router)
app.include_router(items.router)
app.include_router(admin.router)  # protect before deploying; internal use only


@app.get("/")
def root():
    return {"message": "Rounds API"}
