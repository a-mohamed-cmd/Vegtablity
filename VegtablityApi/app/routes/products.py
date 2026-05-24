from fastapi import APIRouter, Query, Depends, HTTPException, status
from app.schemas.products import Product
from app.services.product_service import ProductService
from app.core.security import get_current_user_id
from typing import List

router = APIRouter()

@router.get("/", response_model=List[Product])
async def get_products(
    search: str = Query("", description="Search by name or barcode"),
    user_id: int = Depends(get_current_user_id)
):
    service = ProductService()
    return service.get_products(search)

@router.get("/barcode/{barcode}", response_model=Product)
async def get_product_by_barcode(
    barcode: str,
    user_id: int = Depends(get_current_user_id)
):
    service = ProductService()
    product = service.get_product_by_barcode(barcode)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="الصنف غير موجود أو غير نشط"
        )
    return product

