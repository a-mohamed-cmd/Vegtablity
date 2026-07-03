from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

# =========================================================================
# Wastage Schemas
# =========================================================================

class WastageDetailRequest(BaseModel):
    ProductID: int
    Quantity: float
    CostPrice: float
    StockBefore: float = 0.0

class WastageSaveRequest(BaseModel):
    WastageID: Optional[int] = 0
    WastageDate: datetime
    WarehouseID: int = 1
    TotalValue: float
    Notes: Optional[str] = ""
    Details: List[WastageDetailRequest]

class WastageResponse(BaseModel):
    WastageID: int
    message: str


# =========================================================================
# Stock Take Schemas
# =========================================================================

class StockTakeDetailRequest(BaseModel):
    ProductID: int
    SystemQuantity: float
    ActualQuantity: float
    CostPrice: float

class StockTakeSaveRequest(BaseModel):
    StockTakeID: Optional[int] = 0
    StockTakeDate: datetime
    WarehouseID: int = 1
    TotalDifferenceValue: float
    Notes: Optional[str] = ""
    Details: List[StockTakeDetailRequest]

class StockTakeResponse(BaseModel):
    StockTakeID: int
    message: str
