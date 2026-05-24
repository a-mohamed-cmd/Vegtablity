from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
from app.schemas.purchase_quotes import PurchaseQuoteCreate, PurchaseQuoteResponse, PurchaseQuoteHeaderResponse, PurchaseQuoteDetailResponse
from app.services.purchase_quote_service import PurchaseQuoteService
from app.core.security import get_current_user_id

router = APIRouter()
service = PurchaseQuoteService()

@router.get("/", response_model=List[PurchaseQuoteHeaderResponse])
async def get_purchase_quotes(
    search: Optional[str] = None,
    user_id: int = Depends(get_current_user_id)
):
    try:
        return service.get_all_quotes(search)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# POST endpoint removed as per user request to disable sp_PurchaseQuote_Save and mobile quote creation.

@router.get("/{quote_id}/details", response_model=List[PurchaseQuoteDetailResponse])
async def get_purchase_quote_details(
    quote_id: int,
    user_id: int = Depends(get_current_user_id)
):
    try:
        return service.get_quote_details(quote_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

