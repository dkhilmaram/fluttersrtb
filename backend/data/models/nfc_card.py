
from sqlalchemy import Column, String, Date
from database import Base

class NfcCard(Base):
    __tablename__ = "nfc_cards"

    card_uid   = Column(String(32), primary_key=True)  # hex UID, e.g. "A1B2C3D4"
    nom        = Column(String(100), nullable=False)
    type       = Column(String(50),  nullable=False)   # mensuel, annuel...
    expire     = Column(String(20),  nullable=False)   # ISO date string
    ligne      = Column(String(20),  nullable=False)
    organisme  = Column(String(100), nullable=False)