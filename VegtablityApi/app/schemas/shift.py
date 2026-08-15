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
    EndingCash: Optional[float] = None
    Status: str
    TotalSales: float
    TotalPurchases: float
    SalesCount: int
    PurchasesCount: int
    TotalPaidSales: float
    TotalCashSales: Optional[float] = 0.0
    CashSales: Optional[float] = 0.0
    TotalKnetSales: Optional[float] = 0.0
    KnetSales: Optional[float] = 0.0
    TotalNonCashSales: Optional[float] = 0.0
    CardSales: Optional[float] = 0.0
    TotalRemainder: float
    TotalPaidPurchases: float
    TotalCashPurchases: Optional[float] = 0.0
    TotalNonCashPurchases: Optional[float] = 0.0
    TotalPurchasesRemainder: float
    TotalReceiptVouchers: Optional[float] = 0.0
    TotalPaymentVouchers: Optional[float] = 0.0
    TotalExpenses: Optional[float] = 0.0
    ExpectedCash: Optional[float] = 0.0
    Difference: Optional[float] = 0.0
    Vouchers: Optional[list] = []
    PaymentTotals: Optional[list] = []

