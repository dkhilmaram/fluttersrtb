from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, stored: str) -> bool:
    """Accepts both hashed (new) and plain-text (legacy) passwords."""
    try:
        return pwd_context.verify(plain, stored)
    except Exception:
        return plain == stored  # legacy plain-text fallback