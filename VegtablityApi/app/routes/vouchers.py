from fastapi import APIRouter, HTTPException, Depends
from app.services.voucher_service import VoucherService
from app.core.security import get_current_user_id
from app.services.shift_service import ShiftService

router = APIRouter()
_shift_service = ShiftService()


@router.get("/unpaid_invoices")
async def get_unpaid_invoices(
    partner_id: int,
    type: str = "Sales",
    user_id: int = Depends(get_current_user_id)
):
    """
    جلب الفواتير المُرحّلة وغير المسدّدة بالكامل للشريك.
    type: 'Sales' لعرض مديونيات العملاء | 'Purchase' لعرض مستحقات الموردين
    """
    service = VoucherService()
    try:
        return service.get_unpaid_invoices(partner_id, type)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/accounts")
async def get_voucher_accounts(
    user_id: int = Depends(get_current_user_id)
):
    """جلب الحسابات المتاحة (صندوق/بنك) لاستخدامها في السندات"""
    service = VoucherService()
    try:
        return service.get_accounts_for_voucher()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bulk_pay")
async def bulk_pay(
    payload: dict,
    user_id: int = Depends(get_current_user_id)
):
    """
    سداد مديونيات جماعي وإنشاء سند قبض/صرف مرتبط بالوردية.
    السند يُحفظ بحالة غير مرحّلة (IsPosted=0) ويُرحَّل تلقائياً عند إغلاق الوردية.

    Payload:
    {
        "PartnerID": int,
        "VoucherType": "Receipt" | "Payment",
        "TotalAmount": float,
        "AccountID": int,
        "ShiftID": int,       (اختياري - يُجلب من الكاش إذا لم يُرسل)
        "Description": str,
        "Allocations": [{"InvID": int, "Amount": float}, ...]
    }
    """
    partner_id   = payload.get("PartnerID")
    voucher_type = payload.get("VoucherType")
    total_amount = payload.get("TotalAmount")
    account_id   = payload.get("AccountID")
    description  = payload.get("Description", "")
    allocations  = payload.get("Allocations", [])

    # جلب ShiftID من الكاش إذا لم يُرسل صراحةً
    shift_id = payload.get("ShiftID") or _shift_service.get_active_shift_id(user_id)

    if not all([partner_id, voucher_type, total_amount, account_id, shift_id]):
        raise HTTPException(
            status_code=400,
            detail="البيانات المطلوبة ناقصة: PartnerID, VoucherType, TotalAmount, AccountID, ShiftID"
        )

    if voucher_type not in ("Receipt", "Payment"):
        raise HTTPException(status_code=400, detail="نوع السند يجب أن يكون 'Receipt' أو 'Payment'")



    service = VoucherService()
    try:
        result = service.bulk_pay(
            partner_id=partner_id,
            voucher_type=voucher_type,
            total_amount=total_amount,
            account_id=account_id,
            user_id=user_id,
            shift_id=shift_id,
            description=description,
            allocations=allocations
        )
        return result
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        raise HTTPException(status_code=500, detail=error_msg)

@router.get("/{voucher_id}/allocations")
async def get_voucher_allocations(
    voucher_id: int,
    user_id: int = Depends(get_current_user_id)
):
    try:
        service = VoucherService()
        return service.get_voucher_allocations(voucher_id)
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=traceback.format_exc())

@router.post("/general")
async def save_general_voucher(
    payload: dict,
    user_id: int = Depends(get_current_user_id)
):
    """
    حفظ سند عام (قبض أو صرف) حر بدون تحديد مورد أو عميل.
    يعتمد على العميل الثابت 'سند مباشر'.
    """
    print(f"[DEBUG] General Voucher Payload: {payload}")
    
    voucher_type   = payload.get("VoucherType")
    total_amount   = payload.get("TotalAmount")
    account_id     = payload.get("AccountID")       # حساب الإيراد/المصروف
    description    = payload.get("Description", "")
    payment_method = str(payload.get("PaymentMethod", ""))  # AccountID لحساب الصندوق
    shift_id       = payload.get("ShiftID")         # رقم الوردية

    if not all([voucher_type, total_amount, account_id, payment_method]):
        raise HTTPException(
            status_code=400,
            detail=f"جميع الحقول مطلوبة (VoucherType, TotalAmount, AccountID, PaymentMethod). تم استلام: {payload}"
        )

    try:
        service = VoucherService()
        result = service.save_general_voucher(
            voucher_type=voucher_type,
            total_amount=float(total_amount),
            account_id=int(account_id),
            user_id=user_id,
            shift_id=int(shift_id) if shift_id else None,
            description=description,
            payment_method=payment_method
        )
        return result
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        raise HTTPException(status_code=500, detail=error_msg)
