from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class ShiftOpenRequest(BaseModel):
    StartingCash: float

class ShiftResponse(BaseModel):
    ShiftID: int
    UserID: int
    StartTime: datetime
    StartingCash: float
    Status: str

class ShiftSummaryResponse(BaseModel):
    ShiftID: int
    UserID: int
    UserName: Optional[str] = None
    StartTime: datetime
    EndTime: Optional[datetime] = None
    StartingCash: float
    Status: str
    TotalSales: float
    TotalPurchases: float
    SalesCount: int
    PurchasesCount: int
    TotalPaidSales: float
    TotalRemainder: float
    TotalPaidPurchases: float
    TotalPurchasesRemainder: float
