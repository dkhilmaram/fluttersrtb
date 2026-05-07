from sqlalchemy import Column, String, Date, DateTime, func
from database import Base


class NfcCard(Base):
    __tablename__  = "nfc_cards"
    __table_args__ = {"schema": "billetterie"}

    card_uid   = Column(String(32),  primary_key=True)   # hex UID e.g. "A1B2C3D4"
    nom        = Column(String(100), nullable=False)
    type       = Column(String(50),  nullable=False)      # mensuel, annuel …
    expire     = Column(Date,        nullable=False)      # proper DATE column
    ligne      = Column(String(20),  nullable=False)
    organisme  = Column(String(100), nullable=False)
    created_at = Column(DateTime,    server_default=func.now())