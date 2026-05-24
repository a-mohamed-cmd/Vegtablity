from fastapi import APIRouter, Query, Depends
from app.schemas.partners import Partner
from app.services.partner_service import PartnerService
from app.core.security import get_current_user_id
from typing import List

router = APIRouter()

@router.get("/", response_model=List[Partner])
async def get_partners(
    type: str = Query(..., description="Customer or Supplier"),
    search: str = Query("", description="Search by name or phone"),
    user_id: int = Depends(get_current_user_id)
):
    service = PartnerService()
    return service.get_partners(type, search)

@router.get("/active-purchase-offers", response_model=List[Partner])
async def get_active_purchase_offers(user_id: int = Depends(get_current_user_id)):
    service = PartnerService()
    return service.get_active_purchase_partners()

@router.get("/active-sales-offers", response_model=List[Partner])
async def get_active_sales_offers(user_id: int = Depends(get_current_user_id)):
    service = PartnerService()
    return service.get_active_sales_partners()

