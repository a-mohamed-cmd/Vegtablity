from fastapi import APIRouter, HTTPException, status, Request, Query
from typing import Optional
from app.schemas.auth import TokenResponse
from app.services.auth_service import AuthService
from app.core.security import create_access_token

router = APIRouter()

def extract_database(request: Request, database: Optional[str] = None) -> Optional[str]:
    """استخراج قاعدة البيانات المستهدفة إما من الباراميتر أو من اسم الدومين الفرعي (Subdomain)"""
    if database and database.strip():
        return database.strip()
    
    host = request.headers.get("host", "").lower()
    if "washa" in host:
        return "WashaDB"
    elif "jawhara" in host:
        return "JawharaDB"
    elif "zatter" in host:
        return "zatterDB"
    elif "oman" in host:
        return "OmanCustmerDB"
    elif "vegtablity" in host or "veg" in host:
        return "VegtablityDB"
    
    return None

@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    database: Optional[str] = Query(None, description="Target database name/alias")
):
    """
    تسجيل الدخول الموحد لجميع الأنظمة (Web, Mobile POS, Desktop, Swagger UI)
    يدعم كلاً من application/json و application/x-www-form-urlencoded و multipart/form-data
    """
    username = None
    password = None
    target_db = database
    
    content_type = request.headers.get("content-type", "").lower()
    
    # 1. محاولة قراءة البيانات كـ JSON
    if "application/json" in content_type:
        try:
            body = await request.json()
            if isinstance(body, dict):
                username = body.get("username")
                password = body.get("password")
                if not target_db:
                    target_db = body.get("database")
        except Exception:
            pass
            
    # 2. محاولة قراءة البيانات كـ Form-Urlencoded أو Multipart (من نقاط البيع POS و Swagger)
    if not username or not password:
        try:
            form = await request.form()
            username = form.get("username")
            password = form.get("password")
            if not target_db:
                target_db = form.get("database")
        except Exception:
            pass
            
    if not username or not password:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="اسم المستخدم وكلمة المرور مطلوبان"
        )
        
    db = extract_database(request, target_db)
    auth_service = AuthService()
    user = auth_service.authenticate_user(username, password, database=db)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="اسم المستخدم أو كلمة المرور غير صحيحة",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    access_token = create_access_token(data={"sub": username, "user_id": user["UserID"]})
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "username": username,
        "user_id": user["UserID"],
        "role_name": user.get("RoleName", "admin")
    }

