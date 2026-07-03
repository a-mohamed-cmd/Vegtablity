from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.inventory import WastageSaveRequest, WastageResponse, StockTakeSaveRequest, StockTakeResponse
from app.services.inventory_service import InventoryService
from app.core.security import get_current_user_id

router = APIRouter()

@router.post("/wastage", response_model=WastageResponse)
async def create_wastage(
    wastage: WastageSaveRequest,
    user_id: int = Depends(get_current_user_id)
):
    service = InventoryService()
    try:
        wastage_id = service.save_wastage(wastage, user_id)
        return {
            "WastageID": wastage_id,
            "message": "Wastage draft saved successfully"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@router.post("/stocktake", response_model=StockTakeResponse)
async def create_stocktake(
    stocktake: StockTakeSaveRequest,
    user_id: int = Depends(get_current_user_id)
):
    service = InventoryService()
    try:
        stocktake_id = service.save_stocktake(stocktake, user_id)
        return {
            "StockTakeID": stocktake_id,
            "message": "Stocktake draft saved successfully"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@router.get("/stock-cost", response_model=dict)
async def get_product_stock_cost(
    product_id: int,
    warehouse_id: int,
    user_id: int = Depends(get_current_user_id)
):
    service = InventoryService()
    try:
        return service.get_product_stock_cost(product_id, warehouse_id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

