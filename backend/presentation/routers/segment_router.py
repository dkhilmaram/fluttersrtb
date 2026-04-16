from fastapi import APIRouter
from services.segments_service import SegmentService

router = APIRouter(prefix="/voyages", tags=["Segments"])
_svc = SegmentService()

@router.get("/{id_voyage}/arrets")
def get_arrets(id_voyage: int):
    return _svc.get_arrets(id_voyage)

@router.get("/{id_voyage}/segments")
def get_segments(id_voyage: int):
    return _svc.get_all_segments(id_voyage)