from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from app.schemas.auth import TokenResponse
from app.services.auth_service import AuthService
from app.core.database import get_db_connection

router = APIRouter()

@router.post("/login", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    auth_service = AuthService()
    user = auth_service.authenticate_user(form_data.username, form_data.password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    from app.core.security import create_access_token
    access_token = create_access_token(data={"sub": form_data.username, "user_id": user["UserID"]})
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "username": form_data.username,
        "user_id": user["UserID"]
    }

