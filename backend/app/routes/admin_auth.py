from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app import models
from app.security import verify_password, hash_password, create_access_token, decode_token
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr

router = APIRouter(prefix="/admin", tags=["Admin Auth"])
admin_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/admin/login")

class AdminLogin(BaseModel):
    email: EmailStr
    password: str


class AdminRegister(BaseModel):
    email: EmailStr
    password: str


@router.post("/register")
def admin_register(
    data: AdminRegister,
    db: Session = Depends(get_db)
):
    existing = db.query(models.Admin).filter(
        models.Admin.email == data.email
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered as admin")

    admin = models.Admin(
        email=data.email,
        hashed_password=hash_password(data.password),
        is_active=True,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)

    access_token = create_access_token(
        data={"sub": str(admin.id), "role": "admin"}
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "admin_id": admin.id,
        "email": admin.email,
    }


@router.post("/login")
def admin_login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):

    admin = db.query(models.Admin).filter(
        models.Admin.email == form_data.username
    ).first()

    if not admin:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(form_data.password, admin.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(
        data={"sub": str(admin.id), "role": "admin"}
    )

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

def get_current_admin(
    token: str = Depends(admin_oauth2_scheme),
    db: Session = Depends(get_db)
):

    payload = decode_token(token)

    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Not authorized")

    admin_id = int(payload.get("sub"))

    admin = db.query(models.Admin).filter(
        models.Admin.id == admin_id
    ).first()

    if not admin:
        raise HTTPException(status_code=403, detail="Admin not found")

    return admin

