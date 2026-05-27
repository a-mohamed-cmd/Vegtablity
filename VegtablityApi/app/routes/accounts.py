from fastapi import APIRouter, HTTPException, Depends
from typing import List, Dict, Any
from app.services.account_service import AccountService
from app.core.security import get_current_user_id

router = APIRouter(
    tags=["Accounts"]
)

_account_service = AccountService()

@router.get("/revenues", response_model=List[Dict[str, Any]])
async def get_revenues(user_id: int = Depends(get_current_user_id)):
    try:
        return _account_service.get_revenue_accounts()
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=traceback.format_exc())

@router.get("/expenses", response_model=List[Dict[str, Any]])
async def get_expenses(user_id: int = Depends(get_current_user_id)):
    try:
        return _account_service.get_expense_accounts()
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=traceback.format_exc())

@router.get("/general-partner")
async def get_general_partner(user_id: int = Depends(get_current_user_id)):
    """جلب بيانات العميل الثابت 'سند مباشر' - يُخزّن في ذاكرة التطبيق بعد أول استدعاء"""
    try:
        return _account_service.get_general_partner()
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=traceback.format_exc())
