from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from login import router as login_router
from voyage_programme import router as voyage_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(login_router)
app.include_router(voyage_router)
app.include_router(voyage_router, prefix="/billetterie")