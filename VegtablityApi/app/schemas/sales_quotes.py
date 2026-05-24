from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class SalesQuoteDetailResponse(BaseModel):
    QuoteDetailID: int
    QuoteID: int
    ProductID: int
    QuotedPrice: float
    ProductName: str
    Barcode: Optional[str]
    UnitName: Optional[str]

class SalesQuoteResponse(BaseModel):
    QuoteID: int
    PartnerID: int
    QuoteDate: datetime
    ExpiryDate: Optional[datetime]
    IsActive: bool
    Notes: Optional[str]
    PartnerName: str
    Details: Optional[List[SalesQuoteDetailResponse]] = None
