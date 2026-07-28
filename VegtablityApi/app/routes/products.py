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

@router.get("/for-purchase", response_model=List[Product])
async def get_products_for_purchase(
    user_id: int = Depends(get_current_user_id)
):
    service = ProductService()
    return service.get_products_for_purchase()

@router.get("/for-sales", response_model=List[Product])
async def get_products_for_sales(
    user_id: int = Depends(get_current_user_id)
):
    service = ProductService()
    return service.get_products_for_sales()

@router.get("/for-recipe-ingredients", response_model=List[Product])
async def get_products_for_recipe_ingredients(
    warehouse_id: int = Query(None, description="Optional Warehouse ID"),
    user_id: int = Depends(get_current_user_id)
):
    service = ProductService()
    return service.get_products_for_recipe_ingredients(warehouse_id)

@router.get("/for-recipe-target", response_model=List[Product])
async def get_products_for_recipe_target(
    warehouse_id: int = Query(None, description="Optional Warehouse ID"),
    include_all: bool = Query(False, description="Include all target products regardless of recipe existence"),
    user_id: int = Depends(get_current_user_id)
):
    service = ProductService()
    return service.get_products_for_recipe_target(warehouse_id, include_all)

@router.post("/quick-add", response_model=dict)
async def quick_add_product(
    payload: dict,
    user_id: int = Depends(get_current_user_id)
):
    barcode = payload.get("Barcode")
    name = payload.get("ProductName")
    sale_price = payload.get("SalePrice", 0.0)
    purchase_price = payload.get("PurchasePrice", 0.0)
    product_type = payload.get("ProductType", 1)
    
    if not barcode or not name:
        raise HTTPException(status_code=400, detail="الباركود واسم المنتج مطلوبان")
        
    service = ProductService()
    try:
        product_id = service.quick_add_product(barcode, name, purchase_price, sale_price, product_type)
        return {"ProductID": product_id, "message": "تمت إضافة المنتج بنجاح"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


