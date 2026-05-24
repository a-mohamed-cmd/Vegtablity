from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
from app.schemas.sales_quotes import SalesQuoteResponse, SalesQuoteDetailResponse
from app.services.sales_quote_service import SalesQuoteService
from app.core.security import get_current_user_id

router = APIRouter()
service = SalesQuoteService()

@router.get("/", response_model=List[SalesQuoteResponse])
async def get_sales_quotes(
    search: Optional[str] = None,
    user_id: int = Depends(get_current_user_id)
):
    try:
        return service.get_quotes_paged(search)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{quote_id}/details", response_model=List[SalesQuoteDetailResponse])
async def get_sales_quote_details(
    quote_id: int,
    user_id: int = Depends(get_current_user_id)
):
    try:
        return service.get_quote_details(quote_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
