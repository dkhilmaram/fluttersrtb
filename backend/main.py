from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from presentation.routers import (
    auth_router, agent_router, vente_router, segment_router, ticket_router
)

app = FastAPI(title="SRTB Billetterie API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)                            # /login stays as /login
app.include_router(agent_router.router,   prefix="/billetterie")
app.include_router(vente_router.router,   prefix="/billetterie")
app.include_router(segment_router.router, prefix="/billetterie")
app.include_router(ticket_router.router,  prefix="/billetterie")