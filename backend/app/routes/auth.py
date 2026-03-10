from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app import models, schemas
from app.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_refresh_token

router = APIRouter(prefix="/auth", tags=["Auth"])


class RefreshRequest(BaseModel):
    refresh_token: str

@router.post("/register")
def register(user: schemas.UserRegister, db: Session = Depends(get_db)):

    existing_user = db.query(models.User).filter(models.User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    new_user = models.User(
        name=user.name,
        email=user.email,
        hashed_password=hash_password(user.password)
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    token = create_access_token({"sub": str(new_user.id)})
    refresh_token = create_refresh_token({"sub": str(new_user.id)})

    return {
        "access_token": token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": new_user.id,
        "name": new_user.name,
        "email": new_user.email
    }


from fastapi.security import OAuth2PasswordRequestForm

@router.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(),
          db: Session = Depends(get_db)):

    db_user = db.query(models.User).filter(
        models.User.email == form_data.username
    ).first()

    if not db_user or not verify_password(form_data.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token({"sub": str(db_user.id)})
    refresh_token = create_refresh_token({"sub": str(db_user.id)})

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": db_user.id,
        "name": db_user.name,
        "email": db_user.email
    }


@router.post("/refresh")
def refresh_token(request: RefreshRequest, db: Session = Depends(get_db)):
    payload = decode_refresh_token(request.refresh_token)
    user_id = int(payload.get("sub"))
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return {
        "access_token": create_access_token({"sub": str(user_id)}),
        "token_type": "bearer"
    }
