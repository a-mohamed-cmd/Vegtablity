from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from datetime import datetime, timedelta
import os
from app.services.license_control_service import LicenseControlService

router = APIRouter()

CTRL_SECRET_KEY = os.getenv("CTRL_SECRET_KEY", "ctrl_panel_secure_secret_key_2026")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60  # 1 hour token lifetime (no storage on client)

ctrl_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="ctrl/auth/login")

def create_ctrl_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, CTRL_SECRET_KEY, algorithm=ALGORITHM)

async def get_current_ctrl_user(token: str = Depends(ctrl_oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate control panel credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, CTRL_SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("username")
        if username is None:
            raise credentials_exception
        return username
    except JWTError:
        raise credentials_exception

@router.post("/auth/login")
async def ctrl_login(payload: dict):
    """
    Validates server SQL Server credentials and returns an isolated JWT token.
    """
    username = payload.get("username")
    password = payload.get("password")
    if not username or not password:
        raise HTTPException(status_code=400, detail="Username and password are required")
    
    service = LicenseControlService()
    if service.authenticate_server_user(username, password):
        token = create_ctrl_token({"username": username})
        return {"access_token": token, "token_type": "bearer"}
    else:
        raise HTTPException(status_code=401, detail="Incorrect SQL Server credentials")

@router.get("/databases")
async def get_dbs(current_user: str = Depends(get_current_ctrl_user)):
    """
    Retrieves all available databases on the SQL Server.
    """
    service = LicenseControlService()
    try:
        return service.get_databases()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/licenses/{db_name}")
async def get_licenses(db_name: str, current_user: str = Depends(get_current_ctrl_user)):
    """
    Retrieves device licenses for the specified database.
    """
    service = LicenseControlService()
    try:
        return service.get_licenses(db_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/licenses/{db_name}")
async def save_license(db_name: str, payload: dict, current_user: str = Depends(get_current_ctrl_user)):
    """
    Saves (inserts/updates) a device license on the specified database.
    """
    service = LicenseControlService()
    try:
        service.save_license(db_name, payload)
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/licenses/{db_name}/{license_id}")
async def delete_license(db_name: str, license_id: int, current_user: str = Depends(get_current_ctrl_user)):
    """
    Deletes a device license from the specified database.
    """
    service = LicenseControlService()
    try:
        service.delete_license(db_name, license_id)
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
