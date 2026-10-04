# Rounds API

REST backend for the Rounds iOS app. FastAPI, structured after
[Structuring a FastAPI Project: Best Practices](https://dev.to/mohammad222pr/structuring-a-fastapi-project-best-practices-53l6).

**Status: scaffold only.** Nothing is connected: no database provisioned, no auth provider,
and the iOS app doesn't call it yet. Service functions raise `NotImplementedError` until wired.

## Layout

```
my_fastapi_project/
├── app/
│   ├── main.py            # creates the app, registers routers
│   ├── dependencies.py    # shared dependencies: DB session, current user
│   ├── routers/           # public endpoints: users.py, items.py
│   ├── internal/          # non-public endpoints: admin.py
│   ├── core/              # config.py (settings), security.py (password hashing)
│   ├── models/            # SQLAlchemy tables: user.py, item.py
│   ├── schemas/           # Pydantic request/response models: user.py, item.py
│   ├── services/          # business logic: user_service.py, item_service.py
│   └── db/                # database.py (engine, session, base), migrations/
├── tests/                 # test_main.py, test_users.py, test_items.py
├── .env                   # local settings (git-ignored)
├── .gitignore
├── requirements.txt
├── README.md
└── run.sh                 # uvicorn dev server
```

## Run locally (when ready)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
./run.sh            # http://localhost:8000/docs
pytest
```
