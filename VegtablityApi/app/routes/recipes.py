from fastapi import APIRouter, Query, Depends, HTTPException, status
from app.services.recipe_service import RecipeService
from app.core.security import get_current_user_id
from typing import List, Dict, Any, Optional

router = APIRouter()

@router.get("/", response_model=List[Dict[str, Any]])
async def get_all_recipes(
    user_id: int = Depends(get_current_user_id)
):
    service = RecipeService()
    return service.get_all_recipes()

@router.get("/{product_id}", response_model=Dict[str, Any])
async def get_recipe_by_product(
    product_id: int,
    warehouse_id: Optional[int] = Query(None),
    user_id: int = Depends(get_current_user_id)
):
    service = RecipeService()
    recipe = service.get_recipe_by_product(product_id, warehouse_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="لا توجد وصفة مسجلة لهذا المنتج")
    return recipe

@router.post("/", response_model=dict)
async def save_recipe(
    payload: dict,
    user_id: int = Depends(get_current_user_id)
):
    product_id = payload.get("ProductID")
    notes = payload.get("Notes", "")
    details = payload.get("Details", [])
    warehouse_id = payload.get("WarehouseID") or payload.get("warehouse_id")
    
    if not product_id:
        raise HTTPException(status_code=400, detail="كود المنتج المطلوب تسجيل الوصفة له غير محدد")
    if not details:
        raise HTTPException(status_code=400, detail="يجب إدخال مادة خام واحدة على الأقل في تفاصيل الوصفة")
        
    service = RecipeService()
    try:
        recipe_id = service.save_recipe(product_id, notes, details, warehouse_id)
        return {"RecipeID": recipe_id, "message": "تم حفظ الوصفة وتحديث أسعار التكلفة بنجاح"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{recipe_id}", response_model=dict)
async def delete_recipe(
    recipe_id: int,
    user_id: int = Depends(get_current_user_id)
):
    service = RecipeService()
    try:
        service.delete_recipe(recipe_id)
        return {"message": "تم حذف الوصفة بنجاح"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
