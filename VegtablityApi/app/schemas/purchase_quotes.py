from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class PurchaseQuoteDetailCreate(BaseModel):
    ProductID: int
    QuotedPrice: float

class PurchaseQuoteCreate(BaseModel):
    PartnerID: int
    QuoteDate: datetime
    ExpiryDate: Optional[datetime] = None
    IsActive: bool = True
    Notes: Optional[str] = None
    Details: List[PurchaseQuoteDetailCreate]

class PurchaseQuoteResponse(BaseModel):
    PurchaseQuoteID: int
    message: str

class PurchaseQuoteHeaderResponse(BaseModel):
    PurchaseQuoteID: int
    PartnerID: int
    QuoteDate: datetime
    ExpiryDate: Optional[datetime]
    Notes: Optional[str] = None
    PartnerName: str

class PurchaseQuoteDetailResponse(BaseModel):
    DetailID: int
    PurchaseQuoteID: int
    ProductID: int
    UnitPrice: float
    ProductName: str
    Barcode: Optional[str] = None
    UnitName: Optional[str] = None

