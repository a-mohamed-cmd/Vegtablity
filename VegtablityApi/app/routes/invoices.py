from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.invoices import InvoiceCreate, InvoiceResponse
from app.services.invoice_service import InvoiceService
from app.core.security import get_current_user_id
from typing import List

router = APIRouter()

@router.get("/", response_model=List[dict])
async def get_invoices(
    type: str = "Sales", 
    search: str = None,
    shift_date: str = None,
    user_id: int = Depends(get_current_user_id)
):
    service = InvoiceService()
    try:
        return service.get_all_invoices(type, search, shift_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{inv_id}/pay", response_model=dict)
async def pay_invoice(
    inv_id: int,
    payload: dict,
    user_id: int = Depends(get_current_user_id)
):
    payment_amount = payload.get("PaymentAmount")
    payment_account_id = payload.get("PaymentAccountID")
    
    if payment_amount is None or payment_amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="مبلغ السداد يجب أن يكون أكبر من الصفر")
        
    service = InvoiceService()
    try:
        success = service.pay_invoice(inv_id, payment_amount, payment_account_id, user_id)
        if not success:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="فشل سداد الفاتورة")
        return {"message": "تم سداد الفاتورة بنجاح"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

@router.get("/{inv_id}", response_model=dict)
async def get_invoice(
    inv_id: int,
    user_id: int = Depends(get_current_user_id)
):
    service = InvoiceService()
    try:
        invoice = service.get_invoice_details(inv_id)
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        return invoice
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/", response_model=InvoiceResponse)
async def create_invoice(
    invoice: InvoiceCreate,
    user_id: int = Depends(get_current_user_id)
):
    service = InvoiceService()
    try:
        inv_id = service.save_invoice(invoice, user_id)
        return {"InvID": inv_id, "message": "Invoice saved successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
