from fastapi import APIRouter, Depends, HTTPException
from app.schemas.shift import ShiftOpenRequest, ShiftResponse
from app.services.shift_service import ShiftService
from app.core.security import get_current_user_id

router = APIRouter()

@router.post("/open", response_model=dict)
async def open_shift(
    request: ShiftOpenRequest,
    user_id: int = Depends(get_current_user_id)
):
    service = ShiftService()
    try:
        shift_id = service.open_shift(user_id, request)
        return {"ShiftID": shift_id, "message": "تم فتح الوردية بنجاح"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/active", response_model=ShiftResponse)
async def get_active_shift(
    user_id: int = Depends(get_current_user_id)
):
    service = ShiftService()
    try:
        shift = service.get_active_shift(user_id)
        if not shift:
            raise HTTPException(status_code=404, detail="لا توجد وردية مفتوحة حاليا")
        return shift
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/summary/{shift_id}", response_model=dict)
async def get_shift_summary(
    shift_id: int,
    user_id: int = Depends(get_current_user_id)
):
    service = ShiftService()
    try:
        summary = service.get_shift_summary(shift_id)
        if not summary:
            raise HTTPException(status_code=404, detail="الوردية غير موجودة")
        return summary
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/close", response_model=dict)
async def close_shift(
    payload: dict,
    user_id: int = Depends(get_current_user_id)
):
    shift_id = payload.get("ShiftID")
    ending_cash = payload.get("EndingCash")
    
    if shift_id is None or ending_cash is None:
        raise HTTPException(status_code=400, detail="معرف الوردية ومبلغ الإغلاق مطلوبان")
        
    service = ShiftService()
    try:
        service.close_shift(shift_id, ending_cash)
        return {"message": "تم إغلاق الوردية بنجاح"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
