from fastapi import APIRouter
from services.segments_service import SegmentService

router = APIRouter(prefix="/voyages", tags=["Segments"])
_svc = SegmentService()

@router.get("/{id_vente}/arrets")
def get_arrets(id_vente: int):
    return _svc.get_arrets(id_vente)

@router.get("/{id_vente}/segments")
def get_segments(id_vente: int):
    return _svc.get_all_segments(id_vente)