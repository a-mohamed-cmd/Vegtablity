from pydantic import BaseModel
from typing import Optional, List

class ProductDiscountSaveRequest(BaseModel):
    DiscountID: Optional[int] = 0
    DiscountName: str
    DiscountType: int  # 1: Percentage %, 2: Fixed Amount, 3: Bundle/Tier
    DiscountValue: float
    MinQuantity: Optional[float] = 1.0
    IsActive: Optional[bool] = True
    ProductIDs: List[int] = []

class ProductDiscountResponse(BaseModel):
    DiscountID: int
    DiscountName: str
    DiscountType: int
    DiscountValue: float
    MinQuantity: float
    IsActive: bool
    CreatedDate: Optional[str] = None
    ProductCount: int = 0

class ActiveDiscountPosResponse(BaseModel):
    DiscountID: int
    DiscountName: str
    DiscountType: int
    DiscountValue: float
    MinQuantity: float
    ProductID: int

class ProductForDiscountResponse(BaseModel):
    ProductID: int
    ProductName: str
    Barcode: Optional[str] = None
    ProductType: int
    SalePrice: float
    PurchasePrice: float
    IsActive: bool
    UnitName: str
