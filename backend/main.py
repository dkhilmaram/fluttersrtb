from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from presentation.routers.agent_router     import router as agent_router
from presentation.routers.vente_router     import router as vente_router
from presentation.routers.segment_router   import router as segment_router
from presentation.routers.ticket_router    import router as ticket_router
from presentation.routers.scan_router      import router as scan_router
from presentation.routers.heartbeat_router import router as heartbeat_router
from presentation.routers.nfc_router       import router as nfc_router

app = FastAPI(title="SRTB Billetterie API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"success": False, "error": str(exc)},
    )

app.include_router(agent_router)
app.include_router(vente_router,      prefix="/billetterie")
app.include_router(segment_router,    prefix="/billetterie")
app.include_router(ticket_router,     prefix="/billetterie")
app.include_router(scan_router,       prefix="/billetterie")
app.include_router(nfc_router,        prefix="/billetterie")
app.include_router(heartbeat_router)