from fastapi import APIRouter, HTTPException
from typing import List
from app.schemas.discount import (
    ProductDiscountSaveRequest,
    ProductDiscountResponse,
    ActiveDiscountPosResponse,
    ProductForDiscountResponse
)
from app.services.discount_service import DiscountService

router = APIRouter(prefix="/discounts", tags=["Discounts"])
discount_service = DiscountService()

@router.get("/", response_model=List[ProductDiscountResponse])
def get_all_discounts():
    try:
        return discount_service.get_all_discounts()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/pos/active", response_model=List[ActiveDiscountPosResponse])
def get_active_discounts_for_pos():
    try:
        return discount_service.get_active_discounts_for_pos()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/products", response_model=List[ProductForDiscountResponse])
def get_products_for_discounts():
    try:
        return discount_service.get_products_for_discounts()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{discount_id}/products", response_model=List[int])
def get_product_ids_for_discount(discount_id: int):
    try:
        return discount_service.get_product_ids_for_discount(discount_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/", response_model=dict)
def save_discount(request: ProductDiscountSaveRequest):
    try:
        saved_id = discount_service.save_discount(request.model_dump())
        return {"success": True, "DiscountID": saved_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{discount_id}", response_model=dict)
def delete_discount(discount_id: int):
    try:
        success = discount_service.delete_discount(discount_id)
        return {"success": success}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
