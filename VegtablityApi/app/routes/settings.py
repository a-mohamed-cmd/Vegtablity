from fastapi import APIRouter, HTTPException, status
from app.services.settings_service import SettingsService
from app.schemas.settings import PrinterSettingsSaveRequest

router = APIRouter()

@router.get("/company", response_model=dict)
async def get_company_settings():
    service = SettingsService()
    try:
        settings = service.get_company_settings()
        return settings
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ أثناء جلب إعدادات الشركة: {str(e)}"
        )

@router.post("/printer", response_model=dict)
async def save_printer_settings(request: PrinterSettingsSaveRequest):
    service = SettingsService()
    try:
        success = service.save_printer_settings(request.model_dump())
        return {"success": success, "message": "تم حفظ الإعدادات بنجاح في قاعدة البيانات"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ أثناء حفظ إعدادات الطابعة: {str(e)}"
        )

@router.get("/printer/{machine_hwid}", response_model=dict)
async def get_printer_settings(machine_hwid: str):
    service = SettingsService()
    try:
        settings = service.get_printer_settings(machine_hwid)
        # Return settings dict (might be empty if new machine)
        return settings
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ أثناء جلب إعدادات الطابعة للجهاز: {str(e)}"
        )

from typing import List

@router.get("/warehouses", response_model=List[dict])
async def get_warehouses():
    service = SettingsService()
    try:
        return service.get_warehouses()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ أثناء جلب المستودعات: {str(e)}"
        )

@router.get("/payment-accounts", response_model=List[dict])
async def get_payment_accounts():
    try:
        from app.services.voucher_service import VoucherService
        return VoucherService().get_accounts_for_voucher()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ أثناء جلب طرق الدفع: {str(e)}"
        )



