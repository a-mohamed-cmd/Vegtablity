from pydantic import BaseModel
from typing import Optional, List

class Product(BaseModel):
    ProductID: int
    ProductName: str
    Barcode: Optional[str] = None
    SalePrice: float
    PurchasePrice: float
    UnitName: Optional[str] = None
    StockQuantity: float = 0.0
    CategoryID: Optional[int] = None
    CatName: Optional[str] = None

class ProductSearchResponse(BaseModel):
    products: List[Product]
