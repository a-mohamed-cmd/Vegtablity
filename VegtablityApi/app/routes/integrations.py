import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from app.core.security import get_current_user_id
from app.schemas.integrations import (
    ProviderConfigSaveRequest,
    CreatePaymentLinkRequest,
    PaymentLinkRefundRequest,
    TalabatOrderActionRequest,
)
from app.services.integrations.integration_service import IntegrationService

router = APIRouter(prefix="/integrations", tags=["Payment Gateways & Delivery Integrations"])
service = IntegrationService()


@router.get("/providers")
def get_providers(only_enabled: bool = False):
    return {
        "providers": service.get_providers(only_enabled=only_enabled),
        "is_talabat_configured": service.is_talabat_configured_and_active(),
    }


@router.post("/providers/save")
def save_provider_config(payload: ProviderConfigSaveRequest):
    try:
        return service.save_provider_config(payload.dict())
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as ex:
        raise HTTPException(status_code=500, detail=str(ex))


@router.get("/payment-links")
def get_payment_links(
    provider_code: Optional[str] = None,
    status: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    search_text: Optional[str] = None,
    page_number: int = 1,
    page_size: int = 25,
):
    return service.get_payment_links(
        provider_code, status, start_date, end_date, search_text, page_number, page_size
    )


@router.get("/payment-links/paged")
def get_payment_links_paged(
    provider_code: Optional[str] = None,
    status: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    search_text: Optional[str] = None,
    page_number: int = 1,
    page_size: int = 25,
):
    return service.get_payment_links_paged(
        provider_code=provider_code,
        status=status,
        start_date=start_date,
        end_date=end_date,
        search_text=search_text,
        page_number=page_number,
        page_size=page_size,
    )


@router.get("/payment-links/invoice-quick-info/{inv_id}")
def get_invoice_quick_info(inv_id: int):
    info = service.get_invoice_quick_info(inv_id)
    if not info:
        raise HTTPException(status_code=404, detail=f"⚠️ لم يتم العثور على الفاتورة رقم #{inv_id}.")
    return info


@router.post("/payment-links")
def create_payment_link(payload: CreatePaymentLinkRequest):
    try:
        return service.create_payment_link(payload.dict())
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as ex:
        raise HTTPException(status_code=500, detail=str(ex))


@router.post("/payment-links/{link_id}/status")
def update_link_status(link_id: int, new_status: str = "Paid"):
    try:
        return service.update_payment_link_status(link_id=link_id, new_status=new_status)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as ex:
        raise HTTPException(status_code=500, detail=str(ex))


@router.post("/payment-links/{link_id}/refresh")
def refresh_link_status(link_id: int):
    try:
        return service.refresh_payment_link_status(link_id=link_id)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as ex:
        raise HTTPException(status_code=500, detail=str(ex))


@router.post("/payment-links/refund")
def refund_payment_link(
    payload: PaymentLinkRefundRequest,
    current_user_id: int = Depends(get_current_user_id),
):
    try:
        return service.refund_payment_link(
            link_id=payload.LinkID,
            refund_amount=payload.RefundAmount,
            reason=payload.RefundReason or "Customer Request",
            user_id=current_user_id,
        )
    except PermissionError as pe:
        raise HTTPException(status_code=403, detail=str(pe))
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as ex:
        raise HTTPException(status_code=400, detail=str(ex))


# =========================================================================
# Webhooks for Tap, MyFatoorah, UPayments
# =========================================================================
@router.post("/webhooks/{provider_code}")
async def payment_gateway_webhook(provider_code: str, request: Request):
    body_bytes = await request.body()
    raw_text = body_bytes.decode("utf-8", errors="ignore")
    try:
        data = json.loads(raw_text) if raw_text else {}
    except Exception:
        data = {}

    code = provider_code.upper()
    ext_id = None
    target_status = "Pending"

    if code == "TAP":
        ext_id = data.get("id")
        st = str(data.get("status", "")).upper()
        if st == "CAPTURED":
            target_status = "Paid"
        elif st in ("CANCELLED", "TIMEDOUT", "ABANDONED"):
            target_status = "Expired"
        elif st in ("FAILED", "DECLINED"):
            target_status = "Failed"
    elif code == "MYFATOORAH":
        d_obj = data.get("Data", data)
        ext_id = str(d_obj.get("InvoiceId", ""))
        st = str(d_obj.get("TransactionStatus", d_obj.get("InvoiceStatus", ""))).upper()
        if st in ("SUCCESS", "PAID", "CAPTURED"):
            target_status = "Paid"
        elif st in ("FAILED", "ERROR"):
            target_status = "Failed"
    elif code == "UPAYMENTS":
        ext_id = data.get("trackId") or data.get("orderId")
        st = str(data.get("result", "")).upper()
        if st in ("CAPTURED", "PAID", "SUCCESS"):
            target_status = "Paid"
        elif st in ("NOT CAPTURED", "FAILED"):
            target_status = "Failed"

    if ext_id:
        service.update_payment_link_status(
            link_id=0, external_charge_id=str(ext_id), new_status=target_status, raw_json=raw_text
        )

    return {"received": True, "provider": code, "status": target_status}


# =========================================================================
# Talabat POS Plugin Endpoints & Order Management
# =========================================================================
@router.get("/talabat/orders")
def get_talabat_orders(
    status: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    search_text: Optional[str] = None,
):
    return {
        "is_talabat_configured": service.is_talabat_configured_and_active(),
        "orders": service.get_talabat_orders(status, start_date, end_date, search_text),
    }


@router.post("/talabat/order/{remote_id}", status_code=202)
async def dispatch_talabat_order(remote_id: str, request: Request):
    """
    Official Talabat POS Plugin Dispatch Order Endpoint:
    POST /integrations/talabat/order/{remoteId} -> returns HTTP 202 Accepted
    """
    raw_bytes = await request.body()
    raw_json = raw_bytes.decode("utf-8", errors="ignore")
    data = json.loads(raw_json) if raw_json else {}

    price_info = data.get("price") or {}
    customer = data.get("customer") or {}
    delivery = data.get("delivery") or {}
    address = delivery.get("address") or {}
    products = data.get("products") or []

    payload = {
        "OrderToken": data.get("token") or f"TOKEN_{ data.get('code', remote_id) }",
        "OrderCode": data.get("code") or remote_id,
        "ShortCode": data.get("shortCode") or "",
        "RemoteVendorId": remote_id,
        "ExpeditionType": data.get("expeditionType", "delivery"),
        "PaymentType": (data.get("payment") or {}).get("type", "ONLINE"),
        "SubTotal": float(price_info.get("subTotal", price_info.get("grandTotal", 0))),
        "DeliveryFee": float(price_info.get("deliveryFee", 0)),
        "DiscountAmount": float(price_info.get("discountTotal", 0)),
        "GrandTotal": float(price_info.get("grandTotal", 0)),
        "CurrencyCode": price_info.get("currency", "KWD"),
        "OrderStatus": "Received",
        "CustomerName": f"{customer.get('firstName', '')} {customer.get('lastName', '')}".strip() or "عميل Talabat",
        "CustomerPhone": customer.get("mobilePhone", ""),
        "DeliveryAddress": f"{address.get('city', '')} {address.get('street', '')} {address.get('building', '')}".strip(),
        "Comments": (data.get("comments") or {}).get("customerComment", ""),
        "ItemsJson": json.dumps(products, ensure_ascii=False),
        "RawPayloadJson": raw_json,
    }
    saved = service.save_or_update_talabat_order(payload, auto_create_invoice=False)
    return {"status": "Accepted", "remoteOrderId": f"TLB_{saved.get('TalabatOrderID', 0)}"}


@router.put("/talabat/remoteId/{remote_id}/remoteOrder/{remote_order_id}/posOrderStatus")
async def update_talabat_order_status_webhook(remote_id: str, remote_order_id: str, request: Request):
    raw_bytes = await request.body()
    data = json.loads(raw_bytes.decode("utf-8", errors="ignore") or "{}")
    new_status = data.get("status", "Cancelled")
    service.save_or_update_talabat_order(
        {
            "OrderToken": remote_order_id,
            "OrderCode": remote_order_id,
            "RemoteVendorId": remote_id,
            "OrderStatus": new_status,
            "RejectionReason": data.get("message", ""),
        },
        auto_create_invoice=False,
    )
    return {"status": "Updated"}


@router.post("/talabat/orders/action")
def perform_talabat_order_action(req: TalabatOrderActionRequest):
    action = req.Action.capitalize()
    target_status = "Accepted" if action == "Accept" else ("Prepared" if action == "Prepared" else "Rejected")
    saved = service.save_or_update_talabat_order(
        {
            "OrderToken": req.OrderToken,
            "OrderCode": req.OrderCode,
            "OrderStatus": target_status,
            "RejectionReason": req.RejectionReason,
            "UserID": req.UserID,
        },
        auto_create_invoice=(target_status == "Accepted"),
    )
    return saved

